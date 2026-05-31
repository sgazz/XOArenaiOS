//
//  MainMenuView.swift
//  XOArena
//

import SwiftUI
import UIKit

// MARK: - Adaptive menu typography (geometry + clamp; Dynamic Type via UIFontMetrics)

private enum MainMenuPlayFocus: Equatable {
    case pvAI
    case pvp
}

private enum MainMenuDurationOptions {
    static let pvAI: [GameDuration] = [.thirtySeconds, .oneMinute, .threeMinutes, .fiveMinutes]
    static let pvp: [GameDuration] = [.oneMinute, .threeMinutes, .fiveMinutes]
}

private struct MainMenuLayoutMetrics: Sendable {
    var titleBase: CGFloat
    var subtitleBase: CGFloat
    var pvaiBase: CGFloat
    var pvpBase: CGFloat
    var auxiliaryBase: CGFloat
    var pvaiToPvpSpacing: CGFloat
    var timerGroupSpacing: CGFloat

    static func resolve(bounds: CGSize, dynamicTypeSize: DynamicTypeSize) -> MainMenuLayoutMetrics {
        let w = bounds.width
        let h = bounds.height
        guard w > 8, h > 8 else { return .compactFallback }

        let short = min(w, h)
        let long = max(w, h)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let isLargePhone = !isPad && short >= 390
        let isPadCompact = isPad && long < 900

        var title: CGFloat = isPad ? 40 : (isLargePhone ? 34 : 31)
        if isPadCompact { title -= 2 }
        title += min(8, max(0, short - 320) * 0.022)
        title = title.clamped(to: isPad ? (32 ... 48) : (28 ... 40))

        var subtitle: CGFloat = isPad ? 19.5 : (isLargePhone ? 18 : 17)
        subtitle = subtitle.clamped(to: isPad ? (16.5 ... 23) : (15 ... 20.5))

        var pvai: CGFloat = isPad ? 28 : (isLargePhone ? 25 : 23)
        pvai = pvai.clamped(to: isPad ? (22 ... 32) : (20 ... 28))

        var pvp: CGFloat = pvai - 2
        pvp = pvp.clamped(to: isPad ? (20 ... 30) : (18 ... 26))

        var aux: CGFloat = isPad ? 15.5 : 13.5
        aux = aux.clamped(to: isPad ? (13 ... 18) : (12 ... 16))

        var gapPv = CGFloat(30)
        gapPv = gapPv.clamped(to: isPad ? (26 ... 38) : (24 ... 34))

        var gapTimer = short * 0.068
        gapTimer = gapTimer.clamped(to: isPad ? (22 ... 34) : (14 ... 28))

        var m = MainMenuLayoutMetrics(
            titleBase: title,
            subtitleBase: subtitle,
            pvaiBase: pvai,
            pvpBase: pvp,
            auxiliaryBase: aux,
            pvaiToPvpSpacing: gapPv,
            timerGroupSpacing: gapTimer
        )
        m.applyDynamicTypeTweak(dynamicTypeSize)
        return m
    }

    private static var compactFallback: MainMenuLayoutMetrics {
        MainMenuLayoutMetrics(
            titleBase: 30,
            subtitleBase: 16.5,
            pvaiBase: 22,
            pvpBase: 20,
            auxiliaryBase: 13,
            pvaiToPvpSpacing: 28,
            timerGroupSpacing: 18
        )
    }

