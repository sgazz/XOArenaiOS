//
//  WatchColors.swift
//  XOArenaWatch
//

import SwiftUI

enum WatchColors {
    static let paper = Color(hex: 0xF4EBDD)
    static let cell = Color(hex: 0xFFF8EE)
    static let ink = Color(hex: 0x2B2926)
    static let inkMuted = Color(hex: 0x7A7067)
    static let border = Color(hex: 0xD8C8B8)
    static let accent = Color(hex: 0x6B5344)
}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
