import AppKit
import BuildkiteNotchCore
import SwiftUI

struct NotchRootView: View {
    let model: NotchModel
    let store: BuildStore
    let settings: AppSettings
    let openSettings: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ZStack(alignment: .topLeading) {
                Color.clear

                if model.isExpanded {
                    BuildCard(model: model, store: store, settings: settings, openSettings: openSettings, now: context.date)
                        .frame(width: model.cardRect.width, height: model.cardRect.height, alignment: .top)
                        .background(CardBackground(style: settings.notchStyle))
                        .clipShape(RoundedRectangle(cornerRadius: CardBackground.radius, style: .continuous))
                        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
                        .offset(x: model.cardRect.minX, y: model.cardRect.minY)
                        .transition(.scale(scale: 0.9, anchor: cardAnchor).combined(with: .opacity))
                }

                NotchStack(model: model, store: store, style: settings.notchStyle, now: context.date)
                    .frame(width: model.collapsedRect.width, height: model.collapsedRect.height)
                    .offset(x: model.collapsedRect.minX, y: model.collapsedRect.minY)
            }
            .frame(width: model.windowSize.width, height: model.windowSize.height, alignment: .topLeading)
            .background(alignment: .topLeading) { measurement(now: context.date) }
        }
        .animation(.spring(duration: 0.3, bounce: 0.15), value: model.isExpanded)
        .animation(.spring(duration: 0.3, bounce: 0.1), value: model.cardRect)
        .animation(.spring(duration: 0.25), value: model.collapsedRect)
        .environment(\.colorScheme, .dark)
    }

    /// The card grows out of the side facing the notch.
    private var cardAnchor: UnitPoint {
        switch model.edge {
        case .top: .top
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    /// Hidden copy of the card content that reports its natural height.
    private func measurement(now: Date) -> some View {
        BuildCard(model: model, store: store, settings: settings, openSettings: openSettings, now: now)
            .frame(width: NotchMetrics.cardWidth)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.isMeasuring, true)
            .hidden()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                if abs(model.contentHeight - height) > 0.5 { model.contentHeight = height }
            }
    }
}

// MARK: - Notch

/// Notch body hugging a screen edge, with concave flares where it meets the edge.
struct NotchShape: Shape {
    var edge: ScreenEdge
    var flare: CGFloat = NotchMetrics.flare
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        // Draw as if hanging from the top edge in (along, across) space, then map.
        let along = edge.isHorizontal ? rect.width : rect.height
        let across = edge.isHorizontal ? rect.height : rect.width
        let f = min(flare, across / 2)
        let r = max(0, min(radius, (along - 2 * f) / 2, across - f))

        func point(_ a: CGFloat, _ c: CGFloat) -> CGPoint {
            switch edge {
            case .top: CGPoint(x: rect.minX + a, y: rect.minY + c)
            case .bottom: CGPoint(x: rect.minX + a, y: rect.maxY - c)
            case .left: CGPoint(x: rect.minX + c, y: rect.minY + a)
            case .right: CGPoint(x: rect.maxX - c, y: rect.minY + a)
            }
        }

        var path = Path()
        path.move(to: point(0, 0))
        path.addQuadCurve(to: point(f, f), control: point(f, 0))
        path.addLine(to: point(f, across - r))
        path.addQuadCurve(to: point(f + r, across), control: point(f, across))
        path.addLine(to: point(along - f - r, across))
        path.addQuadCurve(to: point(along - f, across - r), control: point(along - f, across))
        path.addLine(to: point(along - f, f))
        path.addQuadCurve(to: point(along, 0), control: point(along - f, 0))
        path.closeSubpath()
        return path
    }
}

private struct NotchStack: View {
    let model: NotchModel
    let store: BuildStore
    let style: NotchStyle
    let now: Date

    /// Gap between the notch contents and the physical screen edge.
    private static let edgeInset: CGFloat = 2

    var body: some View {
        let shape = NotchShape(edge: model.edge, radius: model.edge.isHorizontal ? 12 : 18)
        stack
            .padding(model.edge.isHorizontal ? .horizontal : .vertical, NotchMetrics.flare + NotchMetrics.stackPadding)
            .padding(edgeSide, Self.edgeInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NotchSurface(style: style, shape: shape))
            .overlay(shape.stroke(.white.opacity(model.isGrabbing ? 0.6 : 0), lineWidth: 1.5))
            .contentShape(shape)
    }

