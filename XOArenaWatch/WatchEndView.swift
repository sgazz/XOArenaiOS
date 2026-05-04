//
//  WatchEndView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchEndView: View {
    @ObservedObject var coordinator: WatchGameCoordinator
    let summary: WatchGameCoordinator.WatchEndSummary
    let onPlayAgain: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var revealed = false
    @State private var revealWorkItem: DispatchWorkItem?

    private var headlineTint: Color {
        if summary.humanScore > summary.aiScore {
            WatchQuietTheme.ColorToken.win
        } else if summary.aiScore > summary.humanScore {
            WatchQuietTheme.ColorToken.lose
        } else {
            WatchQuietTheme.ColorToken.draw
        }
    }

    var body: some View {
        GeometryReader { geo in
            let m = WatchLayoutMetrics(size: geo.size)

            /// No **`ScrollView`** here: implicit Digital Crown scroll + **`GeometryReader`** + opacity animation caused **Crown Sequencer** / detent warnings on device.
            VStack(spacing: m.endVStackSpacing) {
                Spacer(minLength: 0)
                Text(summary.headline)
                    .font(.system(size: m.endTitleFont, weight: .semibold))
                    .foregroundStyle(headlineTint)
                    .multilineTextAlignment(.center)
                    .lineLimit(m.isSmall ? 2 : 3)
                    .minimumScaleFactor(0.92)
                    .frame(maxWidth: .infinity)

                HStack(alignment: .firstTextBaseline, spacing: m.endScoreRowHSpacing) {
                    Text("\(summary.humanScore) : \(summary.aiScore)")
                        .font(.system(size: m.endScoreFont, weight: .semibold))
                        .foregroundStyle(WatchQuietTheme.ColorToken.textMain)
                        .monospacedDigit()

                    Text(summary.endDurationRowSubtitle ?? summary.duration.title)
                        .font(.system(size: m.endDurationFont, weight: .medium))
                        .foregroundStyle(WatchQuietTheme.ColorToken.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                }
                .frame(maxWidth: .infinity)

                Button {
                    onPlayAgain()
                } label: {
                    Text("Play Again")
                        .font(.system(size: m.startButtonFontSize, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, m.playAgainVerticalPadding)
                        .background(
                            Capsule(style: .continuous)
                                .fill(WatchQuietTheme.ColorToken.primary)
                        )
                }
                .buttonStyle(WatchQuietCapsulePressStyle())
                .disabled(!coordinator.inputEnabled)
                .padding(.top, m.isSmall ? 2 : 4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, m.endHorizontalPadding)
            .padding(.vertical, m.endVerticalPadding)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .opacity(revealed ? 1 : 0)
            .animation(.easeOut(duration: 0.1), value: revealed)
        }
        .background(WatchQuietTheme.ColorToken.background.ignoresSafeArea())
        .onAppear {
            print("[XOArenaWatch] VIEW_APPEAR WatchEndView")
            print("[XOArenaWatch] CROWN_REMOVED context=WatchEndView_noScrollView")
            revealWorkItem?.cancel()
            revealed = false
            let humanAhead = summary.humanScore > summary.aiScore
            let isEven = summary.humanScore == summary.aiScore
            let work = DispatchWorkItem {
                revealed = true
                WatchHaptics.matchOutcome(isHumanAhead: humanAhead, isTie: isEven)
            }
            revealWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + WatchFeelTiming.endRevealDelaySeconds, execute: work)
        }
        .onDisappear {
            print("[XOArenaWatch] VIEW_DISAPPEAR WatchEndView")
            revealWorkItem?.cancel()
            revealWorkItem = nil
            print("[XOArenaWatch] VIEW_DISAPPEAR_CANCEL_NAV_TASKS context=WatchEndView_revealTimer")
            if scenePhase != .active {
                coordinator.shutdownForBackground()
            }
        }
    }
}
