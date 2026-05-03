//
//  PvAISetup.swift
//  XOArena
//

import Foundation

enum PlayerSymbolChoice: String, CaseIterable, Sendable, Identifiable {
    case x
    case o

    var id: String { rawValue }

    var mark: Mark {
        switch self {
        case .x: return .x
        case .o: return .o
        }
    }

    var displayLetter: String {
        switch self {
        case .x: return "X"
        case .o: return "O"
        }
    }
}

enum FirstMoverChoice: String, CaseIterable, Sendable, Identifiable {
    case player
    case opponent

    var id: String { rawValue }

    var labelYou: String {
        switch self {
        case .player: return "You"
        case .opponent: return "AI"
        }
    }
}
