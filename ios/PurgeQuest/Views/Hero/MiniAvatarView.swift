//
//  MiniAvatarView.swift
//  PurgeQuest
//
//  Vector mini-figure drawn 1:1 to the reference sprite sheet: an oversized
//  wraparound dome helmet with the angular V-notched face window, black oval
//  eyes with a glint, an orange two-lobed fin crest for the Knight, a trapezoid
//  torso with collar dome + belt, thin stick limbs with fist mitts, dome boots,
//  and the wide two-facet sword. Gear (armor, head, weapon, skin, pet) recolors
//  the figure live.
//

import SwiftUI

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

    // MARK: - Palette (sampled from the reference sheet)

    private var accent: Color { isKnight ? .questAmber : .xpViolet }
    private var skinTone: Color { Color(red: 0.95, green: 0.82, blue: 0.58) }
    private var steel: Color { Color(red: 0.80, green: 0.82, blue: 0.86) }
    private var steelDeep: Color { Color(red: 0.50, green: 0.52, blue: 0.58) }
    /// Dark warm-gray dome of the reference helmet.
    private var helmetDark: Color { Color(red: 0.31, green: 0.31, blue: 0.34) }
    private var charcoal: Color { Color(red: 0.24, green: 0.23, blue: 0.27) }
    private var leather: Color { Color(red: 0.42, green: 0.26, blue: 0.15) }
    private var bootColor: Color { Color(red: 0.20, green: 0.19, blue: 0.23) }
    private var mittColor: Color { Color(red: 0.33, green: 0.32, blue: 0.37) }
    private var wood: Color { Color(red: 0.55, green: 0.38, blue: 0.22) }
    private var outline: Color { Color(red: 0.08, green: 0.07, blue: 0.09) }

    /// Tunic color driven by the equipped skin; falls back to the archetype standard.
    private var tunicColor: Color {
        switch item(.skin)?.id {
        case "skin.iron": return steelDeep
        case "skin.embers": return Color(red: 0.72, green: 0.20, blue: 0.22)
        case "skin.archivist": return Color(red: 0.40, green: 0.31, blue: 0.22)
        case "skin.warden": return Color(red: 0.26, green: 0.28, blue: 0.36)
        default: return isKnight ? Color(red: 0.35, green: 0.35, blue: 0.40) : Color(red: 0.42, green: 0.28, blue: 0.68)
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
                .frame(width: 54 * u, height: 10 * u)
                .blur(radius: 3 * u)
                .offset(y: 58 * u)

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
            headGroup
            rightArm
            weaponLayer
            petLayer
        }
        .frame(width: 112 * u, height: 140 * u)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: equipped.map(\.id))
    }

    // MARK: Legs — thin black sticks + dome boots

    private var legs: some View {
        ZStack {
            leg(x: -6.5)
            leg(x: 6.5)
            boot(x: -7.5)
            boot(x: 7.5)
        }
    }

    private func leg(x: CGFloat) -> some View {
        outlined(Capsule(), outline, lineWidth: 1.2)
            .frame(width: 4.2 * u, height: 11 * u)
            .offset(x: x * u, y: 39 * u)
    }

    private func boot(x: CGFloat) -> some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 6.5 * u,
                bottomLeadingRadius: 2 * u,
                bottomTrailingRadius: 2 * u,
                topTrailingRadius: 6.5 * u,
                style: .continuous
            )
            .fill(bootColor)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 6.5 * u,
                    bottomLeadingRadius: 2 * u,
                    bottomTrailingRadius: 2 * u,
                    topTrailingRadius: 6.5 * u,
                    style: .continuous
                )
                .stroke(outline, lineWidth: 2.2 * u)
            )
        }
        .frame(width: 14.5 * u, height: 9.5 * u)
        .offset(x: x * u, y: 47 * u)
    }

    // MARK: Torso — trapezoid tunic, collar dome, belt with oval buckle

    private var torso: some View {
        ZStack {
            outlined(TaperedShape(topWidth: 0.78, bottomWidth: 1), tunicColor, lineWidth: 2.6)
                .frame(width: 28 * u, height: 24 * u)

            armorLayer
            belt

            // Collar dome: amber half-disc sitting on the tunic's top edge.
            Circle()
                .fill(accent)
                .overlay(Circle().stroke(outline, lineWidth: 2.2 * u))
                .frame(width: 17 * u, height: 17 * u)
                .offset(y: -8 * u)
            // Small notch cut into the collar's top, per the reference torso.
            NotchShape()
                .fill(outline)
                .frame(width: 5 * u, height: 3.5 * u)
                .offset(y: -12.5 * u)
        }
        .offset(y: 21 * u)
    }

    @ViewBuilder private var armorLayer: some View {
        switch item(.armor)?.id {
        case "armor.iron":
            pauldron(x: -14.5)
            pauldron(x: 14.5)
        case "armor.dragonhide":
            pauldron(x: -14.5, tint: .gemEmerald)
            pauldron(x: 14.5, tint: .gemEmerald)
        case "armor.arcanist":
            Circle()
                .fill(.xpViolet)
                .frame(width: 5 * u, height: 5 * u)
                .overlay(Circle().stroke(outline, lineWidth: 1.4 * u))
                .offset(y: 4 * u)
        default:
            pauldron(x: -14.5, tint: mittColor)
            pauldron(x: 14.5, tint: mittColor)
        }
    }

    private func pauldron(x: CGFloat, tint: Color? = nil) -> some View {
        ZStack {
            Ellipse()
                .fill(tint ?? steelDeep)
                .overlay(Ellipse().stroke(outline, lineWidth: 2.2 * u))
                .frame(width: 12 * u, height: 10 * u)
            Circle()
                .fill(outline)
                .frame(width: 2.6 * u, height: 2.6 * u)
                .offset(y: 3.5 * u)
        }
        .offset(x: x * u, y: -9.5 * u)
    }

    private var belt: some View {
        ZStack {
            Rectangle()
                .fill(leather)
                .frame(width: 28 * u, height: 6 * u)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.6 * u))
                .offset(y: 8 * u)
            Capsule()
                .fill(.questAmber)
                .overlay(Capsule().stroke(outline, lineWidth: 1.8 * u))
                .frame(width: 9 * u, height: 6 * u)
                .offset(y: 8 * u)
        }
    }

    // MARK: Robe (behind body, arcanist/hermit variants)

    @ViewBuilder private var robeBack: some View {
        if item(.armor)?.id == "armor.arcanist" || item(.skin)?.id == "skin.archivist" {
            TaperedShape(topWidth: 0.55, bottomWidth: 1)
                .fill(
                    item(.armor)?.id == "armor.arcanist"
                        ? Color(red: 0.46, green: 0.30, blue: 0.76)
                        : Color(red: 0.33, green: 0.25, blue: 0.17)
                )
                .overlay(TaperedShape(topWidth: 0.55, bottomWidth: 1).stroke(outline, lineWidth: 2.4 * u))
                .frame(width: 44 * u, height: 40 * u)
                .offset(y: 24 * u)
        }
    }

    // MARK: Arms — thin black sticks with fist mitts; the right mitt grips the weapon

    private var leftArm: some View { arm(side: -1) }

    /// Drawn before the weapon layer so the sword overlays the front of the mitt.
    private var rightArm: some View {
        ZStack {
            arm(side: 1)
            Capsule()
                .fill(outline)
                .frame(width: 6 * u, height: 1.6 * u)
                .offset(x: 25.5 * u, y: 27 * u)
        }
    }

    private func arm(side: CGFloat) -> some View {
        ZStack {
            outlined(Capsule(), outline, lineWidth: 1.2)
                .frame(width: 4.2 * u, height: 14 * u)
                .rotationEffect(.degrees(side * 30))
                .offset(x: side * 3.5 * u, y: 3 * u)

            ZStack {
                Circle()
                    .fill(mittColor)
                    .overlay(Circle().stroke(outline, lineWidth: 2.2 * u))
                Circle()
                    .fill(outline)
                    .frame(width: 2.4 * u, height: 2.4 * u)
                    .offset(x: side * 1.5 * u, y: 1.5 * u)
            }
            .frame(width: 9.5 * u, height: 9.5 * u)
            .offset(x: side * 9.5 * u, y: 10 * u)
        }
        .offset(x: side * 16 * u, y: 15 * u)
    }

    // MARK: Head — oversized wraparound dome (~60% of the figure)

    private var headGroup: some View {
        headModel
            .offset(y: -26 * u)
    }

    @ViewBuilder private var headModel: some View {
        switch item(.head)?.id {
        case "head.iron":
            knightHelmet(dome: steel, crest: .none, band: true)
        case "head.dragoncrest":
            knightHelmet(dome: .questAmber, crest: .crimson, band: false)
        case "head.starhat":
            starWizardHead
        case "head.hood":
            hoodedHead
        default:
            if isKnight {
                knightHelmet(dome: helmetDark, crest: .orange, band: false)
            } else {
                wizardHead
            }
        }
    }

    private enum Crest {
        case orange
        case crimson
        case none
    }

    /// Solid black oval eyes with a white glint, per the reference sheet.
    private var eyes: some View {
        ZStack {
            eye(x: -9.5)
            eye(x: 9.5)
        }
    }

    private func eye(x: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(outline)
                .frame(width: 8 * u, height: 8 * u)
            Circle()
                .fill(Color.white)
                .frame(width: 2.4 * u, height: 2.4 * u)
                .offset(x: 1.4 * u, y: -1.4 * u)
        }
        .offset(x: x * u)
    }

    /// Angular V-notched face window filling the helmet's lower half.
    private func faceWindow() -> some View {
        ZStack {
            FaceWindowShape()
                .fill(skinTone)
                .overlay(FaceWindowShape().stroke(outline, lineWidth: 2.4 * u))
                .frame(width: 48 * u, height: 36 * u)
                .offset(y: 10.5 * u)

            eyes.offset(y: 6 * u)
        }
    }

    /// Knight helmet: big dome, angular face window, optional crest and rivet band.
    private func knightHelmet(dome: Color, crest: Crest, band: Bool) -> some View {
        ZStack {
            switch crest {
            case .orange:
                finCrest(color: .questAmber)
            case .crimson:
                finCrest(color: .combatCrimson)
            case .none:
                EmptyView()
            }

            Ellipse()
                .fill(dome)
                .overlay(Ellipse().stroke(outline, lineWidth: 2.8 * u))
                .frame(width: 70 * u, height: 66 * u)

            if band {
                RoundedRectangle(cornerRadius: 4.5 * u, style: .continuous)
                    .fill(steelDeep)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4.5 * u, style: .continuous)
                            .stroke(outline, lineWidth: 2 * u)
                    )
                    .frame(width: 50 * u, height: 9 * u)
                    .offset(y: -16 * u)
                bandRivet(x: -16)
                bandRivet(x: 0)
                bandRivet(x: 16)
            }

            helmetShine
            faceWindow()
        }
    }

    /// Two-lobed orange fin crest with the dark center slice, per the close-up reference.
    private func finCrest(color: Color) -> some View {
        ZStack {
            FinShape()
                .fill(color)
            // Dark slice between the two lobes, per the close-up reference.
            NotchShape()
                .fill(outline)
                .frame(width: 4.5 * u, height: 12 * u)
                .rotationEffect(.degrees(14))
                .offset(x: -3 * u, y: -2 * u)
        }
        .overlay(FinShape().stroke(outline, lineWidth: 2.4 * u))
        .frame(width: 36 * u, height: 22 * u)
        .offset(x: 2 * u, y: -36 * u)
    }

    private func bandRivet(x: CGFloat) -> some View {
        Circle()
            .fill(steel)
            .frame(width: 2.8 * u, height: 2.8 * u)
            .offset(x: x * u, y: -16 * u)
    }

    /// Two soft sheen streaks on the dome's upper-right, per the reference.
    private var helmetShine: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 15 * u, height: 5 * u)
                .rotationEffect(.degrees(38))
                .offset(x: 15 * u, y: -20 * u)
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 8 * u, height: 4 * u)
                .rotationEffect(.degrees(38))
                .offset(x: 6 * u, y: -26 * u)
        }
    }

    /// Magician head: open round face, black oval eyes, bushy white mustache + beard, pointed hat.
    private var wizardHead: some View {
        ZStack {
            wizardHat

            Circle()
                .fill(skinTone)
                .overlay(Circle().stroke(outline, lineWidth: 2.6 * u))
                .frame(width: 50 * u, height: 50 * u)
                .offset(y: 5 * u)

            eyes.offset(y: 2 * u)

            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 12 * u, height: 5 * u)
                .rotationEffect(.degrees(14))
                .offset(x: -6 * u, y: 12 * u)
            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 12 * u, height: 5 * u)
                .rotationEffect(.degrees(-14))
                .offset(x: 6 * u, y: 12 * u)

            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(outline, lineWidth: 2.2 * u))
                .frame(width: 27 * u, height: 20 * u)
                .offset(y: 22 * u)
        }
    }

    /// Starry variant of the wizard hat for the "starhat" cosmetic.
    private var starWizardHead: some View {
        ZStack {
            wizardHead
            Image(systemName: "sparkle")
                .font(.system(size: 9 * u, weight: .bold))
                .foregroundStyle(.questAmber)
                .offset(x: 8 * u, y: -32 * u)
        }
    }

    /// Pointed wizard hat with bent tip, brim and amber band.
    private var wizardHat: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.46, green: 0.30, blue: 0.76))
                .frame(width: 9 * u, height: 9 * u)
                .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                .offset(x: -5 * u, y: -44 * u)

            ConeShape()
                .fill(Color(red: 0.52, green: 0.34, blue: 0.82))
                .overlay(ConeShape().stroke(outline, lineWidth: 2.4 * u))
                .frame(width: 54 * u, height: 36 * u)
                .offset(y: -26 * u)

            Ellipse()
                .fill(Color(red: 0.46, green: 0.30, blue: 0.76))
                .overlay(Ellipse().stroke(outline, lineWidth: 2.4 * u))
                .frame(width: 60 * u, height: 13 * u)
                .offset(y: -9 * u)

            Rectangle()
                .fill(.questAmber)
                .frame(width: 24 * u, height: 5 * u)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.4 * u))
                .offset(y: -15 * u)
        }
    }

    /// Dark hood wrapping the head with a shadowed face.
    private var hoodedHead: some View {
        ZStack {
            Circle()
                .fill(charcoal)
                .overlay(Circle().stroke(outline, lineWidth: 2.8 * u))
                .frame(width: 62 * u, height: 62 * u)

            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .foregroundStyle(charcoal)
                .frame(width: 14 * u, height: 15 * u)
                .offset(y: -34 * u)

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
        // Anchored so the grip passes through the right fist at (81.5, 95);
        // the blade leans outward, resting against the helmet like the reference.
        .rotationEffect(.degrees(-8), anchor: .center)
        .offset(x: 25.5 * u, y: 10.5 * u)
    }

    /// Default weapon: the Knight's wide two-facet sword, held tip-up.
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
                    .frame(width: 14 * u, height: 30 * u)
                // Two-tone split: darker left facet, light sheen on the right,
                // clipped to the tapered blade silhouette.
                Rectangle()
                    .fill(steelDeep.opacity(0.45))
                    .frame(width: 7 * u, height: 30 * u)
                    .offset(x: -3.5 * u)
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2.6 * u, height: 19 * u)
                    .offset(x: 2.6 * u, y: -1 * u)
            }
            .frame(width: 14 * u, height: 30 * u)
            .clipShape(BladeShape())
            .overlay(BladeShape().stroke(outline, lineWidth: 2.2 * u))
            Rectangle()
                .fill(.questAmber)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.8 * u))
                .frame(width: 20 * u, height: 6 * u)
            Rectangle()
                .fill(leather)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.8 * u))
                .frame(width: 6 * u, height: 9 * u)
            Rectangle()
                .fill(Color(red: 0.30, green: 0.18, blue: 0.10))
                .overlay(Rectangle().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 6 * u, height: 3.5 * u)
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
            .offset(x: -46 * u, y: 48 * u)
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

