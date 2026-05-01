//
//  GameViewModel.swift
//  XOArena
//

import Foundation
import Observation

@MainActor
@Observable
final class GameViewModel {
    private(set) var session: GameSession
    private let timerService: GameTimerControlling

    /// True when the slab is paced by **`TicTacToeAI`** (**`vsAI`**: **`O`** only; **`aiVsAI`**: both marks).
    var isAITurn: Bool {
        guard session.sessionState == .playing else { return false }
        switch session.gameMode {
        case .vsAI, .learning: return currentMark == .o
        case .aiVsAI: return true
        default: return false
        }
    }

    /// **DEBUG **`aiVsAI`** autoplay pacing** (**`normal`** · **`fast`** · **`instant`**). Ignored outside **`GameMode.aiVsAI`**.
    var aiVsAIDelayPreset: AIDebugDelayPreset = .fast

    /// Last selected AI strength for **`vsAI`** / **`aiVsAI`** (persisted across **`startNewGame`** / **`resetGame`**).
    private var preferredAIDifficulty: AIDifficulty = .hard

    /// Current session AI difficulty (single-board **`TicTacToeAI`**). Writable for DEBUG toolbar.
    var aiDifficulty: AIDifficulty {
        get { session.aiDifficulty }
        set {
            session.aiDifficulty = newValue
            switch session.gameMode {
            case .vsAI, .aiVsAI: preferredAIDifficulty = newValue
            default: break
            }
        }
    }

    /// True during the short “thinking” pause before **`applyMove`** for O.
    private(set) var isAIThinking: Bool = false

    /// Subtle subtitle under header when O is pondering ( **`vsAI`** only ).
    private(set) var aiWhisperLine: String?

    /// Human cannot place marks while AI “thinks” or when **`vsAI`** awaits **`O`**; **`aiVsAI`** is fully automated.
    var isInputLocked: Bool {
        guard session.sessionState == .playing else { return true }
        if isAIThinking { return true }
        if session.gameMode == .aiVsAI { return true }
        if session.gameMode == .vsAI || session.gameMode == .learning, currentMark != .x {
            return true
        }
        return false
    }

    /// Populated while **`GameMode.learning`** is active (human **X**, adaptive **O**).
    private(set) var learningProfile: LearningProfile = .initial

    private(set) var selectedDuration: GameDuration = .threeMinutes
    private(set) var remainingSeconds: Int = GameDuration.threeMinutes.seconds
    private(set) var isTimerRunning: Bool = false
    private(set) var completionReason: CompletionReason?

