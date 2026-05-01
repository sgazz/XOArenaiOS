//
//  MainMenuView.swift
//  XOArena
//

import SwiftUI

/// Mode picker and session duration — main entry after optional launch intro.
struct MainMenuView: View {
    @Environment(\.sgThemeMode) private var themeMode
    @Binding var selectedDuration: GameDuration

    let onPractice: (GameDuration) -> Void
    let onVsAI: (GameDuration) -> Void
    let onLearning: (GameDuration) -> Void
    let onLocalDuel: (GameDuration) -> Void
    var onAiVsAITest: ((GameDuration) -> Void)? = nil

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        ZStack {
            PaperBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: SGSpacing.lg) {
                Spacer(minLength: SGSpacing.md)

                VStack(spacing: SGSpacing.sm) {
                    Text("XOArena")
                        .font(SGTypography.mainTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(t.textPrimary)
                        .tracking(SGTypography.titleTracking)

                    Text("Eight boards. One focus.")
                        .font(SGTypography.body)
                        .foregroundStyle(t.textSecondary)
                        .multilineTextAlignment(.center)
                        .tracking(SGTypography.subtitleTracking)

                    Rectangle()
                        .fill(t.accentSubtle.opacity(themeMode == .light ? 0.38 : 0.42))
                        .frame(width: 52, height: 1)
                        .padding(.top, SGSpacing.xs)
                }
                .padding(.horizontal, SGSpacing.xxl)

                Spacer()

                VStack(spacing: SGSpacing.sm) {
                    durationPicker

                    SGButton(title: "Practice", variant: .secondary) {
                        onPractice(selectedDuration)
                    }
                    SGButton(title: "Play vs AI", variant: .primary) {
                        onVsAI(selectedDuration)
                    }
                    VStack(alignment: .leading, spacing: SGSpacing.xs) {
                        SGButton(title: "Learning", variant: .secondary) {
                            onLearning(selectedDuration)
                        }
                        Text("Learn to beat the AI through short feedback and adaptive challenge.")
                            .font(SGTypography.small)
                            .foregroundStyle(t.textSecondary.opacity(themeMode == .light ? 0.74 : 0.68))
                            .tracking(0.35)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    SGButton(title: "Local duel", variant: .secondary) {
                        onLocalDuel(selectedDuration)
                    }
#if DEBUG
                    if let onAiVsAITest {
                        SGButton(title: GameMode.aiVsAI.displayTitle, variant: .secondary) {
                            onAiVsAITest(selectedDuration)
                        }
                    }
#endif
                }
                .padding(.horizontal, SGSpacing.xl + 6)
                .padding(.bottom, SGSpacing.xxl)
                .accessibilityElement(children: .contain)
                .accessibilityHint("Practice and Local duel alternate two humans on each board; Play vs AI faces the device as X.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SGThemeToggleControl()
            }
        }
    }

    private var durationPicker: some View {
        Picker("Duration", selection: $selectedDuration) {
            ForEach(GameDuration.allCases, id: \.self) { duration in
                Text(duration.title).tag(duration)
            }
        }
        .pickerStyle(.segmented)
        .tint(t.accentSubtle.opacity(themeMode == .light ? 0.86 : 0.76))
        .accessibilityLabel("Session duration")
    }
}
