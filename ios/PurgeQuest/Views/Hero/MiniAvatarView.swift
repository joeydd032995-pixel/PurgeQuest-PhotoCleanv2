//
//  MiniAvatarView.swift
//  PurgeQuest
//
//  Chunky-cartoon renderer for the hero mini figure. Every part is built
//  silhouette-first through a shared cel system: a flat base tone, one
//  hard-edged light band toward the top-left key light, one hard-edged dark
//  band on the lower right, and a thick uniform outline. One light source
//  for the whole figure. Gear (skin, head, armor, weapon, shield, pet,
//  effect) recolors and re-equips the figure live. Heads are in
//  MiniAvatar+Heads.swift, weapons and shields in MiniAvatar+Weapons.swift,
//  pets and effects in MiniAvatar+Pets.swift, and silhouette paths in
//  MiniAvatarShapes.swift.
//

import SwiftUI

struct MiniAvatarView: View {
    let hero: Hero
    let equipped: [CosmeticItem]
    /// Size of the orb the figure is drawn for; the figure scales proportionally.
    var size: CGFloat = 210
    /// Set to false for static previews (armory tiles) that skip gear transitions.
    var isAnimated: Bool = true
    /// The hero's resolved identity (skin, face, hair, expression). A draft
    /// appearance can be passed for live editor previews; otherwise it decodes
    /// from the hero record once per view.
    let identity: HeroAppearance

