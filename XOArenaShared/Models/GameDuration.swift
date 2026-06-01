//
//  GameDuration.swift
//  XOArena
//

import Foundation

enum GameDuration: Int, CaseIterable, Equatable, Sendable {
    case oneMinute = 0
    case threeMinutes = 1
    case fiveMinutes = 2
    case noTime = 3
    case thirtySeconds = 4

    var seconds: Int {
        switch self {
        case .thirtySeconds: return 30
        case .oneMinute: return 60
        case .threeMinutes: return 180
        case .fiveMinutes: return 300
        case .noTime: return 0
        }
    }

    var title: String {
        switch self {
        case .thirtySeconds: return "30 sec"
        case .oneMinute: return "1 min"
        case .threeMinutes: return "3 min"
        case .fiveMinutes: return "5 min"
        case .noTime: return "∞"
        }
    }

    /// Duration picker label (PvP uses explicit **No Time** instead of ∞).
    var pickerTitle: String {
        switch self {
        case .noTime: return "No Time"
        default: return title
        }
    }
}
