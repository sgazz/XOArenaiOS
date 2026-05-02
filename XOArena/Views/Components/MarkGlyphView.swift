//
//  MarkGlyphView.swift
//  XOArena
//

import SwiftUI

/// Hand-drawn marks: determinističke varijante X/O + slojevi tuša iz `InkVariance`.
struct MarkGlyphView: View {
    @Environment(\.sgThemeMode) private var themeMode

    let mark: Mark
    var boardIndex: Int = 0
    var cellIndex: Int = 0
    /// Opcionalni broj poteza u trenutku postavljanja (zaključava seme kad view proslijedi ga iz `CellMarkReveal`).
    var placementMoveOrdinal: Int?

    private var strokeScale: CGFloat {
        InkVariance.strokeScale(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
    }

    private var inkRotation: Double {
        InkVariance.markRotationDegrees(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
            + InkVariance.markRotationFineTuneDegrees(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
    }

    private var inkNudge: CGSize {
        InkVariance.markOffsetPoints(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
    }

    private var opacityDrift: (CGFloat, CGFloat, CGFloat) {
        InkVariance.markLayerOpacityDrifts(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
    }

    private var xVariant: Int {
        InkVariance.xVariantIndex(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
    }

    private var oVariant: Int {
        InkVariance.oVariantIndex(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
    }

    /// X varijante 4: tanji, oštrij izgled.
    private var xPencilThinMul: CGFloat {
        xVariant == 4 ? 0.91 : 1
    }

    var body: some View {
        Group {
            switch mark {
            case .empty:
                Color.clear
            case .x:
                xInkStack
                    .padding(4 + paddingNudge(forX: true))
                    .rotationEffect(.degrees(1.1 + inkRotation))
                    .offset(inkNudge)
                    .drawingGroup(opaque: false)
            case .o:
                oInkStack
                    .padding(5 + paddingNudge(forX: false))
                    .rotationEffect(.degrees(-1.95 + inkRotation))
                    .offset(inkNudge)
                    .scaleEffect(x: 1.03, y: 0.945)
                    .drawingGroup(opaque: false)
            }
        }
    }

    /// Blagi unutarnji razmak od mreže; varira po oznaci.
    private func paddingNudge(forX: Bool) -> CGFloat {
        let s = InkVariance.glyphVariantSeed(boardIndex: boardIndex, cellIndex: cellIndex, placementMoveOrdinal: placementMoveOrdinal)
        let bump = CGFloat((s >> (forX ? 2 : 6)) % 5) / 28
        return forX ? bump : bump + 0.15
    }

    @ViewBuilder
    private var xInkStack: some View {
        let (oo, om, oi) = opacityDrift
        switch themeMode {
        case .dark:
            xTriStroke(
                outer: SGColors.textSecondary.opacity(0.32 * Double(oo)),
                mid: SGColors.textDark.opacity(0.48 * Double(om)),
                inner: SGColors.textDark.opacity(0.94 * Double(oi))
            )
        case .light:
            xTriStroke(
                outer: SGColors.inkPrimaryLight.opacity(0.32 * Double(oo)),
                mid: SGColors.inkSecondaryLight.opacity(0.54 * Double(om)),
                inner: SGColors.inkPrimaryLight.opacity(0.94 * Double(oi))
            )
        }
    }

    @ViewBuilder
    private var oInkStack: some View {
        let (oo, om, oi) = opacityDrift
        switch themeMode {
        case .dark:
            oStyledStroke(
                outer: SGColors.textSecondary.opacity(0.42 * Double(oo)),
                mid: SGColors.textDark.opacity(0.74 * Double(om)),
                inner: SGColors.textDark.opacity(0.95 * Double(oi))
            )
        case .light:
            oStyledStroke(
                outer: SGColors.inkSecondaryLight.opacity(0.46 * Double(oo)),
                mid: SGColors.inkPrimaryLight.opacity(0.62 * Double(om)),
                inner: SGColors.inkPrimaryLight.opacity(0.92 * Double(oi))
            )
        }
    }

    private func xTriStroke(outer: Color, mid: Color, inner: Color) -> some View {
        let lw: (CGFloat, CGFloat, CGFloat) = (
            max(3.05 * strokeScale * xPencilThinMul, 2.74),
            max(2.08 * strokeScale * xPencilThinMul, 1.76),
            max(1.42 * strokeScale * xPencilThinMul, 1.22)
        )
        return ZStack {
            HandDrawnXShape(variant: xVariant)
                .stroke(outer, style: StrokeStyle(lineWidth: lw.0, lineCap: .round, lineJoin: .round))
            HandDrawnXShape(variant: xVariant)
                .stroke(mid, style: StrokeStyle(lineWidth: lw.1, lineCap: .round, lineJoin: .round))
            HandDrawnXShape(variant: xVariant)
                .stroke(inner, style: StrokeStyle(lineWidth: lw.2, lineCap: .round, lineJoin: .round))
        }
    }

    private func oStyledStroke(outer: Color, mid: Color, inner: Color) -> some View {
        let lw: (CGFloat, CGFloat, CGFloat) = (
            max(2.96 * strokeScale, 2.68),
            max(1.92 * strokeScale, 1.68),
            max(1.08 * strokeScale, 0.92)
        )
        return Group {
            if oVariant == 4 {
                ZStack {
                    HandDrawnOShape(variant: 4, contour: .outer)
                        .stroke(outer, style: StrokeStyle(lineWidth: lw.0, lineCap: .round, lineJoin: .round))
                    HandDrawnOShape(variant: 4, contour: .inner)
                        .stroke(mid, style: StrokeStyle(lineWidth: lw.1, lineCap: .round, lineJoin: .round))
                    HandDrawnOShape(variant: 4, contour: .inner)
                        .stroke(inner, style: StrokeStyle(lineWidth: lw.2, lineCap: .round, lineJoin: .round))
                }
            } else {
                ZStack {
                    HandDrawnOShape(variant: oVariant, contour: .single)
                        .stroke(outer, style: StrokeStyle(lineWidth: lw.0, lineCap: .round, lineJoin: .round))
                    HandDrawnOShape(variant: oVariant, contour: .single)
                        .stroke(mid, style: StrokeStyle(lineWidth: lw.1, lineCap: .round, lineJoin: .round))
                    HandDrawnOShape(variant: oVariant, contour: .single)
                        .stroke(inner, style: StrokeStyle(lineWidth: lw.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

// MARK: - X oblika (5)

private struct HandDrawnXShape: Shape {
    var variant: Int

    func path(in rect: CGRect) -> Path {
        switch clamp(variant, 0, 4) {
        case 0: return pathClassic(rect)
        case 1: return pathWideLongLowerLeft(rect)
        case 2: return pathNarrow(rect)
        case 3: return pathSoftBow(rect)
        case 4: return pathAngularPencil(rect)
        default: return pathClassic(rect)
        }
    }

    /// Klasično X, lagano zakrivljeno.
    private func pathClassic(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.13, y: r.minY + r.height * 0.21))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.125, y: r.maxY - r.height * 0.135),
            control: CGPoint(x: r.midX + r.width * 0.192, y: r.midY - r.height * 0.108)
        )
        path.move(to: CGPoint(x: r.maxX - r.width * 0.118, y: r.minY + r.height * 0.168))
        path.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.162, y: r.maxY - r.height * 0.158),
            control: CGPoint(x: r.midX - r.width * 0.205, y: r.midY + r.height * 0.172)
        )
        return path
    }

    /// Šire krake; donji lijevi kraj prvog povučen niže lijevo (duži).
    private func pathWideLongLowerLeft(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.205))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.108, y: r.maxY - r.height * 0.148),
            control: CGPoint(x: r.midX + r.width * 0.22, y: r.midY - r.height * 0.098)
        )
        path.move(to: CGPoint(x: r.maxX - r.width * 0.098, y: r.minY + r.height * 0.152))
        path.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.098, y: r.maxY - r.height * 0.062),
            control: CGPoint(x: r.midX - r.width * 0.21, y: r.midY + r.height * 0.198)
        )
        return path
    }

    private func pathNarrow(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.19, y: r.minY + r.height * 0.258))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.172, y: r.maxY - r.height * 0.206),
            control: CGPoint(x: r.midX + r.width * 0.146, y: r.midY - r.height * 0.068)
        )
        path.move(to: CGPoint(x: r.maxX - r.width * 0.174, y: r.minY + r.height * 0.246))
        path.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.196, y: r.maxY - r.height * 0.214),
            control: CGPoint(x: r.midX - r.width * 0.168, y: r.midY + r.height * 0.138)
        )
        return path
    }

    private func pathSoftBow(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.218))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.118, y: r.maxY - r.height * 0.148),
            control: CGPoint(x: r.midX + r.width * 0.24, y: r.midY - r.height * 0.174)
        )
        path.move(to: CGPoint(x: r.maxX - r.width * 0.126, y: r.minY + r.height * 0.174))
        path.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.154, y: r.maxY - r.height * 0.174),
            control: CGPoint(x: r.midX - r.width * 0.24, y: r.midY + r.height * 0.174)
        )
        return path
    }

    private func pathAngularPencil(_ r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.146, y: r.minY + r.height * 0.258))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - r.width * 0.142, y: r.maxY - r.height * 0.202),
            control: CGPoint(x: r.midX + r.width * 0.065, y: r.midY - r.height * 0.088)
        )
        path.move(to: CGPoint(x: r.maxX - r.width * 0.154, y: r.minY + r.height * 0.266))
        path.addQuadCurve(
            to: CGPoint(x: r.minX + r.width * 0.142, y: r.maxY - r.height * 0.226),
            control: CGPoint(x: r.midX - r.width * 0.062, y: r.midY + r.height * 0.068)
        )
        return path
    }
}

