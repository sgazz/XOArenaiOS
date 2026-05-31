//
//  BoardWinLineGlowView.swift
//  XOArena
//

import SwiftUI

/// Winning-line emphasis across three cells (Neon Pulse: lime tube glow).
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
                winLinePath(centers: centers)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func winLinePath(centers: [CGPoint]) -> some View {
        let path = Path { path in
            path.move(to: centers[0])
            path.addLine(to: centers[1])
            path.addLine(to: centers[2])
        }

        if themeMode.isNeonPulse {
            ZStack {
                path.stroke(SGColors.neonLime.opacity(0.55), style: StrokeStyle(lineWidth: lineWidth + 2.4, lineCap: .round, lineJoin: .round))
                path.stroke(SGColors.neonLime, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                path.stroke(SGColors.neonWhiteCore.opacity(0.88), style: StrokeStyle(lineWidth: lineWidth * 0.42, lineCap: .round, lineJoin: .round))
            }
            .shadow(color: SGColors.neonLime.opacity(0.95), radius: tightGlowRadius)
            .shadow(color: SGColors.neonLimeSoft.opacity(0.72), radius: ambientGlowRadius)
        } else {
            path.stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .shadow(color: glowColor, radius: glowRadius)
                .shadow(color: glowColor.opacity(0.55), radius: glowRadius * 0.45)
        }
    }

    private var strokeColor: Color {
        Color.white.opacity(0.42)
    }

    private var glowColor: Color {
        Color.white.opacity(0.18)
    }

    private var lineWidth: CGFloat {
        themeMode.isNeonPulse ? 3.6 : 2.2
    }

    private var glowRadius: CGFloat {
        3
    }

    private var tightGlowRadius: CGFloat { 7 }

    private var ambientGlowRadius: CGFloat { 22 }
}
