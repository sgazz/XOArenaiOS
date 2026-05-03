//
//  SGEngravedButton.swift
//  XOArena
//
//  Bez površine / ivica — tekst + ugravljavanje + pritisak.

import SwiftUI

enum SGEngravedTextButtonVariant: Hashable, Sendable {
    case primary(engravedIntensity: SGEngravedTextIntensity = .high)
    case secondary(opacity: CGFloat = 0.6)
    case timerOption(isSelected: Bool)
}

struct SGEngravedTextButtonStyle: ButtonStyle {
    @Environment(\.sgThemeMode) private var themeMode

    var variant: SGEngravedTextButtonVariant
    var primaryFont: Font
    var secondaryFont: Font
    var timerFontSelected: Font
    var timerFontUnselected: Font
    /// `nil` = podrazumevani tus kamena po **`sgThemeMode`**.
    var primaryInk: Color?

    init(
        variant: SGEngravedTextButtonVariant,
        primaryFont: Font = Font.system(.body, design: .rounded).weight(.semibold),
        secondaryFont: Font = Font.system(.body, design: .rounded).weight(.medium),
        timerFontSelected: Font = Font.system(.subheadline, design: .rounded).weight(.semibold),
        timerFontUnselected: Font = Font.system(.subheadline, design: .rounded),
        primaryInk: Color? = nil
    ) {
        self.variant = variant
        self.primaryFont = primaryFont
        self.secondaryFont = secondaryFont
        self.timerFontSelected = timerFontSelected
        self.timerFontUnselected = timerFontUnselected
        self.primaryInk = primaryInk
    }

    private var resolvedInk: Color {
        primaryInk ?? SGEngravedTextTheme.defaultInk(for: themeMode)
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        Group {
            switch variant {
            case .primary(let i):
                configuration.label
                    .font(primaryFont)
                    .foregroundStyle(resolvedInk)
                    .multilineTextAlignment(.center)
                    .sgEngravedText(intensity: i, isPressed: pressed, color: resolvedInk)

            case .secondary(let opacity):
                configuration.label
                    .font(secondaryFont)
                    .foregroundStyle(resolvedInk)
                    .opacity(opacity)
                    .multilineTextAlignment(.center)
                    .sgEngravedText(intensity: .low, isPressed: pressed, color: resolvedInk)

            case .timerOption(let selected):
                if selected {
                    configuration.label
                        .font(timerFontSelected)
                        .foregroundStyle(resolvedInk)
                        .sgEngravedText(intensity: .medium, isPressed: pressed, color: resolvedInk)
                } else {
                    configuration.label
                        .font(timerFontUnselected)
                        .foregroundStyle(resolvedInk)
                        .opacity(0.4)
                }
            }
        }
        .scaleEffect(pressed ? 0.98 : 1)
        .animation(.easeOut(duration: 0.2), value: pressed)
    }
}
