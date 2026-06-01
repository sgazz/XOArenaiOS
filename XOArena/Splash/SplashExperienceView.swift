//
//  SplashExperienceView.swift
//  XOArena
//

import SwiftUI
import UIKit

// MARK: - Layout

private struct SplashLayoutMetrics: Sendable {
    var titleBase: CGFloat
    var bodyBase: CGFloat
    var taglineBase: CGFloat

    static func resolve(bounds: CGSize, dynamicTypeSize: DynamicTypeSize) -> SplashLayoutMetrics {
        let short = min(bounds.width, bounds.height)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        var title: CGFloat = isPad ? 42 : (short >= 390 ? 38 : 34)
        var body: CGFloat = isPad ? 22 : (short >= 390 ? 20 : 18)
        var tagline: CGFloat = isPad ? 19 : 17
        switch dynamicTypeSize {
        case .xLarge, .xxLarge, .xxxLarge:
            title += 1.5
            body += 1
            tagline += 0.75
        default:
            break
        }
        return SplashLayoutMetrics(titleBase: title, bodyBase: body, taglineBase: tagline)
    }
}

// MARK: - View

/// Calm launch sequence (~4 s); tap to skip. Replaces legacy **`IntroView`**.
struct SplashExperienceView: View {
    @Environment(\.sgThemeMode) private var themeMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let onFinish: () -> Void

    @State private var phase: Int = 0
    @State private var identityOpacity: Double = 0
    @State private var identityScale: CGFloat = 0.98
    @State private var copyOpacity: Double = 0
    @State private var ambientStrength: Double = 0
    @State private var timerStrength: Double = 1
    @State private var isExiting = false
    @State private var hasFinishedSplash = false
    @State private var sequenceTask: Task<Void, Never>?
    @State private var exitTask: Task<Void, Never>?
    @State private var failsafeTask: Task<Void, Never>?

    private var titleInk: Color {
        themeMode == .light ? SGColors.introSerifTitleLight : SGColors.introSerifTitleDark
    }

    private var bodyInk: Color {
        SGEngravedTextTheme.defaultInk(for: themeMode).opacity(themeMode == .light ? 0.9 : 0.92)
    }

