//
//  ComboRim.swift
//  PurgeQuest
//
//  What the combo looks like on the front card (design section 6): a steady brass glow on the rim that rises with
//  the multiplier, a thin second line inside the rim from x1.5, a brightness pulse when the card arrives after a
//  deletion that raised the multiplier, one metallic sheen across the rim at x2.0, and a fade from brass to ash when
//  a keep took 12% of it. Event-driven: nothing here loops. It is drawn inside the frame's background, which sits
//  behind the photo, so it can only ever light the rim.
//

import SwiftUI

/// Everything the rim needs to draw one moment of the combo.
struct ComboRimState: Equatable {
    var tier: ComboTier
    /// 0...1 brightness bump on arrival after a raise.
    var pulse: Double = 0
    /// Where the sheen band is across the frame, as a fraction of its width. Outside 0...1 it is off the frame.
    var sheen: CGFloat = -0.4
    /// 0...1 how much of the glow is ash instead of brass (the cooling after a keep).
    var cool: Double = 0
    /// 0...1 overall visibility: it fades in over 150 ms under Reduce Motion or Low Power, instead of moving.
    var shown: Double = 1
}

struct ComboRim: View {
    let state: ComboRimState
    let outerRadius: CGFloat
    let rim: CGFloat

    var body: some View {
        let glow: Double = state.tier.glowAlpha * state.shown
        // A cooling card shows at least a soft ash even at x1.0, so a keep's cost is felt there too.
        let brassAlpha: Double = min(1, (glow + state.pulse * 0.5) * (1 - state.cool))
        let ashAlpha: Double = min(1, max(glow, 0.3) * state.cool * state.shown)
        let lineWidth: CGFloat = max(1, rim - 1)
        let shape = RoundedRectangle(cornerRadius: outerRadius)
        let innerLineAlpha: Double = 0.6 * state.shown
        ZStack {
            shape.strokeBorder(Color.questAmber.opacity(brassAlpha), lineWidth: lineWidth)
            shape.strokeBorder(Color(white: 0.62).opacity(ashAlpha), lineWidth: lineWidth)
            if state.tier.hasInnerLine {
                shape.inset(by: rim - 1.4).stroke(Color.questAmber.opacity(innerLineAlpha), lineWidth: 0.8)
            }
            sheenBand
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One bright band that crosses the rim once, at x2.0.
    private var sheenBand: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let bandWidth: CGFloat = width * 0.3
            let colors: [Color] = [Color.clear, Color.white.opacity(0.6), Color.clear]
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                .frame(width: bandWidth)
                .offset(x: state.sheen * width - bandWidth / 2)
        }
        .mask {
            RoundedRectangle(cornerRadius: outerRadius).strokeBorder(Color.white, lineWidth: rim)
        }
        .opacity(state.tier.isMax ? 1 : 0)
    }
}
