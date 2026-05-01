//
//  GameView.swift
//  XOArena
//

import SwiftUI

struct GameView: View {
    @Bindable var viewModel: GameViewModel
    @Environment(\.sgThemeMode) private var themeMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperBackgroundView()
                    .ignoresSafeArea()

                let showLearningStrip = viewModel.gameMode == .learning
                let metrics = layoutMetrics(
                    in: proxy,
                    showLearningStrip: showLearningStrip,
                    dynamicTypeBonus: learningStripReserveBonus(for: dynamicTypeSize)
                )

                VStack(spacing: metrics.contentSpacing) {
                    header(compact: metrics.compactHeader)
                        .frame(height: metrics.headerHeight, alignment: .top)

                    if showLearningStrip {
                        LearningModeStripView(
                            profile: viewModel.learningProfile,
                            tokens: t,
                            themeMode: themeMode,
                            compactVertical: metrics.compactLearningStripLayout
                        )
                    }

                    boardsGrid(metrics: metrics)
                        .frame(maxHeight: .infinity, alignment: .top)

                    if viewModel.isSessionComplete {
                        SessionCompletionPanel(
                            stats: viewModel.stats,
                            reason: viewModel.completionReason ?? .timeExpired,
                            gameMode: viewModel.gameMode,
                            learningProfile: viewModel.gameMode == .learning ? viewModel.learningProfile : nil,
                            onPlayAgain: { viewModel.resetGame() },
                            compact: metrics.compactPanel
                        )
                        .frame(height: metrics.completionHeight)
                        .id("complete-\(viewModel.stats.totalMoves)-\(viewModel.stats.boardDraws)")
                    }
                }
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, metrics.topPadding)
                .padding(.bottom, metrics.bottomPadding)
            }
            .allowsHitTesting(true)
        }
        .navigationTitle(viewModel.gameMode == .learning ? "Learning" : "Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onGameViewAppear()
        }
        .onDisappear {
            viewModel.onGameViewDisappear()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SGThemeToggleControl()
            }
