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

    static func aiThink(delaySeconds: Double, remaining: Int, difficulty: String, reason: String) {
        emit(
            "AI_THINK delay=\(String(format: "%.3f", delaySeconds))s remaining=\(remaining)s difficulty=\(difficulty) reason=\(reason)"
        )
    }

    /// Per-second (or finer) countdown visibility audit (**`clockTickDetailed`** preferiran).
    static func clockTick(active: Mark?, xRemain: Int, oRemain: Int, isAIThinking: Bool) {
        let a = active.map { markChar($0) } ?? "?"
        emit("CLOCK_TICK active=\(a) x=\(xRemain) o=\(oRemain) isAIThinking=\(isAIThinking)")
    }

    static func clockTickDetailed(active: Mark, xBefore: Int, oBefore: Int, xAfter: Int, oAfter: Int) {
        // Struktuirani gameplay audit (**`GAMEPLAY_CLOCK`**) ima prigušenje (**max 1/s**).
        logClockTick(activeMark: active, xTime: xAfter, oTime: oAfter)
    }

    // MARK: - Gameplay audit (jednolinijsko `key=value`)

    /// Poslednji **`GAMEPLAY_CLOCK`** u monotonim nanosekundama uptime-a (**prigušenje 1 Hz**).
    private static var lastGameplayClockAuditUptimeNs: UInt64?

    /// Posle **`MOVE_OK`**: potez (board/cell po konvenciji 1‑based kao u tragovima).
    static func logMove(board: Int, mark: Mark, cell: Int, xTime: Int, oTime: Int) {
        emit(
            "GAMEPLAY_MOVE board=\(board) mark=\(markChar(mark)) cell=\(cell) xSec=\(xTime) oSec=\(oTime)"
        )
    }

    static func logClockTick(activeMark: Mark, xTime: Int, oTime: Int) {
        let n = DispatchTime.now().uptimeNanoseconds
        if let last = lastGameplayClockAuditUptimeNs, n &- last < 1_000_000_000 { return }
        lastGameplayClockAuditUptimeNs = n
        emit(
            "GAMEPLAY_CLOCK active=\(markChar(activeMark)) xSec=\(xTime) oSec=\(oTime)"
        )
    }

    /// Posle **`CLOCK_SWITCH`**: promena aktivnog igrača na satu.
    static func logSwitch(from: Mark, to: Mark, board: Int, xTime: Int, oTime: Int) {
        emit(
            "GAMEPLAY_SWITCH from=\(markChar(from)) to=\(markChar(to)) board=\(board) xSec=\(xTime) oSec=\(oTime)"
        )
    }

    /// Neposredno pre AI kašnjenja (vsAI / learning koristi **`oSec`** kao referencu naglaska).
    static func logAIThinkStart(oTime: Int) {
        emit("GAMEPLAY_AI_THINK_START oSec=\(oTime)")
    }

    /// Odmah posle AI razmišljanja, pre validacije **post‑sleep**.
    static func logAIThinkEnd(oTime: Int) {
        emit("GAMEPLAY_AI_THINK_END oSec=\(oTime)")
    }

    static func logBoardWin(board: Int, winner: Mark) {
        emit("GAMEPLAY_BOARD_WIN board=\(board) winner=\(markChar(winner))")
    }

    static func logReward(xTime: Int, oTime: Int) {
        emit("GAMEPLAY_REWARD xSec=\(xTime) oSec=\(oTime)")
    }

    static func logDraw(board: Int, xTime: Int, oTime: Int) {
        emit("GAMEPLAY_DRAW board=\(board) xSec=\(xTime) oSec=\(oTime)")
    }

    static func logTimeout(loser: Mark, xTime: Int, oTime: Int) {
        guard loser == .x || loser == .o else { return }
        emit("GAMEPLAY_TIMEOUT loser=\(markChar(loser)) xSec=\(xTime) oSec=\(oTime)")
    }

    static func clockSwitch(from: Mark, to: Mark, boardOneBased: Int) {
        emit(
            "CLOCK_SWITCH from=\(markChar(from)) to=\(markChar(to)) board=\(boardOneBased)"
        )
    }

    static func drawBonusApplied(secondsEach: Int, xAfter: Int, oAfter: Int) {
        emit("DRAW_BONUS +\(secondsEach) each x=\(xAfter) o=\(oAfter)")
    }

    static func rewardApplied(winner: Mark, xAfter: Int, oAfter: Int) {
        emit("REWARD_APPLIED winner=\(markChar(winner)) x=\(xAfter) o=\(oAfter)")
    }

    static func timeOut(loser: Mark) {
        guard loser == .x || loser == .o else { return }
        emit("TIMEOUT loser=\(markChar(loser))")
    }

    static func aiThinkStartDetailed(active: Mark, xRemain: Int, oRemain: Int) {
        emit(
            "AI_THINK_START active=\(markChar(active)) x=\(xRemain) o=\(oRemain)"
        )
    }

    static func aiThinkEndDetailed(active: Mark, xRemain: Int, oRemain: Int) {
        emit(
            "AI_THINK_END active=\(markChar(active)) x=\(xRemain) o=\(oRemain)"
        )
    }

    static func aiThinkStart(remaining: Int) {
        emit("AI_THINK_START remaining=\(remaining)s")
    }

    static func aiThinkEnd(remaining: Int) {
        emit("AI_THINK_END remaining=\(remaining)s")
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
    static func aiThink(delaySeconds: Double, remaining: Int, difficulty: String, reason: String) {}
    static func clockTick(active: Mark?, xRemain: Int, oRemain: Int, isAIThinking: Bool) {}
    static func clockTickDetailed(active: Mark, xBefore: Int, oBefore: Int, xAfter: Int, oAfter: Int) {}
    static func logMove(board: Int, mark: Mark, cell: Int, xTime: Int, oTime: Int) {}
    static func logClockTick(activeMark: Mark, xTime: Int, oTime: Int) {}
    static func logSwitch(from: Mark, to: Mark, board: Int, xTime: Int, oTime: Int) {}
    static func logAIThinkStart(oTime: Int) {}
    static func logAIThinkEnd(oTime: Int) {}
    static func logBoardWin(board: Int, winner: Mark) {}
    static func logReward(xTime: Int, oTime: Int) {}
    static func logDraw(board: Int, xTime: Int, oTime: Int) {}
    static func logTimeout(loser: Mark, xTime: Int, oTime: Int) {}
    static func clockSwitch(from: Mark, to: Mark, boardOneBased: Int) {}
    static func drawBonusApplied(secondsEach: Int, xAfter: Int, oAfter: Int) {}
    static func rewardApplied(winner: Mark, xAfter: Int, oAfter: Int) {}
    static func timeOut(loser: Mark) {}
    static func aiThinkStartDetailed(active: Mark, xRemain: Int, oRemain: Int) {}
    static func aiThinkEndDetailed(active: Mark, xRemain: Int, oRemain: Int) {}
    static func aiThinkStart(remaining: Int) {}
    static func aiThinkEnd(remaining: Int) {}
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
