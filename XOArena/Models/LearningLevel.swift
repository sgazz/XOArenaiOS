//
//  LearningLevel.swift
//  XOArena
//

import Foundation

/// Pedagogical stage inside **Learning Mode** (v1 milestone ladder).
enum LearningLevel: String, CaseIterable, Equatable, Sendable {
    case basics
    case blocking
    case corners
    case tempo
    case challenge

    var title: String {
        switch self {
        case .basics: return "Basics"
        case .blocking: return "Blocking"
        case .corners: return "Corners"
        case .tempo: return "Tempo"
        case .challenge: return "Challenge"
        }
    }

    var shortDescription: String {
        switch self {
        case .basics: return "Learn the board and first goals."
        case .blocking: return "Read threats before you tap."
        case .corners: return "Angles that stack pressure."
        case .tempo: return "Keep calm under the clock."
        case .challenge: return "Full adaptive sparring."
        }
    }

    /// One-line goal shown in the Learning strip.
    var targetText: String {
        switch self {
        case .basics: return "Find the center"
        case .blocking: return "Stop two-in-a-row"
        case .corners: return "Use corners to create pressure"
        case .tempo: return "Play faster with control"
        case .challenge: return "Beat the adaptive AI"
        }
    }
}
