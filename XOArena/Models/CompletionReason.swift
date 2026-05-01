//
//  CompletionReason.swift
//  XOArena
//

import Foundation

enum CompletionReason: Equatable, Sendable {
    case timeExpired

    var subtitle: String {
        switch self {
        case .timeExpired:
            return "Time ended"
        }
    }
}
