//
//  HeldGearFit.swift
//  PurgeQuest
//
//  Pure math for held gear. Every weapon/shield image is drawn with its
//  top-left at the SCML anchor pivot. An item declares its grip (image px);
//  each art pack declares the hold point where its own baked weapon sits.
//  For any scale s the local offset that keeps the grip on the hold is
//
//      offset(s) = hold - s * (grip - pivotPx)
//
//  so scaling (Titan Blade, s = 2) grows the item about the grip and the
//  hand never lets go. Turning the item about the anchor pivot by an angle
//  moves the grip, so the grip starts where the hold would be after turning
//  the other way, and the turn carries it back onto the hold: the item
//  pivots about its grip. Mirrors tools/modular_assets/held_gear.py.
//

import Foundation

nonisolated struct HeldGearPlacement: Equatable, Sendable {
    let scale: Double
    /// Offset in the anchor's local (image-axis, y-down) frame, in SCML units.
    let offsetX: Double
    let offsetY: Double
    let rotationDegrees: Double
}

nonisolated enum HeldGearFit {
    /// The Titan Blade upgrade doubles the held weapon. The store copy promises 2x; the sprite
    /// renderer previously applied 1.4x. This is the single source of truth.
    static let titanScale: Double = 2

    /// A blade, staff or hammer is never left pointing flat out from the hero's side. The art packs draw the hand at hip
    /// height and hold the sword sideways through most of the attack, so a weapon left the way the art draws it sticks
    /// straight out from the pelvis, which reads as something it is not. Whenever the weapon points between `carryFloor` and
    /// the item's carry angle (degrees counter-clockwise from the way it points in the art: 0 is straight out sideways, 90
    /// is straight up) it is turned about its grip up to the carry angle: up and away from the body, clear of the head.
    /// A weapon already raised (the wind-up of the swing) or pointing back is left alone. Mirrors held_gear.CARRY_ANGLE and
    /// held_gear.CARRY_FLOOR.
    static let carryAngle: Double = 45
    static let carryFloor: Double = -45

    /// Folds an angle in degrees into (-180, 180]. SCML bone angles accumulate down the chain and are not normalized.
    static func normalized(degrees: Double) -> Double {
        var a = degrees.truncatingRemainder(dividingBy: 360)
        if a > 180 { a -= 360 } else if a <= -180 { a += 360 }
        return a
    }

    /// Degrees to turn a weapon whose blade points along `bladeAngle` so it is carried at `carryAngle`: the whole way up to
    /// it when the blade points between `carryFloor` and `carryAngle`, otherwise not at all (also when there is no carry
    /// angle, as for a bow or a shield). Mirrors held_gear.carry_turn.
    static func carryTurn(bladeAngle: Double, carryAngle: Double?) -> Double {
        guard let carryAngle, bladeAngle.isFinite, carryAngle.isFinite else { return 0 }
        let a = normalized(degrees: bladeAngle)
        return (a >= carryFloor && a < carryAngle) ? carryAngle - a : 0
    }

    /// Offset that keeps the grip on the hold. `rotationDegrees` is how far the item is turned (counter-clockwise, like SCML
    /// angles) about the anchor pivot on top of the anchor's own angle.
    static func offset(hold: [Double], grip: [Double], pivotPx: [Double], scale: Double,
                       rotationDegrees: Double = 0) -> (x: Double, y: Double)? {
        guard hold.count == 2, grip.count == 2, pivotPx.count == 2,
              scale.isFinite, scale > 0, rotationDegrees.isFinite else { return nil }
        let r = rotationDegrees * .pi / 180
        let holdX = hold[0] * cos(r) - hold[1] * sin(r)
        let holdY = hold[0] * sin(r) + hold[1] * cos(r)
        return (holdX - scale * (grip[0] - pivotPx[0]), holdY - scale * (grip[1] - pivotPx[1]))
    }

    static func isSupported(_ item: HeldGearEntry, pack: String) -> Bool {
        item.supportedPacks.contains(pack)
    }

    /// Placement of a catalog item on a pack, or nil when the pair is unsupported or malformed. `anchorAngle` is the
    /// direction the frame's weapon anchor points (SCML degrees); with it, an item that has a carry angle is turned about
    /// its grip whenever it would point flat (see `carryAngle`). Without it the item keeps the pack's own angle.
    static func placement(item: HeldGearEntry, anchors: PackAnchors, pack: String, titan: Bool,
                          anchorAngle: Double? = nil) -> HeldGearPlacement? {
        guard isSupported(item, pack: pack) else { return nil }
        let isWeapon = item.slot == "mainHand"
        let scale = item.scale * ((titan && isWeapon) ? titanScale : 1)
        let hold = isWeapon ? anchors.weaponHold : anchors.shieldHold
        let pivot = isWeapon ? anchors.weaponPivotPx : anchors.shieldPivotPx
        let turn = (isWeapon && anchorAngle != nil)
            ? carryTurn(bladeAngle: (anchorAngle ?? 0) + item.rotationDegrees, carryAngle: item.carryAngle) : 0
        let rotation = item.rotationDegrees + turn
        guard let off = offset(hold: hold, grip: item.gripPx, pivotPx: pivot, scale: scale, rotationDegrees: rotation) else { return nil }
        return HeldGearPlacement(scale: scale, offsetX: off.x, offsetY: off.y, rotationDegrees: rotation)
    }

    /// The pack's own baked weapon scaled about its grip (Titan with nothing equipped): grip == hold + pivot. With an
    /// `anchorAngle` it is also turned about its grip like any other blade, except a bow, which is upright already.
    static func bakedWeaponPlacement(anchors: PackAnchors, titan: Bool, anchorAngle: Double? = nil) -> HeldGearPlacement {
        let scale = titan ? titanScale : 1
        let hold = anchors.weaponHold
        guard hold.count == 2 else { return HeldGearPlacement(scale: scale, offsetX: 0, offsetY: 0, rotationDegrees: 0) }
        var turn = 0.0
        if anchors.weaponAnchor != "bow", let anchorAngle {
            turn = carryTurn(bladeAngle: anchorAngle, carryAngle: Self.carryAngle)
        }
        guard turn != 0 else {
            return HeldGearPlacement(scale: scale, offsetX: hold[0] * (1 - scale), offsetY: hold[1] * (1 - scale), rotationDegrees: 0)
        }
        // The baked grip is the hold (plus the pivot), so the grip's local position before the turn is the hold turned back.
        let r = turn * .pi / 180
        return HeldGearPlacement(scale: scale,
                                 offsetX: hold[0] * cos(r) - hold[1] * sin(r) - scale * hold[0],
                                 offsetY: hold[0] * sin(r) + hold[1] * cos(r) - scale * hold[1],
                                 rotationDegrees: turn)
    }
}

