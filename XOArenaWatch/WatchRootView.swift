//
//  WatchRootView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchRootView: View {
    @State private var coordinator = WatchGameCoordinator()

    var body: some View {
        @Bindable var coordinator = coordinator
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
