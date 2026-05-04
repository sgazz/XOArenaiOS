//
//  WatchQuietTheme.swift
//  XOArenaWatch — SG Quiet System (Watch Edition)
//

import SwiftUI

/// Design tokens: color, type, layout (Watch-only).
enum WatchQuietTheme {
    enum ColorToken {
        static let background = Color(hex: 0xF3EDE6)
        static let surface = Color(hex: 0xE8DFD4)
        static let border = Color(hex: 0xC9B8A3)
        static let primary = Color(hex: 0x7A5C45)
        static let textMain = Color(hex: 0x2B2B2B)
        static let textSoft = Color(hex: 0x7A7A7A)
        static let win = Color(hex: 0x6F9D7A)
        static let lose = Color(hex: 0xA06A6A)
        static let draw = Color(hex: 0x9A8F7A)
    }

    enum Typography {
        static let hero = Font.system(size: 17, weight: .semibold)
        /// Compact slab tag in hero row (**“B3”**) — bolder than timer/score.
        static let heroBoardLabel = Font.system(size: 17, weight: .bold)
        static let score = Font.system(size: 13, weight: .medium)
        static let secondary = Font.system(size: 11, weight: .regular)
        static let label = Font.system(size: 12, weight: .medium)
        static let setupPill = Font.system(size: 13, weight: .semibold)
        static let endTitle = Font.system(size: 18, weight: .semibold)
        /// End-screen score token (`0 : 0`) — calm emphasis.
        static let endScore = Font.system(size: 13, weight: .semibold)
        /// End-screen duration — same optical size as score, softened by color.
        static let endDuration = Font.system(size: 13, weight: .medium)
        static let endBody = Font.system(size: 13, weight: .regular)
    }
}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
