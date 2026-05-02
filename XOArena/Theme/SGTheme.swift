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

/// Ikona‑only (bez kapsula); mikro-feedback preko opacity.
private struct ToolbarThemeIconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.38 : 0.6)
            .animation(.easeInOut(duration: 0.25), value: configuration.isPressed)
    }
}

/// Quiet dev toggle — does not dominate the bar.
struct SGThemeToggleControl: View {
    @EnvironmentObject private var themeManager: SGThemeManager

    var body: some View {
        Button {
            themeManager.mode = themeManager.mode == .light ? .dark : .light
        } label: {
            Image(systemName: themeManager.mode == .light ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(themeManager.mode == .light ? SGColors.inkPrimaryLight : SGColors.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarThemeIconPressStyle())
        .accessibilityLabel(themeManager.mode == .light ? "Dark mode" : "Light mode")
        .accessibilityHint("Prebacuje između svetlog i tamnog izgleda.")
    }
}
