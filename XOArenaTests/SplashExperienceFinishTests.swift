//
//  SplashExperienceFinishTests.swift
//  XOArenaTests
//

import XCTest
@testable import XOArena

final class SplashFinishGateTests: XCTestCase {
    func test_attemptFinish_only_succeeds_once() {
        var finished = false
        XCTAssertTrue(SplashFinishGate.attemptFinish(alreadyFinished: &finished))
        XCTAssertTrue(finished)
        XCTAssertFalse(SplashFinishGate.attemptFinish(alreadyFinished: &finished))
    }

    func test_multiple_rapid_attempts_leave_single_finish() {
        var finished = false
        var successCount = 0
        for _ in 0 ..< 5 {
            if SplashFinishGate.attemptFinish(alreadyFinished: &finished) {
                successCount += 1
            }
        }
        XCTAssertEqual(successCount, 1)
    }
}

final class SplashExperienceTimelineTests: XCTestCase {
    func test_timeline_fits_within_maximum_duration() {
        let beats = SplashExperienceTimeline.beat * 4
        let crossfades = SplashExperienceTimeline.crossfadePause * 3
        XCTAssertLessThan(beats + crossfades, SplashExperienceTimeline.maximumDuration)
    }

    func test_failsafe_exceeds_nominal_sequence_length() {
        let nominal = SplashExperienceTimeline.beat * 4 + SplashExperienceTimeline.crossfadePause * 3
        XCTAssertGreaterThan(SplashExperienceTimeline.maximumDuration, nominal)
    }
}
