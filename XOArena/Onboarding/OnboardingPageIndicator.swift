//
//  OnboardingPageIndicator.swift
//  XOArena
//

import SwiftUI

struct OnboardingPageIndicator: View {
    @Environment(\.sgThemeMode) private var themeMode

    let pageCount: Int
    let currentIndex: Int

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        HStack(spacing: SGSpacing.sm) {
            ForEach(0 ..< pageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? t.accent : t.border.opacity(themeMode == .light ? 0.55 : 0.45))
                    .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
                    .animation(.easeInOut(duration: 0.22), value: currentIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentIndex + 1) of \(pageCount)")
    }
}
