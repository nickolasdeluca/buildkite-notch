import AppKit
import BuildkiteNotchCore
import Observation
import SwiftUI

enum NotchMetrics {
    static let maxItems = 5
    /// Depth of the notch (distance it sticks out from the edge).
    static let verticalThickness: CGFloat = 52
    static let horizontalThickness: CGFloat = 34
    /// Space each stacked pipeline takes along the edge.
    static let verticalItemLength: CGFloat = 58
    static let horizontalItemLength: CGFloat = 66
    static let stackPadding: CGFloat = 8
    /// Concave curve joining the notch to the screen edge.
    static let flare: CGFloat = 10
    static let cardWidth: CGFloat = 330
    static let cardMaxHeight: CGFloat = 560
    static let cardMinHeight: CGFloat = 120
    static let cardGap: CGFloat = 8
    static let screenMargin: CGFloat = 8
    /// Room around the card for its shadow.
    static let shadowMargin: CGFloat = 24
}

/// State shared between the AppKit controller and the SwiftUI views.
/// Rects are window-local with a top-left origin (SwiftUI convention).
@MainActor
@Observable
final class NotchModel {
    var edge: ScreenEdge = .top
    var windowSize: CGSize = .zero
    var collapsedRect: CGRect = .zero
    var cardRect: CGRect = .zero
    var thickness: CGFloat = NotchMetrics.horizontalThickness
    /// Width hidden behind the camera housing when merged with a hardware notch.
    var hardwareNotchWidth: CGFloat?
    var isExpanded = false
    var isGrabbing = false
    /// Natural height of the card content, reported by the view.
    var contentHeight: CGFloat = 0
}