    private var secondaryInk: Color {
        SGColors.introTextSecondary.opacity(themeMode == .light ? 0.62 : 0.68)
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = SplashLayoutMetrics.resolve(bounds: geo.size, dynamicTypeSize: dynamicTypeSize)
            ZStack {
                splashBackground
                MainMenuAmbientBackground(strength: ambientStrength, timerStrength: timerStrength)
                IntroPaperGrainOverlay(opacityMultiplier: 0.35)

                VStack(spacing: 0) {
                    Spacer(minLength: SGSpacing.lg)
                    copyStack(metrics: metrics)
                        .padding(.horizontal, SGSpacing.xl + SGSpacing.sm)
                    Spacer(minLength: SGSpacing.lg)
                }
                .opacity(isExiting ? 0 : 1)
                .scaleEffect(isExiting ? 1.01 : 1, anchor: .center)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture { finishSplash(immediate: true) }
        }
        .ignoresSafeArea()
        .onAppear { beginSequence() }
        .onDisappear { cancelSplashTasks() }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.default) { finishSplash(immediate: true) }
        .accessibilityHint("Double tap to skip the launch experience.")
    }

    // MARK: - Copy

    @ViewBuilder
    private func copyStack(metrics: SplashLayoutMetrics) -> some View {
        ZStack {
            identityCopy(metrics: metrics)
                .opacity(phase == 0 ? copyOpacity * identityOpacity : 0)
                .scaleEffect(phase == 0 ? identityScale : 1, anchor: .center)

            messageCopy(
                "Play across\neight boards at once.",
                metrics: metrics,
                visible: phase == 1
            )

            messageCopy(
                "Time is your resource.",
                metrics: metrics,
                visible: phase == 2
            )

            messageCopy(
                "Win boards.\nGain time.\nStay alive.",
                metrics: metrics,
                visible: phase == 3
            )
        }
        .animation(hasFinishedSplash ? nil : crossfadeAnimation, value: phase)
        .animation(hasFinishedSplash ? nil : identityAnimation, value: identityOpacity)
        .animation(hasFinishedSplash ? nil : identityAnimation, value: identityScale)
    }

    private func identityCopy(metrics: SplashLayoutMetrics) -> some View {
        VStack(spacing: SGSpacing.md + 4) {
            Text("XOArena")
                .font(serifTitleFont(base: metrics.titleBase))
                .foregroundStyle(titleInk)
                .tracking(SGTypography.titleTracking + 3)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .sgRaisedText(intensity: .medium, color: titleInk)

            VStack(spacing: 4) {
                Text("Eight boards.")
                Text("One focus.")
            }
            .font(roundedBodyFont(base: metrics.taglineBase))
            .foregroundStyle(secondaryInk)
            .tracking(SGTypography.subtitleTracking)
            .multilineTextAlignment(.center)
            .sgEngravedText(intensity: .low, color: secondaryInk)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("XOArena. Eight boards. One focus.")
    }

    private func messageCopy(_ text: String, metrics: SplashLayoutMetrics, visible: Bool) -> some View {
        Text(text)
            .font(roundedBodyFont(base: metrics.bodyBase))
            .fontWeight(.medium)
            .foregroundStyle(bodyInk)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .minimumScaleFactor(0.8)
            .opacity(visible ? copyOpacity : 0)
            .accessibilityHidden(!visible)
            .accessibilityLabel(text.replacingOccurrences(of: "\n", with: ". "))
    }

    // MARK: - Background

    private var splashBackground: some View {
        Group {
            if themeMode == .light {
                LinearGradient(
                    colors: [SGColors.introGradientTopLight, SGColors.introGradientBottomLight],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else if themeMode == .dark {
                LinearGradient(
                    colors: [SGColors.introGradientTopDark, SGColors.introGradientBottomDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [SGColors.neonGraphite, SGColors.neonGraphiteDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Sequence

    private func beginSequence() {
        cancelSplashTasks()
        resetSplashPresentationState()
        hasFinishedSplash = false
        armFailsafeTimeout()

        sequenceTask = Task { @MainActor in
            do {
                try await runSequence()
                finishSplash(immediate: false)
            } catch is CancellationError {
                return
            } catch {
                finishSplash(immediate: true)
            }
        }
    }

    private func resetSplashPresentationState() {
        phase = 0
        identityOpacity = 0
        identityScale = 0.98
        copyOpacity = 0
        ambientStrength = 0
        timerStrength = 1
        isExiting = false
    }

    private func runSequence() async throws {
        guard !hasFinishedSplash else { return }

        try await runBeat {
            withAnimation(identityAnimation) {
                identityOpacity = 1
                identityScale = 1
                copyOpacity = 1
            }
        }

        try await advanceToPhase(1) {
            withAnimation(ambientAnimation) { ambientStrength = 0.85 }
        }

        try await advanceToPhase(2) {
            withAnimation(ambientAnimation) {
                ambientStrength = 1
                timerStrength = 1.55
            }
        }

        try await advanceToPhase(3) {
            withAnimation(ambientAnimation) { timerStrength = 1.75 }
        }
    }

    private func runBeat(_ updates: () -> Void) async throws {
        try Task.checkCancellation()
        guard !hasFinishedSplash else { return }
        updates()
        try await Task.sleep(for: .seconds(SplashExperienceTimeline.beat))
    }

    private func advanceToPhase(_ next: Int, ambientUpdate: () -> Void) async throws {
        try Task.checkCancellation()
        guard !hasFinishedSplash else { return }
        ambientUpdate()
        withAnimation(crossfadeAnimation) {
            copyOpacity = 0
        }
        let pause = accessibilityReduceMotion
            ? SplashExperienceTimeline.crossfadePause * 0.55
            : SplashExperienceTimeline.crossfadePause
        try await Task.sleep(for: .seconds(pause))
        guard !hasFinishedSplash else { return }
        phase = next
        withAnimation(crossfadeAnimation) {
            copyOpacity = 1
        }
        try await Task.sleep(for: .seconds(SplashExperienceTimeline.beat))
    }

    /// Single exit path: automatic completion, tap-to-skip, failsafe, and stalled-sequence recovery.
    private func finishSplash(immediate: Bool) {
        guard SplashFinishGate.attemptFinish(alreadyFinished: &hasFinishedSplash) else { return }

        cancelSplashTasks()
        HapticService.lightImpact()
        SplashExperienceStorage.markPresented()

        if immediate {
            isExiting = false
            onFinish()
            return
        }

        withAnimation(exitAnimation) {
            isExiting = true
        }

        let fade = accessibilityReduceMotion
            ? SplashExperienceTimeline.exitFadeReducedMotion
            : SplashExperienceTimeline.exitFade

        exitTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(fade))
            } catch {
                return
            }
            guard hasFinishedSplash else { return }
            onFinish()
        }
    }

    private func armFailsafeTimeout() {
        failsafeTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(SplashExperienceTimeline.maximumDuration))
            } catch {
                return
            }
            finishSplash(immediate: true)
        }
    }

    private func cancelSplashTasks() {
        sequenceTask?.cancel()
        sequenceTask = nil
        exitTask?.cancel()
        exitTask = nil
        failsafeTask?.cancel()
        failsafeTask = nil
    }

    // MARK: - Fonts & motion

    private func serifTitleFont(base: CGFloat) -> Font {
        let size = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: base)
        return .system(size: size, weight: .medium, design: .serif)
    }

    private func roundedBodyFont(base: CGFloat) -> Font {
        let size = UIFontMetrics(forTextStyle: .title3).scaledValue(for: base)
        return .system(size: size, weight: .regular, design: .rounded)
    }

    private var identityAnimation: Animation {
        accessibilityReduceMotion
            ? .easeOut(duration: 0.35)
            : .easeOut(duration: 0.95)
    }

    private var crossfadeAnimation: Animation {
        accessibilityReduceMotion
            ? .easeInOut(duration: 0.28)
            : .easeInOut(duration: 0.92)
    }

    private var ambientAnimation: Animation {
        accessibilityReduceMotion
            ? .easeInOut(duration: 0.4)
            : .easeInOut(duration: 1.1)
    }

    private var exitAnimation: Animation {
        accessibilityReduceMotion
            ? .easeInOut(duration: 0.22)
            : .easeInOut(duration: 0.45)
    }
}
