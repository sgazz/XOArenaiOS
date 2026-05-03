//
//  WatchGameView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchGameView: View {
    @ObservedObject var coordinator: WatchGameCoordinator

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

                // TEMP diagnostic: must match engine active board (1-based).
                Text("B\(coordinator.visibleBoardIndex + 1)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WatchColors.accent)
                    .padding(.bottom, 2)

                ZStack {
                    WatchBoardView(
                        cells: coordinator.visibleBoardCells,
                        boardID: coordinator.visibleBoardID,
                        locked: coordinator.isAIThinking || coordinator.isBoardPreviewing,
                        allowsInput: coordinator.visibleBoardAllowsMoves,
                        onTap: { coordinator.handleCellTap($0) }
                    )

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
                    }
                }
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