private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int {
    min(max(v, lo), hi)
}

// MARK: - O oblika

private enum OContour {
    case single
    case outer
    case inner
}

private struct HandDrawnOShape: Shape {
    var variant: Int
    var contour: OContour

    func path(in rect: CGRect) -> Path {
        let v = clamp(variant, 0, 4)

        if v == 4 {
            switch contour {
            case .outer:
                return imperfectOval(rect, rxMul: 0.36, ryMul: 0.38)
            case .inner:
                let insetX = rect.width * 0.069
                let insetY = rect.height * 0.076
                let ir = rect.insetBy(dx: insetX, dy: insetY)
                return imperfectOval(ir, rxMul: 0.36, ryMul: 0.38)
            case .single:
                return imperfectOval(rect, rxMul: 0.36, ryMul: 0.38)
            }
        }

        guard case .single = contour else { return Path() }

        switch v {
        case 0:
            return imperfectOval(rect, rxMul: 0.36, ryMul: 0.38)
        case 1:
            return slightlyOpenArc(rect)
        case 2:
            return imperfectOval(rect, rxMul: 0.42, ryMul: 0.35)
        case 3:
            return imperfectOval(rect, rxMul: 0.332, ryMul: 0.418)
        default:
            return imperfectOval(rect, rxMul: 0.36, ryMul: 0.38)
        }
    }

