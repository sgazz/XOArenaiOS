//
//  HumanInputGate.swift
//  XOArena
//

import Foundation

/// Central gate for tactile input (testable independently of **`GameViewModel`** delays).
enum HumanInputGate: Sendable {
    static func permitsCellPlacement(
        gameMode: GameMode,
        sessionState: GameSessionState,
        isAIThinking: Bool,
        currentMark: Mark,
        boardPlayState: BoardPlayState,
        cellMark: Mark,
        isFocusedBoard: Bool,
        humanControlledMark: Mark?
    ) -> Bool {
        guard sessionState == .playing else { return false }
        guard isFocusedBoard else { return false }
        guard boardPlayState == .inProgress else { return false }
        guard cellMark == .empty else { return false }
        guard !isAIThinking else { return false }
        switch gameMode {
        case .vsAI, .learning:
            let human = humanControlledMark ?? .x
            guard human == .x || human == .o else { return false }
            return currentMark == human
        case .aiVsAI:
            return false
        case .soloFocus, .localDuel:
            return true
        }
    }
}
