//
//  SGToolbarStyle.swift
//  XOArena
//

import SwiftUI

struct SGToolbarStyleModifier: ViewModifier {
    @Environment(\.sgThemeMode) private var themeMode

    func body(content: Content) -> some View {
        let barFill: Color = {
            switch themeMode {
            case .light: return SGColors.paperBackgroundLight
            case .dark: return SGColors.paperDark
            case .neonPulse: return SGColors.neonGraphite
            }
        }()
        content
            .toolbarBackground(barFill, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(XOTheme.tokens(for: themeMode).navigationBarScheme, for: .navigationBar)
    }
}

extension View {
    func sgToolbarStyle() -> some View {
        modifier(SGToolbarStyleModifier())
    }
}
