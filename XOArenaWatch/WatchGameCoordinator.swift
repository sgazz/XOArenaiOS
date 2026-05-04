//
//  WatchGameCoordinator.swift
//  XOArenaWatch
//

import Combine
import Foundation
import SwiftUI

/// Watch gameplay hub: **`ObservableObject` + `@Published`** so slab UI always flows from **`visibleBoardCells`** / **`visibleBoardID`**, never from raw **`GameSession`** in views.
@MainActor
final class WatchGameCoordinator: ObservableObject {
    enum Route: Equatable {
        case intro
        case setup
        case game
        case end(WatchEndSummary)
    }

    struct WatchEndSummary: Equatable {
        var headline: String
        var humanScore: Int
        var aiScore: Int
        var duration: GameDuration
        /// Watch feel: match ended when clock hit 0 (for haptic layering).
        var endedByTime: Bool = false
        /// **No Time** manual end: **`"Played mm:ss"`**; **`nil`** → show **`duration.title`** (timed).
        var endDurationRowSubtitle: String? = nil
    }

    enum BoardFeedback: Equatable {
        case playerPlusOne
        case aiPlusOne
        case draw
    }

    @Published var route: Route = .intro

    @Published var setupSymbol: PlayerSymbolChoice = .x
    @Published var setupFirst: FirstMoverChoice = .player
    @Published var setupDuration: GameDuration = .threeMinutes

    @Published private(set) var session: GameSession = GameEngine.makeIdleSession()
    @Published private(set) var isAIThinking: Bool = false

    /// Watch-only slab transition (**idle** · **preview** hold · vertical **scroll** to next slab).
    enum BoardTransitionPhase: Equatable {
        case idle
        case previewing
        case scrolling
    }

    @Published private(set) var boardTransitionPhase: BoardTransitionPhase = .idle
    /// 0 → top slab (former “current”); animates toward 1 (“incoming” aligns with clip).
    @Published private(set) var verticalBoardScrollFraction: CGFloat = 0
    /// Cells for the slab **`session` already advanced to** — shown underneath during **`scrolling`**.
    @Published private(set) var incomingBoardCells: [String] =
        Array(repeating: "", count: GameConstants.cellCount)
    @Published private(set) var incomingBoardID = UUID()

    /// Single match countdown (wall clock from first game screen).
    @Published private(set) var matchSecondsRemaining: Int = 0

    /// Start instant for **No Time** sessions → **Played …** on End screen.
    private(set) var matchStartDate: Date?

    @Published private(set) var boardFeedback: BoardFeedback?
    @Published private(set) var showLowTimeHint: Bool = false

    /// When **`false`**, defer draw-breathing **`Timer`** in **`WatchBoardView`** (avoids waking display during background/inactive).
    @Published private(set) var allowsLiveBoardEffects: Bool = true

    /// Cell taps / destructive actions gated off during **`shutdownForBackground()`** (**`resume`** restores).
    @Published private(set) var inputEnabled: Bool = true

    /// Grid shown on Watch (**ONLY** **`""`** / **`"X"`** / **`"O"`**); paired with **`visibleBoardID`** for hard invalidation.
    @Published var visibleBoardCells: [String] = Array(repeating: "", count: 9)
    @Published var visibleBoardID = UUID()
    /// Must match **`session.activeBoardIndex`** after every **`syncFromEngine`** (diagnostic / hero alignment).
    @Published private(set) var visibleBoardIndex: Int = 0
    /// Slab **`playState == .inProgress`** (synced alongside strings).
    @Published private(set) var visibleBoardAllowsMoves: Bool = false

    /// Optional quick fade-in for the cell AI just filled (no board advance).
    @Published private(set) var feelAIMarkFadeCell: Int?

    private var matchTimer: Timer?
    private var feedbackReset: Task<Void, Never>?
    private var aiSequence: UInt64 = 0
    /// Bumped in **`cancelAITask()`** so a superseded **`aiTask`** **`defer`** does not clear **`aiTask`** belonging to a newer run (**watchOS**, fast match restarts).
    private var aiRunEpoch: UInt64 = 0
    private var aiTask: Task<Void, Never>?
    private var boardPreviewTask: Task<Void, Never>?
    /// Human non-advance path uses an untracked **`Task`** unless stored here (**must cancel on background**).
    private var postMoveLooseTask: Task<Void, Never>?
    private var aiFadeClearTask: Task<Void, Never>?

    /// Scene not active — match ticker / AI / transitions must not run (published so intro pulse can exit).
    @Published private(set) var suspendedForBackground: Bool = false

    private var lastLoggedHeroBoardLabel: String?

    /// Who just applied a move — drives non-advance follow-up (AI fade vs scheduling).
    private enum PostMoveActor {
        case human
        case ai(cell: Int)
    }

    private var humanMark: Mark { setupSymbol.mark }
    private var aiMark: Mark { humanMark.nextInTurn }

    var boards: [XOBoard] { session.boards }
    var activeBoardIndex: Int { session.activeBoardIndex }
    var currentMark: Mark { session.currentMarkForActiveBoard }

    /// **`false`** for Watch unlimited sessions (**`∞`** hero bar, no countdown / auto end).
    private var matchClockRuns: Bool {
        setupDuration != .noTime
    }

    /// Feeds **`AIThinkingDelay`** so untimed sessions do not clamp thinking to **`aiRemainingSeconds < 10`**.
    private var aiThinkingDelayRemainingSecondsSynthetic: Int {
        matchClockRuns ? matchSecondsRemaining : GameDuration.fiveMinutes.seconds
    }

    /// Match clock for compact hero bar (**`m:ss`** or **`∞`**).
    var remainingTimeText: String {
        guard matchClockRuns else { return "∞" }
        let t = max(0, matchSecondsRemaining)
        let m = t / 60
        let s = t % 60
        return String(format: "%d:%02d", m, s)
    }

    var playerScore: Int {
        let hMark = session.humanControlledMark ?? humanMark
        return hMark == .x ? session.stats.xBoardWins : session.stats.oBoardWins
    }

    var aiScore: Int {
        let hMark = session.humanControlledMark ?? humanMark
        let aiM = hMark.nextInTurn
        return aiM == .x ? session.stats.xBoardWins : session.stats.oBoardWins
    }

    /// Minimal hero-bar match score (**`human : ai`** slab wins).
    var compactHeroScoreText: String {
        "\(playerScore) : \(aiScore)"
    }

    /// **`B1`… `B`** — preview shows completed slab index; scrolling + idle track engine active (**display 1-based**).
    private var heroBoardDisplayIndex1Based: Int {
        guard case .game = route else { return 1 }
        let rawBoardIndex: Int
        switch boardTransitionPhase {
        case .previewing:
            rawBoardIndex = visibleBoardIndex
        case .idle, .scrolling:
            rawBoardIndex = activeBoardIndex
        }
        let upperBound = max(session.boards.count - 1, 0)
        let clamped = min(max(rawBoardIndex, 0), upperBound)
        return clamped + 1
    }

