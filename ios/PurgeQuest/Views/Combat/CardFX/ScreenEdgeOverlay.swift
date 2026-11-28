//
//  ScreenEdgeOverlay.swift
//  PurgeQuest
//
//  The tear and the barrier, drawn at the screen's own left and right edges instead of on the card. On the card they
//  slid off the screen with it and could barely be seen (the first tour's mid-drag shots). Here they stay put while
//  the card moves under them, over the whole deck area, so a drag toward Delete or Keep is read from the edge it is
//  heading for. They are the one bounded exception to "the photo is never touched" (design section 3.3), and only
//  while a finger is dragging: at rest nothing is drawn.
//

import SwiftUI

/// What the front card's drag is telling the screen's edges. The card writes it and only `ScreenEdgeOverlay` reads it,
/// so a drag redraws the overlay and nothing else (the combat screen itself does not read it).
@Observable
final class CardDragModel {
    var signal = EdgeSignal.rest
    /// False under Reduce Motion or Low Power Mode: the armed shape then shows at once and nothing is smoothed.
    var animated = true
}

struct ScreenEdgeOverlay: View {
    let model: CardDragModel

    var body: some View {
        let signal: EdgeSignal = model.signal
        let smoothing: Animation? = model.animated ? Animation.easeOut(duration: 0.18) : nil
        ZStack {
            TearOverlay(strength: signal.tearStrength, armed: signal.tearArmed, animated: model.animated)
            BarrierOverlay(strength: signal.barrierStrength, armed: signal.barrierArmed, animated: model.animated)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(smoothing, value: signal)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
