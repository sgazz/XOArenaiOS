//
//  WatchGameView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchGameView: View {
    @Bindable var coordinator: WatchGameCoordinator

    var body: some View {
        ZStack {
            WatchColors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                if coordinator.showLowTimeHint {
                    Capsule()
                        .fill(WatchColors.accent.opacity(0.28))
                        .frame(width: 32, height: 3)
                        .padding(.top, 2)
                } else {
                    Color.clear.frame(height: 5)
                }

                ZStack {
                    WatchBoardView(
                        board: coordinator.boards[coordinator.activeBoardIndex],
                        locked: coordinator.isAIThinking
                    ) { idx in
                        coordinator.cellTapped(cellIndex: idx)
                    }
                    .id(coordinator.activeBoardIndex)
                    .transition(.opacity)

                    if let fb = coordinator.boardFeedback {
                        Text(feedbackText(fb))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(WatchColors.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(WatchColors.cell.opacity(0.92))
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: coordinator.activeBoardIndex)
                .animation(.easeOut(duration: 0.15), value: coordinator.boardFeedback)
            }
        }
        .onAppear { coordinator.onGameAppear() }
        .onDisappear { coordinator.onGameDisappear() }
    }

    private func feedbackText(_ fb: WatchGameCoordinator.BoardFeedback) -> String {
        switch fb {
        case .playerPlusOne: return "+1"
        case .aiPlusOne: return "AI +1"
        case .draw: return "Draw"
        }
    }
}
