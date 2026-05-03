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
    /// Monotonic / wall source for countdown deadlines (**`Mock + TestClock`** može zaključati testove).
    private let now: () -> Date

    /// Kada je postavljeno (samo **`@testable`** testovi), preskače slučajnu vsAI pause.
    internal var aiThinkDelayNanosecondsOverrideForTests: UInt64?

    /// True when the slab is paced by **`TicTacToeAI`** (**`vsAI`** / **`learning`**: mark suprotan od **`humanControlledMark`**).
    var isAITurn: Bool {
        guard session.sessionState == .playing else { return false }
        switch session.gameMode {
        case .vsAI, .learning:
            let human = session.humanControlledMark ?? .x
            return currentMark == human.nextInTurn
        case .aiVsAI: return true
        default: return false
        }
    }

    /// **DEBUG **`aiVsAI`** autoplay pacing** (**`normal`** · **`fast`** · **`instant`**). Ignored outside **`GameMode.aiVsAI`**.
    var aiVsAIDelayPreset: AIDebugDelayPreset = .fast

    /// Last selected AI strength for **`vsAI`** / **`aiVsAI`** (persisted across **`startNewGame`** / **`resetGame`**).
    private var preferredAIDifficulty: AIDifficulty = .easy

    /// Ponovno korišćenje u **`resetGame`** za **vsAI** / **learning**.
    private var persistedPvAIHumanMark: Mark = .x
    private var persistedPvAIFirstMover: FirstMoverChoice = .player

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

    /// Human cannot place marks while AI “thinks” ili kada nije red na **`humanControlledMark`**; **`aiVsAI`** je potpuno automatski.
    var isInputLocked: Bool {
        guard session.sessionState == .playing else { return true }
        if isAIThinking { return true }
        if session.gameMode == .aiVsAI { return true }
        if session.gameMode == .vsAI || session.gameMode == .learning {
            let human = session.humanControlledMark ?? .x
            if currentMark != human { return true }
        }
        return false
    }

    /// Populated while **`GameMode.learning`** is active (čovek vs adaptivni AI).
    private(set) var learningProfile: LearningProfile = .initial

    private(set) var selectedDuration: GameDuration = .oneMinute
    /// Preostalo vreme na satu igrača **X** (sesija).
    private(set) var xRemainingSeconds: Int = GameDuration.oneMinute.seconds
    /// Preostalo vreme na satu igrača **O** (sesija).
    private(set) var oRemainingSeconds: Int = GameDuration.oneMinute.seconds
    /// Čiji se sat trenutno odbrojava u **`GameTimerService`** (samo jedan aktivan).
    private var timerActiveForMark: Mark?
    /// Wall-clock trenutak kada ističe preostalo vreme za **`timerActiveForMark`** (uključujući AI pauzu; ne pauzira se za **`isAIThinking`**).
    private var activeClockDeadline: Date?
    private(set) var isTimerRunning: Bool = false
    private(set) var completionReason: CompletionReason?

    /// Dok nema ni jednog markera na ijednoj tabli, ne palimo **`GameTimerService`** (**`scheduleAIIfNeeded`** i dalje radi).
    @ObservationIgnored private var playClockSuspendedUntilFirstMark: Bool = false

    /// Kratak vizuelni signal nakon **vsAI / learning** pobjede igrača na tabli (vidi **`TimeRewardEvent`**).
    private(set) var latestTimeReward: TimeRewardEvent?
    /// Menja se pri svakoj novoj najavi (**SwiftUI** **`.id`** / animacija bez merge-a istih vrijednosti).
    private(set) var timeRewardAnnouncementID: UInt64 = 0
    private var clearTimeRewardTask: Task<Void, Never>?

#if DEBUG
    /// Vizuelni DEBUG audit sata (**`GameView.showClockAuditOverlay`**).
    var debugClockAuditTimerActiveMark: Mark? { timerActiveForMark }
