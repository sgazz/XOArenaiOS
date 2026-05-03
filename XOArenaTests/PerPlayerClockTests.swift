//
//  PerPlayerClockTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

@MainActor
final class PerPlayerClockTests: XCTestCase {
    private func makeVM(timer: MockGameTimerService, session: GameSession? = nil) -> GameViewModel {
        GameViewModel(session: session, timerService: timer, now: { timer.clock.date })
    }

    func test_initial_both_banks_equal_selected_duration() throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)
        vm.startNewGame(mode: .soloFocus, duration: .threeMinutes)
        XCTAssertEqual(vm.xRemainingSeconds, 180)
        XCTAssertEqual(vm.oRemainingSeconds, 180)
        XCTAssertNil(timer.startedSeconds)

        vm.makeMove(boardIndex: 0, cellIndex: 0)
        XCTAssertEqual(timer.startedSeconds, 180)
        XCTAssertEqual(vm.currentMark, .o)
    }

    func test_mock_timer_restarts_on_opponent_turn_local_duel() async throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)
        vm.startNewGame(mode: .localDuel, duration: .oneMinute)
        XCTAssertNil(timer.startedSeconds)

        vm.makeMove(boardIndex: 0, cellIndex: 0)
        XCTAssertEqual(vm.currentMark, .o)
        XCTAssertEqual(timer.startedSeconds, 60)
        XCTAssertEqual(vm.xRemainingSeconds, 60)
        XCTAssertEqual(vm.oRemainingSeconds, 60)

        timer.simulateSecondsPassed(GameDuration.oneMinute.seconds - 52)
        await waitUntil("O bank drains to 52", timeoutNs: 300_000_000) {
            vm.oRemainingSeconds == 52 && vm.xRemainingSeconds == 60
        }

        vm.makeMove(boardIndex: 0, cellIndex: 1)
        XCTAssertEqual(vm.currentMark, .x)
        XCTAssertEqual(timer.startedSeconds, 60)
        XCTAssertEqual(vm.xRemainingSeconds, 60)
        XCTAssertEqual(vm.oRemainingSeconds, 52)
    }

    func test_local_duel_X_turn_tick_only_X_bank_decreases() async throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)
        vm.startNewGame(mode: .localDuel, duration: .oneMinute)
        XCTAssertEqual(vm.currentMark, .x)

        vm.makeMove(boardIndex: 0, cellIndex: 0)
        vm.makeMove(boardIndex: 0, cellIndex: 1)
        XCTAssertEqual(vm.currentMark, .x)

        let oFrozen = vm.oRemainingSeconds
        let xBefore = vm.xRemainingSeconds

        timer.simulateOneSecondPassed()
        await Task.yield()

        XCTAssertEqual(vm.oRemainingSeconds, oFrozen)
        XCTAssertLessThan(vm.xRemainingSeconds, xBefore)
    }

    func test_draw_bonus_adds_five_to_each_bank_after_board_draw() throws {
        let timer = MockGameTimerService()
        var s = GameEngine.makeInitialSession(mode: .soloFocus)
        s.boards[0] = TestBoardFixture.board(
            with: [
                .x, .o, .x,
                .x, .o, .o,
                .o, .x, .empty
            ],
            phase: .secondMove
        )
        s.boards[0].startingMark = .x
        s.activeBoardIndex = 0

        let vm = makeVM(timer: timer, session: s)
        XCTAssertEqual(vm.xRemainingSeconds, GameDuration.oneMinute.seconds)
        XCTAssertEqual(vm.oRemainingSeconds, GameDuration.oneMinute.seconds)

        vm.onGameViewAppear()
        vm.makeMove(boardIndex: 0, cellIndex: 8)

        XCTAssertEqual(vm.stats.boardDraws, 1)
        XCTAssertEqual(vm.xRemainingSeconds, GameDuration.oneMinute.seconds + 5)
        XCTAssertEqual(vm.oRemainingSeconds, GameDuration.oneMinute.seconds + 5)
    }

    func test_on_time_timer_ticks_each_reduce_active_bank_by_exactly_one_second() async throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)
        vm.startNewGame(mode: .vsAI, duration: .oneMinute)
        vm.makeMove(boardIndex: 0, cellIndex: 0)
        XCTAssertEqual(vm.currentMark, .o)
        XCTAssertEqual(vm.oRemainingSeconds, 60)

        for expected in stride(from: 59, through: 56, by: -1) {
            try await Task.sleep(nanoseconds: 15_000_000)
            timer.advanceClockAndDeliverTick(seconds: 1, lateSlip: 0)
            try await Task.sleep(nanoseconds: 15_000_000)
            XCTAssertEqual(vm.oRemainingSeconds, expected)
        }
        XCTAssertEqual(vm.xRemainingSeconds, 60)
    }

    func test_deadline_to_bank_never_steals_extra_second_when_timer_tick_arrives_fractionally_late() async throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)
        vm.startNewGame(mode: .vsAI, duration: .oneMinute)
        vm.makeMove(boardIndex: 0, cellIndex: 0)
        XCTAssertEqual(vm.currentMark, .o)
        XCTAssertEqual(vm.oRemainingSeconds, 60)

        try await Task.sleep(nanoseconds: 15_000_000)

        timer.advanceClockAndDeliverTick(seconds: 1, lateSlip: 0)
        try await Task.sleep(nanoseconds: 15_000_000)
        XCTAssertEqual(vm.oRemainingSeconds, 59)

        timer.advanceClockAndDeliverTick(seconds: 1, lateSlip: 0.73)
        try await Task.sleep(nanoseconds: 15_000_000)
        XCTAssertEqual(
            vm.oRemainingSeconds,
            58,
            "Stari „floor(interval)“ bi ovde mogao javiti 57 ako je **`dt`** palo tek ispod celog broja."
        )

        XCTAssertEqual(vm.xRemainingSeconds, 60)
    }

    func test_vs_ai_after_human_only_active_mark_bank_decreases_on_tick() async throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)
        vm.startNewGame(mode: .vsAI, duration: .oneMinute)

        XCTAssertEqual(vm.currentMark, .x)
        vm.makeMove(boardIndex: 0, cellIndex: 0)
        XCTAssertEqual(vm.currentMark, .o)

        let xFrozen = vm.xRemainingSeconds
        let oBefore = vm.oRemainingSeconds

        await Task.yield()
        timer.simulateOneSecondPassed()
        await Task.yield()

        XCTAssertEqual(vm.xRemainingSeconds, xFrozen)
        XCTAssertLessThan(vm.oRemainingSeconds, oBefore)
        XCTAssertGreaterThanOrEqual(vm.oRemainingSeconds, 0)
    }
}