    init(
        hero: Hero,
        equipped: [CosmeticItem],
        size: CGFloat = 210,
        isAnimated: Bool = true,
        appearance: HeroAppearance? = nil
    ) {
        self.hero = hero
        self.equipped = equipped
        self.size = size
        self.isAnimated = isAnimated
        self.identity = appearance ?? hero.appearance
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Base design unit so every dimension scales with the orb size.
    var u: CGFloat { size / 200 }

    var isKnight: Bool { hero.archetype == .knight }

    func item(_ type: CosmeticType) -> CosmeticItem? {
        equipped.first { $0.type == type }
    }

    // MARK: - Palette

    var outline: Color { Color(red: 0.045, green: 0.085, blue: 0.07) }
    var steelLight: Color { Color(red: 0.78, green: 0.85, blue: 0.82) }
    var steel: Color { Color(red: 0.60, green: 0.70, blue: 0.65) }
    var steelDeep: Color { Color(red: 0.40, green: 0.49, blue: 0.45) }
    var helmetDark: Color { Color(red: 0.24, green: 0.30, blue: 0.27) }
    var charcoal: Color { Color(red: 0.21, green: 0.26, blue: 0.23) }
    var leather: Color { Color(red: 0.52, green: 0.31, blue: 0.15) }
    var leatherDark: Color { Color(red: 0.34, green: 0.19, blue: 0.09) }
    var bootColor: Color { Color(red: 0.17, green: 0.23, blue: 0.20) }
    var mittColor: Color { Color(red: 0.33, green: 0.40, blue: 0.36) }
    var wood: Color { Color(red: 0.58, green: 0.40, blue: 0.22) }
    /// Skin tone driven by the hero's saved identity.
    var skinTone: Color { identity.skinTone.color }
    var skinShade: Color { skinTone.darker(0.16) }
    var hairColor: Color { identity.hairColor.color }
    var hatColor: Color { Color(red: 0.20, green: 0.42, blue: 0.38) }

    /// Tunic color driven by the equipped skin; falls back to the archetype standard.
    var tunicColor: Color {
        switch item(.skin)?.id {
        case "skin.iron": return steelDeep
        case "skin.embers": return Color(red: 0.74, green: 0.24, blue: 0.22)
        case "skin.archivist": return Color(red: 0.44, green: 0.33, blue: 0.20)
        case "skin.warden": return Color(red: 0.26, green: 0.33, blue: 0.29)
        case "skin.wraithcloak": return Color(red: 0.18, green: 0.21, blue: 0.20)
        case "skin.sandblade": return Color(red: 0.80, green: 0.68, blue: 0.45)
        default: return isKnight ? Color(red: 0.36, green: 0.41, blue: 0.38) : Color(red: 0.24, green: 0.47, blue: 0.44)
        }
    }

    /// Outfit cloth color with the saved armor dye blended in, so light and
    /// dark cel bands shift together and the tint reads as dyed fabric.
    var outfitColor: Color {
        guard identity.armorDye != .none else { return tunicColor }
        return tunicColor.blended(with: identity.armorDye.color, amount: 0.55)
    }

    var petColor: Color {
        switch item(.pet)?.id {
        case "pet.reel": return .videoSapphire
        case "pet.owl": return Color(red: 0.56, green: 0.41, blue: 0.24)
        case "pet.beachSpirit": return Color(red: 0.40, green: 0.68, blue: 0.76)
        default: return .gemEmerald
        }
    }

    var isRobed: Bool {
        item(.armor)?.id == "armor.arcanist" || item(.skin)?.id == "skin.archivist"
    }

    var isWraith: Bool { item(.skin)?.id == "skin.wraithcloak" }

    var skinId: String { item(.skin)?.id ?? "" }

    // MARK: - Cel system

    /// Chunky cel fill: flat base tone, a hard-edged light band toward the
    /// top-left key light, a hard-edged dark band on the lower right, and a
    /// thick uniform outline. Bands are clipped inside the silhouette so no
    /// fill ever bleeds past the outline, and band offsets and outline width
    /// keep a minimum absolute size so shading stays readable on small tiles.
    func cel<S: Shape>(
        _ shape: S,
        _ base: Color,
        lineWidth: CGFloat = 2.4,
        shift: CGFloat = 1.6,
        dark: Color? = nil,
        light: Color? = nil
    ) -> some View {
        let lightShift = max(shift * u, 1.0)
        let darkShiftX = max(shift * 1.9 * u, 1.7)
        let darkShiftY = max(shift * 2.3 * u, 2.1)
        return ZStack {
            shape.fill(light ?? base.lighter(0.30))
            shape.fill(base)
                .offset(x: lightShift, y: lightShift * 1.2)
            shape.fill(dark ?? base.darker(0.38))
                .offset(x: darkShiftX, y: darkShiftY)
        }
        .clipShape(shape)
        .overlay(shape.stroke(outline, lineWidth: max(lineWidth * u, 1.3)))
    }

    /// Two-tone flat fill for tiny details that cannot fit three bands.
    func celFlat<S: Shape>(_ shape: S, _ base: Color, lineWidth: CGFloat = 2.0) -> some View {
        shape
            .fill(base)
            .overlay(shape.stroke(outline, lineWidth: max(lineWidth * u, 1.1)))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            groundShadow
            HeroSpriteView(
                hero: hero,
                appearance: identity,
                equipped: equipped,
                size: 132 * u,
                isAnimated: isAnimated
            )
            .frame(width: 112 * u, height: 132 * u, alignment: .bottom)
        }
        .frame(width: 118 * u, height: 140 * u)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    var groundShadow: some View {
        ZStack {
            Ellipse().fill(Color.black.opacity(0.20))
                .frame(width: 62 * u, height: 13 * u)
            Ellipse().fill(Color.black.opacity(0.38))
                .frame(width: 44 * u, height: 8.5 * u)
        }
        .offset(y: 59 * u)
    }

    var figure: some View {
        ZStack {
            cloakBack
            legs
            torso
            leftArm
            maceLayer
            shieldLayer
            headGroup
            rightArm
            weaponLayer
            fxLayer
            petLayer
        }
        .frame(width: 112 * u, height: 140 * u)
        .animation(
            isAnimated && !reduceMotion
                ? .spring(response: 0.4, dampingFraction: 0.78)
                : nil,
            value: equipped.map(\.id)
        )
    }

    var accessibilitySummary: String {
        let worn = CosmeticType.allCases.compactMap { slot -> String? in
            item(slot)?.name
        }
        if worn.isEmpty { return "Hero figure, default gear" }
        return "Hero figure wearing \(worn.joined(separator: ", "))"
    }

    // MARK: - Legs

    var legs: some View {
        ZStack {
            leg(x: -7.5)
            leg(x: 7.5)
            if isKnight {
                // Gold knee guards seated on the greaves.
                ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                    cel(DiamondShape(), .questAmber, lineWidth: 1.8, shift: 1.0)
                        .frame(width: 5.5 * u, height: 6 * u)
                        .offset(x: side * 7.5 * u, y: 36 * u)
                }
            }
            boot(x: -8.5)
            boot(x: 8.5)
        }
    }