#endif

    /// Aktivni igrač (**`currentMark`**) — zgodno za AI i hitne provere.
    var remainingSeconds: Int {
        switch currentMark {
        case .x: return xRemainingSeconds
        case .o: return oRemainingSeconds
        case .empty: return min(xRemainingSeconds, oRemainingSeconds)
        }
    }

    var formattedRemainingTime: String { Self.formatClockDigits(remainingSeconds) }

    var formattedXRemainingTime: String { Self.formatClockDigits(xRemainingSeconds) }

    var formattedORemainingTime: String { Self.formatClockDigits(oRemainingSeconds) }

    private static func formatClockDigits(_ seconds: Int) -> String {
        let bounded = max(seconds, 0)
        let mins = bounded / 60
        let secs = bounded % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private static let boardDrawTimeBonusSeconds: Int = 5
    /// vsAI / learning: pomeraj vremena kad **čovek** pobedi tablu.
    private static let vsAILearningHumanBoardWinRewardShiftSeconds: Int = 5
    /// Gornja granica **čovekove** banke nakon nagrade: **`selectedDuration` + ovo**.
    private static let vsAILearningHumanTimeCapOverInitialSeconds: Int = 15
    /// Donja granica **AI** banke nakon nagrade.
    private static let vsAILearningAiTimeFloorAfterRewardSeconds: Int = 3
    /// Koliko dugo drži **`latestTimeReward`** prije auto-brisanja (**~1.2s**, usklađeno sa HUD fade pulsom).
    private static let timeRewardFeedbackVisibilityNanoseconds: UInt64 = 1_220_000_000

    private func secondsForMark(_ mark: Mark) -> Int {
        switch mark {
        case .x: return xRemainingSeconds
        case .o: return oRemainingSeconds
        case .empty: return 0
        }
    }

    private static func sessionHasAnyMarkedCell(_ session: GameSession) -> Bool {
        session.boards.contains { slab in slab.cells.contains { $0.mark != .empty } }
    }

    private static func playClockSuspendedForSession(_ session: GameSession) -> Bool {
        session.sessionState == .playing && !sessionHasAnyMarkedCell(session)
    }

    /// Zaustavlja sat, opciono dodeljuje bonus nerešenom mini‑krugu, ponovo pokreće sat za **`currentMark`**.
    /// **`movedBoardIndex`**: tabla na kojoj je **`applyMove`** izvršen (za **`GAMEPLAY_DRAW`**, ne aktivna posle **`GameEngine`**).
    private func resyncClocksAfterMove(from before: GameSession, to after: GameSession, movedBoardIndex: Int? = nil) {
        snapOutgoingClockFromDeadlineBeforeStopping()
        stopTimer()
        if after.stats.boardDraws > before.stats.boardDraws {
            xRemainingSeconds += Self.boardDrawTimeBonusSeconds
            oRemainingSeconds += Self.boardDrawTimeBonusSeconds
#if DEBUG
            GameDebugLogger.drawBonusApplied(
                secondsEach: Self.boardDrawTimeBonusSeconds,
                xAfter: xRemainingSeconds,
                oAfter: oRemainingSeconds
            )
            let drawBoard = movedBoardIndex ?? before.activeBoardIndex
            GameDebugLogger.logDraw(
                board: drawBoard + 1,
                xTime: xRemainingSeconds,
                oTime: oRemainingSeconds
            )
#endif
        } else if after.gameMode == .vsAI || after.gameMode == .learning,
                  let humanMark = after.humanControlledMark {
            let humanWonBoard =
                (humanMark == .x && after.stats.xBoardWins > before.stats.xBoardWins)
                || (humanMark == .o && after.stats.oBoardWins > before.stats.oBoardWins)
            if humanWonBoard {
                applyHumanVsAIWinReward(humanMark: humanMark)
#if DEBUG
                GameDebugLogger.rewardApplied(
                    winner: humanMark,
                    xAfter: xRemainingSeconds,
                    oAfter: oRemainingSeconds
                )
                GameDebugLogger.logReward(xTime: xRemainingSeconds, oTime: oRemainingSeconds)
#endif
                presentBoardWinTimeRewardFeedback(.humanBoardWinAgainstAI(humanMark: humanMark))
            }
        }
        startTimerIfNeeded()
    }

    private func applyHumanVsAIWinReward(humanMark: Mark) {
        let shift = Self.vsAILearningHumanBoardWinRewardShiftSeconds
        let cap = selectedDuration.seconds + Self.vsAILearningHumanTimeCapOverInitialSeconds
        let floorSecs = Self.vsAILearningAiTimeFloorAfterRewardSeconds
        switch humanMark {
        case .x:
            xRemainingSeconds += shift
            oRemainingSeconds -= shift
            xRemainingSeconds = min(xRemainingSeconds, cap)
            oRemainingSeconds = max(oRemainingSeconds, floorSecs)
        case .o:
            oRemainingSeconds += shift
            xRemainingSeconds -= shift
            oRemainingSeconds = min(oRemainingSeconds, cap)
            xRemainingSeconds = max(xRemainingSeconds, floorSecs)
        case .empty:
            break
        }
    }

    private func presentBoardWinTimeRewardFeedback(_ event: TimeRewardEvent) {
        clearTimeRewardTask?.cancel()
        latestTimeReward = event
        timeRewardAnnouncementID += 1
        HapticService.success()
        clearTimeRewardTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.timeRewardFeedbackVisibilityNanoseconds)
            guard let self else { return }
            if !Task.isCancelled {
                latestTimeReward = nil
            }
        }
    }

    private func cancelTimeRewardFeedback() {
        clearTimeRewardTask?.cancel()
        clearTimeRewardTask = nil
        latestTimeReward = nil
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
        timerService: GameTimerControlling,
        now: @escaping () -> Date = { Date() }
    ) {
        _ = services
        self.timerService = timerService
        self.now = now
        let initial = session ?? GameEngine.makeIdleSession()
        self.session = initial
        self.playClockSuspendedUntilFirstMark = Self.playClockSuspendedForSession(initial)
        _ = SoundService.shared
    }

    convenience init(session: GameSession? = nil, services: AppServices = AppServices()) {
        self.init(session: session, services: services, timerService: GameTimerService(), now: { Date() })
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
            isFocusedBoard: focused,
            humanControlledMark: session.humanControlledMark
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

    func startNewGame(
        mode: GameMode,
        duration: GameDuration = .oneMinute,
        pvaiHumanMark: Mark? = nil,
        pvaiFirstMover: FirstMoverChoice? = nil
    ) {
        selectedDuration = duration
        let full = duration.seconds
        xRemainingSeconds = full
        oRemainingSeconds = full
        completionReason = nil
        cancelTimeRewardFeedback()
        cancelAIPipeline(debugLogCancel: true)
        stopTimer()
        if mode == .vsAI || mode == .learning {
            let h = pvaiHumanMark ?? .x
            let fm = pvaiFirstMover ?? .player
            persistedPvAIHumanMark = h
            persistedPvAIFirstMover = fm
            session = GameEngine.makeInitialSession(
                mode: mode,
                humanControlledMark: h,
                firstMover: fm
            )
        } else {
            session = GameEngine.makeInitialSession(mode: mode)
        }
        playClockSuspendedUntilFirstMark = Self.playClockSuspendedForSession(session)
        learningProfile = .initial
        switch mode {
        case .vsAI, .learning, .aiVsAI:
            session.aiDifficulty = preferredAIDifficulty
        default:
            break
        }
#if DEBUG
        if mode == .aiVsAI {
            aiVsAIDebugBoardResetCount = 0
            aiVsAIDebugInvalidMoves = 0
            aiVsAIDebugStartedAt = now()
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
            isFocusedBoard: focusedBoardIndex.map { $0 == boardIndex } ?? false,
            humanControlledMark: session.humanControlledMark
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
                let humanM = beforeSession.humanControlledMark ?? .x
                LearningAnalyzer.processHumanMove(
                    preBoard: preBoard,
                    postBoard: postBoard,
                    cellIndex: cellIndex,
                    aiMark: humanM.nextInTurn,
                    profile: &p
                )
                LearningAnalyzer.applyBoardOutcomeDelta(
                    before: beforeSession.stats,
                    after: next.stats,
                    humanControlledMark: humanM,
                    profile: &p
                )
                learningBlockIncremented = p.successfulBlocks > learningBlocksBefore
                learningProfile = p
            }
            notifyAppliedMoveFeedback(
                beforeStats: beforeSession.stats,
                afterStats: next.stats,
                learningSuccessfulBlock: learningBlockIncremented
            )
            resyncClocksAfterMove(from: beforeSession, to: next, movedBoardIndex: boardIndex)
#if DEBUG
            let placedMark = beforeSession.boards[boardIndex].currentMark
            GameDebugLogger.logMove(
                board: boardIndex + 1,
                mark: placedMark,
                cell: cellIndex + 1,
                xTime: xRemainingSeconds,
                oTime: oRemainingSeconds
            )
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
        let full = selectedDuration.seconds
        xRemainingSeconds = full
        oRemainingSeconds = full
        completionReason = nil
        cancelTimeRewardFeedback()
        cancelAIPipeline(debugLogCancel: true)
#if DEBUG
        if session.gameMode == .vsAI || session.gameMode == .learning {
            GameDebugLogger.vsAIVerifyResetCancelledPendingAI()
        }
#endif
        stopTimer()
        let mode = session.gameMode
        if mode == .vsAI || mode == .learning {
            session = GameEngine.makeInitialSession(
                mode: mode,
                humanControlledMark: persistedPvAIHumanMark,
                firstMover: persistedPvAIFirstMover
            )
        } else {
            session = GameEngine.makeInitialSession(mode: mode)
        }
        playClockSuspendedUntilFirstMark = Self.playClockSuspendedForSession(session)
        switch mode {
        case .vsAI, .learning, .aiVsAI:
            session.aiDifficulty = preferredAIDifficulty
        default:
            break
        }
#if DEBUG
        if mode == .aiVsAI {
            aiVsAIDebugBoardResetCount = 0
            aiVsAIDebugInvalidMoves = 0
            aiVsAIDebugStartedAt = now()
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
        if session.gameMode == .vsAI || session.gameMode == .learning {
            let human = session.humanControlledMark ?? .x
            if currentMark != human { return }
        }
        guard let next = GameEngine.advanceFocus(session) else { return }
        session = next
        snapOutgoingClockFromDeadlineBeforeStopping()
        stopTimer()
        startTimerIfNeeded()
#if DEBUG
        GameDebugLogger.snapshot(session: session, formattedTime: formattedRemainingTime)
#endif
        scheduleAIIfNeeded()
    }

    func selectDuration(_ duration: GameDuration) {
        selectedDuration = duration
        if session.sessionState == .notStarted || session.sessionState == .completed {
            let full = duration.seconds
            xRemainingSeconds = full
            oRemainingSeconds = full
        }
    }

    func onGameViewAppear() {
        startTimerIfNeeded()
        scheduleAIIfNeeded()
    }

    func onGameViewDisappear() {
        cancelTimeRewardFeedback()
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
        let mark = currentMark
        guard mark == .x || mark == .o else { return }

        if playClockSuspendedUntilFirstMark {
            guard Self.sessionHasAnyMarkedCell(session) else {
                scheduleAIIfNeeded()
                return
            }
            playClockSuspendedUntilFirstMark = false
        }

#if DEBUG
        var switchedFromTimerMark: Mark? = nil
#endif
        if isTimerRunning {
            if timerActiveForMark == mark {
                scheduleAIIfNeeded()
                return
            }
#if DEBUG
            switchedFromTimerMark = timerActiveForMark
#endif
            snapOutgoingClockFromDeadlineBeforeStopping()
            stopTimer()
        }

        let secs = secondsForMark(mark)
        guard secs > 0 else {
            completeForTimeExpiryIfNeeded(finishedMark: mark)
            return
        }
#if DEBUG
        if let fm = switchedFromTimerMark, fm != mark {
            GameDebugLogger.clockSwitch(
                from: fm,
                to: mark,
                boardOneBased: session.activeBoardIndex + 1
            )
            GameDebugLogger.logSwitch(
                from: fm,
                to: mark,
                board: session.activeBoardIndex + 1,
                xTime: xRemainingSeconds,
                oTime: oRemainingSeconds
            )
        }
#endif
        timerActiveForMark = mark
        let runningMark = mark
        activeClockDeadline = now().addingTimeInterval(TimeInterval(secs))
        timerService.start(
            seconds: secs,
            onTick: { [weak self] seconds in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard self.session.sessionState == .playing else { return }
                    let live = self.session.currentMarkForActiveBoard
                    guard live == runningMark else { return }
                    let left: Int
                    if self.activeClockDeadline != nil {
                        left = self.updateClockBankFromDeadline(for: runningMark)
                    } else {
                        left = seconds
                        switch runningMark {
                        case .x: self.xRemainingSeconds = seconds
                        case .o: self.oRemainingSeconds = seconds
                        case .empty: break
                        }
                    }
#if DEBUG
                    GameDebugLogger.logClockTick(
                        activeMark: runningMark,
                        xTime: self.xRemainingSeconds,
                        oTime: self.oRemainingSeconds
                    )
#endif
                    if left == 0 {
                        self.completeForTimeExpiryIfNeeded(finishedMark: runningMark)
                    }
                }
            },
            onFinished: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.completeForTimeExpiryIfNeeded(finishedMark: runningMark)
                }
            }
        )
        isTimerRunning = true
        scheduleAIIfNeeded()
    }

    private func stopTimer() {
        timerService.stop()
        isTimerRunning = false
        timerActiveForMark = nil
        activeClockDeadline = nil
    }

    /// Snima proteklo wall vreme u banku pre **`stopTimer()`** (npr. potez kraći od 1 s — **`GameTimerService`** ne okine).
    private func snapOutgoingClockFromDeadlineBeforeStopping() {
        guard let m = timerActiveForMark, m == .x || m == .o else { return }
        _ = updateClockBankFromDeadline(for: m)
    }

    /// Deadline → preostale **cele** sekunde za HUD i banku.
    ///
    /// **`Int(floor(dt))`** kod tikova koji stignu malo kasno mogao je da spusti prikaz za **2+** u jednom intervalu (~**`dt ≈ k − 0.02`** → **floor** daje **k−1**, a trebalo je **k** za „jedna protekla sekunda“).
    /// Za **`dt > 0`** koristimo **`ceil(max(0, dt − ε))`** (mali **ε** sprečava grešku na floating-point granici). Za **`dt ≤ 0`** vraćamo **0** tako da istek i **`completeForTimeExpiryIfNeeded`** ostanu tačni.
    private static func wholeSecondsRemainingUntilDeadline(_ deadline: Date, relativeTo nowDate: Date) -> Int {
        let dt = deadline.timeIntervalSince(nowDate)
        guard dt > 0 else { return 0 }
        let adjusted = Swift.max(0, dt - 1e-9)
        return Swift.max(0, Int(ceil(adjusted)))
    }

    /// Samo čitanje preostalog vremena sa **`activeClockDeadline`** (bez menjanja **`@Observable`** stanja — za log ili brzu proveru).
    private func peekWallRemainingSeconds(for armMark: Mark) -> Int {
        guard armMark == .x || armMark == .o else { return 0 }
        guard armMark == timerActiveForMark, let deadline = activeClockDeadline else {
            return secondsForMark(armMark)
        }
        return Self.wholeSecondsRemainingUntilDeadline(deadline, relativeTo: now())
    }

    /// Vraća preostale sekunde za **`armMark`** nakon usklađivanja sa **`activeClockDeadline`**.
    /// Kreće se samo kada **`armMark`** odgovara trenutno naoružanom **`GameTimerService`** (**`timerActiveForMark`**); u suprotnom ne prepisuje banku nevidljive boje (**`deadline`** je zajednički).
    private func updateClockBankFromDeadline(for armMark: Mark) -> Int {
        guard armMark == .x || armMark == .o else { return 0 }
        guard armMark == timerActiveForMark else {
            return secondsForMark(armMark)
        }
        guard let deadline = activeClockDeadline else {
            return secondsForMark(armMark)
        }
        let left = Self.wholeSecondsRemainingUntilDeadline(deadline, relativeTo: now())
        switch armMark {
        case .x: xRemainingSeconds = left
        case .o: oRemainingSeconds = left
        default: break
        }
        return left
    }

    private func completeForTimeExpiryIfNeeded(finishedMark: Mark? = nil) {
        guard session.sessionState == .playing else {
            stopTimer()
            return
        }
        let expiredMark = finishedMark ?? timerActiveForMark
        guard let expiredMark, expiredMark == .x || expiredMark == .o else {
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
        switch expiredMark {
        case .x:
            xRemainingSeconds = 0
            completionReason = .xTimedOut
        case .o:
            oRemainingSeconds = 0
            completionReason = .oTimedOut
        case .empty:
            completionReason = .timeExpired
        }
#if DEBUG
        GameDebugLogger.logTimeout(
            loser: expiredMark,
            xTime: xRemainingSeconds,
            oTime: oRemainingSeconds
        )
        GameDebugLogger.timeOut(loser: expiredMark)
#endif
        var next = session
        next.sessionState = .completed
        HapticService.heavyImpact()
        SoundService.shared.playCompletion()
#if DEBUG
        if session.gameMode == .aiVsAI {
            let elapsed = aiVsAIDebugStartedAt.map { Int(now().timeIntervalSince($0)) } ?? selectedDuration.seconds
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
        stopTimer()
#if DEBUG
        let reasonLog: String = {
            switch expiredMark {
            case .x: return "x_timed_out"
            case .o: return "o_timed_out"
            case .empty: return "time_expired"
            }
        }()
        GameDebugLogger.sessionCompleted(reason: reasonLog)
#endif
    }

    /// Central AI scheduler: **`aiVsAI`** oba markera; **`vsAI`** / **`learning`** samo kada je red na **AI** marku (`humanControlledMark.nextInTurn`).
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

        let aiMark = (session.humanControlledMark ?? .x).nextInTurn
        let requiresCentralAI = mode == .aiVsAI || ((mode == .vsAI || mode == .learning) && mark == aiMark)
        guard requiresCentralAI else {
            audit(false, "not_central_ai_mode")
            return
        }
        guard session.sessionState == .playing else {
            audit(false, "session_not_playing")
            return
        }
        guard secondsForMark(mark) > 0 else {
            audit(false, "timer_zero")
            return
        }
        guard aiTask == nil else {
            audit(false, "ai_task_inflight")
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
                self.aiWhisperLine = "AI is thinking…"
            }

            let computedDelayNanos: UInt64
            let thinkLogRemaining: Int
            let thinkLogDifficulty: String
            let thinkLogReason: String
            if runningMode == .aiVsAI {
                computedDelayNanos = self.aiVsAIDelayPreset.nanoseconds
                thinkLogRemaining = self.secondsForMark(scheduledMark)
                thinkLogDifficulty = self.session.aiDifficulty.rawValue
                thinkLogReason = "aiVsAI_debug_preset=\(self.aiVsAIDelayPreset.rawValue)"
            } else {
                let effectiveDifficulty: AIDifficulty =
                    self.session.gameMode == .learning
                    ? self.learningProfile.adaptiveAIDifficulty()
                    : self.session.aiDifficulty
                let remainingForCap = self.secondsForMark(scheduledMark)
                let vSeed = AIThinkingDelay.variationSeed(
                    board: slabSnapshot,
                    difficulty: effectiveDifficulty,
                    token: token
                )
                let computed = AIThinkingDelay.nanoseconds(
                    difficulty: effectiveDifficulty,
                    aiRemainingSeconds: remainingForCap,
                    board: slabSnapshot,
                    aiMark: scheduledMark,
                    opponentMark: scheduledMark.nextInTurn,
                    variationSeed: vSeed
                )
                computedDelayNanos = computed.nanoseconds
                thinkLogRemaining = remainingForCap
                thinkLogDifficulty = effectiveDifficulty.rawValue
                thinkLogReason = computed.reason
            }

            let delayNanos = self.aiThinkDelayNanosecondsOverrideForTests ?? computedDelayNanos

#if DEBUG
            GameDebugLogger.aiThink(
                delaySeconds: Double(delayNanos) / 1_000_000_000.0,
                remaining: thinkLogRemaining,
                difficulty: thinkLogDifficulty,
                reason: thinkLogReason
            )
            GameDebugLogger.aiScheduled(
                boardIndex: scheduledBoardIndex,
                mark: scheduledMark,
                phase: scheduledPhase,
                delayNanoseconds: delayNanos,
                token: token
            )
#endif

#if DEBUG
            GameDebugLogger.logAIThinkStart(oTime: self.oRemainingSeconds)
            GameDebugLogger.aiThinkStartDetailed(
                active: scheduledMark,
                xRemain: self.xRemainingSeconds,
                oRemain: self.oRemainingSeconds
            )
#endif
            try? await Task.sleep(nanoseconds: delayNanos)

            if Task.isCancelled {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "task_cancelled")
#endif
                return
            }

#if DEBUG
            GameDebugLogger.aiThinkEndDetailed(
                active: scheduledMark,
                xRemain: self.xRemainingSeconds,
                oRemain: self.oRemainingSeconds
            )
#endif

            guard token == self.aiSequence else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "stale_token_after_sleep")