final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Borderless windows may sit over the menu bar and screen edges.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class NotchController {
    let model = NotchModel()

    private let panel = NotchPanel()
    private let settings: AppSettings
    private var monitors: [Any] = []
    private var expandTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var isDragging = false

    // Screen-space rects of the current layout.
    private var windowFrame: CGRect = .zero
    private var collapsedFrame: CGRect = .zero
    private var cardFrame: CGRect = .zero

    init(settings: AppSettings, store: BuildStore, openSettings: @escaping () -> Void) {
        self.settings = settings
        let hosting = FirstMouseHostingView(
            rootView: NotchRootView(model: model, store: store, settings: settings, openSettings: openSettings)
        )
        hosting.sizingOptions = []
        panel.contentView = hosting

        layout()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        }
        observeChanges({ [settings] in settings.placement }) { [weak self] in self?.layout() }
        observeChanges({ [model] in model.contentHeight }) { [weak self] in self?.layout() }
        observeChanges({ [settings] in settings.pipelines.count }) { [weak self] in self?.layout() }
        installMonitors()
    }

    // MARK: - Layout

    private func layout() {
        let placement = settings.placement
        let edge = placement.edge
        let screen = Self.screen(for: placement.displayID)
        let frame = screen.frame
        let hardwareNotch = Self.hardwareNotch(of: screen)
        let mergesWithNotch = edge == .top && placement.isCentered && hardwareNotch != nil

        let items = CGFloat(max(1, min(settings.pipelines.count, NotchMetrics.maxItems)))
        let thickness = edge.isHorizontal
            ? max(hardwareNotch?.height ?? 0, NotchMetrics.horizontalThickness)
            : NotchMetrics.verticalThickness
        let itemLength = edge.isHorizontal ? NotchMetrics.horizontalItemLength : NotchMetrics.verticalItemLength
        let stackLength: CGFloat = if mergesWithNotch {
            // Items split into two symmetric ears beside the camera housing.
            hardwareNotch!.width + 2 * ((items / 2).rounded(.up) * itemLength + NotchMetrics.stackPadding)
        } else {
            items * itemLength + 2 * NotchMetrics.stackPadding
        }

        collapsedFrame = NotchLayout.rect(
            for: placement,
            along: stackLength + 2 * NotchMetrics.flare,
            across: thickness,
            in: frame
        )
        let height = min(max(model.contentHeight, NotchMetrics.cardMinHeight), NotchMetrics.cardMaxHeight)
        cardFrame = cardRect(height: height, edge: edge, in: frame)
        windowFrame = cardRect(height: NotchMetrics.cardMaxHeight, edge: edge, in: frame)
            .insetBy(dx: -NotchMetrics.shadowMargin, dy: -NotchMetrics.shadowMargin)
            .union(collapsedFrame)

        if panel.frame != windowFrame { panel.setFrame(windowFrame, display: true) }
        model.edge = edge
        model.thickness = thickness
        model.hardwareNotchWidth = mergesWithNotch ? hardwareNotch!.width : nil
        model.windowSize = windowFrame.size
        model.collapsedRect = local(collapsedFrame)
        model.cardRect = local(cardFrame)
    }

    /// The card floats beside the notch, on the screen side, kept inside the screen.
    private func cardRect(height: CGFloat, edge: ScreenEdge, in screen: CGRect) -> CGRect {
        let width = NotchMetrics.cardWidth
        let gap = NotchMetrics.cardGap
        let notch = collapsedFrame
        let origin: CGPoint = switch edge {
        case .top: CGPoint(x: notch.midX - width / 2, y: notch.minY - gap - height)
        case .bottom: CGPoint(x: notch.midX - width / 2, y: notch.maxY + gap)
        case .left: CGPoint(x: notch.maxX + gap, y: notch.midY - height / 2)
        case .right: CGPoint(x: notch.minX - gap - width, y: notch.midY - height / 2)
        }
        let bounds = screen.insetBy(dx: NotchMetrics.screenMargin, dy: NotchMetrics.screenMargin)
        return CGRect(
            x: min(max(origin.x, bounds.minX), bounds.maxX - width),
            y: min(max(origin.y, bounds.minY), bounds.maxY - height),
            width: width,
            height: height
        )
    }

    private func local(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX - windowFrame.minX, y: windowFrame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func screen(for displayID: UInt32?) -> NSScreen {
        NSScreen.screens.first { $0.displayID == displayID } ?? NSScreen.screens.first ?? NSScreen.main!
    }

    private static func hardwareNotch(of screen: NSScreen) -> CGSize? {
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea
        else { return nil }
        return CGSize(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
    }

    // MARK: - Mouse

    private func installMonitors() {
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .flagsChanged],
            handler: { [weak self] _ in MainActor.assumeIsolated { self?.updateHover() } }
        ) { monitors.append(global) }

        if let local = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .flagsChanged, .leftMouseDown, .leftMouseDragged, .leftMouseUp],
            handler: { [weak self] event in
                nonisolated(unsafe) let event = event
                let consumed = MainActor.assumeIsolated { self?.consumes(event) ?? false }
                return consumed ? nil : event
            }
        ) { monitors.append(local) }
    }

    /// Returns true when the event belongs to an Option-drag and must not reach SwiftUI.
    private func consumes(_ event: NSEvent) -> Bool {
        switch event.type {
        case .leftMouseDown where model.isGrabbing:
            isDragging = true
            NSCursor.closedHand.set()
            return true
        case .leftMouseDragged where isDragging:
            drag(to: NSEvent.mouseLocation)
            return true
        case .leftMouseUp where isDragging:
            isDragging = false
            model.isGrabbing = false
            panel.ignoresMouseEvents = true
            NSCursor.arrow.set()
            updateHover()
            return true
        default:
            updateHover()
            return false
        }
    }

    private func drag(to point: CGPoint) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? Self.screen(for: settings.placement.displayID)
        let placement = NotchLayout.placement(nearest: point, in: screen.frame, displayID: screen.displayID)
        if placement != settings.placement { settings.placement = placement }
    }

    private func updateHover() {
        guard !isDragging else { return }
        let point = NSEvent.mouseLocation
        let hotZone = model.isExpanded
            ? collapsedFrame.union(cardFrame).insetBy(dx: -6, dy: -6)
            : NotchLayout.extendTowardEdge(collapsedFrame, edge: model.edge, by: 2)
        let inside = hotZone.contains(point)
        let wantsGrab = inside && !model.isExpanded && NSEvent.modifierFlags.contains(.option)

        if wantsGrab != model.isGrabbing {
            model.isGrabbing = wantsGrab
            panel.ignoresMouseEvents = !wantsGrab
            (wantsGrab ? NSCursor.openHand : NSCursor.arrow).set()
        }
        if wantsGrab {
            expandTask?.cancel()
            return
        }

        if inside {
            collapseTask?.cancel()
            collapseTask = nil
            if !model.isExpanded, expandTask == nil {
                expandTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(120))
                    guard !Task.isCancelled else { return }
                    self?.setExpanded(true)
                    self?.expandTask = nil
                }
            }
        } else {
            expandTask?.cancel()
            expandTask = nil
            if model.isExpanded, collapseTask == nil {
                collapseTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    self?.setExpanded(false)
                    self?.collapseTask = nil
                }
            }
        }
    }

    private func setExpanded(_ expanded: Bool) {
        model.isExpanded = expanded
        panel.ignoresMouseEvents = !expanded
    }
}

extension NSScreen {
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// Calls `onChange` every time the observable value read by `value` changes.
@MainActor
func observeChanges<T>(_ value: @escaping @MainActor () -> T, onChange: @escaping @MainActor () -> Void) {
    withObservationTracking {
        _ = value()
    } onChange: {
        Task { @MainActor in
            onChange()
            observeChanges(value, onChange: onChange)
        }
    }
}
