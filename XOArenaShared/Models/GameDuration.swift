//
//  GameDuration.swift
//  XOArena
//

import Foundation

enum GameDuration: Int, CaseIterable, Equatable, Sendable {
    case oneMinute
    case threeMinutes
    case fiveMinutes
    /// Watch vs-AI unlimited session (no shared clock); **`seconds`** is **0** (not used where untimed guards exist).
    case noTime

    var seconds: Int {
        switch self {
        case .oneMinute: return 60
        case .threeMinutes: return 180
        case .fiveMinutes: return 300
        case .noTime: return 0
        }
    }

    var title: String {
        switch self {
        case .oneMinute: return "1 min"
        case .threeMinutes: return "3 min"
        case .fiveMinutes: return "5 min"
        case .noTime: return "∞"
        }
    }
}
