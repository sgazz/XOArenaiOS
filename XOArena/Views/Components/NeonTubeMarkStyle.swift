//
//  NeonTubeMarkStyle.swift
//  XOArena
//

import SwiftUI

/// Glow tier for Neon Pulse board marks (performance-safe: max two shadows per mark).
enum NeonMarkEmphasis: Sendable, Equatable {
    case standard
    case placementPulse
    case winning

    var tightGlowRadius: CGFloat {
        switch self {
        case .standard: return 5
        case .placementPulse: return 6
        case .winning: return 7
        }
    }

    var ambientGlowRadius: CGFloat {
        switch self {
        case .standard: return 16
        case .placementPulse: return 19
        case .winning: return 22
        }
    }

    var strokeBoost: CGFloat {
        switch self {
        case .standard: return 1.14
        case .placementPulse: return 1.18
        case .winning: return 1.22
        }
    }

    var tightGlowOpacity: Double {
        switch self {
        case .standard: return 0.78
        case .placementPulse: return 0.86
        case .winning: return 0.92
        }
    }

    var ambientGlowOpacity: Double {
        switch self {
        case .standard: return 0.46
        case .placementPulse: return 0.54
        case .winning: return 0.62
        }
    }
}

enum NeonTubeMarkStyle {
    /// Slightly wider strokes vs paper themes; kept below grid dominance.
    static let neonStrokeBoost: CGFloat = 1.12

    static func glowColors(for mark: Mark) -> (tight: Color, ambient: Color) {
        switch mark {
        case .x:
            return (SGColors.neonMagenta, SGColors.neonMagentaSoft)
        case .o:
            return (SGColors.neonCyan, SGColors.neonCyanSoft)
        case .empty:
            return (.clear, .clear)
        }
    }

    static func tubeColors(for mark: Mark) -> (edge: Color, mid: Color, core: Color) {
        switch mark {
        case .x:
            return (
                SGColors.neonMagenta,
                Color(red: 1, green: 0.72, blue: 0.92),
                SGColors.neonWhiteCore
            )
        case .o:
            return (
                SGColors.neonCyan,
                Color(red: 0.78, green: 0.98, blue: 1),
                SGColors.neonWhiteCore
            )
        case .empty:
            return (.clear, .clear, .clear)
        }
    }
}
