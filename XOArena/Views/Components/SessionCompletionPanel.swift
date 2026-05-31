//
//  SessionCompletionPanel.swift
//  XOArena
//

import SwiftUI

// MARK: - Full-screen centered modal

/// Zamrznuti sesiju: zatamnjen pozadinski sloj + centrirana kartica (nije u flow-u glavnog `VStack`-a).
struct SessionCompletionModal: View {
    @Environment(\.sgThemeMode) private var themeMode

    let stats: GameStats
    let reason: CompletionReason
    let gameMode: GameMode
    /// Za **vsAI** / **learning**: čovekov simbol (etikete u rezimeu).
    var humanPlayerMark: Mark? = nil
    let learningProfile: LearningProfile?
    let onPlayAgain: () -> Void
    let onMainMenu: () -> Void

    @State private var appearPhase: CGFloat = 0

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.08 * Double(appearPhase))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticService.lightImpact()
                    onPlayAgain()
                }

            VStack(spacing: 0) {
                SessionCompletionCard(
                    stats: stats,
                    reason: reason,
                    gameMode: gameMode,
                    humanPlayerMark: humanPlayerMark,
                    learningProfile: learningProfile,
                    onPlayAgain: onPlayAgain,
                    onMainMenu: onMainMenu,
                    appearPhase: appearPhase
                )
                .environment(\.sgThemeMode, themeMode)
                .frame(maxWidth: SessionCompletionChrome.maxCardWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session complete. \(reason.subtitle). Play again or return to main menu.")
        .onAppear {
            appearPhase = 0
            withAnimation(.easeInOut(duration: 0.2)) {
                appearPhase = 1
            }
        }
    }
}

// MARK: - Card

private enum SessionCompletionChrome {
    static let cornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 24
    static let maxCardWidth: CGFloat = 328

    static let cappuccinoLight = Color(red: 243 / 255, green: 237 / 255, blue: 230 / 255)
    /// Topla kamena ploča u mraku (ne čista siva).
    static let cappuccinoDark = Color(red: 48 / 255, green: 45 / 255, blue: 42 / 255)
}

private struct SessionCompletionCard: View {
    @Environment(\.sgThemeMode) private var themeMode

    let stats: GameStats
    let reason: CompletionReason
    let gameMode: GameMode
    /// **nil**: zadržati starije „You **(X)** / AI **(O)**“ kao podrazumevano.
    var humanPlayerMark: Mark?
    let learningProfile: LearningProfile?
    let onPlayAgain: () -> Void
    let onMainMenu: () -> Void
    var appearPhase: CGFloat

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    private var cardInk: Color {
        themeMode == .light ? SGColors.inkPrimaryLight : SGColors.textDark
    }

    private var cardFill: Color {
        themeMode == .light ? SessionCompletionChrome.cappuccinoLight : SessionCompletionChrome.cappuccinoDark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Session Complete")
                    .font(.system(size: themeMode == .light ? 20 : 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(cardInk.opacity(themeMode == .light ? 0.96 : 0.94))
                    .tracking(0.35)
                    .sgEngravedText(intensity: .high, color: cardInk.opacity(themeMode == .light ? 0.96 : 0.94))

                Text(reason.subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(t.textSecondary.opacity(themeMode == .light ? 0.78 : 0.74))
                    .tracking(0.12)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 5) {
                summaryRow(title: xCaption, value: "\(stats.xBoardWins)")
                summaryRow(title: oCaption, value: "\(stats.oBoardWins)")
                summaryRow(title: "Draws", value: "\(stats.boardDraws)")
            }
            .padding(.top, SGSpacing.sm)

            if let lp = learningProfile, gameMode == .learning {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Level: \(lp.currentLevel.title)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(cardInk.opacity(0.9))
                        .tracking(0.2)
                        .sgEngravedText(intensity: .low, color: cardInk.opacity(0.9))

                    Text(learningCoachLine(for: lp))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(t.textSecondary.opacity(0.86))
                        .tracking(0.12)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, SGSpacing.xs + 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Level \(lp.currentLevel.title). \(learningCoachLine(for: lp))")
            }

            VStack(spacing: SGSpacing.sm) {
                Button {
                    HapticService.lightImpact()
                    onPlayAgain()
                } label: {
                    Text("Play Again")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(cardInk.opacity(themeMode == .light ? 0.95 : 0.96))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(SessionPlayAgainScaleStyle())

                Button {
                    HapticService.lightImpact()
                    onMainMenu()
                } label: {
                    Text("Main Menu")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(t.textSecondary.opacity(themeMode == .light ? 0.88 : 0.84))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(SessionPlayAgainScaleStyle())
            }
            .padding(.top, SGSpacing.md)
        }
        .padding(SessionCompletionChrome.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundLayers)
        .opacity(Double(appearPhase))
        .scaleEffect(CGFloat(0.96 + 0.04 * appearPhase))
    }

    /// Ugravirani „stone slab”: dvije blage sjene bez obruba.
    private var cardBackgroundLayers: some View {
        RoundedRectangle(cornerRadius: SessionCompletionChrome.cornerRadius, style: .continuous)
            .fill(cardFill)
            .shadow(color: Color.white.opacity(themeMode == .light ? 0.4 : 0.28), radius: 1.25, x: -2.25, y: -2)
            .shadow(color: Color(red: 73 / 255, green: 58 / 255, blue: 48 / 255).opacity(themeMode == .light ? 0.25 : 0.38), radius: 4, x: 2.75, y: 4)
    }

    private var xCaption: String {
        switch gameMode {
        case .vsAI, .learning:
            guard let h = humanPlayerMark else { return "You (X)" }
            return h == .x ? "You (X)" : "AI (X)"
        case .soloFocus, .localDuel, .aiVsAI:
            return "X"
        }
    }

    private var oCaption: String {
        switch gameMode {
        case .vsAI, .learning:
            guard let h = humanPlayerMark else { return "AI (O)" }
            return h == .o ? "You (O)" : "AI (O)"
        case .soloFocus, .localDuel, .aiVsAI:
            return "O"
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(t.textSecondary.opacity(0.86))
                .tracking(0.12)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(cardInk)
                .monospacedDigit()
                .sgEngravedText(intensity: .low, color: cardInk)
        }
        .minimumScaleFactor(0.82)
        .lineLimit(1)
    }

    /// Kratak rekapitulant — koristi **`LearningProfile`**, bez **GameEngine**-a.
    private func learningCoachLine(for profile: LearningProfile) -> String {
        let trimmed = profile.latestFeedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if profile.humanWins > profile.aiWins {
            return "Strong slab wins — steady hands."
        }
        if profile.aiWins > profile.humanWins {
            return "Good reps — tighten threats next session."
        }
        return profile.currentLevel.shortDescription
    }
}

private struct SessionPlayAgainScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("Session complete") {
    SessionCompletionModal(
        stats: GameStats(totalMoves: 42, xBoardWins: 3, oBoardWins: 2, boardDraws: 1),
        reason: .xTimedOut,
        gameMode: .vsAI,
        humanPlayerMark: .x,
        learningProfile: nil,
        onPlayAgain: {},
        onMainMenu: {}
    )
    .environment(\.sgThemeMode, .light)
}
