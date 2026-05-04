//
//  WatchLayoutMetrics.swift
//  XOArenaWatch — adaptive layout across 40/41mm, 44/45mm, Ultra (~49mm).
//

import SwiftUI

/// Sizes derived from the **watch screen** `GeometryProxy` root (full safe content area).
struct WatchLayoutMetrics {
    let size: CGSize

    /// Typical 40/41 mm portrait content.
    var isSmall: Bool { size.height < 200 || size.width < 180 }

    /// 49 mm Ultra / tall layouts.
    var isLarge: Bool { size.height > 230 }

    // MARK: - Hero row

    var heroFont: CGFloat {
        switch (isSmall, isLarge) {
        case (true, _): return 15
        case (_, true): return 18
        default: return 17
        }
    }

    var heroBoardLabelFont: CGFloat { heroFont }

    var heroHorizontalPadding: CGFloat { isSmall ? 3 : 4 }

    var heroBarTopPadding: CGFloat { isSmall ? 0 : 1 }

    var heroBarBottomPadding: CGFloat { isSmall ? 2 : 3 }

    /// Spacers ∞ or clock | B | score (timed mode).
    var heroSpacerStandard: CGFloat {
        if isSmall { return 5 }
        if isLarge { return 11 }
        return 8
    }

    /// Tighter row when ∞ + score + cancel share width.
    var heroSpacerNoTime: CGFloat {
        if isSmall { return 3 }
        if isLarge { return 9 }
        return 6
    }

    var heroCancelTrailing: CGFloat { isSmall ? 2 : 6 }

    var xmarkSize: CGFloat {
        switch (isSmall, isLarge) {
        case (true, _): return 11
        case (_, true): return 13
        default: return 12
        }
    }

    var xmarkTapMin: CGFloat { isSmall ? 28 : 32 }

    // MARK: - Board grid

    var boardGap: CGFloat {
        if isSmall { return 3 }
        if isLarge { return 4.25 }
        return 3.5
    }

    var cellCornerRadius: CGFloat {
        if isSmall { return 9 }
        if isLarge { return 14 }
        return 12
    }

    // MARK: - Setup

    /// Section-to-section spacing in setup stack.
    var setupSpacing: CGFloat {
        if isSmall { return 10 }
        if isLarge { return 18 }
        return 14
    }

    var setupSectionInnerSpacing: CGFloat { isSmall ? 5 : 6 }

    var setupHeaderFontSize: CGFloat { isSmall ? 10 : 11 }

    var setupPillFontSize: CGFloat { isSmall ? 12 : 13 }

    var setupPillVerticalPadding: CGFloat {
        if isSmall { return 6 }
        if isLarge { return 9 }
        return 8
    }

    var setupTimePillsHSpacing: CGFloat { isSmall ? 4 : 5 }

    var setupHorizontalPadding: CGFloat { isSmall ? 5 : 6 }

    var setupTopPadding: CGFloat { isSmall ? 2 : 4 }

    var setupBottomPadding: CGFloat { isSmall ? 6 : 8 }

    var startButtonFontSize: CGFloat { isSmall ? 12 : 13 }

    var startButtonVerticalPadding: CGFloat {
        if isSmall { return 8 }
        if isLarge { return 11 }
        return 10
    }

    // MARK: - Intro

    var introIconSize: CGFloat {
        let h = size.height
        if isSmall { return clampMetric(h * 0.39, lower: 70, upper: 88) }
        if isLarge { return clampMetric(h * 0.33, lower: 100, upper: 118) }
        return clampMetric(h * 0.36, lower: 86, upper: 104)
    }

    var introIconCornerRadius: CGFloat { introIconSize * 0.2 }

    var introTitleSize: CGFloat {
        switch (isSmall, isLarge) {
        case (true, _): return 17
        case (_, true): return 20
        default: return 19
        }
    }

    var introSubtitleSize: CGFloat {
        switch (isSmall, isLarge) {
        case (true, _): return 11
        case (_, true): return 13
        default: return 12
        }
    }

    var introIconTitleGap: CGFloat {
        if isSmall { return 10 }
        if isLarge { return 14 }
        return 12
    }

    var introTitleSubtitleGap: CGFloat { isSmall ? 4 : 5 }

    // MARK: - End

    var endVStackSpacing: CGFloat {
        if isSmall { return 10 }
        if isLarge { return 16 }
        return 14
    }

    var endTitleFont: CGFloat {
        if isSmall { return 16 }
        if isLarge { return 19 }
        return 18
    }

    var endScoreFont: CGFloat { isSmall ? 12 : 13 }

    var endDurationFont: CGFloat { isSmall ? 12 : 13 }

    var endScoreRowHSpacing: CGFloat { isSmall ? 14 : 22 }

    var endHorizontalPadding: CGFloat { isSmall ? 6 : 8 }

    var endVerticalPadding: CGFloat { isSmall ? 6 : 8 }

    var playAgainVerticalPadding: CGFloat { isSmall ? 8 : 9 }

    // MARK: - In-game feedback chip

    var boardFeedbackFontSize: CGFloat { isSmall ? 12 : 13 }

    private func clampMetric(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, lower), upper)
    }
}
