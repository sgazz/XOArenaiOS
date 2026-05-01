//
//  SGTypography.swift
//  XOArena
//

import SwiftUI

enum SGTypography {
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    static let small = Font.system(size: 12, weight: .regular, design: .rounded)
    static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let mainTitle = Font.system(size: 28, weight: .semibold, design: .serif)

    /// Hand-ish micro label for active focus (readable, calm; not pretending to be a real script font).
    static let inkActiveStamp = Font.system(size: 9, weight: .semibold, design: .serif)

    /// Calm airy titles (intro + headings).
    static let titleTracking: CGFloat = 2.5
    static let subtitleTracking: CGFloat = 1.05
}
