//
//  MainMenuAmbientBackground.swift
//  XOArena
//

import SwiftUI

/// Ultra-subtle drifting arena fragments (GPU-friendly transforms only).
struct MainMenuAmbientBackground: View {
    @Environment(\.sgThemeMode) private var themeMode
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    /// Scales overall layer opacity (splash reveal uses **0…1**).
    var strength: Double = 1
    /// Emphasizes timer glyphs on later splash beats.
    var timerStrength: Double = 1

    @State private var driftForward = false

    private var glyphTint: Color {
        SGEngravedTextTheme.defaultInk(for: themeMode).opacity(themeMode == .light ? 0.92 : 0.88)
    }

    private var baseLayerOpacity: Double {
        switch themeMode {
        case .light: return 0.055
        case .dark: return 0.048
        case .neonPulse: return 0.065
        }
    }

    private var layerOpacity: Double {
        baseLayerOpacity * min(max(strength, 0), 1.25)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                ambientPiece(index: 0, in: size)
                ambientPiece(index: 1, in: size)
                ambientPiece(index: 2, in: size)
                ambientPiece(index: 3, in: size)
                ambientPiece(index: 4, in: size)
                ambientPiece(index: 5, in: size)
            }
            .frame(width: size.width, height: size.height)
            .blur(radius: 26)
            .opacity(layerOpacity)
            .drawingGroup(opaque: false)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .onAppear { armDriftIfAllowed() }
        .onChange(of: accessibilityReduceMotion) { _, _ in armDriftIfAllowed() }
    }

    @ViewBuilder
    private func ambientPiece(index: Int, in size: CGSize) -> some View {
        let base = MainMenuAmbientLayout.anchor(index: index, in: size)
        let delta = MainMenuAmbientLayout.driftDelta(index: index)
        let offset = accessibilityReduceMotion || !driftForward
            ? base
            : CGPoint(x: base.x + delta.width, y: base.y + delta.height)

        Group {
            switch index % 3 {
            case 0:
                AmbientMiniGridGlyph(tint: glyphTint)
                    .frame(width: glyphSize(index), height: glyphSize(index))
            case 1:
                Text(index.isMultiple(of: 2) ? "X" : "O")
                    .font(.system(size: markSize(index), weight: .bold, design: .rounded))
                    .foregroundStyle(glyphTint)
            default:
                AmbientTimerGlyph(tint: glyphTint)
                    .opacity(min(max(timerStrength, 0.35), 2))
            }
        }
        .position(x: offset.x, y: offset.y)
    }

    private func glyphSize(_ index: Int) -> CGFloat {
        index < 2 ? 48 : 36
    }

    private func markSize(_ index: Int) -> CGFloat {
        index == 1 ? 34 : 28
    }

    private func armDriftIfAllowed() {
        guard !accessibilityReduceMotion else {
            driftForward = false
            return
        }
        driftForward = false
        withAnimation(.linear(duration: MainMenuAmbientLayout.cycleDuration).repeatForever(autoreverses: true)) {
            driftForward = true
        }
    }
}

// MARK: - Layout

private enum MainMenuAmbientLayout {
    /// Single slow loop (20–40 s spec); per-piece deltas stay subtle.
    static let cycleDuration: TimeInterval = 32

    static func anchor(index: Int, in size: CGSize) -> CGPoint {
        let presets: [(CGFloat, CGFloat)] = [
            (0.14, 0.22), (0.86, 0.18), (0.78, 0.72), (0.12, 0.78), (0.52, 0.12), (0.44, 0.88)
        ]
        let p = presets[index % presets.count]
        return CGPoint(x: size.width * p.0, y: size.height * p.1)
    }

    static func driftDelta(index: Int) -> CGSize {
        switch index % 6 {
        case 0: return CGSize(width: 14, height: -10)
        case 1: return CGSize(width: -12, height: 11)
        case 2: return CGSize(width: 10, height: 14)
        case 3: return CGSize(width: -14, height: -8)
        case 4: return CGSize(width: 8, height: -12)
        default: return CGSize(width: -9, height: 10)
        }
    }
}

// MARK: - Glyphs

private struct AmbientMiniGridGlyph: View {
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var grid = Path()
            for i in 1 ... 2 {
                let x = w * CGFloat(i) / 3
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: h))
                let y = h * CGFloat(i) / 3
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: w, y: y))
            }
            context.stroke(grid, with: .color(tint), lineWidth: 0.9)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct AmbientTimerGlyph: View {
    let tint: Color

    var body: some View {
        Text("00:00")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(tint.opacity(0.85), lineWidth: 0.7)
            )
    }
}