    var formattedRemainingTime: String {
        let bounded = max(remainingSeconds, 0)
        let mins = bounded / 60
        let secs = bounded % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private var aiSequence: UInt64 = 0
    private var aiTask: Task<Void, Never>?

#if DEBUG
    private var aiVsAIDebugBoardResetCount: Int = 0
    private var aiVsAIDebugInvalidMoves: Int = 0
    private var aiVsAIDebugStartedAt: Date?
#endif

    init(
        session: GameSession? = nil,
        services: AppServices = AppServices(),
        timerService: GameTimerControlling
    ) {
        _ = services
        self.timerService = timerService
        self.session = session ?? GameEngine.makeIdleSession()
        _ = SoundService.shared
    }

    convenience init(session: GameSession? = nil, services: AppServices = AppServices()) {
        self.init(session: session, services: services, timerService: GameTimerService())
    }

    var boards: [XOBoard] { session.boards }
    var activeBoardIndex: Int { session.activeBoardIndex }
    var currentBoardPhase: BoardTurnPhase {
        guard boards.indices.contains(activeBoardIndex) else {
            return .firstMove
        }
        return boards[activeBoardIndex].turnPhase
    }
    var currentMark: Mark { session.currentMarkForActiveBoard }
    var activeBoardStarter: Mark {
        guard boards.indices.contains(activeBoardIndex) else { return .x }
        return boards[activeBoardIndex].startingMark
    }
    var gameMode: GameMode { session.gameMode }
    var stats: GameStats { session.stats }
    var sessionState: GameSessionState { session.sessionState }
    var isSessionComplete: Bool { session.sessionState == .completed }

    var focusedBoardIndex: Int? {
        session.sessionState == .playing ? session.activeBoardIndex : nil
    }

    /// Applies move feedback after **`GameEngine.applyMove`** succeeds (human or scheduled AI path).
    private func notifyAppliedMoveFeedback(
        beforeStats: GameStats,
        afterStats: GameStats,
        learningSuccessfulBlock: Bool
    ) {
        if learningSuccessfulBlock {
            SoundService.shared.playBlock()
            HapticService.success()
        } else {
            SoundService.shared.playPencil()
            HapticService.lightImpact()
        }
        let winDelta =
            (afterStats.xBoardWins - beforeStats.xBoardWins)
            + (afterStats.oBoardWins - beforeStats.oBoardWins)
        if winDelta > 0 {
            HapticService.mediumImpact()
        }
    }

    func allowsHumanPlacement(boardIndex: Int, cellIndex: Int) -> Bool {
        let focused = focusedBoardIndex.map { $0 == boardIndex } ?? false
        let cellMark = boards[safe: boardIndex]?.cells[safe: cellIndex]?.mark ?? .empty
        let slab = boards[safe: boardIndex]?.playState ?? .drawn
        return HumanInputGate.permitsCellPlacement(
            gameMode: session.gameMode,
            sessionState: session.sessionState,
            isAIThinking: isAIThinking,
            currentMark: currentMark,
            boardPlayState: slab,
            cellMark: cellMark,
            isFocusedBoard: focused
        )
    }

    var turnLabelPrimary: String {
        guard session.sessionState == .playing else {
            return session.sessionState == .completed ? "Session finished" : "Ready"
        }
        return currentMark == .x ? "Turn: X" : "Turn: O"
    }

    /// Backwards‑compatible combined line for callers that want a single string.
    var turnLabel: String { turnLabelPrimary }

    func startNewGame(mode: GameMode, duration: GameDuration = .threeMinutes) {
        selectedDuration = duration
        remainingSeconds = duration.seconds
        completionReason = nil
        cancelAIPipeline(debugLogCancel: true)
        stopTimer()
        session = GameEngine.makeInitialSession(mode: mode)
        learningProfile = .initial
        switch mode {
        case .vsAI, .aiVsAI:
            session.aiDifficulty = preferredAIDifficulty
        default:
            break
        }
#if DEBUG
        if mode == .aiVsAI {
            aiVsAIDebugBoardResetCount = 0
            aiVsAIDebugInvalidMoves = 0
            aiVsAIDebugStartedAt = Date()
            aiVsAIDelayPreset = .fast
        } else {
            aiVsAIDebugStartedAt = nil
        }
#endif
#if DEBUG
        GameDebugLogger.sessionStarted(mode: mode, durationSeconds: duration.seconds)
#endif
        startTimerIfNeeded()
        scheduleAIIfNeeded()
#if DEBUG
        GameDebugLogger.snapshot(session: session, formattedTime: formattedRemainingTime)
#endif
    }

    func makeMove(boardIndex: Int, cellIndex: Int) {
        guard HumanInputGate.permitsCellPlacement(
            gameMode: session.gameMode,
            sessionState: session.sessionState,
            isAIThinking: isAIThinking,
            currentMark: currentMark,
            boardPlayState: boards[safe: boardIndex]?.playState ?? .drawn,
            cellMark: boards[safe: boardIndex]?.cells[safe: cellIndex]?.mark ?? .empty,
            isFocusedBoard: focusedBoardIndex.map { $0 == boardIndex } ?? false
        ) else {
            HapticService.warning()
#if DEBUG
            GameDebugLogger.gateRejected(boardIndex: boardIndex, cellIndex: cellIndex, detail: "humanInputGate")
#endif
            return
        }

#if DEBUG
        if boards.indices.contains(boardIndex) {
            let phase = boards[boardIndex].turnPhase
            let mark = boards[boardIndex].currentMark
            GameDebugLogger.moveAttempt(
                boardIndex: boardIndex,
                cellIndex: cellIndex,
                mark: mark,
                phase: phase,
                formattedTime: formattedRemainingTime
            )
        }
#endif

        let beforeSession = session
        let learningBlocksBefore = learningProfile.successfulBlocks
        do {
            let next = try GameEngine.applyMove(session, boardIndex: boardIndex, cellIndex: cellIndex)
            session = next
            var learningBlockIncremented = false
            if next.gameMode == .learning {
                var p = learningProfile
                let preBoard = beforeSession.boards[boardIndex]
                let postBoard = next.boards[boardIndex]
                LearningAnalyzer.processHumanMove(
                    preBoard: preBoard,
                    postBoard: postBoard,
                    cellIndex: cellIndex,
                    profile: &p
                )
                LearningAnalyzer.applyBoardOutcomeDelta(before: beforeSession.stats, after: next.stats, profile: &p)
                learningBlockIncremented = p.successfulBlocks > learningBlocksBefore
                learningProfile = p
            }
            notifyAppliedMoveFeedback(
                beforeStats: beforeSession.stats,
                afterStats: next.stats,
                learningSuccessfulBlock: learningBlockIncremented
            )
#if DEBUG
            bumpAiVsAIBoardResetIfNeeded(before: beforeSession, after: next)
            if next.gameMode != .aiVsAI {
                GameDebugLogger.snapshot(session: session, formattedTime: formattedRemainingTime)
            }
#endif
        } catch {
            if error is MoveError {
                HapticService.warning()
            }
            // **`GameEngine`** logs **`MOVE_REJECT`** for **`MoveError`** in DEBUG builds.
            if !(error is MoveError) {
#if DEBUG
                GameDebugLogger.moveRejected(
                    boardIndex: boardIndex,
                    cellIndex: cellIndex,
                    reason: String(describing: error)
                )
#endif
            }
        }
        scheduleAIIfNeeded()
    }

    func resetGame() {
        remainingSeconds = selectedDuration.seconds
        completionReason = nil
        cancelAIPipeline(debugLogCancel: true)
#if DEBUG
        if session.gameMode == .vsAI || session.gameMode == .learning {
            GameDebugLogger.vsAIVerifyResetCancelledPendingAI()
        }
#endif
        stopTimer()
        let mode = session.gameMode
        session = GameEngine.makeInitialSession(mode: mode)
        switch mode {
        case .vsAI, .aiVsAI:
            session.aiDifficulty = preferredAIDifficulty
        default:
            break
        }
#if DEBUG
        if mode == .aiVsAI {
            aiVsAIDebugBoardResetCount = 0
            aiVsAIDebugInvalidMoves = 0
            aiVsAIDebugStartedAt = Date()
            aiVsAIDelayPreset = .fast
        } else {
            aiVsAIDebugStartedAt = nil
        }
        GameDebugLogger.sessionStarted(mode: mode, durationSeconds: selectedDuration.seconds)
#endif
        startTimerIfNeeded()
        scheduleAIIfNeeded()
#if DEBUG
        GameDebugLogger.snapshot(session: session, formattedTime: formattedRemainingTime)
#endif
    }

    func advanceToNextBoard() {
        guard session.sessionState == .playing else { return }
        guard !isAIThinking else { return }
        if session.gameMode == .aiVsAI { return }
        if session.gameMode == .vsAI || session.gameMode == .learning, currentMark != .x { return }
        guard let next = GameEngine.advanceFocus(session) else { return }
        session = next
#if DEBUG
        GameDebugLogger.snapshot(session: session, formattedTime: formattedRemainingTime)
#endif
        scheduleAIIfNeeded()
    }

    func selectDuration(_ duration: GameDuration) {
        selectedDuration = duration
        if session.sessionState == .notStarted || session.sessionState == .completed {
            remainingSeconds = duration.seconds
        }
    }

    func onGameViewAppear() {
        startTimerIfNeeded()
        scheduleAIIfNeeded()
    }

    func onGameViewDisappear() {
        stopTimer()
        cancelAIPipeline(debugLogCancel: true)
    }

    private func cancelAIPipeline(debugLogCancel: Bool = true) {
#if DEBUG
        if debugLogCancel, aiTask != nil || isAIThinking {
            GameDebugLogger.aiMoveIgnored(reason: "pipeline_cancel")
        }
#endif
        aiSequence &+= 1
        aiTask?.cancel()
        aiTask = nil
        isAIThinking = false
        aiWhisperLine = nil
    }

    private func startTimerIfNeeded() {
        guard session.sessionState == .playing else { return }
        guard !isTimerRunning else {
            scheduleAIIfNeeded()
            return
        }
        guard remainingSeconds > 0 else {
            completeForTimeExpiryIfNeeded()
            return
        }
        timerService.start(
            seconds: remainingSeconds,
            onTick: { [weak self] seconds in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.remainingSeconds = seconds
                }
            },
            onFinished: { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    self?.completeForTimeExpiryIfNeeded()
                }
            }
        )
        isTimerRunning = true
        scheduleAIIfNeeded()
    }

    private func stopTimer() {
        timerService.stop()
        isTimerRunning = false
    }

    private func completeForTimeExpiryIfNeeded() {
        guard session.sessionState == .playing else {
            stopTimer()
            return
        }
        let wasVsAILike = session.gameMode == .vsAI || session.gameMode == .learning
        cancelAIPipeline(debugLogCancel: false)
#if DEBUG
        if wasVsAILike {
            GameDebugLogger.vsAIVerifyTimerExpiryCancelledPendingAI()
        }
#endif
        remainingSeconds = 0
        var next = session
        next.sessionState = .completed
        HapticService.heavyImpact()
        SoundService.shared.playCompletion()
#if DEBUG
        if session.gameMode == .aiVsAI {
            let elapsed = aiVsAIDebugStartedAt.map { Int(Date().timeIntervalSince($0)) } ?? selectedDuration.seconds
            GameDebugLogger.testSummaryAiVsAI(
                totalMoves: session.stats.totalMoves,
                xWins: session.stats.xBoardWins,
                oWins: session.stats.oBoardWins,
                draws: session.stats.boardDraws,
                resets: aiVsAIDebugBoardResetCount,
                invalidMoves: aiVsAIDebugInvalidMoves,
                elapsedSeconds: max(0, elapsed)
            )
        }
        GameDebugLogger.timerExpired()
        GameDebugLogger.snapshot(session: next, formattedTime: "00:00")
#endif
        session = next
        completionReason = .timeExpired
        stopTimer()
#if DEBUG
        GameDebugLogger.sessionCompleted(reason: "time_expired")
#endif
    }

    /// Central AI scheduler: **`aiVsAI`** plays both **`X`** and **`O`**; **`vsAI`** only **`O`**. Always async + re-validates before **`applyMove`**.
    func scheduleAIIfNeeded() {
        let board = activeBoardIndex
        let mark = currentMark
        let phase = currentBoardPhase
        let mode = session.gameMode

        func audit(_ schedule: Bool, _ reason: String) {
#if DEBUG
            GameDebugLogger.aiCheck(
                mode: mode,
                boardIndex: board,
                mark: mark,
                phase: phase,
                shouldSchedule: schedule,
                reason: reason
            )
#else
            _ = (schedule, reason)
#endif
        }

        let requiresCentralAI = mode == .aiVsAI || ((mode == .vsAI || mode == .learning) && mark == .o)
        guard requiresCentralAI else {
            audit(false, "not_central_ai_mode")
            return
        }
        guard session.sessionState == .playing else {
            audit(false, "session_not_playing")
            return
        }
        guard remainingSeconds > 0 else {
            audit(false, "timer_zero")
            return
        }
        guard aiTask == nil else {
            audit(false, "ai_task_inflight")
            return
        }
        guard !isAIThinking else {
            audit(false, "thinking_flag_set")
            return
        }
        guard mark == .x || mark == .o else {
            audit(false, "unexpected_empty_mark")
            return
        }
        guard boards.indices.contains(board) else {
            audit(false, "bad_board_index")
            return
        }
        let slabSnapshot = boards[board]
        guard slabSnapshot.playState == .inProgress else {
            audit(false, "board_not_in_progress")
            return
        }
        guard slabSnapshot.currentMark == mark else {
            audit(false, "slab_mark_desync")
            return
        }

        audit(true, "schedule")

        aiSequence &+= 1
        let token = aiSequence
        let scheduledBoardIndex = activeBoardIndex
        let scheduledPhase = currentBoardPhase
        let scheduledMark = mark

        aiTask = Task { @MainActor [weak self] in
            guard let self else { return }

            defer { self.scheduleAIIfNeeded() }

            defer {
                self.isAIThinking = false
                self.aiWhisperLine = nil
                self.aiTask = nil
            }

            guard token == self.aiSequence else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "stale_token")
#endif
                return
            }

            let runningMode = self.session.gameMode
            guard runningMode == .vsAI || runningMode == .learning || runningMode == .aiVsAI else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "mode_not_ai_scheduled")
