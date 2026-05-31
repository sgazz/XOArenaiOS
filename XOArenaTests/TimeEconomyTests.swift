//
//  TimeEconomyTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class TimeEconomyTests: XCTestCase {
    private let initial = 60

    // MARK: - PvP

    func test_pvp_board_win_x_gains_5_o_loses_3() {
        let rules = TimeEconomyRules.pvp
        let planned = TimeEconomyEngine.plannedAdjustment(
            outcome: .xWin,
            rules: rules,
            context: .pvp
        )
        XCTAssertEqual(planned?.xDelta, 5)
        XCTAssertEqual(planned?.oDelta, -3)

        var x = initial
        var o = initial
        let applied = TimeEconomyEngine.apply(planned!, xRemaining: &x, oRemaining: &o, initialDurationSeconds: initial)
        XCTAssertEqual(applied.xDelta, 5)
        XCTAssertEqual(applied.oDelta, -3)
        XCTAssertEqual(x, 65)
        XCTAssertEqual(o, 57)
    }

    func test_pvp_draw_both_gain_2() {
        let planned = TimeEconomyEngine.plannedAdjustment(
            outcome: .draw,
            rules: .pvp,
            context: .pvp
        )
        XCTAssertEqual(planned?.xDelta, 2)
        XCTAssertEqual(planned?.oDelta, 2)
    }

    // MARK: - PvAI tiers

    func test_easy_ai_human_win_shift() {
        let planned = TimeEconomyEngine.plannedAdjustment(
            outcome: .xWin,
            rules: .vsAI(difficulty: .easy),
            context: .vsAI(humanMark: .x, difficulty: .easy)
        )
        XCTAssertEqual(planned?.xDelta, 6)
        XCTAssertEqual(planned?.oDelta, -3)
    }

    func test_medium_ai_human_win_shift() {
        let planned = TimeEconomyEngine.plannedAdjustment(
            outcome: .oWin,
            rules: .vsAI(difficulty: .medium),
            context: .vsAI(humanMark: .o, difficulty: .medium)
        )
        XCTAssertEqual(planned?.xDelta, -4)
        XCTAssertEqual(planned?.oDelta, 8)
    }

    func test_hard_ai_human_win_shift() {
        let planned = TimeEconomyEngine.plannedAdjustment(
            outcome: .xWin,
            rules: .vsAI(difficulty: .hard),
            context: .vsAI(humanMark: .x, difficulty: .hard)
        )
        XCTAssertEqual(planned?.xDelta, 12)
        XCTAssertEqual(planned?.oDelta, -5)
    }

    func test_ai_board_win_applies_no_reward() {
        let planned = TimeEconomyEngine.plannedAdjustment(
            outcome: .oWin,
            rules: .vsAI(difficulty: .medium),
            context: .vsAI(humanMark: .x, difficulty: .medium)
        )
        XCTAssertNil(planned)
    }

    func test_vsai_draw_human_gains_2_ai_unchanged() {
        let rules = TimeEconomyRules.vsAI(difficulty: .medium)
        let xHuman = TimeEconomyEngine.plannedAdjustment(
            outcome: .draw,
            rules: rules,
            context: .vsAI(humanMark: .x, difficulty: .medium)
        )
        XCTAssertEqual(xHuman?.xDelta, 2)
        XCTAssertEqual(xHuman?.oDelta, 0)

        let oHuman = TimeEconomyEngine.plannedAdjustment(
            outcome: .draw,
            rules: rules,
            context: .vsAI(humanMark: .o, difficulty: .medium)
        )
        XCTAssertEqual(oHuman?.xDelta, 0)
        XCTAssertEqual(oHuman?.oDelta, 2)
    }

    // MARK: - Floor & cap

    func test_penalty_floor_never_below_3() {
        var x = 5
        var o = 4
        let applied = TimeEconomyEngine.apply(
            TimeEconomyAdjustment(xDelta: 0, oDelta: -3),
            xRemaining: &x,
            oRemaining: &o,
            initialDurationSeconds: initial
        )
        XCTAssertEqual(o, 3)
        XCTAssertEqual(applied.oDelta, -1)
    }

    func test_bonus_cap_at_initial_plus_15() {
        var x = initial + 14
        var o = initial
        _ = TimeEconomyEngine.apply(
            TimeEconomyAdjustment(xDelta: 5, oDelta: 0),
            xRemaining: &x,
            oRemaining: &o,
            initialDurationSeconds: initial
        )
        XCTAssertEqual(x, initial + 15)
    }

    func test_solo_focus_has_no_rules() {
        XCTAssertNil(TimeEconomyEngine.rules(for: .soloFocus, aiDifficulty: .easy))
    }
}