#if DEBUG
            if viewModel.gameMode == .vsAI || viewModel.gameMode == .aiVsAI {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 6) {
                        if viewModel.gameMode == .aiVsAI {
                            Picker("Speed", selection: Binding(
                                get: { viewModel.aiVsAIDelayPreset },
                                set: { viewModel.aiVsAIDelayPreset = $0 }
                            )) {
                                ForEach(AIDebugDelayPreset.allCases, id: \.self) { preset in
                                    Text(preset.rawValue.capitalized).tag(preset)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .accessibilityLabel("AI vs AI pacing")
                            .accessibilityHint("Slows or speeds automatic moves for debugging.")
                        }
                        Picker("AI difficulty", selection: Binding(
                            get: { viewModel.aiDifficulty },
                            set: { viewModel.aiDifficulty = $0 }
                        )) {
                            ForEach(AIDifficulty.allCases, id: \.self) { level in
                                Text(level.rawValue.capitalized).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .accessibilityLabel("AI difficulty")
                        .accessibilityHint("Easy random, medium mix, hard minimax.")
                    }
                }
            }
#endif
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    viewModel.resetGame()
                }
                .tint(t.accentSubtle)
                .font(SGTypography.small)
            }
        }
        .sgToolbarStyle()
    }

    private func boardsGrid(metrics: GameLayoutMetrics) -> some View {
        let columns: [GridItem] = Array(
            repeating: GridItem(.fixed(metrics.boardSize), spacing: metrics.boardGap),
            count: metrics.columns
        )

        return LazyVGrid(columns: columns, spacing: metrics.boardGap) {
            ForEach(Array(viewModel.boards.enumerated()), id: \.offset) { index, board in
                CompactBoardGrid(
                    boardIndex: index,
                    board: board,
                    isFocused: viewModel.focusedBoardIndex.map { $0 == index } ?? false,
                    permitsCellPlacement: { cell in
                        viewModel.allowsHumanPlacement(boardIndex: index, cellIndex: cell)
                    },
                    onSelectCell: { cell in
                        viewModel.makeMove(boardIndex: index, cellIndex: cell)
                    },
                    boardSize: metrics.boardSize
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? SGSpacing.xs : SGSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: SGSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.turnLabelPrimary)
                        .font(compact ? SGTypography.small : SGTypography.body)
                        .tracking(compact ? 0.5 : SGTypography.subtitleTracking)
                        .foregroundStyle(t.textPrimary)
                    Text("Play until time runs out.")
                        .font(SGTypography.small)
                        .foregroundStyle(t.textSecondary.opacity(0.82))
                        .tracking(0.25)
                    if let whisper = viewModel.aiWhisperLine, !whisper.isEmpty {
                        Text(whisper)
                            .font(SGTypography.small)
                            .foregroundStyle(t.textSecondary.opacity(0.92))
                            .tracking(0.3)
                    }
                }
                Spacer(minLength: SGSpacing.sm)
                timerChip
            }

            HStack(spacing: compact ? SGSpacing.xs : SGSpacing.sm) {
                statChip(title: "Board", value: "\(viewModel.activeBoardIndex + 1)/\(GameConstants.boardCount)")
                statChip(title: "Starter", value: viewModel.activeBoardStarter == .x ? "X" : "O")
                statChip(title: "Moves", value: "\(viewModel.stats.totalMoves)")
                statChip(title: "X", value: "\(viewModel.stats.xBoardWins)")
                statChip(title: "O", value: "\(viewModel.stats.oBoardWins)")
                statChip(title: "D", value: "\(viewModel.stats.boardDraws)")
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(SGTypography.small)
                .foregroundStyle(t.textSecondary)
                .tracking(1.05)
            Text(value)
                .font(SGTypography.small)
                .fontWeight(.semibold)
                .foregroundStyle(t.textPrimary)
        }
        .padding(.horizontal, SGSpacing.sm)
        .padding(.vertical, SGSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: SGRadius.sm, style: .continuous)
                .fill(t.surfaceMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: SGRadius.sm, style: .continuous)
                        .strokeBorder(t.border.opacity(themeMode == .light ? 0.5 : 0.45), lineWidth: 0.85)
                )
        )
    }

    private var timerChip: some View {
        let urgency = viewModel.remainingSeconds <= 10 && viewModel.sessionState == .playing
        return Text(viewModel.formattedRemainingTime)
            .font(SGTypography.small)
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(urgency ? t.accent : t.textPrimary)
            .padding(.horizontal, SGSpacing.sm)
            .padding(.vertical, SGSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: SGRadius.sm, style: .continuous)
                    .fill(t.surfaceMuted)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGRadius.sm, style: .continuous)
                            .strokeBorder(
                                (urgency ? t.accentSubtle : t.border).opacity(themeMode == .light ? 0.52 : 0.45),
                                lineWidth: 0.85
                            )
                    )
            )
            .accessibilityLabel("Time remaining \(viewModel.formattedRemainingTime)")
    }

    /// Extra vertical reservation for Learning strip when Dynamic Type grows (layout-only; typography in strip stays fixed-sized).
    private func learningStripReserveBonus(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .accessibility1, .accessibility2: return 14
        case .accessibility3, .accessibility4, .accessibility5: return 26
        default: return 0
        }
    }

    private func layoutMetrics(
        in proxy: GeometryProxy,
        showLearningStrip: Bool,
        dynamicTypeBonus: CGFloat
    ) -> GameLayoutMetrics {
        let insets = proxy.safeAreaInsets
        let width = proxy.size.width
        let height = proxy.size.height
        let isPhoneSized = width < 700
        let isLandscapePhone = isPhoneSized && width > height

        let horizontalPadding: CGFloat = width >= 700 ? SGSpacing.xl : SGSpacing.md
        let topPadding: CGFloat = SGSpacing.sm
        let bottomPadding: CGFloat = max(SGSpacing.md, insets.bottom * 0.45)

        var contentSpacing: CGFloat = width >= 700 ? SGSpacing.md : SGSpacing.sm
        if showLearningStrip && isLandscapePhone {
            contentSpacing = SGSpacing.xs
        }

        let learningCompletionStripe: CGFloat = {
            guard viewModel.isSessionComplete, viewModel.gameMode == .learning else { return 0 }
            return width >= 700 ? 52 : 48
        }()
        /// Fixed slot under the eight boards (`ScrollView`-free): sized for recap + **`Play Again`**.
        let completionHeight: CGFloat = {
            guard viewModel.isSessionComplete else { return 0 }
            let base: CGFloat = width >= 700 ? 192 : 166
            return base + learningCompletionStripe
        }()

        let headerHeight: CGFloat = {
            if width >= 700 { return 94 }
            // Short vertical space: compact stats row, still enough for chips + timer without clipping fixed frame.
            if isLandscapePhone && showLearningStrip { return 76 }
            if isLandscapePhone { return 74 }
            return 76
        }()

        // Reserve aligns with intrinsic strip height (~5 compact text lines + bar + pad) — prevents grid/str overlap on short screens.
        let learningStripHeight: CGFloat = {
            guard showLearningStrip else { return 0 }
            if width >= 700 {
                return 101 + dynamicTypeBonus * 0.55
            }
            if isLandscapePhone {
                return 90 + dynamicTypeBonus * 0.85
            }
            return 104 + dynamicTypeBonus
        }()

        let learningExtraSpacing: CGFloat = showLearningStrip ? contentSpacing : 0
        let boardGap = width >= 700 ? SGSpacing.md : SGSpacing.sm

        /// iPhone portrait: **2 × 4**; iPad: **4 × 2** — non-negotiable for this sprint.
        let columnsCount = width >= 700 ? 4 : 2

        let availableWidth = width - (horizontalPadding * 2)
        let availableHeight =
            height - insets.top - bottomPadding - topPadding - headerHeight - learningStripHeight
            - learningExtraSpacing - contentSpacing - completionHeight

        let chosen = boardSize(
            for: availableWidth,
            availableHeight: availableHeight,
            columns: columnsCount,
            rows: GameConstants.boardCount / columnsCount,
            gap: boardGap
        )

        return GameLayoutMetrics(
            columns: chosen.0,
            rows: chosen.1,
            boardSize: chosen.2,
            boardGap: boardGap,
            horizontalPadding: horizontalPadding,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
            contentSpacing: contentSpacing,
            completionHeight: completionHeight,
            headerHeight: headerHeight,
            compactHeader: width < 400 || isLandscapePhone,
            compactPanel: width < 430,
            compactLearningStripLayout: isLandscapePhone && showLearningStrip
        )
    }

    private func boardSize(for width: CGFloat, availableHeight: CGFloat, columns: Int, rows: Int, gap: CGFloat) -> (Int, Int, CGFloat) {
        let widthBased = (width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let heightBased = (availableHeight - CGFloat(rows - 1) * gap) / CGFloat(rows)
        return (columns, rows, floor(min(widthBased, heightBased)))
    }
}

