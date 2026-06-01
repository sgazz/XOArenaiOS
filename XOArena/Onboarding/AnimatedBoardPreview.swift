//
//  AnimatedBoardPreview.swift
//  XOArena
//

import SwiftUI

/// Mini arena visuals for onboarding — 4×2 grid matching real game layout.
struct AnimatedBoardPreview: View {
    @Environment(\.sgThemeMode) private var themeMode

    let kind: OnboardingVisualKind

    @State private var revealedBoardCount = 0
    @State private var activeBoardIndex = 0
    @State private var winFlashPhase: CGFloat = 0
    @State private var showTimeReward = false
    @State private var showParticles = false
    @State private var rotationTask: Task<Void, Never>?

    @State private var youClockSeconds = 12
    @State private var opponentClockSeconds = 28
    @State private var youClockExpired = false
    @State private var clockTask: Task<Void, Never>?

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        GeometryReader { geo in
            switch kind {
            case .clockSurvival:
                clockSurvivalVisual
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                arenaGrid(in: geo.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { restartAnimations() }
        .onDisappear {
            rotationTask?.cancel()
            clockTask?.cancel()
        }
        .onChange(of: kind) { _, _ in restartAnimations() }
    }

    @ViewBuilder
    private func arenaGrid(in size: CGSize) -> some View {
        let layout = OnboardingArenaLayout.resolve(in: size)
        VStack(spacing: layout.rowGap) {
            ForEach(0 ..< 2, id: \.self) { row in
                HStack(spacing: layout.columnGap) {
                    ForEach(0 ..< 4, id: \.self) { col in
                        let index = row * 4 + col
                        miniBoard(
                            index: index,
                            side: layout.boardSide,
                            layout: layout
                        )
                    }
                }
            }

            if kind == .timeEconomy {
                timeRewardBadge
                    .padding(.top, SGSpacing.sm)
                    .opacity(showTimeReward ? 1 : 0)
                    .offset(y: showTimeReward ? 0 : 6)
                    .animation(.spring(response: 0.48, dampingFraction: 0.76), value: showTimeReward)
            }
        }
    }

    @ViewBuilder
    private func miniBoard(index: Int, side: CGFloat, layout: OnboardingArenaLayout) -> some View {
        let visible = boardVisible(index: index)
        let highlighted = kind == .activeBoardRotation && activeBoardIndex == index
        let winBoard = kind == .timeEconomy && index == 0

        OnboardingMiniBoardTile(
            boardSide: side,
            marks: marksForBoard(index: index),
            isHighlighted: highlighted,
            showsWinLine: winBoard && winFlashPhase > 0.35,
            winFlashOpacity: winBoard ? winFlashPhase : 0
        )
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.88)
        .animation(.easeInOut(duration: 0.34), value: visible)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: highlighted)
        .overlay {
            if showParticles, winBoard {
                OnboardingWinParticleBurst()
                    .frame(width: side * 1.6, height: side * 1.6)
            }
        }
    }

    private var timeRewardBadge: some View {
        HStack(spacing: SGSpacing.md) {
            timeShiftPill(label: "You", delta: "+8s", isGain: true)
            timeShiftPill(label: "Opponent", delta: "−4s", isGain: false)
        }
    }

    private func timeShiftPill(label: String, delta: String, isGain: Bool) -> some View {
        VStack(spacing: SGSpacing.xs) {
            Text(label)
                .font(SGTypography.small)
                .foregroundStyle(t.textSecondary)
            Text(delta)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(isGain ? t.accent : t.textPrimary.opacity(0.88))
        }
        .padding(.horizontal, SGSpacing.md)
        .padding(.vertical, SGSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                .fill(t.surface.opacity(themeMode == .light ? 0.92 : 0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                .strokeBorder(t.border.opacity(0.45), lineWidth: 1)
        )
    }

    private var clockSurvivalVisual: some View {
        VStack(spacing: SGSpacing.lg) {
            HStack(spacing: SGSpacing.lg) {
                onboardingClockColumn(
                    label: "You",
                    seconds: youClockSeconds,
                    isExpired: youClockExpired,
                    isWinner: false
                )
                onboardingClockColumn(
                    label: "Opponent",
                    seconds: opponentClockSeconds,
                    isExpired: false,
                    isWinner: youClockExpired
                )
            }

            if youClockExpired {
                Text("Time decides the match.")
                    .font(SGTypography.small)
                    .foregroundStyle(t.textSecondary)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.32), value: youClockExpired)
    }

    private func onboardingClockColumn(
        label: String,
        seconds: Int,
        isExpired: Bool,
        isWinner: Bool
    ) -> some View {
        VStack(spacing: SGSpacing.sm) {
            Text(label)
                .font(SGTypography.sectionTitle)
                .foregroundStyle(t.textSecondary)

            Text(formatClock(seconds))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isExpired ? t.textSecondary.opacity(0.45) : t.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.22), value: seconds)

            if isExpired {
                Text("Out of time")
                    .font(SGTypography.small)
                    .foregroundStyle(Color.red.opacity(0.82))
            } else if isWinner {
                Text("Survives")
                    .font(SGTypography.small)
                    .foregroundStyle(t.accent)
            }
        }
        .frame(minWidth: 120)
        .padding(.horizontal, SGSpacing.md)
        .padding(.vertical, SGSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SGRadius.lg, style: .continuous)
                .fill(t.surface.opacity(themeMode == .light ? 0.92 : 0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SGRadius.lg, style: .continuous)
                .strokeBorder(
                    isWinner ? t.accent.opacity(0.55) : t.border.opacity(0.45),
                    lineWidth: isWinner ? 1.5 : 1
                )
        )
    }

