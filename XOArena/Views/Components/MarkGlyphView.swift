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
                outer: SGColors.textDark.opacity(0.26),
                mid: SGColors.textDark.opacity(0.45),
                inner: SGColors.textDark.opacity(0.93)
            )
        case .light:
            xTriStroke(
                outer: SGColors.accentLightMuted.opacity(0.34),
                mid: SGColors.accentLightMuted.opacity(0.58),
                inner: SGColors.inkPrimaryLight.opacity(0.92)
            )
        }
    }

    @ViewBuilder
    private var oInkStack: some View {
        switch themeMode {
        case .dark:
            oTriStroke(
                outer: SGColors.textSecondary.opacity(0.38),
                mid: SGColors.textSecondary.opacity(0.88),
                inner: SGColors.textSecondary.opacity(0.96)
            )
        case .light:
            oTriStroke(
                outer: SGColors.inkSecondaryLight.opacity(0.44),
                mid: SGColors.inkSecondaryLight.opacity(0.78),
                inner: SGColors.inkPrimaryLight.opacity(0.9)
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

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.20))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.13, y: rect.maxY - rect.height * 0.14),
            control: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.midY - rect.height * 0.10)
        )

        path.move(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.17))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.maxY - rect.height * 0.16),
            control: CGPoint(x: rect.midX - rect.width * 0.20, y: rect.midY + rect.height * 0.16)
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

        let right = CGPoint(x: mx + rx * 0.96, y: my - ry * 0.05)
        let bottom = CGPoint(x: mx + rx * 0.05, y: my + ry * 0.88)
        let left = CGPoint(x: mx - rx * 0.92, y: my + ry * 0.10)
        let top = CGPoint(x: mx - rx * 0.14, y: my - ry * 0.90)

        path.move(to: right)
        path.addQuadCurve(to: bottom, control: CGPoint(x: mx + rx * 0.94, y: my + ry * 0.55))
        path.addQuadCurve(to: left, control: CGPoint(x: mx - rx * 0.48, y: my + ry * 1.06))
        path.addQuadCurve(to: top, control: CGPoint(x: mx - rx * 0.94, y: my - ry * 0.48))
        path.addQuadCurve(to: right, control: CGPoint(x: mx + rx * 0.50, y: my - ry * 0.86))
        path.closeSubpath()
        return path
    }
}
