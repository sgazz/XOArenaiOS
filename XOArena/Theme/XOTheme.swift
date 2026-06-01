//
//  XOTheme.swift
//  XOArena
//

import SwiftUI

/// Semantic colors per appearance; views read `XOTheme.tokens(for: themeMode)`.
enum XOTheme {
    struct Tokens {
        let backgroundDeep: Color
        let surface: Color
        let surfaceMuted: Color
        let textPrimary: Color
        let textSecondary: Color
        let gridLine: Color
        let accent: Color
        let accentSubtle: Color
        let border: Color
        let primaryButtonLabel: Color
        let secondaryButtonFill: Color
        let secondaryButtonLabel: Color
        let secondaryButtonBorder: Color
        let shadowCalm: Color
        let shadowCalmRadius: CGFloat
        let navigationBarScheme: ColorScheme
    }

    static func tokens(for mode: SGThemeMode) -> Tokens {
        switch mode {
        case .light:
            return Tokens(
                backgroundDeep: SGColors.paperBackgroundLight,
                surface: SGColors.paperSurfaceLight,
                surfaceMuted: SGColors.paperBackgroundLight.opacity(0.88),
                textPrimary: SGColors.inkPrimaryLight,
                textSecondary: SGColors.inkSecondaryLight,
                gridLine: SGColors.inkPrimaryLight.opacity(0.44),
                accent: SGColors.accentLightMuted,
                accentSubtle: SGColors.accentSubtleLight,
                border: SGColors.borderLightWarm,
                primaryButtonLabel: SGColors.paperSurfaceLight,
                secondaryButtonFill: SGColors.paperSurfaceLight.opacity(0.72),
                secondaryButtonLabel: SGColors.inkPrimaryLight,
                secondaryButtonBorder: SGColors.borderLightWarm.opacity(0.95),
                shadowCalm: SGColors.inkPrimaryLight.opacity(0.10),
                shadowCalmRadius: 8,
                navigationBarScheme: .light
            )
        case .dark:
            return Tokens(
                backgroundDeep: SGColors.paperDark,
                surface: SGColors.surfaceDark,
                surfaceMuted: SGColors.surfaceDark.opacity(0.8),
                textPrimary: SGColors.textDark,
                textSecondary: SGColors.textSecondary,
                gridLine: SGColors.borderDark.opacity(0.8),
                accent: SGColors.accent,
                accentSubtle: SGColors.accentSubtle,
                border: SGColors.borderDark,
                primaryButtonLabel: SGColors.textDark,
                secondaryButtonFill: SGColors.surfaceDark,
                secondaryButtonLabel: SGColors.textDark,
                secondaryButtonBorder: SGColors.borderDark,
                shadowCalm: SGShadows.calm,
                shadowCalmRadius: SGShadows.calmRadius,
                navigationBarScheme: .dark
            )
        case .neonPulse:
            return Tokens(
                backgroundDeep: SGColors.neonGraphite,
                surface: SGColors.neonSurfaceGlass,
                surfaceMuted: SGColors.neonGraphite.opacity(0.92),
                textPrimary: SGColors.neonTextPrimary,
                textSecondary: SGColors.neonTextSecondary,
                gridLine: SGColors.neonCyanGrid,
                accent: SGColors.neonAccent,
                accentSubtle: SGColors.neonAccentSubtle,
                border: SGColors.neonBorder,
                primaryButtonLabel: SGColors.neonTextPrimary,
                secondaryButtonFill: SGColors.neonSurfaceGlass,
                secondaryButtonLabel: SGColors.neonTextPrimary,
                secondaryButtonBorder: SGColors.neonBorder,
                shadowCalm: SGColors.neonCyan.opacity(0.18),
                shadowCalmRadius: 10,
                navigationBarScheme: .dark
            )
        }
    }
}
