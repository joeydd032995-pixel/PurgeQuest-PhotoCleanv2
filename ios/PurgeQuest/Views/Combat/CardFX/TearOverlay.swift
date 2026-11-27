//
//  TearOverlay.swift
//  PurgeQuest
//
//  The delete drag's overlay (design section 4): a jagged void that grows from the card's left edge as the drag
//  grows, widening when the commit line is crossed. It replaces the old full-card crimson wash, which tinted the
//  whole photo. Strongest at the edge, gone by 34% of the card's width, so most of the picture stays clear.
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
        let depth = rect.width * widthFraction
        guard depth > 0.5 else { return path }
        let steps = 14
        func point(_ i: Int) -> CGPoint {
            let t = Double(i) / Double(steps)
            let jag = i.isMultiple(of: 2) ? 1.0 : 0.6
            let wobble = 0.85 + 0.15 * sin(t * 9)
            return CGPoint(x: rect.minX + depth * jag * wobble, y: rect.minY + rect.height * t)
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
        ZStack {
            TearShape(widthFraction: width)
                .fill(LinearGradient(
                    colors: [
                        Color.black.opacity(alpha),
                        Color.combatCrimsonDeep.opacity(alpha * 0.7),
                        Color.combatCrimson.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: UnitPoint(x: max(width, 0.01), y: 0.5)
                ))
            TearShape(widthFraction: width, edgeOnly: true)
                .stroke(Color.combatCrimson.opacity(min(1, alpha * (armed ? 1.8 : 1.2))), lineWidth: armed ? 2.5 : 1.5)
        }
        .animation(animated ? .spring(response: 0.18, dampingFraction: 0.6) : nil, value: armed)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
