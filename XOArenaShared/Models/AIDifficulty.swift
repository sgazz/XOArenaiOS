//
//  AIDifficulty.swift
//  XOArena
//

import Foundation

/// Single-board AI strength for **`TicTacToeAI`** (evaluates only the given **`XOBoard`** slab).
nonisolated enum AIDifficulty: String, CaseIterable, Equatable, Hashable, Sendable {
    /// Random-ish play with a light filter plus optional timer “panic”.
    case easy
    /// Instant win/block, otherwise random among top minimax-ranked moves (pool widens under time pressure).
    case medium
    /// Instant win/block, otherwise mostly minimax-best with occasional second-best; clock pressure adds jitter.
    case hard
}
