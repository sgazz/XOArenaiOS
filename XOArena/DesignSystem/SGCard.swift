//
//  SGCard.swift
//  XOArena
//

import SwiftUI

// Boje moraju biti van generičkog `SGCard` — unutrašnji tip ne sme imati `static let` skladišta.
private enum SGCardStoneLight {
    static let paper = Color(red: 243 / 255, green: 237 / 255, blue: 230 / 255)
    static let surface = Color(red: 232 / 255, green: 222 / 255, blue: 210 / 255)
    static let shadow = Color(red: 205 / 255, green: 191 / 255, blue: 175 / 255)
    static let ink = Color(red: 43 / 255, green: 38 / 255, blue: 34 / 255)
}

/// Tabla kao blago urezan „stone slab“ u cappuccino tonovima (samo **CompactBoardGrid** u ovom projektu).
struct SGCard<Content: View>: View {
    @Environment(\.sgThemeMode) private var themeMode

    var isActive: Bool = false
    var borderTone: CGFloat = 1
    @ViewBuilder var content: () -> Content

    private var paperFill: Color {
        switch themeMode {
        case .light:
            if isActive {
                return SGCardStoneLight.surface.opacity(0.97)
            }
            return SGCardStoneLight.paper
        case .dark:
            if isActive {
                return SGColors.surfaceLight.opacity(0.078)
            }
            return SGColors.surfaceLight.opacity(0.056)
        }
    }

    private var borderColor: Color {
        let tone = min(max(borderTone, 0.75), 1.25)
        switch themeMode {
        case .light:
            let base = isActive ? 0.32 : 0.2
            return SGCardStoneLight.ink.opacity(min(1, base * tone))
        case .dark:
            if isActive {
                return SGColors.borderDark.opacity(min(1, 0.4 * tone))
            }
            return SGColors.borderDark.opacity(min(1, 0.28 * tone))
        }
    }

    private var slabShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        switch themeMode {
        case .light:
            return (
                SGCardStoneLight.shadow.opacity(isActive ? 0.24 : 0.14),
                isActive ? 3.2 : 2,
                1
            )
        case .dark:
            return (
                Color.black.opacity(isActive ? 0.22 : 0.12),
                isActive ? 4 : 2.5,
                1.2
            )
        }
    }

    var body: some View {
        content()
            .padding(SGSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: SGRadius.lg, style: .continuous)
                    .fill(paperFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SGRadius.lg, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isActive ? 0.52 : 0.38)
            )
            .shadow(color: slabShadow.color, radius: slabShadow.radius, x: 0, y: slabShadow.y)
    }
}
