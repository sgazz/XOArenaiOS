//
//  FreehandBoardView.swift
//  XOArena
//

import SwiftUI

/// Paper playfield: playable cells underneath, hand-drawn guides on top.
struct FreehandBoardView<Content: View>: View {
    @Environment(\.sgThemeMode) private var themeMode

    var accent: Bool
    /// Stabilna per-tabla variacija crtica (`FreehandBoardLinesView`).
    var boardIndex: Int = 0
    @ViewBuilder var underneath: () -> Content

    var body: some View {
        ZStack {
            if themeMode.isNeonPulse {
                neonBoardCardBackground
            }
            underneath()
            FreehandBoardLinesView(boardIndex: boardIndex, accent: accent)
        }
    }

    private var neonBoardCardBackground: some View {
        RoundedRectangle(cornerRadius: SGRadius.sm, style: .continuous)
            .fill(SGColors.neonBoardCardFill)
            .overlay(
                RoundedRectangle(cornerRadius: SGRadius.sm, style: .continuous)
                    .strokeBorder(SGColors.neonBoardCardBorder, lineWidth: 0.75)
            )
            .padding(1.5)
    }
}
