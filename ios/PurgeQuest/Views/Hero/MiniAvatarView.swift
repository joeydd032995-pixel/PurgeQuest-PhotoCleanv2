//
//  MiniAvatarView.swift
//  PurgeQuest
//

import SwiftUI

/// The hero mini-figure, drawn 1:1 to the tiny-sprite reference standard:
/// an oversized wraparound helmet (~55% of the figure) with a heart-notched
/// face window, solid black oval eyes with a glint, an orange fin crest for
/// the Knight, a tiny torso with belt + gold buckle, stubby boots, and a
/// wide-bladed sword held tip-up. Gear (armor, head, weapon, skin, pet)
/// changes the figure live.
struct MiniAvatarView: View {
    let hero: Hero
    let equipped: [CosmeticItem]
    /// Size of the orb the figure is drawn for; the figure scales proportionally.
    var size: CGFloat = 210

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBobbing = false

    /// Base design unit so every dimension scales with the orb size.
    private var u: CGFloat { size / 200 }

    private var isKnight: Bool { hero.archetype == .knight }

    private func item(_ type: CosmeticType) -> CosmeticItem? {
        equipped.first { $0.type == type }
    }

    // MARK: - Palette

    private var accent: Color { isKnight ? .questAmber : .xpViolet }
    private var skinTone: Color { Color(red: 0.96, green: 0.80, blue: 0.60) }
    private var steel: Color { Color(red: 0.74, green: 0.77, blue: 0.82) }
    private var steelDeep: Color { Color(red: 0.46, green: 0.49, blue: 0.56) }
    private var helmetDark: Color { Color(red: 0.28, green: 0.28, blue: 0.33) }
    private var charcoal: Color { Color(red: 0.22, green: 0.20, blue: 0.26) }
    private var leather: Color { Color(red: 0.45, green: 0.29, blue: 0.17) }
    private var bootColor: Color { Color(red: 0.15, green: 0.13, blue: 0.17) }
    private var wood: Color { Color(red: 0.55, green: 0.38, blue: 0.22) }
    private var outline: Color { Color(red: 0.09, green: 0.07, blue: 0.11) }

    /// Tunic color driven by the equipped skin; falls back to the archetype standard.
    private var tunicColor: Color {
        switch item(.skin)?.id {
        case "skin.iron": return steelDeep
        case "skin.embers": return Color(red: 0.72, green: 0.20, blue: 0.22)
        case "skin.archivist": return Color(red: 0.40, green: 0.31, blue: 0.22)
        case "skin.warden": return Color(red: 0.26, green: 0.28, blue: 0.36)
        default: return isKnight ? Color(red: 0.33, green: 0.33, blue: 0.39) : Color(red: 0.42, green: 0.28, blue: 0.68)
        }
    }

    private var petColor: Color {
        switch item(.pet)?.id {
        case "pet.reel": return .videoSapphire
        case "pet.owl": return Color(red: 0.62, green: 0.46, blue: 0.28)
        default: return .gemEmerald
        }
    }

