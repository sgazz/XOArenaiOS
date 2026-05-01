//
//  MockGameTimerService.swift
//  XOArenaTests
//

import Foundation
@testable import XOArena

/// **`GameTimerService` test double** (callbacks match host semantics).
final class MockGameTimerService: GameTimerControlling {
    private var onTick: (@Sendable (Int) -> Void)?
    private var onFinished: (@Sendable () -> Void)?
    private(set) var startedSeconds: Int?
    private(set) var stopCount: Int = 0

    func start(
        seconds: Int,
        onTick: @escaping @Sendable (Int) -> Void,
        onFinished: @escaping @Sendable () -> Void
    ) {
        startedSeconds = seconds
        self.onTick = onTick
        self.onFinished = onFinished
    }

    func stop() {
        stopCount += 1
        onTick = nil
        onFinished = nil
    }

    func simulateTick(_ seconds: Int) {
        onTick?(seconds)
    }

    func simulateFinish() {
        onTick?(0)
        onFinished?()
    }
}