    var heroBoardLabelCompact: String {
        "B\(heroBoardDisplayIndex1Based)"
    }

    var isNoTimeMode: Bool {
        guard case .game = route else { return false }
        return setupDuration == .noTime
    }

    /// Elapsed wall clock for an active **No Time** match (`mm:ss`; opt. live UI / debug).
    var elapsedTimeText: String? {
        guard !suspendedForBackground else { return nil }
        guard isNoTimeMode, let start = matchStartDate else { return nil }
        let t = max(0, Int(Date().timeIntervalSince(start).rounded(.down)))
        let m = t / 60
        let s = t % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Winning cells for subtle preview accent (completed slab only).
    var previewWinningHighlightIndices: Set<Int>? {
        guard boardTransitionPhase == .previewing || boardTransitionPhase == .scrolling else { return nil }
        return WatchBoardWinLine.winningIndices(from: visibleBoardCells)
    }

    /// Draw slab during preview — soft cell breathing.
    var isBoardPreviewingDraw: Bool {
        guard boardTransitionPhase == .previewing || boardTransitionPhase == .scrolling else { return false }
        guard previewWinningHighlightIndices == nil else { return false }
        return visibleBoardCells.allSatisfy { $0 == "X" || $0 == "O" }
    }

    private var routeDiagnosticLabel: String {
        Self.routeLabel(route)
    }

    /// Stable route name for **`NAV_STATE_CHANGE`** (**`end`** drops summary payload).
    private static func routeLabel(_ r: Route) -> String {
        switch r {
        case .intro: return "intro"
        case .setup: return "setup"
        case .game: return "game"
        case .end: return "end"
        }
    }

    /// Single place for **`route`** writes (**`navigation`** / **`Group`** `switch`) so logs stay truthful.
    private func navigateRoute(to newRoute: Route) {
        let prev = route
        guard prev != newRoute else { return }
        route = newRoute
        print(
            "[XOArenaWatch] NAV_STATE_CHANGE from=\(Self.routeLabel(prev)) to=\(Self.routeLabel(newRoute))"
        )
    }

    /// Cancel slab preview / AI / loose tasks before leaving **`.game`** so SwiftUI transitions do not overlap animated board scroll.
    private func prepareMatchEndNavigation() {
        stopMatchTicker()
        cancelBoardPreviewTask()
        cancelPostMoveLooseTask()
        cancelAITask()
        cancelAIMarkFadeTask()
        cancelFeedback(resetOnlyTask: false)
        feelAIMarkFadeCell = nil
        isAIThinking = false
    }

    private func logEndMatchIgnored(reason: String) {
        print("[XOArenaWatch] END_MATCH_IGNORED reason=\(reason)")
    }

    init() {
        syncFromEngine(reason: "init")
    }

    deinit {
        /// **`deinit`** is **`nonisolated`** (Swift 6): cannot snapshot **`@MainActor`** state here — use **`dumpRuntimeState`** from **`shutdownForBackground`** (**`@StateObject`** coordinator often never **`deinit`** s).
        matchTimer?.invalidate()
        aiTask?.cancel()
        boardPreviewTask?.cancel()
        postMoveLooseTask?.cancel()
        feedbackReset?.cancel()
        aiFadeClearTask?.cancel()
        print("[XOArenaWatch] COORDINATOR_DEINIT_CLEANUP")
        print("[XOArenaWatch] RUNTIME_DUMP note=deinit_skipped_nonisolated_context_use_shutdown_logs")
    }

    /// Debug: verify no stray **`Timer`** / **`Task`** / transitions keep the device busy ( **`@StateObject`** coordinator often never **`deinit`** s).
    func dumpRuntimeState(reason: String) {
        Self.printRuntimeDump(
            reason: reason,
            route: routeDiagnosticLabel,
            sessionStateDescription: String(describing: session.sessionState),
            setupDurationSummary: Self.setupDumpLabel(setupDuration),
            matchSecondsRemaining: matchSecondsRemaining,
            matchTimerActive: matchTimer != nil,
            aiTaskActive: aiTask != nil,
            boardPreviewTaskActive: boardPreviewTask != nil,
            postMoveLooseTaskActive: postMoveLooseTask != nil,
            feedbackResetActive: feedbackReset != nil,
            aiFadeClearTaskActive: aiFadeClearTask != nil,
            allowsLiveBoardEffects: allowsLiveBoardEffects,
            suspendedForBackground: suspendedForBackground,
            transitionState: String(describing: boardTransitionPhase),
            inputEnabled: inputEnabled
        )
    }

    nonisolated private static func setupDumpLabel(_ duration: GameDuration) -> String {
        "\(duration.title) (raw \(duration.rawValue))"
    }

    nonisolated private static func printRuntimeDump(
        reason: String,
        route: String,
        sessionStateDescription: String,
        setupDurationSummary: String,
        matchSecondsRemaining: Int,
        matchTimerActive: Bool,
        aiTaskActive: Bool,
        boardPreviewTaskActive: Bool,
        postMoveLooseTaskActive: Bool,
        feedbackResetActive: Bool,
        aiFadeClearTaskActive: Bool,
        allowsLiveBoardEffects: Bool,
        suspendedForBackground: Bool,
        transitionState: String,
        inputEnabled: Bool
    ) {
        print("[XOArenaWatch] RUNTIME_DUMP reason=\(reason)")
        print("  route=\(route) sessionState=\(sessionStateDescription)")
        print("  selectedSetupDuration=\(setupDurationSummary)")
        print("  matchSecondsRemaining=\(matchSecondsRemaining) matchTickerTimer=\(matchTimerActive ? "active" : "nil")")
        print(
            "  aiTask=\(aiTaskActive ? "active" : "nil") boardPreviewTask=\(boardPreviewTaskActive ? "active" : "nil") postMoveLooseTask=\(postMoveLooseTaskActive ? "active" : "nil")"
        )
        print("  feedbackResetTask=\(feedbackResetActive ? "active" : "nil") aiFadeClearTask=\(aiFadeClearTaskActive ? "active" : "nil")")
        print("  allowsLiveBoardEffects=\(allowsLiveBoardEffects) suspendedForBackground=\(suspendedForBackground) inputEnabled=\(inputEnabled)")
        print("  boardTransitionPhase=\(transitionState) introPulseTask=delegated_WatchIntroView")
    }

    /// Hard quiesce: cancel coordinator **`Task`** / **`Timer`** when the Watch scene loses **`active`** (draw-board **`Timer`** is owned by **`WatchBoardView`**, invalidated via **`allowsLiveBoardEffects`** + **`scenePhase`**; intro **`Task`** in **`WatchIntroView`** observes **`scenePhase`** + **`suspendedForBackground`**).
    func shutdownForBackground() {
        print("[XOArenaWatch] HARD_BACKGROUND_SHUTDOWN")

        if suspendedForBackground {
            printHardShutdownStateAudit()
            dumpRuntimeState(reason: "shutdownForBackground_duplicate")
            return
        }

        suspendedForBackground = true
        allowsLiveBoardEffects = false
        inputEnabled = false

        if matchTimer != nil {
            print("[XOArenaWatch] TASK_CANCEL ticker")
        }
        stopMatchTicker()

        cancelAITask()
        cancelBoardPreviewTask()
        cancelPostMoveLooseTask()
        cancelFeedback(resetOnlyTask: false)
        cancelAIMarkFadeTask()
        isAIThinking = false
        feelAIMarkFadeCell = nil
        resetBoardTransitionUI()

        printHardShutdownStateAudit()
        dumpRuntimeState(reason: "shutdownForBackground")
    }

    private func printHardShutdownStateAudit() {
        func refNil(_ alive: Bool) -> String { alive ? "LEAK" : "nil" }
        let tick = refNil(matchTimer != nil)
        let ai = refNil(aiTask != nil)
        let prv = refNil(boardPreviewTask != nil)
        let pm = refNil(postMoveLooseTask != nil)
        let timersInvalidated = matchTimer == nil
        let trans = String(describing: boardTransitionPhase)
        let fx = allowsLiveBoardEffects ? "true" : "false"
        print(
            "[XOArenaWatch] HARD_SHUTDOWN_STATE ticker=\(tick) ai=\(ai) preview=\(prv) postMove=\(pm) intro=nil timersInvalidated=\(timersInvalidated) transition=\(trans) effects=\(fx)"
        )
    }

    /// Restore timed ticker / AI scheduling after returning **`active`**.
    func resumeFromForegroundIfNeeded() {
        guard suspendedForBackground else { return }
        suspendedForBackground = false
        allowsLiveBoardEffects = true
        inputEnabled = true
        print("[XOArenaWatch] APP_FOREGROUND_RESUME")

        syncFromEngine(reason: "resumeForeground")

        guard case .game = route else { return }
        guard session.sessionState == .playing else { return }

        if matchClockRuns, matchSecondsRemaining > 0 {
            startMatchTickerIfNeeded()
        }
        /// Only reschedule when slab transition pipeline is idle (cancel during pause resets phase).
        if boardTransitionPhase == .idle {
            scheduleAIMoveIfNeeded(context: "resumeForeground", feelAfterHumanMove: false)
        }
    }

    func tapIntroAdvance() {
        suspendedForBackground = false
        allowsLiveBoardEffects = true
        inputEnabled = true
        navigateRoute(to: .setup)
    }

    func beginMatchFromSetup() {
        lastLoggedHeroBoardLabel = nil
        cancelFeedback()
        cancelBoardPreviewTask()
        cancelPostMoveLooseTask()
        cancelAITask()
        cancelAIMarkFadeTask()
        stopMatchTicker()
        feedbackReset?.cancel()

        session = GameEngine.makeInitialSession(
            mode: .vsAI,
            humanControlledMark: humanMark,
            firstMover: setupFirst
        )
        session.aiDifficulty = .medium
        navigateRoute(to: .game)
        if setupDuration == .noTime {
            print("[XOArenaWatch] MATCH_DURATION selected=noTime")
            matchSecondsRemaining = 0
            matchStartDate = Date()
        } else {
            matchSecondsRemaining = setupDuration.seconds
            matchStartDate = nil
        }
        showLowTimeHint = false
        suspendedForBackground = false
        allowsLiveBoardEffects = true
        inputEnabled = true
        if boardTransitionPhase != .idle {
            print("[XOArenaWatch] FORCE_IDLE_AT_START context=beginMatchFromSetup")
        }
        resetBoardTransitionUI()

        syncFromEngine(reason: "beginMatch")
        scheduleAIMoveIfNeeded(context: "beginMatchFromSetup", feelAfterHumanMove: false)
    }

    func onGameAppear() {
        guard case .game = route else { return }
        guard session.sessionState == .playing else { return }
        guard !suspendedForBackground else { return }

        syncFromEngine(reason: "onGameAppear")

        if boardTransitionPhase != .idle {
            print("[XOArenaWatch] FORCE_IDLE_AT_START context=onGameAppear")
            resetBoardTransitionUI()
        }

        inputEnabled = true
        print("[XOArenaWatch] INPUT_ENABLED_INITIAL context=onGameAppear")

        if matchClockRuns {
            guard matchSecondsRemaining > 0 else { return }
            startMatchTickerIfNeeded()
        }
        scheduleAIMoveIfNeeded(context: "onGameAppear", feelAfterHumanMove: false)
    }

    func onGameDisappear() {
        stopMatchTicker()
        cancelBoardPreviewTask()
        cancelPostMoveLooseTask()
        cancelAITask()
        cancelAIMarkFadeTask()
        cancelFeedback(resetOnlyTask: false)
        feelAIMarkFadeCell = nil
        dumpRuntimeState(reason: "onGameDisappear")
    }

    private func startMatchTickerIfNeeded() {
        guard !suspendedForBackground else { return }
        guard matchTimer == nil else { return }
        guard matchClockRuns else {
            print("[XOArenaWatch] TIMER_SKIP reason=noTime")
            return
        }
        print("[XOArenaWatch] TIMER_START")
        matchTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !Task.isCancelled else { return }
                self.tickMatch()
            }
        }
        RunLoop.main.add(matchTimer!, forMode: .common)
    }

    private func stopMatchTicker() {
        guard matchTimer != nil else { return }
        print("[XOArenaWatch] TIMER_STOP")
        matchTimer?.invalidate()
        matchTimer = nil
    }

    private func tickMatch() {
        guard !suspendedForBackground else { return }
        guard case .game = route else { return }
        guard session.sessionState == .playing else { return }
        guard matchClockRuns else { return }
        matchSecondsRemaining = max(matchSecondsRemaining - 1, 0)
        if matchSecondsRemaining <= 15 && matchSecondsRemaining > 0 {
            showLowTimeHint = true
        }
        if matchSecondsRemaining == 0 {
            finishMatchTimeUp()
        }
    }

    private func finishMatchTimeUp() {
        guard matchClockRuns else {
            logEndMatchIgnored(reason: "clockNotRunning")
            return
        }
        guard case .game = route else {
            logEndMatchIgnored(reason: "routeNotGame")
            return
        }
        guard session.sessionState == .playing else {
            logEndMatchIgnored(reason: "alreadyEnded")
            return
        }
        prepareMatchEndNavigation()
        print("[XOArenaWatch] FEEL_GAME_END")
        matchStartDate = nil
        var s = session
        s.sessionState = .completed
        session = s
        syncFromEngine(reason: "finishMatchTimeUp")
        dumpRuntimeState(reason: "finishMatchTimeUp")
        navigateRoute(to: .end(buildSummary(endedByTime: true)))
    }

    /// Player ends an endless **No Time** match → End screen with **Played …** subtitle.
    func endNoTimeMatch() {
        guard setupDuration == .noTime else {
            logEndMatchIgnored(reason: "notNoTimeMode")
            return
        }
        guard case .game = route else {
            logEndMatchIgnored(reason: "routeNotGame")
            return
        }
        guard session.sessionState == .playing else {
            logEndMatchIgnored(reason: "alreadyEnded")
            return
        }
        guard inputEnabled else {
            logEndMatchIgnored(reason: "inputDisabled")
            return
        }

        let start = matchStartDate ?? Date()
        let elapsedSec = max(0, Int(Date().timeIntervalSince(start).rounded(.down)))
        let h = playerScore
        let a = aiScore
        print("[XOArenaWatch] NO_TIME_END elapsed=\(elapsedSec)s score=\(h):\(a)")

        prepareMatchEndNavigation()

        matchStartDate = nil
        var s = session
        s.sessionState = .completed
        session = s
        syncFromEngine(reason: "endNoTimeMatch")

        let subtitle = Self.formatPlayedSubtitle(seconds: elapsedSec)
        dumpRuntimeState(reason: "endNoTimeMatch")
        navigateRoute(to: .end(buildSummary(endedByTime: false, endDurationRowSubtitle: subtitle)))
    }

    func playAgain() {
        lastLoggedHeroBoardLabel = nil
        cancelFeedback()
        cancelBoardPreviewTask()
        cancelPostMoveLooseTask()
        cancelAITask()
        cancelAIMarkFadeTask()
        stopMatchTicker()
        suspendedForBackground = false
        allowsLiveBoardEffects = true
        inputEnabled = true
        navigateRoute(to: .setup)
        session = GameEngine.makeIdleSession()
        feelAIMarkFadeCell = nil
        syncFromEngine(reason: "playAgain")
        isAIThinking = false
        matchSecondsRemaining = 0
        showLowTimeHint = false
        matchStartDate = nil
        dumpRuntimeState(reason: "playAgain")
    }

    func handleCellTap(_ cellIndex: Int) {
        let boardIdx = activeBoardIndex
        let transitionLabel = String(describing: boardTransitionPhase)
        print(
            "[XOArenaWatch] TAP_RECEIVED cell=\(cellIndex) inputEnabled=\(inputEnabled) suspended=\(suspendedForBackground) transition=\(transitionLabel) isAIThinking=\(isAIThinking)"
        )

        guard inputEnabled else {
            print("[XOArenaWatch] TAP_BLOCKED reason=inputDisabled transition=\(transitionLabel)")
            WatchHaptics.invalid()
            return
        }
        guard !suspendedForBackground else {
            print("[XOArenaWatch] TAP_BLOCKED reason=suspendedForBackground transition=\(transitionLabel)")
            WatchHaptics.invalid()
            return
        }
        guard boards.indices.contains(boardIdx) else {
            print("[XOArenaWatch] TAP_BLOCKED reason=noActiveBoard transition=\(transitionLabel)")
            WatchHaptics.invalid()
            return
        }
        if session.sessionState != .playing {
            print("[XOArenaWatch] TAP_BLOCKED reason=sessionNotPlaying(\(session.sessionState)) transition=\(transitionLabel)")
            WatchHaptics.invalid()
            return
        }
        if boardTransitionPhase != .idle {
            print("[XOArenaWatch] TAP_BLOCKED reason=transitionNotIdle(\(transitionLabel))")
            WatchHaptics.invalid()
            return
        }
        if isAIThinking {
            print("[XOArenaWatch] TAP_BLOCKED reason=aiApplyingMove transition=\(transitionLabel)")
            WatchHaptics.invalid()
            return
        }
        let gateThinking = false
        guard HumanInputGate.permitsCellPlacement(
            gameMode: session.gameMode,
            sessionState: session.sessionState,
            isAIThinking: gateThinking,
            currentMark: currentMark,
            boardPlayState: boards[boardIdx].playState,
            cellMark: boards[boardIdx].cells[cellIndex].mark,
            isFocusedBoard: true,
            humanControlledMark: session.humanControlledMark
        ) else {
            let slab = boards[boardIdx]
            guard slab.cells.indices.contains(cellIndex) else {
                print("[XOArenaWatch] TAP_BLOCKED reason=cellIndexOutOfRange transition=\(transitionLabel)")
                WatchHaptics.invalid()
                return
            }
            let reason: String
            switch session.gameMode {
            case .vsAI, .learning:
                let human = session.humanControlledMark ?? humanMark
                if slab.cells[cellIndex].mark != .empty {
                    reason = "cellOccupied"
                } else if slab.playState != .inProgress {
                    reason = "boardSlabNotInProgress(\(String(describing: slab.playState)))"
                } else if currentMark != human {
                    reason = "notHumanTurn(currentMark=\(currentMark.rawValue))"
                } else {
                    reason = "humanGateOther"
                }
            case .aiVsAI:
                reason = "aiVsAiNoHumanInput"
            case .soloFocus, .localDuel:
                if slab.cells[cellIndex].mark != .empty {
                    reason = "cellOccupied"
                } else {
                    reason = "gateDenied"
                }
            }
            print("[XOArenaWatch] TAP_BLOCKED reason=\(reason) transition=\(transitionLabel)")
            WatchHaptics.invalid()
            return
        }

        let before = session.stats
        do {
            let movedBoardIndex = session.activeBoardIndex
            let slabBeforeMove = session.boards[boardIdx]
            print("[XOArenaWatch] BEFORE_HUMAN_MOVE engineBoard=\(movedBoardIndex + 1)")
            session = try GameEngine.applyMove(session, boardIndex: boardIdx, cellIndex: cellIndex)
            let newBoardIndex = session.activeBoardIndex
            let didAdvanceBoard = newBoardIndex != movedBoardIndex
            print("[XOArenaWatch] AFTER_HUMAN_MOVE engineBoard=\(newBoardIndex + 1)")

            let slabFeelTriggered = maybePresentBoardFeedback(
                before: before,
                after: session.stats,
                suppressSlabHaptic: didAdvanceBoard
            )
            if !slabFeelTriggered {
                WatchHaptics.tapLight()
            }
            print("[XOArenaWatch] FEEL_PLAYER_TAP")

            #if DEBUG
            debugLog(
                "[XOArenaWatch] PLAYER_MOVE \(WatchDebugLogFormatting.boardCellLine(boardIndex: boardIdx, cellIndex: cellIndex))"
            )
            #endif

            let previewCells = didAdvanceBoard
                ? cellStringsAfterPlacing(slab: slabBeforeMove, cellIndex: cellIndex)
                : nil
            postMoveLooseTask?.cancel()
            postMoveLooseTask = nil
            boardPreviewTask?.cancel()
            if didAdvanceBoard {
                boardPreviewTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard !Task.isCancelled, !self.suspendedForBackground else { return }
                    await self.handlePostMoveVisualSync(
                        movedBoardIndex: movedBoardIndex,
                        newBoardIndex: newBoardIndex,
                        didAdvanceBoard: true,
                        previewCells: previewCells,
                        reason: "humanApplyMove",
                        feelAfterHumanMove: true,
                        actor: .human
                    )
                }
            } else {
                boardPreviewTask = nil
                postMoveLooseTask?.cancel()
                postMoveLooseTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    defer { self.postMoveLooseTask = nil }
                    guard !Task.isCancelled, !self.suspendedForBackground else { return }
                    await self.handlePostMoveVisualSync(
                        movedBoardIndex: movedBoardIndex,
                        newBoardIndex: newBoardIndex,
                        didAdvanceBoard: false,
                        previewCells: nil,
                        reason: "humanApplyMove",
                        feelAfterHumanMove: true,
                        actor: .human
                    )
                }
            }
        } catch {
            WatchHaptics.invalid()
        }
    }

    /// Canonical copy from **`session.activeBoardIndex`** → published grid (**watch-only diagnostic path**).
    private func syncFromEngine(reason: String) {
        let engineBoardIndex = session.activeBoardIndex

        let nextStrings: [String]
        let allows: Bool

        if session.boards.indices.contains(engineBoardIndex) {
            let board = session.boards[engineBoardIndex]
            visibleBoardIndex = engineBoardIndex
            allows = board.playState == .inProgress
            var row = board.cells.prefix(GameConstants.cellCount).map { cell -> String in
                switch cell.mark {
                case .x: return "X"
                case .o: return "O"
                case .empty: return ""
                }
            }
            while row.count < GameConstants.cellCount { row.append("") }
            nextStrings = Array(row.prefix(GameConstants.cellCount))
        } else {
            visibleBoardIndex = engineBoardIndex
            nextStrings = Array(repeating: "", count: GameConstants.cellCount)
            allows = false
        }

        visibleBoardAllowsMoves = allows
        visibleBoardCells = nextStrings
        visibleBoardID = UUID()

        let eng = engineBoardIndex + 1
        let vis = visibleBoardIndex + 1
        print("[XOArenaWatch] SYNC reason=\(reason) engineBoard=\(eng) visibleBoard=\(vis) cells=\(visibleBoardCells)")
        logHeroBoardLabelIfNeeded()
    }

    private func logHeroBoardLabelIfNeeded() {
        guard case .game = route else {
            lastLoggedHeroBoardLabel = nil
            return
        }
        let label = heroBoardLabelCompact
        guard lastLoggedHeroBoardLabel != label else { return }
        lastLoggedHeroBoardLabel = label
        print("[XOArenaWatch] HERO_BOARD_LABEL value=\(label)")
    }

    @discardableResult
    private func maybePresentBoardFeedback(
        before: GameStats,
        after: GameStats,
        suppressSlabHaptic: Bool = false
    ) -> Bool {
        let human = humanMark
        let ai = aiMark

        let humanUp =
            (human == .x && after.xBoardWins > before.xBoardWins)
                || (human == .o && after.oBoardWins > before.oBoardWins)
        let aiUp =
            (ai == .x && after.xBoardWins > before.xBoardWins)
                || (ai == .o && after.oBoardWins > before.oBoardWins)
        let drew = after.boardDraws > before.boardDraws

        cancelFeedback(resetOnlyTask: false)
        if humanUp {
            boardFeedback = .playerPlusOne
            if !suppressSlabHaptic { WatchHaptics.slabOutcomeTick() }
        } else if aiUp {
            boardFeedback = .aiPlusOne
            if !suppressSlabHaptic { WatchHaptics.slabOutcomeTick() }
        } else if drew {
            boardFeedback = .draw
            if !suppressSlabHaptic { WatchHaptics.slabOutcomeTick() }
        } else {
            return false
        }

        feedbackReset = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 580_000_000)
            guard let self, !Task.isCancelled else { return }
            guard !self.suspendedForBackground else { return }
            self.boardFeedback = nil
        }
        return true
    }

    private func cancelFeedback(resetOnlyTask: Bool = true) {
        feedbackReset?.cancel()
        feedbackReset = nil
        if !resetOnlyTask {
            boardFeedback = nil
        }
    }

    private func cancelAITask() {
        if aiTask != nil {
            print("[XOArenaWatch] TASK_CANCEL ai")
        }
        aiRunEpoch &+= 1
        aiSequence &+= 1
        aiTask?.cancel()
        aiTask = nil
        isAIThinking = false
    }

    private func cancelAIMarkFadeTask() {
        aiFadeClearTask?.cancel()
        aiFadeClearTask = nil
    }

    private func cancelBoardPreviewTask() {
        if boardPreviewTask != nil {
            print("[XOArenaWatch] TASK_CANCEL preview")
            print("[XOArenaWatch] TASK_CANCEL scroll")
        }
        boardPreviewTask?.cancel()
        boardPreviewTask = nil
        resetBoardTransitionUI()
    }

    private func cancelPostMoveLooseTask() {
        guard postMoveLooseTask != nil else { return }
        print("[XOArenaWatch] TASK_CANCEL scroll")
        postMoveLooseTask?.cancel()
        postMoveLooseTask = nil
    }

    private func resetBoardTransitionUI() {
        boardTransitionPhase = .idle
        verticalBoardScrollFraction = 0
        incomingBoardCells = Array(repeating: "", count: GameConstants.cellCount)
        incomingBoardID = UUID()
    }

    /// Watch-only: show the just-played slab (terminal grid snapshot; engine clears completed boards in-session).
    private func applyCompletedBoardPreview(boardIndex: Int, cellStrings: [String]) {
        guard session.boards.indices.contains(boardIndex) else { return }
        visibleBoardIndex = boardIndex
        var row = Array(cellStrings.prefix(GameConstants.cellCount))
        while row.count < GameConstants.cellCount { row.append("") }
        visibleBoardCells = row
        visibleBoardAllowsMoves = false
        visibleBoardID = UUID()
        print("[XOArenaWatch] BOARD_PREVIEW boardDisplay=\(boardIndex + 1) cells=\(visibleBoardCells)")
    }

    /// Grid as shown immediately after a legal placement on **`slab`** (matches engine placement; works when engine later resets the slab).
    private func cellStringsAfterPlacing(slab: XOBoard, cellIndex: Int) -> [String] {
        var cells = slab.cells
        guard cells.indices.contains(cellIndex) else {
            return paddedCellStrings(from: slab.cells)
        }
        let mark = slab.currentMark
        cells[cellIndex] = BoardCell(index: cellIndex, mark: mark)
        return paddedCellStrings(from: cells)
    }

    private func paddedCellStrings(from cells: [BoardCell]) -> [String] {
        var row = cells.prefix(GameConstants.cellCount).map { c -> String in
            switch c.mark {
            case .x: return "X"
            case .o: return "O"
            case .empty: return ""
            }
        }
        while row.count < GameConstants.cellCount { row.append("") }
        return row
    }

    private func paddedCellStringsFromSessionBoard(at index: Int) -> [String] {
        guard session.boards.indices.contains(index) else {
            return Array(repeating: "", count: GameConstants.cellCount)
        }
        return paddedCellStrings(from: session.boards[index].cells)
    }

    @MainActor
    private func handlePostMoveVisualSync(
        movedBoardIndex: Int,
        newBoardIndex: Int,
        didAdvanceBoard: Bool,
        previewCells: [String]?,
        reason: String,
        feelAfterHumanMove: Bool,
        actor: PostMoveActor
    ) async {
        let movedDisplay = movedBoardIndex + 1
        let newDisplay = newBoardIndex + 1
        print(
            "[XOArenaWatch] POST_MOVE_SYNC reason=\(reason) movedBoard=\(movedDisplay) newBoard=\(newDisplay) didAdvance=\(didAdvanceBoard)"
        )

        if didAdvanceBoard {
            guard let cells = previewCells,
                  cells.count == GameConstants.cellCount
            else {
                resetBoardTransitionUI()
                syncFromEngine(reason: "afterMoveNoBoardAdvance")
                print("[XOArenaWatch] TRANSITION_STATE value=idle reason=afterMoveNoBoardAdvance")
                switch actor {
                case .human:
                    scheduleAIMoveIfNeeded(context: "afterMoveNoBoardAdvance", feelAfterHumanMove: feelAfterHumanMove)
                case .ai(let cell):
                    scheduleAIMarkFade(cell: cell)
                }
                boardPreviewTask = nil
                return
            }

            print("[XOArenaWatch] BOARD_PREVIEW_START movedBoard=\(movedDisplay)")
            boardTransitionPhase = .previewing
            applyCompletedBoardPreview(boardIndex: movedBoardIndex, cellStrings: cells)
            logHeroBoardLabelIfNeeded()

            try? await Task.sleep(nanoseconds: WatchFeelTiming.boardPreviewHoldNanoseconds)
            guard !Task.isCancelled else {
                resetBoardTransitionUI()
                syncFromEngine(reason: "boardPreviewCancelled")
                boardPreviewTask = nil
                return
            }
            guard !suspendedForBackground else {
                resetBoardTransitionUI()
                syncFromEngine(reason: "boardPreviewSuspended")
                boardPreviewTask = nil
                return
            }

            print(
                "[XOArenaWatch] BOARD_SCROLL_PREPARE fromBoard=\(movedDisplay) toBoard=\(newDisplay)"
            )
            incomingBoardCells = paddedCellStringsFromSessionBoard(at: newBoardIndex)
            incomingBoardID = UUID()
            verticalBoardScrollFraction = 0
            boardTransitionPhase = .scrolling
            print("[XOArenaWatch] BOARD_SCROLL_START from=\(movedDisplay) to=\(newDisplay)")
            logHeroBoardLabelIfNeeded()
            await Task.yield()
            guard !Task.isCancelled else {
                resetBoardTransitionUI()
                syncFromEngine(reason: "boardScrollCancelled")
                boardPreviewTask = nil
                return
            }
            guard !suspendedForBackground else {
                resetBoardTransitionUI()
                syncFromEngine(reason: "boardScrollSuspended")
                boardPreviewTask = nil
                return
            }

            withAnimation(WatchFeelTiming.boardScrollAnimation) {
                verticalBoardScrollFraction = 1
            }
            try? await Task.sleep(nanoseconds: WatchFeelTiming.boardScrollNanoseconds)
            guard !Task.isCancelled else {
                resetBoardTransitionUI()
                syncFromEngine(reason: "boardScrollCancelled")
                boardPreviewTask = nil
                return
            }
            guard !suspendedForBackground else {
                resetBoardTransitionUI()
                syncFromEngine(reason: "boardScrollSuspended")
                boardPreviewTask = nil
                return
            }

            let currentDisplay = session.activeBoardIndex + 1
            print("[XOArenaWatch] BOARD_SCROLL_END current=\(currentDisplay)")
            syncFromEngine(reason: "afterScrollTransition")
            resetBoardTransitionUI()

            guard session.sessionState == .playing else {
                boardPreviewTask = nil
                return
            }
            /// Nil tracked task before chaining AI (**scroll path** only stores **`boardPreviewTask`** during advance transitions).
            boardPreviewTask = nil
            scheduleAIMoveIfNeeded(context: "afterScrollTransition", feelAfterHumanMove: feelAfterHumanMove)
        } else {
            if boardTransitionPhase != .idle {
                resetBoardTransitionUI()
            }
            switch actor {
            case .human:
                break
            case .ai(let cell):
                scheduleAIMarkFade(cell: cell)
            }
            syncFromEngine(reason: "afterMoveNoBoardAdvance")
            print("[XOArenaWatch] TRANSITION_STATE value=idle reason=afterMoveNoBoardAdvance")

            guard session.sessionState == .playing else {
                boardPreviewTask = nil
                return
            }
            if case .human = actor {
                scheduleAIMoveIfNeeded(context: "afterMoveNoBoardAdvance", feelAfterHumanMove: feelAfterHumanMove)
            }
            boardPreviewTask = nil
        }
    }

    private func scheduleAIMoveIfNeeded(context: String, feelAfterHumanMove: Bool = false) {
        guard !suspendedForBackground else {
            #if DEBUG
            debugLogSkip("app_suspended_background")
            #endif
            return
        }
        let board = activeBoardIndex
        let mark = currentMark
        let aiSymbol = aiMarkViaSession()

        func transitionAllowsAIReservation() -> Bool {
            if boardTransitionPhase == .previewing {
                print("[XOArenaWatch] AI_AUTO_SKIP reason=board_previewing")
                return false
            }
            if boardTransitionPhase == .scrolling {
                print("[XOArenaWatch] AI_AUTO_SKIP reason=board_scrolling")
                return false
            }
            return true
        }

        let willSchedule =
            session.gameMode == .vsAI
                && mark == aiSymbol
                && session.sessionState == .playing
                && (!matchClockRuns || matchSecondsRemaining > 0)
                && boardTransitionPhase == .idle
                && !isAIThinking
                && aiTask == nil
                && boards.indices.contains(board)
                && boards[board].playState == .inProgress

        #if DEBUG
        let slabDescribe: String
        if boards.indices.contains(board) {
            slabDescribe = String(describing: boards[board].playState)
        } else {
            slabDescribe = "n/a"
        }
        debugLog(
            "[XOArenaWatch] AI_AUTO_CHECK currentMark=\(mark.rawValue) aiSymbol=\(aiSymbol.rawValue) shouldMove=\(willSchedule)",
            extras: "(ctx=\(context) \(WatchDebugLogFormatting.boardTag(boardIndex: board)) slab=\(slabDescribe) session=\(session.sessionState.rawValue) transition=\(boardTransitionPhase) advancePreviewHeld=\(boardPreviewTask != nil ? "yes" : "no")))"
        )
        #endif

        guard session.gameMode == .vsAI else { return }
        guard mark == aiSymbol else { return }
        guard session.sessionState == .playing else {
            debugLogSkip("session_not_playing")
            return
        }
        guard !matchClockRuns || matchSecondsRemaining > 0 else {
            debugLogSkip("match_clock_exhausted")
            return
        }
        guard transitionAllowsAIReservation() else { return }
        guard !isAIThinking else {
            debugLogSkip("already_thinking")
            return
        }
        guard aiTask == nil else {
            debugLogSkip("ai_task_pending")
            return
        }
        guard boards.indices.contains(board) else {
            debugLogSkip("invalid_board_index")
            return
        }
        let slab = boards[board]
        guard slab.playState == .inProgress else {
            debugLogSkip("board_not_in_progress(playState)")
            return
        }

        if context == "afterMoveNoBoardAdvance" {
            print("[XOArenaWatch] AI_AUTO_ALLOW reason=idle_after_non_advancing_move")
        }

        aiSequence &+= 1
        let token = aiSequence
        let scheduledBoard = board
        let scheduledMark = mark
        let epochWhenScheduled = aiRunEpoch

        aiTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard !self.suspendedForBackground else { return }
            defer {
                self.isAIThinking = false
                if self.aiRunEpoch == epochWhenScheduled {
                    self.aiTask = nil
                }
                /// While **advance** preview/scroll is tracked in **`boardPreviewTask`**, phase may still be **idle** briefly — defer must not chain AI until task is queued for advance or phase is purely idle with no pending advance task.
                let mayDeferSyncAndSchedule =
                    self.boardPreviewTask == nil
                    && self.boardTransitionPhase == .idle
                    && !self.suspendedForBackground
                if mayDeferSyncAndSchedule {
                    self.syncFromEngine(reason: "aiTaskDeferMainActor")
                    self.scheduleAIMoveIfNeeded(context: "afterAIMoveDefer", feelAfterHumanMove: false)
                }
            }

            /// Delays (**`feelAfterHumanMove`**, **`AIThinkingDelay`**) MUST NOT flip **`isAIThinking`** early — **`HumanInputGate`** / hero UI treat it as blocking human (**first human move** felt ~3 s delayed on cold start races).
            self.syncFromEngine(reason: "aiBeforeDelay")

            if feelAfterHumanMove {
                let feelNs = UInt64.random(in: WatchFeelTiming.aiHumanResponseMinNanos...WatchFeelTiming.aiHumanResponseMaxNanos)
                try? await Task.sleep(nanoseconds: feelNs)
            }

            guard !Task.isCancelled, token == self.aiSequence, !self.suspendedForBackground else { return }

            let slabSnapshot = self.session.boards[scheduledBoard]
            let variationSeed = UInt64(self.aiSequence &* 1_049_867) ^ (UInt64(scheduledBoard) << 32)

            let computed = AIThinkingDelay.nanoseconds(
                difficulty: self.session.aiDifficulty,
                aiRemainingSeconds: self.aiThinkingDelayRemainingSecondsSynthetic,
                board: slabSnapshot,
                aiMark: scheduledMark,
                opponentMark: scheduledMark.nextInTurn,
                variationSeed: variationSeed
            )

            try? await Task.sleep(nanoseconds: computed.nanoseconds)
            self.syncFromEngine(reason: "aiAfterSleepMainActor")

            guard !Task.isCancelled, token == self.aiSequence, !self.suspendedForBackground else {
                self.debugLog("[XOArenaWatch] AI_AUTO_SKIP reason=ai_task_cancelled_or_stale_token")
                return
            }
            guard self.session.sessionState == .playing else {
                self.debugLog("[XOArenaWatch] AI_AUTO_SKIP reason=post_sleep_not_playing")
                return
            }
            guard self.session.activeBoardIndex == scheduledBoard else {
                let a = self.session.activeBoardIndex
                self.debugLog(
                    "[XOArenaWatch] AI_AUTO_SKIP reason=post_sleep_board_mismatch expected=\(WatchDebugLogFormatting.boardTag(boardIndex: scheduledBoard)) actual=\(WatchDebugLogFormatting.boardTag(boardIndex: a))"
                )
                return
            }
            guard self.currentMark == scheduledMark else {
                self.debugLog("[XOArenaWatch] AI_AUTO_SKIP reason=post_sleep_turn_changed expectedMark=\(scheduledMark.rawValue) actual=\(self.currentMark.rawValue)")
                return
            }
            if self.matchClockRuns, self.matchSecondsRemaining <= 0 {
                self.finishMatchTimeUp()
                return
            }

            self.syncFromEngine(reason: "aiBeforeChooseMove")

            let activeSlab = self.session.boards[self.session.activeBoardIndex]
            guard activeSlab.playState == .inProgress else {
                self.debugLog("[XOArenaWatch] AI_AUTO_SKIP reason=post_sleep_slab_not_active state=\(String(describing: activeSlab.playState))")
                return
            }

            let humanM = self.session.humanControlledMark ?? .x
            let aiM = humanM.nextInTurn
            let ctx = AIMoveTimerContext(
                remainingSeconds: self.matchClockRuns ? self.matchSecondsRemaining : 0,
                totalSeconds: self.matchClockRuns ? self.setupDuration.seconds : 0
            )
            let difficultySnapshot = self.session.aiDifficulty

            let cellOpt = TicTacToeAI.chooseMove(
                on: activeSlab,
                aiMark: aiM,
                humanMark: humanM,
                difficulty: difficultySnapshot,
                timerContext: ctx
            )

            guard let cell = cellOpt else {
                self.debugLog(
                    "[XOArenaWatch] AI_AUTO_SKIP reason=chooseMove_nil \(WatchDebugLogFormatting.boardTag(boardIndex: scheduledBoard))"
                )
                return
            }
            guard token == self.aiSequence else {
                self.debugLog("[XOArenaWatch] AI_AUTO_SKIP reason=pre_apply_stale_token")
                return
            }
            guard self.session.sessionState == .playing else {
                self.debugLog("[XOArenaWatch] AI_AUTO_SKIP reason=pre_apply_session_not_playing")
                return
            }
            guard self.session.activeBoardIndex == scheduledBoard else {
                let a = self.session.activeBoardIndex
                self.debugLog(
                    "[XOArenaWatch] AI_AUTO_SKIP reason=pre_apply_board_mismatch expected=\(WatchDebugLogFormatting.boardTag(boardIndex: scheduledBoard)) actual=\(WatchDebugLogFormatting.boardTag(boardIndex: a)) \(WatchDebugLogFormatting.cellTag(cellIndex: cell))"
                )
                return
            }

            /// Input / gate **only** clamps **exactly before** **`GameEngine.applyMove`** for AI (delays ran with **`isAIThinking == false`** so human can tap whenever **`currentMark`** is theirs).
            self.isAIThinking = true
            print("[XOArenaWatch] AI_INPUT_LOCK_BEFORE_AI_MOVE engineBoard=\(scheduledBoard + 1)")

            let beforeAI = self.session.stats
            do {
                self.debugLog(
                    "[XOArenaWatch] AI_AUTO_MOVE \(WatchDebugLogFormatting.boardCellLine(boardIndex: scheduledBoard, cellIndex: cell))"
                )
                let movedBoardIndex = self.session.activeBoardIndex
                let slabBeforeAIMove = self.session.boards[scheduledBoard]
                print("[XOArenaWatch] BEFORE_AI_MOVE engineBoard=\(movedBoardIndex + 1)")
                let next = try GameEngine.applyMove(self.session, boardIndex: scheduledBoard, cellIndex: cell)
                self.session = next
                let newBoardIndex = self.session.activeBoardIndex
                let didAdvanceBoard = newBoardIndex != movedBoardIndex
                print("[XOArenaWatch] AFTER_AI_MOVE engineBoard=\(newBoardIndex + 1)")

                let slabFeelTriggered = self.maybePresentBoardFeedback(
                    before: beforeAI,
                    after: next.stats,
                    suppressSlabHaptic: didAdvanceBoard
                )
                if !slabFeelTriggered {
                    WatchHaptics.aiMoveLightDelayed()
                }
                print("[XOArenaWatch] FEEL_AI_MOVE")

                let previewCells = didAdvanceBoard
                    ? self.cellStringsAfterPlacing(slab: slabBeforeAIMove, cellIndex: cell)
                    : nil
                if didAdvanceBoard {
                    self.cancelAIMarkFadeTask()
                    self.feelAIMarkFadeCell = nil
                    self.boardPreviewTask?.cancel()
                    self.boardPreviewTask = Task { @MainActor [weak self] in
                        guard let self else { return }
                        guard !Task.isCancelled, !self.suspendedForBackground else { return }
                        await self.handlePostMoveVisualSync(
                            movedBoardIndex: movedBoardIndex,
                            newBoardIndex: newBoardIndex,
                            didAdvanceBoard: true,
                            previewCells: previewCells,
                            reason: "aiApplyMove",
                            feelAfterHumanMove: false,
                            actor: .ai(cell: cell)
                        )
                    }
                } else {
                    await self.handlePostMoveVisualSync(
                        movedBoardIndex: movedBoardIndex,
                        newBoardIndex: newBoardIndex,
                        didAdvanceBoard: false,
                        previewCells: nil,
                        reason: "aiApplyMove",
                        feelAfterHumanMove: false,
                        actor: .ai(cell: cell)
                    )
                }
            } catch {
                WatchHaptics.invalid()
                self.debugLog(
                    "[XOArenaWatch] AI_AUTO_SKIP reason=apply_move_failed \(WatchDebugLogFormatting.boardCellLine(boardIndex: scheduledBoard, cellIndex: cell))"
                )
            }
        }
    }

    private func scheduleAIMarkFade(cell: Int) {
        cancelAIMarkFadeTask()
        feelAIMarkFadeCell = cell
        let ns = UInt64(WatchFeelTiming.aiMarkFadeSeconds * 1_000_000_000) + 30_000_000
        aiFadeClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: ns)
            guard let self, !Task.isCancelled else { return }
            guard !self.suspendedForBackground else { return }
            if self.feelAIMarkFadeCell == cell {
                self.feelAIMarkFadeCell = nil
            }
            self.aiFadeClearTask = nil
        }
    }

    private func aiMarkViaSession() -> Mark {
        (session.humanControlledMark ?? .x).nextInTurn
    }

    private enum WatchDebugLogFormatting {
        static func boardTag(boardIndex: Int) -> String {
            "boardIndex=\(boardIndex) boardDisplay=\(boardIndex + 1)"
        }

        static func cellTag(cellIndex: Int) -> String {
            "cellIndex=\(cellIndex) cellDisplay=\(cellIndex + 1)"
        }

        static func boardCellLine(boardIndex: Int, cellIndex: Int) -> String {
            "\(boardTag(boardIndex: boardIndex)) \(cellTag(cellIndex: cellIndex))"
        }
    }

    #if DEBUG
    private func debugLog(_ message: String, extras: String = "") {
        if extras.isEmpty {
            print(message)
        } else {
            print("\(message) \(extras)")
        }
    }

    private func debugLogSkip(_ reason: String) {
        print("[XOArenaWatch] AI_AUTO_SKIP reason=\(reason)")
    }
    #else
    private func debugLog(_ message: String, extras: String = "") {}
    private func debugLogSkip(_ reason: String) {}
    #endif

    private func buildSummary(
        endedByTime: Bool = false,
        endDurationRowSubtitle: String? = nil
    ) -> WatchEndSummary {
        let hScore = humanMark == .x ? session.stats.xBoardWins : session.stats.oBoardWins
        let aScore = aiMark == .x ? session.stats.xBoardWins : session.stats.oBoardWins

        let headline: String = {
            if hScore > aScore { return "You win" }
            if aScore > hScore { return "AI wins" }
            return "Draw"
        }()

        return WatchEndSummary(
            headline: headline,
            humanScore: hScore,
            aiScore: aScore,
            duration: setupDuration,
            endedByTime: endedByTime,
            endDurationRowSubtitle: endDurationRowSubtitle
        )
    }

    private static func formatPlayedSubtitle(seconds: Int) -> String {
        let t = max(0, seconds)
        let m = t / 60
        let s = t % 60
        return String(format: "Played %02d:%02d", m, s)
    }
}
