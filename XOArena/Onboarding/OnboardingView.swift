//
//  OnboardingView.swift
//  XOArena
//

import SwiftUI

struct OnboardingView: View {
    enum PresentationMode {
        case firstLaunch
        case helpReplay
    }

    @Environment(\.sgThemeMode) private var themeMode

    let mode: PresentationMode
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private var pages: [OnboardingPageModel] { OnboardingPageModel.pages }
    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        ZStack {
            PaperBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, SGSpacing.md)
                    .padding(.top, SGSpacing.sm)

                TabView(selection: $pageIndex) {
                    ForEach(pages) { page in
                        OnboardingPage(model: page)
                            .tag(page.id)
                            .padding(.top, SGSpacing.md)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.28), value: pageIndex)

                OnboardingPageIndicator(pageCount: pages.count, currentIndex: pageIndex)
                    .padding(.top, SGSpacing.sm)

                navigationBar
                    .padding(.horizontal, SGSpacing.lg)
                    .padding(.top, SGSpacing.lg)
                    .padding(.bottom, SGSpacing.xl)
            }
        }
        .interactiveDismissDisabled(mode == .firstLaunch)
    }

    private var headerBar: some View {
        HStack {
            Spacer()
            Button {
                HapticService.lightImpact()
                completeAndDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(t.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close tutorial")
        }
    }

    @ViewBuilder
    private var navigationBar: some View {
        HStack {
            leadingNavButton
            Spacer()
            trailingNavButton
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var leadingNavButton: some View {
        switch pageIndex {
        case 0:
            Button("Skip") {
                HapticService.lightImpact()
                completeAndDismiss()
            }
            .font(SGTypography.body)
            .foregroundStyle(t.textSecondary)
        default:
            Button("Back") {
                HapticService.lightImpact()
                withAnimation(.easeInOut(duration: 0.26)) {
                    pageIndex -= 1
                }
            }
            .font(SGTypography.body)
            .foregroundStyle(t.textPrimary)
        }
    }

    @ViewBuilder
    private var trailingNavButton: some View {
        if pageIndex >= pages.count - 1 {
            Button {
                HapticService.mediumImpact()
                completeAndDismiss()
            } label: {
                Text("Start Playing")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(t.primaryButtonLabel)
                    .padding(.horizontal, SGSpacing.lg)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                            .fill(t.accent)
                    )
            }
            .buttonStyle(.plain)
        } else {
            Button("Next") {
                HapticService.lightImpact()
                withAnimation(.easeInOut(duration: 0.26)) {
                    pageIndex += 1
                }
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(t.accent)
        }
    }

    private func completeAndDismiss() {
        if mode == .firstLaunch {
            OnboardingStorage.markCompleted()
        }
        onFinish()
    }
}

#if DEBUG
#Preview("Onboarding — first launch") {
    OnboardingView(mode: .firstLaunch, onFinish: {})
        .environment(\.sgThemeMode, .light)
        .environmentObject(SGThemeManager())
}
#endif
