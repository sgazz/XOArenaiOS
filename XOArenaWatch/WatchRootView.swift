//
//  WatchRootView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchRootView: View {
    @StateObject private var coordinator = WatchGameCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch coordinator.route {
            case .intro:
                WatchIntroView(coordinator: coordinator)
            case .setup:
                WatchSetupView(coordinator: coordinator)
            case .game:
                WatchGameView(coordinator: coordinator)
            case .end(let summary):
                WatchEndView(coordinator: coordinator, summary: summary) {
                    coordinator.playAgain()
                }
            }
        }
        .onAppear {
            print("[XOArenaWatch] VIEW_APPEAR WatchRootView")
        }
        .onDisappear {
            print("[XOArenaWatch] VIEW_DISAPPEAR WatchRootView")
            coordinator.shutdownForBackground()
        }
        .onChange(of: scenePhase) { _, newPhase in
            let label: String = {
                switch newPhase {
                case .active: return "active"
                case .inactive: return "inactive"
                case .background: return "background"
                @unknown default: return "unknown"
                }
            }()
            print("[XOArenaWatch] SCENE_PHASE \(label)")
            switch newPhase {
            case .active:
                coordinator.resumeFromForegroundIfNeeded()
            case .inactive, .background:
                coordinator.shutdownForBackground()
            @unknown default:
                coordinator.shutdownForBackground()
            }
        }
    }
}
