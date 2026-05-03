//
//  IntroView.swift
//  XOArena
//

import SwiftUI
import UIKit

// MARK: - Intro layout (geometry + clamp; fonts still follow Dynamic Type via UIFontMetrics)

private struct IntroLayoutMetrics: Sendable {
    var titleBase: CGFloat
    var subtitleBase: CGFloat
    var hintBase: CGFloat
    var checkboxLabelBase: CGFloat
    var checkboxSide: CGFloat
    var headlineStackSpacing: CGFloat

    static func resolve(bounds: CGSize, dynamicTypeSize: DynamicTypeSize) -> IntroLayoutMetrics {
        let w = bounds.width
        let h = bounds.height
        guard w > 8, h > 8 else { return .compactPhoneFallback }

        let short = min(w, h)
        let long = max(w, h)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let isLargePhone = !isPad && short >= 390
        let isPadCompact = isPad && long < 900

        var title: CGFloat = isPad ? 44 : (isLargePhone ? 40 : 36)
        if isPadCompact { title -= 2 }
        title += min(10, max(0, short - 320) * 0.028)
        title = title.clamped(to: isPad ? (34 ... 50) : (30 ... 44))

        var subtitle: CGFloat = isPad ? 20.5 : (isLargePhone ? 18.5 : 17)
        subtitle = subtitle.clamped(to: isPad ? (17 ... 23) : (15.5 ... 20.5))

        var hint: CGFloat = isPad ? 17.5 : 15.5
        hint = hint.clamped(to: isPad ? (15 ... 20) : (13.5 ... 18))

        let cbLabel: CGFloat = isPad ? 13.5 : 11.5
        let cbSide: CGFloat = isPad ? 20 : 18

        let stackGap: CGFloat = isPad ? SGSpacing.lg : SGSpacing.md

        var metrics = IntroLayoutMetrics(
            titleBase: title,
            subtitleBase: subtitle,
            hintBase: hint,
            checkboxLabelBase: cbLabel,
            checkboxSide: cbSide,
            headlineStackSpacing: stackGap
        )
        metrics.applyDynamicTypeTweak(dynamicTypeSize)
        return metrics
    }

    private static var compactPhoneFallback: IntroLayoutMetrics {
        IntroLayoutMetrics(
            titleBase: 34,
            subtitleBase: 16.5,
            hintBase: 14.5,
            checkboxLabelBase: 11.5,
            checkboxSide: 18,
            headlineStackSpacing: SGSpacing.md
        )
    }

