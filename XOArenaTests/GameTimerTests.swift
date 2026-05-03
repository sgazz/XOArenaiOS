//
//  GameTimerTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

@MainActor
final class GameTimerTests: XCTestCase {
    private func makeVM(timer: MockGameTimerService) -> GameViewModel {
        GameViewModel(timerService: timer, now: { timer.clock.date })
    }

    func test_timer_starts_with_selected_duration() throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)

        vm.startNewGame(mode: .soloFocus, duration: .oneMinute)

        XCTAssertEqual(vm.selectedDuration, .oneMinute)
        XCTAssertEqual(vm.remainingSeconds, 60)
        XCTAssertTrue(vm.isTimerRunning)
        XCTAssertEqual(timer.startedSeconds, 60)
    }

    func test_timer_reaching_zero_completes_session() async throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)

        vm.startNewGame(mode: .soloFocus, duration: .oneMinute)
        timer.simulateFinish()
        await Task.yield()

        XCTAssertEqual(vm.sessionState, .completed)
        XCTAssertEqual(vm.remainingSeconds, 0)
        XCTAssertEqual(vm.completionReason, .xTimedOut)
        XCTAssertTrue(vm.isInputLocked)
    }

    func test_reset_restores_remaining_time() async throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)

        vm.startNewGame(mode: .localDuel, duration: .fiveMinutes)
        timer.simulateSecondsPassed(59)
        await Task.yield()
        XCTAssertEqual(vm.remainingSeconds, 241)

        vm.resetGame()
        XCTAssertEqual(vm.remainingSeconds, 300)
        XCTAssertEqual(vm.xRemainingSeconds, 300)
        XCTAssertEqual(vm.oRemainingSeconds, 300)
        XCTAssertEqual(vm.selectedDuration, .fiveMinutes)
        XCTAssertEqual(vm.sessionState, .playing)
    }

    func test_new_session_uses_selected_duration() throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)

        vm.selectDuration(.oneMinute)
        vm.startNewGame(mode: .vsAI, duration: .oneMinute)
        XCTAssertEqual(vm.remainingSeconds, 60)

        vm.startNewGame(mode: .soloFocus, duration: .threeMinutes)
        XCTAssertEqual(vm.remainingSeconds, 180)
    }

    func test_ai_does_not_move_after_timeout() async throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)
        vm.startNewGame(mode: .vsAI, duration: .oneMinute)

        vm.makeMove(boardIndex: 0, cellIndex: 0) // human X
        XCTAssertEqual(vm.currentMark, .o)

        timer.simulateFinish()
        try await Task.sleep(nanoseconds: 700_000_000)

        let oCount = vm.boards
            .flatMap(\.cells)
            .filter { $0.mark == .o }
            .count
        XCTAssertEqual(oCount, 0)
        XCTAssertEqual(vm.sessionState, .completed)
        XCTAssertEqual(vm.completionReason, .oTimedOut)
    }

    func test_manual_move_cannot_happen_after_timeout() async throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)
        vm.startNewGame(mode: .soloFocus, duration: .oneMinute)
        timer.simulateFinish()
        await Task.yield()

        let before = vm.stats.totalMoves
        vm.makeMove(boardIndex: 0, cellIndex: 0)

        XCTAssertEqual(vm.stats.totalMoves, before)
        XCTAssertEqual(vm.boards[0].cells[0].mark, .empty)
        XCTAssertEqual(vm.sessionState, .completed)
    }
}

