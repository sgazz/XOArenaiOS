//
//  TestBoardFixture.swift
//  XOArenaTests
//

@testable import XOArena

enum TestBoardFixture {
    /// Nine marks in rows 0…2 scanning left‑to‑top.
    static func board(
        with marks: [Mark],
        startingMark: Mark = .x,
        phase: BoardTurnPhase = .firstMove
    ) -> XOBoard {
        precondition(marks.count == GameConstants.cellCount, "nine marks required")
        return XOBoard(
            cells: marks.enumerated().map { BoardCell(index: $0.offset, mark: $0.element) },
            startingMark: startingMark,
            turnPhase: phase
        )
    }
}
