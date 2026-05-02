//
//  GameView.swift
//  XOArena
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Propagacija: u iPhone landscape sakriven je DEBUG trailing toolbar (po želji ostaje samo back).
private struct MinimalGameTrailingToolbarPreferenceKey: PreferenceKey {
    static let defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

struct GameView: View {
#if DEBUG
    /// **`true`**: poluprozirni okviri (cela scena, safe area, zona grida, tap oblasti tabla). U produkciji ostaje **`false`**.
    static var showLayoutDebugFrames = false
#endif

    @Bindable var viewModel: GameViewModel
    @Environment(\.sgThemeMode) private var themeMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var hideTrailingDebugToolbarChrome = false

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    private static var userInterfaceIsPad: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
#else
        false
#endif
    }

    var body: some View {
        GeometryReader { proxy in
            let hideTrail = GameView.toolbarTrailingHiddenForOrientation(proxy)

            ZStack {
                PaperBackgroundView()
                    .ignoresSafeArea()

                let showLearningStrip = viewModel.gameMode == .learning
                let metrics = layoutMetrics(
                    in: proxy,
                    showLearningStrip: showLearningStrip,
                    dynamicTypeBonus: learningStripReserveBonus(for: dynamicTypeSize),
                    horizontalSizeClass: horizontalSizeClass,
                    verticalSizeClass: verticalSizeClass
                )

                VStack(spacing: metrics.contentSpacing) {
                    gameInformationHeader(metrics: metrics)
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
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, metrics.topPadding)
                .padding(.bottom, metrics.bottomPadding)

                Group {
                    if viewModel.sessionState == .completed {
                        SessionCompletionModal(
                            stats: viewModel.stats,
                            reason: viewModel.completionReason ?? .timeExpired,
                            gameMode: viewModel.gameMode,
                            learningProfile: viewModel.gameMode == .learning ? viewModel.learningProfile : nil,
                            onPlayAgain: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.resetGame()
                                }
                            }
                        )
                        .transition(.opacity)
                        .zIndex(50)
                        .id("completion-modal-\(viewModel.stats.totalMoves)-\(viewModel.stats.boardDraws)")
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.sessionState)
#if DEBUG
                if GameView.showLayoutDebugFrames {
                    GameLayoutDebugOverlay(
                        containerSize: proxy.size,
                        safeInsets: proxy.safeAreaInsets,
                        metrics: metrics,
                        showsLearningStrip: showLearningStrip,
                        columnCount: metrics.columns,
                        rowCount: metrics.rows
                    )
                    .allowsHitTesting(false)
                    .zIndex(100)
                }
#endif
            }
            .allowsHitTesting(true)
            .preference(key: MinimalGameTrailingToolbarPreferenceKey.self, value: hideTrail)
        }
        .onPreferenceChange(MinimalGameTrailingToolbarPreferenceKey.self) { hideTrailingDebugToolbarChrome = $0 }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onGameViewAppear()
        }
        .onDisappear {
            viewModel.onGameViewDisappear()
        }
#if DEBUG
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.gameMode == .aiVsAI, !hideTrailingDebugToolbarChrome {
                    Menu {
                        ForEach(AIDebugDelayPreset.allCases, id: \.self) { preset in
                            Button(preset.rawValue.capitalized) {
                                viewModel.aiVsAIDelayPreset = preset
                            }
                        }
                    } label: {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.body.weight(.medium))
                            .foregroundStyle(t.textSecondary)
                    }
                    .accessibilityLabel("AI vs AI pacing")
                }
            }
        }
