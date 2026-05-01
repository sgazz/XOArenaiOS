//
//  MoveError.swift
//  XOArena
//

import Foundation

/// Reasons `GameEngine.applyMove` rejects play. UI intentionally ignores failures for now; errors stay explicit for QA and future tooling.
enum MoveError: Equatable, Error, Sendable {
    /// `sessionState` is not `.playing` (`notStarted` or `completed`).
    case sessionNotActive
    case invalidBoardIndex
    case invalidCellIndex
    /// Attempted board is not `session.activeBoardIndex` (only one board may receive input).
    case wrongBoard(expected: Int, attempted: Int)
    case cellOccupied
    case boardFinished
}

extension MoveError: CustomStringConvertible {
    var description: String {
        switch self {
        case .sessionNotActive:
            return "sessionNotActive: session must be playing"
        case .invalidBoardIndex:
            return "invalidBoardIndex"
        case .invalidCellIndex:
            return "invalidCellIndex"
        case .wrongBoard(let expected, let attempted):
            return "wrongBoard: expected \(expected), attempted \(attempted)"
        case .cellOccupied:
            return "cellOccupied"
        case .boardFinished:
            return "boardFinished"
        }
    }
}

extension MoveError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .sessionNotActive:
            return "The session isn’t accepting moves right now."
        case .invalidBoardIndex:
            return "That board doesn’t exist."
        case .invalidCellIndex:
            return "That cell doesn’t exist."
        case .wrongBoard(let expected, _):
            return "Play is only allowed on board \(expected + 1)."
        case .cellOccupied:
            return "That cell is already taken."
        case .boardFinished:
            return "That board is already finished."
        }
    }
}