    private var items: [PipelineItem] {
        Array(store.pipelineItems.prefix(NotchMetrics.maxItems))
    }

    private var edgeSide: Edge.Set {
        switch model.edge {
        case .top: .top
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    @ViewBuilder
    private var stack: some View {
        if items.isEmpty {
            Image(systemName: "shippingbox")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        } else if model.edge.isHorizontal {
            HStack(spacing: 0) {
                if let gap = model.hardwareNotchWidth {
                    let split = (items.count + 1) / 2
                    row(items.prefix(split))
                    Spacer(minLength: gap)
                    row(items.dropFirst(split))
                } else {
                    row(items[...])
                }
            }
        } else {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    StackItem(item: item, now: now, vertical: true)
                        .frame(height: NotchMetrics.verticalItemLength)
                }
            }
        }
    }

    private func row(_ slice: ArraySlice<PipelineItem>) -> some View {
        HStack(spacing: 0) {
            ForEach(slice) { item in
                StackItem(item: item, now: now, vertical: false)
                    .frame(width: NotchMetrics.horizontalItemLength)
            }
        }
    }
}

/// One pipeline in the collapsed stack: progress ring plus a short caption.
private struct StackItem: View {
    let item: PipelineItem
    let now: Date
    let vertical: Bool

    var body: some View {
        let ring = PipelineRing(item: item, diameter: vertical ? 32 : 20, lineWidth: vertical ? 3 : 2.5)
        let caption = Text(caption)
            .font(.system(size: vertical ? 11 : 10.5, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

        Group {
            if vertical {
                VStack(spacing: 4) { ring; caption }
            } else {
                HStack(spacing: 5) { ring; caption }
            }
        }
        .help(item.name)
    }

    private var caption: String {
        guard let build = item.build else { return "–" }
        if build.state.isActive { return build.duration(at: now).map(formatClock) ?? "fila" }
        guard let date = build.lastActivity else { return "–" }
        return compactAge(now.timeIntervalSince(date))
    }
}

private struct PipelineRing: View {
    let item: PipelineItem
    let diameter: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        let glyph = item.build.map { Glyph($0.state) } ?? .idle
        ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: item.build?.progressFraction ?? 0)
                .stroke(glyph.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if glyph.isActive {
                Spinner(color: .white.opacity(0.7), length: 0.12, lineWidth: lineWidth)
            }
            Text(initials(of: item.name))
                .font(.system(size: diameter * 0.32, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: diameter, height: diameter)
    }
}

extension Build {
    /// Jobs done while running; a full bar once the build settled.
    var progressFraction: CGFloat {
        guard state.isActive else { return 1 }
        let (finished, total) = jobProgress
        return total == 0 ? 0 : CGFloat(finished) / CGFloat(total)
    }
}

func initials(of name: String) -> String {
    let words = name.split { !$0.isLetter && !$0.isNumber }
    let letters = words.count >= 2
        ? words.prefix(2).compactMap(\.first).map(String.init).joined()
        : String(words.first?.prefix(2) ?? "?")
    return letters.uppercased()
}

func compactAge(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval))
    switch seconds {
    case ..<60: return "agora"
    case ..<3600: return "\(seconds / 60)m"
    case ..<86_400: return "\(seconds / 3600)h"
    default: return "\(seconds / 86_400)d"
    }
}

/// "há 13 min" style, matching the compact captions.
func relativeAge(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval))
    switch seconds {
    case ..<60: return "agora"
    case ..<3600: return "há \(seconds / 60) min"
    case ..<86_400: return "há \(seconds / 3600) h"
    default: return "há \(seconds / 86_400) d"
    }
}

func formatClock(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval))
    if seconds >= 3600 { return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}

// MARK: - Card

/// Fixed text colors: hierarchical styles turn too faint over glass on light wallpapers.
private enum Palette {
    static let secondary = Color.white.opacity(0.72)
    static let tertiary = Color.white.opacity(0.55)
}

private struct CardBackground: View {
    static let radius: CGFloat = 18
    let style: NotchStyle

    var body: some View {
        NotchSurface(style: style, shape: RoundedRectangle(cornerRadius: Self.radius, style: .continuous), isCard: true)
    }
}

