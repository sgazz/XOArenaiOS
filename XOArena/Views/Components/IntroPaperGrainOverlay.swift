//
//  IntroPaperGrainOverlay.swift
//  XOArena
//

import SwiftUI

/// Very faint deterministic „fiber“ noise — analogue paper tactility without heavy GPU cost.
struct IntroPaperGrainOverlay: View {
    @Environment(\.sgThemeMode) private var themeMode

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 5
            var x: CGFloat = 0
            while x < size.width + step {
                var y: CGFloat = 0
                while y < size.height + step {
                    let ix = Int(x / step)
                    let iy = Int(y / step)
                    let t = hash01(ix, iy)
                    if t < 0.088 {
                        let base = CGFloat(0.038 + Double(t) * 0.05)
                        let color: Color =
                            themeMode == .light
                                ? SGColors.introTextPrimary.opacity(Double(base))
                                : Color.white.opacity(Double(base * 0.72))
                        var r = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                        r = r.integral
                        var dot = Path()
                        dot.addEllipse(in: r)
                        context.fill(dot, with: .color(color))
                    }
                    y += step
                }
                x += step
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
        .blendMode(.multiply)
        .opacity(themeMode == .light ? 0.38 : 0.55)
    }

    /// Stable [0,1) from grid coords (no RNG allocation).
    private func hash01(_ ix: Int, _ iy: Int) -> CGFloat {
        let u = UInt32(bitPattern: Int32(ix &* 374_761_393 &+ iy &* 668_265_263))
        let v = u & (~(u >> 16))
        return CGFloat(Int32(v >> 24) & 0xFF) / 255.0
    }
}
