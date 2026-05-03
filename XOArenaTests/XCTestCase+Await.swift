//
//  XCTestCase+Await.swift
//  XOArenaTests
//

import XCTest

extension XCTestCase {
    @MainActor
    func waitUntil(
        _ message: String = "condition",
        timeoutNs: UInt64 = 5_000_000_000,
        pollNs: UInt64 = 15_000_000,
        _ predicate: @escaping () -> Bool
    ) async {
        let start = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - start < timeoutNs {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: pollNs)
            await Task.yield()
        }
        XCTFail("Timeout waiting for \(message)")
    }
}
