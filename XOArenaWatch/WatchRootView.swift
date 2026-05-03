//
//  WatchRootView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchRootView: View {
    @StateObject private var coordinator = WatchGameCoordinator()

    var body: some View {
        Group {
            switch coordinator.route {
            case .intro:
                WatchIntroView { coordinator.tapIntroAdvance() }
            case .setup:
                WatchSetupView(coordinator: coordinator)
            case .game:
                WatchGameView(coordinator: coordinator)
            case .end(let summary):
                WatchEndView(summary: summary) {
                    coordinator.playAgain()
                }
            }
        }
    }
}
