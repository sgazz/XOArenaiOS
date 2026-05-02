//
//  XOArenaLogoView.swift
//  XOArena
//

import SwiftUI

/// Hand-ink **XO** mark from asset catalog — shared by intro, marketing, and app icon compositions.
struct XOArenaLogoView: View {
    enum Style: Sendable {
        /// Intro splash: respects theme, Dynamic Type via **`introMaxLogoHeight`**.
        case intro
        /// Launcher artwork: forced **`.light`** ink treatment; premium-soft shadow depth.
        case appIcon
    }

    @Environment(\.sgThemeMode) private var themeMode

    var style: Style = .intro

    /// Only used when **`style == .intro`** (**`ScaledMetric`**).
    @ScaledMetric(relativeTo: .largeTitle) private var introMaxLogoHeight: CGFloat = 148

    private var inkTheme: SGThemeMode {
        switch style {
        case .intro: themeMode
        case .appIcon: .light
        }
    }

    var body: some View {
        let mark =
            Image("IntroXOMonogram")
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .modifier(MonogramSepiaInk(themeMode: inkTheme))

        Group {
            switch style {
            case .intro:
                mark
                    .shadow(color: .black.opacity(themeMode == .light ? 0.05 : 0.22), radius: 10, x: 0, y: 5)
                    .frame(maxHeight: introMaxLogoHeight)

            case .appIcon:
                mark
                    .shadow(color: Color.black.opacity(0.036), radius: 12, x: 0, y: 3)
                    .shadow(color: Color.black.opacity(0.022), radius: 26, x: 0, y: 9)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Dark paper lifts sepia pigments; light path leaves asset hues intact (**Infinity Paper–adjacent warmth**).
struct MonogramSepiaInk: ViewModifier {
    let themeMode: SGThemeMode

    func body(content: Content) -> some View {
        switch themeMode {
        case .light:
            content
        case .dark:
            content
                .colorMultiply(Color(red: 0.90, green: 0.86, blue: 0.80))
                .opacity(0.94)
        }
    }
}
