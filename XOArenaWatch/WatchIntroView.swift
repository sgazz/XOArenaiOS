//
//  WatchIntroView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchIntroView: View {
    @ObservedObject var coordinator: WatchGameCoordinator

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var iconOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.94
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 6
    @State private var subtitleOpacity: Double = 0
    @State private var iconIdlePulse: CGFloat = 1.0
    @State private var tapSquashScale: CGFloat = 1.0
    @State private var introSequenceStarted = false
    /// Bounded idle breathing — **never** **`repeatForever`** (would keep Core Animation churn and hurt display sleep).
    @State private var idlePulseTask: Task<Void, Never>?
    @State private var tapAdvanceWorkItem: DispatchWorkItem?

    var body: some View {
        GeometryReader { geo in
            let m = WatchLayoutMetrics(size: geo.size)

            ZStack {
                WatchQuietTheme.ColorToken.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Image("XOArenaLogo")
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: m.introIconSize, height: m.introIconSize)
                        .scaleEffect(iconScale * iconIdlePulse * tapSquashScale)
                        .opacity(iconOpacity)
                        .clipShape(RoundedRectangle(cornerRadius: m.introIconCornerRadius, style: .continuous))

                    Spacer().frame(height: m.introIconTitleGap)

                    Text("XOArena")
                        .font(.system(size: m.introTitleSize, weight: .semibold))
                        .foregroundStyle(WatchQuietTheme.ColorToken.textMain)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)
                        .scaleEffect(tapSquashScale)

                    Spacer().frame(height: m.introTitleSubtitleGap)

                    Text("Tap to start")
                        .font(.system(size: m.introSubtitleSize, weight: .regular))
                        .foregroundStyle(WatchQuietTheme.ColorToken.textSoft)
                        .opacity(subtitleOpacity)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: handleTap)
        .task(id: introSequenceStarted) {
            guard introSequenceStarted else { return }
            await runIntroSequence()
        }
        .onAppear {
            print("[XOArenaWatch] VIEW_APPEAR WatchIntroView")
            if introSequenceStarted { return }
            introSequenceStarted = true
        }
        .onDisappear {
            print("[XOArenaWatch] VIEW_DISAPPEAR WatchIntroView")
            tapAdvanceWorkItem?.cancel()
            tapAdvanceWorkItem = nil
            print("[XOArenaWatch] VIEW_DISAPPEAR_CANCEL_NAV_TASKS context=WatchIntroView_tapAndPulse")
            stopIdlePulse()
            if scenePhase != .active {
                coordinator.shutdownForBackground()
            }
        }
        .onChange(of: scenePhase) { _, new in
            if new == .active {
                reconcileIdlePulseAfterSequence()
            } else {
                stopIdlePulse()
            }
        }
    }

    private func reconcileIdlePulseAfterSequence() {
        guard iconOpacity >= 1, subtitleOpacity >= 1 else {
            stopIdlePulse()
            return
        }
        guard scenePhase == .active else {
            stopIdlePulse()
            return
        }
        guard !coordinator.suspendedForBackground else {
            stopIdlePulse()
            return
        }
        guard !accessibilityReduceMotion else {
            stopIdlePulse()
            return
        }
        startBoundedIdlePulse()
    }

    private func invalidateIdlePulseTaskOnly() {
        idlePulseTask?.cancel()
        idlePulseTask = nil
    }

    private func stopIdlePulse() {
        invalidateIdlePulseTaskOnly()
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            iconIdlePulse = 1.0
        }
    }

    private func startBoundedIdlePulse() {
        invalidateIdlePulseTaskOnly()
        iconIdlePulse = 1.0
        idlePulseTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled, scenePhase == .active, !coordinator.suspendedForBackground else { break }
                withAnimation(.easeInOut(duration: 2.2)) {
                    iconIdlePulse = 1.015
                }
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled, scenePhase == .active, !coordinator.suspendedForBackground else { break }
                withAnimation(.easeInOut(duration: 2.2)) {
                    iconIdlePulse = 1.0
                }
            }
        }
    }

    private func handleTap() {
        WatchHaptics.tapLight()
        tapAdvanceWorkItem?.cancel()
        stopIdlePulse()
        if accessibilityReduceMotion {
            coordinator.tapIntroAdvance()
            return
        }
        withAnimation(.easeOut(duration: 0.12)) {
            tapSquashScale = 0.98
        }
        let work = DispatchWorkItem {
            coordinator.tapIntroAdvance()
            tapSquashScale = 1.0
        }
        tapAdvanceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    @MainActor
    private func runIntroSequence() async {
        if accessibilityReduceMotion {
            iconOpacity = 1
            iconScale = 1
            titleOpacity = 1
            titleOffset = 0
            subtitleOpacity = 1
            return
        }

        withAnimation(.easeOut(duration: 0.45)) {
            iconOpacity = 1
            iconScale = 1
        }

        try? await Task.sleep(for: .seconds(0.12))
        guard !Task.isCancelled, !coordinator.suspendedForBackground else { return }

        withAnimation(.easeOut(duration: 0.35)) {
            titleOpacity = 1
            titleOffset = 0
        }

        try? await Task.sleep(for: .seconds(0.22))
        guard !Task.isCancelled, !coordinator.suspendedForBackground else { return }

        withAnimation(.easeOut(duration: 0.30)) {
            subtitleOpacity = 1
        }

        try? await Task.sleep(for: .seconds(0.30))
        guard !Task.isCancelled, !coordinator.suspendedForBackground else { return }

        reconcileIdlePulseAfterSequence()
    }
}
