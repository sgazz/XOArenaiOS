//
//  WatchGameCoordinator.swift
//  XOArenaWatch
//

import Foundation
import Observation

@MainActor
@Observable
final class WatchGameCoordinator {
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

    /// Immutable value snapshot for SwiftUI (**watch-only**); avoids stale nested session reads.
    /// `cells`: `nil` = empty square; **`id`** ties **`boardIndex` + `renderVersion`** so the grid reinstantiates every rebuild.
    struct WatchBoardRenderState: Equatable, Identifiable {
        let id: String
        let boardIndex: Int
        let boardDisplay: Int
        let cells: [Mark?]
        let phase: BoardPlayState
        let renderVersion: Int

        init(boardIndex: Int, renderVersion: Int, cells: [Mark?], phase: BoardPlayState) {
            self.boardIndex = boardIndex
            self.boardDisplay = boardIndex + 1
            self.renderVersion = renderVersion
            self.cells = cells
            self.phase = phase
            self.id = "\(boardIndex)-\(renderVersion)"
        }
    }

    var route: Route = .intro

    var setupSymbol: PlayerSymbolChoice = .x
    var setupFirst: FirstMoverChoice = .player
    var setupDuration: GameDuration = .oneMinute

    private(set) var session: GameSession = GameEngine.makeIdleSession()
    private(set) var isAIThinking: Bool = false

    /// Single match countdown (wall clock from first game screen).
    private(set) var matchSecondsRemaining: Int = 0

    private(set) var boardFeedback: BoardFeedback?
    private(set) var showLowTimeHint: Bool = false

    /// Single source of truth for the board grid (`@Observable` tracks assignments; same role as **`@Published`** on an observable object).
    private(set) var boardRenderState: WatchBoardRenderState = WatchBoardRenderState(
        boardIndex: 0,
        renderVersion: 0,
        cells: Array(repeating: nil, count: GameConstants.cellCount),
        phase: .inProgress
    )

    private var boardRenderGeneration: Int = 0

    private var matchTimer: Timer?
    private var feedbackReset: Task<Void, Never>?
    private var aiSequence: UInt64 = 0
    private var aiTask: Task<Void, Never>?

    private var humanMark: Mark { setupSymbol.mark }
    private var aiMark: Mark { humanMark.nextInTurn }

    var boards: [XOBoard] { session.boards }
    var activeBoardIndex: Int { session.activeBoardIndex }
    var currentMark: Mark { session.currentMarkForActiveBoard }

