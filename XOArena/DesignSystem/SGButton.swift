//
//  SGButton.swift
//  XOArena
//

import SwiftUI

enum SGButtonVariant {
    case primary
    case secondary
}

struct SGButton: View {
    @Environment(\.sgThemeMode) private var themeMode

    let title: String
    var variant: SGButtonVariant = .primary
    var isEnabled: Bool = true
    var action: () -> Void

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        switch variant {
        case .primary:
            Button(action: action) {
                chromeLabel
            }
            .buttonStyle(HandInkRoundedRippleButtonStyle(cornerRadius: SGRadius.md))
            .disabled(!isEnabled)

        case .secondary:
            Button(action: action) {
                chromeLabel
            }
            .buttonStyle(PlainSecondaryInkStyle(themeMode: themeMode))
            .disabled(!isEnabled)
        }
    }

    @ViewBuilder
    private var chromeLabel: some View {
        Text(title)
            .font(SGTypography.body)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: return t.accent
        case .secondary: return t.secondaryButtonFill
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return t.primaryButtonLabel
        case .secondary: return t.secondaryButtonLabel
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary: return t.accentSubtle.opacity(themeMode == .light ? 0.45 : 0.5)
        case .secondary: return t.secondaryButtonBorder
        }
    }
}

/// Sekundarni **`SGButton`** — blagi mastiljni pritisak.
private struct PlainSecondaryInkStyle: ButtonStyle {
    let themeMode: SGThemeMode

    func makeBody(configuration: Configuration) -> some View {
        let core = themeMode == .light
            ? SGColors.inkPrimaryLight.opacity(0.14)
            : Color.white.opacity(0.1)
        return configuration.label
            .overlay {
                RadialGradient(colors: [core, core.opacity(0)], center: .center, startRadius: 0, endRadius: 96)
                    .blendMode(themeMode == .light ? .multiply : .overlay)
                    .scaleEffect(configuration.isPressed ? 1.35 : 0.25)
                    .opacity(configuration.isPressed ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: configuration.isPressed)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.28), value: configuration.isPressed)
    }
}
