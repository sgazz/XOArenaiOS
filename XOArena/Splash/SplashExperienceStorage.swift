//
//  SplashExperienceStorage.swift
//  XOArena
//

import Foundation

enum SplashExperienceStorage {
    static let showSettingKey = "showSplashExperience"
    static let hasPresentedOnceKey = "splashHasPresentedOnce"
    private static let legacyShowIntroKey = "showIntro"

    /// First launch always shows splash; later launches only when the user enables the setting.
    static func shouldPresentOnLaunch() -> Bool {
        migrateLegacyShowIntroIfNeeded()
        if !UserDefaults.standard.bool(forKey: hasPresentedOnceKey) {
            return true
        }
        return UserDefaults.standard.bool(forKey: showSettingKey)
    }

    static func markPresented() {
        UserDefaults.standard.set(true, forKey: hasPresentedOnceKey)
    }

    private static func migrateLegacyShowIntroIfNeeded() {
        guard UserDefaults.standard.object(forKey: legacyShowIntroKey) != nil else { return }
        guard UserDefaults.standard.object(forKey: showSettingKey) == nil else { return }
        UserDefaults.standard.set(
            UserDefaults.standard.bool(forKey: legacyShowIntroKey),
            forKey: showSettingKey
        )
    }
}
