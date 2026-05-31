//
//  TimeRewardEvent.swift
//  XOArena
//

import Foundation

enum TimeRewardReason: Equatable, Hashable, Sendable {
    case pvpBoardWin
    case pvpDraw
    case humanBoardWinAgainstAI(difficulty: AIDifficulty)
}

struct TimeRewardEvent: Equatable, Sendable {
    let xDelta: Int
    let oDelta: Int
    let reason: TimeRewardReason

    /// Jednolinijski HUD ispod sata (**−** je U+2212). Redosled uvek kao glavni tajmer: **X levo**, **O desno**.
    var clockRowCaption: String {
        switch reason {
        case .pvpDraw:
            let gain = max(xDelta, oDelta)
            return "Draw +\(gain)s"
        case .humanBoardWinAgainstAI(let difficulty):
            let humanGain = max(xDelta, oDelta)
            return "\(difficulty.displayTitle) AI Defeated +\(humanGain)s"
        case .pvpBoardWin:
            break
        }
        let m = "\u{2212}"
        let xSide = xDelta > 0 ? "+\(xDelta)s X" : (xDelta < 0 ? "\(m)\(abs(xDelta))s X" : "0s X")
        let oSide = oDelta > 0 ? "+\(oDelta)s O" : (oDelta < 0 ? "\(m)\(abs(oDelta))s O" : "0s O")
        if reason == .pvpBoardWin, xDelta > 0 || oDelta > 0 {
            let winnerGain = max(xDelta, oDelta)
            return "Board Win +\(winnerGain)s · \(xSide)   \(oSide)"
        }
        return "\(xSide)   \(oSide)"
    }
}

private extension AIDifficulty {
    var displayTitle: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}
