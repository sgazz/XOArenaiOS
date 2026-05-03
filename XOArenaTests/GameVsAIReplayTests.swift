//
//  GameVsAIReplayTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class GameVsAIReplayTests: XCTestCase {
    /// Mirrors host rules without **`GameViewModel`** delay: AI can start when board starter is O.
    func test_ai_can_start_board_when_starter_is_o() throws {
        var session = GameEngine.makeInitialSession(mode: .vsAI)
        session.boards[0].startingMark = .o
        session.boards[0].turnPhase = .firstMove
        XCTAssertEqual(session.currentMarkForActiveBoard, .o)

        let active = session.activeBoardIndex
        let slab = session.boards[active]
        guard let aiCell = TicTacToeAI.chooseMove(on: slab, aiMark: .o, humanMark: .x) else {
            XCTFail("expected AI move")
            return
        }
        session = try GameEngine.applyMove(session, boardIndex: active, cellIndex: aiCell)
        XCTAssertEqual(session.activeBoardIndex, 0)
        XCTAssertEqual(session.boards[0].turnPhase, .secondMove)
        XCTAssertEqual(session.currentMarkForActiveBoard, .x)
    }

    func test_two_move_cycle_advances_after_second_move() throws {
        var session = GameEngine.makeInitialSession(mode: .vsAI)
        session = try GameEngine.applyMove(session, boardIndex: 0, cellIndex: 0) // X first
        let aiCell = TicTacToeAI.chooseMove(on: session.boards[0], aiMark: .o, humanMark: .x) ?? 1
        session = try GameEngine.applyMove(session, boardIndex: 0, cellIndex: aiCell) // O second
        XCTAssertEqual(session.activeBoardIndex, 1)
        XCTAssertEqual(session.boards[1].turnPhase, .firstMove)
    }

    @MainActor
    func test_view_model_schedules_ai_when_o_starts_board() async throws {
        var seeded = GameEngine.makeInitialSession(mode: .vsAI)
        var slab0 = seeded.boards[0]
        slab0.startingMark = .o
        slab0.turnPhase = .firstMove
        seeded.boards[0] = slab0

        let timer = MockGameTimerService()
        let vm = GameViewModel(session: seeded, timerService: timer, now: { timer.clock.date })
        vm.aiThinkDelayNanosecondsOverrideForTests = 0
        vm.onGameViewAppear()
        await Task.yield()

        await waitUntil(
            "AI places O then human X acts",
            timeoutNs: 3_000_000_000
        ) {
            vm.boards[0].cells.filter { $0.mark == .o }.count == 1 && vm.currentMark == .x
        }

        XCTAssertEqual(vm.activeBoardIndex, 0)
        XCTAssertEqual(vm.currentMark, .x)
        XCTAssertEqual(vm.boards[0].cells.filter { $0.mark == .o }.count, 1)
    }
}
