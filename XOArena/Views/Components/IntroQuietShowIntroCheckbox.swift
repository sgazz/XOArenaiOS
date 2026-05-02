//
//  IntroQuietShowIntroCheckbox.swift
//  XOArena
//

import SwiftUI

/// Minimal paper-style checkbox (no UISwitch chrome). **`binding`** binds to **`AppStorage`** from parent.
struct IntroQuietShowIntroCheckbox: View {
    @Environment(\.sgThemeMode) private var themeMode

    @Binding var isOn: Bool

    private var squareStroke: Color {
        SGColors.introTextSecondary.opacity(themeMode == .light ? 0.38 : 0.42)
    }

    private var checkTint: Color {
        SGColors.accentLightMuted.opacity(themeMode == .light ? 0.62 : 0.54)
    }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: SGSpacing.sm) {
                ZStack {
                    IntroHanddrawnCheckboxSquarePath()
                        .stroke(squareStroke, style: StrokeStyle(lineWidth: 1.05, lineCap: .round, lineJoin: .round))
                    if isOn {
                        IntroHanddrawnCheckmarkPath()
                            .stroke(checkTint, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(width: 18, height: 18)

                Text("Show intro on launch")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(SGColors.introTextSecondary.opacity(0.62))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(-1)
                    .sgEngravedText(intensity: .low, color: SGColors.introTextSecondary.opacity(0.62))

                Spacer(minLength: 0)
            }
            .padding(.vertical, SGSpacing.sm)
            .padding(.horizontal, SGSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show intro on launch")
        .accessibilityValue(isOn ? "Selected" : "Not selected")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// Slightly wobbled square — reads hand-ruled, not vector UI.
private struct IntroHanddrawnCheckboxSquarePath: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 1
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 0.3, y: r.minY + 1.0))
        p.addQuadCurve(
            to: CGPoint(x: r.maxX - 0.25, y: r.minY + 0.4),
            control: CGPoint(x: r.midX, y: r.minY - 0.35)
        )
        p.addQuadCurve(
            to: CGPoint(x: r.maxX - 0.4, y: r.maxY - 0.5),
            control: CGPoint(x: r.maxX + 0.4, y: r.midY)
        )
        p.addQuadCurve(
            to: CGPoint(x: r.minX + 0.6, y: r.maxY - 0.2),
            control: CGPoint(x: r.midX, y: r.maxY + 0.35)
        )
        p.addQuadCurve(
            to: CGPoint(x: r.minX + 0.3, y: r.minY + 1.0),
            control: CGPoint(x: r.minX - 0.45, y: r.midY)
        )
        p.closeSubpath()
        return p
    }
}

private struct IntroHanddrawnCheckmarkPath: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.52))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.38, y: rect.minY + h * 0.82),
            control: CGPoint(x: rect.minX + w * 0.22, y: rect.minY + h * 0.72)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.92, y: rect.minY + h * 0.16),
            control: CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 0.68)
        )
        return p
    }
}
