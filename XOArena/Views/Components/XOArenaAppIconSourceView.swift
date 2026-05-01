//
//  XOArenaAppIconSourceView.swift
//  XOArena
//
//  1024×1024 raster source for Xcode **App Icon** slots. No typography; calm cappuccino field + organic mark.
//

import SwiftUI

/// Exactly **1024×1024** layout for App Store / asset catalog ingestion.
/// Warm slab **#F3EDE6**, hairline luminance drift (InkSeed / infinity-paper adjacent), **`XOArenaLogoView`** centred with optical bias.
struct XOArenaAppIconSourceView: View {
    /// Canvas edge (pixels at export scale 1×).
    private let side: CGFloat = 1024
    /// Mark occupies ~ 58% of canvas — midpoint of requested 55–65%.
    private let logoNominalFraction: CGFloat = 0.58
    /// Sub‑pixel upward / trailing nudge — compensates perceptual mass of strokes.
    private let opticalShift = CGSize(width: 5, height: -11)

    private var cappuccinoBase: Color { Color(red: 243 / 255, green: 237 / 255, blue: 230 / 255) }
    /// Imperceptibly warmer toward top (not glossy lift).
    private var cappuccinoHead: Color { Color(red: 247 / 255, green: 241 / 255, blue: 234 / 255) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [cappuccinoHead, cappuccinoBase],
                startPoint: .top,
                endPoint: .bottom
            )
            XOArenaLogoView(style: .appIcon)
                .frame(width: side * logoNominalFraction, height: side * logoNominalFraction)
                .offset(x: opticalShift.width, y: opticalShift.height)
        }
        .frame(width: side, height: side)
        .clipped()
    }
}

#if DEBUG
#Preview("App Icon · 256 px canvas") {
    XOArenaAppIconSourceView()
        .frame(width: 256, height: 256)
}
#endif
