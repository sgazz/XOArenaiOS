//
//  LearningProfile.swift
//  XOArena
//

import Foundation

/// Session-scoped learning telemetry for **Learning Mode** (human **X** vs **O** AI).
struct LearningProfile: Equatable, Sendable {
    var totalHumanMoves: Int
    var centerMoves: Int
    var cornerMoves: Int
    var sideMoves: Int
    var missedBlocks: Int
    var successfulBlocks: Int
    var humanWins: Int
    var aiWins: Int
    var draws: Int
    var currentLevel: LearningLevel
    var latestFeedbackMessage: String
    /// **0 ... 1** blended mastery signal (v1 heuristic).
    var progressValue: Double

    /// Consecutive early-game moves while center was open but not played (throttles center hint).
    var earlyAvoidCenterStreak: Int

    static let initial = LearningProfile(
        totalHumanMoves: 0,
        centerMoves: 0,
        cornerMoves: 0,
        sideMoves: 0,
        missedBlocks: 0,
        successfulBlocks: 0,
        humanWins: 0,
        aiWins: 0,
        draws: 0,
        currentLevel: .basics,
        latestFeedbackMessage: "",
        progressValue: 0,
        earlyAvoidCenterStreak: 0
    )

    /// AI strength for the next **O** move (never illegal; uses **`AIDifficulty`** pipeline).
    func adaptiveAIDifficulty() -> AIDifficulty {
        let base: AIDifficulty
        switch currentLevel {
        case .basics, .blocking, .corners, .tempo:
            base = .medium
        case .challenge:
            base = .hard
        }
        let excelling = successfulBlocks >= 3 && humanWins > aiWins
        if missedBlocks >= 3, !excelling {
            return .easy
        }
        if excelling {
            return .hard
        }
        return base
    }

    mutating func recomputeProgressAndLevel() {
        var p =
            Double(min(successfulBlocks, 12)) * 0.07
            + Double(min(humanWins, 10)) * 0.09
            + Double(min(cornerMoves, 10)) * 0.04
            + Double(min(totalHumanMoves, 45)) * 0.008
            - Double(min(missedBlocks, 10)) * 0.06
        p = min(1, max(0, p))
        progressValue = p

        switch p {
        case ..<0.18:
            currentLevel = .basics
        case ..<0.36:
            currentLevel = .blocking
        case ..<0.54:
            currentLevel = .corners
        case ..<0.72:
            currentLevel = .tempo
        default:
            currentLevel = .challenge
        }
    }
}
