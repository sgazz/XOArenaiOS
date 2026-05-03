//
//  GameDuration.swift
//  XOArena
//

import Foundation

enum GameDuration: Int, CaseIterable, Equatable, Sendable {
    case oneMinute
    case threeMinutes
    case fiveMinutes

    var seconds: Int {
        switch self {
        case .oneMinute: return 60
        case .threeMinutes: return 180
        case .fiveMinutes: return 300
        }
    }

    var title: String {
        switch self {
        case .oneMinute: return "1 min"
        case .threeMinutes: return "3 min"
        case .fiveMinutes: return "5 min"
        }
    }
}
