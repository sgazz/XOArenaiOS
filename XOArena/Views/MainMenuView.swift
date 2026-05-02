//
//  MainMenuView.swift
//  XOArena
//

import SwiftUI

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
    @Binding var selectedDuration: GameDuration

    let onPractice: (GameDuration) -> Void
    let onVsAI: (GameDuration) -> Void
    let onLearning: (GameDuration) -> Void
    let onLocalDuel: (GameDuration) -> Void
    var onAiVsAITest: ((GameDuration) -> Void)? = nil

    /// Semantic font — Dynamic Type uz veći utisak od PvP.
    private var pvaiButtonFont: Font {
        Font.system(.title3, design: .rounded).weight(.semibold)
    }
    private static let pvaiToPvpSpacing: CGFloat = 30
    private static let timerGroupSpacing: CGFloat = 26

    var body: some View {
        ZStack {
            (themeMode == .light ? MenuStoneChrome.gradientLight : MenuStoneChrome.gradientDark)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBlock
                    .padding(.bottom, SGSpacing.lg)

                Spacer(minLength: SGSpacing.md)

                VStack(alignment: .leading, spacing: 0) {
                    pvaiPrimaryButton

                    pvpTextButton
                        .padding(.top, Self.pvaiToPvpSpacing)

                    durationTextPicker
                        .padding(.top, SGSpacing.xl)
                }
                .padding(.horizontal, SGSpacing.xl)

                Spacer(minLength: SGSpacing.xxl)
            }
            .padding(.top, SGSpacing.lg + SGSpacing.sm)
            .accessibilityElement(children: .contain)
            .accessibilityHint("PvAI igra protiv veštačke inteligencije. PvP je lokalni duel dva igrača.")
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerBlock: some View {
        VStack(spacing: SGSpacing.xl + SGSpacing.sm) {
            Text("XOArena")
                .font(SGTypography.mainTitle)
                .fontWeight(.semibold)
                .foregroundStyle(MenuStoneChrome.titleInk(themeMode))
                .tracking(SGTypography.titleTracking)

            Text("Eight boards. One focus.")
                .font(SGTypography.body)
                .foregroundStyle(MenuStoneChrome.taglineSoft(themeMode).opacity(0.6))
                .multilineTextAlignment(.center)
                .tracking(SGTypography.subtitleTracking)
        }
        .padding(.horizontal, SGSpacing.xxl + SGSpacing.sm)
        .padding(.bottom, SGSpacing.sm)
        .accessibilityElement(children: .contain)
    }

    private var pvaiPrimaryButton: some View {
        Button {
            HapticService.lightImpact()
            onVsAI(selectedDuration)
        } label: {
            Text("PvAI")
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
        }
        .buttonStyle(
            SGEngravedTextButtonStyle(
                variant: .primary(engravedIntensity: .high),
                primaryFont: pvaiButtonFont,
                primaryInk: themeMode == .light ? MenuStoneChrome.carveInkLight : nil
            )
        )
    }

    private var pvpTextButton: some View {
        Button {
            onLocalDuel(selectedDuration)
        } label: {
            Text("PvP")
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(SGEngravedTextButtonStyle(variant: .secondary(opacity: 0.6)))
    }

    private var durationTextPicker: some View {
        HStack(spacing: Self.timerGroupSpacing) {
            ForEach(GameDuration.allCases, id: \.self) { duration in
                Button {
                    selectedDuration = duration
                } label: {
                    Text(duration.title)
                        .fixedSize()
                }
                .buttonStyle(
                    SGEngravedTextButtonStyle(
                        variant: .timerOption(isSelected: selectedDuration == duration),
                        primaryInk: SGEngravedTextTheme.defaultInk(for: themeMode)
                    )
                )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session duration")
        .accessibilityValue(selectedDuration.title)
    }
}