    /// Asimetričan oval od četiri kvadratikne „ćetvorine”; nije `Ellipse()`.
    private func imperfectOval(
        _ r: CGRect,
        rxMul: CGFloat,
        ryMul: CGFloat,
        mxShift: CGFloat = 0,
        myShift: CGFloat = 0
    ) -> Path {
        var path = Path()
        let mx = r.midX + r.width * 0.012 + mxShift
        let my = r.midY + r.height * 0.018 + myShift
        let rx = r.width * rxMul
        let ry = r.height * ryMul

        let right = CGPoint(x: mx + rx * 0.965, y: my - ry * 0.048)
        let bottom = CGPoint(x: mx + rx * 0.048, y: my + ry * 0.885)
        let left = CGPoint(x: mx - rx * 0.915, y: my + ry * 0.108)
        let top = CGPoint(x: mx - rx * 0.142, y: my - ry * 0.895)

        path.move(to: right)
        path.addQuadCurve(to: bottom, control: CGPoint(x: mx + rx * 0.932, y: my + ry * 0.562))
        path.addQuadCurve(to: left, control: CGPoint(x: mx - rx * 0.472, y: my + ry * 1.04))
        path.addQuadCurve(to: top, control: CGPoint(x: mx - rx * 0.948, y: my - ry * 0.465))
        path.addQuadCurve(to: right, control: CGPoint(x: mx + rx * 0.512, y: my - ry * 0.848))
        path.closeSubpath()
        return path
    }

