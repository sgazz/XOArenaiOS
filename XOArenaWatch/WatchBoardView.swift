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
    let onTap: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let gap: CGFloat = 5
            let cellSide = max((side - gap * 2) / 3, 8)
            let columns = [
                GridItem(.flexible(), spacing: gap, alignment: .center),
                GridItem(.flexible(), spacing: gap, alignment: .center),
                GridItem(.flexible(), spacing: gap, alignment: .center),
            ]

            LazyVGrid(columns: columns, spacing: gap) {
                ForEach(0..<9, id: \.self) { index in
                    gridCell(at: index, size: cellSide)
                }
            }
            .id(boardID)
            .frame(width: side, height: side, alignment: .center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func gridCell(at index: Int, size: CGFloat) -> some View {
        let glyph = cellGlyph(at: index)
        let canTapCell = allowsInput && !locked && glyph.isEmpty

        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(WatchColors.cell.opacity(locked ? 0.55 : 1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(WatchColors.border, lineWidth: 1)
                )
            Text(glyph)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(WatchColors.ink)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .allowsHitTesting(canTapCell)
        .onTapGesture {
            onTap(index)
        }
    }

    private func cellGlyph(at index: Int) -> String {
        guard index < cells.count else { return "" }
        let s = cells[index]
        guard s == "X" || s == "O" else { return "" }
        return s
    }
}
