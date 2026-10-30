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
//  hand never lets go. Mirrors tools/modular_assets/held_gear.py.
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

    static func offset(hold: [Double], grip: [Double], pivotPx: [Double], scale: Double) -> (x: Double, y: Double)? {
        guard hold.count == 2, grip.count == 2, pivotPx.count == 2,
              scale.isFinite, scale > 0 else { return nil }
        return (hold[0] - scale * (grip[0] - pivotPx[0]), hold[1] - scale * (grip[1] - pivotPx[1]))
    }

    static func isSupported(_ item: HeldGearEntry, pack: String) -> Bool {
        item.supportedPacks.contains(pack)
    }

    /// Placement of a catalog item on a pack, or nil when the pair is unsupported or malformed.
    static func placement(item: HeldGearEntry, anchors: PackAnchors, pack: String, titan: Bool) -> HeldGearPlacement? {
        guard isSupported(item, pack: pack) else { return nil }
        let isWeapon = item.slot == "mainHand"
        let scale = item.scale * ((titan && isWeapon) ? titanScale : 1)
        let hold = isWeapon ? anchors.weaponHold : anchors.shieldHold
        let pivot = isWeapon ? anchors.weaponPivotPx : anchors.shieldPivotPx
        guard let off = offset(hold: hold, grip: item.gripPx, pivotPx: pivot, scale: scale) else { return nil }
        return HeldGearPlacement(scale: scale, offsetX: off.x, offsetY: off.y, rotationDegrees: item.rotationDegrees)
    }

    /// The pack's own baked weapon scaled about its grip (Titan with nothing equipped): grip == hold + pivot.
    static func bakedWeaponPlacement(anchors: PackAnchors, titan: Bool) -> HeldGearPlacement {
        let scale = titan ? titanScale : 1
        let hold = anchors.weaponHold
        guard hold.count == 2 else { return HeldGearPlacement(scale: scale, offsetX: 0, offsetY: 0, rotationDegrees: 0) }
        return HeldGearPlacement(scale: scale, offsetX: hold[0] * (1 - scale), offsetY: hold[1] * (1 - scale), rotationDegrees: 0)
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