    private mutating func applyDynamicTypeTweak(_ d: DynamicTypeSize) {
        switch d {
        case .xLarge, .xxLarge, .xxxLarge:
            titleBase += 1.5
            subtitleBase += 0.75
            hintBase += 0.5
            checkboxLabelBase += 0.5
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            headlineStackSpacing = min(headlineStackSpacing + SGSpacing.sm, SGSpacing.xl)
        default:
            break
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

/// Cappuccino papir — uvod ostaje dok korisnik ne tapne. **`MainMenuView`** tek posle **`onFinish`**.
struct IntroView: View {
    @Environment(\.sgThemeMode) private var themeMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("showIntro") private var showIntroOnLaunch: Bool = true

    let onFinish: () -> Void

    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var hintVisible = false
    @State private var isExiting = false
    @State private var exitStarted = false

    private func introTitleFont(base: CGFloat) -> Font {
        let m = UIFontMetrics(forTextStyle: .largeTitle)
        let size = m.scaledValue(for: base)
        return .system(size: size, weight: .medium, design: .serif)
    }

    private func introSubtitleFont(base: CGFloat) -> Font {
        let m = UIFontMetrics(forTextStyle: .title3)
        let size = m.scaledValue(for: base)
        return .system(size: size, weight: .regular, design: .rounded)
    }

    private func introHintFont(base: CGFloat) -> Font {
        let m = UIFontMetrics(forTextStyle: .callout)
        let size = m.scaledValue(for: base)
        return .system(size: size, weight: .regular, design: .rounded)
    }

    private var titleInk: Color {
        themeMode == .light ? SGColors.introSerifTitleLight : SGColors.introSerifTitleDark
    }

    /// Lagani vertikalni preliv (SG Quiet — bez jakih gradijenata).
    private var introBackground: some View {
        Group {
            if themeMode == .light {
                LinearGradient(
                    colors: [SGColors.introGradientTopLight, SGColors.introGradientBottomLight],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [SGColors.introGradientTopDark, SGColors.introGradientBottomDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = IntroLayoutMetrics.resolve(bounds: geo.size, dynamicTypeSize: dynamicTypeSize)
            ZStack {
                introBackground

                IntroPaperGrainOverlay(opacityMultiplier: 0.42)

                VStack(spacing: 0) {
                    mainTappableRegion(metrics: metrics)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            finishIntro()
                        }

                    /// Izvan ovog expandable regiona — tap menja samo **`showIntro`**, ne poziva **`onFinish`**.
                    IntroQuietShowIntroCheckbox(
                        isOn: $showIntroOnLaunch,
                        labelSizeBase: metrics.checkboxLabelBase,
                        checkboxSide: metrics.checkboxSide
                    )
                    .zIndex(1)
                    .padding(.leading, SGSpacing.md)
                    .padding(.trailing, SGSpacing.lg)
                    .padding(.top, SGSpacing.sm)
                    .padding(.bottom, SGSpacing.xxl + SGSpacing.sm + dynamicTypePadding)
                }
                .scaleEffect(isExiting ? 1.02 : 1.0, anchor: .center)
                .opacity(isExiting ? 0 : 1)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
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

    @ViewBuilder
    private func mainTappableRegion(metrics: IntroLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: SGSpacing.sm)

            VStack(spacing: metrics.headlineStackSpacing) {
                Text("XOArena")
                    .font(introTitleFont(base: metrics.titleBase))
                    .foregroundStyle(titleInk)
                    .tracking(SGTypography.titleTracking + 4)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                    .sgRaisedText(intensity: .medium, color: titleInk)
                    .opacity(titleVisible ? 1 : 0)

                Text("Eight boards. One focus.")
                    .font(introSubtitleFont(base: metrics.subtitleBase))
                    .foregroundStyle(SGColors.introTextSecondary)
                    .tracking(SGTypography.subtitleTracking + 0.2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)
                    .lineLimit(subtitleDynamicLineLimit)
                    .sgEngravedText(intensity: .low, color: SGColors.introTextSecondary)
                    .opacity(subtitleVisible ? 1 : 0)
            }
            .padding(.horizontal, SGSpacing.xl)

            Spacer(minLength: SGSpacing.sm)

            introHintPhrase(metrics: metrics)
                .multilineTextAlignment(.center)
                .opacity(hintVisible ? 1 : 0)
                .padding(.bottom, SGSpacing.sm)

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

    @ViewBuilder
    private func introHintPhrase(metrics: IntroLayoutMetrics) -> some View {
        ViewThatFits(in: .horizontal) {
            Text("Make your first move")
                .font(introHintFont(base: metrics.hintBase))
                .foregroundStyle(SGColors.introTextSecondary.opacity(0.55))
                .tracking(0.45)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .sgEngravedText(intensity: .low, color: SGColors.introTextSecondary.opacity(0.55))
            Text("Begin")
                .font(introHintFont(base: metrics.hintBase))
                .foregroundStyle(SGColors.introTextSecondary.opacity(0.55))
                .tracking(0.45)
                .sgEngravedText(intensity: .low, color: SGColors.introTextSecondary.opacity(0.55))
        }
    }

    private func runEntranceAnimations() {
        titleVisible = false
        subtitleVisible = false
        hintVisible = false

        withAnimation(.easeOut(duration: 0.38)) {
            titleVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.easeOut(duration: 0.42)) {
                subtitleVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
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
