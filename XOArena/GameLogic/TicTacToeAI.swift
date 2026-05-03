//
//  TicTacToeAI.swift
//  XOArena
//

import Foundation

/// Single-slab tic-tac-toe AI: **`rankedMoves`** + minimax, with humanized stochastic choices by **`AIDifficulty`**.
enum TicTacToeAI: Sendable {
    typealias RankedMove = (index: Int, score: Int)

    private struct MinimaxCacheKey: Hashable {
        var encodedMarks: UInt32
        let aiMark: Mark
        let humanMark: Mark
        let maximizingForAI: Bool

        init(board: XOBoard, aiMark: Mark, humanMark: Mark, maximizingForAI: Bool) {
            self.encodedMarks = Self.encodeMarks(board)
            self.aiMark = aiMark
            self.humanMark = humanMark
            self.maximizingForAI = maximizingForAI
        }

        /// Base-3 packing of the nine cell marks (order matches **cell index**).
        private static func encodeMarks(_ board: XOBoard) -> UInt32 {
            var code: UInt32 = 0
            var mul: UInt32 = 1
            for cell in board.cells {
                let t: UInt32
                switch cell.mark {
                case .empty: t = 0
                case .x: t = 1
                case .o: t = 2
                }
                code &+= t &* mul
                mul &*= 3
            }
            return code
        }
    }

