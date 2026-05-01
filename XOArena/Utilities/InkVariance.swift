//
//  InkVariance.swift
//  XOArena
//

import CoreGraphics

/// Deterministic ink personality per board/cell — stable across layout passes.
enum InkVariance {
    static func cellSeed(boardIndex: Int, cellIndex: Int) -> UInt32 {
        var n = UInt32(truncatingIfNeeded: boardIndex &* 1_069 &+ cellIndex &* 37_943)
        n &*= 2_659_443_763
        n ^= n >> 16
        n &*= 224_694_353
        n ^= n >> 13
        return n
    }

    /// -2° … +2° (deterministic).
    static func markRotationDegrees(boardIndex: Int, cellIndex: Int) -> Double {
        let h = cellSeed(boardIndex: boardIndex, cellIndex: cellIndex)
        let u = Double(h % 20_011) / 20_010
        return -2 + u * 4
    }

    /// Roughly ±1…2 pt (deterministic magnitude + sign).
    static func markOffsetPoints(boardIndex: Int, cellIndex: Int) -> CGSize {
        let h = cellSeed(boardIndex: boardIndex, cellIndex: cellIndex)
        let sx: CGFloat = (h & 1) == 0 ? 1 : -1
        let sy: CGFloat = ((h >> 1) & 1) == 0 ? 1 : -1
        let magX = 1 + CGFloat((h >> 3) % 101) / 100
        let magY = 1 + CGFloat((h >> 9) % 101) / 100
        return CGSize(width: sx * magX, height: sy * magY)
    }

    /// Multiplier for nominal strokes (≈ 0.90 … 1.10).
    static func strokeScale(boardIndex: Int, cellIndex: Int) -> CGFloat {
        let h = cellSeed(boardIndex: boardIndex, cellIndex: cellIndex)
        return 0.9 + CGFloat(h % 2_051) / 2_050 * 0.2
    }

    /// Per-board scale drift 0.98 … 1.02.
    static func boardPresenceScale(boardIndex: Int) -> CGFloat {
        let h = UInt32(truncatingIfNeeded: boardIndex &* 17_759 &+ 99_983)
        return 0.98 + CGFloat(h % 401) / 400 * 0.04
    }

    /// Modulates frame contrast (≈ 0.88 … 1.12).
    static func boardBorderIntensity(boardIndex: Int) -> CGFloat {
        let h = UInt32(truncatingIfNeeded: boardIndex &* 29_087 &+ 40_063)
        return 0.88 + CGFloat(h % 481) / 480 * 0.24
    }

    /// Per-cell graphite frame shimmer (barely perceptible edge wash).
    static func cellEdgeOpacityDrift(boardIndex: Int, cellIndex: Int) -> CGFloat {
        let h = cellSeed(boardIndex: boardIndex, cellIndex: cellIndex)
        return 0.9 + CGFloat(h % 379) / 378 * 0.18
    }
}
