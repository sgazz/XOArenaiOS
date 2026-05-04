//
//  WatchBoardView.swift
//  XOArenaWatch
//

import SwiftUI

/// Pure string grid (**no** `GameSession`, **`Mark`**, or shared board types visible to SwiftUI layout).
struct WatchBoardView: View {
    let cells: [String]
    let boardID: UUID
    var locked: Bool
    /// `true` when the active slab is **`inProgress`** (from coordinator sync, not derived here from engine).
    var allowsInput: Bool
    /// Subtle winning-line emphasis (e.g. during completed-slab preview).
    var highlightIndices: Set<Int>? = nil
    /// Draw slab preview — subtle shared opacity sway.
    var isDrawPreviewSoft: Bool = false
    /// When **`false`** (scene background / coordinator pause), do not run repeating draw **`Timer`**.
    var drawEffectsEnabled: Bool = true
    /// Last AI cell → quick fade-in.
    var aiFadeCellIndex: Int?
    /// Adaptive gap between grid cells (**2× horizontal + vertical** deducted from square side).
    var boardGap: CGFloat = 3.5
    var cellCornerRadius: CGFloat = 12
    let onTap: (Int) -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var burstScales: [CGFloat] = Array(repeating: 1, count: 9)
    @State private var aiFadeOpacities: [CGFloat] = Array(repeating: 1, count: 9)
    @State private var drawLow = false
    @State private var drawTimer: Timer?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let gap = boardGap
            let cellSide = max((side - gap * 2) / 3, 8)
            let radius = cellCornerRadius
            let columns = [
                GridItem(.flexible(), spacing: gap, alignment: .center),
                GridItem(.flexible(), spacing: gap, alignment: .center),
                GridItem(.flexible(), spacing: gap, alignment: .center),
            ]

            LazyVGrid(columns: columns, spacing: gap) {
                ForEach(0 ..< 9, id: \.self) { index in
                    gridCell(at: index, size: cellSide, cellRadius: radius)
                }
            }
            .id(boardID)
            .opacity(isDrawPreviewSoft ? (drawLow ? 0.9 : 1) : 1)
            .animation(isDrawPreviewSoft ? .easeInOut(duration: 0.35) : nil, value: drawLow)
            .frame(width: side, height: side, alignment: .center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            reconcileDrawBreathingTimerIfNeeded()
        }
        .onChange(of: isDrawPreviewSoft) { _, _ in
            reconcileDrawBreathingTimerIfNeeded()
        }
        .onChange(of: drawEffectsEnabled) { _, _ in
            reconcileDrawBreathingTimerIfNeeded()
        }
        .onChange(of: scenePhase) { _, _ in
            reconcileDrawBreathingTimerIfNeeded()
        }
        .onDisappear {
            drawTimer?.invalidate()
            drawTimer = nil
            drawLow = false
        }
        .onChange(of: aiFadeCellIndex) { _, newIdx in
            guard let idx = newIdx, (0 ..< 9).contains(idx) else { return }
            aiFadeOpacities[idx] = 0.28
            withAnimation(.easeOut(duration: WatchFeelTiming.aiMarkFadeSeconds)) {
                aiFadeOpacities[idx] = 1
            }
        }
    }

    /// **`scenePhase`** must gate the repeating **`Timer`** immediately on **`inactive`** / **`background`** (before **`allowsLiveBoardEffects`** propagates).
    private func reconcileDrawBreathingTimerIfNeeded() {
        drawTimer?.invalidate()
        drawTimer = nil
        drawLow = false
        guard scenePhase == .active else { return }
        guard drawEffectsEnabled, isDrawPreviewSoft else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                drawLow.toggle()
            }
        }
        drawTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @ViewBuilder
    private func gridCell(at index: Int, size: CGFloat, cellRadius: CGFloat) -> some View {
        let glyph = cellGlyph(at: index)
        let canTapCell = allowsInput && !locked && glyph.isEmpty
        let highlighted = highlightIndices?.contains(index) == true

        togglableCell(
            index: index,
            glyph: glyph,
            size: size,
            cellRadius: cellRadius,
            highlighted: highlighted,
            canTapCell: canTapCell
        )
    }

    @ViewBuilder
    private func togglableCell(
        index: Int,
        glyph: String,
        size: CGFloat,
        cellRadius: CGFloat,
        highlighted: Bool,
        canTapCell: Bool
    ) -> some View {
        if canTapCell {
            Button {
                triggerTapBurst(at: index)
                onTap(index)
            } label: {
                cellCore(
                    glyph: glyph,
                    size: size,
                    cellRadius: cellRadius,
                    highlighted: highlighted,
                    index: index
                )
            }
            .buttonStyle(.plain)
        } else {
            cellCore(glyph: glyph, size: size, cellRadius: cellRadius, highlighted: highlighted, index: index)
        }
    }

    private func triggerTapBurst(at index: Int) {
        guard (0 ..< 9).contains(index) else { return }
        withAnimation(.easeOut(duration: 0.045)) {
            burstScales[index] = 0.96
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + WatchFeelTiming.tapHoldSeconds) {
            withAnimation(.easeOut(duration: WatchFeelTiming.tapReturnSeconds)) {
                burstScales[index] = 1
            }
        }
    }

    @ViewBuilder
    private func cellCore(
        glyph: String,
        size: CGFloat,
        cellRadius: CGFloat,
        highlighted: Bool,
        index: Int
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cellRadius, style: .continuous)
                .fill(cellFill(highlighted: highlighted))
                .overlay(
                    RoundedRectangle(cornerRadius: cellRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(locked ? 0.04 : 0.14),
                                    Color.black.opacity(0.02),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cellRadius, style: .continuous)
                        .strokeBorder(cellBorder(highlighted: highlighted), lineWidth: highlighted ? 2 : 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 0, x: 0, y: 1)
                .shadow(color: highlighted ? WatchQuietTheme.ColorToken.win.opacity(0.42) : .clear, radius: 5, x: 0, y: 0)

            if glyph.isEmpty {
                Color.clear
            } else {
                WatchBoardMark(symbol: glyph, drawableSide: size * 0.72)
                    .opacity(aiFadeOpacities[index])
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .scaleEffect(burstScales[index])
    }

    private func cellFill(highlighted: Bool) -> Color {
        if highlighted {
            return WatchQuietTheme.ColorToken.win.opacity(0.22)
        }
        return WatchQuietTheme.ColorToken.surface.opacity(locked ? 0.62 : 1)
    }

    private func cellBorder(highlighted: Bool) -> Color {
        if highlighted {
            return WatchQuietTheme.ColorToken.win.opacity(0.72)
        }
        return WatchQuietTheme.ColorToken.border
    }

    private func cellGlyph(at index: Int) -> String {
        guard index < cells.count else { return "" }
        let s = cells[index]
        guard s == "X" || s == "O" else { return "" }
        return s
    }
}
