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

    var subtitle: String {
        switch self {
        case .timeExpired:
            return "Time ended"
        case .xTimedOut:
            return "O wins on time"
        case .oTimedOut:
            return "X wins on time"
        }
    }
}
