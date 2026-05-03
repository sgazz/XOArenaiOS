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

    private var matchTimer: Timer?
    private var feedbackReset: Task<Void, Never>?
    private var aiSequence: UInt64 = 0
    private var aiTask: Task<Void, Never>?

    private var humanMark: Mark { setupSymbol.mark }
    private var aiMark: Mark { humanMark.nextInTurn }

    var boards: [XOBoard] { session.boards }
    var activeBoardIndex: Int { session.activeBoardIndex }
    var currentMark: Mark { session.currentMarkForActiveBoard }

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
    }

    func onGameAppear() {
        guard case .game = route else { return }
        guard matchSecondsRemaining > 0, session.sessionState == .playing else { return }
        startMatchTickerIfNeeded()
        scheduleAIIfNeeded()
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
        WatchHaptics.matchEnd()
        route = .end(buildSummary())
    }

    func playAgain() {
        cancelFeedback()
        route = .setup
        session = GameEngine.makeIdleSession()
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
            WatchHaptics.move()
            maybePresentBoardFeedback(before: before, after: session.stats)
            scheduleAIIfNeeded()
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

    private func scheduleAIIfNeeded() {
        let board = activeBoardIndex
        let mark = currentMark
        let mode = session.gameMode
        let aiScheduledMark = (session.humanControlledMark ?? .x).nextInTurn
        let needsAI = mode == .vsAI && mark == aiScheduledMark

        guard needsAI else { return }
        guard session.sessionState == .playing else { return }
        guard matchSecondsRemaining > 0 else { return }
        guard aiTask == nil else { return }
        guard boards.indices.contains(board) else { return }
        let slab = boards[board]
        guard slab.playState == .inProgress else { return }

        aiSequence &+= 1
        let token = aiSequence
        let scheduledBoard = board
        let scheduledMark = mark

        aiTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isAIThinking = false
                self.aiTask = nil
                self.scheduleAIIfNeeded()
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

            guard !Task.isCancelled, token == self.aiSequence else { return }
            guard self.session.sessionState == .playing else { return }
            guard self.session.activeBoardIndex == scheduledBoard else { return }
            guard self.currentMark == scheduledMark else { return }
            guard self.matchSecondsRemaining > 0 else {
                self.finishMatchTimeUp()
                return
            }

            let activeSlab = self.session.boards[self.session.activeBoardIndex]
            guard activeSlab.playState == .inProgress else { return }

            let humanM = self.session.humanControlledMark ?? .x
            let aiM = humanM.nextInTurn
            let ctx = AIMoveTimerContext(
                remainingSeconds: self.matchSecondsRemaining,
                totalSeconds: self.setupDuration.seconds
            )
            let difficultySnapshot = self.session.aiDifficulty

            let cellOpt = await Task.detached(priority: .utility) {
                TicTacToeAI.chooseMove(
                    on: activeSlab,
                    aiMark: aiM,
                    humanMark: humanM,
                    difficulty: difficultySnapshot,
                    timerContext: ctx
                )
            }.value

            guard let cell = cellOpt else { return }
            guard token == self.aiSequence else { return }
            guard self.session.sessionState == .playing else { return }
            guard self.session.activeBoardIndex == scheduledBoard else { return }

            let before = self.session.stats
            do {
                let next = try GameEngine.applyMove(self.session, boardIndex: scheduledBoard, cellIndex: cell)
                self.session = next
                WatchHaptics.move()
                self.maybePresentBoardFeedback(before: before, after: next.stats)
            } catch {
                WatchHaptics.invalid()
            }
        }
    }

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
