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
        Button(action: action) {
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
        .buttonStyle(.plain)
        .disabled(!isEnabled)
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
