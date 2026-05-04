//
//  WatchGameView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchGameView: View {
    @ObservedObject var coordinator: WatchGameCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @State private var heroTimePulse: CGFloat = 1
    @State private var heroTimePulseResetWork: DispatchWorkItem?

    private var urgentTimePulse: Bool {
        coordinator.setupDuration != .noTime
            && coordinator.matchSecondsRemaining < 10
            && coordinator.matchSecondsRemaining > 0
    }

    var body: some View {
        GeometryReader { screen in
            let m = WatchLayoutMetrics(size: screen.size)
            ZStack {
                WatchQuietTheme.ColorToken.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    compactMatchHeroBar(metrics: m)
                        .padding(.horizontal, m.heroHorizontalPadding)
                        .padding(.top, m.heroBarTopPadding)
                        .padding(.bottom, m.heroBarBottomPadding)
                        .onChange(of: coordinator.matchSecondsRemaining) { _, newVal in
                            guard coordinator.setupDuration != .noTime else {
                                heroTimePulse = 1
                                return
                            }
                            guard newVal < 10, newVal > 0 else {
                                heroTimePulse = 1
                                return
                            }
                            heroTimePulseResetWork?.cancel()
                            withAnimation(.easeInOut(duration: 0.28)) {
                                heroTimePulse = 1.03
                            }
                            let work = DispatchWorkItem {
                                withAnimation(.easeInOut(duration: 0.32)) {
                                    heroTimePulse = 1
                                }
                            }
                            heroTimePulseResetWork = work
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.52, execute: work)
                        }

                    ZStack {
                        boardGameplayArea(metrics: m)

                        if let fb = coordinator.boardFeedback {
                            Text(feedbackLabel(fb))
                                .font(.system(size: m.boardFeedbackFontSize, weight: .medium))
                                .foregroundStyle(feedbackForeground(fb))
                                .padding(.horizontal, m.isSmall ? 8 : 10)
                                .padding(.vertical, m.isSmall ? 4 : 5)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(WatchQuietTheme.ColorToken.surface.opacity(0.94))
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(WatchQuietTheme.ColorToken.border.opacity(0.7), lineWidth: 0.5)
                                        )
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            print("[XOArenaWatch] VIEW_APPEAR WatchGameView")
            coordinator.onGameAppear()
        }
        .onDisappear {
            print("[XOArenaWatch] VIEW_DISAPPEAR WatchGameView")
            heroTimePulseResetWork?.cancel()
            heroTimePulseResetWork = nil
            print("[XOArenaWatch] VIEW_DISAPPEAR_CANCEL_NAV_TASKS context=WatchGameView_heroPulse")
            coordinator.onGameDisappear()
            if scenePhase != .active {
                coordinator.shutdownForBackground()
            }
        }
    }

    private var boardInputLocked: Bool {
        coordinator.isAIThinking || coordinator.boardTransitionPhase != .idle
    }

    private var boardAllowsInput: Bool {
        coordinator.boardTransitionPhase == .idle && coordinator.visibleBoardAllowsMoves
    }

    @ViewBuilder
    private func boardGameplayArea(metrics m: WatchLayoutMetrics) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let side = min(w, h)
            Group {
                if coordinator.boardTransitionPhase == .scrolling {
                    verticalScrollBoardStack(side: side, metrics: m)
                } else {
                    WatchBoardView(
                        cells: coordinator.visibleBoardCells,
                        boardID: coordinator.visibleBoardID,
                        locked: boardInputLocked,
                        allowsInput: boardAllowsInput,
                        highlightIndices: coordinator.previewWinningHighlightIndices,
                        isDrawPreviewSoft: coordinator.isBoardPreviewingDraw,
                        drawEffectsEnabled: coordinator.allowsLiveBoardEffects,
                        aiFadeCellIndex: coordinator.boardTransitionPhase == .idle ? coordinator.feelAIMarkFadeCell : nil,
                        boardGap: m.boardGap,
                        cellCornerRadius: m.cellCornerRadius,
                        onTap: { coordinator.handleCellTap($0) }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func verticalScrollBoardStack(side: CGFloat, metrics m: WatchLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            WatchBoardView(
                cells: coordinator.visibleBoardCells,
                boardID: coordinator.visibleBoardID,
                locked: true,
                allowsInput: false,
                highlightIndices: coordinator.previewWinningHighlightIndices,
                isDrawPreviewSoft: coordinator.isBoardPreviewingDraw,
                drawEffectsEnabled: coordinator.allowsLiveBoardEffects,
                aiFadeCellIndex: nil,
                boardGap: m.boardGap,
                cellCornerRadius: m.cellCornerRadius,
                onTap: { coordinator.handleCellTap($0) }
            )
            .frame(width: side, height: side)

            WatchBoardView(
                cells: coordinator.incomingBoardCells,
                boardID: coordinator.incomingBoardID,
                locked: true,
                allowsInput: false,
                highlightIndices: nil,
                isDrawPreviewSoft: false,
                drawEffectsEnabled: coordinator.allowsLiveBoardEffects,
                aiFadeCellIndex: nil,
                boardGap: m.boardGap,
                cellCornerRadius: m.cellCornerRadius,
                onTap: { coordinator.handleCellTap($0) }
            )
            .frame(width: side, height: side)
        }
        .frame(width: side, height: side * 2, alignment: .top)
        .offset(y: -coordinator.verticalBoardScrollFraction * side)
        .frame(width: side, height: side, alignment: .top)
        .clipped()
    }

    private func heroBoardTag(metrics m: WatchLayoutMetrics) -> some View {
        Text(coordinator.heroBoardLabelCompact)
            .font(.system(size: m.heroBoardLabelFont, weight: .bold))
            .foregroundStyle(WatchQuietTheme.ColorToken.textMain)
            .lineLimit(1)
            .minimumScaleFactor(m.isSmall ? 0.78 : 0.85)
    }

    private func compactMatchHeroBar(metrics m: WatchLayoutMetrics) -> some View {
        let scoreScale: CGFloat = m.isSmall ? 0.78 : 0.82

        return Group {
            if coordinator.isNoTimeMode {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(coordinator.remainingTimeText)
                        .font(.system(size: m.heroFont, weight: .semibold))
                        .foregroundStyle(WatchQuietTheme.ColorToken.textMain)

                    Spacer(minLength: m.heroSpacerNoTime)

                    heroBoardTag(metrics: m)

                    Spacer(minLength: m.heroSpacerNoTime)

                    Text(coordinator.compactHeroScoreText)
                        .font(.system(size: m.heroFont, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(WatchQuietTheme.ColorToken.textSoft)
                        .minimumScaleFactor(scoreScale)
                        .lineLimit(1)

                    Spacer(minLength: m.heroCancelTrailing)

                    Button {
                        WatchHaptics.tapLight()
                        coordinator.endNoTimeMatch()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: m.xmarkSize, weight: .medium))
                            .foregroundStyle(WatchQuietTheme.ColorToken.textSoft.opacity(0.65))
                            .frame(minWidth: m.xmarkTapMin, minHeight: m.xmarkTapMin)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("End match")
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "No time limit, \(coordinator.heroBoardLabelCompact), score \(coordinator.compactHeroScoreText). End match on the right."
                )
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(coordinator.remainingTimeText)
                        .font(.system(size: m.heroFont, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(WatchQuietTheme.ColorToken.textMain)
                        .scaleEffect(urgentTimePulse ? heroTimePulse : 1)

                    Spacer(minLength: m.heroSpacerStandard)

                    heroBoardTag(metrics: m)

                    Spacer(minLength: m.heroSpacerStandard)

                    Text(coordinator.compactHeroScoreText)
                        .font(.system(size: m.heroFont, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(WatchQuietTheme.ColorToken.textSoft)
                        .minimumScaleFactor(scoreScale)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Time \(coordinator.remainingTimeText), \(coordinator.heroBoardLabelCompact), score \(coordinator.compactHeroScoreText)"
                )
            }
        }
    }

    private func feedbackLabel(_ fb: WatchGameCoordinator.BoardFeedback) -> String {
        switch fb {
        case .playerPlusOne, .aiPlusOne: "+1"
        case .draw: "Draw"
        }
    }

    private func feedbackForeground(_ fb: WatchGameCoordinator.BoardFeedback) -> Color {
        switch fb {
        case .playerPlusOne: WatchQuietTheme.ColorToken.win
        case .aiPlusOne: WatchQuietTheme.ColorToken.lose
        case .draw: WatchQuietTheme.ColorToken.draw
        }
    }
}
