//
//  GameEngine.swift
//  XOArena
//

import Foundation

/// Pure session rules (`Sendable`): classic 3×3 on each slab with board-local two-step cycle.
///
/// Classic per-board behaviour:
/// • Only empty cells accept the current player’s mark; occupied cells refuse.
/// • Every board stores `startingMark` + phase (`firstMove` / `secondMove`).
/// • Current mark is derived from active board (`startingMark` first, opposite second).
/// • On first move, stay on same board and flip to second move unless board ends.
/// • On second move, advance to next board and reset phase to first move.
/// • A board ends on **three in a row** (row/column/diagonal matching `X` or `O`), or **draw** when all nine cells filled with no winner; result is recorded, board is immediately cleared, and play continues.
/// Multi-board UX: exactly one **`activeBoardIndex`** receives placement; when a board ends it is reset, starting mark switches, and focus advances.
enum GameEngine: Sendable {
    static func makeIdleSession() -> GameSession {
        GameSession(
            boards: Array(repeating: XOBoard.empty, count: GameConstants.boardCount),
            activeBoardIndex: 0,
            gameMode: .soloFocus,
            aiDifficulty: .hard,
            stats: .zero,
            sessionState: .notStarted
        )
    }

    /// Playable lobby: **X** opens; every board blank; rotation starts at slab `0`.
    static func makeInitialSession(mode: GameMode) -> GameSession {
        let boards = Array(repeating: XOBoard.empty, count: GameConstants.boardCount)
        return GameSession(
            boards: boards,
            activeBoardIndex: 0,
            gameMode: mode,
            aiDifficulty: .hard,
            stats: .zero,
            sessionState: .playing
        )
    }

    /// Next board clockwise from `(from + 1) % count`.
    static func nextInProgressBoardIndex(boards: [XOBoard], after from: Int) -> Int? {
        guard !boards.isEmpty else { return nil }
        return (from + 1) % boards.count
    }

    /// Manual focus cycle (toolbar advance) without placing a mark.
    static func advanceFocus(_ session: GameSession) -> GameSession? {
        guard session.sessionState == .playing else { return nil }
        guard let next = nextInProgressBoardIndex(boards: session.boards, after: session.activeBoardIndex) else {
            return nil
        }
        var s = session
        let prev = s.activeBoardIndex
        s.activeBoardIndex = next
#if DEBUG
        GameDebugLogger.activeBoardChanged(
            from: prev,
            to: next,
            mark: s.boards[next].currentMark,
            phase: s.boards[next].turnPhase
        )
#endif
        return s
    }

