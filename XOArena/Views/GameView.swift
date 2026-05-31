//
//  GameView.swift
//  XOArena
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
private func gameSessionScoreFont(base: CGFloat) -> Font {
    let size = UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: base)
    return .system(size: size, weight: .semibold, design: .rounded)
}
#else
private func gameSessionScoreFont(base: CGFloat) -> Font {
    .system(size: base, weight: .medium, design: .rounded)
}
#endif

/// Propagacija: u iPhone landscape sakriven je DEBUG trailing toolbar (po želji ostaje samo back).
private struct MinimalGameTrailingToolbarPreferenceKey: PreferenceKey {
    static let defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

/// iPhone: **`padding`** 24, **`spacing`** **`(kolone−1)×24`**, **`totalHeight`** = visina − 160.
private func gameBoardGridCellSize(container: CGSize, columns: Int, rows: Int) -> CGFloat {
    let pad: CGFloat = 24
    let spacing: CGFloat = 24
    let c = CGFloat(max(1, columns))
    let r = CGFloat(max(1, rows))
    let totalWidth =
        Swift.max(CGFloat(1), container.width - pad * CGFloat(2) - CGFloat(max(0, columns - 1)) * spacing)
    let totalHeight = Swift.max(CGFloat(1), container.height - CGFloat(160))
    let cellWidth = totalWidth / c
    let cellHeight = totalHeight / r
    let raw = Swift.min(cellWidth, cellHeight)
    guard raw.isFinite, !raw.isNaN else { return 1 }
    return Swift.max(1, raw)
}

/// iPad: **`columns` × `rows`** iz metrika (**portrait** **2×4**, **landscape** **4×2**), puna dostupna visina play zone, clamp po orijentaciji grida.
private func gameBoardGridCellSizeIPad(
    availableWidth: CGFloat,
    availableHeight: CGFloat,
    columns: Int,
    rows: Int,
    isCompactWidth: Bool,
    columnSpacing: CGFloat,
    rowSpacing: CGFloat
) -> CGFloat {
    let c = CGFloat(max(1, columns))
    let r = CGFloat(max(1, rows))
    let aw = Swift.max(1, availableWidth)
    let ah = Swift.max(1, availableHeight)
    let totalColumnSpacing = CGFloat(max(0, columns - 1)) * columnSpacing
    let totalRowSpacing = CGFloat(max(0, rows - 1)) * rowSpacing
    let boardSizeByWidth = (aw - totalColumnSpacing) / c
    let boardSizeByHeight = (ah - totalRowSpacing) / r

    let raw = Swift.min(boardSizeByWidth, boardSizeByHeight)
    guard raw.isFinite, !raw.isNaN else { return 120 }

    let minB: CGFloat = isCompactWidth ? 108 : 150
    let isPortraitPadGrid = columns == 2 && rows == 4
    let maxB: CGFloat
    if isPortraitPadGrid {
        maxB = 240
    } else {
        maxB = Swift.max(210, Swift.min(240, availableWidth * CGFloat(0.185) + CGFloat(158)))
    }

    return Swift.min(maxB, Swift.max(minB, raw))
}

// MARK: - iPhone landscape (4×2) layout — play area bez menjanja iPada / portrait iPhone matematike tabla

/// Donja ivica HUD-a ispod koju pada grid (usklađeno sa **`VStack`** u **`GameView`** i **`gameHUDCluster`** razmacima).
private func iphonePlayAreaTopY(
    safeTop: CGFloat,
    metrics: GameLayoutMetrics,
    hudInnerSpacing: CGFloat,
    gapHUDClusterToBoardGrid: CGFloat
) -> CGFloat {
    let cluster =
        metrics.headerHeight + hudInnerSpacing + metrics.scoreStripHeight
        + (metrics.learningStripOccupiedHeight > CGFloat(0.5)
            ? hudInnerSpacing + metrics.learningStripOccupiedHeight
            : CGFloat(0))
    return safeTop + metrics.topPadding + cluster + gapHUDClusterToBoardGrid
}

private func iphoneLandscapeBoardBottomMargin(safeBottom: CGFloat) -> CGFloat {
    safeBottom + SGSpacing.sm
}

private func iphoneLandscapeGridGaps(shortSide: CGFloat) -> (column: CGFloat, row: CGFloat) {
    let t = Swift.min(CGFloat(1), Swift.max(CGFloat(0), (shortSide - CGFloat(320)) / CGFloat(110)))
    let col = CGFloat(28) + CGFloat(16) * t
    let row = CGFloat(24) + CGFloat(8) * t
    return (col, row)
}

/// **`maxClamp`** adaptivno **[160…180]** prema širini; **stari clamp** bio je konstanta **132** (premalo za landscape).
private func gameBoardGridCellSizeIPhoneLandscape(
    availableWidth: CGFloat,
    availableHeight: CGFloat,
    columnGap: CGFloat,
    rowGap: CGFloat
) -> (boardSize: CGFloat, maxClamp: CGFloat, rawUncapped: CGFloat) {
    let aw = Swift.max(1, availableWidth)
    let ah = Swift.max(1, availableHeight)
    let byW = (aw - CGFloat(3) * columnGap) / CGFloat(4)
    let byH = (ah - rowGap) / CGFloat(2)
    let raw = Swift.min(byW, byH)
    guard raw.isFinite, !raw.isNaN else {
        return (82, CGFloat(160), CGFloat(82))
    }
    let widenT = Swift.min(CGFloat(1), Swift.max(CGFloat(0), (aw - CGFloat(460)) / CGFloat(280)))
    let maxClamp = CGFloat(160) + CGFloat(20) * widenT
    let board = Swift.min(maxClamp, Swift.max(CGFloat(82), raw))
    return (board, maxClamp, raw)
}

struct GameView: View {
#if DEBUG
    /// **`true`**: poluprozirni okviri (cela scena, safe area, zona grida, tap oblasti tabla). U produkciji ostaje **`false`**.
    static var showLayoutDebugFrames = false
    /// **`true`**: mali HUD za ručnu proveru sata (**`currentMark`** vs **`timerActiveForMark`** i banke). Podrazumevano **`false`**.
    static var showClockAuditOverlay = false
#endif
    /// Razmak između HUD klastera i table u landscape (**`iphonePlayAreaTopY`** koristi istu vrednost).
    fileprivate static let iphoneLandscapeHUDVStackSpacing: CGFloat = 8
    /// Lagano spuštanje grida tek kada je **`boardSize`** već maximizovan u okviru play zone.
    fileprivate static let iphoneLandscapeGridBiasY: CGFloat = 10

