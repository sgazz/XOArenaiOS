//
//  AIMoveTimerContext.swift
//  XOArena
//

import Foundation

/// Session timer snapshot for **`TicTacToeAI`** time‑pressure jitter (does not interact with **`GameEngine`** rules).
struct AIMoveTimerContext: Equatable, Sendable {
    var remainingSeconds: Int
    /// Total countdown length for this session (**`selectedDuration.seconds`** pattern from UI).
    var totalSeconds: Int

    /// **0 … 1** of time left; **`nil`** if pressure is disabled.
    func remainingFraction() -> Double? {
        guard totalSeconds > 0 else { return nil }
        let r = max(0, Double(remainingSeconds) / Double(totalSeconds))
        return min(1, r)
    }

    enum Pressure: Sendable {
        /// **≥ ~30 %** remaining (or unknown timer).
        case comfortable
        /// **\< 30 %** and **≥ 10 %**.
        case low
        /// **\< 10 %** remaining (includes **0**).
        case critical

        static func tier(from fraction: Double?) -> Pressure {
            guard let f = fraction else { return .comfortable }
            if f < 0.10 { return .critical }
            if f < 0.30 { return .low }
            return .comfortable
        }
    }

    func pressureTier() -> Pressure {
        Pressure.tier(from: remainingFraction())
    }
}