#endif
        .sgToolbarStyle()
    }

    /// iPhone landscape: bez trailing DEBUG kontrola (**back** ostaje sistemski uz safe area).
    private static func toolbarTrailingHiddenForOrientation(_ proxy: GeometryProxy) -> Bool {
        let w = proxy.size.width
        let h = proxy.size.height
        let isLandscape = w > h
        return !userInterfaceIsPad && isLandscape
    }

    // MARK: - Minimal hero (samo vidljivi timer; hod samo u accessibility)

    private func gameInformationHeader(metrics: GameLayoutMetrics) -> some View {
        Text(viewModel.formattedRemainingTime)
            .font(heroTimerFont(metrics: metrics))
            .foregroundStyle(timerHeroInk)
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.75)
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .sgEngravedText(intensity: .high, color: timerHeroInk)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(heroAccessibilitySummary)
            .accessibilityActions {
                Button("Reset game") {
                    viewModel.resetGame()
                }
                if aiDifficultyBadgeVisible {
                    Button("Change AI difficulty") {
                        cycleAIDifficultyTap()
                    }
                }
            }
    }

    /// VoiceOver: hod, vreme, AI težina; reset / težina i dalje preko akcija.
    private var heroAccessibilitySummary: String {
        var parts: [String] = [heroTurnLine, "Time \(viewModel.formattedRemainingTime)"]
        if aiDifficultyBadgeVisible {
            parts.append("AI \(capitalizeAIDifficultyRaw(viewModel.aiDifficulty.rawValue)) difficulty")
        } else if viewModel.gameMode == .localDuel {
            parts.append("Two players")
        }
        if !viewModel.isSessionComplete {
            parts.append("Actions: reset game or change AI difficulty")
        }
        return parts.joined(separator: ". ")
    }

    private var heroTurnLine: String {
        guard viewModel.sessionState == .playing else {
            return viewModel.sessionState == .completed ? "Session finished" : "Ready"
        }
        return viewModel.currentMark == .x ? "X to play" : "O to play"
    }

    private var timerHeroInk: Color {
        let urgency = viewModel.remainingSeconds <= 10 && viewModel.sessionState == .playing
        return urgency ? t.accent : t.textPrimary
    }

    private func heroTimerFont(metrics: GameLayoutMetrics) -> Font {
        Font.system(size: metrics.heroTimerFontSize, design: .rounded).weight(.semibold)
    }

    private func capitalizeAIDifficultyRaw(_ raw: String) -> String {
        guard let first = raw.first else { return raw }
        return String(first.uppercased() + raw.dropFirst())
    }

    private var aiDifficultyBadgeVisible: Bool {
#if DEBUG
        if viewModel.gameMode == .aiVsAI { return true }
#endif
        return viewModel.gameMode == .vsAI || viewModel.gameMode == .learning
    }

    private func cycleAIDifficultyTap() {
        let order = AIDifficulty.allCases
        guard let i = order.firstIndex(of: viewModel.aiDifficulty) else { return }
        let next = order[(i + 1) % order.count]
        viewModel.aiDifficulty = next
        HapticService.lightImpact()
    }

    // MARK: - Boards

    private func boardsGrid(metrics: GameLayoutMetrics) -> some View {
        let columns: [GridItem] = Array(
            repeating: GridItem(.fixed(metrics.boardSize), spacing: metrics.boardGapHorizontal),
            count: metrics.columns
        )

        return LazyVGrid(columns: columns, spacing: metrics.boardGapVertical) {
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
                    boardSize: metrics.boardSize,
                    sessionTotalMoves: viewModel.stats.totalMoves,
                    focusedScaleBoost: metrics.focusedBoardScaleBoost,
                    unfocusedOpacityFactor: metrics.inactiveBoardOpacityFactor
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Extra vertical reservation for Learning strip when Dynamic Type grows (layout-only).
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
        dynamicTypeBonus: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        verticalSizeClass: UserInterfaceSizeClass?
    ) -> GameLayoutMetrics {
        let insets = proxy.safeAreaInsets
        let width = proxy.size.width
        let height = proxy.size.height
        let isLandscape = width > height
        let isPad = Self.userInterfaceIsPad
        let isPhone = !isPad
        let isLandscapePhone = isPhone && isLandscape

        /// Horizontalno: leading/trailing safe area (ostrva, split view, zakrivljenje).
        let usableWidth = width - insets.leading - insets.trailing

        /// U multitask-u iPad dobija **`compact`** po širini — blaži raspored kao na užem platnu.
        let isPadCompactWidth =
            isPad && (usableWidth < 520 || horizontalSizeClass == .some(.compact))

        let horizontalPadding: CGFloat = {
            if isPad {
                if isPadCompactWidth { return SGSpacing.lg }
                return isLandscape ? SGSpacing.xl : SGSpacing.xl + SGSpacing.sm
            }
            if isLandscapePhone { return SGSpacing.sm + SGSpacing.xs }
            /// iPhone portrait: mali unutrašnji inset (ukupno ~**20** pt) + **leading/trailing** iz `usableWidth` radi **~28–36** pt tipično do ivice ekrana zajedno sa safe area.
            return CGFloat(10)
        }()
        let topPadding: CGFloat = SGSpacing.xs + 2
        let bottomPadding: CGFloat = max(SGSpacing.sm, insets.bottom * 0.38)

        var contentSpacing: CGFloat = {
            guard isPad else { return SGSpacing.sm }
            if isPadCompactWidth { return SGSpacing.sm + 2 }
            return SGSpacing.sm + SGSpacing.sm
        }()
        if !showLearningStrip && isPhone {
            contentSpacing = min(contentSpacing, SGSpacing.sm)
        }
        if showLearningStrip && isLandscapePhone {
            contentSpacing = SGSpacing.xs
        }

        let headerHeight: CGFloat = {
            if isPad {
                return isLandscape ? (isPadCompactWidth ? 48 : 54) : 52
            }
            if isLandscapePhone && showLearningStrip { return 42 }
            if isLandscapePhone { return 42 }
            return 44
        }()

        let learningStripHeight: CGFloat = {
            guard showLearningStrip else { return 0 }
            if isPad {
                return 101 + dynamicTypeBonus * 0.55
            }
            if isLandscapePhone {
                return 90 + dynamicTypeBonus * 0.85
            }
            return 104 + dynamicTypeBonus
        }()

        let learningExtraSpacing: CGFloat = showLearningStrip ? contentSpacing : 0

        let columnsCount: Int
        let rowsCount: Int
        /// Matrix: iPhone portrait **2×4** — iPhone landscape **4×2** — iPad **4×2** ili u landscape (**8×1** samo ako su tablite dovoljno velike vs 4×2).
        if isLandscapePhone {
            columnsCount = 4
            rowsCount = 2
        } else if isPhone {
            columnsCount = 2
            rowsCount = 4
        } else {
            columnsCount = 4
            rowsCount = 2
        }

        let shortestSidePoints = min(width, height)
        let widestSidePoints = max(width, height)

        let focusBoost: CGFloat = {
            if isPad { return 1.028 }
            if shortestSidePoints < 391 { return 1.02 }
            return 1.026
        }()
        let inactiveOpacityMul: CGFloat = 0.9

        let compactHeaderVisual =
            shortestSidePoints < 400 || isLandscapePhone
            || (isPadCompactWidth && (verticalSizeClass == .some(.compact) || widestSidePoints < 900))

        let heroTimerFontSize: CGFloat = {
            guard isPad else {
                let base = compactHeaderVisual ? CGFloat(43) : CGFloat(46)
                return min(CGFloat(48), max(CGFloat(42), base))
            }
            var s = max(CGFloat(48), min(CGFloat(56), isLandscape ? CGFloat(52) : CGFloat(54)))
            if isPadCompactWidth { s -= 4 }
            return min(CGFloat(56), max(CGFloat(48), s))
        }()

        let availableWidth = max(1, usableWidth - horizontalPadding * 2)

        let availableHeightBoardsRegion =
            height - insets.top - bottomPadding - topPadding - headerHeight - learningStripHeight
            - learningExtraSpacing - contentSpacing

        let layout: (boardSize: CGFloat, gapHorizontal: CGFloat, gapVertical: CGFloat)
        var gridColumns = columnsCount
        var gridRows = rowsCount

        if isLandscapePhone {
            layout = resolvedIPhoneLandscapeFourByTwoBoardLayout(
                availableWidth: availableWidth,
                boardsRegionHeight: availableHeightBoardsRegion,
                portraitShortSide: shortestSidePoints
            )
        } else if isPad && isLandscape {
            let picked = resolvedIPadLandscapeGridEightOrFour(
                availableWidth: availableWidth,
                availableHeight: availableHeightBoardsRegion,
                padShortSide: shortestSidePoints,
                padLongSide: widestSidePoints,
                ipadCompactWidthLayout: isPadCompactWidth
            )
            gridColumns = picked.columns
            gridRows = picked.rows
            layout = picked.layout
        } else if isPad {
            layout = resolvedPadBoardGridLayout(
                availableWidth: availableWidth,
                availableHeight: availableHeightBoardsRegion,
                columns: 4,
                rows: 2,
                padShortSide: shortestSidePoints,
                padLongSide: widestSidePoints,
                ipadCompactWidthLayout: isPadCompactWidth
            )
        } else {
            layout = resolvedIPhonePortraitTwoByFourBoardGridLayout(
                availableWidth: availableWidth,
                availableHeight: availableHeightBoardsRegion
            )
        }

        return GameLayoutMetrics(
            columns: gridColumns,
            rows: gridRows,
            boardSize: layout.boardSize,
            boardGapHorizontal: layout.gapHorizontal,
            boardGapVertical: layout.gapVertical,
            horizontalPadding: horizontalPadding,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
            contentSpacing: contentSpacing,
            headerHeight: headerHeight,
            heroTimerFontSize: heroTimerFontSize,
            learningStripOccupiedHeight: showLearningStrip ? learningStripHeight : 0,
            compactHeader: compactHeaderVisual,
            compactLearningStripLayout: isLandscapePhone && showLearningStrip,
            focusedBoardScaleBoost: focusBoost,
            inactiveBoardOpacityFactor: inactiveOpacityMul
        )
    }

    /// iPad landscape: pref. **4×2** — **8×1** ako je **`boardSize`** jasno veći od 4×2 i ≥ ~170 pt.
    private func resolvedIPadLandscapeGridEightOrFour(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        padShortSide: CGFloat,
        padLongSide: CGFloat,
        ipadCompactWidthLayout: Bool
    ) -> (columns: Int, rows: Int, layout: (boardSize: CGFloat, gapHorizontal: CGFloat, gapVertical: CGFloat)) {
        let layoutFour = resolvedPadBoardGridLayout(
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            columns: 4,
            rows: 2,
            padShortSide: padShortSide,
            padLongSide: padLongSide,
            ipadCompactWidthLayout: ipadCompactWidthLayout
        )
        if ipadCompactWidthLayout {
            return (4, 2, layoutFour)
        }
        let layoutEight = resolvedPadBoardGridLayout(
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            columns: 8,
            rows: 1,
            padShortSide: padShortSide,
            padLongSide: padLongSide,
            ipadCompactWidthLayout: ipadCompactWidthLayout
        )

        let eightLargeEnough = layoutEight.boardSize >= 170 && layoutEight.boardSize > layoutFour.boardSize + 8
        if eightLargeEnough {
            return (8, 1, layoutEight)
        }
        return (4, 2, layoutFour)
    }

    /// iPhone landscape (**4 × 2**): `boardSize = min(byWidth, byHeight)` uz clamp 72…max; **`gapVertical`** 36…52.
    private func resolvedIPhoneLandscapeFourByTwoBoardLayout(
        availableWidth: CGFloat,
        boardsRegionHeight: CGFloat,
        portraitShortSide: CGFloat
    ) -> (boardSize: CGFloat, gapHorizontal: CGFloat, gapVertical: CGFloat) {
        let columns = 4
        let rows = 2
        let gapVMin: CGFloat = 36
        let gapVMax: CGFloat = 52
        let minBoard: CGFloat = 72
        let H = max(1, boardsRegionHeight)

        let maxBoard: CGFloat = {
            if portraitShortSide <= 376 { return 120 }
            if portraitShortSide <= 390 { return 128 }
            if portraitShortSide <= 414 { return 138 }
            if portraitShortSide <= 430 { return 144 }
            return 150
        }()

        let gapHorizontal = max(16, min(28, availableWidth * 0.028))

        let boardFromWidth = floor((availableWidth - CGFloat(columns - 1) * gapHorizontal) / CGFloat(columns))
        let boardFromHeightAtMinGap = floor((H - gapVMin) / CGFloat(rows))

        var boardSize = min(boardFromWidth, boardFromHeightAtMinGap)
        boardSize = min(maxBoard, max(minBoard, boardSize))

        var gapVertical = (H - CGFloat(rows) * boardSize) / CGFloat(rows - 1)
        if gapVertical < gapVMin {
            boardSize = floor((H - CGFloat(rows - 1) * gapVMin) / CGFloat(rows))
            boardSize = min(maxBoard, max(minBoard, min(boardFromWidth, boardSize)))
            gapVertical = gapVMin
        } else if gapVertical > gapVMax {
            gapVertical = gapVMax
            boardSize = floor((H - CGFloat(rows - 1) * gapVertical) / CGFloat(rows))
            boardSize = min(maxBoard, max(minBoard, min(boardFromWidth, boardSize)))
            gapVertical = (H - CGFloat(rows) * boardSize) / CGFloat(rows - 1)
            gapVertical = min(gapVMax, max(gapVMin, gapVertical))
        } else {
            gapVertical = min(gapVMax, max(gapVMin, gapVertical))
        }

        var heightCap =
            floor((H - CGFloat(rows - 1) * gapVertical) / CGFloat(rows))
        boardSize = min(boardSize, heightCap)
        boardSize = min(boardFromWidth, max(minBoard, min(maxBoard, boardSize)))

        gapVertical = (H - CGFloat(rows) * boardSize) / CGFloat(rows - 1)
        gapVertical = min(gapVMax, max(gapVMin, gapVertical))

        while CGFloat(rows) * boardSize + CGFloat(rows - 1) * gapVertical > H + 0.5 && boardSize > minBoard {
            boardSize -= 1
            gapVertical = (H - CGFloat(rows) * boardSize) / CGFloat(rows - 1)
            gapVertical = min(gapVMax, max(gapVMin, gapVertical))
        }
        heightCap = floor((H - CGFloat(rows - 1) * gapVertical) / CGFloat(rows))
        boardSize = min(boardSize, heightCap)

        return (boardSize, gapHorizontal, gapVertical)
    }

    /// iPad tabla: **`max`** **170–220** pt po klasi uređaja; multitask uža kolona blago smanjuje plafon.
    private func ipadMaxBoardClamp(
        padShortSide: CGFloat,
        padLongSide: CGFloat,
        ipadCompactWidthLayout: Bool
    ) -> CGFloat {
        let span = Swift.min(CGFloat(1400), padLongSide)
        var cap =
            Swift.min(CGFloat(220), Swift.max(CGFloat(170), padShortSide * 0.27 + span * 0.015))
        if ipadCompactWidthLayout { cap -= 18 }
        return Swift.min(CGFloat(220), Swift.max(CGFloat(170), cap))
    }

    /// iPad: **`gap`** H **48–72**, V **48–80** (**8×1** koristi **`gapVertical == 0`**).
    private func resolvedPadBoardGridLayout(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        columns: Int,
        rows: Int,
        padShortSide: CGFloat,
        padLongSide: CGFloat,
        ipadCompactWidthLayout: Bool
    ) -> (boardSize: CGFloat, gapHorizontal: CGFloat, gapVertical: CGFloat) {
        let AW = Swift.max(CGFloat(1), availableWidth)
        let AH = Swift.max(CGFloat(1), availableHeight)
        let maxBoardPt = ipadMaxBoardClamp(
            padShortSide: padShortSide,
            padLongSide: padLongSide,
            ipadCompactWidthLayout: ipadCompactWidthLayout
        )

        let gapFloorH: CGFloat = ipadCompactWidthLayout ? 42 : 48
        let gapHorizontal = Swift.max(
            gapFloorH,
            Swift.min(CGFloat(72), AW * 0.064 + CGFloat(38))
        )

        guard rows > 1 else {
            let rawW =
                floor((AW - CGFloat(max(0, columns - 1)) * gapHorizontal) / CGFloat(max(1, columns)))
            let rawH = floor(AH)
            let minFloorPad: CGFloat = ipadCompactWidthLayout ? 100 : 120
            var boardSize = floor(Swift.min(rawW, rawH))
            boardSize = Swift.min(maxBoardPt, Swift.max(minFloorPad, boardSize))
            boardSize = Swift.min(boardSize, floor(AH))
            return (boardSize, gapHorizontal, 0)
        }

        let gapVMin = ipadCompactWidthLayout ? CGFloat(44) : CGFloat(48)
        let gapVMax = ipadCompactWidthLayout ? CGFloat(72) : CGFloat(80)
        let minPreferredCell = ipadCompactWidthLayout ? CGFloat(118) : CGFloat(140)

        let boardFromWidth = floor((AW - CGFloat(columns - 1) * gapHorizontal) / CGFloat(columns))

        let slackAfterWidthFit = AH - CGFloat(rows) * boardFromWidth
        let gapVRaw = slackAfterWidthFit / CGFloat(rows - 1)

        let boardSizeRaw: CGFloat
        var gapVertical: CGFloat

        if gapVRaw >= gapVMin {
            boardSizeRaw = boardFromWidth
            gapVertical = Swift.min(gapVRaw, gapVMax)
            if gapVertical < gapVMin { gapVertical = gapVMin }
        } else {
            let boardFromHeight = floor(
                (AH - CGFloat(rows - 1) * gapVMin) / CGFloat(rows))
            let widthLimited = Swift.min(boardFromWidth, boardFromHeight)
            boardSizeRaw = widthLimited
            let slackForRows = AH - CGFloat(rows) * boardSizeRaw
            let distributed = slackForRows / CGFloat(rows - 1)
            gapVertical = Swift.min(gapVMax, Swift.max(gapVMin, distributed))
        }

        let widthCap =
            floor((AW - CGFloat(columns - 1) * gapHorizontal) / CGFloat(columns))
        let heightCapAtCurrentGap =
            floor((AH - CGFloat(rows - 1) * gapVertical) / CGFloat(rows))
        var cellMax = boardSizeRaw
        cellMax = Swift.min(cellMax, heightCapAtCurrentGap)
        cellMax = Swift.min(cellMax, widthCap)
        cellMax = Swift.max(minPreferredCell, Swift.min(cellMax, maxBoardPt))
        cellMax = Swift.max(CGFloat(72), cellMax)
        return (cellMax, gapHorizontal, gapVertical)
    }

    /// iPhone portrait (**2×4**): širina **`(availableWidth − columnGap) / 2`** bez veštačkog cepa na 150 pt ako visina dozvoljava; blaži vertikalni raspon.
    private func resolvedIPhonePortraitTwoByFourBoardGridLayout(
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> (boardSize: CGFloat, gapHorizontal: CGFloat, gapVertical: CGFloat) {
        let columns = 2
        let rows = 4
        let gapHorizontal =
            Swift.max(CGFloat(16), Swift.min(CGFloat(24), availableWidth * CGFloat(0.038) + CGFloat(11)))
        let gapVMin = CGFloat(24)
        let gapVMax = CGFloat(46)
        let minPreferredCell = CGFloat(120)
        let boardByWidth =
            floor((availableWidth - CGFloat(columns - 1) * gapHorizontal) / CGFloat(columns))

        let slackAfterWidthFit = availableHeight - CGFloat(rows) * boardByWidth
        let gapVRaw = slackAfterWidthFit / CGFloat(rows - 1)

        let boardSeed: CGFloat
        let gapVertical: CGFloat

        if gapVRaw >= gapVMin {
            boardSeed = boardByWidth
            gapVertical = Swift.min(gapVRaw, gapVMax)
        } else {
            let boardFromHeight = floor(
                (availableHeight - CGFloat(rows - 1) * gapVMin) / CGFloat(rows))
            let widthLimited = Swift.min(boardByWidth, boardFromHeight)
            boardSeed = widthLimited
            let slackForRows = availableHeight - CGFloat(rows) * boardSeed
            let distributed = slackForRows / CGFloat(rows - 1)
            gapVertical = Swift.min(gapVMax, Swift.max(gapVMin, distributed))
        }

        let heightCapAtGap =
            floor((availableHeight - CGFloat(rows - 1) * gapVertical) / CGFloat(rows))
        let widthCeiling = Swift.min(CGFloat(172), boardByWidth)

        var cellMax = Swift.min(Swift.max(minPreferredCell, boardSeed), heightCapAtGap)
        cellMax = Swift.min(cellMax, widthCeiling)

        while cellMax < boardByWidth && cellMax < widthCeiling {
            let next = cellMax + 1
            let hNeeded = CGFloat(rows) * next + CGFloat(rows - 1) * gapVertical
            if hNeeded > availableHeight + CGFloat(0.5) { break }
            cellMax = next
        }

        let hFinal = CGFloat(rows) * cellMax + CGFloat(rows - 1) * gapVertical
        if hFinal > availableHeight + CGFloat(0.5) {
            cellMax = floor((availableHeight - CGFloat(rows - 1) * gapVertical) / CGFloat(rows))
            cellMax = Swift.max(minPreferredCell, Swift.min(cellMax, widthCeiling))
        }

        return (cellMax, gapHorizontal, gapVertical)
    }
}

// MARK: - Learning strip

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
                .sgEngravedText(intensity: compactVertical ? .low : .medium, color: tokens.textPrimary)
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
    let boardGapHorizontal: CGFloat
    let boardGapVertical: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let contentSpacing: CGFloat
    let headerHeight: CGFloat
    let heroTimerFontSize: CGFloat
    let learningStripOccupiedHeight: CGFloat
    let compactHeader: Bool
    let compactLearningStripLayout: Bool
    let focusedBoardScaleBoost: CGFloat
    let inactiveBoardOpacityFactor: CGFloat
}