    private mutating func applyDynamicTypeTweak(_ d: DynamicTypeSize) {
        switch d {
        case .xLarge, .xxLarge, .xxxLarge:
            titleBase += 1.5
            subtitleBase += 0.75
            pvaiBase += 1
            pvpBase += 1
            auxiliaryBase += 0.5
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            timerGroupSpacing = max(12, timerGroupSpacing * 0.92)
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

/// Tekst bez pozadina: aktivan tus + ugraviranje; neaktivan smanjena čitljivost.
private struct DifficultyTextModifier: ViewModifier {
    @Environment(\.sgThemeMode) private var themeMode

    var isActive: Bool
    var activeFont: Font
    var inactiveFont: Font

    private var ink: Color {
        SGEngravedTextTheme.defaultInk(for: themeMode)
    }

    func body(content: Content) -> some View {
        Group {
            if isActive {
                content
                    .font(activeFont)
                    .foregroundStyle(ink)
                    .sgEngravedText(intensity: .medium, color: ink)
            } else {
                content
                    .font(inactiveFont)
                    .foregroundStyle(ink)
                    .opacity(0.5)
            }
        }
    }
}

// MARK: - Stone surface (gradijent, bez tekstura)

private enum MenuStoneChrome {
    static let carveInkLight = SGEngravedTextTheme.lightInk
    static let textSoft = Color(red: 107 / 255, green: 99 / 255, blue: 92 / 255)

    static func titleInk(_ mode: SGThemeMode) -> Color {
        mode == .light ? carveInkLight : SGEngravedTextTheme.darkInk
    }

    static func taglineSoft(_ mode: SGThemeMode) -> Color {
        mode == .light ? textSoft : Color(red: 140 / 255, green: 132 / 255, blue: 124 / 255)
    }

    static var gradientLight: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 245 / 255, green: 239 / 255, blue: 232 / 255),
                Color(red: 228 / 255, green: 217 / 255, blue: 203 / 255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var gradientDark: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 52 / 255, green: 47 / 255, blue: 42 / 255),
                Color(red: 28 / 255, green: 25 / 255, blue: 22 / 255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Mode picker and session duration — main entry after optional launch intro.
///
/// Napomena: **`GameMode`** i callback‑ovi ostaju u potpisu (**`ContentView`**) i logici; pojednostavljeni glavni UI prikazuje samo **PvAI** i **PvP**.
struct MainMenuView: View {
    @Environment(\.sgThemeMode) private var themeMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedDuration: GameDuration
    @Binding var aiDifficulty: AIDifficulty

    /// Samo vizuelni hint (poslednja sesija iz **`GameViewModel`**): **`localDuel`** → sakrivanje AI težine.
    let menuPlayModeBias: GameMode

    @State private var menuPlayFocus: MainMenuPlayFocus = .pvAI

    let onPractice: (GameDuration) -> Void
    let onVsAI: () -> Void
    let onLearning: (GameDuration) -> Void
    let onLocalDuel: (GameDuration) -> Void
    var onAiVsAITest: ((GameDuration) -> Void)? = nil

    private func menuTitleFont(base: CGFloat) -> Font {
        let m = UIFontMetrics(forTextStyle: .largeTitle)
        let size = m.scaledValue(for: base)
        return .system(size: size, weight: .semibold, design: .serif)
    }

    private func menuSubtitleFont(base: CGFloat) -> Font {
        let m = UIFontMetrics(forTextStyle: .title3)
        let size = m.scaledValue(for: base)
        return .system(size: size, weight: .regular, design: .rounded)
    }

    private func menuModeFont(base: CGFloat) -> Font {
        let m = UIFontMetrics(forTextStyle: .title3)
        let size = m.scaledValue(for: base)
        return .system(size: size, weight: .regular, design: .rounded)
    }

    /// Težina AI + trajanje sesije (**`UIFontMetrics.footnote`** skaliran **`auxiliaryBase`**).
    private func menuFootnoteFonts(base: CGFloat) -> (selected: Font, unselected: Font) {
        let m = UIFontMetrics(forTextStyle: .footnote)
        let size = m.scaledValue(for: base)
        return (
            .system(size: size, weight: .semibold, design: .rounded),
            .system(size: size, weight: .regular, design: .rounded)
        )
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = MainMenuLayoutMetrics.resolve(bounds: geo.size, dynamicTypeSize: dynamicTypeSize)
            let footerFonts = menuFootnoteFonts(base: metrics.auxiliaryBase)
            let nudgeAboveCenter = -geo.size.height * 0.045
            ZStack {
                (themeMode == .light ? MenuStoneChrome.gradientLight : MenuStoneChrome.gradientDark)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 0) {
                        titleTaglineCluster(metrics: metrics)

                        HStack(alignment: .center, spacing: SGSpacing.md) {
                            pvaiPrimaryButton(metrics: metrics)
                                .frame(maxWidth: .infinity)
                            pvpTextButton(metrics: metrics)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, SGSpacing.xl)

                        if menuPlayFocus == .pvAI {
                            aiDifficultyPicker(metrics: metrics, selected: footerFonts.selected, unselected: footerFonts.unselected)
                                .padding(.top, CGFloat(16))
                        }

                        durationTextPicker(
                            metrics: metrics,
                            timerSelected: footerFonts.selected,
                            timerUnselected: footerFonts.unselected
                        )
                        .padding(.top, menuPlayFocus == .pvAI ? CGFloat(20) : metrics.pvaiToPvpSpacing)

                        startPrimaryButton(metrics: metrics)
                            .padding(.top, SGSpacing.xl)
                    }
                    .padding(.horizontal, SGSpacing.xl)
                    .offset(y: nudgeAboveCenter)

                    Spacer(minLength: 0)
                }
                .onAppear {
                    applyMenuFocusFromBias()
                    syncDurationForSelectedMode()
                }
                .onChange(of: menuPlayModeBias) { _, _ in
                    applyMenuFocusFromBias()
                    syncDurationForSelectedMode()
                }
                .accessibilityElement(children: .contain)
                .accessibilityHint("Choose PvAI or PvP, set options, then tap Start.")
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func titleTaglineCluster(metrics: MainMenuLayoutMetrics) -> some View {
        VStack(spacing: SGSpacing.xl + SGSpacing.sm) {
            Text("XOArena")
                .font(menuTitleFont(base: metrics.titleBase))
                .foregroundStyle(MenuStoneChrome.titleInk(themeMode))
                .tracking(SGTypography.titleTracking)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
                .lineLimit(2)

            Text("Eight boards. One focus.")
                .font(menuSubtitleFont(base: metrics.subtitleBase))
                .foregroundStyle(MenuStoneChrome.taglineSoft(themeMode).opacity(0.6))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.78)
                .lineLimit(3)
                .tracking(SGTypography.subtitleTracking)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SGSpacing.xxl + SGSpacing.sm)
        .accessibilityElement(children: .contain)
    }

    private func aiDifficultyPicker(metrics _: MainMenuLayoutMetrics, selected: Font, unselected: Font) -> some View {
        HStack(spacing: SGSpacing.lg) {
            ForEach(AIDifficulty.allCases, id: \.self) { level in
                let isPick = aiDifficulty == level
                Button {
                    HapticService.lightImpact()
                    aiDifficulty = level
                } label: {
                    Text(difficultyDisplayTitle(level))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .modifier(DifficultyTextModifier(isActive: isPick, activeFont: selected, inactiveFont: unselected))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("AI difficulty")
        .accessibilityValue(aiDifficulty.rawValue.capitalized)
    }

    private func difficultyDisplayTitle(_ level: AIDifficulty) -> String {
        level.rawValue.capitalized
    }

    private func applyMenuFocusFromBias() {
        menuPlayFocus = menuPlayModeBias == .localDuel ? .pvp : .pvAI
    }

    private var activeMenuDurations: [GameDuration] {
        menuPlayFocus == .pvAI ? MainMenuDurationOptions.pvAI : MainMenuDurationOptions.pvp
    }

    private func syncDurationForSelectedMode() {
        let allowed = activeMenuDurations
        guard !allowed.contains(selectedDuration) else { return }
        selectedDuration = allowed[0]
    }

    private func pvaiPrimaryButton(metrics: MainMenuLayoutMetrics) -> some View {
        modeSelectorButton(title: "PvAI", focus: .pvAI, metrics: metrics)
    }

    private func pvpTextButton(metrics: MainMenuLayoutMetrics) -> some View {
        modeSelectorButton(title: "PvP", focus: .pvp, metrics: metrics)
    }

    private func modeSelectorButton(title: String, focus: MainMenuPlayFocus, metrics: MainMenuLayoutMetrics) -> some View {
        Button {
            HapticService.lightImpact()
            menuPlayFocus = focus
            syncDurationForSelectedMode()
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(MenuModeSelectorStyle(isSelected: menuPlayFocus == focus, font: menuModeFont(base: metrics.pvaiBase)))
        .accessibilityAddTraits(menuPlayFocus == focus ? .isSelected : [])
    }

    private func startPrimaryButton(metrics: MainMenuLayoutMetrics) -> some View {
        Button {
            HapticService.mediumImpact()
            launchSelectedMode()
        } label: {
            Text("Start")
                .font(.system(size: metrics.pvaiBase, weight: .semibold, design: .rounded))
                .foregroundStyle(XOTheme.tokens(for: themeMode).primaryButtonLabel)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                        .fill(XOTheme.tokens(for: themeMode).accent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                        .strokeBorder(XOTheme.tokens(for: themeMode).accentSubtle.opacity(themeMode == .light ? 0.45 : 0.5), lineWidth: 1)
                )
        }
        .buttonStyle(MenuStartPressStyle())
        .accessibilityLabel("Start")
        .accessibilityHint(menuPlayFocus == .pvAI ? "Starts a PvAI match." : "Starts a local PvP match.")
    }

    private func launchSelectedMode() {
        switch menuPlayFocus {
        case .pvAI:
            onVsAI()
        case .pvp:
            onLocalDuel(selectedDuration)
        }
    }

    private func durationTextPicker(metrics: MainMenuLayoutMetrics, timerSelected: Font, timerUnselected: Font) -> some View {
        HStack(spacing: metrics.timerGroupSpacing) {
            ForEach(activeMenuDurations, id: \.self) { duration in
                Button {
                    selectedDuration = duration
                } label: {
                    Text(duration.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .buttonStyle(
                    SGEngravedTextButtonStyle(
                        variant: .timerOption(isSelected: selectedDuration == duration),
                        timerFontSelected: timerSelected,
                        timerFontUnselected: timerUnselected,
                        primaryInk: SGEngravedTextTheme.defaultInk(for: themeMode)
                    )
                )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(menuPlayFocus == .pvAI ? "PvAI match duration" : "Session duration")
        .accessibilityValue(selectedDuration.title)
    }
}

// MARK: - Mode selector + Start press styles

private struct MenuModeSelectorStyle: ButtonStyle {
    @Environment(\.sgThemeMode) private var themeMode

    var isSelected: Bool
    var font: Font

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    private var ink: Color {
        SGEngravedTextTheme.defaultInk(for: themeMode)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(ink.opacity(isSelected ? 0.96 : 0.52))
            .background(
                RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                    .fill(isSelected ? t.surface.opacity(themeMode == .light ? 0.72 : 0.38) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                    .strokeBorder(
                        isSelected ? t.accentSubtle.opacity(themeMode == .light ? 0.55 : 0.45) : t.border.opacity(0.35),
                        lineWidth: 1
                    )
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct MenuStartPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
