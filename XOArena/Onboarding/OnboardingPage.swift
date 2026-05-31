//
//  OnboardingPage.swift
//  XOArena
//

import SwiftUI

struct OnboardingPage: View {
    @Environment(\.sgThemeMode) private var themeMode

    let model: OnboardingPageModel

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        VStack(spacing: SGSpacing.lg) {
            VStack(spacing: SGSpacing.sm) {
                Text(model.title)
                    .font(SGTypography.mainTitle)
                    .foregroundStyle(t.textPrimary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)
                    .lineLimit(2)

                Text(model.subtitle)
                    .font(SGTypography.sectionTitle)
                    .foregroundStyle(t.textSecondary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)
                    .lineLimit(2)

                Text(model.description)
                    .font(SGTypography.body)
                    .foregroundStyle(t.textSecondary.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, SGSpacing.xs)
            }
            .padding(.horizontal, SGSpacing.lg)

            AnimatedBoardPreview(kind: model.visual)
                .frame(maxWidth: 520)
                .frame(height: onboardingVisualHeight)
                .padding(.horizontal, SGSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var onboardingVisualHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 260 : 210
    }
}
