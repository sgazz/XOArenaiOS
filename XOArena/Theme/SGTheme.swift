//
//  SGTheme.swift
//  XOArena
//

import Combine
import SwiftUI

enum SGThemeMode: Hashable, Sendable {
    case light
    case dark
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

/// Default light; persisted later. Wired from `ContentView` + `ObservableObject`.
@MainActor
final class SGThemeManager: ObservableObject {
    @Published var mode: SGThemeMode = .light
}

/// Quiet dev toggle — does not dominate the bar.
struct SGThemeToggleControl: View {
    @EnvironmentObject private var themeManager: SGThemeManager

    var body: some View {
        Button {
            themeManager.mode = themeManager.mode == .light ? .dark : .light
        } label: {
            HStack(spacing: SGSpacing.xs) {
                Image(systemName: themeManager.mode == .light ? "moon.fill" : "sun.max")
                    .font(SGTypography.small.weight(.medium))
                    .imageScale(.small)
                Text(themeManager.mode == .light ? "Dark" : "Light")
                    .font(SGTypography.small)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(themeManager.mode == .light ? SGColors.inkPrimaryLight.opacity(0.85) : SGColors.textSecondary)
        .accessibilityHint("Alternates cappuccino light and ink dark.")
    }
}
