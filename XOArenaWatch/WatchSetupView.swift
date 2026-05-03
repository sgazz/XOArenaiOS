//
//  WatchSetupView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchSetupView: View {
    @Bindable var coordinator: WatchGameCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                pillRow(
                    title: "You play",
                    options: PlayerSymbolChoice.allCases,
                    selection: $coordinator.setupSymbol
                ) { $0.displayLetter }
                pillRow(
                    title: "Order",
                    options: FirstMoverChoice.allCases,
                    selection: $coordinator.setupFirst
                ) { $0 == .player ? "1st" : "2nd" }
                pillRow(
                    title: "Time",
                    options: GameDuration.allCases,
                    selection: $coordinator.setupDuration
                ) { $0.title }

                Button {
                    coordinator.beginMatchFromSetup()
                } label: {
                    Text("Start")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchColors.accent)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .background(WatchColors.paper.ignoresSafeArea())
    }

    private func pillRow<T: Hashable>(
        title: String,
        options: [T],
        selection: Binding<T>,
        label: @escaping (T) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(WatchColors.inkMuted)
            HStack(spacing: 4) {
                ForEach(options, id: \.self) { opt in
                    let on = selection.wrappedValue == opt
                    Button {
                        selection.wrappedValue = opt
                    } label: {
                        Text(label(opt))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(on ? WatchColors.accent.opacity(0.35) : WatchColors.cell)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(WatchColors.border, lineWidth: on ? 0 : 1)
                    )
                }
            }
        }
    }
}
