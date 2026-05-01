//
//  IntroXOMonogramView.swift
//  XOArena
//

import SwiftUI

/// Thin intro wrapper — uses canonical **`XOArenaLogoView`** (**`.intro`**).
struct IntroXOMonogramView: View {
    var body: some View {
        XOArenaLogoView(style: .intro)
            .accessibilityHidden(true)
    }
}
