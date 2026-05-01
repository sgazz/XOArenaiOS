//
//  FreehandBoardLinesView.swift
//  XOArena
//

import SwiftUI

/// Quiet hand-ruled tic-tac-toe guides: imperfect curves, graphite / plum accents by theme.
struct FreehandBoardLinesView: View {
    @Environment(\.sgThemeMode) private var themeMode

    var accent: Bool = false

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let tint = accent ? t.accentSubtle.opacity(themeMode == .light ? 0.44 : 0.48) : t.gridLine.opacity(0.92)
            let innerLine: CGFloat = {
                guard themeMode == .light else { return 0.88 }
                return accent ? 1.06 : 0.94
            }()

            ZStack {
                FreehandBoardGridShape()
                    .stroke(tint.opacity(themeMode == .light ? 0.32 : 0.28), style: StrokeStyle(lineWidth: 2.55, lineCap: .round, lineJoin: .round))
                FreehandBoardGridShape()
                    .stroke(tint.opacity(themeMode == .light ? 0.68 : 0.7), style: StrokeStyle(lineWidth: 1.52, lineCap: .round, lineJoin: .round))
                FreehandBoardGridShape()
                    .stroke(tint, style: StrokeStyle(lineWidth: innerLine, lineCap: .round, lineJoin: .round))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
}

private struct FreehandBoardGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        guard s > 2 else { return Path() }

        let step = s / 3
        let ox = rect.minX + (rect.width - s) / 2
        let oy = rect.minY + (rect.height - s) / 2

        var path = Path()

        // Vertical 1 — slight S-bias
        path.move(to: CGPoint(x: ox + step + 0.4, y: oy + s * 0.02))
        path.addQuadCurve(
            to: CGPoint(x: ox + step - 0.95, y: oy + s * 0.98),
            control: CGPoint(x: ox + step + 1.25, y: oy + s * 0.51 + 1.8)
        )

        // Vertical 2 — different bow
        path.move(to: CGPoint(x: ox + step * 2 - 0.55, y: oy + s * 0.03))
        path.addQuadCurve(
            to: CGPoint(x: ox + step * 2 + 0.7, y: oy + s * 0.97),
            control: CGPoint(x: ox + step * 2 - 1.9, y: oy + s * 0.47 - 0.8)
        )

        // Horizontal 1
        path.move(to: CGPoint(x: ox + s * 0.02, y: oy + step - 0.5))
        path.addQuadCurve(
            to: CGPoint(x: ox + s * 0.985, y: oy + step + 0.45),
            control: CGPoint(x: ox + s * 0.49 - 2.6, y: oy + step - 1.4)
        )

        // Horizontal 2
        path.move(to: CGPoint(x: ox + s * 0.03, y: oy + step * 2 + 0.6))
        path.addQuadCurve(
            to: CGPoint(x: ox + s * 0.97, y: oy + step * 2 - 0.55),
            control: CGPoint(x: ox + s * 0.46 + 1.9, y: oy + step * 2 + 1.3)
        )

        return path
    }
}
