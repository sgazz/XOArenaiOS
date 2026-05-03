//
//  TimeRewardEvent.swift
//  XOArena
//

import Foundation

enum TimeRewardReason: Equatable, Hashable, Sendable {
    case playerWin
}

struct TimeRewardEvent: Equatable, Sendable {
    let xDelta: Int
    let oDelta: Int
    let reason: TimeRewardReason

    /// Čovek pobedio na tabli protiv AI (**vsAI** / **learning**): **+shift** na njegovu banku, **−shift** na AI.
    static func humanBoardWinAgainstAI(humanMark: Mark, shift: Int = 5) -> TimeRewardEvent {
        let xDelta = humanMark == .x ? shift : -shift
        let oDelta = humanMark == .o ? shift : -shift
        return TimeRewardEvent(xDelta: xDelta, oDelta: oDelta, reason: .playerWin)
    }

    /// Jednolinijski HUD ispod sata (**−** je U+2212). Redosled uvek kao glavni tajmer: **X levo**, **O desno**.
    var clockRowCaption: String {
        let m = "\u{2212}"
        let xSide = xDelta > 0 ? "+\(xDelta)s X" : "\(m)\(abs(xDelta))s X"
        let oSide = oDelta > 0 ? "+\(oDelta)s O" : "\(m)\(abs(oDelta))s O"
        return "\(xSide)   \(oSide)"
    }
}