    /// Otvorena kržnjica (~320°).
    private func slightlyOpenArc(_ r: CGRect) -> Path {
        var path = Path()
        let mx = r.midX + r.width * 0.02
        let my = r.midY + r.height * 0.015
        let rx = r.width * 0.355
        let ry = r.height * 0.382

        let p0 = CGPoint(x: mx + rx * 0.78, y: my - ry * 0.22)
        let p1 = CGPoint(x: mx - rx * 0.82, y: my + ry * 0.26)
        let p2 = CGPoint(x: mx - rx * 0.58, y: my - ry * 0.72)
        let p3 = CGPoint(x: mx + rx * 0.42, y: my - ry * 0.58)

        path.move(to: p0)
        path.addQuadCurve(to: p1, control: CGPoint(x: mx + rx * 0.82, y: my + ry * 0.48))
        path.addQuadCurve(to: p2, control: CGPoint(x: mx - rx * 1.06, y: my - ry * 0.18))
        path.addQuadCurve(to: p3, control: CGPoint(x: mx - rx * 0.28, y: my - ry * 1.06))
        return path
    }
}

// MARK: - DEBUG pregled svih obličja

#if DEBUG
private struct MarkGlyphVariantPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGSpacing.md) {
                Text("Hand-drawn mark variants").font(.headline)

                Text("X — pet Path obližljaka").font(.subheadline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 12) {
                    ForEach(0 ..< 5, id: \.self) { vx in
                        VStack(spacing: 4) {
                            Text("X \(vx)").font(.caption2)
                            HandDrawnXShape(variant: vx)
                                .stroke(Color.primary.opacity(0.85), style: StrokeStyle(lineWidth: 1.85, lineCap: .round, lineJoin: .round))
                                .frame(width: 56, height: 56)
                        }
                            .padding(6)
                            .background(Color.gray.opacity(0.08))
                    }
                }

                Text("O — pet obližljaka (uključujući dvojni prsten)").font(.subheadline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 12) {
                    ForEach(0 ..< 5, id: \.self) { vo in
                        VStack(spacing: 4) {
                            Text("O \(vo)").font(.caption2)
                            Group {
                                if vo == 4 {
                                    ZStack {
                                        HandDrawnOShape(variant: 4, contour: .outer)
                                            .stroke(Color.blue.opacity(0.45), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                                        HandDrawnOShape(variant: 4, contour: .inner)
                                            .stroke(Color.primary.opacity(0.88), style: StrokeStyle(lineWidth: 1.42, lineCap: .round, lineJoin: .round))
                                    }
                                } else {
                                    HandDrawnOShape(variant: vo, contour: .single)
                                        .stroke(Color.primary.opacity(0.82), style: StrokeStyle(lineWidth: 2.05, lineCap: .round, lineJoin: .round))
                                }
                            }
                            .frame(width: 56, height: 56)
                        }
                            .padding(6)
                            .background(Color.gray.opacity(0.08))
                    }
                }
            }
            .padding()
        }
    }
}

#Preview("Mark shapes — variants") {
    MarkGlyphVariantPreviewGallery()
}

#Preview("Single cells — seeded") {
    HStack(spacing: 24) {
        MarkGlyphView(mark: .x, boardIndex: 2, cellIndex: 7, placementMoveOrdinal: 42)
            .frame(width: 72, height: 72)
        MarkGlyphView(mark: .o, boardIndex: 5, cellIndex: 1, placementMoveOrdinal: 17)
            .frame(width: 72, height: 72)
    }
    .padding()
    .environment(\.sgThemeMode, .light)
}

#endif
