//
//  SplashExperienceStorageTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class SplashExperienceStorageTests: XCTestCase {
    private let presentedKey = SplashExperienceStorage.hasPresentedOnceKey
    private let settingKey = SplashExperienceStorage.showSettingKey
    private let legacyKey = "showIntro"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: presentedKey)
        UserDefaults.standard.removeObject(forKey: settingKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        super.tearDown()
    }

    func test_first_launch_always_presents() {
        XCTAssertTrue(SplashExperienceStorage.shouldPresentOnLaunch())
    }

    func test_after_first_present_requires_setting() {
        SplashExperienceStorage.markPresented()
        XCTAssertFalse(SplashExperienceStorage.shouldPresentOnLaunch())

        UserDefaults.standard.set(true, forKey: settingKey)
        XCTAssertTrue(SplashExperienceStorage.shouldPresentOnLaunch())
    }
}