    private func formatClock(_ seconds: Int) -> String {
        let bounded = max(0, seconds)
        return String(format: "%d:%02d", bounded / 60, bounded % 60)
    }

    private func boardVisible(index: Int) -> Bool {
        switch kind {
        case .eightBoardReveal:
            return index < revealedBoardCount
        case .activeBoardRotation, .timeEconomy:
            return true
        case .clockSurvival:
            return false
        }
    }

    private func marksForBoard(index: Int) -> [Mark] {
        switch kind {
        case .eightBoardReveal:
            return Array(repeating: Mark.empty, count: GameConstants.cellCount)
        case .activeBoardRotation:
            if index <= activeBoardIndex {
                return samplePartialMarks(for: index)
            }
            return Array(repeating: .empty, count: GameConstants.cellCount)
        case .timeEconomy:
            if index == 0 {
                return winningBoardMarks
            }
            return samplePartialMarks(for: index)
        case .clockSurvival:
            return Array(repeating: .empty, count: GameConstants.cellCount)
        }
    }

    private var winningBoardMarks: [Mark] {
        var cells = Array(repeating: Mark.empty, count: GameConstants.cellCount)
        cells[3] = .x
        cells[4] = .x
        cells[5] = .x
        cells[0] = .o
        cells[8] = .o
        return cells
    }

    private func samplePartialMarks(for boardIndex: Int) -> [Mark] {
        var cells = Array(repeating: Mark.empty, count: GameConstants.cellCount)
        let seed = boardIndex % 3
        switch seed {
        case 0:
            cells[0] = .x
            cells[4] = .o
        case 1:
            cells[2] = .x
            cells[3] = .o
        default:
            cells[1] = .o
            cells[5] = .x
        }
        return cells
    }

    private func restartAnimations() {
        rotationTask?.cancel()
        clockTask?.cancel()
        revealedBoardCount = 0
        activeBoardIndex = 0
        winFlashPhase = 0
        showTimeReward = false
        showParticles = false
        youClockSeconds = 12
        opponentClockSeconds = 28
        youClockExpired = false

        switch kind {
        case .eightBoardReveal:
            runStaggerReveal()
        case .activeBoardRotation:
            runActiveRotation()
        case .timeEconomy:
            runTimeEconomySequence()
        case .clockSurvival:
            runClockSurvivalSequence()
        }
    }

    private func runStaggerReveal() {
        for i in 0 ..< GameConstants.boardCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.09) {
                withAnimation(.easeInOut(duration: 0.32)) {
                    revealedBoardCount = i + 1
                }
            }
        }
    }

    private func runActiveRotation() {
        rotationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.38)) {
                    activeBoardIndex = (activeBoardIndex + 1) % GameConstants.boardCount
                }
            }
        }
    }

    private func runTimeEconomySequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeInOut(duration: 0.28)) {
                winFlashPhase = 1
            }
            showParticles = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            showTimeReward = true
        }
    }

    private func runClockSurvivalSequence() {
        clockTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            while !Task.isCancelled, youClockSeconds > 0 {
                try? await Task.sleep(for: .milliseconds(420))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.2)) {
                    youClockSeconds -= 1
                }
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                youClockExpired = true
            }
        }
    }
}

// MARK: - Layout

private struct OnboardingArenaLayout {
    var boardSide: CGFloat
    var columnGap: CGFloat
    var rowGap: CGFloat

