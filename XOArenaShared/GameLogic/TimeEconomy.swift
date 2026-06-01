//
//  TimeEconomy.swift
//  XOArena
//

import Foundation

// MARK: - Configuration

/// Per-outcome shift amounts for a game economy preset.
struct BoardWinShift: Equatable, Sendable {
    let winnerGain: Int
    let loserPenalty: Int
}

struct DrawShift: Equatable, Sendable {
    let symmetricGain: Int?
    let humanGain: Int?
    let aiGain: Int?

    /// PvP: oba igrača dobijaju isti bonus.
    static func both(_ seconds: Int) -> DrawShift {
        DrawShift(symmetricGain: seconds, humanGain: nil, aiGain: nil)
    }

    /// PvAI: asimetričan draw (human / AI).
    static func humanVsAI(human: Int, ai: Int) -> DrawShift {
        DrawShift(symmetricGain: nil, humanGain: human, aiGain: ai)
    }
}

/// Reward table for board outcomes in a given mode / AI tier.
struct TimeEconomyRules: Equatable, Sendable {
    let boardWin: BoardWinShift
    let draw: DrawShift?

    static let pvp = TimeEconomyRules(
        boardWin: BoardWinShift(winnerGain: 6, loserPenalty: 4),
        draw: .both(2)
    )

    static func vsAI(difficulty: AIDifficulty) -> TimeEconomyRules {
        let draw = DrawShift.humanVsAI(human: 2, ai: 0)
        switch difficulty {
        case .easy:
            return TimeEconomyRules(
                boardWin: BoardWinShift(winnerGain: 6, loserPenalty: 3),
                draw: draw
            )
        case .medium:
            return TimeEconomyRules(
                boardWin: BoardWinShift(winnerGain: 8, loserPenalty: 4),
                draw: draw
            )
        case .hard:
            return TimeEconomyRules(
                boardWin: BoardWinShift(winnerGain: 12, loserPenalty: 5),
                draw: draw
            )
        }
    }
}

/// Global clamps applied when applying board rewards (not natural countdown).
enum TimeEconomyPolicy: Sendable {
    /// Reward penalties never push a bank below this value.
    static let penaltyFloorSeconds = 3
    /// Default bonus cap (PvAI and other modes).
    static let defaultBonusCapOverInitialSeconds = 15
    /// PvP (`localDuel`) allows more time accumulation from board wins.
    static let pvpBonusCapOverInitialSeconds = 25

    static func bonusCapOverInitial(for mode: GameMode) -> Int {
        switch mode {
        case .localDuel:
            return pvpBonusCapOverInitialSeconds
        case .vsAI, .learning, .soloFocus, .aiVsAI:
            return defaultBonusCapOverInitialSeconds
        }
    }
}

enum BoardTimeOutcome: Equatable, Sendable {
    case draw
    case xWin
    case oWin
}

struct TimeEconomyAdjustment: Equatable, Sendable {
    let xDelta: Int
    let oDelta: Int

    static let zero = TimeEconomyAdjustment(xDelta: 0, oDelta: 0)

    var isEmpty: Bool { xDelta == 0 && oDelta == 0 }
}

enum TimeEconomyContext: Equatable, Sendable {
    case pvp
    case vsAI(humanMark: Mark, difficulty: AIDifficulty)
}

// MARK: - Engine

enum TimeEconomyEngine {
    /// Detects whether a board just finished from stats delta.
    static func boardOutcome(before: GameStats, after: GameStats) -> BoardTimeOutcome? {
        if after.boardDraws > before.boardDraws { return .draw }
        if after.xBoardWins > before.xBoardWins { return .xWin }
        if after.oBoardWins > before.oBoardWins { return .oWin }
        return nil
    }

    /// Rules for modes that participate in the time economy; **`nil`** = no board rewards.
    static func rules(for mode: GameMode, aiDifficulty: AIDifficulty) -> TimeEconomyRules? {
        switch mode {
        case .localDuel:
            return .pvp
        case .vsAI, .learning:
            return .vsAI(difficulty: aiDifficulty)
        case .soloFocus, .aiVsAI:
            return nil
        }
    }

    /// Computes raw deltas before floor/cap. Returns **`nil`** when no reward applies (e.g. AI board win).
    static func plannedAdjustment(
        outcome: BoardTimeOutcome,
        rules: TimeEconomyRules,
        context: TimeEconomyContext
    ) -> TimeEconomyAdjustment? {
        switch outcome {
        case .draw:
            guard let draw = rules.draw else { return nil }
            switch context {
            case .pvp:
                guard let gain = draw.symmetricGain else { return nil }
                return TimeEconomyAdjustment(xDelta: gain, oDelta: gain)
            case .vsAI(let humanMark, _):
                guard let human = draw.humanGain, let ai = draw.aiGain else { return nil }
                switch humanMark {
                case .x:
                    return TimeEconomyAdjustment(xDelta: human, oDelta: ai)
                case .o:
                    return TimeEconomyAdjustment(xDelta: ai, oDelta: human)
                case .empty:
                    return nil
                }
            }

        case .xWin, .oWin:
            let winner: Mark = outcome == .xWin ? .x : .o
            let loser = winner.nextInTurn
            let win = rules.boardWin

            switch context {
            case .pvp:
                return adjustment(winner: winner, loser: loser, win: win)

            case .vsAI(let humanMark, _):
                guard winner == humanMark else { return nil }
                return adjustment(winner: humanMark, loser: humanMark.nextInTurn, win: win)
            }
        }
    }

    /// Applies floor/cap and writes banks; returns **actual** deltas applied.
    static func apply(
        _ adjustment: TimeEconomyAdjustment,
        xRemaining: inout Int,
        oRemaining: inout Int,
        initialDurationSeconds: Int,
        gameMode: GameMode
    ) -> TimeEconomyAdjustment {
        let cap = initialDurationSeconds + TimeEconomyPolicy.bonusCapOverInitial(for: gameMode)
        let floor = TimeEconomyPolicy.penaltyFloorSeconds

        let newX = clampBank(
            current: xRemaining,
            delta: adjustment.xDelta,
            cap: cap,
            floor: floor
        )
        let newO = clampBank(
            current: oRemaining,
            delta: adjustment.oDelta,
            cap: cap,
            floor: floor
        )

        let applied = TimeEconomyAdjustment(
            xDelta: newX - xRemaining,
            oDelta: newO - oRemaining
        )
        xRemaining = newX
        oRemaining = newO
        return applied
    }

    static func context(for session: GameSession, aiDifficulty: AIDifficulty) -> TimeEconomyContext? {
        switch session.gameMode {
        case .localDuel:
            return .pvp
        case .vsAI, .learning:
            guard let human = session.humanControlledMark else { return nil }
            return .vsAI(humanMark: human, difficulty: aiDifficulty)
        case .soloFocus, .aiVsAI:
            return nil
        }
    }

    private static func adjustment(winner: Mark, loser: Mark, win: BoardWinShift) -> TimeEconomyAdjustment {
        switch winner {
        case .x:
            return TimeEconomyAdjustment(xDelta: win.winnerGain, oDelta: -win.loserPenalty)
        case .o:
            return TimeEconomyAdjustment(xDelta: -win.loserPenalty, oDelta: win.winnerGain)
        case .empty:
            return .zero
        }
    }

    private static func clampBank(current: Int, delta: Int, cap: Int, floor: Int) -> Int {
        var value = current + delta
        if delta > 0 {
            value = min(value, cap)
        }
        if delta < 0 {
            value = max(value, floor)
        }
        return value
    }
}
