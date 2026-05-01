//
//  TicTacToeAI.swift
//  XOArena
//

import Foundation

/// Single-slab tic-tac-toe AI: **`rankedMoves`** + minimax, with humanized stochastic choices by **`AIDifficulty`**.
enum TicTacToeAI: Sendable {
    typealias RankedMove = (index: Int, score: Int)

    /// All legal AI moves scored from the AI perspective (**leaf: win +1 · loss −1 · draw 0**), **descending `score`**, then ascending **`index`** for ties.
    static func rankedMoves(on board: XOBoard, aiMark: Mark, humanMark: Mark) -> [RankedMove] {
        precondition(aiMark == .o || aiMark == .x)
        precondition(humanMark == .o || humanMark == .x)
        precondition(aiMark != humanMark)
        guard board.playState == .inProgress else { return [] }

        var rows: [RankedMove] = []
        for cell in emptyIndices(on: board) {
            guard let child = boardByPlacing(board, at: cell, mark: aiMark) else { continue }
            let score = minimax(
                board: child,
                aiMark: aiMark,
                humanMark: humanMark,
                maximizingForAI: false
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
        let secondTierFirst = ranked.first(where: { $0.score < topScore })
        let secondIndex = secondTierFirst?.index

        let u = randomUnit()
        switch pressure {
        case .comfortable:
            if u < 0.90 {
                return pickSortedUniform(from: bestBucketSorted, randomUnit: randomUnit)
            }
            return secondIndex ?? pickSortedUniform(from: bestBucketSorted, randomUnit: randomUnit)

        case .low:
            if u < 0.80 {
                return pickSortedUniform(from: bestBucketSorted, randomUnit: randomUnit)
            }
            if let s = secondIndex { return s }
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
        maximizingForAI: Bool
    ) -> Int {
        if let w = BoardEvaluator.winner(in: board) {
            if w == aiMark { return 1 }
            if w == humanMark { return -1 }
            return 0
        }
        if BoardEvaluator.isDraw(board) { return 0 }

        let markToPlay = maximizingForAI ? aiMark : humanMark
        let empties = emptyIndices(on: board)

        if maximizingForAI {
            var value = Int.min
            for cell in empties {
                guard let child = boardByPlacing(board, at: cell, mark: markToPlay) else { continue }
                value = max(
                    value,
                    minimax(board: child, aiMark: aiMark, humanMark: humanMark, maximizingForAI: false)
                )
            }
            return value
        } else {
            var value = Int.max
            for cell in empties {
                guard let child = boardByPlacing(board, at: cell, mark: markToPlay) else { continue }
                value = min(
                    value,
                    minimax(board: child, aiMark: aiMark, humanMark: humanMark, maximizingForAI: true)
                )
            }
            return value
        }
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

    /// **`weights`** matches **`count`**; consumes one **`randomUnit`** draw.
    private static func weightedPick(count: Int, weights: [Double], randomUnit: () -> Double) -> Int {
        guard count > 0 else { return 0 }
        guard count > 1 else {
            _ = randomUnit()
            return 0
        }
        var w = weights
        if w.count != count {
            w = (0..<count).map { i in i < weights.count ? weights[i] : (weights.last ?? 1) / Double(count) }
            normalize(&w)
        }
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
