//
//  WatchBoardView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchBoardView: View {
    let board: XOBoard
    var locked: Bool
    let onTap: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let gap: CGFloat = 5
            let cellSide = max((side - gap * 2) / 3, 8)

            VStack(spacing: gap) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<3, id: \.self) { col in
                            let idx = row * 3 + col
                            cell(at: idx, size: cellSide)
                        }
                    }
                }
            }
            .frame(width: side, height: side, alignment: .center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func cell(at index: Int, size: CGFloat) -> some View {
        let mark = board.cells[index].mark
        Button {
            onTap(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(WatchColors.cell.opacity(locked ? 0.55 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(WatchColors.border, lineWidth: 1)
                    )
                markText(mark)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .disabled(locked || mark != .empty || board.playState != .inProgress)
    }

    @ViewBuilder
    private func markText(_ mark: Mark) -> some View {
        switch mark {
        case .x:
            Text("X")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(WatchColors.ink)
        case .o:
            Text("O")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(WatchColors.ink)
        case .empty:
            Color.clear
        }
    }
}