#endif
                return
            }

            self.isAIThinking = true
            if runningMode == .aiVsAI {
                self.aiWhisperLine = "Auto-play…"
            } else {
                self.aiWhisperLine = "O is drawing…"
            }

            let delayNanos: UInt64 = {
                if runningMode == .aiVsAI { return self.aiVsAIDelayPreset.nanoseconds }
                let lower: UInt64 = 350_000_000
                let upper: UInt64 = 550_000_000
                let span = Swift.max(upper - lower, 1)
                return lower + UInt64.random(in: 0..<span)
            }()

#if DEBUG
            GameDebugLogger.aiScheduled(
                boardIndex: scheduledBoardIndex,
                mark: scheduledMark,
                phase: scheduledPhase,
                delayNanoseconds: delayNanos,
                token: token
            )
#endif

            try? await Task.sleep(nanoseconds: delayNanos)

            if Task.isCancelled {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "task_cancelled")
#endif
                return
            }

            guard token == self.aiSequence else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "stale_token_after_sleep")
#endif
                return
            }

            guard self.remainingSeconds > 0 else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "timer_zero")
#endif
                return
            }
            guard self.session.sessionState == .playing else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "session_not_playing")
#endif
                return
            }
            guard self.session.gameMode == runningMode else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "mode_changed_mid_task")
