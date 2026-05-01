//
//  BoardEvaluatorTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class BoardEvaluatorTests: XCTestCase {
    func testX_wins_horizontal_top_row() throws {
        let b = TestBoardFixture.board(with: [
            .x, .x, .x,
            .o, .o, .empty,
            .empty, .empty, .empty
        ])
        XCTAssertEqual(BoardEvaluator.winner(in: b), .x)
        XCTAssertFalse(BoardEvaluator.isDraw(b))
        if case .won(.x) = b.playState { } else {
            XCTFail("expected board won by X")
        }
    }

    func testO_wins_vertical_middle_column() throws {
        let b = TestBoardFixture.board(with: [
            .x, .o, .x,
            .x, .o, .empty,
            .empty, .o, .x
        ])
        XCTAssertEqual(BoardEvaluator.winner(in: b), .o)
        XCTAssertEqual(b.playState, .won(.o))
    }

    func testX_wins_diagonal_main() throws {
        let b = TestBoardFixture.board(with: [
            .x, .o, .o,
            .o, .x, .empty,
            .empty, .empty, .x
        ])
        XCTAssertEqual(BoardEvaluator.winner(in: b), .x)
    }

    func test_draw_no_winner_full_board() throws {
        let b = TestBoardFixture.board(with: [
            .x, .o, .x,
            .x, .o, .o,
            .o, .x, .x
        ])
        XCTAssertNil(BoardEvaluator.winner(in: b))
        XCTAssertTrue(BoardEvaluator.isDraw(b))
        XCTAssertEqual(b.playState, .drawn)
    }
}
