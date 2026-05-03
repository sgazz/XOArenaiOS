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
                compactMatchHeroBar
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .padding(.bottom, 3)

                if coordinator.showLowTimeHint {
                    Capsule()
                        .fill(WatchColors.accent.opacity(0.28))
                        .frame(width: 28, height: 2)
                        .padding(.bottom, 2)
                }

                ZStack {
                    WatchBoardView(
                        cells: coordinator.boardRenderState.cells,
                        phase: coordinator.boardRenderState.phase,
                        locked: coordinator.isAIThinking
                    ) { idx in
                        coordinator.cellTapped(cellIndex: idx)
                    }
                    .id(coordinator.boardRenderState.id)
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
                .animation(.easeInOut(duration: 0.22), value: coordinator.boardRenderState.renderVersion)
                .animation(.easeOut(duration: 0.15), value: coordinator.boardFeedback)
            }
        }
        .onAppear { coordinator.onGameAppear() }
        .onDisappear { coordinator.onGameDisappear() }
    }

    private var compactMatchHeroBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(coordinator.remainingTimeText)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(WatchColors.ink)

            Spacer(minLength: 2)

            Text(coordinator.scoreText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(WatchColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time \(coordinator.remainingTimeText), score \(coordinator.scoreText)")
    }

    private func feedbackText(_ fb: WatchGameCoordinator.BoardFeedback) -> String {
        switch fb {
        case .playerPlusOne: return "+1"
        case .aiPlusOne: return "AI +1"
        case .draw: return "Draw"
        }
    }
}
