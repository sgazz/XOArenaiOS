//
//  SGToolbarStyle.swift
//  XOArena
//

import SwiftUI

struct SGToolbarStyleModifier: ViewModifier {
    @Environment(\.sgThemeMode) private var themeMode

    func body(content: Content) -> some View {
        let barFill = themeMode == .dark ? SGColors.paperDark : SGColors.paperBackgroundLight
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
