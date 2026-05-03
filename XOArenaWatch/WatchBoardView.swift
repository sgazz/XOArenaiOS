//
//  WatchBoardView.swift
//  XOArenaWatch
//

import SwiftUI

struct WatchBoardView: View {
    let cells: [Mark?]
    let phase: BoardPlayState
    var locked: Bool
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
                    cellView(at: index, size: cellSide)
                }
            }
            .frame(width: side, height: side, alignment: .center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func cellView(at index: Int, size: CGFloat) -> some View {
        let mark = resolvedMark(at: index)
        let snapshot = index < cells.count ? cells[index] : nil

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
                markGlyph(mark)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .disabled(locked || mark != .empty || phase != .inProgress)
        #if DEBUG
        .onAppear {
            Self.logCellRender(index: index, mark: snapshot)
        }
        #endif
    }

    private func resolvedMark(at index: Int) -> Mark {
        guard index < cells.count, let m = cells[index] else { return .empty }
        return m
    }

    @ViewBuilder
    private func markGlyph(_ mark: Mark) -> some View {
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

    #if DEBUG
    private static func logCellRender(index: Int, mark: Mark?) {
        let desc: String
        if let m = mark {
            desc = m.rawValue
        } else {
            desc = "nil"
        }
        print("[XOArenaWatch] CELL_RENDER index=\(index) mark=\(desc)")
    }
    #endif
}
