//
//  WatchFeelTiming.swift
//  XOArenaWatch — consistent feel timings (no engine logic).
//

import Foundation
import SwiftUI

enum WatchFeelTiming {
    /// Tap “pop”: hold at 0.96 scale (~80 ms dwell).
    static let tapHoldSeconds: TimeInterval = 0.08
    static let tapReturnSeconds: TimeInterval = 0.08

    /// AI “breathing room” **before** AI thinking math (central 120–180 ms).
    static let aiHumanResponseMinNanos: UInt64 = 120_000_000
    static let aiHumanResponseMaxNanos: UInt64 = 180_000_000

    /// Completed slab held before vertical scroll (**0.28 s** ∈ 0.25–0.30).
    static let boardPreviewHoldNanoseconds: UInt64 = 280_000_000

    /// Vertical scroll (**0.26 s** ∈ 0.24–0.28), calm cubic-ish ease (**no bounce**).
    static let boardScrollSeconds: TimeInterval = 0.26
    static var boardScrollNanoseconds: UInt64 { UInt64(boardScrollSeconds * 1_000_000_000) }

    static var boardScrollAnimation: Animation {
        .timingCurve(0.42, 0.0, 0.58, 1.0, duration: boardScrollSeconds)
    }

    /// AI placement mark settle-in (**~0.1 s**).
    static let aiMarkFadeSeconds: TimeInterval = 0.10

    /// End screen stagger before content + outcome haptic.
    static let endRevealDelaySeconds: TimeInterval = 0.20
}
