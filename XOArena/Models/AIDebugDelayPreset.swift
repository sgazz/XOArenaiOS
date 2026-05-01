//
//  AIDebugDelayPreset.swift
//  XOArena
//

import Foundation

/// Async delay presets for **`GameMode.aiVsAI`** autoplay (**DEBUG / rule testing**). Does not affect **`vsAI`** pacing (still uses a separate random human-facing delay band).
enum AIDebugDelayPreset: String, CaseIterable, Equatable, Sendable {
    case normal
    case fast
    case instant

    var nanoseconds: UInt64 {
        switch self {
        case .normal: return 350_000_000
        case .fast: return 80_000_000
        case .instant: return 10_000_000
        }
    }
}