#endif
                return
            }
            guard self.session.activeBoardIndex == scheduledBoardIndex else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(
                    reason: "active_board_changed expected=\(scheduledBoardIndex + 1) now=\(self.session.activeBoardIndex + 1)"
                )
#endif
                return
            }
            guard self.currentMark == scheduledMark else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "mark_changed mid_task expected=\(scheduledMark) got=\(self.currentMark)")
#endif
                return
            }

            let activePhase = self.currentBoardPhase
            guard activePhase == .firstMove || activePhase == .secondMove else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "invalid_phase")
#endif
                return
            }

            guard runningMode == .aiVsAI
                || ((runningMode == .vsAI || runningMode == .learning) && self.currentMark == .o)
            else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "vsAI_no_longer_o")
#endif
                return
            }

            let idx = self.session.activeBoardIndex
            guard self.session.boards.indices.contains(idx) else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "no_active_board")
#endif
                return
            }
            let slab = self.session.boards[idx]
            guard slab.playState == .inProgress else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "board_not_in_progress")
#endif
                return
            }

            let toPlay = self.currentMark
            guard toPlay == .x || toPlay == .o else {
#if DEBUG
                self.recordAiVsAIInvalidIfNeeded()
                GameDebugLogger.aiMoveIgnored(reason: "unexpected_mark_to_play")
#endif
                return
            }

            let opponent = toPlay.nextInTurn
            let aiTimerCtx = AIMoveTimerContext(
                remainingSeconds: self.remainingSeconds,
                totalSeconds: self.selectedDuration.seconds
            )
            let difficulty: AIDifficulty = self.session.gameMode == .learning
                ? self.learningProfile.adaptiveAIDifficulty()
                : self.session.aiDifficulty
            guard let cell = TicTacToeAI.chooseMove(
                on: slab,
                aiMark: toPlay,
                humanMark: opponent,
                difficulty: difficulty,
                timerContext: aiTimerCtx
            ) else {
#if DEBUG
                self.recordAiVsAIInvalidIfNeeded()
                GameDebugLogger.aiMoveIgnored(reason: "ai_choice_nil")
#endif
                return
            }

