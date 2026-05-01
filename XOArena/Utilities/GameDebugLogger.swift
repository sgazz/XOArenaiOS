//
//  GameDebugLogger.swift
//  XOArena
//

import Foundation

enum GameDebugLogger {
#if DEBUG
    static var isEnabled = true
    static var printSnapshots = true
    /// Full **`SNAPSHOT`** every N accepted session moves when **`GameMode.aiVsAI`** (0 = never use this path for multiples).
    static var snapshotEvery: Int = 10

    private static func emit(_ message: String) {
        guard isEnabled else { return }
        print("[XOArena] \(message)")
    }

    private static func markChar(_ mark: Mark) -> String {
        switch mark {
        case .x: return "X"
        case .o: return "O"
        case .empty: return "."
        }
    }

    private static func phaseTag(_ phase: BoardTurnPhase) -> String {
        switch phase {
        case .firstMove: return "firstMove"
        case .secondMove: return "secondMove"
        }
    }

    private static func outcomeTag(afterPlacement: BoardPlayState) -> String {
        switch afterPlacement {
        case .inProgress: return "inProgress"
        case .won(let m): return "won\(markChar(m))"
        case .drawn: return "draw"
        }
    }

    private static func compactBoardRow(cells: [BoardCell], row: Int) -> String {
        let base = row * 3
        return (0..<3).map { markChar(cells[base + $0].mark) }.joined()
    }

    /// One line per slab: rows separated by `|`.
    private static func boardCompactCells(_ board: XOBoard) -> String {
        let c = board.cells
        guard c.count >= 9 else { return "---" }
        return "\(compactBoardRow(cells: c, row: 0))|\(compactBoardRow(cells: c, row: 1))|\(compactBoardRow(cells: c, row: 2))"
    }

    /// `t=` uses `formattedTime` when non-nil else `—`.
    static func snapshot(session: GameSession, formattedTime: String?) {
        guard printSnapshots else { return }
        guard isEnabled else { return }
        let time = formattedTime ?? "—"
        let cm = session.boards.indices.contains(session.activeBoardIndex)
            ? markChar(session.boards[session.activeBoardIndex].currentMark)
            : "?"
        let ph = session.boards.indices.contains(session.activeBoardIndex)
            ? phaseTag(session.boards[session.activeBoardIndex].turnPhase)
            : "—"
        emit("SNAPSHOT t=\(time) active=\(session.activeBoardIndex + 1) mark=\(cm) phase=\(ph)")
        for (idx, b) in session.boards.enumerated() {
            emit(
                "B\(idx + 1) starter=\(markChar(b.startingMark)) phase=\(phaseTag(b.turnPhase)) cells=\(boardCompactCells(b))"
            )
        }
    }

    static func sessionStarted(mode: GameMode, durationSeconds: Int) {
        emit("SESSION_START mode=\(mode.rawValue) duration=\(durationSeconds)s")
    }

    static func sessionCompleted(reason: String) {
        emit("SESSION_DONE reason=\(reason)")
    }

    static func timerStarted(secondsRemaining: Int) {
        emit("TIMER_START secs=\(secondsRemaining)")
    }

    static func timerStopped() {
        emit("TIMER_STOP")
    }

    static func timerExpired() {
        emit("TIMER_TIMEOUT")
    }

    static func moveAttempt(boardIndex: Int, cellIndex: Int, mark: Mark, phase: BoardTurnPhase, formattedTime: String) {
        let t = formattedTime
        emit(
            "MOVE_ATTEMPT board=\(boardIndex + 1) cell=\(cellIndex + 1) mark=\(markChar(mark)) phase=\(phaseTag(phase)) time=\(t)"
        )
    }

    static func moveAccepted(
        boardIndex: Int,
        cellIndex: Int,
        mark: Mark,
        phaseBefore: BoardTurnPhase,
        playStateAfterPlacement: BoardPlayState,
        phaseAfterOnMovedBoard: BoardTurnPhase,
        activeBoardAfter: Int
    ) {
        emit(
            "MOVE_OK board=\(boardIndex + 1) cell=\(cellIndex + 1) mark=\(markChar(mark)) result=\(outcomeTag(afterPlacement: playStateAfterPlacement)) nextPhase=\(phaseTag(phaseAfterOnMovedBoard)) activeBoard=\(activeBoardAfter + 1)"
        )
    }

    static func moveRejected(boardIndex: Int, cellIndex: Int, reason: String) {
        emit("MOVE_REJECT board=\(boardIndex + 1) cell=\(cellIndex + 1) \(reason)")
    }

    /// Win right after placing a mark (`stats` are already incremented).
    static func boardCompletedWin(boardIndex: Int, winner: Mark, stats: GameStats) {
        emit(
            "BOARD_WIN board=\(boardIndex + 1) winner=\(markChar(winner)) score X=\(stats.xBoardWins) O=\(stats.oBoardWins) D=\(stats.boardDraws)"
        )
    }

    static func boardCompletedDraw(boardIndex: Int, stats: GameStats) {
        emit(
            "BOARD_DRAW board=\(boardIndex + 1) score X=\(stats.xBoardWins) O=\(stats.oBoardWins) D=\(stats.boardDraws)"
        )
    }

    /// `outcome`: `winX`, `winO`, or `draw`.
    static func boardReset(boardIndex: Int, outcome: String, nextStarter: Mark) {
        emit(
            "BOARD_RESET board=\(boardIndex + 1) outcome=\(outcome) nextStarter=\(markChar(nextStarter))"
        )
    }

