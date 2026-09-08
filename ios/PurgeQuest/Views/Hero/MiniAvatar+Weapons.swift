//
//  MiniAvatar+Weapons.swift
//  PurgeQuest
//
//  Weapons, shields, and the spare mace for the chunky hero figure. Every
//  item is drawn with the shared cel system so steel, gold, leather, and
//  wood read as one material family across the whole armory.
//

import SwiftUI

extension MiniAvatarView {

    // MARK: - Layers

    /// Spare mace in the off hand when the knight has no shield equipped.
    @ViewBuilder var maceLayer: some View {
        if isKnight && item(.shield) == nil {
            VStack(spacing: 1 * u) {
                ZStack {
                    ForEach(0..<6, id: \.self) { i in
                        cel(ConeShape(), steelDeep, lineWidth: 1.4, shift: 0.9)
                            .frame(width: 4 * u, height: 6 * u)
                            .offset(y: -7.5 * u)
                            .rotationEffect(.degrees(Double(i) * 60))
                    }
                    cel(Circle(), steel, lineWidth: 2.0, shift: 1.3)
                        .frame(width: 13 * u, height: 13 * u)
                }
                celFlat(Capsule(), .questAmber, lineWidth: 1.4)
                    .frame(width: 5.5 * u, height: 3 * u)
                celFlat(Capsule(), leatherDark, lineWidth: 1.6)
                    .frame(width: 4 * u, height: 13 * u)
                celFlat(Capsule(), .questAmber, lineWidth: 1.4)
                    .frame(width: 5.5 * u, height: 3 * u)
            }
            .rotationEffect(.degrees(-26))
            .offset(x: -25.5 * u, y: 15 * u)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    var weaponLayer: some View {
        weaponModel
            .rotationEffect(.degrees(2))
            .offset(x: 25.5 * u, y: 10.5 * u)
    }

    @ViewBuilder var weaponModel: some View {
        if let weapon = item(.weapon) {
            heldWeapon(id: weapon.id)
                .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
        } else if isKnight {
            simpleSword
        } else {
            simpleWand
        }
    }

    @ViewBuilder var shieldLayer: some View {
        if item(.shield)?.id == "shield.templar" {
            templarShield
                .rotationEffect(.degrees(-8))
                .offset(x: -27.5 * u, y: 12 * u)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        } else if item(.shield)?.id == "shield.crux" {
            cruxShield
                .rotationEffect(.degrees(-8))
                .offset(x: -27.5 * u, y: 12 * u)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    // MARK: - Default weapons

    /// Default knight blade: wide steel with a lit edge, dark fuller,
    /// chunky gold guard, wrapped grip, and a heavy pommel.
    var simpleSword: some View {
        VStack(spacing: 0) {
            ZStack {
                cel(BladeShape(), steel, lineWidth: 2.4, shift: 1.8)
                    .frame(width: 17 * u, height: 34 * u)
                Rectangle().fill(Color.white.opacity(0.65))
                    .frame(width: 2.4 * u, height: 21 * u)
                    .offset(x: -3.8 * u, y: -4 * u)
                Rectangle().fill(steelDeep.darker(0.25))
                    .frame(width: 2 * u, height: 19 * u)
                    .offset(x: 2.8 * u, y: -2.5 * u)
            }
            cel(Capsule(), .questAmber, lineWidth: 2.2, shift: 1.4)
                .frame(width: 26 * u, height: 7 * u)
            ZStack {
                celFlat(Capsule(), leatherDark, lineWidth: 1.8)
                    .frame(width: 7 * u, height: 11 * u)
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(leatherDark.lighter(0.28))
                        .frame(width: 7 * u, height: 1.4 * u)
                        .offset(y: (CGFloat(i) - 1) * 3.2 * u)
                }
            }
            cel(Circle(), .questAmber, lineWidth: 2.0, shift: 1.1)
                .frame(width: 9 * u, height: 9 * u)
        }
    }

    /// Default magician wand: turned wood, gold ferrule, jade orb.
    var simpleWand: some View {
        VStack(spacing: 1.5 * u) {
            cel(Circle(), .xpViolet, lineWidth: 2.0, shift: 1.2)
                .frame(width: 11 * u, height: 11 * u)
            celFlat(Capsule(), .questAmber, lineWidth: 1.4)
                .frame(width: 6 * u, height: 2.4 * u)
            celFlat(Capsule(), wood, lineWidth: 1.8)
                .frame(width: 5 * u, height: 30 * u)
        }
    }

    // MARK: - Held weapons

    @ViewBuilder func heldWeapon(id: String) -> some View {
        switch id {
        case "weapon.staff":
            // Archmage Staff: gold claws seating a jade orb over a wood haft.
            VStack(spacing: 1 * u) {
                ZStack {
                    ForEach([CGFloat(-1), CGFloat(0), CGFloat(1)], id: \.self) { x in
                        cel(ConeShape(), .questAmber, lineWidth: 1.4, shift: 0.9)
                            .frame(width: 4 * u, height: 7 * u)
                            .rotationEffect(.degrees(x * 38))
                            .offset(x: x * 5 * u, y: -5.5 * u)
                    }
                    cel(Circle(), .xpViolet, lineWidth: 2.2, shift: 1.5)
                        .frame(width: 14 * u, height: 14 * u)
                }
                celFlat(Capsule(), .questAmber, lineWidth: 1.4)
                    .frame(width: 7 * u, height: 3 * u)
                celFlat(Capsule(), wood, lineWidth: 1.8)
                    .frame(width: 5 * u, height: 34 * u)
            }
        case "weapon.gem":
            // Gem Hammer: steel head with gold gem inlays on a wood haft.
            VStack(spacing: 0) {
                cel(Rectangle(), steel, lineWidth: 2.4, shift: 1.6)
                    .frame(width: 24 * u, height: 13 * u)
                    .overlay(
                        HStack(spacing: 4 * u) {
                            celFlat(DiamondShape(), .questAmber, lineWidth: 1.2)
                                .frame(width: 4 * u, height: 4 * u)
                            celFlat(DiamondShape(), .questAmber, lineWidth: 1.2)
                                .frame(width: 4 * u, height: 4 * u)
                            celFlat(DiamondShape(), .questAmber, lineWidth: 1.2)
                                .frame(width: 4 * u, height: 4 * u)
                        }
                    )
                celFlat(Capsule(), leatherDark, lineWidth: 1.8)
                    .frame(width: 5.5 * u, height: 24 * u)
                celFlat(Capsule(), .questAmber, lineWidth: 1.4)
                    .frame(width: 6.5 * u, height: 3 * u)
            }
        case "weapon.reel":
            // Film Reel Blade: pale blade over a sprocketed reel guard.
            VStack(spacing: 1 * u) {
                cel(BladeShape(), steelLight, lineWidth: 2.2, shift: 1.6)
                    .frame(width: 12 * u, height: 24 * u)
                ZStack {
                    cel(Circle(), steelDeep, lineWidth: 2.2, shift: 1.4)
                        .frame(width: 17 * u, height: 17 * u)
                    ForEach(0..<6, id: \.self) { i in
                        Circle().fill(Color(white: 0.95))
                            .frame(width: 2 * u, height: 2 * u)
                            .offset(y: -6.4 * u)
                            .rotationEffect(.degrees(Double(i) * 60))
                    }
                    Circle().fill(Color.videoSapphire)
                        .frame(width: 5.5 * u, height: 5.5 * u)
                    Circle().stroke(outline, lineWidth: 1.2 * u)
                        .frame(width: 5.5 * u, height: 5.5 * u)
                }
                celFlat(Capsule(), leatherDark, lineWidth: 1.6)
                    .frame(width: 5 * u, height: 8 * u)
            }
        case "weapon.stormblade":
            // Storm Cleaver: broad steel with a bolt emblem.
            VStack(spacing: 0) {
                ZStack {
                    cel(BladeShape(), steelLight, lineWidth: 2.2, shift: 1.7)
                        .frame(width: 16 * u, height: 28 * u)
                    celFlat(ChevronShape(), .videoSapphire, lineWidth: 1.3)
                        .frame(width: 7 * u, height: 8 * u)
                        .rotationEffect(.degrees(180))
                        .offset(y: -6 * u)
                }
                cel(Rectangle(), steelDeep, lineWidth: 2.0, shift: 1.2)
                    .frame(width: 18 * u, height: 5 * u)
                celFlat(Capsule(), leatherDark, lineWidth: 1.8)
                    .frame(width: 6 * u, height: 9 * u)
                celFlat(Circle(), .videoSapphire, lineWidth: 1.6)
                    .frame(width: 6 * u, height: 6 * u)
            }
        case "weapon.chevron":
            // Oathbreaker Greatsword: long blade, chevron etching, big guard.
            VStack(spacing: 0) {
                ZStack {
                    cel(BladeShape(), steel, lineWidth: 2.4, shift: 1.7)
                        .frame(width: 15 * u, height: 34 * u)
                    celFlat(ChevronShape(), steelLight, lineWidth: 1.2)
                        .frame(width: 6 * u, height: 6 * u)
                        .offset(y: -8 * u)
                    celFlat(ChevronShape(), steelLight, lineWidth: 1.2)
                        .frame(width: 6 * u, height: 6 * u)
                }
                cel(Rectangle(), .questAmber, lineWidth: 2.0, shift: 1.2)
                    .frame(width: 22 * u, height: 5.5 * u)
                celFlat(Capsule(), leatherDark, lineWidth: 1.8)
                    .frame(width: 6.5 * u, height: 12 * u)
                cel(Circle(), .questAmber, lineWidth: 1.8, shift: 1.0)
                    .frame(width: 7.5 * u, height: 7.5 * u)
            }
        case "weapon.ruby":
            // Ruby Fang: crimson steel, gold guard, ruby pommel.
            VStack(spacing: 0) {
                cel(BladeShape(), .combatCrimson, lineWidth: 2.2, shift: 1.6)
                    .frame(width: 13 * u, height: 28 * u)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 1.2 * u, height: 18 * u)
                            .offset(x: -2.2 * u, y: -3 * u)
                    )
                cel(Rectangle(), .questAmber, lineWidth: 2.0, shift: 1.2)
                    .frame(width: 19 * u, height: 5.5 * u)
                celFlat(Capsule(), leatherDark, lineWidth: 1.8)
                    .frame(width: 6 * u, height: 8 * u)
                cel(DiamondShape(), .combatCrimson, lineWidth: 1.8, shift: 1.0)
                    .frame(width: 7 * u, height: 7 * u)
            }
        case "weapon.arcane":
            // Arcane Edge: jade longsword with gold fittings.
            VStack(spacing: 0) {
                ZStack {
                    cel(BladeShape(), .xpViolet, lineWidth: 2.2, shift: 1.6)
                        .frame(width: 14 * u, height: 32 * u)
                    Rectangle()
                        .fill(Color.white.opacity(0.40))
                        .frame(width: 1.2 * u, height: 20 * u)
                        .offset(x: -2.4 * u, y: -3 * u)
                }
                cel(Rectangle(), .questAmber, lineWidth: 2.0, shift: 1.2)
                    .frame(width: 20 * u, height: 5.5 * u)
                celFlat(Capsule(), leatherDark, lineWidth: 1.8)
                    .frame(width: 6 * u, height: 9 * u)
                cel(Circle(), .questAmber, lineWidth: 1.8, shift: 1.0)
                    .frame(width: 7 * u, height: 7 * u)
            }
        case "weapon.fireworkBlade":
            // Firework Blade: pale steel with bursting gem sparks.
            VStack(spacing: 0) {
                cel(BladeShape(), steelLight, lineWidth: 2.2, shift: 1.6)
                    .frame(width: 13 * u, height: 28 * u)
                    .overlay(
                        VStack(spacing: 5 * u) {
                            celFlat(DiamondShape(), .combatCrimson, lineWidth: 1.0)
                                .frame(width: 3 * u, height: 3 * u)
                            celFlat(DiamondShape(), .questAmber, lineWidth: 1.0)
                                .frame(width: 3.5 * u, height: 3.5 * u)
                            celFlat(DiamondShape(), .gemEmerald, lineWidth: 1.0)
                                .frame(width: 3 * u, height: 3 * u)
                        }
                        .offset(x: 1.5 * u, y: -4 * u)
                    )
                cel(Rectangle(), .combatCrimson, lineWidth: 2.0, shift: 1.2)
                    .frame(width: 19 * u, height: 5.5 * u)
                celFlat(Capsule(), leatherDark, lineWidth: 1.8)
                    .frame(width: 6 * u, height: 8 * u)
                cel(Circle(), .questAmber, lineWidth: 1.8, shift: 1.0)
                    .frame(width: 7 * u, height: 7 * u)
            }
        default:
            simpleSword
        }
    }

    // MARK: - Shields

    /// Azure Aegis: steel-blue field, gilded cross, heavy rivets.
    var cruxShield: some View {
        ZStack {
            cel(HeaterShieldShape(), Color(red: 0.30, green: 0.44, blue: 0.55), lineWidth: 2.6, shift: 1.8)
                .frame(width: 21 * u, height: 24 * u)
            HeaterShieldShape()
                .stroke(Color.questAmber, lineWidth: 1.8 * u)
                .frame(width: 17 * u, height: 20 * u)
            crossPlate(Color.questAmber, inner: Color.questAmber.lighter(0.35))
            rivets
        }
    }

    /// Templar Bulwark: pale field, scarlet cross, gold rivets.
    var templarShield: some View {
        ZStack {
            cel(HeaterShieldShape(), Color(red: 0.93, green: 0.91, blue: 0.86), lineWidth: 2.6, shift: 1.8)
                .frame(width: 21 * u, height: 24 * u)
            HeaterShieldShape()
                .stroke(Color.questAmber, lineWidth: 1.8 * u)
                .frame(width: 17 * u, height: 20 * u)
            crossPlate(.combatCrimson, inner: Color.combatCrimson.lighter(0.35))
            rivets
        }
    }

    var rivets: some View {
        ForEach(
            [CGPoint(x: -6.5, y: -6.5), CGPoint(x: 6.5, y: -6.5),
             CGPoint(x: -5.5, y: 4), CGPoint(x: 5.5, y: 4)],
            id: \.x
        ) { point in
            ZStack {
                Circle()
                    .fill(Color.questAmber.darker(0.35))
                    .frame(width: 3.2 * u, height: 3.2 * u)
                Circle()
                    .fill(Color.questAmber)
                    .frame(width: 2.2 * u, height: 2.2 * u)
                    .offset(x: -0.4 * u, y: -0.4 * u)
            }
            .offset(x: point.x * u, y: point.y * u)
        }
    }

    /// Embossed cross: upright and lateral bars with a lit inner plate.
    func crossPlate(_ color: Color, inner: Color?) -> some View {
        ZStack {
            celFlat(Capsule(), color, lineWidth: 1.4)
                .frame(width: 4.5 * u, height: 14 * u)
            celFlat(Capsule(), color, lineWidth: 1.4)
                .frame(width: 11 * u, height: 4.5 * u)
                .offset(y: -3 * u)
            if let inner {
                Capsule().fill(inner).frame(width: 1.6 * u, height: 11 * u)
                Capsule().fill(inner).frame(width: 8 * u, height: 1.6 * u)
                    .offset(y: -3 * u)
            }
        }
    }
}