// MARK: - Learning strip (Quiet System, compact)

private struct LearningModeStripView: View {
    let profile: LearningProfile
    let tokens: XOTheme.Tokens
    let themeMode: SGThemeMode
    var compactVertical: Bool = false

    private var stripSpacing: CGFloat { compactVertical ? 2 : 3 }
    private var stripHPadding: CGFloat { compactVertical ? SGSpacing.sm : SGSpacing.sm + 2 }
    private var stripVPadding: CGFloat { compactVertical ? SGSpacing.xs : SGSpacing.xs + 2 }
    private var bodyFont: Font { compactVertical ? Font.system(size: 11, weight: .regular, design: .rounded) : SGTypography.small }

    var body: some View {
        VStack(alignment: .leading, spacing: stripSpacing) {
            Text(profile.currentLevel.title)
                .font(compactVertical ? Font.system(size: 11.5, weight: .semibold, design: .rounded) : SGTypography.small)
                .fontWeight(.semibold)
                .foregroundStyle(tokens.textPrimary)
                .tracking(compactVertical ? 0.3 : 0.35)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text("Goal: \(profile.currentLevel.targetText).")
                .font(bodyFont)
                .foregroundStyle(tokens.textSecondary.opacity(0.9))
                .tracking(0.12)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
            Text(feedbackLine)
                .font(bodyFont)
                .foregroundStyle(tokens.textSecondary.opacity(0.93))
                .tracking(0.08)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
            Text(progressPercentLabel)
                .font(Font.system(size: compactVertical ? 10 : 11, weight: .regular, design: .rounded))
                .foregroundStyle(tokens.textSecondary.opacity(themeMode == .light ? 0.68 : 0.62))
                .tracking(0.15)
                .padding(.top, compactVertical ? 0 : 1)
            progressLine
        }
        .padding(.horizontal, stripHPadding)
        .padding(.vertical, stripVPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                .fill(tokens.surfaceMuted.opacity(themeMode == .light ? 0.52 : 0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                        .strokeBorder(tokens.border.opacity(themeMode == .light ? 0.42 : 0.38), lineWidth: 0.85)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var progressPercentLabel: String {
        let pct = Int((profile.progressValue * 100.0).rounded(.down))
        return "Progress \(pct)%"
    }

    private var feedbackLine: String {
        let t = profile.latestFeedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "—" : t
    }

    private var accessibilitySummary: String {
        "\(profile.currentLevel.title). Goal: \(profile.currentLevel.targetText). \(feedbackLine). \(progressPercentLabel)."
    }

    private var progressLine: some View {
        GeometryReader { geo in
            let w = max(0, min(1, profile.progressValue)) * geo.size.width
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(tokens.border.opacity(themeMode == .light ? 0.2 : 0.26))
                    .frame(height: 2)
                Capsule(style: .continuous)
                    .fill(tokens.accentSubtle.opacity(0.78))
                    .frame(width: max(2, w), height: 2)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

private struct GameLayoutMetrics {
    let columns: Int
    let rows: Int
    let boardSize: CGFloat
    let boardGap: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let contentSpacing: CGFloat
    let completionHeight: CGFloat
    let headerHeight: CGFloat
    let compactHeader: Bool
    let compactPanel: Bool
    let compactLearningStripLayout: Bool
}
