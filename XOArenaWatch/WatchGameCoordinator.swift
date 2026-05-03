//
//  WatchGameCoordinator.swift
//  XOArenaWatch
//

import Combine
import Foundation

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
    }

    enum BoardFeedback: Equatable {
        case playerPlusOne
        case aiPlusOne
        case draw
    }

    @Published var route: Route = .intro

    @Published var setupSymbol: PlayerSymbolChoice = .x
    @Published var setupFirst: FirstMoverChoice = .player
    @Published var setupDuration: GameDuration = .oneMinute

    @Published private(set) var session: GameSession = GameEngine.makeIdleSession()
    @Published private(set) var isAIThinking: Bool = false
    /// Watch-only: completed slab frozen ~0.35s before **`syncFromEngine`** catches **`activeBoardIndex`** advance.
    @Published private(set) var isBoardPreviewing: Bool = false

    /// Single match countdown (wall clock from first game screen).
    @Published private(set) var matchSecondsRemaining: Int = 0

    @Published private(set) var boardFeedback: BoardFeedback?
    @Published private(set) var showLowTimeHint: Bool = false

    /// Grid shown on Watch (**ONLY** **`""`** / **`"X"`** / **`"O"`**); paired with **`visibleBoardID`** for hard invalidation.
    @Published var visibleBoardCells: [String] = Array(repeating: "", count: 9)
    @Published var visibleBoardID = UUID()
    /// Must match **`session.activeBoardIndex`** after every **`syncFromEngine`** (diagnostic / hero alignment).
    @Published private(set) var visibleBoardIndex: Int = 0
    /// Slab **`playState == .inProgress`** (synced alongside strings).
    @Published private(set) var visibleBoardAllowsMoves: Bool = false

    private var matchTimer: Timer?
    private var feedbackReset: Task<Void, Never>?
    private var aiSequence: UInt64 = 0
    private var aiTask: Task<Void, Never>?
    private var boardPreviewTask: Task<Void, Never>?

    private var humanMark: Mark { setupSymbol.mark }
    private var aiMark: Mark { humanMark.nextInTurn }

    var boards: [XOBoard] { session.boards }
    var activeBoardIndex: Int { session.activeBoardIndex }
    var currentMark: Mark { session.currentMarkForActiveBoard }

    /// Match clock for compact hero bar (**`m:ss`**).
    var remainingTimeText: String {
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

    var scoreText: String {
        "You \(playerScore) · AI \(aiScore)"
    }

    init() {
        syncFromEngine(reason: "init")
    }

    func tapIntroAdvance() {
        route = .setup
    }

    func beginMatchFromSetup() {
        cancelFeedback()
        cancelBoardPreviewTask()
        cancelAITask()
        matchTimer?.invalidate()
        matchTimer = nil
        feedbackReset?.cancel()

        session = GameEngine.makeInitialSession(
            mode: .vsAI,
            humanControlledMark: humanMark,
            firstMover: setupFirst
        )
        session.aiDifficulty = .medium
        route = .game
        matchSecondsRemaining = setupDuration.seconds
        showLowTimeHint = false
        syncFromEngine(reason: "beginMatch")
        scheduleAIMoveIfNeeded(context: "beginMatchFromSetup")
    }

    func onGameAppear() {
        guard case .game = route else { return }
        guard matchSecondsRemaining > 0, session.sessionState == .playing else { return }
        syncFromEngine(reason: "onGameAppear")
        startMatchTickerIfNeeded()
        scheduleAIMoveIfNeeded(context: "onGameAppear")
    }

    func onGameDisappear() {
        stopMatchTicker()
        cancelBoardPreviewTask()
        cancelAITask()
    }

    private func startMatchTickerIfNeeded() {
        guard matchTimer == nil else { return }
        matchTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickMatch()
            }
        }
        RunLoop.main.add(matchTimer!, forMode: .common)
    }

    private func stopMatchTicker() {
        matchTimer?.invalidate()
        matchTimer = nil
    }

    private func tickMatch() {
        guard case .game = route else { return }
        guard session.sessionState == .playing else { return }
        matchSecondsRemaining = max(matchSecondsRemaining - 1, 0)
        if matchSecondsRemaining <= 15 && matchSecondsRemaining > 0 {
            showLowTimeHint = true
        }
        if matchSecondsRemaining == 0 {
            finishMatchTimeUp()
        }
    }

    private func finishMatchTimeUp() {
        stopMatchTicker()
        cancelBoardPreviewTask()
        cancelAITask()
        var s = session
        s.sessionState = .completed
        session = s
        syncFromEngine(reason: "finishMatchTimeUp")
        WatchHaptics.matchEnd()
        route = .end(buildSummary())
    }

    func playAgain() {
        cancelFeedback()
        cancelBoardPreviewTask()
        route = .setup
        session = GameEngine.makeIdleSession()
        syncFromEngine(reason: "playAgain")
        isAIThinking = false
        matchSecondsRemaining = 0
        showLowTimeHint = false
    }

    func handleCellTap(_ cellIndex: Int) {
        let boardIdx = activeBoardIndex
        guard HumanInputGate.permitsCellPlacement(
            gameMode: session.gameMode,
            sessionState: session.sessionState,
            isAIThinking: isAIThinking || isBoardPreviewing,
            currentMark: currentMark,
            boardPlayState: boards[boardIdx].playState,
            cellMark: boards[boardIdx].cells[cellIndex].mark,
            isFocusedBoard: true,
            humanControlledMark: session.humanControlledMark
        ) else {
            WatchHaptics.invalid()
            return
        }

        let before = session.stats
        do {
            let movedBoardIndex = session.activeBoardIndex
            print("[XOArenaWatch] BEFORE_HUMAN_MOVE engineBoard=\(movedBoardIndex + 1)")
            session = try GameEngine.applyMove(session, boardIndex: boardIdx, cellIndex: cellIndex)
            let newBoardIndex = session.activeBoardIndex
            let didAdvanceBoard = newBoardIndex != movedBoardIndex
            print("[XOArenaWatch] AFTER_HUMAN_MOVE engineBoard=\(newBoardIndex + 1)")
            WatchHaptics.move()
            #if DEBUG
            debugLog(
                "[XOArenaWatch] PLAYER_MOVE \(WatchDebugLogFormatting.boardCellLine(boardIndex: boardIdx, cellIndex: cellIndex))"
            )
            #endif

            if didAdvanceBoard {
                isBoardPreviewing = true
                applyCompletedBoardPreview(boardIndex: movedBoardIndex)
                maybePresentBoardFeedback(before: before, after: session.stats)
                boardPreviewTask?.cancel()
                boardPreviewTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard let self, !Task.isCancelled else { return }
                    self.isBoardPreviewing = false
                    self.boardPreviewTask = nil
                    self.syncFromEngine(reason: "afterBoardPreviewDelay")
                    guard self.session.sessionState == .playing else { return }
                    self.scheduleAIMoveIfNeeded(context: "afterBoardPreview")
                }
            } else {
                syncFromEngine(reason: "afterHumanApplyMove")
                maybePresentBoardFeedback(before: before, after: session.stats)
                scheduleAIMoveIfNeeded(context: "afterPlayerMove")
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
    }

    private func maybePresentBoardFeedback(before: GameStats, after: GameStats) {
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
            WatchHaptics.boardWin(forHuman: true)
        } else if aiUp {
            boardFeedback = .aiPlusOne
            WatchHaptics.boardWin(forHuman: false)
        } else if drew {
            boardFeedback = .draw
            WatchHaptics.drawBoard()
        } else {
            return
        }

        feedbackReset = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 580_000_000)
            guard let self, !Task.isCancelled else { return }
            self.boardFeedback = nil
        }
    }

    private func cancelFeedback(resetOnlyTask: Bool = true) {
        feedbackReset?.cancel()
        feedbackReset = nil
        if !resetOnlyTask {
            boardFeedback = nil
        }
    }

    private func cancelAITask() {
        aiSequence &+= 1
        aiTask?.cancel()
        aiTask = nil
        isAIThinking = false
    }

    private func cancelBoardPreviewTask() {
        boardPreviewTask?.cancel()
        boardPreviewTask = nil
        isBoardPreviewing = false
    }

    /// Watch-only: show **`session.boards[boardIndex]`** (e.g. just-completed slab) before **`activeBoardIndex`** catches up in UI.
    private func applyCompletedBoardPreview(boardIndex: Int) {
        guard session.boards.indices.contains(boardIndex) else { return }
        let board = session.boards[boardIndex]
        visibleBoardIndex = boardIndex
        var row = board.cells.prefix(GameConstants.cellCount).map { cell -> String in
            switch cell.mark {
            case .x: return "X"
            case .o: return "O"
            case .empty: return ""
            }
        }
        while row.count < GameConstants.cellCount { row.append("") }
        visibleBoardCells = Array(row.prefix(GameConstants.cellCount))
        visibleBoardAllowsMoves = false
        visibleBoardID = UUID()
        print("[XOArenaWatch] BOARD_PREVIEW boardDisplay=\(boardIndex + 1) cells=\(visibleBoardCells)")
    }

    private func scheduleAIMoveIfNeeded(context: String) {
        let board = activeBoardIndex
        let mark = currentMark
        let aiSymbol = aiMarkViaSession()

        let willSchedule =
            session.gameMode == .vsAI
                && mark == aiSymbol
                && session.sessionState == .playing
                && matchSecondsRemaining > 0
                && !isBoardPreviewing
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
            extras: "(ctx=\(context) \(WatchDebugLogFormatting.boardTag(boardIndex: board)) slab=\(slabDescribe) session=\(session.sessionState.rawValue))"
        )
        #endif

        guard session.gameMode == .vsAI else { return }
        guard mark == aiSymbol else { return }
        guard session.sessionState == .playing else {
            debugLogSkip("session_not_playing")
            return
        }
        guard matchSecondsRemaining > 0 else {
            debugLogSkip("match_clock_exhausted")
            return
        }
        guard !isBoardPreviewing else {
            debugLogSkip("board_preview_active")
            return
        }
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

        aiSequence &+= 1
        let token = aiSequence
        let scheduledBoard = board
        let scheduledMark = mark

        aiTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isAIThinking = false
                self.aiTask = nil
                self.syncFromEngine(reason: "aiTaskDeferMainActor")
                self.scheduleAIMoveIfNeeded(context: "afterAIMoveDefer")
            }

            self.isAIThinking = true
            self.syncFromEngine(reason: "aiBeforeDelay")

            let slabSnapshot = self.session.boards[scheduledBoard]
            let variationSeed = UInt64(self.aiSequence &* 1_049_867) ^ (UInt64(scheduledBoard) << 32)

            let computed = AIThinkingDelay.nanoseconds(
                difficulty: self.session.aiDifficulty,
                aiRemainingSeconds: self.matchSecondsRemaining,
                board: slabSnapshot,
                aiMark: scheduledMark,
                opponentMark: scheduledMark.nextInTurn,
                variationSeed: variationSeed
            )

            try? await Task.sleep(nanoseconds: computed.nanoseconds)
            self.syncFromEngine(reason: "aiAfterSleepMainActor")

            guard !Task.isCancelled, token == self.aiSequence else {
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
            guard self.matchSecondsRemaining > 0 else {
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
                remainingSeconds: self.matchSecondsRemaining,
                totalSeconds: self.setupDuration.seconds
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

            let before = self.session.stats
            do {
                self.debugLog(
                    "[XOArenaWatch] AI_AUTO_MOVE \(WatchDebugLogFormatting.boardCellLine(boardIndex: scheduledBoard, cellIndex: cell))"
                )
                let movedBoardIndex = self.session.activeBoardIndex
                print("[XOArenaWatch] BEFORE_AI_MOVE engineBoard=\(movedBoardIndex + 1)")
                let next = try GameEngine.applyMove(self.session, boardIndex: scheduledBoard, cellIndex: cell)
                self.session = next
                let newBoardIndex = self.session.activeBoardIndex
                let didAdvanceBoard = newBoardIndex != movedBoardIndex
                print("[XOArenaWatch] AFTER_AI_MOVE engineBoard=\(newBoardIndex + 1)")
                WatchHaptics.move()

                if didAdvanceBoard {
                    self.isBoardPreviewing = true
                    self.applyCompletedBoardPreview(boardIndex: movedBoardIndex)
                    self.maybePresentBoardFeedback(before: before, after: next.stats)
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    self.isBoardPreviewing = false
                    self.syncFromEngine(reason: "afterBoardPreviewDelay")
                } else {
                    self.syncFromEngine(reason: "afterAIApplyMove")
                    self.maybePresentBoardFeedback(before: before, after: next.stats)
                }
            } catch {
                WatchHaptics.invalid()
                self.debugLog(
                    "[XOArenaWatch] AI_AUTO_SKIP reason=apply_move_failed \(WatchDebugLogFormatting.boardCellLine(boardIndex: scheduledBoard, cellIndex: cell))"
                )
            }
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

    private func buildSummary() -> WatchEndSummary {
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
            duration: setupDuration
        )
    }
}
