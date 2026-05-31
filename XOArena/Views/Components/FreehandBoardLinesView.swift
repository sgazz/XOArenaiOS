//
//  FreehandBoardLinesView.swift
//  XOArena
//

import SwiftUI

/// Slobodnoručna mreža: četiri stabilno „drhtave“ crtice po `boardIndex`, ugraviran par slojeva senki/highlight-a.
struct FreehandBoardLinesView: View {
    @Environment(\.sgThemeMode) private var themeMode

    var boardIndex: Int = 0
    var accent: Bool

    private enum StoneLight {
        static let ink = Color(red: 43 / 255, green: 38 / 255, blue: 34 / 255)
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Group {
                switch themeMode {
                case .light:
                    lightEngravedBoard()
                case .dark:
                    darkEngravedBoard()
                case .neonPulse:
                    neonPulseBoard()
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    private func lightEngravedBoard() -> some View {
        let ink = StoneLight.ink
        let accentMul: CGFloat = accent ? 1.14 : 1
        let baseOpacity = accent ? 0.5 : 0.23
        let baseCore: CGFloat = accent ? 0.98 : 0.74
        return ZStack {
            ForEach(BoardGridSlot.allCases, id: \.rawValue) { slot in
                let v = GridLineVariation.forSlot(boardIndex: boardIndex, slot: slot)
                let lwCore = baseCore * v.strokeWidthMultiplier * accentMul * (accent ? 1.06 : 0.98)

                VariFreehandBoardLine(boardIndex: boardIndex, slot: slot)
                    .stroke(ink.opacity(baseOpacity * 0.55 * v.opacityMultiplier * accentMul), style: StrokeStyle(lineWidth: (accent ? 1.18 : 0.94) * v.strokeWidthMultiplier, lineCap: .round, lineJoin: .round))
                    .offset(x: 0.55 + CGFloat(slot.rawValue % 3) * 0.015, y: 0.55 + CGFloat(boardIndex % 2) * 0.008)
                VariFreehandBoardLine(boardIndex: boardIndex, slot: slot)
                    .stroke(Color.white.opacity(Double((accent ? 0.4 : 0.22) * v.opacityMultiplier)), style: StrokeStyle(lineWidth: (accent ? 0.76 : 0.61) * v.strokeWidthMultiplier, lineCap: .round, lineJoin: .round))
                    .offset(x: -0.48 + v.perpJit * -0.12, y: -0.5 + v.parallelJit * 0.1)
                VariFreehandBoardLine(boardIndex: boardIndex, slot: slot)
                    .stroke(ink.opacity(baseOpacity * v.opacityMultiplier * accentMul), style: StrokeStyle(lineWidth: lwCore, lineCap: .round, lineJoin: .round))
                VariFreehandBoardLine(boardIndex: boardIndex, slot: slot)
                    .stroke(ink.opacity(baseOpacity * (accent ? 0.32 : 0.2) * v.opacityMultiplier), style: StrokeStyle(lineWidth: (accent ? 2.12 : 1.68) * v.strokeWidthMultiplier, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func darkEngravedBoard() -> some View {
        let warmLine = Color(red: 212 / 255, green: 198 / 255, blue: 186 / 255)
        let accentMul: CGFloat = accent ? 1.12 : 1
        let base = accent ? 0.54 : 0.32
        return ZStack {
            ForEach(BoardGridSlot.allCases, id: \.rawValue) { slot in
                let v = GridLineVariation.forSlot(boardIndex: boardIndex, slot: slot)
                let coreW = (accent ? 1.02 : 0.76) * v.strokeWidthMultiplier * accentMul
                VariFreehandBoardLine(boardIndex: boardIndex, slot: slot)
                    .stroke(Color.black.opacity(Double(base * 0.72 * v.opacityMultiplier)), style: StrokeStyle(lineWidth: (accent ? 1.14 : 0.9) * v.strokeWidthMultiplier, lineCap: .round, lineJoin: .round))
                    .offset(x: 0.52, y: 0.52)
                VariFreehandBoardLine(boardIndex: boardIndex, slot: slot)
                    .stroke(Color.white.opacity(accent ? 0.15 : 0.085), style: StrokeStyle(lineWidth: 0.6 * v.strokeWidthMultiplier, lineCap: .round, lineJoin: .round))
                    .offset(x: -0.43 + v.perpJit * 0.06, y: -0.42)
                VariFreehandBoardLine(boardIndex: boardIndex, slot: slot)
                    .stroke(warmLine.opacity(Double((base + (accent ? 0.085 : 0.04)) * v.opacityMultiplier)), style: StrokeStyle(lineWidth: coreW, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func neonPulseBoard() -> some View {
        let line = SGColors.neonCyanGrid
        let accentMul: CGFloat = accent ? 1.12 : 1
        let baseOpacity = accent ? 0.48 : 0.26
        return ZStack {
            ForEach(BoardGridSlot.allCases, id: \.rawValue) { slot in
                let v = GridLineVariation.forSlot(boardIndex: boardIndex, slot: slot)
                let coreW = (accent ? 0.92 : 0.72) * v.strokeWidthMultiplier * accentMul
                VariFreehandBoardLine(boardIndex: boardIndex, slot: slot)
                    .stroke(line.opacity(Double(baseOpacity * 0.42 * v.opacityMultiplier * accentMul)), style: StrokeStyle(lineWidth: (accent ? 1.6 : 1.2) * v.strokeWidthMultiplier, lineCap: .round, lineJoin: .round))
                    .shadow(color: SGColors.neonCyanSoft.opacity(accent ? 0.28 : 0.14), radius: accent ? 2.5 : 1.5)
                VariFreehandBoardLine(boardIndex: boardIndex, slot: slot)
                    .stroke(line.opacity(Double(baseOpacity * v.opacityMultiplier * accentMul)), style: StrokeStyle(lineWidth: coreW, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Deterministic variation per board + line slot

private enum BoardGridSlot: Int, CaseIterable {
    /// Vertikala između prvog i drugog stupca.
    case verticalLeading = 0
    /// Vertikala između drugog i trećeg stupca.
    case verticalTrailing = 1
    /// Horizontala između prvog i drugog reda.
    case horizontalUpper = 2
    /// Horizontala između drugog i trećeg reda.
    case horizontalLower = 3
}

private struct GridLineVariation {
    /// Skraćenje duljine na početku (udio stranice kvadrata).
    let trimStartFraction: CGFloat
    /// Na kraju crtice (udjel stranice).
    let trimEndFraction: CGFloat
    /// Razmak paralelan crte (vizualni „šuškanje”).
    let parallelOffset: CGFloat
    /// Mali pomak pravokretan na smjer crtice (pt na stranicu).
    let perpOffset: CGFloat
    let controlSkewX: CGFloat
    let controlSkewY: CGFloat
    /// Blaga rotacija krajnjih točaka (pt relativno na side).
    let endCapSweep: CGFloat
    let strokeWidthMultiplier: CGFloat
    let opacityMultiplier: CGFloat

    /// Mala vrijednost za offset u Views (pseudo-Jitter zbrojeva).
    var perpJit: CGFloat { perpOffset * 120 }
    var parallelJit: CGFloat { parallelOffset * 120 }

    static func forSlot(boardIndex: Int, slot: BoardGridSlot) -> GridLineVariation {
        let bi = CGFloat(boardIndex)
        let sr = CGFloat(slot.rawValue)

        func w(_ k: CGFloat) -> CGFloat {
            CGFloat(sin(Double(bi * 1.127 + sr * 1.983 + k) * 1.873)
                + 0.58 * cos(Double(bi * 0.887 - sr * 1.211 + k * 0.913) * 2.041))
            * CGFloat(0.5)
        }

        let trim0 = CGFloat(0.010 + CGFloat(0.020 * abs(w(0))))
        let trim1 = CGFloat(0.009 + CGFloat(0.019 * abs(w(1))))
        func clampFrac(_ x: CGFloat) -> CGFloat {
            max(0.0065, min(0.042, x))
        }

        return GridLineVariation(
            trimStartFraction: clampFrac(trim0),
            trimEndFraction: clampFrac(trim1),
            parallelOffset: w(2) * 0.028,
            perpOffset: w(3) * 0.024,
            controlSkewX: w(4) * 3.1,
            controlSkewY: w(5) * 2.6,
            endCapSweep: w(6) * 2.85,
            strokeWidthMultiplier: 0.9 + abs(w(7)).clamped(to: 0 ... 1) * 0.22,
            opacityMultiplier: 0.9 + abs(w(8)).clamped(to: 0 ... 1) * 0.17
        )
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Jedna crtica kao Shape

private struct VariFreehandBoardLine: Shape {
    let boardIndex: Int
    let slot: BoardGridSlot

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        guard s > 6 else { return Path() }

        let step = s / 3
        let ox = rect.minX + (rect.width - s) / 2
        let oy = rect.minY + (rect.height - s) / 2
        let v = GridLineVariation.forSlot(boardIndex: boardIndex, slot: slot)

        switch slot {
        case .verticalLeading, .verticalTrailing:
            let which = CGFloat(slot == .verticalLeading ? 1 : 2)
            let xLine = ox + step * which + v.parallelOffset * s + v.perpOffset * 28
            let y0 = oy + s * v.trimStartFraction + v.parallelOffset * 12
            let y1 = oy + s * (1 - v.trimEndFraction) - v.parallelOffset * 9
            let xStart = xLine + v.endCapSweep
            let xEnd = xLine - v.endCapSweep * 0.94
            let midY = (y0 + y1) / 2 + v.controlSkewY + v.perpOffset * s * 0.22
            let cx = (xStart + xEnd) / 2 + v.controlSkewX

            var p = Path()
            p.move(to: CGPoint(x: xStart, y: y0))
            p.addQuadCurve(to: CGPoint(x: xEnd, y: y1), control: CGPoint(x: cx, y: midY))
            return p

        case .horizontalUpper, .horizontalLower:
            let which = CGFloat(slot == .horizontalUpper ? 1 : 2)
            let yLine = oy + step * which + v.parallelOffset * s + v.perpOffset * 28
            let x0 = ox + s * v.trimStartFraction + v.parallelOffset * 11
            let x1 = ox + s * (1 - v.trimEndFraction) - v.parallelOffset * 10
            let yStart = yLine + v.endCapSweep
            let yEnd = yLine - v.endCapSweep * 0.92
            let midX = (x0 + x1) / 2 + v.controlSkewX + v.perpOffset * s * 0.2
            let cy = (yStart + yEnd) / 2 + v.controlSkewY

            var p = Path()
            p.move(to: CGPoint(x: x0, y: yStart))
            p.addQuadCurve(to: CGPoint(x: x1, y: yEnd), control: CGPoint(x: midX, y: cy))
            return p
        }
    }
}
