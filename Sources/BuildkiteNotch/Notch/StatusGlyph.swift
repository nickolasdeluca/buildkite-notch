import BuildkiteNotchCore
import SwiftUI

enum Glyph: Equatable {
    case idle, scheduled, running, failing, passed, failed, blocked, canceled

    init(_ state: BuildState) {
        self = switch state {
        case .creating, .scheduled: .scheduled
        case .running, .canceling: .running
        case .failing: .failing
        case .passed: .passed
        case .failed: .failed
        case .blocked: .blocked
        case .canceled, .skipped, .notRun, .unknown: .canceled
        }
    }

    init(_ status: NotchStatus) {
        self = switch status {
        case .idle: .idle
        case .running(_, let failing): failing ? .failing : .running
        case .blocked: .blocked
        case .passed: .passed
        case .failed: .failed
        case .canceled: .canceled
        }
    }

    var color: Color {
        switch self {
        case .idle, .scheduled, .canceled: Color(white: 0.72)
        case .running: .yellow
        case .failing: .orange
        case .passed: .green
        case .failed: .red
        case .blocked: .purple
        }
    }
}

extension EnvironmentValues {
    /// True inside the hidden copy used to measure layout; stops animations there.
    @Entry var isMeasuring = false
}

struct StatusGlyph: View {
    let glyph: Glyph
    var size: CGFloat = 14

    var body: some View {
        Group {
            switch glyph {
            case .running, .failing: Spinner(color: glyph.color).padding(1)
            case .idle: Image(systemName: "shippingbox").resizable().foregroundStyle(.white.opacity(0.45))
            case .scheduled: Image(systemName: "circle.dotted").resizable().foregroundStyle(glyph.color)
            case .passed: Image(systemName: "checkmark.circle.fill").resizable().foregroundStyle(glyph.color)
            case .failed: Image(systemName: "xmark.circle.fill").resizable().foregroundStyle(glyph.color)
            case .blocked: Image(systemName: "pause.circle.fill").resizable().foregroundStyle(glyph.color)
            case .canceled: Image(systemName: "slash.circle").resizable().foregroundStyle(glyph.color)
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
    }
}

/// Rotating arc; `length` is the fraction of the circle drawn.
struct Spinner: View {
    let color: Color
    var length: CGFloat = 0.7
    var lineWidth: CGFloat = 2
    @Environment(\.isMeasuring) private var isMeasuring

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: isMeasuring)) { context in
            let turns = context.date.timeIntervalSinceReferenceDate / 0.9
            Circle()
                .trim(from: 0, to: length)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(turns.truncatingRemainder(dividingBy: 1) * 360))
        }
    }
}

extension Glyph {
    var label: String {
        switch self {
        case .idle: "ocioso"
        case .scheduled: "na fila"
        case .running: "rodando"
        case .failing: "falhando"
        case .passed: "passou"
        case .failed: "falhou"
        case .blocked: "aguardando"
        case .canceled: "cancelado"
        }
    }

    var isActive: Bool { self == .running || self == .failing || self == .scheduled }
}
