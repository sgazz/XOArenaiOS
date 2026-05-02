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

    /// Seme za varijantu oznake; `placementMoveOrdinal` uključuje broj poteza u trenutku postavljanja (stabilno nakon lock-a u view-u).
    static func glyphVariantSeed(boardIndex: Int, cellIndex: Int, placementMoveOrdinal: Int?) -> UInt32 {
        var n = cellSeed(boardIndex: boardIndex, cellIndex: cellIndex)
        if let m = placementMoveOrdinal {
            n ^= UInt32(truncatingIfNeeded: m &* 402_689)
            n &*= 2_647_871_231
            n ^= n >> 15
        }
        return n
    }

    /// 0 … 4 — X oblik.
    static func xVariantIndex(boardIndex: Int, cellIndex: Int, placementMoveOrdinal: Int?) -> Int {
        Int(glyphVariantSeed(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal) % 5)
    }

    /// 0 … 4 — O oblik (druga mješavina da korelacija s X bude slaba).
    static func oVariantIndex(boardIndex: Int, cellIndex: Int, placementMoveOrdinal: Int?) -> Int {
        var s = glyphVariantSeed(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
        s = s &* 2_982_579_839 &+ 1
        s ^= s >> 11
        return Int(s % 5)
    }

    /// -2° … +2° (deterministic).
    static func markRotationDegrees(boardIndex: Int, cellIndex: Int, placementMoveOrdinal: Int?) -> Double {
        let h = glyphVariantSeed(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
        let u = Double(h % 20_011) / 20_010
        return -2 + u * 4
    }

    /// Dodatni fini zakret ≈ −1° … +1° (odvojeno od glavnog luka).
    static func markRotationFineTuneDegrees(boardIndex: Int, cellIndex: Int, placementMoveOrdinal: Int?) -> Double {
        let h = glyphVariantSeed(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
        let u = Double((h >> 5) % 16_067) / 16_066
        return -1 + u * 2
    }

    /// Roughly ±1–2 pt (deterministic magnitude + sign).
    static func markOffsetPoints(boardIndex: Int, cellIndex: Int, placementMoveOrdinal: Int?) -> CGSize {
        let h = glyphVariantSeed(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
        let sx: CGFloat = (h & 1) == 0 ? 1 : -1
        let sy: CGFloat = ((h >> 1) & 1) == 0 ? 1 : -1
        let magX = 1 + CGFloat((h >> 3) % 101) / 100
        let magY = 1 + CGFloat((h >> 9) % 101) / 100
        return CGSize(width: sx * magX, height: sy * magY)
    }

    /// Multiplier for nominal strokes (≈ 0.88 … 1.12).
    static func strokeScale(boardIndex: Int, cellIndex: Int, placementMoveOrdinal: Int?) -> CGFloat {
        let h = glyphVariantSeed(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
        return 0.88 + CGFloat(h % 2_401) / 2_400 * 0.24
    }

    /// Tri sloja: vanjski, srednji, unutarnji (≈ 0.93 … 1.07).
    static func markLayerOpacityDrifts(boardIndex: Int, cellIndex: Int, placementMoveOrdinal: Int?) -> (CGFloat, CGFloat, CGFloat) {
        let s = glyphVariantSeed(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
        func t(_ shift: UInt32) -> CGFloat {
            let v = (s >> shift) % 197
            return 0.93 + CGFloat(v) / 196 * 0.14
        }
        return (t(0), t(8), t(17))
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
