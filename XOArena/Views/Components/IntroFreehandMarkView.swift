//
//  IntroFreehandMarkView.swift
//  XOArena
//

import SwiftUI

/// Tiny 3×3 freehand slab with one **X** and one **O** — quiet identity, not gameplay UI.
struct IntroFreehandMarkView: View {
    @ScaledMetric(relativeTo: .body) private var markSide: CGFloat = 64

    var body: some View {
        let cell = max(14, markSide / 3)
        ZStack {
            FreehandBoardLinesView(accent: false)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    markCell(.x, cellIndex: 0, side: cell)
                    Color.clear.frame(width: cell, height: cell)
                    Color.clear.frame(width: cell, height: cell)
                }
                HStack(spacing: 0) {
                    Color.clear.frame(width: cell, height: cell)
                    Color.clear.frame(width: cell, height: cell)
                    Color.clear.frame(width: cell, height: cell)
                }
                HStack(spacing: 0) {
                    Color.clear.frame(width: cell, height: cell)
                    Color.clear.frame(width: cell, height: cell)
                    markCell(.o, cellIndex: 8, side: cell)
                }
            }
            .frame(width: markSide, height: markSide)
        }
        .frame(width: markSide, height: markSide)
        .opacity(0.88)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func markCell(_ mark: Mark, cellIndex: Int, side: CGFloat) -> some View {
        MarkGlyphView(mark: mark, boardIndex: 7, cellIndex: cellIndex)
            .frame(width: side, height: side)
    }
}
