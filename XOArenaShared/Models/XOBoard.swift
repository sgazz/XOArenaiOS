//
//  XOBoard.swift
//  XOArena
//

import Foundation

nonisolated enum BoardTurnPhase: Equatable, Sendable {
    case firstMove
    case secondMove
}

nonisolated enum BoardPlayState: Equatable, Sendable {
    case inProgress
    case won(Mark)
    case drawn
}

/// One 9-cell tic-tac-toe board (`XOBoard.cells.count == 9`). Play state derives from evaluator + fullness.
nonisolated struct XOBoard: Equatable, Sendable {
    var cells: [BoardCell]
    var startingMark: Mark
    var turnPhase: BoardTurnPhase

    static var empty: XOBoard {
        XOBoard(cells: BoardCell.emptyGrid(), startingMark: .x, turnPhase: .firstMove)
    }

    var currentMark: Mark {
        switch turnPhase {
        case .firstMove:
            return startingMark
        case .secondMove:
            return startingMark.nextInTurn
        }
    }

    var playState: BoardPlayState {
        if let winner = BoardEvaluator.winner(in: self) {
            return .won(winner)
        }
        if cells.allSatisfy({ $0.mark != .empty }) {
            return .drawn
        }
        return .inProgress
    }
}
