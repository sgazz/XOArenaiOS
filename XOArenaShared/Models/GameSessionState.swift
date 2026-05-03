//
//  GameSessionState.swift
//  XOArena
//

import Foundation

enum GameSessionState: String, Equatable, Sendable {
    case notStarted
    case playing
    case completed
}
