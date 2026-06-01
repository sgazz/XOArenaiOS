//
//  OnboardingPageModel.swift
//  XOArena
//

import Foundation

enum OnboardingVisualKind: Sendable {
    case eightBoardReveal
    case activeBoardRotation
    case timeEconomy
    case clockSurvival
}

struct OnboardingPageModel: Identifiable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
    let description: String
    let visual: OnboardingVisualKind

    static let pages: [OnboardingPageModel] = [
        OnboardingPageModel(
            id: 0,
            title: "Welcome to XOArena",
            subtitle: "8 boards. One clock battle.",
            description: "Play Tic-Tac-Toe across multiple boards at once.",
            visual: .eightBoardReveal
        ),
        OnboardingPageModel(
            id: 1,
            title: "Follow the Active Board",
            subtitle: "Your turn moves from board to board.",
            description: "Make a move. The arena advances. Keep track of every board.",
            visual: .activeBoardRotation
        ),
        OnboardingPageModel(
            id: 2,
            title: "Win Time",
            subtitle: "Boards control the clock.",
            description: "Winning boards gives you more time and puts pressure on your opponent.",
            visual: .timeEconomy
        ),
        OnboardingPageModel(
            id: 3,
            title: "Survive the Clock",
            subtitle: "Board count is not the final score.",
            description: "When your timer reaches 0:00, you lose. Keep playing until the last second.",
            visual: .clockSurvival
        ),
    ]
}
