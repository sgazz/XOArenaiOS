//
//  SGEngravedText.swift
//  XOArena
//
//  Ugravirani tekst samo slojevima senki / highlightova — bez tekstura.

import SwiftUI

// MARK: - Intensity & mode

enum SGEngravedTextIntensity: Hashable, Sendable {
    case low
    case medium
    case high
}

extension SGEngravedTextIntensity {
    fileprivate func baseFactors() -> (dark: CGFloat, highlight: CGFloat, ambient: CGFloat) {
        switch self {
        case .low: return (0.22, 0.36, 0.065)
        case .medium: return (0.26, 0.40, 0.082)
        case .high: return (0.30, 0.45, 0.10)
        }
    }

    /// Blago dizanje — suprotniji vertikalni odnos, manje jakosti.
    fileprivate func raisedFactors() -> (dark: CGFloat, highlight: CGFloat) {
        let m = CGFloat(0.82)
        switch self {
        case .low: return (0.10 * m, 0.26 * m)
        case .medium: return (0.13 * m, 0.32 * m)
        case .high: return (0.16 * m, 0.38 * m)
        }
    }
}

enum SGEngravedAppearanceMode: Hashable, Sendable {
    case engraved
    case raised
}

/// Deljen zadati tus za ugravirano označavanje (glavni meni, dugmad).
enum SGEngravedTextTheme {
    static let lightInk = Color(red: 43 / 255, green: 38 / 255, blue: 34 / 255)
    static let darkInk = Color(red: 232 / 255, green: 227 / 255, blue: 221 / 255)

    static func defaultInk(for mode: SGThemeMode) -> Color {
        switch mode {
        case .light: return lightInk
        case .dark: return darkInk
        case .neonPulse: return SGColors.neonTextPrimary
        }
    }
}

// MARK: - Modifier

struct SGEngravedTextModifier: ViewModifier {
    @Environment(\.sgThemeMode) private var themeMode
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var mode: SGEngravedAppearanceMode = .engraved
    var intensity: SGEngravedTextIntensity = .medium
    var isPressed: Bool = false
    /// `nil` = podrazumevani „kameni“ tus po temi.
    var color: Color?

    private var contrastFactor: CGFloat {
        colorSchemeContrast == .increased ? CGFloat(0.78) : 1
    }

    private var darkEnvelope: CGFloat {
        themeMode == .dark ? CGFloat(0.62) : 1
    }

    private var highlightEnvelope: CGFloat {
        themeMode == .dark ? CGFloat(0.48) : 1
    }

    func body(content: Content) -> some View {
        let ink = resolvedColor
        Group {
            if reduceTransparency {
                content
                    .foregroundStyle(ink)
            } else {
                switch mode {
                case .engraved:
                content
                    .foregroundStyle(ink)
                    .shadow(color: engravedHighlightColor.opacity(highlightOpacityFinal), radius: engravedHighlightRadiusFinal, x: 0, y: engravedHighlightYFinal)
                    .shadow(color: Color.black.opacity(darkOpacityFinal), radius: 1, x: 0, y: 1 + pressedYOffsetBump)
                    .shadow(color: ambientColor.opacity(ambientOpacityFinal), radius: 2, x: 0, y: 1.5 + pressedYOffsetBump)
                case .raised:
                    content
                        .foregroundStyle(ink)
                        .shadow(color: Color.black.opacity(Double(raisedDarkOpacity)), radius: 0.85, x: 0, y: -1)
                        .shadow(color: engravedHighlightColor.opacity(Double(raisedHlOpacity)), radius: 1, x: 0, y: 1)
                }
            }
        }
        .brightness(isPressed ? -0.058 : 0)
        .offset(y: isPressed ? 0.5 : 0)
        .animation(.easeOut(duration: 0.22), value: isPressed)
    }

    private var resolvedColor: Color {
        color ?? SGEngravedTextTheme.defaultInk(for: themeMode)
    }

    private var engravedHighlightColor: Color { themeMode == .light ? Color.white : Color.white.opacity(0.92) }

    private var ambientColor: Color { Color(red: 95 / 255, green: 72 / 255, blue: 58 / 255) }

    private var pressedHighlightMul: CGFloat { isPressed ? 0.55 : 1 }
    private var pressedYOffsetBump: CGFloat { isPressed ? 0.5 : 0 }

    private var baseFactors: (dark: CGFloat, highlight: CGFloat, ambient: CGFloat) {
        intensity.baseFactors()
    }

    private var darkOpacityFinal: Double {
        let v = Double(baseFactors.dark) * Double(darkEnvelope) * Double(contrastFactor)
        return min(1, v)
    }

    private var highlightOpacityFinal: Double {
        let v = Double(baseFactors.highlight) * Double(highlightEnvelope) * Double(contrastFactor) * Double(pressedHighlightMul)
        return min(1, v)
    }

    private var ambientOpacityFinal: Double {
        let v = Double(baseFactors.ambient) * Double(themeMode == .dark ? 0.42 : 1) * Double(contrastFactor) * Double(isPressed ? 0.82 : 1)
        return min(1, v)
    }

    private var engravedHighlightRadiusFinal: CGFloat {
        CGFloat(intensity == .low ? 0.55 : (intensity == .medium ? 0.72 : 0.95))
    }

    private var engravedHighlightYFinal: CGFloat {
        (-1 + (isPressed ? 0.08 : 0))
    }

    private var rf: (dark: CGFloat, highlight: CGFloat) { intensity.raisedFactors() }

    private var raisedDarkOpacity: CGFloat {
        min(1, rf.dark * darkEnvelope * contrastFactor)
    }

    private var raisedHlOpacity: CGFloat {
        min(1, rf.highlight * highlightEnvelope * contrastFactor * pressedHighlightMul)
    }
}

// MARK: - View helpers

extension View {
    func sgEngravedText(intensity: SGEngravedTextIntensity, isPressed: Bool = false, color: Color? = nil) -> some View {
        modifier(SGEngravedTextModifier(mode: .engraved, intensity: intensity, isPressed: isPressed, color: color))
    }

    /// Blago kao da tekst pomalo stoji iznad površine — suptilan par senki bez „skeuo“ jakosti.
    func sgRaisedText(intensity: SGEngravedTextIntensity = .medium, isPressed: Bool = false, color: Color? = nil) -> some View {
        modifier(SGEngravedTextModifier(mode: .raised, intensity: intensity, isPressed: isPressed, color: color))
    }
}