    @Bindable var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.sgThemeMode) private var themeMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var hideTrailingDebugToolbarChrome = false
    @State private var swipeBackDragStart: CGPoint?

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
            let edgeSwipeDismiss = edgeSwipeDismissGesture(containerWidth: proxy.size.width)

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

                Group {
                    if metrics.isPad {
                        VStack(spacing: 0) {
                            gameHUDCluster(metrics: metrics, showLearningStrip: showLearningStrip)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, metrics.horizontalPadding)
                                .padding(.top, metrics.topPadding)

                            boardsGrid(proxy: proxy, metrics: metrics)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(.bottom, metrics.bottomPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        let isLandscapePhoneLayout =
                            !metrics.isPad && proxy.size.width > proxy.size.height
                        let phoneStackSpacing: CGFloat =
                            isLandscapePhoneLayout ? GameView.iphoneLandscapeHUDVStackSpacing : 12
                        VStack(spacing: phoneStackSpacing) {
                            gameHUDCluster(metrics: metrics, showLearningStrip: showLearningStrip)

                            boardsGrid(proxy: proxy, metrics: metrics)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: isLandscapePhoneLayout ? .center : .topLeading
                                )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.topPadding)
                        .padding(.bottom, metrics.bottomPadding)
                    }
                }

                Group {
                    if viewModel.isPaused, viewModel.sessionState == .playing {
                        GamePauseMenuOverlay(
                            onResume: {
                                viewModel.resumeGame()
                            },
                            onRestart: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.resetGame()
                                }
                            },
                            onMainMenu: {
                                viewModel.prepareToExitGame()
                                dismiss()
                            }
                        )
                        .transition(.opacity)
                        .zIndex(45)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.isPaused)

                Group {
                    if viewModel.sessionState == .completed {
                        SessionCompletionModal(
                            stats: viewModel.stats,
                            reason: viewModel.completionReason ?? .timeExpired,
                            gameMode: viewModel.gameMode,
                            humanPlayerMark: (viewModel.gameMode == .vsAI || viewModel.gameMode == .learning)
                                ? viewModel.session.humanControlledMark
                                : nil,
                            learningProfile: viewModel.gameMode == .learning ? viewModel.learningProfile : nil,
                            onPlayAgain: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.resetGame()
                                }
                            },
                            onMainMenu: {
                                dismiss()
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
                if GameView.showClockAuditOverlay {
                    GameClockAuditOverlay(viewModel: viewModel)
                        .allowsHitTesting(false)
                        .zIndex(99)
                }
#endif
            }
            .allowsHitTesting(true)
            .simultaneousGesture(edgeSwipeDismiss)
            .accessibilityAction(.escape) {
                dismiss()
            }
            .accessibilityHint("Prevucite od ivice ekrana da napustite partiju.")
            .preference(key: MinimalGameTrailingToolbarPreferenceKey.self, value: hideTrail)
        }
        .onPreferenceChange(MinimalGameTrailingToolbarPreferenceKey.self) { hideTrailingDebugToolbarChrome = $0 }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.sessionState == .playing && !viewModel.isPaused {
                    Button {
                        HapticService.lightImpact()
                        viewModel.pauseGame()
                    } label: {
                        Text("Pause")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(t.textSecondary)
                    }
                    .accessibilityLabel("Pause game")
                }
            }
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

    /// iPhone landscape: bez trailing DEBUG kontrola (nazad je **swipe sa ivice**).
    private static func toolbarTrailingHiddenForOrientation(_ proxy: GeometryProxy) -> Bool {
        let w = proxy.size.width
        let h = proxy.size.height
        let isLandscape = w > h
        return !userInterfaceIsPad && isLandscape
    }

    /// Izlaz kao na **interactive pop**: početak u uzem pojasu uz **leading** (LTR) / **trailing** (RTL) ivicu.
    private func edgeSwipeDismissGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 36, coordinateSpace: .local)
            .onChanged { value in
                if swipeBackDragStart == nil {
                    swipeBackDragStart = value.location
                }
            }
            .onEnded { value in
                defer { swipeBackDragStart = nil }
                guard containerWidth > 1, let start = swipeBackDragStart else { return }
                let margin: CGFloat = 76
                let startedNearBackGeometry: Bool
                switch layoutDirection {
                case .rightToLeft:
                    startedNearBackGeometry = start.x > containerWidth - margin
                case .leftToRight:
                    fallthrough
                @unknown default:
                    startedNearBackGeometry = start.x < margin
                }
                guard startedNearBackGeometry else { return }
                let dx = value.translation.width
                let dy = abs(value.translation.height)
                guard dy < 100 else { return }
                switch layoutDirection {
                case .rightToLeft:
                    guard dx < -115 else { return }
                case .leftToRight:
                    fallthrough
                @unknown default:
                    guard dx > 115 else { return }
                }
                dismiss()
            }
    }

    // MARK: - Minimal hero (samo vidljivi timer; hod samo u accessibility)

    private func gameInformationHeader(metrics: GameLayoutMetrics) -> some View {
        let base = metrics.heroTimerFontSize
        let activeFont = Font.system(size: base, design: .rounded).weight(.semibold)
        let inactiveFont = Font.system(size: base * 0.88, design: .rounded).weight(.medium)
        let markLetterFont = Font.system(size: base, design: .rounded).weight(.bold)
        let dashFont = Font.system(size: base * 0.72, design: .rounded).weight(.medium)

        return HStack(alignment: .firstTextBaseline, spacing: SGSpacing.sm) {
            HStack(spacing: 4) {
                Text("X")
                    .font(markLetterFont)
                Text(viewModel.formattedXRemainingTime)
                    .font(viewModel.currentMark == .x ? activeFont : inactiveFont)
                    .monospacedDigit()
            }
            .foregroundStyle(heroClockInk(for: .x))
            .sgEngravedText(
                intensity: viewModel.currentMark == .x && viewModel.sessionState == .playing ? .high : .low,
                color: heroClockInk(for: .x)
            )

            Text("—")
                .font(dashFont)
                .foregroundStyle(t.textSecondary.opacity(0.42))

            HStack(spacing: 4) {
                Text(viewModel.formattedORemainingTime)
                    .font(viewModel.currentMark == .o ? activeFont : inactiveFont)
                    .monospacedDigit()
                Text("O")
                    .font(markLetterFont)
            }
            .foregroundStyle(heroClockInk(for: .o))
            .sgEngravedText(
                intensity: viewModel.currentMark == .o && viewModel.sessionState == .playing ? .high : .low,
                color: heroClockInk(for: .o)
            )
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.62)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .center)
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

    private func heroClockInk(for mark: Mark) -> Color {
        guard mark == .x || mark == .o else { return t.textPrimary.opacity(0.5) }
        let secs = mark == .x ? viewModel.xRemainingSeconds : viewModel.oRemainingSeconds
        let isActive = viewModel.sessionState == .playing && viewModel.currentMark == mark
        let urgent = isActive && secs <= 10
        if urgent { return t.accent }
        if isActive { return t.textPrimary }
        return t.textPrimary.opacity(0.52)
    }

    /// Rezultat sesije (pobede po tablama) — diskretno ispod tajmera, iznad mreže.
    private func sessionScoreStrip(metrics: GameLayoutMetrics) -> some View {
        let inkOpacity: CGFloat = themeMode == .light ? 0.58 : 0.66
        let ink = t.textPrimary.opacity(inkOpacity)
        let font = gameSessionScoreFont(base: metrics.scoreFontBase)

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: SGSpacing.sm) {
                Text("\(viewModel.stats.xBoardWins)")
                    .monospacedDigit()
                Text("–")
                    .opacity(0.88)
                Text("\(viewModel.stats.oBoardWins)")
                    .monospacedDigit()
            }
            Spacer()
        }
        .font(font)
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity)
        .frame(height: metrics.scoreStripHeight, alignment: .center)
        .sgEngravedText(intensity: .low, color: ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session score")
        .accessibilityValue("X \(viewModel.stats.xBoardWins), O \(viewModel.stats.oBoardWins)")
    }

    /// VoiceOver: hod, vreme, AI težina; reset / težina i dalje preko akcija.
    private var heroAccessibilitySummary: String {
        var parts: [String] = [
            heroTurnLine,
            "X \(viewModel.formattedXRemainingTime), O \(viewModel.formattedORemainingTime)"
        ]
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

    /// Vertikalni pomak linije nagrade ispod reda sata (overlay ne menja layout visine HUD-a).
    private func timeRewardOverlayOffsetY(metrics: GameLayoutMetrics) -> CGFloat {
        max(16, metrics.heroTimerFontSize * 0.4 + 4)
    }

    // MARK: - HUD (tajmer + skor + learning)

    @ViewBuilder
    private func gameHUDCluster(metrics: GameLayoutMetrics, showLearningStrip: Bool) -> some View {
        VStack(spacing: metrics.hudClusterSpacing) {
            gameInformationHeader(metrics: metrics)
                .overlay(alignment: .bottom) {
                    if let reward = viewModel.latestTimeReward {
                        GameClockTimeRewardLine(
                            event: reward,
                            announcement: viewModel.timeRewardAnnouncementID,
                            tokens: t,
                            themeMode: themeMode
                        )
                        .offset(y: timeRewardOverlayOffsetY(metrics: metrics))
                    }
                }
            sessionScoreStrip(metrics: metrics)
            if showLearningStrip {
                LearningModeStripView(
                    profile: viewModel.learningProfile,
                    tokens: t,
                    themeMode: themeMode,
                    compactVertical: metrics.compactLearningStripLayout
                )
            }
        }
    }

    // MARK: - Boards

    @ViewBuilder
    private func boardsGrid(proxy: GeometryProxy, metrics: GameLayoutMetrics) -> some View {
        if metrics.isPad {
            GeometryReader { playGeo in
                iPadBoardsGrid(playArea: playGeo.size, metrics: metrics)
            }
        } else if !metrics.isPad && metrics.columns == 4 && metrics.rows == 2 {
            GeometryReader { _ in
                iPhoneLandscapeBoardsGrid(proxy: proxy, metrics: metrics)
            }
        } else {
            GeometryReader { _ in
                iPhoneBoardsGrid(proxy: proxy, metrics: metrics)
            }
        }
    }

    private func iPhoneBoardsGrid(proxy: GeometryProxy, metrics: GameLayoutMetrics) -> some View {
        let spacing: CGFloat = 24
        let cols = metrics.columns
        let rows = metrics.rows

        let insets = proxy.safeAreaInsets
        let usableW = Swift.max(1, proxy.size.width - insets.leading - insets.trailing)
        let W = Swift.max(1, usableW - metrics.horizontalPadding * 2)
        let H = proxy.size.height
        let cellSize = gameBoardGridCellSize(
            container: CGSize(width: W, height: H),
            columns: cols,
            rows: rows
        )

        let columns: [GridItem] = Array(
            repeating: GridItem(.fixed(cellSize), spacing: spacing),
            count: cols
        )

        return LazyVGrid(columns: columns, spacing: spacing) {
            boardCells(metrics: metrics, cellSize: cellSize)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// iPhone samo **`width > height`**: **`4×2`**, pun play prostor između HUD-a i donjeg bezbednog pojasa.
    private func iPhoneLandscapeBoardsGrid(proxy: GeometryProxy, metrics: GameLayoutMetrics) -> some View {
        let cols = metrics.columns
        let rows = metrics.rows
        let ins = proxy.safeAreaInsets
        let Wgeo = Swift.max(1, proxy.size.width)
        let Hgeo = Swift.max(1, proxy.size.height)

        let playTopY = iphonePlayAreaTopY(
            safeTop: ins.top,
            metrics: metrics,
            hudInnerSpacing: metrics.hudClusterSpacing,
            gapHUDClusterToBoardGrid: GameView.iphoneLandscapeHUDVStackSpacing
        )
        let bottomMarg = iphoneLandscapeBoardBottomMargin(safeBottom: ins.bottom)
        let ah = Swift.max(1, Hgeo - playTopY - bottomMarg)

        let usableW = Swift.max(1, Wgeo - ins.leading - ins.trailing)
        let aw = Swift.max(1, usableW - metrics.horizontalPadding * CGFloat(2))

        let shortSide = min(Wgeo, Hgeo)
        let gaps = iphoneLandscapeGridGaps(shortSide: shortSide)
        let colGap = gaps.column
        let rowGap = gaps.row

        let layoutCell = gameBoardGridCellSizeIPhoneLandscape(
            availableWidth: aw,
            availableHeight: ah,
            columnGap: colGap,
            rowGap: rowGap
        )

#if DEBUG
        print(
            "IPHONE_LANDSCAPE_LAYOUT width=\(Int(Wgeo)) height=\(Int(Hgeo)) availableWidth=\(Int(aw)) availableHeight=\(Int(ah)) boardSize=\(Int(layoutCell.boardSize)) rowGap=\(Int(rowGap)) columnGap=\(Int(colGap)) maxClamp=\(Int(layoutCell.maxClamp.rounded(.down))) rawUncapped=\(Int(layoutCell.rawUncapped))"
        )
#endif

        let cell = layoutCell.boardSize

        let columnsArr = Array(repeating: GridItem(.fixed(cell), spacing: colGap), count: cols)
        let gridW = CGFloat(cols) * cell + CGFloat(max(0, cols - 1)) * colGap
        let gridH = CGFloat(rows) * cell + CGFloat(max(0, rows - 1)) * rowGap

        let grid = LazyVGrid(columns: columnsArr, spacing: rowGap) {
            boardCells(metrics: metrics, cellSize: cell)
        }
        .frame(width: gridW, height: gridH)
        .offset(y: GameView.iphoneLandscapeGridBiasY)

        return ZStack {
            grid
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func iPadBoardsGrid(playArea: CGSize, metrics: GameLayoutMetrics) -> some View {
        let cols = metrics.columns
        let rows = metrics.rows

        let colSp: CGFloat = {
            if metrics.isLandscape {
                return metrics.isPadCompactWidth ? 22 : 28
            }
            return metrics.isPadCompactWidth ? 24 : 30
        }()
        let rowSp: CGFloat = {
            if metrics.isLandscape { return metrics.isPadCompactWidth ? 24 : 28 }
            return metrics.isPadCompactWidth ? 32 : 40
        }()

        let aw = Swift.max(1, playArea.width)
        let ah = Swift.max(1, playArea.height)
        let cell = gameBoardGridCellSizeIPad(
            availableWidth: aw,
            availableHeight: ah,
            columns: cols,
            rows: rows,
            isCompactWidth: metrics.isPadCompactWidth,
            columnSpacing: colSp,
            rowSpacing: rowSp
        )

        let columnsArr = Array(repeating: GridItem(.fixed(cell), spacing: colSp), count: cols)
        let gridW = CGFloat(cols) * cell + CGFloat(max(0, cols - 1)) * colSp
        let gridH = CGFloat(rows) * cell + CGFloat(max(0, rows - 1)) * rowSp

        let grid = LazyVGrid(columns: columnsArr, spacing: rowSp) {
            boardCells(metrics: metrics, cellSize: cell)
        }
        .frame(width: gridW, height: gridH)

        return ZStack {
            grid
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func boardCells(metrics: GameLayoutMetrics, cellSize: CGFloat) -> some View {
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
                boardSize: cellSize,
                sessionTotalMoves: viewModel.stats.totalMoves,
                focusedScaleBoost: metrics.focusedBoardScaleBoost,
                unfocusedOpacityFactor: metrics.inactiveBoardOpacityFactor
            )
        }
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

        let horizontalPadding: CGFloat = 24
        let topPadding: CGFloat = {
            if isLandscapePhone { return CGFloat(4) }
            return SGSpacing.xs + 2
        }()
        let bottomPadding: CGFloat = max(SGSpacing.sm, insets.bottom * 0.38)

        /// Portrait / iPad; landscape telefon koristi **`hudClusterSpacing`** + kraći HUD.
        let contentSpacing: CGFloat = 12
        let hudClusterSpacing: CGFloat = isLandscapePhone ? GameView.iphoneLandscapeHUDVStackSpacing : 12

        let headerHeight: CGFloat = {
            if isPad {
                /// Kompaktniji HUD — ostaje više **`playArea`** ispod tajmera.
                return isLandscape ? (isPadCompactWidth ? 40 : 42) : (isPadCompactWidth ? 44 : 46)
            }
            if isLandscapePhone && showLearningStrip { return CGFloat(37) }
            if isLandscapePhone { return CGFloat(32) }
            return 46
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

        let columnsCount: Int
        let rowsCount: Int
        /// Matrix: iPhone portrait **2×4** · iPhone landscape **4×2** · iPad portrait **2×4** · iPad landscape **4×2**.
        if isLandscapePhone {
            columnsCount = 4
            rowsCount = 2
        } else if isPhone {
            columnsCount = 2
            rowsCount = 4
        } else if isLandscape {
            columnsCount = 4
            rowsCount = 2
        } else {
            columnsCount = 2
            rowsCount = 4
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
#if os(iOS)
            let m = UIFontMetrics(forTextStyle: .largeTitle)
            let base: CGFloat = {
                if isPad { return 38 }
                if isLandscapePhone { return 34 }
                return 42
            }()
            let scaled = m.scaledValue(for: base)
            return Swift.min(CGFloat(56), Swift.max(CGFloat(34), scaled))
#else
            if isLandscapePhone { return 34 }
            return isPad ? 38 : 42
#endif
        }()

        let scoreFontBase: CGFloat = {
            if isPad { return isPadCompactWidth ? 16.5 : 18 }
            if isLandscapePhone { return 15 }
            return compactHeaderVisual ? 15 : 16.5
        }()

        let scoreStripHeight: CGFloat = {
            if isPad { return isLandscape ? 28 : 30 }
            if isLandscapePhone { return CGFloat(22) }
            return compactHeaderVisual ? 28 : 30
        }()


        return GameLayoutMetrics(
            columns: columnsCount,
            rows: rowsCount,
            boardSize: 0,
            boardGapHorizontal: 24,
            boardGapVertical: 24,
            horizontalPadding: horizontalPadding,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
            contentSpacing: contentSpacing,
            hudClusterSpacing: hudClusterSpacing,
            headerHeight: headerHeight,
            heroTimerFontSize: heroTimerFontSize,
            scoreStripHeight: scoreStripHeight,
            scoreFontBase: scoreFontBase,
            learningStripOccupiedHeight: showLearningStrip ? learningStripHeight : 0,
            compactHeader: compactHeaderVisual,
            compactLearningStripLayout: isLandscapePhone && showLearningStrip,
            focusedBoardScaleBoost: focusBoost,
            inactiveBoardOpacityFactor: inactiveOpacityMul,
            isPad: isPad,
            isLandscape: isLandscape,
            isPadCompactWidth: isPadCompactWidth
        )
    }
}

// MARK: - Time reward HUD (vsAI / learning, pobeda čoveka na tabli)

/// Diskretna linija nagrade: **overlay** ispod reda sata (**fade + drift**), bez dodatne visine HUD-a.
private struct GameClockTimeRewardLine: View {
    let event: TimeRewardEvent
    let announcement: UInt64
    let tokens: XOTheme.Tokens
    let themeMode: SGThemeMode

    @State private var opacity: Double = 0
    @State private var offsetY: CGFloat = 5

    private let fadeInSeconds: CGFloat = 0.32
    private let dwellNanoseconds: UInt64 = 560_000_000
    private let fadeOutSeconds: CGFloat = 0.32

    var body: some View {
        Text(event.clockRowCaption)
            .font(.footnote.weight(.medium))
            .foregroundStyle(tokens.textSecondary.opacity(themeMode == .light ? 0.74 : 0.62))
            .tracking(0.12)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .multilineTextAlignment(.center)
            .opacity(opacity)
            .offset(y: offsetY)
            .sgEngravedText(intensity: .low, color: tokens.textSecondary.opacity(themeMode == .light ? 0.74 : 0.62))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity)
            .onAppear {
                runPulse()
            }
            .id(announcement)
    }

    private func runPulse() {
        opacity = 0
        offsetY = 5
        withAnimation(.easeOut(duration: fadeInSeconds)) {
            opacity = 1
            offsetY = -2
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: dwellNanoseconds)
            withAnimation(.easeIn(duration: fadeOutSeconds)) {
                opacity = 0
                offsetY = -7
            }
        }
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
    /// Razmak između tajmera, skora i learning trake (**`gameHUDCluster`**).
    let hudClusterSpacing: CGFloat
    let headerHeight: CGFloat
    let heroTimerFontSize: CGFloat
    let scoreStripHeight: CGFloat
    let scoreFontBase: CGFloat
    let learningStripOccupiedHeight: CGFloat
    let compactHeader: Bool
    let compactLearningStripLayout: Bool
    let focusedBoardScaleBoost: CGFloat
    let inactiveBoardOpacityFactor: CGFloat
    /// Raspored tabla; iPhone portrait: **`gameBoardGridCellSize`**; iPhone landscape: poseban play-prostor + clamp.
    let isPad: Bool
    let isLandscape: Bool
    let isPadCompactWidth: Bool
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
                + metrics.scoreStripHeight + metrics.contentSpacing
                + (showsLearningStrip ? metrics.learningStripOccupiedHeight + metrics.contentSpacing : 0)

            let playW = w - innerLeft - innerRight
            let playH = Swift.max(1, h - contentTop - metrics.bottomPadding)

            let iphoneLandscapeDebug =
                !metrics.isPad && columnCount == 4 && rowCount == 2 && w > h
            let iphoneLandPlayTop = iphonePlayAreaTopY(
                safeTop: safeInsets.top,
                metrics: metrics,
                hudInnerSpacing: metrics.hudClusterSpacing,
                gapHUDClusterToBoardGrid: GameView.iphoneLandscapeHUDVStackSpacing
            )
            let iphoneLandPlayH =
                Swift.max(
                    1,
                    h - iphoneLandPlayTop - iphoneLandscapeBoardBottomMargin(safeBottom: safeInsets.bottom)
                )

            let ipadGapH: CGFloat =
                metrics.isLandscape
                    ? (metrics.isPadCompactWidth ? 22 : 28)
                    : (metrics.isPadCompactWidth ? 24 : 30)
            let ipadGapV: CGFloat =
                metrics.isLandscape
                    ? (metrics.isPadCompactWidth ? 24 : 28)
                    : (metrics.isPadCompactWidth ? 32 : 40)

            let (gapH, gapV, cell) =
                metrics.isPad
                    ? (
                        ipadGapH,
                        ipadGapV,
                        gameBoardGridCellSizeIPad(
                            availableWidth: playW,
                            availableHeight: playH,
                            columns: columnCount,
                            rows: rowCount,
                            isCompactWidth: metrics.isPadCompactWidth,
                            columnSpacing: ipadGapH,
                            rowSpacing: ipadGapV
                        )
                    )
                    : iphoneLandscapeDebug
                        ? ({
                            let (cg, rg) = iphoneLandscapeGridGaps(shortSide: Swift.min(w, h))
                            let pack = gameBoardGridCellSizeIPhoneLandscape(
                                availableWidth: Swift.max(1, playW),
                                availableHeight: iphoneLandPlayH,
                                columnGap: cg,
                                rowGap: rg
                            )
                            return (
                                cg,
                                rg,
                                pack.boardSize
                            )
                        })()
                        : (
                            CGFloat(24),
                            CGFloat(24),
                            gameBoardGridCellSize(
                                container: CGSize(width: w, height: h),
                                columns: columnCount,
                                rows: rowCount
                            )
                        )

            let gridW =
                CGFloat(columnCount) * cell + CGFloat(max(0, columnCount - 1)) * gapH
            let gridH =
                CGFloat(rowCount) * cell + CGFloat(max(0, rowCount - 1)) * gapV
            let gridX = innerLeft + Swift.max(0, (playW - gridW) / 2)

            let gridY: CGFloat =
                metrics.isPad
                    ? contentTop + Swift.max(0, (playH - gridH) / 2)
                    : iphoneLandscapeDebug
                        ? iphoneLandPlayTop + Swift.max(0, (iphoneLandPlayH - gridH) / 2)
                            + GameView.iphoneLandscapeGridBiasY
                        : contentTop

            Rectangle()
                .stroke(Color.purple.opacity(0.42), lineWidth: 1.25)
                .frame(width: gridW, height: gridH)
                .offset(x: gridX, y: gridY)

            ForEach(0 ..< rowCount, id: \.self) { r in
                ForEach(0 ..< columnCount, id: \.self) { c in
                    Rectangle()
                        .stroke(Color.orange.opacity(0.35), lineWidth: 0.75)
                        .frame(width: cell, height: cell)
                        .offset(
                            x: gridX + CGFloat(c) * (cell + gapH),
                            y: gridY + CGFloat(r) * (cell + gapV)
                        )
                }
            }
        }
        .frame(width: w, height: h)
    }
}

/// Vizuelni DEBUG audit per‑igračkih satova (ručna verifikacija).
private struct GameClockAuditOverlay: View {
    let viewModel: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("clock audit")
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
            Text("active \(markAbbrev(viewModel.currentMark))")
            Text("timerArm \(timerArmLabel(viewModel.debugClockAuditTimerActiveMark))")
            Text("x \(viewModel.xRemainingSeconds)s")
            Text("o \(viewModel.oRemainingSeconds)s")
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.primary)
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.65), lineWidth: 1)
        )
        .padding(.leading, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func markAbbrev(_ m: Mark) -> String {
        switch m {
        case .x: return "X"
        case .o: return "O"
        case .empty: return "—"
        }
    }

    private func timerArmLabel(_ m: Mark?) -> String {
        guard let m else { return "nil" }
        return markAbbrev(m)
    }
}
#endif
