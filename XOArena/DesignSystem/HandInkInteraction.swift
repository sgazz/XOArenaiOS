//
//  HandInkInteraction.swift
//  XOArena
//
//  Mekani radial „mastiljni“ puls na tap (**~0.3–0.36 s**).

import SwiftUI

/// Primarni ljubičasti / teski ton dugmeta sa zaobljenim ivicama (**PvAI**, **`SGButton` primary**, itd.).
struct HandInkRoundedRippleButtonStyle: ButtonStyle {
    @Environment(\.sgThemeMode) private var themeMode

    /// Krug zasečenja ripple‑a (**`continuous`** kao papir kartica).
    var cornerRadius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        let core = themeMode == .light
            ? SGColors.inkPrimaryLight.opacity(0.28)
            : Color.white.opacity(0.2)

        return configuration.label
            .overlay {
                RadialGradient(
                    colors: [core, core.opacity(0)],
                    center: .center,
                    startRadius: 2,
                    endRadius: 120
                )
                .blendMode(themeMode == .light ? .multiply : .overlay)
                .scaleEffect(configuration.isPressed ? 1.55 : 0.35)
                .opacity(configuration.isPressed ? 1 : 0)
                .animation(.easeOut(duration: 0.34), value: configuration.isPressed)
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.34), value: configuration.isPressed)
    }
}

/// Tekstualni sekundarni link (`PvP`).
struct HandInkRippleTextLinkStyle: ButtonStyle {
    @Environment(\.sgThemeMode) private var themeMode

    func makeBody(configuration: Configuration) -> some View {
        let core = themeMode == .light
            ? SGColors.inkPrimaryLight.opacity(0.19)
            : Color.white.opacity(0.14)

        return configuration.label
            .overlay {
                RadialGradient(
                    colors: [core, core.opacity(0)],
                    center: .center,
                    startRadius: 1,
                    endRadius: 100
                )
                .blendMode(themeMode == .light ? .multiply : .overlay)
                .scaleEffect(configuration.isPressed ? 1.45 : 0.28)
                .opacity(configuration.isPressed ? 1 : 0)
                .animation(.easeOut(duration: 0.32), value: configuration.isPressed)
                .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.58 : 1)
            .animation(.easeInOut(duration: 0.3), value: configuration.isPressed)
    }
}

/// Ćelijska tabla — mastiljni diskretan talas (**multiply** na papiru).
struct HandInkRippleBoardCellStyle: ButtonStyle {
    @Environment(\.sgThemeMode) private var themeMode

    func makeBody(configuration: Configuration) -> some View {
        let core = themeMode == .light
            ? SGColors.inkPrimaryLight.opacity(0.24)
            : Color.white.opacity(0.17)

        return configuration.label
            .overlay {
                RadialGradient(
                    colors: [core, core.opacity(0)],
                    center: .center,
                    startRadius: 1,
                    endRadius: 90
                )
                .blendMode(themeMode == .light ? .multiply : .overlay)
                .scaleEffect(configuration.isPressed ? 1.5 : 0.3)
                .opacity(configuration.isPressed ? 1 : 0)
                .animation(.easeOut(duration: 0.36), value: configuration.isPressed)
                .allowsHitTesting(false)
            }
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.34), value: configuration.isPressed)
    }
}
