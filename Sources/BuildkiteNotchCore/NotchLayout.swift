import CoreGraphics
import Foundation

public enum ScreenEdge: String, Codable, Sendable, CaseIterable {
    case top, bottom, left, right

    public var isHorizontal: Bool { self == .top || self == .bottom }
}

/// Where the notch lives: an edge of a screen plus a 0...1 fraction along it
/// (left to right for top/bottom, bottom to top for left/right).
public struct NotchPlacement: Codable, Sendable, Equatable {
    public var edge: ScreenEdge
    public var position: Double
    /// CGDirectDisplayID of the screen; nil means the main screen.
    public var displayID: UInt32?

    public init(edge: ScreenEdge = .top, position: Double = 0.5, displayID: UInt32? = nil) {
        self.edge = edge
        self.position = min(max(position, 0), 1)
        self.displayID = displayID
    }

    public static let `default` = NotchPlacement()

    public var isCentered: Bool { abs(position - 0.5) < 0.0001 }
}

/// Pure geometry for the notch. All rects are in screen coordinates
/// (AppKit convention, origin bottom-left).
public enum NotchLayout {
    /// Snap to the middle of an edge when dropped this close to it (fraction of the edge).
    public static let centerSnap = 0.03

    /// Rect of a box with `along` length and `across` depth hugging `placement`'s edge,
    /// centered at the placement position and clamped inside the screen.
    public static func rect(
        for placement: NotchPlacement,
        along: CGFloat,
        across: CGFloat,
        in screen: CGRect
    ) -> CGRect {
        let fraction = CGFloat(placement.position)
        switch placement.edge {
        case .top, .bottom:
            let length = min(along, screen.width)
            let center = screen.minX + fraction * screen.width
            let x = min(max(center - length / 2, screen.minX), screen.maxX - length)
            let y = placement.edge == .top ? screen.maxY - across : screen.minY
            return CGRect(x: x, y: y, width: length, height: across)
        case .left, .right:
            let length = min(along, screen.height)
            let center = screen.minY + fraction * screen.height
            let y = min(max(center - length / 2, screen.minY), screen.maxY - length)
            let x = placement.edge == .left ? screen.minX : screen.maxX - across
            return CGRect(x: x, y: y, width: across, height: length)
        }
    }

    /// Placement whose edge is the closest one to `point`.
    public static func placement(nearest point: CGPoint, in screen: CGRect, displayID: UInt32?) -> NotchPlacement {
        let distances: [(ScreenEdge, CGFloat)] = [
            (.top, abs(screen.maxY - point.y)),
            (.bottom, abs(point.y - screen.minY)),
            (.left, abs(point.x - screen.minX)),
            (.right, abs(screen.maxX - point.x)),
        ]
        let edge = distances.min { $0.1 < $1.1 }!.0
        var position = edge.isHorizontal
            ? Double((point.x - screen.minX) / screen.width)
            : Double((point.y - screen.minY) / screen.height)
        if abs(position - 0.5) < centerSnap { position = 0.5 }
        return NotchPlacement(edge: edge, position: position, displayID: displayID)
    }

    /// Grows `rect` by `amount` towards the outside of the screen edge so the
    /// last pixel row/column still counts as hovering.
    public static func extendTowardEdge(_ rect: CGRect, edge: ScreenEdge, by amount: CGFloat) -> CGRect {
        switch edge {
        case .top: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + amount)
        case .bottom: CGRect(x: rect.minX, y: rect.minY - amount, width: rect.width, height: rect.height + amount)
        case .left: CGRect(x: rect.minX - amount, y: rect.minY, width: rect.width + amount, height: rect.height)
        case .right: CGRect(x: rect.minX, y: rect.minY, width: rect.width + amount, height: rect.height)
        }
    }
}
