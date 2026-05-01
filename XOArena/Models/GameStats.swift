//
//  GameStats.swift
//  XOArena
//

import Foundation

struct GameStats: Equatable, Sendable {
    var totalMoves: Int
    var xBoardWins: Int
    var oBoardWins: Int
    var boardDraws: Int

    static let zero = GameStats(totalMoves: 0, xBoardWins: 0, oBoardWins: 0, boardDraws: 0)
}
