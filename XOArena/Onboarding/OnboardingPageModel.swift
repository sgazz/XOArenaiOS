//
//  OnboardingPageModel.swift
//  XOArena
//

import Foundation

enum OnboardingVisualKind: Sendable {
    case eightBoardReveal
    case activeBoardRotation
    case winAndScore
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
            subtitle: "8 boards. One timer. Endless decisions.",
            description: "Play Tic-Tac-Toe across multiple boards at the same time.",
            visual: .eightBoardReveal
        ),
        OnboardingPageModel(
            id: 1,
            title: "Follow the Active Board",
            subtitle: "Your turn moves across the arena.",
            description: "After every move, play continues on the next board.",
            visual: .activeBoardRotation
        ),
        OnboardingPageModel(
            id: 2,
            title: "Survive the Clock",
            subtitle: "Gain time. Outlast your opponent.",
            description: "Win boards to gain time. The match is won by the player whose clock survives. When your timer reaches 0:00, you lose.",
            visual: .winAndScore
        ),
    ]
}
