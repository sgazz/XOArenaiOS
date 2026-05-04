//
//  WatchBoardMark.swift
//  XOArenaWatch — unified stroke-weight X / O marks.
//

import SwiftUI

struct WatchBoardMark: View {
    let symbol: String
    /// Side length of the drawable area inside the cell.
    var drawableSide: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let side = min(drawableSide, min(geo.size.width, geo.size.height) - 4)
            let inset = side * 0.12
            ZStack {
                if symbol == "X" {
                    markX(side: side, inset: inset, lineWidth: max(2, side * 0.09))
                } else if symbol == "O" {
                    markO(side: side, inset: inset, lineWidth: max(2.6, side * 0.11))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    private func markX(side: CGFloat, inset: CGFloat, lineWidth: CGFloat) -> some View {
        let ink = WatchQuietTheme.ColorToken.textMain
        return Canvas { cx, size in
            let w = max(1, lineWidth)
            let p = Path { path in
                path.move(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: side - inset, y: side - inset))
                path.move(to: CGPoint(x: side - inset, y: inset))
                path.addLine(to: CGPoint(x: inset, y: side - inset))
            }
            cx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        }
        .frame(width: side, height: side)
    }

    private func markO(side: CGFloat, inset: CGFloat, lineWidth: CGFloat) -> some View {
        let ink = WatchQuietTheme.ColorToken.textMain
        return Canvas { cx, size in
            let w = max(1, lineWidth)
            let r = (side - inset * 2) / 2
            let c = CGPoint(x: side / 2, y: side / 2)
            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            let p = Path(ellipseIn: rect)
            cx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: w, lineCap: .round))
        }
        .frame(width: side, height: side)
    }
}
