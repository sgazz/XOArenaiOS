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
            let tint = accent ? t.accentSubtle.opacity(themeMode == .light ? 0.38 : 0.42) : t.gridLine.opacity(0.92)
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

        // Vertical 1 — blaga S‑krivina (ne savršeno ravno)
        path.move(to: CGPoint(x: ox + step + 0.52, y: oy + s * 0.024))
        path.addQuadCurve(
            to: CGPoint(x: ox + step - 0.82, y: oy + s * 0.982),
            control: CGPoint(x: ox + step + 1.38, y: oy + s * 0.505 + 2.05)
        )

        // Vertical 2
        path.move(to: CGPoint(x: ox + step * 2 - 0.62, y: oy + s * 0.028))
        path.addQuadCurve(
            to: CGPoint(x: ox + step * 2 + 0.66, y: oy + s * 0.968),
            control: CGPoint(x: ox + step * 2 - 2.08, y: oy + s * 0.462 - 0.65)
        )

        // Horizontal 1
        path.move(to: CGPoint(x: ox + s * 0.024, y: oy + step - 0.42))
        path.addQuadCurve(
            to: CGPoint(x: ox + s * 0.978, y: oy + step + 0.52),
            control: CGPoint(x: ox + s * 0.485 - 2.35, y: oy + step - 1.62)
        )

        // Horizontal 2
        path.move(to: CGPoint(x: ox + s * 0.032, y: oy + step * 2 + 0.68))
        path.addQuadCurve(
            to: CGPoint(x: ox + s * 0.962, y: oy + step * 2 - 0.48),
            control: CGPoint(x: ox + s * 0.455 + 2.15, y: oy + step * 2 + 1.42)
        )

        return path
    }
}