    static func resolve(in size: CGSize) -> OnboardingArenaLayout {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        let colGap = min(14, w * 0.028)
        let rowGap = min(16, h * 0.04)
        let byWidth = (w - colGap * 3) / 4
        let byHeight = (h - rowGap) / 2
        let side = min(byWidth, byHeight).clamped(to: 44 ... 96)
        return OnboardingArenaLayout(boardSide: side, columnGap: colGap, rowGap: rowGap)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Mini board tile

private struct OnboardingMiniBoardTile: View {
    @Environment(\.sgThemeMode) private var themeMode

    let boardSide: CGFloat
    let marks: [Mark]
    var isHighlighted: Bool
    var showsWinLine: Bool
    var winFlashOpacity: CGFloat

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SGRadius.sm, style: .continuous)
                .fill(t.surface.opacity(themeMode == .light ? 0.88 : 0.42))
            RoundedRectangle(cornerRadius: SGRadius.sm, style: .continuous)
                .strokeBorder(t.border.opacity(0.5), lineWidth: 0.75)

            OnboardingMiniGridLines()
                .stroke(t.gridLine.opacity(0.85), lineWidth: 0.85)
                .padding(boardSide * 0.12)

            ForEach(0 ..< GameConstants.cellCount, id: \.self) { idx in
                let mark = marks[idx]
                if mark != .empty {
                    OnboardingMiniMark(mark: mark)
                        .frame(width: boardSide / 3.6, height: boardSide / 3.6)
                        .position(cellCenter(idx))
                }
            }

            if showsWinLine {
                OnboardingMiniWinLine()
                    .stroke(winLineColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .padding(boardSide * 0.14)
                    .opacity(0.95)
                    .shadow(color: winLineColor.opacity(0.55), radius: 4)
            }

            if isHighlighted {
                RoundedRectangle(cornerRadius: SGRadius.sm + 1, style: .continuous)
                    .strokeBorder(t.accent, lineWidth: 2)
                    .shadow(color: t.accent.opacity(0.55), radius: 8)
                    .padding(-2)
            }

            if winFlashOpacity > 0 {
                RoundedRectangle(cornerRadius: SGRadius.sm, style: .continuous)
                    .fill(t.accent.opacity(0.14 * Double(winFlashOpacity)))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: boardSide, height: boardSide)
    }

    private var winLineColor: Color {
        themeMode.isNeonPulse ? SGColors.neonLime : t.accent
    }

    private func cellCenter(_ index: Int) -> CGPoint {
        let cell = boardSide / 3
        let row = index / 3
        let col = index % 3
        return CGPoint(x: cell * (CGFloat(col) + 0.5), y: cell * (CGFloat(row) + 0.5))
    }
}

private struct OnboardingMiniGridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let thirdW = rect.width / 3
        let thirdH = rect.height / 3
        path.move(to: CGPoint(x: thirdW, y: rect.minY))
        path.addLine(to: CGPoint(x: thirdW, y: rect.maxY))
        path.move(to: CGPoint(x: thirdW * 2, y: rect.minY))
        path.addLine(to: CGPoint(x: thirdW * 2, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: thirdH))
        path.addLine(to: CGPoint(x: rect.maxX, y: thirdH))
        path.move(to: CGPoint(x: rect.minX, y: thirdH * 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: thirdH * 2))
        return path
    }
}

private struct OnboardingMiniWinLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: y))
        path.addLine(to: CGPoint(x: rect.maxX, y: y))
        return path
    }
}

private struct OnboardingMiniMark: View {
    @Environment(\.sgThemeMode) private var themeMode

    let mark: Mark

    private var markColor: Color {
        let t = XOTheme.tokens(for: themeMode)
        switch mark {
        case .x:
            return themeMode.isNeonPulse ? SGColors.neonMagenta : t.accent
        case .o:
            return themeMode.isNeonPulse ? SGColors.neonCyan : t.textPrimary.opacity(0.82)
        case .empty:
            return .clear
        }
    }

    var body: some View {
        Group {
            switch mark {
            case .x:
                Image(systemName: "xmark")
            case .o:
                Image(systemName: "circle")
            case .empty:
                EmptyView()
            }
        }
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundStyle(markColor)
        .frame(width: 16, height: 16)
    }
}

private struct OnboardingWinParticleBurst: View {
    @State private var expand = false

    var body: some View {
        ZStack {
            ForEach(0 ..< 10, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 4, height: 4)
                    .offset(
                        x: expand ? cos(Double(i) / 10 * .pi * 2) * 28 : 0,
                        y: expand ? sin(Double(i) / 10 * .pi * 2) * 28 : 0
                    )
                    .opacity(expand ? 0 : 0.85)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                expand = true
            }
        }
        .allowsHitTesting(false)
    }
}
