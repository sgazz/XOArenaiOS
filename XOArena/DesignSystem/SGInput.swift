//
//  SGInput.swift
//  XOArena
//

import SwiftUI

struct SGInput: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.xs) {
            Text(title)
                .font(SGTypography.small)
                .foregroundStyle(SGColors.textSecondary)

            TextField("", text: $text)
                .font(SGTypography.body)
                .foregroundStyle(SGColors.textDark)
                .padding(.horizontal, SGSpacing.md)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                        .fill(SGColors.surfaceDark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SGRadius.md, style: .continuous)
                        .strokeBorder(SGColors.borderDark, lineWidth: 1)
                )
        }
    }
}
