//
//  PvAISetupSheet.swift
//  XOArena
//

import SwiftUI

/// **PvAI** podešavanje — **SG Quiet**: `paperLight` / `paperDark`, blage ivice, naglašenje preko `accentSubtle`, CTA kao **`SGButton`** (isti akcent kao ostatak app-a).
struct PvAISetupSheet: View {
    @Environment(\.sgThemeMode) private var themeMode

    let onStart: (_ symbol: PlayerSymbolChoice, _ first: FirstMoverChoice) -> Void

    @State private var symbol: PlayerSymbolChoice = .x
    @State private var firstMove: FirstMoverChoice = .player

    private var t: XOTheme.Tokens { XOTheme.tokens(for: themeMode) }

    private var sheetPaper: Color {
        themeMode == .light ? SGColors.paperLight : SGColors.paperDark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.lg) {
            section(
                title: "Play as",
                accessibilityRoot: "Play as"
            ) {
                HStack(spacing: SGSpacing.sm) {
                    ForEach(PlayerSymbolChoice.allCases) { choice in
                        pickButton(
                            title: choice.displayLetter,
                            selected: symbol == choice
                        ) {
                            symbol = choice
                        }
                        .accessibilityLabel("Play as \(choice.displayLetter)")
                    }
                }
            }

            section(
                title: "First move",
                accessibilityRoot: "First move"
            ) {
                HStack(spacing: SGSpacing.sm) {
                    ForEach(FirstMoverChoice.allCases) { choice in
                        pickButton(
                            title: choice.labelYou,
                            selected: firstMove == choice
                        ) {
                            firstMove = choice
                        }
                        .accessibilityLabel("First move \(choice.labelYou)")
                    }
                }
            }

            SGButton(title: "Start", variant: .primary) {
                HapticService.lightImpact()
                onStart(symbol, firstMove)
            }
            .padding(.top, SGSpacing.xs)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SGSpacing.lg)
        .padding(.top, SGSpacing.md)
        .padding(.bottom, SGSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(sheetPaper.ignoresSafeArea())
    }

    private func section<Content: View>(
        title: String,
        accessibilityRoot: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Text(title)
                .font(SGTypography.small)
                .foregroundStyle(t.textSecondary.opacity(themeMode == .light ? 0.88 : 0.82))
                .tracking(0.15)
                .accessibilityLabel(accessibilityRoot)
            content()
        }
        .accessibilityElement(children: .contain)
    }

    private func pickButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SGTypography.body)
                .fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(selected ? t.textPrimary : t.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                        .fill(pickerFill(selected: selected))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                        .strokeBorder(pickerBorder(selected: selected), lineWidth: 1)
                )
        }
        .buttonStyle(SheetPickerRippleStyle(themeMode: themeMode))
    }

    private func pickerFill(selected: Bool) -> Color {
        if selected {
            return themeMode == .light
                ? t.accentSubtle.opacity(0.22)
                : t.accentSubtle.opacity(0.12)
        }
        return themeMode == .light
            ? SGColors.surfaceLight.opacity(0.42)
            : SGColors.surfaceDark.opacity(0.38)
    }

    private func pickerBorder(selected: Bool) -> Color {
        if selected {
            return t.accent.opacity(themeMode == .light ? 0.42 : 0.5)
        }
        return themeMode == .light
            ? SGColors.borderLightWarm.opacity(0.65)
            : SGColors.borderDark.opacity(0.55)
    }
}

/// Blagi pritisak kao **`PlainSecondaryInkStyle`**, prilagođen sheet-u.
private struct SheetPickerRippleStyle: ButtonStyle {
    let themeMode: SGThemeMode

    func makeBody(configuration: Configuration) -> some View {
        let core = themeMode == .light
            ? SGColors.inkPrimaryLight.opacity(0.1)
            : Color.white.opacity(0.08)
        return configuration.label
            .overlay {
                RadialGradient(colors: [core, core.opacity(0)], center: .center, startRadius: 0, endRadius: 88)
                    .blendMode(themeMode == .light ? .multiply : .overlay)
                    .scaleEffect(configuration.isPressed ? 1.2 : 0.2)
                    .opacity(configuration.isPressed ? 1 : 0)
                    .animation(.easeOut(duration: 0.26), value: configuration.isPressed)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.22), value: configuration.isPressed)
    }
}
