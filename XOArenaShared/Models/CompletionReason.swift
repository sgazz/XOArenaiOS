//
//  CompletionReason.swift
//  XOArena
//

import Foundation

enum CompletionReason: Equatable, Sendable {
    /// Zastarelo / rezerva — preferiraj **`xTimedOut`** / **`oTimedOut`**.
    case timeExpired
    /// Igrač **X** je ostao bez vremena → **O** pobeduje na vreme.
    case xTimedOut
    /// Igrač **O** je ostao bez vremena → **X** pobeduje na vreme.
    case oTimedOut
    /// **No Time** PvP: više pobeda na tablama.
    case xWinsOnBoardCount
    case oWinsOnBoardCount
    /// **No Time** PvP: jednak broj pobeda na tablama.
    case drawOnBoardCount

    var subtitle: String {
        switch self {
        case .timeExpired:
            return "Time ended"
        case .xTimedOut:
            return "O wins on time"
        case .oTimedOut:
            return "X wins on time"
        case .xWinsOnBoardCount:
            return "X wins the duel"
        case .oWinsOnBoardCount:
            return "O wins the duel"
        case .drawOnBoardCount:
            return "Draw on boards"
        }
    }
}
