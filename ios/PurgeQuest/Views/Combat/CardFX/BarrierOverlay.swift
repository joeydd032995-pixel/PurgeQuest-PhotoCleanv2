//
//  BarrierOverlay.swift
//  PurgeQuest
//
//  The keep drag's overlay (design section 4): a brass ward that rises along the screen's right edge as the drag
//  grows and locks, brighter, when the commit line is crossed. Defensive, not celebratory: a bowed line and a soft
//  inward glow, gone by 24% of the width it is drawn in. The KEEP stamp stays patina; only the barrier is brass.
//  `ScreenEdgeOverlay` draws it at the screen's edge, not on the card.
//

import SwiftUI

/// The ward's outline: the card's right edge and a quadratic arc bowing inward. `edgeOnly` is just the arc.
struct BarrierShape: Shape {
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
        // A quadratic curve reaches half of its control offset, so the control sits 2x depth in for an arc `depth` deep.
        let controlX: CGFloat = rect.maxX - depth * 2
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: controlX, y: rect.midY)
        )
        if !edgeOnly { path.closeSubpath() }
        return path
    }
}

struct BarrierOverlay: View {
    /// 0...1: how far the drag has gone toward Keep.
    let strength: Double
    /// True once the commit line is crossed: the ward widens, thickens and brightens.
    let armed: Bool
    /// False under Reduce Motion or Low Power: the armed shape then shows at once.
    let animated: Bool

    var body: some View {
        let width = EdgeOverlay.barrierWidth(strength: strength, armed: armed)
        let alpha = EdgeOverlay.barrierAlpha(strength: strength)
        let reach = CGFloat(max(width, 0.01))
        let fillColors: [Color] = [
            Color.questAmber.opacity(alpha),
            Color.questAmber.opacity(alpha * 0.35),
            Color.questAmber.opacity(0)
        ]
        let fill = LinearGradient(colors: fillColors, startPoint: .trailing, endPoint: UnitPoint(x: 1 - reach, y: 0.5))
        let edgeAlpha: Double = min(1, alpha * (armed ? 2.0 : 1.4))
        let edgeWidth: CGFloat = armed ? 3 : 1.5
        let spring: Animation? = animated ? .spring(response: 0.18, dampingFraction: 0.6) : nil
        ZStack {
            BarrierShape(widthFraction: width)
                .fill(fill)
            BarrierShape(widthFraction: width, edgeOnly: true)
                .stroke(Color.questAmber.opacity(edgeAlpha), lineWidth: edgeWidth)
        }
        .animation(spring, value: armed)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
