//
//  AIThinkingDelay.swift
//  XOArena
//

import Foundation

/// Human-like async pacing before central AI applies a move. Wall-clock consumes the AI player’s bank via existing session timer + deadline sync (**`GameViewModel`**); this type only computes **`Task.sleep`** duration.
enum AIThinkingDelay: Sendable {
    private static let winLines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6]
    ]

    /// Returns delay in nanoseconds and a short reason string for **`AI_THINK`** logs.
    static func nanoseconds(
        difficulty: AIDifficulty,
        aiRemainingSeconds: Int,
        board: XOBoard,
        aiMark: Mark,
        opponentMark: Mark,
        variationSeed: UInt64
    ) -> (nanoseconds: UInt64, reason: String) {
        let (low, high) = baseRangeSeconds(for: difficulty)
        let u1 = unitInterval(mixSeed(variationSeed, salt: 0xA0761D6478BD642F))
        var seconds = low + (high - low) * u1

        var parts: [String] = [
            String(format: "base=%.2f-%.2f pick=%.3f", low, high, seconds)
        ]

        let tactical = hasImmediateWinOrBlock(board: board, aiMark: aiMark, opponentMark: opponentMark)
        if tactical {
            seconds *= 0.6
            parts.append("tactical_x0.6")
        }

        let filled = board.cells.filter { $0.mark != .empty }.count
        if filled >= 6 {
            seconds *= 0.92
            parts.append("marks6+_x0.92")
        }

        let u2 = unitInterval(mixSeed(variationSeed, salt: 0xE7037ED1A0B428DB))
        seconds *= 0.94 + 0.12 * u2
        parts.append(String(format: "var_x%.2f", 0.94 + 0.12 * u2))

        if aiRemainingSeconds < 10 {
            seconds = min(seconds, 0.15)
            parts.append("cap<10s=0.15")
        } else if aiRemainingSeconds < 30 {
            seconds = min(seconds, 0.3)
            parts.append("cap<30s=0.3")
        }

        seconds = max(seconds, 0.05)
        let ns = UInt64((seconds * 1_000_000_000.0).rounded(.toNearestOrAwayFromZero))
        let bounded = max(ns, 50_000_000)
        parts.append(String(format: "final=%.3fs", Double(bounded) / 1e9))
        return (bounded, parts.joined(separator: " "))
    }

    private static func baseRangeSeconds(for difficulty: AIDifficulty) -> (Double, Double) {
        switch difficulty {
        case .easy: return (0.7, 1.2)
        case .medium: return (0.45, 0.85)
        case .hard: return (0.25, 0.55)
        }
    }

    private static func markDiscriminator(_ m: Mark) -> UInt64 {
        switch m {
        case .x: return 1
        case .o: return 2
        case .empty: return 0
        }
    }

    /// Stable across launches for the same board + token + difficulty (no **`hashValue`**).
    static func variationSeed(board: XOBoard, difficulty: AIDifficulty, token: UInt64) -> UInt64 {
        var s = token &* 0x243F6A8885A308D3
        for (i, c) in board.cells.enumerated() {
            s &+= markDiscriminator(c.mark) &+ UInt64(i) &* 0x9E37_79B9_7F4A_7C15
        }
        switch difficulty {
        case .easy: s ^= 0x1111_1111_1111_1111
        case .medium: s ^= 0x2222_2222_2222_2222
        case .hard: s ^= 0x3333_3333_3333_3333
        }
        return s
    }

    private static func mixSeed(_ seed: UInt64, salt: UInt64) -> UInt64 {
        seed &+ salt &* 0x85EB_CA77_C2B2_AE63
    }

    private static func unitInterval(_ seed: UInt64) -> Double {
        var z = seed &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        let hi = UInt32(truncatingIfNeeded: z)
        return Double(hi) / Double(UInt32.max)
    }

    private static func hasImmediateWinOrBlock(board: XOBoard, aiMark: Mark, opponentMark: Mark) -> Bool {
        guard aiMark == .x || aiMark == .o, opponentMark == .x || opponentMark == .o else { return false }
        let marks = board.cells.map(\.mark)
        for line in winLines {
            var aiC = 0
            var opC = 0
            var emC = 0
            for i in line {
                let m = marks[i]
                if m == aiMark { aiC += 1 }
                else if m == opponentMark { opC += 1 }
                else if m == .empty { emC += 1 }
            }
            if aiC == 2, emC == 1 { return true }
            if opC == 2, emC == 1 { return true }
        }
        return false
    }
}
