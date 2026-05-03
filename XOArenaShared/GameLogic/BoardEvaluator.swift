//
//  BoardEvaluator.swift
//  XOArena
//

import Foundation

/// Classic 3×3 win geometry: rows, columns, both diagonals.
nonisolated enum BoardEvaluator: Sendable {
    private static let winLines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6]
    ]

    /// Returns winning mark (`X` or `O`) if either player completed a row, column, or diagonal with matching marks.
    static func winner(in board: XOBoard) -> Mark? {
        let marks = board.cells.map(\.mark)
        for line in winLines {
            let a = marks[line[0]]
            let b = marks[line[1]]
            let c = marks[line[2]]
            guard a != .empty, a == b, b == c else { continue }
            return a
        }
        return nil
    }

    /// Full board without a winner.
    static func isDraw(_ board: XOBoard) -> Bool {
        winner(in: board) == nil && board.cells.allSatisfy { $0.mark != .empty }
    }
}
