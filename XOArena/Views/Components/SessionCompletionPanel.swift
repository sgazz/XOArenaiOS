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

            SessionHandInkDividerShape()
                .stroke(t.border.opacity(themeMode == .light ? 0.42 : 0.36), style: StrokeStyle(lineWidth: 0.95, lineCap: .round))
                .frame(height: 3)

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
                        .sgEngravedText(intensity: .low, color: t.textPrimary.opacity(0.92))

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

            Button {
                HapticService.lightImpact()
                onPlayAgain()
            } label: {
                Text("Play Again")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(
                SGEngravedTextButtonStyle(variant: .primary(engravedIntensity: .medium), primaryInk: t.textPrimary)
            )
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
        .shadow(color: t.shadowCalm.opacity(0.28), radius: floor(t.shadowCalmRadius * 0.55), y: themeMode == .light ? 1 : 1.5)
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
                .sgEngravedText(intensity: .medium, color: t.textPrimary)

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
                .sgEngravedText(intensity: .low, color: t.textPrimary)
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

/// Blago nepravilo „povlačenje perom“ umesto strogo horizontalne linije.
private struct SessionHandInkDividerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let y = rect.midY
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 0.2, y: y - 0.25))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - 0.25, y: y + 0.22),
            control: CGPoint(x: rect.midX + 0.8, y: y + 0.48)
        )
        return p
    }
}