    /// All legal AI moves scored from the AI perspective (**leaf: win +1 · loss −1 · draw 0**), **descending `score`**, then ascending **`index`** for ties.
    static func rankedMoves(on board: XOBoard, aiMark: Mark, humanMark: Mark) -> [RankedMove] {
        precondition(aiMark == .o || aiMark == .x)
        precondition(humanMark == .o || humanMark == .x)
        precondition(aiMark != humanMark)
        guard board.playState == .inProgress else { return [] }

        var minimaxCache: [MinimaxCacheKey: Int] = [:]
        var rows: [RankedMove] = []
        for cell in emptyIndices(on: board) {
            guard let child = boardByPlacing(board, at: cell, mark: aiMark) else { continue }
            let score = minimax(
                board: child,
                aiMark: aiMark,
                humanMark: humanMark,
                maximizingForAI: false,
                cache: &minimaxCache
            )
            rows.append((cell, score))
        }
        rows.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.index < b.index
        }
        return rows
    }

    /// Next cell index for **`aiMark`** on **`board`**, or `nil` when the slab is finished.
    static func chooseMove(
        on board: XOBoard,
        aiMark: Mark,
        humanMark: Mark,
        difficulty: AIDifficulty = .hard,
        timerContext: AIMoveTimerContext? = nil
    ) -> Int? {
        chooseMove(
            on: board,
            aiMark: aiMark,
            humanMark: humanMark,
            difficulty: difficulty,
            timerContext: timerContext,
            randomUnit: { Double.random(in: 0..<1) }
        )
    }

    /// Same as **`chooseMove`**, **`randomUnit`** draws in **\[0 , 1\)** for stochastic branches (**`@testable`**).
    static func chooseMove(
        on board: XOBoard,
        aiMark: Mark,
        humanMark: Mark,
        difficulty: AIDifficulty,
        timerContext: AIMoveTimerContext?,
        randomUnit: () -> Double
    ) -> Int? {
        guard board.playState == .inProgress else { return nil }
        precondition(aiMark == .o || aiMark == .x)
        precondition(humanMark == .o || humanMark == .x)
        precondition(aiMark != humanMark)

        let empties = emptyIndices(on: board)
        guard !empties.isEmpty else { return nil }

        let pressure = timerContext?.pressureTier() ?? .comfortable

        switch difficulty {
        case .easy:
            return chooseEasy(
                board: board,
                aiMark: aiMark,
                humanMark: humanMark,
                empties: empties,
                pressure: pressure,
                randomUnit: randomUnit
            )
        case .medium:
            if let tac = immediateTacticalMove(board: board, aiMark: aiMark, humanMark: humanMark) {
                return tac
            }
            return chooseMediumFromRankings(
                board: board,
                aiMark: aiMark,
                humanMark: humanMark,
                pressure: pressure,
                randomUnit: randomUnit
            )
        case .hard:
            if let tac = immediateTacticalMove(board: board, aiMark: aiMark, humanMark: humanMark) {
                return tac
            }
            return chooseHard(
                ranked: rankedMoves(on: board, aiMark: aiMark, humanMark: humanMark),
                pressure: pressure,
                randomUnit: randomUnit
            )
        }
    }

    // MARK: - Tactical (shared)

    private static func immediateTacticalMove(board: XOBoard, aiMark: Mark, humanMark: Mark) -> Int? {
        if let win = immediateWinningCell(board: board, mark: aiMark) { return win }
        if let block = immediateWinningCell(board: board, mark: humanMark) { return block }
        return nil
    }

    // MARK: - Difficulty pickers

    private static func chooseHard(
        ranked: [RankedMove],
        pressure: AIMoveTimerContext.Pressure,
        randomUnit: () -> Double
    ) -> Int? {
        guard let best = ranked.first else { return nil }
        let topScore = best.score
        let bestBucketSorted = ranked.filter { $0.score == topScore }.map(\.index).sorted()
        let secondTierSorted = ranked.filter { $0.score < topScore }.map(\.index).sorted()

        let u = randomUnit()
        switch pressure {
        case .comfortable:
            if u < 0.90 {
                return pickSortedUniform(from: bestBucketSorted, randomUnit: randomUnit)
            }
            if !secondTierSorted.isEmpty {
                return pickSortedUniform(from: secondTierSorted, randomUnit: randomUnit)
            }
            return pickSortedUniform(from: bestBucketSorted, randomUnit: randomUnit)

        case .low:
            if u < 0.80 {
                return pickSortedUniform(from: bestBucketSorted, randomUnit: randomUnit)
            }
            if !secondTierSorted.isEmpty {
                return pickSortedUniform(from: secondTierSorted, randomUnit: randomUnit)
            }
            let top3Sorted = ranked.prefix(min(3, ranked.count)).map(\.index).sorted()
            return pickSortedUniform(from: top3Sorted, randomUnit: randomUnit)

        case .critical:
            let topK = min(4, ranked.count)
            var weights: [Double] = [0.50, 0.25, 0.15, 0.10]
            if topK < 4 {
                weights = Array(weights.prefix(topK))
                normalize(&weights)
            }
            let pick = weightedPick(count: topK, weights: weights, randomUnit: randomUnit)
            return ranked[pick].index
        }
    }

    private static func chooseMediumFromRankings(
        board: XOBoard,
        aiMark: Mark,
        humanMark: Mark,
        pressure: AIMoveTimerContext.Pressure,
        randomUnit: () -> Double
    ) -> Int? {
        let ranked = rankedMoves(on: board, aiMark: aiMark, humanMark: humanMark)
        guard !ranked.isEmpty else { return nil }

        let k: Int
        switch pressure {
        case .comfortable: k = 3
        case .low: k = 4
        case .critical: k = min(6, ranked.count)
        }
        let slice = Array(ranked.prefix(min(k, ranked.count)))
        let i = uniformSlot(count: slice.count, randomUnit: randomUnit)
        return slice[i].index
    }

    private static func chooseEasy(
        board: XOBoard,
        aiMark: Mark,
        humanMark: Mark,
        empties: [Int],
        pressure: AIMoveTimerContext.Pressure,
        randomUnit: () -> Double
    ) -> Int? {
        let sortedEmpties = empties.sorted()
        let safe = sortedEmpties.filter { cell in
            guard let child = boardByPlacing(board, at: cell, mark: aiMark) else { return false }
            return immediateWinningCell(board: child, mark: humanMark) == nil
        }
        let panicMix: Double
        switch pressure {
        case .comfortable: panicMix = 0
        case .low: panicMix = 0.12
        case .critical: panicMix = 0.30
        }
        let u = randomUnit()
        let pool = (safe.isEmpty || u < panicMix) ? sortedEmpties : safe
        return pickSortedUniform(from: pool, randomUnit: randomUnit)
    }

    // MARK: - Minimax

    private static func minimax(
        board: XOBoard,
        aiMark: Mark,
        humanMark: Mark,
        maximizingForAI: Bool,
        cache: inout [MinimaxCacheKey: Int]
    ) -> Int {
        let key = MinimaxCacheKey(board: board, aiMark: aiMark, humanMark: humanMark, maximizingForAI: maximizingForAI)
        if let hit = cache[key] { return hit }

        let value: Int
        if let w = BoardEvaluator.winner(in: board) {
            if w == aiMark { value = 1 }
            else if w == humanMark { value = -1 }
            else { value = 0 }
        } else if BoardEvaluator.isDraw(board) {
            value = 0
        } else {
            let markToPlay = maximizingForAI ? aiMark : humanMark
            let empties = emptyIndices(on: board)

            if maximizingForAI {
                var maxV = Int.min
                for cell in empties {
                    guard let child = boardByPlacing(board, at: cell, mark: markToPlay) else { continue }
                    maxV = max(
                        maxV,
                        minimax(board: child, aiMark: aiMark, humanMark: humanMark, maximizingForAI: false, cache: &cache)
                    )
                }
                value = maxV
            } else {
                var minV = Int.max
                for cell in empties {
                    guard let child = boardByPlacing(board, at: cell, mark: markToPlay) else { continue }
                    minV = min(
                        minV,
                        minimax(board: child, aiMark: aiMark, humanMark: humanMark, maximizingForAI: true, cache: &cache)
                    )
                }
                value = minV
            }
        }
        cache[key] = value
        return value
    }

    /// One ply: lowest-index empty whose fill by **`mark`** wins on **`board`**.
    private static func immediateWinningCell(board: XOBoard, mark: Mark) -> Int? {
        for idx in 0..<GameConstants.cellCount where board.cells[idx].mark == .empty {
            guard let next = boardByPlacing(board, at: idx, mark: mark) else { continue }
            if BoardEvaluator.winner(in: next) == mark { return idx }
        }
        return nil
    }

    // MARK: - Board helpers

    private static func emptyIndices(on board: XOBoard) -> [Int] {
        (0..<GameConstants.cellCount).filter { board.cells[$0].mark == .empty }
    }

    private static func boardByPlacing(_ board: XOBoard, at index: Int, mark: Mark) -> XOBoard? {
        guard board.cells[index].mark == .empty else { return nil }
        var copy = board
        copy.cells[index].mark = mark
        return copy
    }

    private static func uniformSlot(count: Int, randomUnit: () -> Double) -> Int {
        guard count > 1 else {
            _ = randomUnit()
            return 0
        }
        var u = randomUnit()
        if u >= 1 { u = nextafter(1.0, 0.0) * 0.9999999999999999 }
        return min(count - 1, Int(u * Double(count)))
    }

    /// One draw allocates the slot (**uniform over sorted order**).
    private static func pickSortedUniform(from sortedIndices: [Int], randomUnit: () -> Double) -> Int {
        precondition(!sortedIndices.isEmpty, "non-empty indices required")
        let i = uniformSlot(count: sortedIndices.count, randomUnit: randomUnit)
        return sortedIndices[i]
    }

    private static func normalize(_ w: inout [Double]) {
        let s = w.reduce(0, +)
        guard s > 0 else { return }
        for i in w.indices { w[i] /= s }
    }

    /// **`weights`** should align with **`count`**; if not, values are truncated or padded with equal positive weights, then normalized.
    private static func weightedPick(count: Int, weights: [Double], randomUnit: () -> Double) -> Int {
        guard count > 0 else { return 0 }
        guard count > 1 else {
            _ = randomUnit()
            return 0
        }
        var w: [Double] = (0..<count).map { i in
            if i < weights.count { return max(weights[i], 0) }
            return 1
        }
        var sum = w.reduce(0, +)
        if sum <= 0 || !sum.isFinite {
            w = Array(repeating: 1, count: count)
            sum = Double(count)
        }
        for i in w.indices { w[i] /= sum }
        var u = randomUnit()
        if u >= 1 { u = nextafter(u, 0) }
        var acc = 0.0
        for i in 0..<count {
            acc += w[i]
            if u < acc { return i }
        }
        return count - 1
    }
}
