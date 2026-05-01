//
//  VsAIGameplayTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

/// **`GameMode.vsAI`** host rules versus **`GameViewModel`** (timer AI delay, **`HumanInputGate`**, reset / expiry cancelling central AI).
@MainActor
final class VsAIGameplayTests: XCTestCase {
    func test_vsAI_gate_rejects_human_while_AI_thinking_mid_delay() async throws {
        let timer = MockGameTimerService()
        let vm = GameViewModel(timerService: timer)
        vm.startNewGame(mode: .vsAI, duration: .oneMinute)

        vm.makeMove(boardIndex: 0, cellIndex: 0)
        await Task.yield()
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertTrue(vm.isAIThinking, "Expected central AI to flip thinking on before random delay elapses.")
        XCTAssertFalse(vm.allowsHumanPlacement(boardIndex: 0, cellIndex: 4))
    }

    func test_vsAI_human_X_locked_after_first_move_waiting_for_O() throws {
        let timer = MockGameTimerService()
        let vm = GameViewModel(timerService: timer)

        vm.startNewGame(mode: .vsAI, duration: .oneMinute)
        XCTAssertFalse(vm.isInputLocked)
        XCTAssertTrue(vm.allowsHumanPlacement(boardIndex: 0, cellIndex: 4))

        vm.makeMove(boardIndex: 0, cellIndex: 0)
        XCTAssertEqual(vm.currentMark, .o)
        XCTAssertTrue(vm.isInputLocked)
        XCTAssertFalse(vm.allowsHumanPlacement(boardIndex: 0, cellIndex: 1))
    }

    func test_vsAI_human_rejected_after_session_completed_via_timer() async throws {
        let timer = MockGameTimerService()
        let vm = GameViewModel(timerService: timer)
        vm.startNewGame(mode: .vsAI, duration: .oneMinute)

        let before = vm.stats.totalMoves
        timer.simulateFinish()
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(vm.sessionState, .completed)
        XCTAssertFalse(vm.allowsHumanPlacement(boardIndex: 0, cellIndex: 0))

        vm.makeMove(boardIndex: 0, cellIndex: 0)
        XCTAssertEqual(vm.stats.totalMoves, before)
    }

    func test_vsAI_reset_without_stray_AI_marks_after_immediate_human_X() async throws {
        let timer = MockGameTimerService()
        let vm = GameViewModel(timerService: timer)
        vm.startNewGame(mode: .vsAI, duration: .oneMinute)

        vm.makeMove(boardIndex: 0, cellIndex: 0)
        vm.resetGame()

        try await Task.sleep(nanoseconds: 950_000_000)
        await Task.yield()

        XCTAssertEqual(vm.sessionState, .playing)
        XCTAssertEqual(vm.stats.totalMoves, 0)
        XCTAssertTrue(vm.boards.allSatisfy { slab in
            slab.cells.allSatisfy { $0.mark == .empty }
        })
    }

    func test_vsAI_scores_track_after_engine_style_X_then_O_round() throws {
        var s = GameEngine.makeInitialSession(mode: .vsAI)
        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 0)
        let aiCell = TicTacToeAI.chooseMove(on: s.boards[0], aiMark: .o, humanMark: .x) ?? 1
        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: aiCell)
        XCTAssertEqual(s.stats.totalMoves, 2)
        XCTAssertEqual(s.activeBoardIndex, 1)
    }

    func test_vsAI_seeded_O_starter_active_slab_gets_O_from_central_ai() async throws {
        var seeded = GameEngine.makeInitialSession(mode: .vsAI)
        seeded.activeBoardIndex = 3
        seeded.boards[3].startingMark = .o
        seeded.boards[3].turnPhase = .firstMove

        let vm = GameViewModel(session: seeded, timerService: MockGameTimerService())
        vm.onGameViewAppear()
        try await Task.sleep(nanoseconds: 700_000_000)
        await Task.yield()

        XCTAssertEqual(vm.activeBoardIndex, 3)
        XCTAssertEqual(vm.boards[3].startingMark, .o)
        let oCount = vm.boards[3].cells.filter { $0.mark == .o }.count
        XCTAssertEqual(oCount, 1, "When **`nextStarter`** is **O** and slab is active, central AI should open as **O**.")
        XCTAssertEqual(vm.currentMark, .x)
    }
}