    func leg(x: CGFloat) -> some View {
        celFlat(Capsule(), charcoal, lineWidth: 1.8)
            .frame(width: 5.5 * u, height: 12 * u)
            .offset(x: x * u, y: 40 * u)
    }

    func boot(x: CGFloat) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 7 * u,
            bottomLeadingRadius: 2.5 * u,
            bottomTrailingRadius: 2.5 * u,
            topTrailingRadius: 7 * u,
            style: .continuous
        )
        return ZStack {
            cel(shape, bootColor, lineWidth: 2.2, shift: 1.3)
            if isKnight {
                // Gold strap ringing the boot's throat.
                celFlat(Capsule(), .questAmber, lineWidth: 1.2)
                    .frame(width: 12.5 * u, height: 2 * u)
                    .offset(y: -3.4 * u)
            }
            // Single hard light kiss on the toe.
            RoundedRectangle(cornerRadius: 1.1 * u, style: .continuous)
                .fill(Color.white.opacity(0.30))
                .frame(width: 4.5 * u, height: 2.2 * u)
                .offset(x: x < 0 ? -4 * u : 4 * u, y: -1.6 * u)
            // Sole line grounds the boot.
            Rectangle()
                .fill(outline.opacity(0.9))
                .frame(width: 14 * u, height: 1.3 * u)
                .offset(y: 3.9 * u)
        }
        .frame(width: 16 * u, height: 10.5 * u)
        .offset(x: x * u, y: 48 * u)
    }

    // MARK: - Torso

    var torso: some View {
        ZStack {
            if isRobed {
                // Full robe column covering the top of the legs.
                cel(TaperedShape(topWidth: 0.88, bottomWidth: 1.25), outfitColor, lineWidth: 2.4)
                    .frame(width: 36 * u, height: 40 * u)
                    .offset(y: 18 * u)
                // Center pleat.
                Rectangle()
                    .fill(outfitColor.darker(0.30))
                    .frame(width: 1.2 * u, height: 30 * u)
                    .offset(y: 21 * u)
            } else {
                cel(TaperedShape(topWidth: 0.82, bottomWidth: 1), outfitColor, lineWidth: 2.4)
                    .frame(width: 33 * u, height: 26 * u)
                    .offset(y: 12 * u)
            }
            armorLayer
            if isKnight && !isRobed {
                knightPlate
            }
            belt
            skinTrim
        }
    }

    /// Knight chest plate: pectoral seam and a gold boss.
    var knightPlate: some View {
        ZStack {
            cel(TaperedShape(topWidth: 0.86, bottomWidth: 1), steel, lineWidth: 2.2, shift: 1.4)
                .frame(width: 27 * u, height: 18 * u)
            Rectangle()
                .fill(outline.opacity(0.5))
                .frame(width: 1.1 * u, height: 12 * u)
                .offset(y: 0.5 * u)
            ZStack {
                Circle().fill(Color.questAmber.darker(0.30)).frame(width: 5 * u, height: 5 * u)
                Circle().fill(Color.questAmber).frame(width: 4 * u, height: 4 * u)
                    .offset(x: -0.5 * u, y: -0.6 * u)
                Circle().stroke(outline, lineWidth: 1.2 * u).frame(width: 5 * u, height: 5 * u)
            }
            .offset(y: 2.5 * u)
        }
        .offset(y: 13.5 * u)
    }

    var belt: some View {
        ZStack {
            celFlat(Capsule(), leatherDark, lineWidth: 1.6)
                .frame(width: isRobed ? 30 * u : 28 * u, height: 4.5 * u)
            celFlat(Capsule(), .questAmber, lineWidth: 1.6)
                .frame(width: 7.5 * u, height: 6 * u)
                .overlay(
                    Rectangle()
                        .fill(outline.opacity(0.8))
                        .frame(width: 1 * u, height: 3.4 * u)
                )
        }
        .offset(y: isRobed ? 8 * u : 20.5 * u)
    }

    /// One small accent per skin so each outfit reads at a glance.
    @ViewBuilder var skinTrim: some View {
        switch skinId {
        case "skin.embers":
            celFlat(ChevronShape(), .questAmber, lineWidth: 1.4)
                .frame(width: 11 * u, height: 5.5 * u)
                .offset(y: (isRobed ? 15 : 12) * u)
        case "skin.warden":
            celFlat(Capsule(), steel, lineWidth: 1.6)
                .frame(width: 26 * u, height: 3 * u)
                .offset(y: (isRobed ? 14 : 15) * u)
        case "skin.sandblade":
            celFlat(Capsule(), Color(red: 0.92, green: 0.84, blue: 0.62), lineWidth: 1.4)
                .frame(width: 24 * u, height: 2.4 * u)
                .offset(y: (isRobed ? 12 : 9.5) * u)
        default:
            EmptyView()
        }
    }

    // MARK: - Back layer

    @ViewBuilder var cloakBack: some View {
        if isWraith {
            cel(NotchShape(), tunicColor, lineWidth: 2.4, shift: 1.8)
                .frame(width: 46 * u, height: 52 * u)
                .offset(y: 16 * u)
        } else if isRobed {
            cel(TaperedShape(topWidth: 0.9, bottomWidth: 1.05), outfitColor.darker(0.14), lineWidth: 2.2, shift: 1.6)
                .frame(width: 40 * u, height: 42 * u)
                .offset(y: 16 * u)
        } else if isKnight {
            // Short half-cape behind the shoulders.
            cel(TaperedShape(topWidth: 0.95, bottomWidth: 1.1), outfitColor.darker(0.18), lineWidth: 2.2, shift: 1.5)
                .frame(width: 40 * u, height: 26 * u)
                .offset(y: 8 * u)
        }
    }

    // MARK: - Arms

    var leftArm: some View { arm(side: -1) }
    var rightArm: some View { arm(side: 1) }

    func arm(side: CGFloat) -> some View {
        ZStack {
            cel(
                Capsule(),
                isKnight && !isRobed ? steelDeep : outfitColor,
                lineWidth: 2.0,
                shift: 1.2
            )
            .frame(width: 7 * u, height: 15 * u)
            .rotationEffect(.degrees(side * 14))
            .offset(x: side * 17.5 * u, y: 10 * u)
            cel(Circle(), mittColor, lineWidth: 2.0, shift: 1.0)
                .frame(width: 9 * u, height: 8.5 * u)
                .offset(x: side * 21 * u, y: 18.5 * u)
        }
    }

    // MARK: - Armor

    @ViewBuilder var armorLayer: some View {
        switch item(.armor)?.id {
        case "armor.iron":
            pauldron(x: -17)
            pauldron(x: 17)
        case "armor.dragonhide":
            scalePlate(x: -17.5)
            scalePlate(x: 17.5)
        case "armor.arcanist":
            // Jade collar and cloth shoulder puffs over the robe.
            celFlat(Capsule(), .xpViolet, lineWidth: 1.8)
                .frame(width: 22 * u, height: 4.5 * u)
                .offset(y: -5 * u)
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                cel(Circle(), outfitColor.darker(0.10), lineWidth: 1.8, shift: 1.0)
                    .frame(width: 11 * u, height: 9.5 * u)
                    .offset(x: side * 17 * u, y: 1.5 * u)
            }
        default:
            EmptyView()
        }
    }

    /// Steel pauldron with a gold rim crescent.
    func pauldron(x: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.questAmber)
                .frame(width: 14 * u, height: 14 * u)
                .offset(y: -0.5 * u)
            cel(Circle(), steel, lineWidth: 2.2, shift: 1.4)
                .frame(width: 13 * u, height: 12 * u)
        }
        .offset(x: x * u, y: 1.5 * u)
    }

    /// Layered dragonhide scales on the shoulder.
    func scalePlate(x: CGFloat) -> some View {
        ZStack {
            cel(ScaleShape(), Color(red: 0.34, green: 0.43, blue: 0.32), lineWidth: 2.0, shift: 1.2)
                .frame(width: 15 * u, height: 11 * u)
            cel(ScaleShape(), Color(red: 0.45, green: 0.55, blue: 0.42), lineWidth: 1.4, shift: 0.9)
                .frame(width: 9 * u, height: 6.5 * u)
                .offset(x: -2.5 * u, y: -2 * u)
        }
        .offset(x: x * u, y: 2 * u)
    }
}
