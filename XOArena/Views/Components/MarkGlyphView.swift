//
//  MarkGlyphView.swift
//  XOArena
//

import SwiftUI

/// Hand-ink marks with deterministic imperfection per board × cell slot.
struct MarkGlyphView: View {
    @Environment(\.sgThemeMode) private var themeMode

    let mark: Mark
    var boardIndex: Int = 0
    var cellIndex: Int = 0

    private var strokeScale: CGFloat {
        InkVariance.strokeScale(boardIndex: boardIndex, cellIndex: cellIndex)
    }

    private var inkRotation: Double {
        InkVariance.markRotationDegrees(boardIndex: boardIndex, cellIndex: cellIndex)
    }

    private var inkNudge: CGSize {
        InkVariance.markOffsetPoints(boardIndex: boardIndex, cellIndex: cellIndex)
    }

    var body: some View {
        Group {
            switch mark {
            case .empty:
                Color.clear
            case .x:
                xInkStack
                    .padding(4)
                    .rotationEffect(.degrees(1.1 + inkRotation))
                    .offset(inkNudge)
                    .drawingGroup(opaque: false)
            case .o:
                oInkStack
                    .padding(5)
                    .rotationEffect(.degrees(-1.95 + inkRotation))
                    .offset(inkNudge)
                    .scaleEffect(x: 1.05, y: 0.92)
                    .drawingGroup(opaque: false)
            }
        }
    }

    @ViewBuilder
    private var xInkStack: some View {
        switch themeMode {
        case .dark:
            xTriStroke(
                outer: SGColors.textSecondary.opacity(0.32),
                mid: SGColors.textDark.opacity(0.48),
                inner: SGColors.textDark.opacity(0.94)
            )
        case .light:
            xTriStroke(
                outer: SGColors.inkPrimaryLight.opacity(0.32),
                mid: SGColors.inkSecondaryLight.opacity(0.54),
                inner: SGColors.inkPrimaryLight.opacity(0.94)
            )
        }
    }

    @ViewBuilder
    private var oInkStack: some View {
        switch themeMode {
        case .dark:
            oTriStroke(
                outer: SGColors.textSecondary.opacity(0.42),
                mid: SGColors.textDark.opacity(0.74),
                inner: SGColors.textDark.opacity(0.95)
            )
        case .light:
            oTriStroke(
                outer: SGColors.inkSecondaryLight.opacity(0.46),
                mid: SGColors.inkPrimaryLight.opacity(0.62),
                inner: SGColors.inkPrimaryLight.opacity(0.92)
            )
        }
    }

    private func xTriStroke(outer: Color, mid: Color, inner: Color) -> some View {
        ZStack {
            HandDrawnXShape()
                .stroke(outer, style: StrokeStyle(lineWidth: max(3.05 * strokeScale, 2.85), lineCap: .round, lineJoin: .round))
            HandDrawnXShape()
                .stroke(mid, style: StrokeStyle(lineWidth: max(2.08 * strokeScale, 1.94), lineCap: .round, lineJoin: .round))
            HandDrawnXShape()
                .stroke(inner, style: StrokeStyle(lineWidth: max(1.42 * strokeScale, 1.3), lineCap: .round, lineJoin: .round))
        }
    }

    private func oTriStroke(outer: Color, mid: Color, inner: Color) -> some View {
        ZStack {
            TiltedEllipseMark()
                .stroke(outer, style: StrokeStyle(lineWidth: max(2.96 * strokeScale, 2.75), lineCap: .round, lineJoin: .round))
            TiltedEllipseMark()
                .stroke(mid, style: StrokeStyle(lineWidth: max(1.92 * strokeScale, 1.76), lineCap: .round, lineJoin: .round))
            TiltedEllipseMark()
                .stroke(inner, style: StrokeStyle(lineWidth: max(1.08 * strokeScale, 0.96), lineCap: .round, lineJoin: .round))
        }
    }
}

private struct HandDrawnXShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.13, y: rect.minY + rect.height * 0.21))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.125, y: rect.maxY - rect.height * 0.135),
            control: CGPoint(x: rect.midX + rect.width * 0.192, y: rect.midY - rect.height * 0.108)
        )

        path.move(to: CGPoint(x: rect.maxX - rect.width * 0.118, y: rect.minY + rect.height * 0.168))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.162, y: rect.maxY - rect.height * 0.158),
            control: CGPoint(x: rect.midX - rect.width * 0.205, y: rect.midY + rect.height * 0.172)
        )
        return path
    }
}

/// Soft oval stitched from four asymmetric quadratics.
private struct TiltedEllipseMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mx = rect.midX + rect.width * 0.012
        let my = rect.midY + rect.height * 0.018
        let rx = rect.width * 0.36
        let ry = rect.height * 0.38

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
}
