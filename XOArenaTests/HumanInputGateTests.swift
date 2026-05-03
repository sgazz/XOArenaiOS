//
//  HumanInputGateTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class HumanInputGateTests: XCTestCase {
    func test_vsAI_human_allowed_when_turn_is_X_on_focus_board() throws {
        let allows = HumanInputGate.permitsCellPlacement(
            gameMode: .vsAI,
            sessionState: .playing,
            isAIThinking: false,
            currentMark: .x,
            boardPlayState: .inProgress,
            cellMark: .empty,
            isFocusedBoard: true,
            humanControlledMark: .x
        )
        XCTAssertTrue(allows)
    }

    func test_vsAI_human_allowed_on_O_turn_when_human_is_O() throws {
        let allows = HumanInputGate.permitsCellPlacement(
            gameMode: .vsAI,
            sessionState: .playing,
            isAIThinking: false,
            currentMark: .o,
            boardPlayState: .inProgress,
            cellMark: .empty,
            isFocusedBoard: true,
            humanControlledMark: .o
        )
        XCTAssertTrue(allows)
    }

    func test_vsAI_human_only_on_X_even_if_focused_idle_cell() throws {
        let allows = HumanInputGate.permitsCellPlacement(
            gameMode: .vsAI,
            sessionState: .playing,
            isAIThinking: false,
            currentMark: .o,
            boardPlayState: .inProgress,
            cellMark: .empty,
            isFocusedBoard: true,
            humanControlledMark: .x
        )
        XCTAssertFalse(allows)
    }

    func test_vsAI_blocks_while_AI_thinking() throws {
        let allows = HumanInputGate.permitsCellPlacement(
            gameMode: .vsAI,
            sessionState: .playing,
            isAIThinking: true,
            currentMark: .x,
            boardPlayState: .inProgress,
            cellMark: .empty,
            isFocusedBoard: true,
            humanControlledMark: .x
        )
        XCTAssertFalse(allows)
    }

    func test_localDuel_human_on_O_turn_when_focused() throws {
        let allows = HumanInputGate.permitsCellPlacement(
            gameMode: .localDuel,
            sessionState: .playing,
            isAIThinking: false,
            currentMark: .o,
            boardPlayState: .inProgress,
            cellMark: .empty,
            isFocusedBoard: true,
            humanControlledMark: nil
        )
        XCTAssertTrue(allows)
    }

    func test_aiVsAI_never_accepts_human_taps() throws {
        let allows = HumanInputGate.permitsCellPlacement(
            gameMode: .aiVsAI,
            sessionState: .playing,
            isAIThinking: false,
            currentMark: .x,
            boardPlayState: .inProgress,
            cellMark: .empty,
            isFocusedBoard: true,
            humanControlledMark: nil
        )
        XCTAssertFalse(allows)
    }
}