    /// Match clock for compact hero bar (**`m:ss`**, monospaced in UI).
    var remainingTimeText: String {
        let t = max(0, matchSecondsRemaining)
        let m = t / 60
        let s = t % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Human slab wins (vsAI uses **`humanControlledMark`** when set).
    var playerScore: Int {
        let hMark = session.humanControlledMark ?? humanMark
        return hMark == .x ? session.stats.xBoardWins : session.stats.oBoardWins
    }

    /// AI slab wins.
    var aiScore: Int {
        let hMark = session.humanControlledMark ?? humanMark
        let aiM = hMark.nextInTurn
        return aiM == .x ? session.stats.xBoardWins : session.stats.oBoardWins
    }

    /// Single-line score for hero bar (**You / AI** labels).
    var scoreText: String {
        "You \(playerScore) · AI \(aiScore)"
    }

    init() {
        rebuildBoardRenderState()
    }

    func tapIntroAdvance() {
        route = .setup
    }

    func beginMatchFromSetup() {
        cancelFeedback()
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
        rebuildBoardRenderState()
        scheduleAIMoveIfNeeded(context: "beginMatchFromSetup")
    }

    func onGameAppear() {
        guard case .game = route else { return }
        guard matchSecondsRemaining > 0, session.sessionState == .playing else { return }
        startMatchTickerIfNeeded()
        scheduleAIMoveIfNeeded(context: "onGameAppear")
    }

    func onGameDisappear() {
        stopMatchTicker()
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
        cancelAITask()
        var s = session
        s.sessionState = .completed
        session = s
        rebuildBoardRenderState()
        WatchHaptics.matchEnd()
        route = .end(buildSummary())
    }

    func playAgain() {
        cancelFeedback()
        route = .setup
        session = GameEngine.makeIdleSession()
        rebuildBoardRenderState()
        isAIThinking = false
        matchSecondsRemaining = 0
        showLowTimeHint = false
    }

    func cellTapped(cellIndex: Int) {
        let boardIdx = activeBoardIndex
        guard HumanInputGate.permitsCellPlacement(
            gameMode: session.gameMode,
            sessionState: session.sessionState,
            isAIThinking: isAIThinking,
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
            session = try GameEngine.applyMove(session, boardIndex: boardIdx, cellIndex: cellIndex)
            rebuildBoardRenderState()
            WatchHaptics.move()
            #if DEBUG
            debugLog(
                "[XOArenaWatch] PLAYER_MOVE \(WatchDebugLogFormatting.boardCellLine(boardIndex: boardIdx, cellIndex: cellIndex))"
            )
            #endif
            maybePresentBoardFeedback(before: before, after: session.stats)
            scheduleAIMoveIfNeeded(context: "afterPlayerMove")
        } catch {
            WatchHaptics.invalid()
        }
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

    /// Schedules **`TicTacToeAI`** when **`currentMark`** is the AI symbol (first move **Second**, after human move, board transition / reset → engine updates turn).
    private func scheduleAIMoveIfNeeded(context: String) {
        let board = activeBoardIndex
        let mark = currentMark
        let aiSymbol = aiMarkViaSession()

        let willSchedule =
            session.gameMode == .vsAI
                && mark == aiSymbol
                && session.sessionState == .playing
                && matchSecondsRemaining > 0
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
                self.scheduleAIMoveIfNeeded(context: "afterAIMoveDefer")
            }

            self.isAIThinking = true

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
                let next = try GameEngine.applyMove(self.session, boardIndex: scheduledBoard, cellIndex: cell)
                self.session = next
                self.rebuildBoardRenderState()
                WatchHaptics.move()
                self.maybePresentBoardFeedback(before: before, after: next.stats)
            } catch {
                WatchHaptics.invalid()
                self.debugLog(
                    "[XOArenaWatch] AI_AUTO_SKIP reason=apply_move_failed \(WatchDebugLogFormatting.boardCellLine(boardIndex: scheduledBoard, cellIndex: cell))"
                )
            }
        }
    }

    /// Aligns with **`GameEngine`** / **`makeInitialSession`** (`humanControlledMark` + opposite = AI).
    private func aiMarkViaSession() -> Mark {
        (session.humanControlledMark ?? .x).nextInTurn
    }

    /// Replaces the entire grid snapshot after every session mutation that can change the active slab (**human / AI / advance / reset / match start**).
    private func rebuildBoardRenderState() {
        boardRenderGeneration += 1
        let rv = boardRenderGeneration
        let idx = session.activeBoardIndex

        let cells: [Mark?]
        let phase: BoardPlayState

        if session.boards.indices.contains(idx) {
            let slab = session.boards[idx]
            let mapped = slab.cells.map { cell -> Mark? in
                switch cell.mark {
                case .empty: return nil
                case .x: return .x
                case .o: return .o
                }
            }
            cells = mapped.count == GameConstants.cellCount
                ? mapped
                : Array(repeating: nil, count: GameConstants.cellCount)
            phase = slab.playState
        } else {
            cells = Array(repeating: nil, count: GameConstants.cellCount)
            phase = .inProgress
        }

        boardRenderState = WatchBoardRenderState(boardIndex: idx, renderVersion: rv, cells: cells, phase: phase)

        #if DEBUG
        let cellsLog = cells.map { $0?.rawValue ?? "empty" }.joined(separator: ",")
        debugLog("[XOArenaWatch] RENDER_REBUILD version=\(rv) boardDisplay=\(boardRenderState.boardDisplay) cells=\(cellsLog)")
        #endif
    }

    /// Debug-only wording: **`boardDisplay`/`cellDisplay`** match one-based numbering used in **`GameEngine`** logs.
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
