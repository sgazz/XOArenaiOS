//
//  WatchSetupView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchSetupView: View {
    @ObservedObject var coordinator: WatchGameCoordinator

    private var isNoTimeSelected: Bool {
        coordinator.setupDuration == .noTime
    }

    var body: some View {
        GeometryReader { geo in
            let m = WatchLayoutMetrics(size: geo.size)

            Group {
                if m.isSmall {
                    /// Explicit size + root **`ScrollView`** reduces **Crown Sequencer "no view property"** / **`contentOffset`** churn vs a zero-phase **`GeometryReader`** parent.
                    ScrollView {
                        setupContent(metrics: m)
                    }
                    .scrollIndicators(.never)
                    .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    setupContent(metrics: m)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .background(WatchQuietTheme.ColorToken.background.ignoresSafeArea())
        }
    }

    private static let timedDurations: [GameDuration] = [.oneMinute, .threeMinutes, .fiveMinutes]

    @ViewBuilder
    private func setupContent(metrics m: WatchLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: m.setupSpacing) {
            pillRow(
                metrics: m,
                title: "You play",
                options: PlayerSymbolChoice.allCases,
                selection: $coordinator.setupSymbol
            ) { $0.displayLetter }
            pillRow(
                metrics: m,
                title: "Order",
                options: FirstMoverChoice.allCases,
                selection: $coordinator.setupFirst
            ) { $0 == .player ? "1st" : "2nd" }
            timeSelectionSection(metrics: m)

            Button {
                coordinator.beginMatchFromSetup()
            } label: {
                Text("Start")
                    .font(.system(size: m.startButtonFontSize, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, m.startButtonVerticalPadding)
                    .background(
                        Capsule(style: .continuous)
                            .fill(WatchQuietTheme.ColorToken.primary)
                    )
            }
            .buttonStyle(WatchQuietCapsulePressStyle())
            .disabled(!coordinator.inputEnabled)
            .padding(.top, m.isSmall ? 2 : 4)
            .padding(.bottom, m.isLarge ? 4 : 2)
        }
        .padding(.horizontal, m.setupHorizontalPadding)
        .padding(.top, m.setupTopPadding)
        .padding(.bottom, m.setupBottomPadding)
    }

    private func timeSelectionSection(metrics m: WatchLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: m.setupSectionInnerSpacing) {
            Text("Time")
                .font(.system(size: m.setupHeaderFontSize, weight: .medium))
                .foregroundStyle(WatchQuietTheme.ColorToken.textSoft)

            HStack(spacing: m.setupTimePillsHSpacing) {
                ForEach(Self.timedDurations, id: \.self) { opt in
                    let on = coordinator.setupDuration == opt
                    Button {
                        coordinator.setupDuration = opt
                    } label: {
                        Text(opt.title)
                            .font(.system(size: m.setupPillFontSize, weight: .semibold))
                            .foregroundStyle(on ? Color.white : WatchQuietTheme.ColorToken.textSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, m.setupPillVerticalPadding)
                            .padding(.horizontal, m.isSmall ? 3 : 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(on ? WatchQuietTheme.ColorToken.primary : WatchQuietTheme.ColorToken.surface)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        WatchQuietTheme.ColorToken.border.opacity(on ? 0 : 1),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(WatchQuietCapsulePressStyle())
                }
            }

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Button {
                    coordinator.setupDuration = .noTime
                } label: {
                    Text("∞ No Time")
                        .font(.system(size: m.setupPillFontSize, weight: .semibold))
                        .foregroundStyle(isNoTimeSelected ? Color.white : WatchQuietTheme.ColorToken.textSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, m.setupPillVerticalPadding)
                        .padding(.horizontal, m.isSmall ? 6 : 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isNoTimeSelected ? WatchQuietTheme.ColorToken.primary : WatchQuietTheme.ColorToken.surface)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    WatchQuietTheme.ColorToken.border.opacity(isNoTimeSelected ? 0 : 1),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(WatchQuietCapsulePressStyle())
                Spacer(minLength: 0)
            }
        }
    }

    private func pillRow<T: Hashable>(
        metrics m: WatchLayoutMetrics,
        title: String,
        options: [T],
        selection: Binding<T>,
        label: @escaping (T) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: m.setupSectionInnerSpacing) {
            Text(title)
                .font(.system(size: m.setupHeaderFontSize, weight: .medium))
                .foregroundStyle(WatchQuietTheme.ColorToken.textSoft)
            HStack(spacing: m.setupTimePillsHSpacing) {
                ForEach(options, id: \.self) { opt in
                    let on = selection.wrappedValue == opt
                    Button {
                        selection.wrappedValue = opt
                    } label: {
                        Text(label(opt))
                            .font(.system(size: m.setupPillFontSize, weight: .semibold))
                            .foregroundStyle(on ? Color.white : WatchQuietTheme.ColorToken.textSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, m.setupPillVerticalPadding)
                            .padding(.horizontal, m.isSmall ? 3 : 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(on ? WatchQuietTheme.ColorToken.primary : WatchQuietTheme.ColorToken.surface)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        WatchQuietTheme.ColorToken.border.opacity(on ? 0 : 1),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(WatchQuietCapsulePressStyle())
                }
            }
        }
    }
}
