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

    /// Mixes this color toward another by the given amount (0 to 1). Used by
    /// the armor dye system to tint cloth while keeping the same value range.
    func blended(with other: Color, amount: Double) -> Color {
        let t = min(max(amount, 0), 1)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double(r1 + (r2 - r1) * t),
            green: Double(g1 + (g2 - g1) * t),
            blue: Double(b1 + (b2 - b1) * t)
        )
    }
}
