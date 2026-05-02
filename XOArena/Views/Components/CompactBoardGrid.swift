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
    /// Per playable cell tap (focused board checks live in **ViewModel**).
    let permitsCellPlacement: (Int) -> Bool
    let onSelectCell: (Int) -> Void
    var boardSize: CGFloat

    /// Ensures frame dimensions are finite and non-negative to avoid runtime layout errors.
    private var safeBoardSize: CGFloat {
        // Guard against NaN or infinite values
        if !boardSize.isFinite || boardSize.isNaN {
            return 0
        }
        // Clamp to a minimum of 0 to avoid negative sizes
        return max(0, boardSize)
    }

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    private var boardInkDrift: CGFloat {
        InkVariance.boardBorderIntensity(boardIndex: boardIndex)
    }

    var body: some View {
        SGCard(isActive: isFocused, borderTone: boardInkDrift) {
            VStack(alignment: .leading, spacing: SGSpacing.sm) {
                ZStack(alignment: .leading) {
                    if isFocused {
                        Text("ACTIVE")
                            .font(SGTypography.inkActiveStamp)
                            .tracking(2.8)
                            .foregroundStyle(t.accentSubtle.opacity(0.64))
                            .accessibilityHidden(true)
                    }
                }
                .frame(height: 11)

                FreehandBoardView(accent: isFocused) {
                    boardCells
                }
                .clipShape(RoundedRectangle(cornerRadius: SGRadius.sm, style: .continuous))
            }
        }
        .frame(width: safeBoardSize, height: safeBoardSize)
        .rotationEffect(.degrees(boardTiltDegrees))
        .opacity(boardSheetOpacity)
        .scaleEffect(InkVariance.boardPresenceScale(boardIndex: boardIndex))
    }

    private var boardCells: some View {
        VStack(spacing: 4) {
            ForEach(0..<GameConstants.gridSide, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<GameConstants.gridSide, id: \.self) { column in
                        let index = row * GameConstants.gridSide + column
                        cellButton(at: index)
                    }
                }
            }
        }
    }

    private func cellButton(at index: Int) -> some View {
        let edgeTone = CGFloat(InkVariance.cellEdgeOpacityDrift(boardIndex: boardIndex, cellIndex: index))
        let baseStrokeOpacity = isFocused ? 0.42 : 0.21
        let strokeOpacity = min(1, CGFloat(baseStrokeOpacity * edgeTone))

        return Button {
            guard !cellDisabled(at: index) else { return }
            onSelectCell(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: SGRadius.sm - 2, style: .continuous)
                    .fill(cellFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGRadius.sm - 2, style: .continuous)
                            .strokeBorder(cellStrokeColor(opacity: strokeOpacity), lineWidth: 0.6)
                    )

                CellMarkReveal(
                    boardIndex: boardIndex,
                    cellIndex: index,
                    mark: board.cells[index].mark
                )
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(SGSpacing.xs)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(HandInkRippleBoardCellStyle())
        .disabled(cellDisabled(at: index))
        .opacity(cellDisabled(at: index) ? 0.38 : 1)
    }

    private func cellStrokeColor(opacity: CGFloat) -> Color {
        switch themeMode {
        case .light:
            return SGColors.borderLightWarm.opacity(opacity * 1.05)
        case .dark:
            return SGColors.borderDark.opacity(opacity)
        }
    }

    private var cellFill: Color {
        switch themeMode {
        case .light:
            return isFocused
                ? SGColors.paperSurfaceLight.opacity(0.62)
                : SGColors.paperBackgroundLight.opacity(0.38)
        case .dark:
            return isFocused ? SGColors.surfaceLight.opacity(0.068) : SGColors.surfaceDark.opacity(0.33)
        }
    }

    private func cellDisabled(at index: Int) -> Bool {
        !permitsCellPlacement(index)
    }

    private var boardTiltDegrees: Double {
        let table: [Double] = [-0.48, 0.41, -0.32, 0.51, -0.40, 0.36, -0.52, 0.33]
        return table[boardIndex % table.count]
    }

    private var boardSheetOpacity: Double {
        let table: [Double] = [1.0, 0.958, 0.976, 0.939, 0.966, 0.951, 0.982, 0.943]
        return table[boardIndex % table.count]
    }
}

private struct CellMarkReveal: View {
    let boardIndex: Int
    let cellIndex: Int
    let mark: Mark
    @State private var inkScale: CGFloat = 1
    @State private var inkOpacity: Double = 1

    /// Sporiji talas — mastilo koje upija u papir (**0.28** s).
    private static let pulseDuration: CGFloat = 0.28

    var body: some View {
        MarkGlyphView(mark: mark, boardIndex: boardIndex, cellIndex: cellIndex)
            .scaleEffect(mark == .empty ? 1 : inkScale)
            .opacity(mark == .empty ? 1 : inkOpacity)
            .onChange(of: mark) { old, new in
                guard old == .empty, new != .empty else { return }
                inkScale = 0.95
                inkOpacity = 0.88
                withAnimation(.easeOut(duration: Self.pulseDuration)) {
                    inkScale = 1
                    inkOpacity = 1
                }
            }
            .onAppear {
                if mark != .empty {
                    inkScale = 1
                    inkOpacity = 1
                }
            }
    }
}