/// How a (possibly enlarged) frame canvas sits around the pack's base canvas. The sprite view keeps the
/// character the same size and lets a Titan blade overflow, instead of shrinking the hero to fit it.
nonisolated struct SpriteCanvasLayout: Equatable, Sendable {
    let left: Double
    let top: Double
    let right: Double
    let bottom: Double

    static let zero = SpriteCanvasLayout(left: 0, top: 0, right: 0, bottom: 0)

    /// Origins are world-space (y-up) lower-left corners; sizes in canvas units.
    static func around(baseOrigin: (x: Double, y: Double), baseSize: (w: Double, h: Double),
                       frameOrigin: (x: Double, y: Double), frameSize: (w: Double, h: Double)) -> SpriteCanvasLayout {
        SpriteCanvasLayout(
            left: max(0, baseOrigin.x - frameOrigin.x),
            top: max(0, (frameOrigin.y + frameSize.h) - (baseOrigin.y + baseSize.h)),
            right: max(0, (frameOrigin.x + frameSize.w) - (baseOrigin.x + baseSize.w)),
            bottom: max(0, baseOrigin.y - frameOrigin.y)
        )
    }

    /// Points per canvas unit so the *base* canvas fills `height`.
    static func pointsPerUnit(height: Double, baseHeight: Double) -> Double {
        baseHeight > 0 ? height / baseHeight : 1
    }
}
