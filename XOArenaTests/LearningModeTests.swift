//
//  LearningModeTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class LearningModeTests: XCTestCase {
    private func emptyBoard() -> XOBoard {
        TestBoardFixture.board(with: BoardCell.emptyGrid().map(\.mark), startingMark: .x, phase: .firstMove)
    }

    func test_center_move_increments_centerMoves() {
        var profile = LearningProfile.initial
        let pre = emptyBoard()
        var post = pre
        post.cells[4].mark = .x
        LearningAnalyzer.processHumanMove(preBoard: pre, postBoard: post, cellIndex: 4, aiMark: .o, profile: &profile)
        XCTAssertEqual(profile.centerMoves, 1)
        XCTAssertEqual(profile.cornerMoves, 0)
        XCTAssertEqual(profile.sideMoves, 0)
    }

    func test_corner_move_increments_cornerMoves() {
        var profile = LearningProfile.initial
        let pre = emptyBoard()
        var post = pre
        post.cells[0].mark = .x
        LearningAnalyzer.processHumanMove(preBoard: pre, postBoard: post, cellIndex: 0, aiMark: .o, profile: &profile)
        XCTAssertEqual(profile.cornerMoves, 1)
        XCTAssertEqual(profile.centerMoves, 0)
    }

    func test_side_move_increments_sideMoves() {
        var profile = LearningProfile.initial
        let pre = emptyBoard()
        var post = pre
        post.cells[1].mark = .x
        LearningAnalyzer.processHumanMove(preBoard: pre, postBoard: post, cellIndex: 1, aiMark: .o, profile: &profile)
        XCTAssertEqual(profile.sideMoves, 1)
    }

    func test_missed_block_increments_missedBlocks() {
        var profile = LearningProfile.initial
        let pre = TestBoardFixture.board(with: [
            .o, .o, .empty,
            .x, .empty, .empty,
            .empty, .empty, .empty
        ])
        var post = pre
        post.cells[8].mark = .x
        LearningAnalyzer.processHumanMove(preBoard: pre, postBoard: post, cellIndex: 8, aiMark: .o, profile: &profile)
        XCTAssertEqual(profile.missedBlocks, 1)
        XCTAssertEqual(profile.successfulBlocks, 0)
        XCTAssertEqual(profile.latestFeedbackMessage, "You missed a block.")
    }

    func test_successful_block_increments_successfulBlocks() {
        var profile = LearningProfile.initial
        let pre = TestBoardFixture.board(with: [
            .o, .o, .empty,
            .x, .empty, .empty,
            .empty, .empty, .empty
        ])
        var post = pre
        post.cells[2].mark = .x
        LearningAnalyzer.processHumanMove(preBoard: pre, postBoard: post, cellIndex: 2, aiMark: .o, profile: &profile)
        XCTAssertEqual(profile.successfulBlocks, 1)
        XCTAssertEqual(profile.missedBlocks, 0)
        XCTAssertEqual(profile.latestFeedbackMessage, "Good block.")
    }

    func test_repeated_missedBlocks_lowers_AI_difficulty_via_policy() {
        var profile = LearningProfile.initial
        profile.missedBlocks = 3
        profile.successfulBlocks = 0
        profile.humanWins = 0
        profile.aiWins = 0
        profile.currentLevel = .basics
        XCTAssertEqual(profile.adaptiveAIDifficulty(), .easy)
    }

    func test_successfulBlocks_and_humanWins_raise_AI_difficulty() {
        var profile = LearningProfile.initial
        profile.successfulBlocks = 3
        profile.humanWins = 4
        profile.aiWins = 1
        profile.missedBlocks = 0
        profile.currentLevel = .basics
        XCTAssertEqual(profile.adaptiveAIDifficulty(), .hard)
    }

    func test_strong_performance_overrides_soften_even_with_miss_streak() {
        var profile = LearningProfile.initial
        profile.missedBlocks = 4
        profile.successfulBlocks = 4
        profile.humanWins = 5
        profile.aiWins = 1
        profile.currentLevel = .corners
        XCTAssertEqual(profile.adaptiveAIDifficulty(), .hard)
    }

    func test_feedback_updates_for_center_hint_after_avoiding_center() {
        var profile = LearningProfile.initial
        let pre = emptyBoard()
        XCTAssertTrue(pre.cells[4].mark == .empty)

        var post1 = pre
        post1.cells[0].mark = .x
        LearningAnalyzer.processHumanMove(preBoard: pre, postBoard: post1, cellIndex: 0, aiMark: .o, profile: &profile)
        XCTAssertTrue(profile.latestFeedbackMessage.isEmpty)

        let pre2 = post1
        var post2 = pre2
        post2.cells[1].mark = .x
        LearningAnalyzer.processHumanMove(preBoard: pre2, postBoard: post2, cellIndex: 1, aiMark: .o, profile: &profile)
        XCTAssertEqual(profile.latestFeedbackMessage, "Try the center early.")
    }

    func test_learning_gate_mirrors_vsAI_for_X_turn() {
        let allows = HumanInputGate.permitsCellPlacement(
            gameMode: .learning,
            sessionState: .playing,
            isAIThinking: false,
            currentMark: .x,
            boardPlayState: .inProgress,
            cellMark: .empty,
            isFocusedBoard: true,
            humanControlledMark: .x
        )
        XCTAssertTrue(allows)
        let blocksO = HumanInputGate.permitsCellPlacement(
            gameMode: .learning,
            sessionState: .playing,
            isAIThinking: false,
            currentMark: .o,
            boardPlayState: .inProgress,
            cellMark: .empty,
            isFocusedBoard: true,
            humanControlledMark: .x
        )
        XCTAssertFalse(blocksO)
    }
}