#if DEBUG
/// Opcioni pregled slojeva (samo ako je **`GameView.showLayoutDebugFrames == true`**).
private struct GameLayoutDebugOverlay: View {
    let containerSize: CGSize
    let safeInsets: EdgeInsets
    let metrics: GameLayoutMetrics
    let showsLearningStrip: Bool
    let columnCount: Int
    let rowCount: Int

    var body: some View {
        let w = containerSize.width
        let h = containerSize.height
        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                .frame(width: w, height: h)

            Rectangle()
                .stroke(Color.blue.opacity(0.42), lineWidth: 1)
                .frame(
                    width: w - safeInsets.leading - safeInsets.trailing,
                    height: h - safeInsets.top - safeInsets.bottom
                )
                .offset(x: safeInsets.leading, y: safeInsets.top)

            let innerLeft = safeInsets.leading + metrics.horizontalPadding
            let innerRight = safeInsets.trailing + metrics.horizontalPadding
            Rectangle()
                .stroke(Color.green.opacity(0.38), lineWidth: 1)
                .frame(width: w - innerLeft - innerRight, height: h - safeInsets.top - safeInsets.bottom)
                .offset(x: innerLeft, y: safeInsets.top)

            let contentTop =
                safeInsets.top + metrics.topPadding + metrics.headerHeight + metrics.contentSpacing
                + (showsLearningStrip ? metrics.learningStripOccupiedHeight + metrics.contentSpacing : 0)
            let gridW =
                CGFloat(columnCount) * metrics.boardSize
                + CGFloat(max(0, columnCount - 1)) * metrics.boardGapHorizontal
            let gridH =
                CGFloat(rowCount) * metrics.boardSize + CGFloat(max(0, rowCount - 1)) * metrics.boardGapVertical
            let gridX = innerLeft + max(0, (w - innerLeft - innerRight - gridW) / 2)

            Rectangle()
                .stroke(Color.purple.opacity(0.42), lineWidth: 1.25)
                .frame(width: gridW, height: gridH)
                .offset(x: gridX, y: contentTop)

            ForEach(0 ..< rowCount, id: \.self) { r in
                ForEach(0 ..< columnCount, id: \.self) { c in
                    Rectangle()
                        .stroke(Color.orange.opacity(0.35), lineWidth: 0.75)
                        .frame(width: metrics.boardSize, height: metrics.boardSize)
                        .offset(
                            x: gridX + CGFloat(c) * (metrics.boardSize + metrics.boardGapHorizontal),
                            y: contentTop + CGFloat(r) * (metrics.boardSize + metrics.boardGapVertical)
                        )
                }
            }
        }
        .frame(width: w, height: h)
    }
}
#endif
