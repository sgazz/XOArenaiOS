//
//  GameMode.swift
//  XOArena
//

import Foundation

enum GameMode: String, CaseIterable, Equatable, Sendable {
    case soloFocus
    case vsAI
    /// Human **X** vs adaptive **O** with compact coaching (**timer** unchanged).
    case learning
    case localDuel
    /// **DEBUG-heavy**: both marks played by **`TicTacToeAI`** for rule/timer regression; no human input.
    case aiVsAI

    var displayTitle: String {
        switch self {
        case .soloFocus: return "Solo focus"
        case .vsAI: return "Vs AI"
        case .learning: return "Learning"
        case .localDuel: return "Local duel"
        case .aiVsAI:
#if DEBUG
            return "AI vs AI Test"
#else
            return "AI vs AI"
#endif
        }
    }
}
