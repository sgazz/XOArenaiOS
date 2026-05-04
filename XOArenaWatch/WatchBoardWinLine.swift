//
//  WatchBoardWinLine.swift
//  XOArenaWatch — winning cell indices derived from glyph grid (mirrors evaluator geometry).
//

import Foundation

enum WatchBoardWinLine {
    private static let lines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6],
    ]

    /// Returns indices of the winning trio when **`cells`** holds a resolved win (`X` / `O`).
    static func winningIndices(from cells: [String]) -> Set<Int>? {
        guard cells.count >= 9 else { return nil }
        for line in lines {
            let a = cells[line[0]]
            let b = cells[line[1]]
            let c = cells[line[2]]
            guard a == "X" || a == "O", a == b, b == c else { continue }
            return Set(line)
        }
        return nil
    }
}
