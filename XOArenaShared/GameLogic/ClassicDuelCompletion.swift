//
//  ClassicDuelCompletion.swift
//  XOArena
//

import Foundation

/// End-of-match rules for **No Time** `localDuel` (board-count victory, no clocks).
enum ClassicDuelCompletion {
    static func completedBoardCount(_ stats: GameStats) -> Int {
        stats.xBoardWins + stats.oBoardWins + stats.boardDraws
    }

    /// **`nil`** until **`GameConstants.boardCount`** mini-board results are recorded.
    static func completionReason(for stats: GameStats) -> CompletionReason? {
        guard completedBoardCount(stats) >= GameConstants.boardCount else { return nil }
        if stats.xBoardWins > stats.oBoardWins { return .xWinsOnBoardCount }
        if stats.oBoardWins > stats.xBoardWins { return .oWinsOnBoardCount }
        return .drawOnBoardCount
    }
}
