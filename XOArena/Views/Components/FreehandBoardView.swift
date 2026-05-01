//
//  FreehandBoardView.swift
//  XOArena
//

import SwiftUI

/// Paper playfield: playable cells underneath, hand-drawn guides on top.
struct FreehandBoardView<Content: View>: View {
    var accent: Bool
    @ViewBuilder var underneath: () -> Content

    var body: some View {
        ZStack {
            underneath()
            FreehandBoardLinesView(accent: accent)
        }
    }
}
