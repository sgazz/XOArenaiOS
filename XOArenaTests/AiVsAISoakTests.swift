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
    private func assertRemainingEventually(
        _ vm: GameViewModel,
        equals expected: Int,
        timeoutNs: UInt64 = 200_000_000,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let step: UInt64 = 2_000_000
        var elapsed: UInt64 = 0
        while elapsed <= timeoutNs {
            if vm.remainingSeconds == expected { return }
            await Task.yield()
            try? await Task.sleep(nanoseconds: step)
            elapsed += step
        }
        XCTFail(
            "Remaining time did not converge to \(expected)s (still \(vm.remainingSeconds)).",
            file: file,
            line: line
        )
    }

    func test_aiVsAI_soak_timerCompletion_noPostTimeoutMoves() async throws {
        let timer = MockGameTimerService()
        let vm = GameViewModel(timerService: timer)

        vm.startNewGame(mode: .aiVsAI, duration: .oneMinute)
        vm.aiVsAIDelayPreset = .instant

        XCTAssertEqual(vm.sessionState, .playing)
        XCTAssertEqual(vm.remainingSeconds, 60)

        for secs in stride(from: 59, through: 1, by: -1) {
            try await Task.sleep(nanoseconds: 12_000_000)
            await Task.yield()
            timer.simulateTick(secs)
            await assertRemainingEventually(vm, equals: secs)
        }

        XCTAssertEqual(vm.remainingSeconds, 1)
        XCTAssertEqual(vm.sessionState, .playing)

        try await Task.sleep(nanoseconds: 35_000_000)
        await Task.yield()

        XCTAssertGreaterThan(vm.stats.totalMoves, 12, "Autoplay should make many moves before timeout.")

        let movesBeforeExpiry = vm.stats.totalMoves

        timer.simulateFinish()

        try await Task.sleep(nanoseconds: 50_000_000)
        await Task.yield()

        for _ in 0..<450 {
            if vm.sessionState == .completed, !vm.isAIThinking {
                break
            }
            await Task.yield()
            try await Task.sleep(nanoseconds: 3_000_000)
        }

        XCTAssertEqual(vm.sessionState, .completed)
        XCTAssertEqual(vm.completionReason, .timeExpired)
        XCTAssertEqual(vm.remainingSeconds, 0)

        XCTAssertEqual(
            vm.stats.totalMoves,
            movesBeforeExpiry,
            "`MOVE_OK`/AI-applied totals must not advance after TIMER_TIMEOUT settles."
        )

        try await Task.sleep(nanoseconds: 180_000_000)
        await Task.yield()

        XCTAssertEqual(vm.stats.totalMoves, movesBeforeExpiry, "No stale AI applies long after completion.")
    }
}

#endif