#endif
                return
            }

            guard self.session.sessionState == .playing else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "session_not_playing")
#endif
                return
            }

            if self.peekWallRemainingSeconds(for: scheduledMark) <= 0 {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "timer_zero")
#endif
                self.completeForTimeExpiryIfNeeded(finishedMark: scheduledMark)
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

            let aiScheduledMark = (self.session.humanControlledMark ?? .x).nextInTurn
            guard runningMode == .aiVsAI
                || ((runningMode == .vsAI || runningMode == .learning) && self.currentMark == aiScheduledMark)
            else {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "vsAI_no_longer_ai_mark")
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
            _ = self.updateClockBankFromDeadline(for: toPlay)
            if self.secondsForMark(toPlay) <= 0 {
#if DEBUG
                GameDebugLogger.aiMoveIgnored(reason: "timer_zero_before_choice")
#endif
                self.completeForTimeExpiryIfNeeded(finishedMark: toPlay)
                return
            }
            let aiTimerCtx = AIMoveTimerContext(
                remainingSeconds: self.secondsForMark(toPlay),
                totalSeconds: self.selectedDuration.seconds
            )
            let difficultyForMove: AIDifficulty = self.session.gameMode == .learning
                ? self.learningProfile.adaptiveAIDifficulty()
                : self.session.aiDifficulty

            let slabCopy = slab
            let aiMarkSnapshot = toPlay
            let humanMarkSnapshot = opponent
            let cellOpt = await Task.detached(priority: .utility) {
                TicTacToeAI.chooseMove(
                    on: slabCopy,
                    aiMark: aiMarkSnapshot,
                    humanMark: humanMarkSnapshot,
                    difficulty: difficultyForMove,
                    timerContext: aiTimerCtx
                )
            }.value

            guard let cell = cellOpt else {
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
                _ = self.updateClockBankFromDeadline(for: toPlay)
                if self.secondsForMark(toPlay) <= 0 {
#if DEBUG
                    GameDebugLogger.aiMoveIgnored(reason: "timer_zero_before_apply")
#endif
                    self.completeForTimeExpiryIfNeeded(finishedMark: toPlay)
                    return
                }
                let beforeSnap = self.session
                let applied = try GameEngine.applyMove(self.session, boardIndex: idx, cellIndex: cell)
                self.session = applied
                if applied.gameMode == .learning {
                    var p = self.learningProfile
                    LearningAnalyzer.applyBoardOutcomeDelta(
                        before: beforeSnap.stats,
                        after: applied.stats,
                        humanControlledMark: self.session.humanControlledMark ?? .x,
                        profile: &p
                    )
                    self.learningProfile = p
                }
                self.notifyAppliedMoveFeedback(
                    beforeStats: beforeSnap.stats,
                    afterStats: applied.stats,
                    learningSuccessfulBlock: false
                )
                self.resyncClocksAfterMove(from: beforeSnap, to: applied, movedBoardIndex: idx)
#if DEBUG
                GameDebugLogger.logMove(
                    board: idx + 1,
                    mark: aiMarkSnapshot,
                    cell: cell + 1,
                    xTime: self.xRemainingSeconds,
                    oTime: self.oRemainingSeconds
                )
                GameDebugLogger.logAIThinkEnd(oTime: self.oRemainingSeconds)
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
