//
//  IrisTransition.swift
//  PurgeQuest
//
//  How a Live Photo starts to play on the combat card (design section 6): the moving picture is revealed through a
//  circle that grows from the corner where the LIVE badge sits, and closes back into it when playback stops. It
//  replaces the plain opacity toggle. Under Reduce Motion or Low Power Mode the card keeps the plain 200 ms cross-fade.
//

import SwiftUI

struct IrisTransition: Transition {
    /// Where the circle opens from, in the view's own points: near the LIVE badge.
    let origin: CGPoint

    func body(content: Content, phase: TransitionPhase) -> some View {
        content.mask {
            GeometryReader { proxy in
                let reach: CGFloat = max(proxy.size.width, proxy.size.height) * 2.6
                let scale: CGFloat = phase.isIdentity ? 1 : 0.001
                Circle()
                    .frame(width: reach, height: reach)
                    .scaleEffect(scale, anchor: .center)
                    .position(x: origin.x, y: origin.y)
            }
        }
    }
}
