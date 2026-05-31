//
//  BoardWinLineGlowView.swift
//  XOArena
//

import SwiftUI

/// Subtle winning-line emphasis across three cells (Neon Pulse: lime glow).
struct BoardWinLineGlowView: View {
    @Environment(\.sgThemeMode) private var themeMode

    let cellIndices: [Int]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 3
            let centers = cellIndices.map { idx -> CGPoint in
                let row = idx / 3
                let col = idx % 3
                return CGPoint(x: cell * (CGFloat(col) + 0.5), y: cell * (CGFloat(row) + 0.5))
            }
            if centers.count == 3 {
                Path { path in
                    path.move(to: centers[0])
                    path.addLine(to: centers[1])
                    path.addLine(to: centers[2])
                }
                .stroke(
                    strokeColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: glowColor, radius: glowRadius)
                .shadow(color: glowColor.opacity(0.55), radius: glowRadius * 0.45)
            }
        }
        .allowsHitTesting(false)
    }

    private var strokeColor: Color {
        themeMode.isNeonPulse ? SGColors.neonLime : Color.white.opacity(0.42)
    }

    private var glowColor: Color {
        themeMode.isNeonPulse ? SGColors.neonLimeSoft : Color.white.opacity(0.18)
    }

    private var lineWidth: CGFloat {
        themeMode.isNeonPulse ? 3.2 : 2.2
    }

    private var glowRadius: CGFloat {
        themeMode.isNeonPulse ? 8 : 3
    }
}
