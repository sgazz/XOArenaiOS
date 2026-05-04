//
//  WatchQuietButtonStyles.swift
//  XOArenaWatch
//

import SwiftUI

/// Capsule selection / CTA — subtle scale on press (no spring).
struct WatchQuietCapsulePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
