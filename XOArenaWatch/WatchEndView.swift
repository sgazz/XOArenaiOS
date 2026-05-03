//
//  WatchEndView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchEndView: View {
    let summary: WatchGameCoordinator.WatchEndSummary
    let onPlayAgain: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.headline)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchColors.ink)

                VStack(alignment: .leading, spacing: 2) {
                    Text("You \(summary.humanScore)")
                    Text("AI \(summary.aiScore)")
                    Text(summary.duration.title)
                }
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(WatchColors.inkMuted)

                Button {
                    onPlayAgain()
                } label: {
                    Text("Play Again")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchColors.accent)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(WatchColors.paper.ignoresSafeArea())
    }
}
