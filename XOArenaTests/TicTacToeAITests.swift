//
//  TicTacToeAITests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class TicTacToeAITests: XCTestCase {
    func test_ranked_moves_are_sorted_descending_by_score_then_index() throws {
        let board = TestBoardFixture.board(with: [
            .x, .empty, .o,
            .empty, .x, .empty,
            .empty, .empty, .o
        ])
        let r = TicTacToeAI.rankedMoves(on: board, aiMark: .o, humanMark: .x)
        XCTAssertFalse(r.isEmpty)
        for i in 0..<(r.count - 1) {
            let a = r[i].score
            let b = r[i + 1].score
            if a == b {
                XCTAssertLessThan(r[i].index, r[i + 1].index, "tie-break by ascending cell index")
            } else {
                XCTAssertGreaterThan(a, b)
            }
        }
    }

    func test_hard_still_blocks_obvious_human_win_line_even_with_extreme_rng() throws {
        let board = TestBoardFixture.board(with: [
            .x, .x, .empty,
            .o, .empty, .empty,
            .empty, .empty, .empty
        ])
        let ctxComfort = AIMoveTimerContext(remainingSeconds: 1_000, totalSeconds: 1_000)
        XCTAssertEqual(
            TicTacToeAI.chooseMove(on: board, aiMark: .o, humanMark: .x, difficulty: .hard, timerContext: ctxComfort, randomUnit: { 0.999 }),
            2
        )
        let ctxPanic = AIMoveTimerContext(remainingSeconds: 0, totalSeconds: 100)
        XCTAssertEqual(
            TicTacToeAI.chooseMove(on: board, aiMark: .o, humanMark: .x, difficulty: .hard, timerContext: ctxPanic, randomUnit: { 0.999 }),
            2
        )
    }

    func test_hard_ai_takes_winning_move_when_ai_is_O_after_tactics_fallback() throws {
        let board = TestBoardFixture.board(with: [
            .x, .o, .x,
            .o, .x, .o,
            .o, .o, .empty
        ])
        XCTAssertEqual(
            TicTacToeAI.chooseMove(on: board, aiMark: .o, humanMark: .x, difficulty: .hard),
            8
        )
    }

    func test_medium_always_blocks_obvious_human_win_line() throws {
        let board = TestBoardFixture.board(with: [
            .x, .x, .empty,
            .o, .empty, .empty,
            .empty, .empty, .empty
        ])
        XCTAssertEqual(
            TicTacToeAI.chooseMove(on: board, aiMark: .o, humanMark: .x, difficulty: .medium),
            2
        )
    }

    func test_medium_takes_own_immediate_win_before_ranked_shuffle() throws {
        let board = TestBoardFixture.board(with: [
            .o, .o, .empty,
            .x, .x, .empty,
            .empty, .empty, .empty
        ])
        XCTAssertEqual(
            TicTacToeAI.chooseMove(on: board, aiMark: .o, humanMark: .x, difficulty: .medium),
            2
        )
    }

    func test_medium_without_tactics_always_picks_within_top_three_rank_when_comfortable_timer() throws {
        let board = TestBoardFixture.board(with: [
            .x, .empty, .empty,
            .empty, .empty, .empty,
            .empty, .empty, .empty
        ])
        let ranked = TicTacToeAI.rankedMoves(on: board, aiMark: .o, humanMark: .x)
        let allowed = Set(ranked.prefix(min(3, ranked.count)).map(\.index))
        let ctxOk = AIMoveTimerContext(remainingSeconds: 100, totalSeconds: 100)
        for i in 0..<50 {
            let u = Double(i) / 50.0
            guard let idx = TicTacToeAI.chooseMove(
                on: board,
                aiMark: .o,
                humanMark: .x,
                difficulty: .medium,
                timerContext: ctxOk,
                randomUnit: { u }
            ) else {
                XCTFail("expected move"); return
            }
            XCTAssertTrue(allowed.contains(idx), "\(idx) not in \(allowed) for rng \(u)")
        }
    }

    func test_easy_returns_valid_moves_repeated_trials() throws {
        let board = TestBoardFixture.board(with: [
            .x, .empty, .empty,
            .empty, .o, .empty,
            .empty, .empty, .empty
        ])
        for i in 0..<80 {
            let u = Double(i) / 80.0
            guard let idx = TicTacToeAI.chooseMove(
                on: board,
                aiMark: .o,
                humanMark: .x,
                difficulty: .easy,
                timerContext: nil,
                randomUnit: { u }
            ) else {
                XCTFail(); return
            }
            XCTAssertEqual(board.cells[idx].mark, .empty)
        }
    }

    func test_easy_when_filtered_safe_moves_reduce_to_blocking_cell_still_respects_that_cell() throws {
        let board = TestBoardFixture.board(with: [
            .x, .x, .empty,
            .o, .empty, .empty,
            .empty, .empty, .empty
        ])
        let ctxComfort = AIMoveTimerContext(remainingSeconds: 500, totalSeconds: 500)
        for i in 0..<48 {
            let u = Double(i) / 48.0
            guard let idx = TicTacToeAI.chooseMove(
                on: board,
                aiMark: .o,
                humanMark: .x,
                difficulty: .easy,
                timerContext: ctxComfort,
                randomUnit: { u }
            ) else {
                XCTFail(); return
            }
            XCTAssertEqual(idx, 2, "Unique non-losing replies should collapse randomness.")
        }
    }

    func test_hard_ai_blocks_when_ai_is_X() throws {
        let board = TestBoardFixture.board(with: [
            .o, .o, .empty,
            .x, .empty, .empty,
            .empty, .empty, .empty
        ])
        XCTAssertEqual(
            TicTacToeAI.chooseMove(on: board, aiMark: .x, humanMark: .o, difficulty: .hard),
            2
        )
    }

    func test_ai_never_chooses_occupied_cell_all_difficulties() throws {
        let board = TestBoardFixture.board(with: [
            .x, .empty, .o,
            .empty, .x, .empty,
            .o, .empty, .empty
        ])

        for i in 0..<32 {
            let u = Double(i) / 32.0
            guard let e = TicTacToeAI.chooseMove(on: board, aiMark: .o, humanMark: .x, difficulty: .easy, timerContext: nil, randomUnit: { u })
            else {
                XCTFail(); return
            }
            XCTAssertEqual(board.cells[e].mark, .empty)
        }

        let ctx = AIMoveTimerContext(remainingSeconds: 999, totalSeconds: 999)
        for i in 0..<24 {
            let u = Double(i) / 24.0
            guard let m = TicTacToeAI.chooseMove(on: board, aiMark: .o, humanMark: .x, difficulty: .medium, timerContext: ctx, randomUnit: { u })
            else {
                XCTFail(); return
            }
            XCTAssertEqual(board.cells[m].mark, .empty)
        }

        for i in 0..<24 {
            let u = Double(i) / 24.0
            guard let h = TicTacToeAI.chooseMove(on: board, aiMark: .o, humanMark: .x, difficulty: .hard, timerContext: ctx, randomUnit: { u })
            else {
                XCTFail(); return
            }
            XCTAssertEqual(board.cells[h].mark, .empty)
        }
    }

    func test_hard_takes_center_when_no_immediate_line_threat() throws {
        let board = TestBoardFixture.board(with: [
            .x, .empty, .empty,
            .empty, .empty, .empty,
            .empty, .empty, .empty
        ])
        XCTAssertEqual(
            TicTacToeAI.chooseMove(
                on: board,
                aiMark: .o,
                humanMark: .x,
                difficulty: .hard,
                timerContext: AIMoveTimerContext(remainingSeconds: 500, totalSeconds: 500),
                randomUnit: { 0 }
            ),
            4
        )
    }

    func test_hard_under_low_timer_may_leave_center_via_wider_sampling() throws {
        let board = TestBoardFixture.board(with: [
            .x, .empty, .empty,
            .empty, .empty, .empty,
            .empty, .empty, .empty
        ])
        let ctxCritical = AIMoveTimerContext(remainingSeconds: 3, totalSeconds: 100)
        var sawNonCenter = false
        for i in 0..<64 {
            let u = Double(i) / 64.0
            let idx = TicTacToeAI.chooseMove(
                on: board,
                aiMark: .o,
                humanMark: .x,
                difficulty: .hard,
                timerContext: ctxCritical,
                randomUnit: { u }
            )
            XCTAssertNotNil(idx)
            if idx != 4 { sawNonCenter = true; break }
        }
        XCTAssertTrue(sawNonCenter, "Critical clock bucket should expose non-center picks.")
    }

    func test_ai_does_not_suggest_completed_board() throws {
        let board = TestBoardFixture.board(with: [
            .x, .x, .x,
            .o, .o, .empty,
            .empty, .empty, .empty
        ])
        XCTAssertNil(TicTacToeAI.chooseMove(on: board, aiMark: .o, humanMark: .x, difficulty: .hard))
        XCTAssertNil(TicTacToeAI.chooseMove(on: board, aiMark: .o, humanMark: .x, difficulty: .easy))
        XCTAssertNil(TicTacToeAI.rankedMoves(on: board, aiMark: .o, humanMark: .x).first?.index)
    }

    func test_ranked_moves_deterministic_across_calls() throws {
        let board = TestBoardFixture.board(with: [
            .x, .empty, .o,
            .empty, .x, .empty,
            .o, .empty, .empty
        ])
        let a = TicTacToeAI.rankedMoves(on: board, aiMark: .o, humanMark: .x)
        let b = TicTacToeAI.rankedMoves(on: board, aiMark: .o, humanMark: .x)
        XCTAssertFalse(a.isEmpty && b.isEmpty)
        XCTAssertEqual(a.map(\.index), b.map(\.index))
        XCTAssertEqual(a.map(\.score), b.map(\.score))
    }

    func test_hard_comfortable_second_tier_not_fixed_to_single_index_when_many_suboptimal() throws {
        let board = TestBoardFixture.board(with: [
            .x, .empty, .empty,
            .empty, .empty, .empty,
            .empty, .empty, .empty
        ])
        let ranked = TicTacToeAI.rankedMoves(on: board, aiMark: .o, humanMark: .x)
        let topScore = ranked[0].score
        let suboptimalIndices = ranked.filter { $0.score < topScore }.map(\.index)
        XCTAssertGreaterThanOrEqual(
            suboptimalIndices.count,
            2,
            "fixture needs ≥2 strictly suboptimal moves for this behavioral check"
        )

        let ctxComfort = AIMoveTimerContext(remainingSeconds: 100, totalSeconds: 100)
        var picks = Set<Int>()
        for trial in 0 ..< max(72, suboptimalIndices.count * 12) {
            var call = 0
            guard let idx = TicTacToeAI.chooseMove(
                on: board,
                aiMark: .o,
                humanMark: .x,
                difficulty: .hard,
                timerContext: ctxComfort,
                randomUnit: {
                    defer { call += 1 }
                    return call == 0
                        ? 0.95
                        : Double((trial * 65_537 + call) % 1000) / 1000.0
                }
            ) else {
                XCTFail("expected move"); return
            }
            XCTAssertTrue(suboptimalIndices.contains(idx))
            XCTAssertNotEqual(idx, 4)
            picks.insert(idx)
        }
        XCTAssertGreaterThanOrEqual(picks.count, 2)
    }

    func test_hard_low_pressure_second_tier_samples_multiple_when_available() throws {
        let board = TestBoardFixture.board(with: [
            .x, .empty, .empty,
            .empty, .empty, .empty,
            .empty, .empty, .empty
        ])
        let ranked = TicTacToeAI.rankedMoves(on: board, aiMark: .o, humanMark: .x)
        let topScore = ranked[0].score
        let suboptimalSorted = ranked.filter { $0.score < topScore }.map(\.index).sorted()

        XCTAssertGreaterThanOrEqual(suboptimalSorted.count, 2)

        let ctxLow = AIMoveTimerContext(remainingSeconds: 20, totalSeconds: 100)
        var picks = Set<Int>()
        for trial in 0 ..< 60 {
            var call = 0
            guard let idx = TicTacToeAI.chooseMove(
                on: board,
                aiMark: .o,
                humanMark: .x,
                difficulty: .hard,
                timerContext: ctxLow,
                randomUnit: {
                    defer { call += 1 }
                    return call == 0
                        ? 0.85
                        : Double((trial * 973 + call * 41) % 997) / 997.0
                }
            ) else {
                XCTFail("expected move"); return
            }
            XCTAssertTrue(suboptimalSorted.contains(idx))
            picks.insert(idx)
        }
        XCTAssertGreaterThanOrEqual(picks.count, 2)
    }

    func test_hard_critical_pressure_never_returns_invalid_cell() throws {
        let board = TestBoardFixture.board(with: [
            .x, .empty, .empty,
            .empty, .empty, .empty,
            .empty, .empty, .empty
        ])
        let ctxCritical = AIMoveTimerContext(remainingSeconds: 0, totalSeconds: 120)
        let legal = Set((0 ..< GameConstants.cellCount).filter { board.cells[$0].mark == .empty })

        for i in 0 ..< 120 {
            let u = Double(i) / Double(119)
            guard let idx = TicTacToeAI.chooseMove(
                on: board,
                aiMark: .o,
                humanMark: .x,
                difficulty: .hard,
                timerContext: ctxCritical,
                randomUnit: { u }
            ) else {
                XCTFail("expected move"); return
            }
            XCTAssertTrue(legal.contains(idx))
        }
    }

}
