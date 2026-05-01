//
//  SGCard.swift
//  XOArena
//

import SwiftUI

/// Paper slip presence: active boards feel materially closer (light: cappuccino; dark: ink).
struct SGCard<Content: View>: View {
    @Environment(\.sgThemeMode) private var themeMode

    var isActive: Bool = false
    /// Multiplier for tonal contrast on neutral ink frame (deterministic drift).
    var borderTone: CGFloat = 1
    @ViewBuilder var content: () -> Content

    private var paperFill: Color {
        switch themeMode {
        case .light:
            if isActive {
                return SGColors.paperSurfaceActiveLight.opacity(0.96)
            }
            return SGColors.paperSurfaceLight.opacity(0.93)
        case .dark:
            if isActive {
                return SGColors.surfaceLight.opacity(0.074)
            }
            return SGColors.surfaceLight.opacity(0.055)
        }
    }

    private var borderColor: Color {
        let tone = min(max(borderTone, 0.75), 1.25)
        switch themeMode {
        case .light:
            let base = isActive ? 0.54 : 0.4
            return SGColors.borderLightWarm.opacity(min(1, base * CGFloat(tone)))
        case .dark:
            if isActive {
                return SGColors.borderDark.opacity(min(1, 0.46 * tone))
            }
            return SGColors.borderDark.opacity(min(1, 0.34 * tone))
        }
    }

    private var underlineColor: Color {
        switch themeMode {
        case .light:
            return SGColors.accentLightMuted.opacity(0.42)
        case .dark:
            return SGColors.accent.opacity(0.22)
        }
    }

    private var cardShadowColor: Color {
        switch themeMode {
        case .light:
            return SGColors.vignetteWarm.opacity(isActive ? 0.16 : 0.09)
        case .dark:
            return Color.black.opacity(isActive ? 0.44 : 0.21)
        }
    }

    private var underlineAccent: Bool { isActive }

    var body: some View {
        content()
            .padding(SGSpacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: SGRadius.lg, style: .continuous)
                    .fill(paperFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SGRadius.lg, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isActive ? (themeMode == .light ? 0.55 : 0.7) : (themeMode == .light ? 0.48 : 0.55))
            )
            .overlay(alignment: .bottom) {
                if underlineAccent {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(underlineColor)
                        .frame(height: 2)
                        .padding(.horizontal, SGSpacing.sm + SGSpacing.sm)
                        .padding(.bottom, SGSpacing.sm)
                        .allowsHitTesting(false)
                }
            }
            .shadow(
                color: cardShadowColor,
                radius: isActive ? (themeMode == .light ? 8 : 11) : (themeMode == .light ? 4 : 5),
                x: 0,
                y: isActive ? (themeMode == .light ? 2 : 3) : 2
            )
    }
}
