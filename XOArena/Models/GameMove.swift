//
//  GameMove.swift
//  XOArena
//

import Foundation

struct GameMove: Equatable, Sendable {
    let boardIndex: Int
    let cellIndex: Int
    let mark: Mark
}