private struct BuildCard: View {
    let model: NotchModel
    let store: BuildStore
    let settings: AppSettings
    let openSettings: () -> Void
    let now: Date

    private static let maxRecent = 4

    var body: some View {
        let recent = store.recentBuilds.prefix(Self.maxRecent)

        VStack(alignment: .leading, spacing: 12) {
            header
            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }
            if !settings.isConfigured {
                EmptyState(
                    icon: "key.fill",
                    message: settings.token.isEmpty ? "Conecte sua conta Buildkite" : "Escolha os pipelines para acompanhar",
                    action: ("Abrir Preferências", openSettings)
                )
            } else {
                ForEach(store.pipelineItems) { item in
                    PipelineSection(item: item, now: now)
                }
                if !recent.isEmpty {
                    Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
                    VStack(spacing: 10) {
                        ForEach(recent) { build in
                            RecentRow(build: build, now: now)
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.green)
            Text("Buildkite")
                .font(.system(size: 17, weight: .bold))
            if !settings.organizationName.isEmpty {
                Text(settings.organizationName)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if store.isRefreshing {
                ProgressView().controlSize(.mini)
            }
            IconButton(systemImage: "arrow.clockwise", help: "Atualizar", action: store.refreshNow)
            IconButton(systemImage: "gearshape", help: "Preferências", action: openSettings)
        }
    }
}

private struct PipelineSection: View {
    let item: PipelineItem
    let now: Date
    @State private var hovering = false

    var body: some View {
        let glyph = item.build.map { Glyph($0.state) } ?? .idle
        Button {
            if let url = item.build?.url { NSWorkspace.shared.open(url) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(trailing)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                }
                ProgressBar(fraction: item.build?.progressFraction ?? 0, color: glyph.color)
                HStack(spacing: 6) {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(glyph.label)
                        .font(.system(size: 11))
                        .foregroundStyle(glyph == .idle ? Palette.secondary : glyph.color)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(hovering ? 0.06 : 0)))
            .padding(-6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(item.build?.title ?? item.name)
    }

    private var trailing: String {
        guard let build = item.build else { return "" }
        if build.state.isActive {
            return "#\(build.number) · \(build.duration(at: now).map(formatClock) ?? "na fila")"
        }
        guard let date = build.lastActivity else { return "#\(build.number)" }
        return "#\(build.number) · \(relativeAge(now.timeIntervalSince(date)))"
    }

    private var detail: String {
        guard let build = item.build else { return "Sem builds recentes" }
        let (finished, total) = build.jobProgress
        var parts: [String] = []
        if total > 0 { parts.append("\(finished)/\(total) jobs") }
        if let branch = build.branch { parts.append(branch) }
        parts.append(build.title)
        return parts.joined(separator: " · ")
    }
}

private struct ProgressBar: View {
    let fraction: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                if fraction > 0 {
                    Capsule().fill(color)
                        .frame(width: max(proxy.size.width * min(fraction, 1), 6))
                }
            }
        }
        .frame(height: 5)
    }
}

private struct RecentRow: View {
    let build: Build
    let now: Date
    @State private var hovering = false

    var body: some View {
        let glyph = Glyph(build.state)
        Button {
            if let url = build.url { NSWorkspace.shared.open(url) }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(build.pipeline?.name ?? "Pipeline") #\(build.number)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Text([build.branch, build.creator?.name].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        StatusGlyph(glyph: glyph, size: 9)
                        Text(glyph.label)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
                    Text(age)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Palette.tertiary)
                }
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(hovering ? 0.06 : 0)))
            .padding(-5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(build.title)
    }

    private var age: String {
        if build.state.isActive { return build.duration(at: now).map(formatClock) ?? "" }
        guard let date = build.lastActivity else { return "" }
        return compactAge(now.timeIntervalSince(date))
    }
}

private struct IconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(hovering ? 0.15 : 0)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.8))
        .onHover { hovering = $0 }
        .help(help)
    }
}

private struct EmptyState: View {
    let icon: String
    let message: String
    let action: (String, () -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(Palette.secondary)
            Text(message).font(.callout).foregroundStyle(Palette.secondary)
            if let action {
                Button(action.0, action: action.1).controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
