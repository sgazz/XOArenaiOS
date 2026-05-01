//
//  LearningAnalyzer.swift
//  XOArena
//

import Foundation

/// Classifies human **X** moves on one slab and updates **`LearningProfile`** (no **`GameEngine`** mutations).
enum LearningAnalyzer: Sendable {
    private static let centerIndex = 4
    private static let cornerIndices: Set<Int> = [0, 2, 6, 8]
    private static let sideIndices: Set<Int> = [1, 3, 5, 7]

    /// Apply board-outcome deltas after a move finishes a slab (session-level stats already advanced).
    static func applyBoardOutcomeDelta(
        before: GameStats,
        after: GameStats,
        profile: inout LearningProfile
    ) {
        let dx = after.xBoardWins - before.xBoardWins
        let dO = after.oBoardWins - before.oBoardWins
        let dD = after.boardDraws - before.boardDraws
        if dx > 0 { profile.humanWins += dx }
        if dO > 0 { profile.aiWins += dO }
        if dD > 0 { profile.draws += dD }
        profile.recomputeProgressAndLevel()
    }

    /// Analyze a confirmed human (**X**) move on the active slab.
    static func processHumanMove(
        preBoard: XOBoard,
        postBoard: XOBoard,
        cellIndex: Int,
        profile: inout LearningProfile
    ) {
        profile.totalHumanMoves += 1
        classifyGeometry(cellIndex: cellIndex, profile: &profile)

        let centerEmptyBefore = preBoard.cells[centerIndex].mark == .empty
        let earlyBoard = nonEmptyCellCount(on: preBoard) <= 3

        let oThreatCell = immediateWinningCell(for: .o, on: preBoard)
        var message: String?

        if let mustBlock = oThreatCell {
            if cellIndex == mustBlock {
                profile.successfulBlocks += 1
                message = "Good block."
            } else {
                profile.missedBlocks += 1
                message = "You missed a block."
            }
            profile.earlyAvoidCenterStreak = 0
        } else {
            if earlyBoard && centerEmptyBefore {
                if cellIndex == centerIndex {
                    profile.earlyAvoidCenterStreak = 0
                } else {
                    profile.earlyAvoidCenterStreak += 1
                    if profile.earlyAvoidCenterStreak >= 2 {
                        message = "Try the center early."
                        profile.earlyAvoidCenterStreak = 0
                    }
                }
            } else {
                profile.earlyAvoidCenterStreak = 0
            }
        }

        if postBoard.cells[centerIndex].mark != .empty {
            profile.earlyAvoidCenterStreak = 0
        }

        if let m = message {
            profile.latestFeedbackMessage = m
        }

        profile.recomputeProgressAndLevel()
    }

    private static func classifyGeometry(cellIndex: Int, profile: inout LearningProfile) {
        switch cellIndex {
        case centerIndex:
            profile.centerMoves += 1
        case let i where cornerIndices.contains(i):
            profile.cornerMoves += 1
        case let i where sideIndices.contains(i):
            profile.sideMoves += 1
        default:
            break
        }
    }

    private static func nonEmptyCellCount(on board: XOBoard) -> Int {
        board.cells.filter { $0.mark != .empty }.count
    }

    /// Lowest-index empty that completes a line for **`mark`** if played now.
    private static func immediateWinningCell(for mark: Mark, on board: XOBoard) -> Int? {
        for idx in 0..<GameConstants.cellCount where board.cells[idx].mark == .empty {
            var copy = board
            copy.cells[idx].mark = mark
            if BoardEvaluator.winner(in: copy) == mark {
                return idx
            }
        }
        return nil
    }
}
