//
//  SessionCompletionPanel.swift
//  XOArena
//

import SwiftUI

struct SessionCompletionPanel: View {
    @Environment(\.sgThemeMode) private var themeMode

    let stats: GameStats
    let reason: CompletionReason
    let gameMode: GameMode
    /// Non-**`nil`** only while **`gameMode == .learning`** — optional Learning strip-style recap.
    let learningProfile: LearningProfile?
    let onPlayAgain: () -> Void
    var compact: Bool = false

    @State private var revealOpacity: CGFloat = 0

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? SGSpacing.sm : SGSpacing.md) {
            headerBlock(compact: compact)

            Rectangle()
                .fill(t.border.opacity(themeMode == .light ? 0.45 : 0.38))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: compact ? SGSpacing.xs : SGSpacing.sm) {
                summaryRow(title: xCaption, value: "\(stats.xBoardWins)")
                summaryRow(title: oCaption, value: "\(stats.oBoardWins)")
                summaryRow(title: "Draws", value: "\(stats.boardDraws)")
            }

            if let lp = learningProfile, gameMode == .learning {
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text("Level: \(lp.currentLevel.title)")
                        .font(SGTypography.small)
                        .fontWeight(.medium)
                        .foregroundStyle(t.textPrimary.opacity(0.92))
                        .tracking(0.25)

                    Text(learningCoachLine(for: lp))
                        .font(SGTypography.small)
                        .foregroundStyle(t.textSecondary.opacity(0.9))
                        .tracking(0.2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, SGSpacing.xs)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Level \(lp.currentLevel.title). \(learningCoachLine(for: lp))")
            }

            SGButton(title: "Play Again", variant: .primary, action: onPlayAgain)
                .frame(height: 44)
                .padding(.top, compact ? SGSpacing.xs : SGSpacing.sm)
        }
        .padding(compact ? SGSpacing.md : SGSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SGRadius.lg, style: .continuous)
                .fill(t.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: SGRadius.lg, style: .continuous)
                        .strokeBorder(t.border.opacity(themeMode == .light ? 0.5 : 0.42), lineWidth: 0.9)
                )
        )
        .shadow(color: t.shadowCalm.opacity(0.88), radius: t.shadowCalmRadius, y: themeMode == .light ? 2 : 3)
        .opacity(Double(revealOpacity))
        .offset(y: 10 - revealOpacity * 10)
        .onAppear {
            revealOpacity = 0
            withAnimation(.easeOut(duration: 0.42)) {
                revealOpacity = 1
            }
        }
    }

    private var xCaption: String {
        switch gameMode {
        case .vsAI, .learning: return "You (X)"
        case .soloFocus, .localDuel, .aiVsAI:
            return "X"
        }
    }

    private var oCaption: String {
        switch gameMode {
        case .vsAI, .learning: return "AI (O)"
        case .soloFocus, .localDuel, .aiVsAI:
            return "O"
        }
    }

    private func headerBlock(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: SGSpacing.xs + 2) {
            Text("Session Complete")
                .font(compact ? Font.system(size: 17, weight: .semibold, design: .rounded) : SGTypography.sectionTitle)
                .tracking(SGTypography.subtitleTracking + 0.35)
                .foregroundStyle(t.textPrimary)

            Text(reason.subtitle)
                .font(SGTypography.small)
                .foregroundStyle(t.textSecondary.opacity(0.82))
                .tracking(0.28)
                .fixedSize(horizontal: false, vertical: true)
        }
        .allowsHitTesting(false)
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(spacing: SGSpacing.sm) {
            Text(title)
                .font(SGTypography.small)
                .foregroundStyle(t.textSecondary)
                .tracking(0.15)
            Spacer(minLength: SGSpacing.sm)
            Text(value)
                .font(SGTypography.body)
                .fontWeight(.semibold)
                .foregroundStyle(t.textPrimary)
                .monospacedDigit()
        }
        .minimumScaleFactor(0.82)
        .lineLimit(1)
    }

    /// Short line for recap — prefers live Learning feedback else a quiet heuristic summary (no **`GameEngine`**).
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
