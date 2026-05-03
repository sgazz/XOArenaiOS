//
//  WatchIntroView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchIntroView: View {
    let onTap: () -> Void

    var body: some View {
        ZStack {
            WatchColors.paper.ignoresSafeArea()
            VStack(spacing: 10) {
                Image("XOArenaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("XOArena")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchColors.ink)
                Text("Tap to start")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(WatchColors.inkMuted)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