    static func activeBoardChanged(from previous: Int?, to next: Int, mark: Mark, phase: BoardTurnPhase) {
        let prev = previous.map { String($0 + 1) } ?? "—"
        emit(
            "ACTIVE_BOARD from=\(prev) to=\(next + 1) currentMark=\(markChar(mark)) phase=\(phaseTag(phase))"
        )
    }

    static func aiCheck(
        mode: GameMode,
        boardIndex: Int,
        mark: Mark,
        phase: BoardTurnPhase,
        shouldSchedule: Bool,
        reason: String
    ) {
        emit(
            "AI_CHECK mode=\(mode.rawValue) board=\(boardIndex + 1) mark=\(markChar(mark)) phase=\(phaseTag(phase)) shouldSchedule=\(shouldSchedule) reason=\(reason)"
        )
    }

    static func aiScheduled(
        boardIndex: Int,
        mark: Mark,
        phase: BoardTurnPhase,
        delayNanoseconds: UInt64,
        token: UInt64
    ) {
        let ms = Double(delayNanoseconds) / 1_000_000.0
        emit(
            "AI_SCHEDULE board=\(boardIndex + 1) mark=\(markChar(mark)) phase=\(phaseTag(phase)) delayMs=\(String(format: "%.2f", ms)) token=\(token)"
        )
    }

    static func aiMoveApplied(boardIndex: Int, cellIndex: Int, mark: Mark) {
        emit("AI_APPLY board=\(boardIndex + 1) mark=\(markChar(mark)) cell=\(cellIndex + 1)")
    }

    static func testSummaryAiVsAI(
        totalMoves: Int,
        xWins: Int,
        oWins: Int,
        draws: Int,
        resets: Int,
        invalidMoves: Int,
        elapsedSeconds: Int
    ) {
        emit(
            "TEST_SUMMARY moves=\(totalMoves) X=\(xWins) O=\(oWins) draws=\(draws) resets=\(resets) invalid=\(invalidMoves) elapsed=\(elapsedSeconds)s"
        )
    }

    static func aiMoveIgnored(reason: String) {
        emit("AI_IGNORED \(reason)")
    }

    /// Input blocked before **`GameEngine.applyMove`** (e.g. **`HumanInputGate`**).
    static func gateRejected(boardIndex: Int, cellIndex: Int, detail: String) {
        emit("GATE_REJECT board=\(boardIndex + 1) cell=\(cellIndex + 1) \(detail)")
    }

    /// Manual grep targets for **`GameMode.vsAI`** harnesses (`VS_AI_VERIFY …`).
    static func vsAIVerifyResetCancelledPendingAI() {
        emit("VS_AI_VERIFY reset_cancelled_pending_ai")
    }

    static func vsAIVerifyTimerExpiryCancelledPendingAI() {
        emit("VS_AI_VERIFY timer_expiry_cancelled_pending_ai")
    }

#else

    static var isEnabled = false
    static var printSnapshots = false
    static var snapshotEvery: Int = 10

    static func snapshot(session: GameSession, formattedTime: String?) {}
    static func sessionStarted(mode: GameMode, durationSeconds: Int) {}
    static func sessionCompleted(reason: String) {}
    static func timerStarted(secondsRemaining: Int) {}
    static func timerStopped() {}
    static func timerExpired() {}
    static func moveAttempt(boardIndex: Int, cellIndex: Int, mark: Mark, phase: BoardTurnPhase, formattedTime: String) {}
    static func moveAccepted(
        boardIndex: Int,
        cellIndex: Int,
        mark: Mark,
        phaseBefore: BoardTurnPhase,
        playStateAfterPlacement: BoardPlayState,
        phaseAfterOnMovedBoard: BoardTurnPhase,
        activeBoardAfter: Int
    ) {}
    static func moveRejected(boardIndex: Int, cellIndex: Int, reason: String) {}
    static func boardCompletedWin(boardIndex: Int, winner: Mark, stats: GameStats) {}
    static func boardCompletedDraw(boardIndex: Int, stats: GameStats) {}
    static func boardReset(boardIndex: Int, outcome: String, nextStarter: Mark) {}
    static func activeBoardChanged(from previous: Int?, to next: Int, mark: Mark, phase: BoardTurnPhase) {}
    static func aiCheck(
        mode: GameMode,
        boardIndex: Int,
        mark: Mark,
        phase: BoardTurnPhase,
        shouldSchedule: Bool,
        reason: String
    ) {}
    static func aiScheduled(
        boardIndex: Int,
        mark: Mark,
        phase: BoardTurnPhase,
        delayNanoseconds: UInt64,
        token: UInt64
    ) {}
    static func aiMoveApplied(boardIndex: Int, cellIndex: Int, mark: Mark) {}
    static func aiMoveIgnored(reason: String) {}
    static func testSummaryAiVsAI(
        totalMoves: Int,
        xWins: Int,
        oWins: Int,
        draws: Int,
        resets: Int,
        invalidMoves: Int,
        elapsedSeconds: Int
    ) {}
    static func gateRejected(boardIndex: Int, cellIndex: Int, detail: String) {}
    static func vsAIVerifyResetCancelledPendingAI() {}
    static func vsAIVerifyTimerExpiryCancelledPendingAI() {}

#endif
}
