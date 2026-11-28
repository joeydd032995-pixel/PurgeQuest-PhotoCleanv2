//
//  LitEdge.swift
//  PurgeQuest
//
//  The faint rim a flat tile takes from the torch: a 1 pt line that is white on the side the light comes from, clear
//  in the middle and black on the far side. It is the recipe ExhibitFrame already uses for the combat card's frame,
//  with the same end points from `LightSource`, so every lit edge in the app agrees (design:
//  docs/superpowers/specs/2026-11-28-atmosphere-and-light-design.md, section 4.2).
//
//      .litEdge(cornerRadius: 12)
//
//  One alpha pair serves both appearances: the highlight shows on a dark tile and the shade on a light one.
//

import SwiftUI

private struct LitEdge: ViewModifier {
    let cornerRadius: CGFloat

    /// White on the lit side, clear in the middle, black on the far side: the frame's recipe, from `LightSource`.
    /// A computed property with an explicit `return`, as `ExhibitFrame.frameBackground` does, so `body` stays one
    /// expression.
    private var rim: LinearGradient {
        let points = LightSource.highlightPoints()
        let litStart = UnitPoint(x: CGFloat(points.start.x), y: CGFloat(points.start.y))
        let litEnd = UnitPoint(x: CGFloat(points.end.x), y: CGFloat(points.end.y))
        let colors: [Color] = [
            Color.white.opacity(LightSource.rimHighlightAlpha),
            Color.white.opacity(0),
            Color.black.opacity(LightSource.rimShadeAlpha)
        ]
        return LinearGradient(colors: colors, startPoint: litStart, endPoint: litEnd)
    }

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(rim, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

extension View {
    /// A faint rim from the torch: lit on the top left, shaded on the bottom right. Draws inside the view's bounds.
    func litEdge(cornerRadius: CGFloat) -> some View {
        modifier(LitEdge(cornerRadius: cornerRadius))
    }
}
