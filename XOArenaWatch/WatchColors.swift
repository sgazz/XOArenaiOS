//
//  WatchColors.swift
//  XOArenaWatch — aliases to SG Quiet Watch tokens (backward compatible names).
//

import SwiftUI

enum WatchColors {
    static var paper: Color { WatchQuietTheme.ColorToken.background }
    static var cell: Color { WatchQuietTheme.ColorToken.surface }
    static var border: Color { WatchQuietTheme.ColorToken.border }
    static var accent: Color { WatchQuietTheme.ColorToken.primary }
    static var ink: Color { WatchQuietTheme.ColorToken.textMain }
    static var inkMuted: Color { WatchQuietTheme.ColorToken.textSoft }
    static var win: Color { WatchQuietTheme.ColorToken.win }
    static var lose: Color { WatchQuietTheme.ColorToken.lose }
    static var drawAccent: Color { WatchQuietTheme.ColorToken.draw }
}
