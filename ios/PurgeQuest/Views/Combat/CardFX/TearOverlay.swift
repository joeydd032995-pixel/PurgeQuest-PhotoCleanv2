//
//  TearOverlay.swift
//  PurgeQuest
//
//  The delete drag's overlay (design section 4): a jagged tear that grows from the screen's left edge as the drag
//  grows, widening when the commit line is crossed. It replaces the old full-card crimson wash, which tinted the
//  whole photo. Strongest at the edge, gone by 34% of the width it is drawn in, so most of the picture stays clear.
//  `ScreenEdgeOverlay` draws it at the screen's edge, not on the card.
//

import SwiftUI

/// The tear's outline: a deterministic zigzag, so it never flickers. `edgeOnly` is just the jagged edge, for a stroke.
struct TearShape: Shape {
    /// Fraction of the rectangle's width the tear reaches at its deepest.
    var widthFraction: Double
    var edgeOnly = false

    var animatableData: Double {
        get { widthFraction }
        set { widthFraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let depth: CGFloat = rect.width * CGFloat(widthFraction)
        guard depth > 0.5 else { return path }
        let steps = 14
        func point(_ i: Int) -> CGPoint {
            let t: CGFloat = CGFloat(i) / CGFloat(steps)
            let jag: CGFloat = i.isMultiple(of: 2) ? 1.0 : 0.6
            let wobble: CGFloat = 0.85 + 0.15 * sin(t * 9)
            let x: CGFloat = rect.minX + depth * jag * wobble
            let y: CGFloat = rect.minY + rect.height * t
            return CGPoint(x: x, y: y)
        }
        path.move(to: edgeOnly ? point(0) : CGPoint(x: rect.minX, y: rect.minY))
        for i in 0...steps { path.addLine(to: point(i)) }
        if !edgeOnly {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

struct TearOverlay: View {
    /// 0...1: how far the drag has gone toward Delete.
    let strength: Double
    /// True once the commit line is crossed: the tear opens wider and its edge brightens.
    let armed: Bool
    /// False under Reduce Motion or Low Power: the armed shape then shows at once.
    let animated: Bool

    var body: some View {
        let width = EdgeOverlay.tearWidth(strength: strength, armed: armed)
        let alpha = EdgeOverlay.tearAlpha(strength: strength)
        let reach = CGFloat(max(width, 0.01))
        // Crimson from the edge inward: the first tour's black-first fill vanished on the Dark canvas.
        let fillColors: [Color] = [
            Color.combatCrimson.opacity(alpha),
            Color.combatCrimsonDeep.opacity(alpha * 0.7),
            Color.combatCrimson.opacity(0)
        ]
        let fill = LinearGradient(colors: fillColors, startPoint: .leading, endPoint: UnitPoint(x: reach, y: 0.5))
        let edgeAlpha: Double = min(1, alpha * (armed ? 1.8 : 1.2))
        let edgeWidth: CGFloat = armed ? 2.5 : 1.5
        let spring: Animation? = animated ? .spring(response: 0.18, dampingFraction: 0.6) : nil
        ZStack {
            TearShape(widthFraction: width)
                .fill(fill)
            TearShape(widthFraction: width, edgeOnly: true)
                .stroke(Color.combatCrimson.opacity(edgeAlpha), lineWidth: edgeWidth)
        }
        .animation(spring, value: armed)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
