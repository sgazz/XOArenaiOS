//
//  OnboardingStorage.swift
//  XOArena
//

import Foundation

enum OnboardingStorage {
    static let completedKey = "hasCompletedOnboarding"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }
}
