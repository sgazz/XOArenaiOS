//
//  GameEngineTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class GameEngineTests: XCTestCase {
    func test_cannot_play_occupied_cell() throws {
        var s = GameEngine.makeInitialSession(mode: .soloFocus)
        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 0) // X on board 0
        XCTAssertEqual(s.activeBoardIndex, 0)
        XCTAssertEqual(s.boards[0].turnPhase, .secondMove)
        XCTAssertEqual(s.boards[0].cells[0].mark, .x)
        XCTAssertThrowsError(try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 0)) { err in
            XCTAssertEqual(err as? MoveError, MoveError.cellOccupied)
        }
    }

    func test_phase_switches_first_then_second_before_advancing() throws {
        var s = GameEngine.makeInitialSession(mode: .soloFocus)
        XCTAssertEqual(s.activeBoardIndex, 0)
        XCTAssertEqual(s.boards[0].turnPhase, .firstMove)
        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 4)
        XCTAssertEqual(s.activeBoardIndex, 0)
        XCTAssertEqual(s.boards[0].turnPhase, .secondMove)
        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 1)
        XCTAssertEqual(s.activeBoardIndex, 1)
        XCTAssertEqual(s.boards[1].turnPhase, .firstMove)
    }

    func test_invalid_move_does_not_change_phase_or_focus() throws {
        let s = GameEngine.makeInitialSession(mode: .soloFocus)
        XCTAssertEqual(s.activeBoardIndex, 0)
        XCTAssertThrowsError(try GameEngine.applyMove(s, boardIndex: 1, cellIndex: 0)) { err in
            XCTAssertEqual(err as? MoveError, .wrongBoard(expected: 0, attempted: 1))
        }
        XCTAssertEqual(s.activeBoardIndex, 0)
        XCTAssertEqual(s.boards[0].turnPhase, .firstMove)
    }

    func test_focus_advances_after_o_move() throws {
        var s = GameEngine.makeInitialSession(mode: .soloFocus)
        XCTAssertEqual(s.activeBoardIndex, 0)
        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 0) // X
        XCTAssertEqual(s.activeBoardIndex, 0)
        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 1) // O
        XCTAssertEqual(s.activeBoardIndex, 1)
        s = try GameEngine.applyMove(s, boardIndex: 1, cellIndex: 0) // X
        XCTAssertEqual(s.activeBoardIndex, 1)
        s = try GameEngine.applyMove(s, boardIndex: 1, cellIndex: 1) // O
        XCTAssertEqual(s.activeBoardIndex, 2)
    }

    func test_focus_cycles_from_board8_back_to_board1() throws {
        var s = GameEngine.makeInitialSession(mode: .soloFocus)
        s.activeBoardIndex = GameConstants.boardCount - 1
        s.boards[s.activeBoardIndex].turnPhase = .secondMove
        s = try GameEngine.applyMove(s, boardIndex: GameConstants.boardCount - 1, cellIndex: 0)
        XCTAssertEqual(s.activeBoardIndex, 0)
        XCTAssertEqual(s.boards[0].turnPhase, .firstMove)
    }

    func test_board_completes_after_x_move_and_resets_and_advances() throws {
        var s = GameEngine.makeInitialSession(mode: .soloFocus)
        s.boards[0] = TestBoardFixture.board(with: [
            .x, .x, .empty,
            .o, .empty, .o,
            .empty, .empty, .empty
        ], phase: .firstMove)
        s.boards[0].startingMark = .x
        s.activeBoardIndex = 0

        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 2) // X wins immediately
        XCTAssertTrue(s.boards[0].cells.allSatisfy { $0.mark == .empty })
        XCTAssertEqual(s.boards[0].startingMark, .o)
        XCTAssertEqual(s.boards[0].turnPhase, .firstMove)
        XCTAssertEqual(s.activeBoardIndex, 1)
        XCTAssertEqual(s.boards[1].turnPhase, .firstMove)
    }

    func test_draw_resets_board_and_switches_starter() throws {
        var s = GameEngine.makeInitialSession(mode: .soloFocus)
        s.boards[0] = TestBoardFixture.board(with: [
            .x, .o, .x,
            .x, .o, .o,
            .o, .x, .empty
        ], phase: .secondMove)
        s.boards[0].startingMark = .x
        s.activeBoardIndex = 0

        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 8) // O draws board
        XCTAssertEqual(s.stats.boardDraws, 1)
        XCTAssertTrue(s.boards[0].cells.allSatisfy { $0.mark == .empty })
        XCTAssertEqual(s.boards[0].startingMark, .o)
        XCTAssertEqual(s.boards[0].turnPhase, .firstMove)
        XCTAssertEqual(s.activeBoardIndex, 1)
    }

    func test_x_win_updates_x_board_wins_counter() throws {
        var s = GameEngine.makeInitialSession(mode: .vsAI)
        s.boards[0] = TestBoardFixture.board(with: [
            .x, .x, .empty,
            .o, .empty, .o,
            .empty, .empty, .empty
        ], phase: .firstMove)
        s.boards[0].startingMark = .x
        s.activeBoardIndex = 0

        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 2)
        XCTAssertEqual(s.stats.xBoardWins, 1)
        XCTAssertEqual(s.stats.oBoardWins, 0)
        XCTAssertEqual(s.stats.boardDraws, 0)
    }

    func test_o_win_updates_o_board_wins_counter() throws {
        var s = GameEngine.makeInitialSession(mode: .vsAI)
        s.boards[0] = TestBoardFixture.board(with: [
            .o, .o, .empty,
            .x, .x, .empty,
            .empty, .empty, .empty
        ], startingMark: .x, phase: .secondMove)
        s.boards[0].startingMark = .x
        s.activeBoardIndex = 0

        s = try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 2)
        XCTAssertEqual(s.stats.oBoardWins, 1)
        XCTAssertEqual(s.stats.xBoardWins, 0)
        XCTAssertEqual(s.stats.boardDraws, 0)
    }

    func test_completed_session_rejects_moves() throws {
        let s = GameSession(
            boards: Array(repeating: XOBoard.empty, count: GameConstants.boardCount),
            activeBoardIndex: 0,
            gameMode: .soloFocus,
            aiDifficulty: .hard,
            stats: .zero,
            sessionState: .completed,
            humanControlledMark: nil
        )
        XCTAssertThrowsError(try GameEngine.applyMove(s, boardIndex: 0, cellIndex: 0)) { err in
            XCTAssertEqual(err as? MoveError, .sessionNotActive)
        }
    }
}
