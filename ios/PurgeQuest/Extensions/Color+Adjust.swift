//
//  Color+Adjust.swift
//  PurgeQuest
//
//  Tonal adjustment helpers for the avatar cel system: shifting a base tone
//  toward white for lit bands and toward black for shadow bands.
//

import SwiftUI
import UIKit

extension Color {
    /// Shifts the color toward white by the given amount (0 to 1).
    func lighter(_ amount: Double) -> Color {
        let clamped = min(max(amount, 0), 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: Double(r + (1 - r) * clamped),
            green: Double(g + (1 - g) * clamped),
            blue: Double(b + (1 - b) * clamped)
        )
    }

    /// Shifts the color toward black by the given amount (0 to 1).
    func darker(_ amount: Double) -> Color {
        let clamped = min(max(amount, 0), 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: Double(r * (1 - clamped)),
            green: Double(g * (1 - clamped)),
            blue: Double(b * (1 - clamped))
        )
    }
}
