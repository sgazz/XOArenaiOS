//
//  BoardCell.swift
//  XOArena
//

import Foundation

struct BoardCell: Identifiable, Equatable, Sendable {
    let index: Int
    var mark: Mark

    var id: Int { index }

    static func emptyGrid() -> [BoardCell] {
        (0..<GameConstants.cellCount).map { BoardCell(index: $0, mark: .empty) }
    }
}