    /// Draws a shape with a flat fill and the thick dark outline of the sprite standard.
    private func outlined<S: Shape>(_ shape: S, _ fill: Color, lineWidth: CGFloat = 2.4) -> some View {
        shape
            .fill(fill)
            .overlay(shape.stroke(outline, lineWidth: lineWidth * u))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.4))
                .frame(width: 52 * u, height: 10 * u)
                .blur(radius: 3 * u)
                .offset(y: 56 * u)

            figure
                .offset(y: isBobbing ? -2.5 * u : 0)
        }
        .frame(width: 118 * u, height: 140 * u)
        .onAppear { startBobbing() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let worn = CosmeticType.allCases.compactMap { slot -> String? in
            item(slot)?.name
        }
        if worn.isEmpty { return "Hero figure, default gear" }
        return "Hero figure wearing \(worn.joined(separator: ", "))"
    }

    private func startBobbing() {
        guard !reduceMotion, !isBobbing else { return }
        withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
            isBobbing = true
        }
    }

    // MARK: - Figure

    private var figure: some View {
        ZStack {
            robeBack
            legs
            torso
            leftArm
            shield
            headGroup
            rightArm
            weaponLayer
            petLayer
        }
        .frame(width: 112 * u, height: 140 * u)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: equipped.map(\.id))
    }

    // MARK: Legs & boots

    private var legs: some View {
        ZStack {
            leg(x: -7)
            leg(x: 7)
            boot(x: -8)
            boot(x: 8)
        }
    }

    private func leg(x: CGFloat) -> some View {
        outlined(Capsule(), charcoal, lineWidth: 2.2)
            .frame(width: 8 * u, height: 14 * u)
            .offset(x: x * u, y: 36 * u)
    }

    private func boot(x: CGFloat) -> some View {
        outlined(
            RoundedRectangle(cornerRadius: 4 * u, style: .continuous),
            bootColor,
            lineWidth: 2.2
        )
        .frame(width: 15 * u, height: 9 * u)
        .offset(x: x * u, y: 45 * u)
    }

    // MARK: Torso & armor

    private var torso: some View {
        ZStack {
            outlined(
                RoundedRectangle(cornerRadius: 8 * u, style: .continuous),
                tunicColor,
                lineWidth: 2.6
            )
            .frame(width: 27 * u, height: 23 * u)

            armorLayer
            belt
        }
        .offset(y: 21 * u)
    }

    @ViewBuilder private var armorLayer: some View {
        switch item(.armor)?.id {
        case "armor.iron":
            pauldron(x: -16)
            pauldron(x: 16)
            outlined(RoundedRectangle(cornerRadius: 5 * u, style: .continuous), steel, lineWidth: 2.2)
                .frame(width: 22 * u, height: 14 * u)
                .offset(y: -2 * u)
            Rectangle()
                .fill(.questAmber)
                .frame(width: 22 * u, height: 3 * u)
                .offset(y: -5 * u)
        case "armor.dragonhide":
            pauldron(x: -16)
            pauldron(x: 16)
            outlined(RoundedRectangle(cornerRadius: 5 * u, style: .continuous), .gemEmeraldDeep, lineWidth: 2.2)
                .frame(width: 22 * u, height: 14 * u)
                .offset(y: -2 * u)
            ZStack {
                scaleDot(x: -6, y: -4)
                scaleDot(x: 0, y: -4)
                scaleDot(x: 6, y: -4)
                scaleDot(x: -3, y: 1)
                scaleDot(x: 3, y: 1)
            }
            .offset(y: -2 * u)
        case "armor.arcanist":
            outlined(RoundedRectangle(cornerRadius: 4 * u, style: .continuous), Color(red: 0.46, green: 0.30, blue: 0.76), lineWidth: 2.2)
                .frame(width: 23 * u, height: 7 * u)
                .offset(y: -6 * u)
            Circle()
                .fill(.questAmber)
                .frame(width: 5 * u, height: 5 * u)
                .overlay(Circle().stroke(outline, lineWidth: 1.4 * u))
                .offset(y: 2 * u)
        default:
            EmptyView()
        }
    }

    private func pauldron(x: CGFloat) -> some View {
        Circle()
            .fill(item(.armor)?.id == "armor.dragonhide" ? Color.gemEmerald : steel)
            .overlay(Circle().stroke(outline, lineWidth: 2 * u))
            .frame(width: 11 * u, height: 11 * u)
            .offset(x: x * u, y: -7 * u)
    }

    private func scaleDot(x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(.gemEmerald)
            .frame(width: 3 * u, height: 3 * u)
            .offset(x: x * u, y: y * u)
    }

    private var belt: some View {
        ZStack {
            Rectangle()
                .fill(leather)
                .frame(width: 27 * u, height: 5.5 * u)
                .offset(y: 7.5 * u)
            Circle()
                .fill(.questAmber)
                .frame(width: 6 * u, height: 6 * u)
                .overlay(Circle().stroke(outline, lineWidth: 1.5 * u))
                .offset(y: 7.5 * u)
        }
    }

    // MARK: Robe (behind body)

    @ViewBuilder private var robeBack: some View {
        if item(.armor)?.id == "armor.arcanist" || item(.skin)?.id == "skin.archivist" {
            TaperedShape(topWidth: 0.55, bottomWidth: 1)
                .fill(
                    item(.armor)?.id == "armor.arcanist"
                        ? Color(red: 0.46, green: 0.30, blue: 0.76)
                        : Color(red: 0.33, green: 0.25, blue: 0.17)
                )
                .overlay(TaperedShape(topWidth: 0.55, bottomWidth: 1).stroke(outline, lineWidth: 2.4 * u))
                .frame(width: 44 * u, height: 38 * u)
                .offset(y: 22 * u)
        }
    }

    // MARK: Arms with fist mitts

    private var leftArm: some View {
        ZStack {
            outlined(Capsule(), tunicColor, lineWidth: 2.2)
                .frame(width: 7 * u, height: 15 * u)
                .rotationEffect(.degrees(20))
            fist
        }
        .offset(x: -18 * u, y: 12 * u)
    }

    private var rightArm: some View {
        ZStack {
            outlined(Capsule(), tunicColor, lineWidth: 2.2)
                .frame(width: 7 * u, height: 15 * u)
                .rotationEffect(.degrees(-38))
            fist
        }
        .offset(x: 20 * u, y: 8 * u)
    }

    private var fist: some View {
        Circle()
            .fill(skinTone)
            .overlay(Circle().stroke(outline, lineWidth: 2 * u))
            .frame(width: 8 * u, height: 8 * u)
            .offset(y: 8 * u)
    }

    // MARK: Shield (Knight signature)

    @ViewBuilder private var shield: some View {
        if isKnight {
            ZStack {
                RoundedRectangle(cornerRadius: 5 * u, style: .continuous)
                    .fill(charcoal)
                Rectangle()
                    .fill(Color.combatCrimson)
                    .frame(width: 4 * u, height: 13 * u)
                Rectangle()
                    .fill(Color.combatCrimson)
                    .frame(width: 9 * u, height: 4 * u)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5 * u, style: .continuous)
                    .stroke(outline, lineWidth: 2.4 * u)
            )
            .frame(width: 18 * u, height: 21 * u)
            .offset(x: -26 * u, y: 14 * u)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    // MARK: Head — oversized wraparound helmet standard

    private var headGroup: some View {
        ZStack {
            headModel
        }
        .offset(y: -24 * u)
    }

    @ViewBuilder private var headModel: some View {
        switch item(.head)?.id {
        case "head.iron":
            knightHelmet(dome: steel, fin: false, plume: false, band: true)
        case "head.dragoncrest":
            knightHelmet(dome: .questAmber, fin: true, plume: true, band: false)
        case "head.starhat":
            starWizardHead
        case "head.hood":
            hoodedHead
        default:
            if isKnight {
                knightHelmet(dome: helmetDark, fin: true, plume: false, band: false)
            } else {
                wizardHead
            }
        }
    }

    /// Solid black oval eyes with a white glint, per the sprite standard.
    private var eyes: some View {
        ZStack {
            eye(x: -9)
            eye(x: 9)
        }
    }

    private func eye(x: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(outline)
                .frame(width: 8 * u, height: 11 * u)
            Circle()
                .fill(Color.white)
                .frame(width: 2.6 * u, height: 2.6 * u)
                .offset(x: 1.6 * u, y: -3 * u)
        }
        .offset(x: x * u)
    }

    /// Heart-notched face window set into the lower center of the helmet.
    private func faceWindow(domeColor: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10 * u, style: .continuous)
                .fill(skinTone)
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * u, style: .continuous)
                        .stroke(outline, lineWidth: 2.4 * u)
                )
                .frame(width: 40 * u, height: 31 * u)
                .offset(y: 9 * u)

            Image(systemName: "arrowtriangle.down.fill")
                .resizable()
                .foregroundStyle(domeColor)
                .frame(width: 13 * u, height: 8 * u)
                .offset(y: -1.5 * u)

            eyes.offset(y: 8 * u)
        }
    }

    /// Knight helmet: big dome, heart face window, optional fin crest, plume, rivet band.
    private func knightHelmet(dome: Color, fin: Bool, plume: Bool, band: Bool) -> some View {
        ZStack {
            if fin {
                FinShape()
                    .fill(.questAmber)
                    .overlay(FinShape().stroke(outline, lineWidth: 2.2 * u))
                    .frame(width: 24 * u, height: 15 * u)
                    .offset(x: 1 * u, y: -33 * u)
                Rectangle()
                    .fill(Color.questAmberDeep)
                    .frame(width: 3 * u, height: 9 * u)
                    .rotationEffect(.degrees(10))
                    .offset(x: 3 * u, y: -30 * u)
            }
            if plume {
                PlumeShape()
                    .fill(Color.combatCrimson)
                    .overlay(PlumeShape().stroke(outline, lineWidth: 2.2 * u))
                    .frame(width: 23 * u, height: 16 * u)
                    .rotationEffect(.degrees(-10))
                    .offset(x: 7 * u, y: -31 * u)
            }

            Circle()
                .fill(dome)
                .overlay(Circle().stroke(outline, lineWidth: 2.8 * u))
                .frame(width: 64 * u, height: 64 * u)

            if band {
                RoundedRectangle(cornerRadius: 4.5 * u, style: .continuous)
                    .fill(steel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4.5 * u, style: .continuous)
                            .stroke(outline, lineWidth: 2 * u)
                    )
                    .frame(width: 46 * u, height: 9 * u)
                    .offset(y: -14 * u)
                bandRivet(x: -15)
                bandRivet(x: 0)
                bandRivet(x: 15)
            }

            helmetShine
            faceWindow(domeColor: dome)
        }
    }

    private func bandRivet(x: CGFloat) -> some View {
        Circle()
            .fill(steelDeep)
            .frame(width: 2.8 * u, height: 2.8 * u)
            .offset(x: x * u, y: -14 * u)
    }

    private var helmetShine: some View {
        Ellipse()
            .fill(Color.white.opacity(0.22))
            .frame(width: 10 * u, height: 6 * u)
            .rotationEffect(.degrees(-32))
            .offset(x: -18 * u, y: -20 * u)
    }

    /// Magician head: open face, black oval eyes, bushy white mustache + beard, pointed hat.
    private var wizardHead: some View {
        ZStack {
            wizardHat

            Circle()
                .fill(skinTone)
                .overlay(Circle().stroke(outline, lineWidth: 2.6 * u))
                .frame(width: 48 * u, height: 48 * u)
                .offset(y: 4 * u)

            eyes.offset(y: 2 * u)

            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 12 * u, height: 5 * u)
                .rotationEffect(.degrees(14))
                .offset(x: -6 * u, y: 11 * u)
            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 12 * u, height: 5 * u)
                .rotationEffect(.degrees(-14))
                .offset(x: 6 * u, y: 11 * u)

            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(outline, lineWidth: 2.2 * u))
                .frame(width: 27 * u, height: 20 * u)
                .offset(y: 20 * u)
        }
    }

    /// Starry variant of the wizard hat for the "starhat" cosmetic.
    private var starWizardHead: some View {
        ZStack {
            wizardHead
            Image(systemName: "sparkle")
                .font(.system(size: 9 * u, weight: .bold))
                .foregroundStyle(.questAmber)
                .offset(x: 8 * u, y: -30 * u)
        }
    }

    /// Pointed wizard hat with bent tip, brim and amber band.
    private var wizardHat: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.46, green: 0.30, blue: 0.76))
                .frame(width: 9 * u, height: 9 * u)
                .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                .offset(x: -5 * u, y: -42 * u)

            ConeShape()
                .fill(Color(red: 0.52, green: 0.34, blue: 0.82))
                .overlay(ConeShape().stroke(outline, lineWidth: 2.4 * u))
                .frame(width: 54 * u, height: 36 * u)
                .offset(y: -24 * u)

            Ellipse()
                .fill(Color(red: 0.46, green: 0.30, blue: 0.76))
                .overlay(Ellipse().stroke(outline, lineWidth: 2.4 * u))
                .frame(width: 60 * u, height: 13 * u)
                .offset(y: -8 * u)

            Rectangle()
                .fill(.questAmber)
                .frame(width: 24 * u, height: 5 * u)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.4 * u))
                .offset(y: -14 * u)
        }
    }

    /// Dark hood wrapping the head with a shadowed face.
    private var hoodedHead: some View {
        ZStack {
            Circle()
                .fill(charcoal)
                .overlay(Circle().stroke(outline, lineWidth: 2.8 * u))
                .frame(width: 60 * u, height: 60 * u)

            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .foregroundStyle(charcoal)
                .frame(width: 14 * u, height: 15 * u)
                .offset(y: -32 * u)

            Circle()
                .fill(skinTone.mix(with: .black, by: 0.18))
                .frame(width: 34 * u, height: 34 * u)
                .offset(y: 9 * u)

            eyes.offset(y: 8 * u)
        }
    }

    // MARK: Weapon

    @ViewBuilder private var weaponLayer: some View {
        ZStack {
            weaponModel
        }
        .offset(x: 31 * u, y: -6 * u)
    }

    /// Default weapon: the Knight's wide-bladed sword, held tip-up like the sprites.
    @ViewBuilder private var weaponModel: some View {
        if let weapon = item(.weapon) {
            heldWeapon(id: weapon.id)
                .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
        } else if isKnight {
            simpleSword
        } else {
            simpleWand
        }
    }

    private var simpleSword: some View {
        VStack(spacing: 0) {
            ZStack {
                BladeShape()
                    .fill(steel)
                    .overlay(BladeShape().stroke(outline, lineWidth: 2.2 * u))
                    .frame(width: 11 * u, height: 26 * u)
                Rectangle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 2.4 * u, height: 16 * u)
                    .offset(x: -2 * u, y: 2 * u)
            }
            Rectangle()
                .fill(.questAmber)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.8 * u))
                .frame(width: 17 * u, height: 5 * u)
            Rectangle()
                .fill(leather)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.8 * u))
                .frame(width: 5.5 * u, height: 9 * u)
            Circle()
                .fill(.questAmber)
                .overlay(Circle().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 6 * u, height: 6 * u)
        }
    }

    private var simpleWand: some View {
        VStack(spacing: 2 * u) {
            Circle()
                .fill(.xpViolet)
                .overlay(Circle().stroke(outline, lineWidth: 1.8 * u))
                .frame(width: 9 * u, height: 9 * u)
                .shadow(color: .xpViolet.opacity(0.8), radius: 3.5 * u)
            Capsule()
                .fill(wood)
                .overlay(Capsule().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 4 * u, height: 32 * u)
        }
    }

    @ViewBuilder private func heldWeapon(id: String) -> some View {
        switch id {
        case "weapon.staff":
            VStack(spacing: 2 * u) {
                Circle()
                    .fill(.xpViolet)
                    .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                    .frame(width: 13 * u, height: 13 * u)
                    .shadow(color: .xpViolet.opacity(0.8), radius: 4 * u)
                Capsule()
                    .fill(wood)
                    .overlay(Capsule().stroke(outline, lineWidth: 1.8 * u))
                    .frame(width: 4.5 * u, height: 44 * u)
            }
        case "weapon.gem":
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3 * u, style: .continuous)
                    .fill(.questAmber)
                    .overlay(RoundedRectangle(cornerRadius: 3 * u, style: .continuous).stroke(outline, lineWidth: 2.2 * u))
                    .frame(width: 19 * u, height: 11 * u)
                Capsule()
                    .fill(wood)
                    .overlay(Capsule().stroke(outline, lineWidth: 1.8 * u))
                    .frame(width: 4.5 * u, height: 34 * u)
            }
        case "weapon.reel":
            VStack(spacing: 0) {
                Circle()
                    .fill(.videoSapphire)
                    .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                    .frame(width: 15 * u, height: 15 * u)
                    .overlay(Circle().fill(outline).frame(width: 5 * u, height: 5 * u))
                BladeShape()
                    .fill(steel)
                    .overlay(BladeShape().stroke(outline, lineWidth: 2 * u))
                    .frame(width: 8 * u, height: 20 * u)
                Rectangle()
                    .fill(.questAmber)
                    .overlay(Rectangle().stroke(outline, lineWidth: 1.6 * u))
                    .frame(width: 15 * u, height: 4 * u)
                Rectangle()
                    .fill(charcoal)
                    .overlay(Rectangle().stroke(outline, lineWidth: 1.6 * u))
                    .frame(width: 5 * u, height: 8 * u)
            }
        case "weapon.stormblade":
            Image(systemName: "bolt.fill")
                .resizable()
                .foregroundStyle(.videoSapphire)
                .frame(width: 14 * u, height: 42 * u)
                .shadow(color: .videoSapphire.opacity(0.85), radius: 4 * u)
        default:
            ZStack {
                Rectangle()
                    .fill(.videoSapphire)
                    .frame(width: 12 * u, height: 12 * u)
                    .rotationEffect(.degrees(45))
                    .scaleEffect(y: 1.6)
                    .overlay(
                        Rectangle()
                            .stroke(outline, lineWidth: 2 * u)
                            .frame(width: 12 * u, height: 12 * u)
                            .rotationEffect(.degrees(45))
                            .scaleEffect(y: 1.6)
                    )
                Rectangle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 4 * u, height: 4 * u)
                    .rotationEffect(.degrees(45))
                    .scaleEffect(y: 1.6)
                    .offset(x: -2 * u, y: -3 * u)
                Capsule()
                    .fill(wood)
                    .overlay(Capsule().stroke(outline, lineWidth: 1.6 * u))
                    .frame(width: 4 * u, height: 10 * u)
                    .offset(y: 17 * u)
            }
        }
    }

    // MARK: Pet

    @ViewBuilder private var petLayer: some View {
        if item(.pet) != nil {
            ZStack {
                ear(x: -4.5)
                ear(x: 4.5)
                Circle()
                    .fill(petColor)
                    .overlay(Circle().stroke(outline, lineWidth: 2.2 * u))
                    .frame(width: 15 * u, height: 15 * u)
                Circle().fill(outline).frame(width: 2.8 * u, height: 2.8 * u).offset(x: -3.2 * u, y: -1 * u)
                Circle().fill(outline).frame(width: 2.8 * u, height: 2.8 * u).offset(x: 3.2 * u, y: -1 * u)
            }
            .offset(x: -46 * u, y: 46 * u)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }

    private func ear(x: CGFloat) -> some View {
        Image(systemName: "arrowtriangle.up.fill")
            .resizable()
            .foregroundStyle(petColor)
            .frame(width: 6 * u, height: 7 * u)
            .offset(x: x * u, y: -9 * u)
    }
}

