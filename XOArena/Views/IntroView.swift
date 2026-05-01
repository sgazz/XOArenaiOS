//
//  IntroView.swift
//  XOArena
//

import SwiftUI
import UIKit

/// Cappuccino papir — uvod ostaje dok korisnik ne tapne. **`MainMenuView`** tek posle **`onFinish`**.
struct IntroView: View {
    @Environment(\.sgThemeMode) private var themeMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("showIntro") private var showIntroOnLaunch: Bool = true

    let onFinish: () -> Void

    @State private var markVisible = false
    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var hintVisible = false
    @State private var isExiting = false
    @State private var exitStarted = false

    private var backgroundColor: Color {
        themeMode == .light ? SGColors.introPaperCappuccino : SGColors.introPaperDark
    }

    private var introSerifTitleFont: Font {
        let m = UIFontMetrics(forTextStyle: .title1)
        let size = m.scaledValue(for: 32)
        return .system(size: size, weight: .medium, design: .serif)
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            IntroPaperGrainOverlay()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                mainTappableRegion
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        finishIntro()
                    }

                /// Izvan ovog expandable regiona — tap menja samo **`showIntro`**, ne poziva **`onFinish`**.
                IntroQuietShowIntroCheckbox(isOn: $showIntroOnLaunch)
                    .zIndex(1)
                    .padding(.leading, SGSpacing.md)
                    .padding(.trailing, SGSpacing.lg)
                    .padding(.bottom, SGSpacing.lg + dynamicTypePadding)
            }
            .scaleEffect(isExiting ? 1.02 : 1.0, anchor: .center)
            .opacity(isExiting ? 0 : 1)
        }
        .onAppear {
            runEntranceAnimations()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.default) {
            finishIntro()
        }
        .accessibilityHint(introAccessibilityHint)
    }

    /// Dodatni donji padding kod većih Dynamic Type — checkbox ostaje dosežan bez preklapanja.
    private var dynamicTypePadding: CGFloat {
        switch dynamicTypeSize {
        case .accessibility1: return 4
        case .accessibility2: return 8
        case .accessibility3, .accessibility4, .accessibility5: return 14
        default: return 0
        }
    }

    private var introAccessibilityHint: String {
        "Dvostrukim dodirom iznad kontrole za prikaz uvoda prelazite u glavni meni. Donja kontrola samo uključuje ili isključuje uvod pri sledećem pokretanju."
    }

    private var mainTappableRegion: some View {
        VStack(spacing: 0) {
            Spacer(minLength: SGSpacing.sm)

            VStack(spacing: SGSpacing.md) {
                IntroXOMonogramView()
                    .opacity(markVisible ? 1 : 0)

                Text("XOArena")
                    .font(introSerifTitleFont)
                    .foregroundStyle(SGColors.introTextPrimary.opacity(themeMode == .light ? 1 : 0.94))
                    .tracking(SGTypography.titleTracking + 0.5)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)
                    .lineLimit(1)
                    .opacity(titleVisible ? 1 : 0)

                Text("Eight boards. One focus.")
                    .font(SGTypography.body)
                    .foregroundStyle(SGColors.introTextSecondary.opacity(themeMode == .light ? 0.62 : 0.58))
                    .tracking(SGTypography.subtitleTracking)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)
                    .lineLimit(subtitleDynamicLineLimit)
                    .opacity(subtitleVisible ? 1 : 0)
            }
            .padding(.horizontal, SGSpacing.xl)

            Spacer(minLength: SGSpacing.md)

            introHintPhrase
                .multilineTextAlignment(.center)
                .opacity(hintVisible ? 1 : 0)

            Spacer(minLength: SGSpacing.sm)
        }
    }

    private var subtitleDynamicLineLimit: Int {
        switch dynamicTypeSize {
        case .xLarge, .xxLarge, .xxxLarge,
             .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return 3
        default:
            return 2
        }
    }

    private var introHintPhrase: some View {
        ViewThatFits(in: .horizontal) {
            Text("Make your first move")
                .font(SGTypography.small)
                .foregroundStyle(SGColors.introTextSecondary.opacity(0.48))
                .tracking(0.35)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("Begin")
                .font(SGTypography.small)
                .foregroundStyle(SGColors.introTextSecondary.opacity(0.48))
                .tracking(0.35)
        }
    }

    private func runEntranceAnimations() {
        markVisible = false
        titleVisible = false
        subtitleVisible = false
        hintVisible = false

        withAnimation(.easeOut(duration: 0.38)) {
            markVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.easeOut(duration: 0.42)) {
                titleVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeOut(duration: 0.42)) {
                subtitleVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            withAnimation(.easeOut(duration: 0.46)) {
                hintVisible = true
            }
        }
    }

    private func finishIntro() {
        guard !exitStarted else { return }
        exitStarted = true
        HapticService.lightImpact()
        withAnimation(.easeInOut(duration: 0.28)) {
            isExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onFinish()
        }
    }
}
