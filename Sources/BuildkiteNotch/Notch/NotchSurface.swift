import AppKit
import SwiftUI

/// Background of the notch and the card, drawn in the user's chosen style.
struct NotchSurface<S: Shape>: View {
    let style: NotchStyle
    let shape: S
    /// The card sits over arbitrary content, so it gets a denser fill than the notch.
    var isCard = false

    var body: some View {
        switch style {
        case .solidBlack:
            shape.fill(isCard ? Color(white: 0.1) : .black)
                .overlay(shape.stroke(.white.opacity(isCard ? 0.09 : 0), lineWidth: 1))
        case .darkGlass:
            glass(dimming: isCard ? 0.6 : 0.55)
        case .liquidGlass:
            glass(dimming: isCard ? 0.22 : 0.08)
        }
    }

    /// Glass plus a black layer; `glassEffect`'s own tint barely darkens, so dimming is drawn on top.
    @ViewBuilder
    private func glass(dimming: Double) -> some View {
        if #available(macOS 26, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
                .overlay(shape.fill(.black.opacity(dimming)))
        } else {
            BehindWindowBlur()
                .overlay(Color.black.opacity(dimming))
                .clipShape(shape)
                .overlay(shape.stroke(.white.opacity(0.15), lineWidth: 1))
        }
    }
}

/// Blurs whatever is behind the (transparent) window; SwiftUI materials only blur within it.
private struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
