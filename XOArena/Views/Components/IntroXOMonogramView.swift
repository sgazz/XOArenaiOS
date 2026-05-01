//
//  IntroXOMonogramView.swift
//  XOArena
//

import SwiftUI

/// Renders the hand-ink **`IntroXOMonogram`** asset like the quiet paper mockup.
struct IntroXOMonogramView: View {
    @Environment(\.sgThemeMode) private var themeMode
    /// Target cap height (~mockup prominence); scales with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var maxLogoHeight: CGFloat = 148

    var body: some View {
        logo
            .frame(maxHeight: maxLogoHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var logo: some View {
        Image("IntroXOMonogram")
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .shadow(color: .black.opacity(themeMode == .light ? 0.05 : 0.22), radius: 10, x: 0, y: 5)
            .modifier(IntroMonogramWarmMultiply(themeMode: themeMode))
    }
}

/// Keeps sepia ink readable on warm light paper; softly lifts pigment on dark intro paper.
private struct IntroMonogramWarmMultiply: ViewModifier {
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
