//
//  OnboardingStorageTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class OnboardingStorageTests: XCTestCase {
    private let key = OnboardingStorage.completedKey

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func test_markCompleted_persistsFlag() {
        XCTAssertFalse(OnboardingStorage.hasCompleted)
        OnboardingStorage.markCompleted()
        XCTAssertTrue(OnboardingStorage.hasCompleted)
    }
}
