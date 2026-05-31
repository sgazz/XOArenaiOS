//
//  GamePauseMenuOverlay.swift
//  XOArena
//

import SwiftUI

struct GamePauseMenuOverlay: View {
    @Environment(\.sgThemeMode) private var themeMode

    let onResume: () -> Void
    let onRestart: () -> Void
    let onMainMenu: () -> Void

    @State private var appearPhase: CGFloat = 0

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    private var cardInk: Color {
        switch themeMode {
        case .light: return SGColors.inkPrimaryLight
        case .dark: return SGColors.textDark
        case .neonPulse: return SGColors.neonTextPrimary
        }
    }

    private var cardFill: Color {
        switch themeMode {
        case .light:
            return Color(red: 243 / 255, green: 237 / 255, blue: 230 / 255)
        case .dark:
            return Color(red: 48 / 255, green: 45 / 255, blue: 42 / 255)
        case .neonPulse:
            return SGColors.neonSurfaceGlass
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.06 * Double(appearPhase))
                .ignoresSafeArea()
                .contentShape(Rectangle())

            VStack(alignment: .leading, spacing: SGSpacing.md) {
                Text("Paused")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(cardInk.opacity(0.94))
                    .sgEngravedText(intensity: .medium, color: cardInk.opacity(0.94))

                VStack(spacing: SGSpacing.sm) {
                    pauseActionButton("Resume", prominent: true, action: onResume)
                    pauseActionButton("Restart", prominent: false, action: onRestart)
                    pauseActionButton("Main Menu", prominent: false, action: onMainMenu)
                }
            }
            .padding(20)
            .frame(maxWidth: 280)
            .background(cardBackground)
            .opacity(Double(appearPhase))
            .scaleEffect(CGFloat(0.97 + 0.03 * appearPhase))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game paused. Resume, restart, or return to main menu.")
        .onAppear {
            appearPhase = 0
            withAnimation(.easeInOut(duration: 0.18)) {
                appearPhase = 1
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(cardFill)
            .overlay {
                if themeMode.isNeonPulse {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(SGColors.neonBorder, lineWidth: 1)
                }
            }
            .shadow(color: themeMode.isNeonPulse ? SGColors.neonCyan.opacity(0.2) : Color.white.opacity(themeMode == .light ? 0.35 : 0.24), radius: themeMode.isNeonPulse ? 10 : 1, x: themeMode.isNeonPulse ? 0 : -1.5, y: themeMode.isNeonPulse ? 0 : -1.5)
            .shadow(color: themeMode.isNeonPulse ? SGColors.neonMagenta.opacity(0.14) : Color(red: 73 / 255, green: 58 / 255, blue: 48 / 255).opacity(themeMode == .light ? 0.2 : 0.32), radius: themeMode.isNeonPulse ? 6 : 3, x: themeMode.isNeonPulse ? 0 : 2, y: themeMode.isNeonPulse ? 0 : 3)
    }

    private func pauseActionButton(_ title: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.lightImpact()
            action()
        } label: {
            Text(title)
                .font(.system(size: prominent ? 15 : 14, weight: prominent ? .semibold : .medium, design: .rounded))
                .foregroundStyle(prominent ? t.primaryButtonLabel : cardInk.opacity(prominent ? 0.96 : 0.82))
                .frame(maxWidth: .infinity)
                .padding(.vertical, prominent ? 10 : 8)
                .background {
                    if prominent {
                        RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                            .fill(t.accent)
                    }
                }
        }
        .buttonStyle(GamePauseActionPressStyle())
    }
}

private struct GamePauseActionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    GamePauseMenuOverlay(onResume: {}, onRestart: {}, onMainMenu: {})
        .environment(\.sgThemeMode, .light)
}
