//
//  CardFX.swift
//  PurgeQuest
//
//  The numbers behind the combat card's depth and commit feel (design:
//  docs/superpowers/specs/2026-11-27-combat-card-depth-design.md, sections 3 and 4). Views render what this
//  decides and decide nothing themselves. Foundation only, so the Linux harness checks it.
//

import Foundation

/// Whether decorative effects run. Reduce Motion or Low Power Mode turns every one of them into a still.
nonisolated enum FXGate: Equatable {
    case live
    case still

    init(reduceMotion: Bool, lowPowerMode: Bool) {
        self = (reduceMotion || lowPowerMode) ? .still : .live
    }

    var isStill: Bool { self == .still }
}

/// One torch for every lit surface on the card. It sits at the top, 15 degrees left of vertical, so light
/// travels down and slightly right and shadows fall the same way.
nonisolated enum LightSource {
    static let angleDegrees: Double = 15

    /// A unit vector in screen coordinates (y points down): the way the light travels.
    static var direction: (x: Double, y: Double) {
        let a = angleDegrees * .pi / 180
        return (sin(a), cos(a))
    }

    /// Where a shadow of this depth falls, in points.
    static func shadowOffset(depth: Double) -> (x: Double, y: Double) {
        let d = direction
        return (d.x * depth, d.y * depth)
    }

    /// Gradient end points, in the unit square, for a highlight that starts on the lit side. `shiftDegrees` swings
    /// the light, so a tilting card catches it differently.
    static func highlightPoints(shiftDegrees: Double = 0) -> (start: (x: Double, y: Double), end: (x: Double, y: Double)) {
        let a = (angleDegrees + shiftDegrees) * .pi / 180
        let sx = sin(a) / 2
        let sy = cos(a) / 2
        return ((0.5 - sx, 0.5 - sy), (0.5 + sx, 0.5 + sy))
    }
}

/// What a drag looks like: how far toward Delete or Keep, how the card tilts and lifts, whether the commit line has
/// been crossed. `dx` is negative toward Delete. The gesture's raw translation, not any number here, decides a commit.
nonisolated struct SwipeProgress: Equatable {
    enum Side: Equatable { case delete, keep }

    /// The commit line, in points. Matches `SwipeMediaCard.commitThreshold`.
    static let threshold: Double = 110
    /// Arms at the full threshold and lets go below 90%, so jitter at the line cannot repeat a haptic.
    static let armAt: Double = 1.0
    static let disarmBelow: Double = 0.9
    static let maxTiltY: Double = 10
    static let maxTiltX: Double = 8
    /// The drag distance at which the photo has fully lifted.
    static let liftDistance: Double = 60
    /// Past the line, the card is drawn this fraction of the excess toward the tear, up to the cap (points).
    static let pullFactor: Double = 0.25
    static let pullCap: Double = 24
    /// Degrees the light swings per degree of Y tilt: 20 at full tilt.
    static let highlightSwing: Double = 2

    let dx: Double
    let dy: Double
    let gate: FXGate
    /// The side the card is armed for, with hysteresis from `wasArmed`.
    let armed: Side?

    init(dx: Double, dy: Double, gate: FXGate, wasArmed: Side? = nil) {
        self.dx = dx
        self.dy = dy
        self.gate = gate
        let side: Side? = dx < 0 ? .delete : (dx > 0 ? .keep : nil)
        let ratio = abs(dx) / Self.threshold
        if let side, ratio >= Self.armAt {
            armed = side
        } else if let side, wasArmed == side, ratio >= Self.disarmBelow {
            armed = side
        } else {
            armed = nil
        }
    }

    var side: Side? { dx < 0 ? .delete : (dx > 0 ? .keep : nil) }

    /// -1 (full Delete) to +1 (full Keep).
    var signed: Double { min(1, max(-1, dx / Self.threshold)) }

    /// 0 to 1, how far toward whichever side.
    var strength: Double { abs(signed) }

    var tiltY: Double {
        gate.isStill ? 0 : min(1, max(-1, dx / (Self.threshold * 1.5))) * Self.maxTiltY
    }

    var tiltX: Double {
        gate.isStill ? 0 : -min(1, max(-1, dy / (Self.threshold * 2))) * Self.maxTiltX
    }

    /// 0 to 1. Not gated: it is the drag itself, so the sense of lift never goes away.
    var lift: Double { min(1, (dx * dx + dy * dy).squareRoot() / Self.liftDistance) }

    /// A cosmetic nudge toward the tear, in points (negative is left). Delete only; the barrier holds the card.
    var pull: Double {
        guard !gate.isStill, dx < -Self.threshold else { return 0 }
        return -min(Self.pullCap, Self.pullFactor * (-dx - Self.threshold))
    }

    /// Degrees the frame's lit edge swings with the tilt.
    var highlightShift: Double { tiltY * Self.highlightSwing }
}

/// The reach of the two drag overlays, as fractions of the card's width. The tear is a jagged crimson void from the
/// left edge, the barrier a brass ward along the right. Both are strongest at the edge and fade to nothing inward,
/// and neither can ever pass its limit.
nonisolated enum EdgeOverlay {
    static let tearMaxWidth: Double = 0.34
    static let barrierMaxWidth: Double = 0.24
    static let tearEdgeAlpha: Double = 0.55
    static let barrierEdgeAlpha: Double = 0.5
    /// How much of the full width an unarmed overlay reaches; arming opens it to the whole.
    static let unarmedShare: Double = 0.8

    static func tearWidth(strength: Double, armed: Bool) -> Double {
        tearMaxWidth * clamp(strength) * (armed ? 1 : unarmedShare)
    }

    static func barrierWidth(strength: Double, armed: Bool) -> Double {
        barrierMaxWidth * clamp(strength) * (armed ? 1 : unarmedShare)
    }

    static func tearAlpha(strength: Double) -> Double { tearEdgeAlpha * clamp(strength) }

    static func barrierAlpha(strength: Double) -> Double { barrierEdgeAlpha * clamp(strength) }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}

/// What the two screen-edge overlays are told while a card is dragged. The tear sits at the screen's left edge for a
/// Delete drag and the barrier at the right for a Keep drag, so they stay put while the card moves under them (drawn
/// on the card itself, they slid off the screen with it). Only the side being dragged is ever above zero.
nonisolated struct EdgeSignal: Equatable {
    var tearStrength: Double
    var tearArmed: Bool
    var barrierStrength: Double
    var barrierArmed: Bool

    init(tearStrength: Double, tearArmed: Bool, barrierStrength: Double, barrierArmed: Bool) {
        self.tearStrength = tearStrength
        self.tearArmed = tearArmed
        self.barrierStrength = barrierStrength
        self.barrierArmed = barrierArmed
    }

    init(progress: SwipeProgress) {
        let strength: Double = progress.strength
        tearStrength = progress.side == .delete ? strength : 0
        barrierStrength = progress.side == .keep ? strength : 0
        tearArmed = progress.armed == .delete
        barrierArmed = progress.armed == .keep
    }

    /// Nothing dragged: both overlays are gone.
    static let rest = EdgeSignal(tearStrength: 0, tearArmed: false, barrierStrength: 0, barrierArmed: false)
}
