//
//  SGColors.swift
//  XOArena
//

import SwiftUI

enum SGColors {
    static let paperLight = Color(hex: 0xF8F5EE)
    static let paperDark = Color(hex: 0x232220)

    // MARK: Cappuccino / paper — light palette (semantic tokens for warm UI)
    /// Warm paper slab base.
    static let paperBackgroundLight = Color(hex: 0xF4EBDD)
    /// Slightly lighter card surface (not pure white).
    static let paperSurfaceLight = Color(hex: 0xFFF8EE)
    /// Active board sits a hair closer to espresso paper.
    static let paperSurfaceActiveLight = Color(hex: 0xF0E6D8)
    static let inkPrimaryLight = Color(hex: 0x2B2926)
    static let inkSecondaryLight = Color(hex: 0x7A7067)
    static let borderLightWarm = Color(hex: 0xD8C8B8)
    static let accentLightMuted = Color(hex: 0x8F5BC8)
    static let accentSubtleLight = Color(hex: 0xD8B7F5)
    /// Vignette / edge wash on light paper (muted umber — not harsh black).
    static let vignetteWarm = Color(hex: 0x5C4334)

    // MARK: Launch intro (cappuccino — solid, no gradients)
    static let introPaperCappuccino = Color(hex: 0xF3EDE4)
    /// Warm ink paper for intro in dark mode (not pure black).
    static let introPaperDark = Color(hex: 0x23201E)
    static let introTextPrimary = Color(hex: 0x2C2825)
    static let introTextSecondary = Color(hex: 0x5C534C)
    static let introRule = Color(hex: 0x5C534C)

    static let surfaceLight = Color(hex: 0xFFFFFF)
    static let surfaceDark = Color(hex: 0x2C2C2C)
    static let textLight = Color(hex: 0x1C1C1C)
    static let textDark = Color(hex: 0xF5F5F5)
    static let textSecondary = Color(hex: 0x8A8A8A)
    static let accent = Color(hex: 0x9D42F0)
    static let accentSubtle = Color(hex: 0xCFA8FF)
    static let borderLight = Color(hex: 0xE5E5E5)
    static let borderDark = Color(hex: 0x3A3A3A)
}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