// MARK: - Shapes

/// A quadrilateral tapering from a relative top width to a relative bottom width.
private struct TaperedShape: Shape {
    var topWidth: CGFloat
    var bottomWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let topHalf = rect.width * topWidth / 2
        let bottomHalf = rect.width * bottomWidth / 2
        path.move(to: CGPoint(x: midX - topHalf, y: rect.minY))
        path.addLine(to: CGPoint(x: midX + topHalf, y: rect.minY))
        path.addLine(to: CGPoint(x: midX + bottomHalf, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - bottomHalf, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Curved wizard-hat cone with a bent tip, matching the classic mage silhouette.
private struct ConeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: tip,
            control: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.45)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.3)
        )
        path.closeSubpath()
        return path
    }
}

/// Wavy helmet plume sweeping toward the upper right.
private struct PlumeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.96, y: rect.minY + rect.height * 0.2),
            control1: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.95),
            control2: CGPoint(x: rect.maxX * 0.88, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.52, y: rect.maxY * 0.6),
            control1: CGPoint(x: rect.maxX * 0.78, y: rect.minY + rect.height * 0.5),
            control2: CGPoint(x: rect.maxX * 0.82, y: rect.maxY * 0.55)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY),
            control1: CGPoint(x: rect.maxX * 0.3, y: rect.maxY * 0.5),
            control2: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.maxY * 0.8)
        )
        path.closeSubpath()
        return path
    }
}

/// Mohawk-style fin crest on top of the helmet, per the reference knights.
private struct FinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.3)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.maxY),
            control: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.minY + rect.height * 0.5)
        )
        path.closeSubpath()
        return path
    }
}

/// Wide sword blade with a tapered tip, matching the reference sword sprite.
private struct BladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.26))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.26))
        path.closeSubpath()
        return path
    }
}

private extension Color {
    /// Returns a lighter variant by blending toward white.
    func lighter(_ amount: Double) -> Color {
        self.mix(with: .white, by: amount)
    }

    func mix(with other: Color, by fraction: Double) -> Color {
        let clamped = max(0, min(1, fraction))
        guard let a = components, let b = other.components else { return self }
        return Color(
            red: a.red + (b.red - a.red) * clamped,
            green: a.green + (b.green - a.green) * clamped,
            blue: a.blue + (b.blue - a.blue) * clamped
        )
    }

    private var components: (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, o: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &o) else { return nil }
        return (r, g, b)
    }
}
