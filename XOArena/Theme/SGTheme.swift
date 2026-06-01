//
//  SGTheme.swift
//  XOArena
//

import Combine
import SwiftUI

enum SGThemeMode: String, CaseIterable, Hashable, Sendable {
    case light
    case dark
    case neonPulse

    /// Stable persistence / settings key (e.g. **`neonPulse`**).
    var themeKey: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .neonPulse: return "Neon Pulse"
        }
    }

    var usesLightPaper: Bool { self == .light }
    var isNeonPulse: Bool { self == .neonPulse }

    /// Appearance toggle exposes only these (Neon Pulse remains in code, hidden for now).
    static let userFacing: [SGThemeMode] = [.light, .dark]

    var isUserFacing: Bool { Self.userFacing.contains(self) }

    func nextUserFacing() -> SGThemeMode {
        switch self {
        case .light: return .dark
        case .dark: return .light
        case .neonPulse: return .light
        }
    }
}

private struct SGThemeModeKey: EnvironmentKey {
    static let defaultValue: SGThemeMode = .light
}

extension EnvironmentValues {
    var sgThemeMode: SGThemeMode {
        get { self[SGThemeModeKey.self] }
        set { self[SGThemeModeKey.self] = newValue }
    }
}

/// Default light; user toggle cycles **Light ↔ Dark** only. Wired from `ContentView`.
@MainActor
final class SGThemeManager: ObservableObject {
    @Published var mode: SGThemeMode = .light

    func cycleTheme() {
        mode = mode.nextUserFacing()
    }
}

/// Ikona‑only (bez kapsula); mikro-feedback preko opacity.
private struct ToolbarThemeIconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.38 : 0.6)
            .animation(.easeInOut(duration: 0.25), value: configuration.isPressed)
    }
}

/// Quiet theme picker — cycles appearance presets without dominating the bar.
struct SGThemeToggleControl: View {
    @EnvironmentObject private var themeManager: SGThemeManager
    @Environment(\.sgThemeMode) private var themeMode

    private var iconName: String {
        switch themeManager.mode {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .neonPulse: return "sparkles"
        }
    }

    var body: some View {
        Button {
            HapticService.lightImpact()
            themeManager.cycleTheme()
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(themeManager.mode.isNeonPulse ? SGColors.neonCyan : (themeManager.mode == .light ? SGColors.inkPrimaryLight : SGColors.textSecondary))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarThemeIconPressStyle())
        .accessibilityLabel("Theme: \(themeManager.mode.displayName)")
        .accessibilityHint("Prebacuje između Light i Dark.")
    }
}