#if DEBUG
            GameDebugLogger.moveAttempt(
                boardIndex: idx,
                cellIndex: cell,
                mark: toPlay,
                phase: activePhase,
                formattedTime: self.formattedRemainingTime
            )
#endif

            do {
                let beforeSnap = self.session
                let applied = try GameEngine.applyMove(self.session, boardIndex: idx, cellIndex: cell)
                self.session = applied
                if applied.gameMode == .learning {
                    var p = self.learningProfile
                    LearningAnalyzer.applyBoardOutcomeDelta(before: beforeSnap.stats, after: applied.stats, profile: &p)
                    self.learningProfile = p
                }
                self.notifyAppliedMoveFeedback(
                    beforeStats: beforeSnap.stats,
                    afterStats: applied.stats,
                    learningSuccessfulBlock: false
                )
#if DEBUG
                self.bumpAiVsAIBoardResetIfNeeded(before: beforeSnap, after: applied)
                GameDebugLogger.aiMoveApplied(boardIndex: idx, cellIndex: cell, mark: toPlay)
                if applied.gameMode == .aiVsAI {
                    let n = GameDebugLogger.snapshotEvery
                    if n > 0, applied.stats.totalMoves % n == 0 {
                        GameDebugLogger.snapshot(session: self.session, formattedTime: self.formattedRemainingTime)
                    }
                } else {
                    GameDebugLogger.snapshot(session: self.session, formattedTime: self.formattedRemainingTime)
                }
#endif
            } catch {
#if DEBUG
                self.recordAiVsAIInvalidIfNeeded()
                GameDebugLogger.aiMoveIgnored(reason: "apply_throw:\(error)")
#endif
            }
        }
    }
}

#if DEBUG
extension GameViewModel {
    fileprivate func bumpAiVsAIBoardResetIfNeeded(before: GameSession, after: GameSession) {
        guard after.gameMode == .aiVsAI else { return }
        let o0 = before.stats.xBoardWins + before.stats.oBoardWins + before.stats.boardDraws
        let o1 = after.stats.xBoardWins + after.stats.oBoardWins + after.stats.boardDraws
        if o1 > o0 { aiVsAIDebugBoardResetCount += 1 }
    }

    fileprivate func recordAiVsAIInvalidIfNeeded() {
        guard session.gameMode == .aiVsAI else { return }
        aiVsAIDebugInvalidMoves += 1
    }
}
#endif

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
