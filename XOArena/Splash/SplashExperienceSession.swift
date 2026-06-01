//
//  SplashExperienceSession.swift
//  XOArena
//

import Foundation

/// Idempotent splash completion gate (testable, MainActor-agnostic).
enum SplashFinishGate {
    static func attemptFinish(alreadyFinished: inout Bool) -> Bool {
        guard !alreadyFinished else { return false }
        alreadyFinished = true
        return true
    }
}

/// Timeline constants for the launch splash (~4 s beats, hard cap).
enum SplashExperienceTimeline {
    static let beat: TimeInterval = 1.05
    static let crossfadePause: TimeInterval = 0.22
    static let exitFade: TimeInterval = 0.42
    static let exitFadeReducedMotion: TimeInterval = 0.2
    /// Failsafe if animation state stalls.
    static let maximumDuration: TimeInterval = 6
}
