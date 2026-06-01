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
    static let pvp: [GameDuration] = [.noTime, .thirtySeconds, .oneMinute, .threeMinutes, .fiveMinutes]
}

private enum MainMenuMatchCopy {
    static func description(focus: MainMenuPlayFocus, duration: GameDuration) -> String {
        switch focus {
        case .pvAI:
            return "Challenge the AI across eight active boards."
        case .pvp:
            if duration == .noTime {
                return "Classic duel. No timers. Pure strategy."
            }
            return "Fast survival duel. Win boards to gain time."
        }
    }
}

private extension GameDuration {
    var mainMenuChipLabel: String {
        switch self {
        case .thirtySeconds: return "30s"
        case .oneMinute: return "1m"
        case .threeMinutes: return "3m"
        case .fiveMinutes: return "5m"
        case .noTime: return "No Time"
        }
    }
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
        switch mode {
        case .light: return carveInkLight
        case .dark: return SGEngravedTextTheme.darkInk
        case .neonPulse: return SGColors.neonTextPrimary
        }
    }

    static func taglineSoft(_ mode: SGThemeMode) -> Color {
        switch mode {
        case .light: return textSoft
        case .dark: return Color(red: 140 / 255, green: 132 / 255, blue: 124 / 255)
        case .neonPulse: return SGColors.neonTextSecondary
        }
    }

    @ViewBuilder
    static func menuBackground(_ mode: SGThemeMode) -> some View {
        switch mode {
        case .light:
            gradientLight
        case .dark:
            gradientDark
        case .neonPulse:
            LinearGradient(
                colors: [SGColors.neonGraphite, SGColors.neonGraphiteDeep],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @EnvironmentObject private var themeManager: SGThemeManager
    @AppStorage(SplashExperienceStorage.showSettingKey) private var showSplashExperience = false
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
    var onShowHelp: (() -> Void)? = nil

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
            ZStack {
                MenuStoneChrome.menuBackground(themeMode)
                MainMenuAmbientBackground()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: SGSpacing.xl + SGSpacing.sm) {
                        titleTaglineCluster(metrics: metrics)

                        matchSetupCard(
                            metrics: metrics,
                            footerFonts: footerFonts,
                            maxWidth: Self.resolvedMatchSetupCardMaxWidth(containerWidth: geo.size.width)
                        )
                    }
                    .padding(.horizontal, SGSpacing.lg)
                    .frame(maxWidth: .infinity)

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
                .onChange(of: menuPlayFocus) { _, _ in
                    syncDurationForSelectedMode()
                }
                .accessibilityElement(children: .contain)
                .accessibilityHint("Choose mode and time, then tap Start Match.")
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Help") {
                    HapticService.lightImpact()
                    onShowHelp?()
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(MenuStoneChrome.taglineSoft(themeMode).opacity(0.88))
                .accessibilityLabel("Help")
                .accessibilityHint("Opens the gameplay tutorial.")
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: SGSpacing.sm) {
                    Menu {
                        Toggle("Show Splash Experience", isOn: $showSplashExperience)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(MenuStoneChrome.taglineSoft(themeMode).opacity(0.88))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("More options")
                    .accessibilityHint("Includes Show Splash Experience on launch.")

                    SGThemeToggleControl()
                }
            }
        }
    }

    private func titleTaglineCluster(metrics: MainMenuLayoutMetrics) -> some View {
        VStack(spacing: SGSpacing.md) {
            Text("XOArena")
                .font(menuTitleFont(base: metrics.titleBase))
                .foregroundStyle(MenuStoneChrome.titleInk(themeMode))
                .tracking(SGTypography.titleTracking)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
                .lineLimit(2)

            Text("Eight boards. One focus.")
                .font(menuSubtitleFont(base: metrics.subtitleBase))
                .foregroundStyle(MenuStoneChrome.taglineSoft(themeMode).opacity(0.62))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.78)
                .lineLimit(3)
                .tracking(SGTypography.subtitleTracking)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SGSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("XOArena. Eight boards. One focus.")
    }

    /// Avoids invalid **`frame(maxWidth:)`** when **`GeometryReader`** reports zero width on first layout pass.
    private static func resolvedMatchSetupCardMaxWidth(containerWidth: CGFloat) -> CGFloat {
        guard containerWidth.isFinite, containerWidth > 0 else { return 360 }
        let inset = SGSpacing.lg * 2
        let available = containerWidth - inset
        guard available.isFinite, available > 0 else { return min(360, containerWidth) }
        return min(max(available, 200), 400)
    }

    private func matchSetupCard(
        metrics: MainMenuLayoutMetrics,
        footerFonts: (selected: Font, unselected: Font),
        maxWidth: CGFloat
    ) -> some View {
        let safeMaxWidth = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 360
        let t = XOTheme.tokens(for: themeMode)
        let description = MainMenuMatchCopy.description(focus: menuPlayFocus, duration: selectedDuration)

        return VStack(alignment: .leading, spacing: SGSpacing.lg) {
            menuSectionLabel("Mode")
            HStack(spacing: SGSpacing.sm) {
                modeSelectorButton(title: "PvAI", focus: .pvAI, metrics: metrics)
                modeSelectorButton(title: "PvP", focus: .pvp, metrics: metrics)
            }

            if menuPlayFocus == .pvAI {
                menuSectionLabel("AI Difficulty")
                    .padding(.top, SGSpacing.xs)
                aiDifficultyPicker(
                    metrics: metrics,
                    selected: footerFonts.selected,
                    unselected: footerFonts.unselected
                )
            }

            timeControlSection(metrics: metrics)
                .padding(.top, menuPlayFocus == .pvAI ? SGSpacing.sm : 0)

            Text(description)
                .font(.system(size: metrics.auxiliaryBase + 0.5, weight: .regular, design: .rounded))
                .foregroundStyle(MenuStoneChrome.taglineSoft(themeMode).opacity(0.82))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
                .accessibilityLabel("Match description")
                .accessibilityValue(description)

            startPrimaryButton(metrics: metrics)
                .padding(.top, SGSpacing.xs)
        }
        .padding(SGSpacing.lg)
        .frame(maxWidth: safeMaxWidth)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SGRadius.lg, style: .continuous)
                .fill(t.surface.opacity(themeMode == .light ? 0.58 : 0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SGRadius.lg, style: .continuous)
                .strokeBorder(t.border.opacity(themeMode == .light ? 0.35 : 0.42), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(themeMode == .light ? 0.06 : 0.2),
            radius: themeMode == .light ? 10 : 14,
            y: 4
        )
        .accessibilityElement(children: .contain)
    }

    private func menuSectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(MenuStoneChrome.taglineSoft(themeMode).opacity(0.72))
            .tracking(0.6)
            .accessibilityAddTraits(.isHeader)
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
        .buttonStyle(MenuModeSelectorStyle(isSelected: menuPlayFocus == focus, font: menuModeFont(base: metrics.auxiliaryBase + 3)))
        .accessibilityAddTraits(menuPlayFocus == focus ? .isSelected : [])
    }

    private func startPrimaryButton(metrics: MainMenuLayoutMetrics) -> some View {
        let t = XOTheme.tokens(for: themeMode)
        return Button {
            HapticService.mediumImpact()
            launchSelectedMode()
        } label: {
            Text("Start Match")
                .font(.system(size: metrics.pvaiBase * 0.68, weight: .semibold, design: .rounded))
                .foregroundStyle(t.primaryButtonLabel)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                        .fill(t.accent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                        .strokeBorder(t.accentSubtle.opacity(themeMode == .light ? 0.5 : 0.55), lineWidth: 1)
                )
                .shadow(color: t.accent.opacity(themeMode == .light ? 0.22 : 0.35), radius: 8, y: 3)
        }
        .buttonStyle(MenuStartPressStyle())
        .accessibilityLabel("Start Match")
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

    private func timeControlFonts(base: CGFloat) -> (selected: Font, unselected: Font) {
        let metrics = UIFontMetrics(forTextStyle: .callout)
        return (
            .system(size: metrics.scaledValue(for: base + 3), weight: .semibold, design: .rounded),
            .system(size: metrics.scaledValue(for: base + 1.5), weight: .medium, design: .rounded)
        )
    }

    private func timeControlSection(metrics: MainMenuLayoutMetrics) -> some View {
        let fonts = timeControlFonts(base: metrics.auxiliaryBase)
        let durations = activeMenuDurations
        let rows = timeControlPillRows(for: durations)

        return VStack(spacing: SGSpacing.md) {
            Text("Time Control")
                .font(.system(size: metrics.auxiliaryBase + 3, weight: .semibold, design: .rounded))
                .foregroundStyle(MenuStoneChrome.titleInk(themeMode).opacity(0.92))
                .tracking(0.15)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: SGSpacing.sm) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: SGSpacing.sm) {
                        ForEach(row, id: \.self) { duration in
                            timeControlPill(
                                duration,
                                selectedFont: fonts.selected,
                                unselectedFont: fonts.unselected
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .animation(
                timeControlSelectionAnimation,
                value: selectedDuration
            )
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(menuPlayFocus == .pvAI ? "PvAI time control" : "PvP time control")
        .accessibilityValue(selectedDuration.pickerTitle)
    }

    private var timeControlSelectionAnimation: Animation? {
        accessibilityReduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)
    }

    /// Centered rows: four durations on one line; five (PvP) split 3 + 2.
    private func timeControlPillRows(for durations: [GameDuration]) -> [[GameDuration]] {
        guard durations.count == 5 else { return [durations] }
        return [Array(durations.prefix(3)), Array(durations.suffix(2))]
    }

    private func timeControlPill(
        _ duration: GameDuration,
        selectedFont: Font,
        unselectedFont: Font
    ) -> some View {
        let isSelected = selectedDuration == duration
        return Button {
            HapticService.lightImpact()
            selectedDuration = duration
        } label: {
            timeControlPillLabel(
                duration,
                font: isSelected ? selectedFont : unselectedFont,
                isSelected: isSelected
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, duration == .noTime ? SGSpacing.md : SGSpacing.md + 2)
            .frame(minWidth: duration == .noTime ? 96 : 54)
            .frame(height: 46)
            .contentShape(Capsule())
        }
        .buttonStyle(
            MainMenuTimeControlPillStyle(
                isSelected: isSelected,
                themeMode: themeMode,
                reduceMotion: accessibilityReduceMotion
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func timeControlPillLabel(_ duration: GameDuration, font: Font, isSelected: Bool) -> some View {
        let ink = SGEngravedTextTheme.defaultInk(for: themeMode)
        let opacity: CGFloat = isSelected ? 0.98 : 0.58
        if duration == .noTime {
            HStack(spacing: 4) {
                Text("∞")
                    .font(font)
                Text("No Time")
                    .font(font)
            }
            .foregroundStyle(ink.opacity(opacity))
        } else {
            Text(duration.mainMenuChipLabel)
                .font(font)
                .foregroundStyle(ink.opacity(opacity))
        }
    }
}

// MARK: - Time control pill

private struct MainMenuTimeControlPillStyle: ButtonStyle {
    var isSelected: Bool
    var themeMode: SGThemeMode
    var reduceMotion: Bool

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(pillFill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(pillBorder, lineWidth: isSelected ? 1.25 : 1)
            }
            .shadow(
                color: isSelected ? t.accent.opacity(themeMode == .light ? 0.2 : 0.32) : .clear,
                radius: isSelected ? 7 : 0,
                y: isSelected ? 2.5 : 0
            )
            .scaleEffect(selectionScale(isPressed: configuration.isPressed))
            .animation(pressAnimation, value: configuration.isPressed)
    }

    private var pillFill: Color {
        if isSelected {
            return t.accent.opacity(themeMode == .light ? 0.2 : 0.3)
        }
        return t.surface.opacity(themeMode == .light ? 0.5 : 0.28)
    }

    private var pillBorder: Color {
        if isSelected {
            return t.accent.opacity(themeMode == .light ? 0.62 : 0.72)
        }
        return t.border.opacity(themeMode == .light ? 0.38 : 0.45)
    }

    private func selectionScale(isPressed: Bool) -> CGFloat {
        if isPressed { return 0.97 }
        if isSelected { return reduceMotion ? 1 : 1.03 }
        return 1
    }

    private var pressAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.14)
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
