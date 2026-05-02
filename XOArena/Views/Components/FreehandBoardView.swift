//
//  FreehandBoardView.swift
//  XOArena
//

import SwiftUI

/// Paper playfield: playable cells underneath, hand-drawn guides on top.
struct FreehandBoardView<Content: View>: View {
    var accent: Bool
    /// Stabilna per-tabla variacija crtica (`FreehandBoardLinesView`).
    var boardIndex: Int = 0
    @ViewBuilder var underneath: () -> Content

    var body: some View {
        ZStack {
            underneath()
            FreehandBoardLinesView(boardIndex: boardIndex, accent: accent)
        }
    }
}