/// Small downward V used for the collar notch.
private struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
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

/// Angular face window: wide shoulders, deep V-notch at the top center,
/// bulging sides and a broad rounded-U bottom — matching the close-up reference.
private struct FaceWindowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.06, y: rect.minY + h * 0.30))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.36, y: rect.minY + h * 0.05))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.38))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.64, y: rect.minY + h * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.94, y: rect.minY + h * 0.30))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.70),
            control: CGPoint(x: rect.maxX - w * 0.005, y: rect.minY + h * 0.52)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.70),
            control: CGPoint(x: rect.midX, y: rect.maxY + h * 0.16)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.06, y: rect.minY + h * 0.30),
            control: CGPoint(x: rect.minX + w * 0.005, y: rect.minY + h * 0.52)
        )
        path.closeSubpath()
        return path
    }
}

/// Two-lobed mohawk fin with the dark center slice: a small curl on the left,
/// a taller sweeping blade on the right — per the close-up reference crest.
private struct FinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.04, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.34, y: rect.minY + h * 0.08),
            control: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.28)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.50, y: rect.minY + h * 0.52),
            control: CGPoint(x: rect.minX + w * 0.42, y: rect.minY + h * 0.30)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.68, y: rect.minY),
            control: CGPoint(x: rect.minX + w * 0.56, y: rect.minY + h * 0.10)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.98, y: rect.maxY),
            control: CGPoint(x: rect.maxX + w * 0.02, y: rect.minY + h * 0.30)
        )
        path.closeSubpath()
        return path
    }
}

/// Wide sword blade with a tapered tip (points up), matching the reference sword.
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
