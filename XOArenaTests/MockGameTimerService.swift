//
//  MockGameTimerService.swift
//  XOArenaTests
//

import Foundation
@testable import XOArena

/// **`GameTimerService` test double** (callbacks match host semantics).
///
/// Kombinacija sa **`TestClock`** + isti **`now:`** kao za **`GameViewModel`** država **`activeClockDeadline`** poklopljivim sa očekivanim **`remainingSeconds`/bankama**.
final class MockGameTimerService: GameTimerControlling {
    let clock: TestClock
    private var onTick: (@Sendable (Int) -> Void)?
    private var onFinished: (@Sendable () -> Void)?
    private(set) var startedSeconds: Int?
    private(set) var stopCount: Int = 0

    init(clock: TestClock = TestClock()) {
        self.clock = clock
    }

    func start(
        seconds: Int,
        onTick: @escaping @Sendable (Int) -> Void,
        onFinished: @escaping @Sendable () -> Void
    ) {
        startedSeconds = seconds
        self.onTick = onTick
        self.onFinished = onFinished
    }

    func stop() {
        stopCount += 1
        onTick = nil
        onFinished = nil
    }

    /// Jedna „sekunda“ **`GameTimerService`**: pomeri test sat i okini tick (vrednost se ignoriše kad VM koristi **`activeClockDeadline`**).
    func simulateOneSecondPassed() {
        clock.advance(by: 1)
        onTick?(0)
    }

    /// Pozovi **`simulateOneSecondPassed`** **`n`** puta.
    func simulateSecondsPassed(_ wholeSeconds: Int) {
        for _ in 0 ..< wholeSeconds {
            simulateOneSecondPassed()
        }
    }

    /// @deprecated Prefer **`simulateSecondsPassed`** / **`simulateOneSecondPassed`**. Jedan sekundski „tick“, ignoriše argument (ostaje za stare pozive koji su slali preostalo vreme kao u host tickeru — VM i dalje računa iz deadline-a kad je dostupan).
    func simulateTick(_ secondsIgnored: Int) {
        simulateOneSecondPassed()
    }

    func simulateFinish() {
        clock.advance(by: 48 * 3600)
        onTick?(0)
        onFinished?()
    }
}

