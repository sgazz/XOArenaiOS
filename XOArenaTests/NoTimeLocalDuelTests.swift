//
//  NoTimeLocalDuelTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class ClassicDuelCompletionTests: XCTestCase {
    func test_completion_nil_until_eight_board_results() {
        let stats = GameStats(totalMoves: 10, xBoardWins: 3, oBoardWins: 3, boardDraws: 1)
        XCTAssertEqual(ClassicDuelCompletion.completedBoardCount(stats), 7)
        XCTAssertNil(ClassicDuelCompletion.completionReason(for: stats))
    }

    func test_completion_x_wins_on_board_count() {
        let stats = GameStats(totalMoves: 16, xBoardWins: 5, oBoardWins: 2, boardDraws: 1)
        XCTAssertEqual(ClassicDuelCompletion.completionReason(for: stats), .xWinsOnBoardCount)
    }

    func test_completion_o_wins_on_board_count() {
        let stats = GameStats(totalMoves: 16, xBoardWins: 2, oBoardWins: 5, boardDraws: 1)
        XCTAssertEqual(ClassicDuelCompletion.completionReason(for: stats), .oWinsOnBoardCount)
    }

    func test_completion_draw_on_equal_board_wins() {
        let stats = GameStats(totalMoves: 16, xBoardWins: 4, oBoardWins: 4, boardDraws: 0)
        XCTAssertEqual(ClassicDuelCompletion.completionReason(for: stats), .drawOnBoardCount)
    }
}

@MainActor
final class NoTimeLocalDuelTests: XCTestCase {
    private func makeVM(timer: MockGameTimerService, session: GameSession? = nil) -> GameViewModel {
        GameViewModel(session: session, timerService: timer, now: { timer.clock.date })
    }

    private static func oneMoveXWinBoard() -> XOBoard {
        TestBoardFixture.board(
            with: [
                .x, .x, .empty,
                .o, .empty, .o,
                .empty, .empty, .empty
            ],
            phase: .firstMove
        )
    }

    func test_no_time_pvp_does_not_start_clocks() throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)
        vm.startNewGame(mode: .localDuel, duration: .noTime)
        XCTAssertTrue(vm.isNoTimeLocalDuel)
        XCTAssertEqual(vm.xRemainingSeconds, 0)
        XCTAssertEqual(vm.oRemainingSeconds, 0)

        vm.makeMove(boardIndex: 0, cellIndex: 0)
        XCTAssertNil(timer.startedSeconds)

        timer.simulateOneSecondPassed()
        XCTAssertEqual(vm.xRemainingSeconds, 0)
        XCTAssertEqual(vm.oRemainingSeconds, 0)
    }

    func test_no_time_pvp_does_not_apply_time_economy_on_board_win() throws {
        let timer = MockGameTimerService()
        var s = GameEngine.makeInitialSession(mode: .localDuel)
        s.boards[0] = Self.oneMoveXWinBoard()
        s.boards[0].startingMark = .x
        s.activeBoardIndex = 0

        let vm = makeVM(timer: timer, session: s)
        vm.selectDuration(.noTime)
        let xBefore = vm.xRemainingSeconds
        let oBefore = vm.oRemainingSeconds
        vm.onGameViewAppear()
        vm.makeMove(boardIndex: 0, cellIndex: 2)

        XCTAssertEqual(vm.stats.xBoardWins, 1)
        XCTAssertEqual(vm.xRemainingSeconds, xBefore)
        XCTAssertEqual(vm.oRemainingSeconds, oBefore)
        XCTAssertNil(vm.latestTimeReward)
    }

    func test_no_time_pvp_completes_after_eighth_board_result_x_wins() throws {
        let timer = MockGameTimerService()
        var s = GameEngine.makeInitialSession(mode: .localDuel)
        s.stats = GameStats(totalMoves: 20, xBoardWins: 5, oBoardWins: 1, boardDraws: 1)
        s.boards[0] = Self.oneMoveXWinBoard()
        s.boards[0].startingMark = .x
        s.activeBoardIndex = 0

        let vm = makeVM(timer: timer, session: s)
        vm.selectDuration(.noTime)
        vm.onGameViewAppear()
        vm.makeMove(boardIndex: 0, cellIndex: 2)

        XCTAssertTrue(vm.isSessionComplete)
        XCTAssertEqual(vm.completionReason, .xWinsOnBoardCount)
        XCTAssertEqual(vm.stats.xBoardWins, 6)
    }

    func test_no_time_pvp_draw_when_board_wins_tied_after_eight_boards() throws {
        let timer = MockGameTimerService()
        var s = GameEngine.makeInitialSession(mode: .localDuel)
        s.stats = GameStats(totalMoves: 20, xBoardWins: 3, oBoardWins: 3, boardDraws: 1)
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
        vm.selectDuration(.noTime)
        vm.onGameViewAppear()
        vm.makeMove(boardIndex: 0, cellIndex: 8)

        XCTAssertTrue(vm.isSessionComplete)
        XCTAssertEqual(vm.completionReason, .drawOnBoardCount)
        XCTAssertEqual(vm.stats.xBoardWins, 3)
        XCTAssertEqual(vm.stats.oBoardWins, 3)
        XCTAssertEqual(vm.stats.boardDraws, 2)
    }

    func test_timed_local_duel_still_runs_clocks() throws {
        let timer = MockGameTimerService()
        let vm = makeVM(timer: timer)
        vm.startNewGame(mode: .localDuel, duration: .oneMinute)
        XCTAssertFalse(vm.isNoTimeLocalDuel)
        vm.makeMove(boardIndex: 0, cellIndex: 0)
        XCTAssertEqual(timer.startedSeconds, 60)
    }
}
