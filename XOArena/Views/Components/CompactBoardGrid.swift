//
//  CompactBoardGrid.swift
//  XOArena
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CompactBoardGrid: View {
    @Environment(\.sgThemeMode) private var themeMode

    let boardIndex: Int
    let board: XOBoard
    let isFocused: Bool
    let permitsCellPlacement: (Int) -> Bool
    let onSelectCell: (Int) -> Void
    var boardSize: CGFloat
    /// Trenutačni `stats.totalMoves` iz sesije (za seme oznaka pri postavljanju).
    var sessionTotalMoves: Int = 0
    var focusedScaleBoost: CGFloat = 1.05
    var unfocusedOpacityFactor: CGFloat = 0.85

    private enum StoneLight {
        static let ink = Color(red: 43 / 255, green: 38 / 255, blue: 34 / 255)
    }

    private var safeBoardSize: CGFloat {
        if !boardSize.isFinite || boardSize.isNaN {
            return 0
        }
        return max(0, boardSize)
    }

    private var winningCellIndices: Set<Int> {
        Set(BoardEvaluator.winningLine(in: board)?.indices ?? [])
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            FreehandBoardView(accent: isFocused, boardIndex: boardIndex) {
                boardCells
            }
            if let winLine = BoardEvaluator.winningLine(in: board)?.indices {
                BoardWinLineGlowView(cellIndices: winLine)
            }
            if isFocused {
                Circle()
                    .fill(focusDotColor)
                    .frame(width: 4, height: 4)
                    .padding(.leading, 6)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: safeBoardSize, height: safeBoardSize)
        .scaleEffect(InkVariance.boardPresenceScale(boardIndex: boardIndex) * presenceScaleMultiply)
        .opacity(boardSheetOpacity * presenceOpacityMultiply)
        .accessibilityLabel(isFocused ? "Active board \(boardIndex + 1)" : "Board \(boardIndex + 1)")
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    private var presenceScaleMultiply: CGFloat {
        isFocused ? focusedScaleBoost : 1
    }

    private var presenceOpacityMultiply: CGFloat {
        isFocused ? 1 : CGFloat(unfocusedOpacityFactor)
    }

    private var boardCells: some View {
        VStack(spacing: 0) {
            ForEach(0..<GameConstants.gridSide, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<GameConstants.gridSide, id: \.self) { column in
                        let index = row * GameConstants.gridSide + column
                        cellButton(at: index)
                    }
                }
            }
        }
    }

    private func cellButton(at index: Int) -> some View {
        Button {
            guard !cellDisabled(at: index) else { return }
            onSelectCell(index)
        } label: {
            ZStack {
                Color.clear.contentShape(Rectangle())
                CellMarkReveal(
                    boardIndex: boardIndex,
                    cellIndex: index,
                    mark: board.cells[index].mark,
                    sessionTotalMoves: sessionTotalMoves,
                    isWinningCell: winningCellIndices.contains(index)
                )
                .minimumScaleFactor(0.56)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(2)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(HandInkRippleBoardCellStyle())
        .disabled(cellDisabled(at: index))
        .opacity(cellDisabled(at: index) ? 0.42 : 1)
    }

    private func cellDisabled(at index: Int) -> Bool {
        !permitsCellPlacement(index)
    }

    private var focusDotColor: Color {
        switch themeMode {
        case .light:
            return StoneLight.ink.opacity(0.52)
        case .dark:
            return Color.white.opacity(0.38)
        case .neonPulse:
            return SGColors.neonCyanGrid.opacity(0.65)
        }
    }

    private var boardSheetOpacity: Double {
        let table: [Double] = [1.0, 0.968, 0.982, 0.956, 0.976, 0.962, 0.988, 0.954]
        return table[boardIndex % table.count]
    }
}

private struct CellMarkReveal: View {
    @Environment(\.sgThemeMode) private var themeMode

    let boardIndex: Int
    let cellIndex: Int
    let mark: Mark
    let sessionTotalMoves: Int
    var isWinningCell: Bool = false
    @State private var inkScale: CGFloat = 1
    @State private var inkOpacity: Double = 1
    @State private var placementPulseActive = false
    /// Zaključava broj poteza u trenutku punjenja ćelije — varijanta oznake ne mijenja se pri kasnijim potezima drugdje.
    @State private var placementMoveOrdinal: Int?

    private static let pulseDuration: CGFloat = 0.28

    private var neonEmphasis: NeonMarkEmphasis {
        if isWinningCell { return .winning }
        if placementPulseActive { return .placementPulse }
        return .standard
    }

    var body: some View {
        MarkGlyphView(
            mark: mark,
            boardIndex: boardIndex,
            cellIndex: cellIndex,
            placementMoveOrdinal: placementMoveOrdinal,
            neonEmphasis: themeMode.isNeonPulse ? neonEmphasis : .standard
        )
            .scaleEffect(mark == .empty ? 1 : inkScale)
            .opacity(mark == .empty ? 1 : inkOpacity)
            .onChange(of: mark) { old, new in
                if old == .empty, new != .empty {
                    if placementMoveOrdinal == nil {
                        placementMoveOrdinal = sessionTotalMoves
                    }
                    inkScale = themeMode.isNeonPulse ? 0.92 : 0.95
                    inkOpacity = themeMode.isNeonPulse ? 0.82 : 0.88
                    placementPulseActive = themeMode.isNeonPulse
                    withAnimation(.easeOut(duration: Self.pulseDuration)) {
                        inkScale = 1
                        inkOpacity = 1
                    }
                    if themeMode.isNeonPulse {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(Self.pulseDuration)) {
                            placementPulseActive = false
                        }
                    }
                    return
                }
                if new == .empty {
                    placementMoveOrdinal = nil
                    placementPulseActive = false
                }
            }
            .onAppear {
                if mark != .empty, placementMoveOrdinal == nil {
                    placementMoveOrdinal = sessionTotalMoves
                }
                if mark != .empty {
                    inkScale = 1
                    inkOpacity = 1
                }
            }
    }
}