    /// Places mark derived from active board phase (`firstMove`/`secondMove`) and applies two-move-per-board progression.
    static func applyMove(
        _ session: GameSession,
        boardIndex: Int,
        cellIndex: Int
    ) throws -> GameSession {
        guard session.sessionState == .playing else {
#if DEBUG
            GameDebugLogger.moveRejected(
                boardIndex: boardIndex,
                cellIndex: cellIndex,
                reason: MoveError.sessionNotActive.description
            )
#endif
            throw MoveError.sessionNotActive
        }
        guard (0..<GameConstants.boardCount).contains(boardIndex) else {
#if DEBUG
            GameDebugLogger.moveRejected(boardIndex: boardIndex, cellIndex: cellIndex, reason: MoveError.invalidBoardIndex.description)
#endif
            throw MoveError.invalidBoardIndex
        }
        guard (0..<GameConstants.cellCount).contains(cellIndex) else {
#if DEBUG
            GameDebugLogger.moveRejected(boardIndex: boardIndex, cellIndex: cellIndex, reason: MoveError.invalidCellIndex.description)
#endif
            throw MoveError.invalidCellIndex
        }
        guard boardIndex == session.activeBoardIndex else {
#if DEBUG
            GameDebugLogger.moveRejected(
                boardIndex: boardIndex,
                cellIndex: cellIndex,
                reason: MoveError.wrongBoard(expected: session.activeBoardIndex, attempted: boardIndex).description
            )
#endif
            throw MoveError.wrongBoard(expected: session.activeBoardIndex, attempted: boardIndex)
        }

        var boards = session.boards
        guard boards[boardIndex].playState == .inProgress else {
#if DEBUG
            GameDebugLogger.moveRejected(boardIndex: boardIndex, cellIndex: cellIndex, reason: MoveError.boardFinished.description)
#endif
            throw MoveError.boardFinished
        }
        guard boards[boardIndex].cells[cellIndex].mark == .empty else {
#if DEBUG
            GameDebugLogger.moveRejected(boardIndex: boardIndex, cellIndex: cellIndex, reason: MoveError.cellOccupied.description)
#endif
            throw MoveError.cellOccupied
        }

        let phase = boards[boardIndex].turnPhase
        let markToPlace = boards[boardIndex].currentMark
        boards[boardIndex].cells[cellIndex].mark = markToPlace

        var stats = session.stats
        stats.totalMoves += 1

        let afterState = boards[boardIndex].playState
        switch afterState {
        case .won(let mark):
            switch mark {
            case .x:
                stats.xBoardWins += 1
            case .o:
                stats.oBoardWins += 1
            case .empty:
                break
            }
        case .drawn:
            stats.boardDraws += 1
        case .inProgress:
            break
        }

        let boardCompleted = afterState != .inProgress

        let shouldAdvance: Bool = {
            if boardCompleted { return true }
            switch phase {
            case .firstMove:
                return false
            case .secondMove:
                return true
            }
        }()

        if boardCompleted {
            boards[boardIndex].cells = BoardCell.emptyGrid()
            boards[boardIndex].startingMark = boards[boardIndex].startingMark.nextInTurn
            boards[boardIndex].turnPhase = .firstMove
        } else {
            boards[boardIndex].turnPhase = (phase == .firstMove) ? .secondMove : .firstMove
        }

        let nextState: GameSessionState = .playing

        let nextActive: Int = {
            guard shouldAdvance else { return boardIndex }
            return nextInProgressBoardIndex(boards: boards, after: boardIndex) ?? boardIndex
        }()

        if shouldAdvance, boards.indices.contains(nextActive) {
            boards[nextActive].turnPhase = .firstMove
        }

        let phaseAfterOnMovedBoard = boards[boardIndex].turnPhase

#if DEBUG
        GameDebugLogger.moveAccepted(
            boardIndex: boardIndex,
            cellIndex: cellIndex,
            mark: markToPlace,
            phaseBefore: phase,
            playStateAfterPlacement: afterState,
            phaseAfterOnMovedBoard: phaseAfterOnMovedBoard,
            activeBoardAfter: nextActive
        )

        switch afterState {
        case .won(let winner):
            GameDebugLogger.boardCompletedWin(boardIndex: boardIndex, winner: winner, stats: stats)
        case .drawn:
            GameDebugLogger.boardCompletedDraw(boardIndex: boardIndex, stats: stats)
        case .inProgress:
            break
        }

        if boardCompleted {
            let oc: String
            switch afterState {
            case .won(let w):
                switch w {
                case .x: oc = "winX"
                case .o: oc = "winO"
                case .empty: oc = "win?"
                }
            case .drawn:
                oc = "draw"
            case .inProgress:
                oc = "?"
            }
            GameDebugLogger.boardReset(boardIndex: boardIndex, outcome: oc, nextStarter: boards[boardIndex].startingMark)
        }

        if nextActive != session.activeBoardIndex {
            GameDebugLogger.activeBoardChanged(
                from: session.activeBoardIndex,
                to: nextActive,
                mark: boards[nextActive].currentMark,
                phase: boards[nextActive].turnPhase
            )
        }
#endif

        return GameSession(
            boards: boards,
            activeBoardIndex: nextActive,
            gameMode: session.gameMode,
            aiDifficulty: session.aiDifficulty,
            stats: stats,
            sessionState: nextState
        )
    }
}
