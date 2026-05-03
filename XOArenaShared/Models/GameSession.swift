//
//  GameSession.swift
//  XOArena
//

import Foundation

struct GameSession: Equatable, Sendable {
    var boards: [XOBoard]
    var activeBoardIndex: Int
    var gameMode: GameMode
    var aiDifficulty: AIDifficulty
    var stats: GameStats
    var sessionState: GameSessionState
    /// U **vsAI** / **learning**: oznaka koju kontroliše čovek; **`nil`** u ostalim modovima.
    var humanControlledMark: Mark?

    var currentMarkForActiveBoard: Mark {
        guard boards.indices.contains(activeBoardIndex) else { return .x }
        return boards[activeBoardIndex].currentMark
    }
}
