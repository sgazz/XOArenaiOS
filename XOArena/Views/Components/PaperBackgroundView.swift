//
//  PaperBackgroundView.swift
//  XOArena
//

import SwiftUI

/// Cappuccino paper (light) or ink paper (dark) — static layers, GPU-friendly washes.
struct PaperBackgroundView: View {
    @Environment(\.sgThemeMode) private var themeMode

    private var lightPaper: Bool { themeMode == .light }

    var body: some View {
        ZStack {
            (lightPaper ? SGColors.paperBackgroundLight : SGColors.paperDark)

            UnevenToneWashLayer(lightPaper: lightPaper)
                .blendMode(lightPaper ? .multiply : .softLight)
                .opacity(lightPaper ? 0.15 : 0.28)
                .allowsHitTesting(false)

            PaperGrainNoiseLayer(lightPaper: lightPaper)
                .blendMode(lightPaper ? .multiply : .softLight)
                .opacity(lightPaper ? 0.28 : 0.45)
                .allowsHitTesting(false)

            PaperGrainNoiseLayer(lightPaper: lightPaper, dotScale: 0.82, jitter: 0.9)
                .blendMode(lightPaper ? .softLight : .overlay)
                .opacity(lightPaper ? 0.11 : 0.18)
                .allowsHitTesting(false)

            RadialInkVignette(lightPaper: lightPaper)
                .blendMode(.multiply)
                .opacity(lightPaper ? 0.2 : 0.55)
                .allowsHitTesting(false)

            LinearEdgeBloom(lightPaper: lightPaper)
                .blendMode(lightPaper ? .multiply : .softLight)
                .opacity(lightPaper ? 0.09 : 0.16)
                .allowsHitTesting(false)
        }
    }
}

/// Large, sparse tonal drift — deterministic hash, coarse grid (few draws).
private struct UnevenToneWashLayer: View {
    var step: CGFloat = 128
    var lightPaper: Bool = false

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            guard size.width > 2, size.height > 2 else { return }

            for ix in stride(from: step * 0.5, through: size.width + step, by: step) {
                for iy in stride(from: step * 0.35, through: size.height + step, by: step) {
                    let h = seededHash(ix: Int(ix), iy: Int(iy))
                    guard (h % 11) < 8 else { continue }

                    let rect = CGRect(
                        x: ix - CGFloat((h >> 3) % 70),
                        y: iy - CGFloat((h >> 7) % 60),
                        width: CGFloat(48 + Int(h % 55)),
                        height: CGFloat(62 + Int((h >> 5) % 54))
                    )
                    let alpha: Double = {
                        if lightPaper {
                            let base = 0.015 + CGFloat(h % 15) / 850
                            return Double(base)
                        }
                        return 0.02 + Double(h % 17) / 900
                    }()
                    let color: Color = lightPaper
                        ? SGColors.inkPrimaryLight.opacity(alpha)
                        : Color.white.opacity(alpha)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }

    private func seededHash(ix: Int, iy: Int) -> UInt32 {
        var n = UInt32(truncatingIfNeeded: (ix &* 7919) ^ (iy &* 30_073))
        n &*= 2_659_443_763
        n ^= n >> 17
        return n
    }
}

private struct RadialInkVignette: View {
    var lightPaper: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let diagonal = hypot(w, h)

            RadialGradient(
                gradient: {
                    if lightPaper {
                        return Gradient(stops: [
                            .init(color: SGColors.vignetteWarm.opacity(0), location: 0),
                            .init(color: SGColors.vignetteWarm.opacity(0.07), location: 0.92)
                        ])
                    }
                    return Gradient(stops: [
                        .init(color: Color.black.opacity(0), location: 0),
                        .init(color: Color.black.opacity(0.18), location: 0.92)
                    ])
                }(),
                center: .center,
                startRadius: diagonal * 0.18,
                endRadius: diagonal * 0.86
            )
            .frame(width: w, height: h)
            .allowsHitTesting(false)
        }
    }
}

private struct LinearEdgeBloom: View {
    var lightPaper: Bool = false

    var body: some View {
        Group {
            if lightPaper {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: SGColors.inkSecondaryLight.opacity(0.05), location: 0),
                        .init(color: Color.clear, location: 0.07),
                        .init(color: Color.clear, location: 0.93),
                        .init(color: SGColors.inkSecondaryLight.opacity(0.06), location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.black.opacity(0.045), location: 0),
                        .init(color: Color.clear, location: 0.06),
                        .init(color: Color.clear, location: 0.94),
                        .init(color: Color.black.opacity(0.065), location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

private struct PaperGrainNoiseLayer: View {
    var lightPaper: Bool = false
    var step: CGFloat = 6
    var dotScale: CGFloat = 1
    var jitter: CGFloat = 1

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            guard size.width > 1, size.height > 1 else { return }

            for ix in stride(from: 0, through: Int(size.width), by: Int(step)) {
                for iy in stride(from: 0, through: Int(size.height), by: Int(step)) {
                    let h = seededHash(ix: ix, iy: iy)
                    if (h % 37) > (lightPaper ? 24 : 26) { continue }

                    let xf = CGFloat(ix)
                    let yf = CGFloat(iy)

                    let jx = grainOffset(seed: h) * jitter
                    let jy = grainOffset(seed: h &>> 11) * jitter

                    let alphaBase: CGFloat = lightPaper ? 0.018 : 0.012
                    let alpha = alphaBase + CGFloat(h % 9) / (lightPaper ? 700 : 900)
                    let w = CGFloat(0.85 + CGFloat(h % 5) / 18) * dotScale

                    let rect = CGRect(x: xf + jx - w * 0.5, y: yf + jy - w * 0.5, width: w, height: w)
                    let tint: Color = lightPaper ? SGColors.inkPrimaryLight : Color.white
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(Double(alpha))))
                }
            }
        }
    }

    private func grainOffset(seed: UInt32) -> CGFloat {
        let bounded = CGFloat(Int32(bitPattern: seed % 241)) / 240 * 2 - 1
        return bounded * 0.52
    }

    private func seededHash(ix: Int, iy: Int) -> UInt32 {
        var n = UInt32(truncatingIfNeeded: ix &* 23_791)
        n &*= 2_659_975
        n ^= UInt32(truncatingIfNeeded: iy &* 70_783)
        n &*= 2_659_977
        n ^= n >> 16
        n &*= 2_246_821_917
        n ^= n >> 13
        return n
    }
}
