//
//  AiVsAISoakTests.swift
//  XOArenaTests
//

#if DEBUG

import XCTest
@testable import XOArena

/// Soak **`GameMode.aiVsAI`** with **`MockGameTimerService`** + **`AIDebugDelayPreset.instant`** bursts between countdown ticks (**`GameTimerService`** semantics; no full wall-clock minute).
@MainActor
final class AiVsAISoakTests: XCTestCase {
    func test_aiVsAI_soak_timerCompletion_noPostTimeoutMoves() async throws {
        let timer = MockGameTimerService()
        let vm = GameViewModel(timerService: timer, now: { timer.clock.date })

        /// **`soloFocus`**: nema paralelnog AI poteza — odbrojavanje je deterministično kao jedan aktivni sat (**X** prvi).
        vm.startNewGame(mode: .soloFocus, duration: .oneMinute)

        XCTAssertEqual(vm.sessionState, .playing)
        XCTAssertEqual(vm.remainingSeconds, 60)
        XCTAssertFalse(vm.isTimerRunning)

        vm.makeMove(boardIndex: 0, cellIndex: 0)
        XCTAssertEqual(vm.currentMark, .o)
        XCTAssertTrue(vm.isTimerRunning)

        for expected in stride(from: 59, through: 1, by: -1) {
            timer.simulateOneSecondPassed()
            try await Task.sleep(nanoseconds: 10_000_000)
            XCTAssertEqual(vm.remainingSeconds, expected)
        }

        XCTAssertEqual(vm.remainingSeconds, 1)
        XCTAssertEqual(vm.sessionState, .playing)

        let movesBeforeExpiry = vm.stats.totalMoves

        timer.simulateFinish()

        try await Task.sleep(nanoseconds: 50_000_000)
        await Task.yield()

        XCTAssertEqual(vm.sessionState, .completed)
        XCTAssertEqual(vm.completionReason, .oTimedOut)
        XCTAssertEqual(vm.remainingSeconds, 0)

        XCTAssertEqual(
            vm.stats.totalMoves,
            movesBeforeExpiry,
            "Potezi se ne smeju povećavati posle isteka sata."
        )

        try await Task.sleep(nanoseconds: 180_000_000)
        await Task.yield()

        XCTAssertEqual(vm.stats.totalMoves, movesBeforeExpiry, "No stale AI applies long after completion.")
    }
}

#endif
