//
//  Mark.swift
//  XOArena
//

import Foundation

enum Mark: String, CaseIterable, Equatable, Sendable {
    case empty
    case x
    case o

    /// Alternates **X ⇄ O** for live play. **X** always opens a session (`GameEngine.makeInitialSession`). `.empty` maps to `.x` as a harmless fallback only.
    var nextInTurn: Mark {
        switch self {
        case .empty: return .x
        case .x: return .o
        case .o: return .x
        }
    }
}
