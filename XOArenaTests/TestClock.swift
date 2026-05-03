//
//  TestClock.swift
//  XOArenaTests
//

import Foundation

/// Kontrolisani „wall clock“ za **`GameViewModel`** u testovima (deadline sata ostaje uz `MockGameTimerService`).
final class TestClock {
    static let baseline = Date(timeIntervalSinceReferenceDate: 600_000)
    private var offset: TimeInterval = 0
    var date: Date { Self.baseline.addingTimeInterval(offset) }
    func advance(by dt: TimeInterval) { offset += dt }
}
