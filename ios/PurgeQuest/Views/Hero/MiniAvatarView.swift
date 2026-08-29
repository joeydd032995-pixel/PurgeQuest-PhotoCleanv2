//
//  MiniAvatarView.swift
//  PurgeQuest
//

import SwiftUI

/// The hero mini-figure, drawn in a "tiny style" chibi standard: oversized head,
/// thick outlines, big cartoon eyes. The Knight wears a plumed helmet with a
/// dark face opening, carries a shield and sword; the Magician wears a pointed
/// hat and beard. Armor, headgear, weapon, tunic and pet change with equipped items.
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
    private var skinTone: Color { Color(red: 0.96, green: 0.78, blue: 0.55) }
    private var steel: Color { Color(red: 0.72, green: 0.75, blue: 0.80) }
    private var steelDeep: Color { Color(red: 0.45, green: 0.48, blue: 0.55) }
    private var charcoal: Color { Color(red: 0.22, green: 0.20, blue: 0.26) }
    private var wood: Color { Color(red: 0.55, green: 0.38, blue: 0.22) }
    private var outline: Color { Color(red: 0.09, green: 0.07, blue: 0.11) }

    /// Tunic color driven by the equipped skin; falls back to the archetype accent.
    private var tunicColor: Color {
        switch item(.skin)?.id {
        case "skin.iron": return steelDeep
        case "skin.embers": return Color(red: 0.72, green: 0.20, blue: 0.22)
        case "skin.archivist": return Color(red: 0.40, green: 0.31, blue: 0.22)
        case "skin.warden": return Color(red: 0.26, green: 0.28, blue: 0.36)
        default: return accent
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
                .frame(width: 50 * u, height: 10 * u)
                .blur(radius: 3 * u)
                .offset(y: 64 * u)

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
            boot(x: -7.5)
            boot(x: 7.5)
        }
    }

    private func leg(x: CGFloat) -> some View {
        outlined(Capsule(), charcoal, lineWidth: 2.2)
            .frame(width: 9 * u, height: 17 * u)
            .offset(x: x * u, y: 34 * u)
    }

    private func boot(x: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5 * u, style: .continuous)
                .fill(Color(red: 0.32, green: 0.24, blue: 0.16))
            RoundedRectangle(cornerRadius: 3.5 * u, style: .continuous)
                .stroke(outline, lineWidth: 2.2 * u)
        }
        .frame(width: 16 * u, height: 9 * u)
        .offset(x: x * u, y: 44 * u)
    }

    // MARK: Torso & armor

    private var torso: some View {
        ZStack {
            bodyShape
            armorLayer
            belt
        }
        .offset(y: 12 * u)
    }

    private var bodyShape: some View {
        outlined(
            RoundedRectangle(cornerRadius: 9 * u, style: .continuous),
            tunicColor,
            lineWidth: 2.6
        )
        .frame(width: 31 * u, height: 27 * u)
    }

    @ViewBuilder private var armorLayer: some View {
        switch item(.armor)?.id {
        case "armor.iron":
            Circle().fill(steel).frame(width: 12 * u, height: 12 * u)
                .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                .offset(x: -17 * u, y: -9 * u)
            Circle().fill(steel).frame(width: 12 * u, height: 12 * u)
                .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                .offset(x: 17 * u, y: -9 * u)
            outlined(RoundedRectangle(cornerRadius: 5 * u, style: .continuous), steel, lineWidth: 2.4)
                .frame(width: 25 * u, height: 19 * u)
            Rectangle()
                .fill(.questAmber)
                .frame(width: 25 * u, height: 3.4 * u)
                .offset(y: -3 * u)
        case "armor.dragonhide":
            Circle().fill(.gemEmerald).frame(width: 12 * u, height: 12 * u)
                .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                .offset(x: -17 * u, y: -9 * u)
            Circle().fill(.gemEmerald).frame(width: 12 * u, height: 12 * u)
                .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                .offset(x: 17 * u, y: -9 * u)
            outlined(RoundedRectangle(cornerRadius: 5 * u, style: .continuous), .gemEmeraldDeep, lineWidth: 2.4)
                .frame(width: 25 * u, height: 19 * u)
            scaleDots
        case "armor.arcanist":
            outlined(RoundedRectangle(cornerRadius: 4 * u, style: .continuous), Color(red: 0.46, green: 0.30, blue: 0.76), lineWidth: 2.4)
                .frame(width: 26 * u, height: 8 * u)
                .offset(y: -8 * u)
            Circle()
                .fill(.questAmber)
                .frame(width: 5 * u, height: 5 * u)
                .overlay(Circle().stroke(outline, lineWidth: 1.4 * u))
                .offset(y: 2 * u)
        default:
            EmptyView()
        }
    }

    private var scaleDots: some View {
        ZStack {
            scaleDot(x: -6, y: -2)
            scaleDot(x: 0, y: -2)
            scaleDot(x: 6, y: -2)
            scaleDot(x: -3, y: 4)
            scaleDot(x: 3, y: 4)
        }
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
                .fill(charcoal)
                .frame(width: 31 * u, height: 5 * u)
                .offset(y: 9 * u)
            Circle()
                .fill(.questAmber)
                .frame(width: 5.5 * u, height: 5.5 * u)
                .overlay(Circle().stroke(outline, lineWidth: 1.4 * u))
                .offset(y: 9 * u)
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
                .frame(width: 46 * u, height: 40 * u)
                .offset(y: 20 * u)
        }
    }

    // MARK: Arms

    private var leftArm: some View {
        outlined(Capsule(), tunicColor, lineWidth: 2.2)
            .frame(width: 8 * u, height: 17 * u)
            .rotationEffect(.degrees(18))
            .offset(x: -18 * u, y: 8 * u)
    }

    private var rightArm: some View {
        outlined(Capsule(), tunicColor, lineWidth: 2.2)
            .frame(width: 8 * u, height: 17 * u)
            .rotationEffect(.degrees(-42))
            .offset(x: 18 * u, y: 6 * u)
    }

    // MARK: Shield (Knight signature)

    @ViewBuilder private var shield: some View {
        if isKnight {
            ZStack {
                RoundedRectangle(cornerRadius: 6 * u, style: .continuous)
                    .fill(charcoal)
                Rectangle()
                    .fill(Color.combatCrimson)
                    .frame(width: 4.5 * u, height: 15 * u)
                Rectangle()
                    .fill(Color.combatCrimson)
                    .frame(width: 10 * u, height: 4.5 * u)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6 * u, style: .continuous)
                    .stroke(outline, lineWidth: 2.4 * u)
            )
            .frame(width: 20 * u, height: 24 * u)
            .offset(x: -26 * u, y: 13 * u)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    // MARK: Head

    private var headGroup: some View {
        ZStack {
            headModel
        }
        .offset(y: -28 * u)
    }

    @ViewBuilder private var headModel: some View {
        switch item(.head)?.id {
        case "head.iron":
            plumedHelmet(dome: steel, trim: .questAmber, showPlume: false)
        case "head.dragoncrest":
            plumedHelmet(dome: .questAmber, trim: .combatCrimson, showPlume: true)
        case "head.starhat":
            starWizardHat
        case "head.hood":
            hoodedHead
        default:
            if isKnight {
                plumedHelmet(dome: steel, trim: steelDeep, showPlume: true)
            } else {
                wizardHead
            }
        }
    }

    /// Big cartoon eyes with dark pupils and a glint, matching the sprite standard.
    private var eyes: some View {
        ZStack {
            eye(x: -7.5)
            eye(x: 7.5)
        }
    }

    private func eye(x: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(outline, lineWidth: 1.8 * u))
                .frame(width: 11.5 * u, height: 11.5 * u)
            Circle()
                .fill(outline)
                .frame(width: 5.4 * u, height: 5.4 * u)
                .offset(x: 1.8 * u, y: 0.6 * u)
            Circle()
                .fill(Color.white)
                .frame(width: 2 * u, height: 2 * u)
                .offset(x: 3.4 * u, y: -1.2 * u)
        }
        .offset(x: x * u)
    }

    /// Knight-style helmet: big dome, dark face opening, trim band, optional plume.
    private func plumedHelmet(dome: Color, trim: Color, showPlume: Bool) -> some View {
        ZStack {
            if showPlume {
                PlumeShape()
                    .fill(Color.combatCrimson)
                    .overlay(PlumeShape().stroke(outline, lineWidth: 2.2 * u))
                    .frame(width: 24 * u, height: 17 * u)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 4 * u, y: -31 * u)
            }

            Circle()
                .fill(dome)
                .overlay(Circle().stroke(outline, lineWidth: 2.6 * u))
                .frame(width: 54 * u, height: 54 * u)

            Circle()
                .fill(outline)
                .frame(width: 38 * u, height: 38 * u)
                .offset(y: 7 * u)

            Circle()
                .fill(skinTone)
                .frame(width: 33 * u, height: 33 * u)
                .offset(y: 8.5 * u)

            eyes.offset(y: 6 * u)

            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 27 * u, height: 4.5 * u)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.4 * u))
                .offset(y: -5 * u)

            rivet(x: -19, y: -15)
            rivet(x: 19, y: -15)
            rivet(x: 0, y: -22)
        }
    }

    private func rivet(x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(Color.white.opacity(0.45))
            .frame(width: 2.8 * u, height: 2.8 * u)
            .offset(x: x * u, y: y * u)
    }

    /// Magician head: open face, big eyes, bushy white beard, pointed hat.
    private var wizardHead: some View {
        ZStack {
            wizardHat

            Circle()
                .fill(skinTone)
                .overlay(Circle().stroke(outline, lineWidth: 2.6 * u))
                .frame(width: 45 * u, height: 45 * u)
                .offset(y: 2 * u)

            eyes.offset(y: -1 * u)

            // Mustache
            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 11 * u, height: 5 * u)
                .rotationEffect(.degrees(14))
                .offset(x: -5.5 * u, y: 8.5 * u)
            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 11 * u, height: 5 * u)
                .rotationEffect(.degrees(-14))
                .offset(x: 5.5 * u, y: 8.5 * u)

            // Beard
            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(outline, lineWidth: 2.2 * u))
                .frame(width: 26 * u, height: 19 * u)
                .offset(y: 17 * u)
        }
    }

    /// Pointed wizard hat with bent tip, brim and amber band.
    private var wizardHat: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.46, green: 0.30, blue: 0.76))
                .frame(width: 8 * u, height: 8 * u)
                .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                .offset(x: -4 * u, y: -38 * u)

            ConeShape()
                .fill(Color(red: 0.52, green: 0.34, blue: 0.82))
                .overlay(ConeShape().stroke(outline, lineWidth: 2.4 * u))
                .frame(width: 50 * u, height: 32 * u)
                .offset(y: -22 * u)

            Ellipse()
                .fill(Color(red: 0.46, green: 0.30, blue: 0.76))
                .overlay(Ellipse().stroke(outline, lineWidth: 2.4 * u))
                .frame(width: 56 * u, height: 12 * u)
                .offset(y: -8 * u)

            Rectangle()
                .fill(.questAmber)
                .frame(width: 22 * u, height: 4.5 * u)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.4 * u))
                .offset(y: -13 * u)
        }
    }

    /// Starry variant of the wizard hat for the "starhat" cosmetic.
    private var starWizardHat: some View {
        ZStack {
            wizardHat
            Image(systemName: "sparkle")
                .font(.system(size: 9 * u, weight: .bold))
                .foregroundStyle(.questAmber)
                .offset(x: 6 * u, y: -26 * u)
        }
    }

    /// Dark hood wrapping the head with a shadowed face.
    private var hoodedHead: some View {
        ZStack {
            Circle()
                .fill(charcoal)
                .overlay(Circle().stroke(outline, lineWidth: 2.6 * u))
                .frame(width: 52 * u, height: 52 * u)

            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .foregroundStyle(charcoal)
                .frame(width: 13 * u, height: 14 * u)
                .offset(y: -30 * u)

            Circle()
                .fill(skinTone.mix(with: .black, by: 0.18))
                .frame(width: 32 * u, height: 32 * u)
                .offset(y: 8 * u)

            eyes.offset(y: 6 * u)
        }
    }

    // MARK: Weapon

    @ViewBuilder private var weaponLayer: some View {
        ZStack {
            weaponModel
            Circle()
                .fill(skinTone)
                .overlay(Circle().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 8 * u, height: 8 * u)
                .offset(y: 12 * u)
        }
        .offset(x: 30 * u, y: -4 * u)
    }

    /// Default weapon: the Knight's simple sword, held upright like the sprites.
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
            RoundedRectangle(cornerRadius: 1.5 * u, style: .continuous)
                .fill(steel)
                .overlay(RoundedRectangle(cornerRadius: 1.5 * u, style: .continuous).stroke(outline, lineWidth: 2 * u))
                .frame(width: 6.5 * u, height: 25 * u)
            Rectangle()
                .fill(.questAmber)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 15 * u, height: 4.5 * u)
            Rectangle()
                .fill(charcoal)
                .overlay(Rectangle().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 4.5 * u, height: 9 * u)
        }
    }

    private var simpleWand: some View {
        VStack(spacing: 2 * u) {
            Circle()
                .fill(.xpViolet)
                .overlay(Circle().stroke(outline, lineWidth: 1.8 * u))
                .frame(width: 8 * u, height: 8 * u)
                .shadow(color: .xpViolet.opacity(0.8), radius: 3.5 * u)
            Capsule()
                .fill(wood)
                .overlay(Capsule().stroke(outline, lineWidth: 1.6 * u))
                .frame(width: 4 * u, height: 30 * u)
        }
    }

    @ViewBuilder private func heldWeapon(id: String) -> some View {
        switch id {
        case "weapon.staff":
            VStack(spacing: 2 * u) {
                Circle()
                    .fill(.xpViolet)
                    .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                    .frame(width: 12 * u, height: 12 * u)
                    .shadow(color: .xpViolet.opacity(0.8), radius: 4 * u)
                Capsule()
                    .fill(wood)
                    .overlay(Capsule().stroke(outline, lineWidth: 1.8 * u))
                    .frame(width: 4.5 * u, height: 42 * u)
            }
        case "weapon.gem":
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3 * u, style: .continuous)
                    .fill(.questAmber)
                    .overlay(RoundedRectangle(cornerRadius: 3 * u, style: .continuous).stroke(outline, lineWidth: 2.2 * u))
                    .frame(width: 18 * u, height: 10 * u)
                Capsule()
                    .fill(wood)
                    .overlay(Capsule().stroke(outline, lineWidth: 1.8 * u))
                    .frame(width: 4.5 * u, height: 32 * u)
            }
        case "weapon.reel":
            VStack(spacing: 0) {
                Circle()
                    .fill(.videoSapphire)
                    .overlay(Circle().stroke(outline, lineWidth: 2 * u))
                    .frame(width: 14 * u, height: 14 * u)
                    .overlay(Circle().fill(outline).frame(width: 5 * u, height: 5 * u))
                    .offset(y: 4 * u)
                RoundedRectangle(cornerRadius: 1.5 * u, style: .continuous)
                    .fill(steel)
                    .overlay(RoundedRectangle(cornerRadius: 1.5 * u, style: .continuous).stroke(outline, lineWidth: 2 * u))
                    .frame(width: 6 * u, height: 22 * u)
                Rectangle()
                    .fill(.questAmber)
                    .overlay(Rectangle().stroke(outline, lineWidth: 1.6 * u))
                    .frame(width: 14 * u, height: 4 * u)
                Rectangle()
                    .fill(charcoal)
                    .overlay(Rectangle().stroke(outline, lineWidth: 1.6 * u))
                    .frame(width: 4.5 * u, height: 8 * u)
            }
        case "weapon.stormblade":
            Image(systemName: "bolt.fill")
                .resizable()
                .foregroundStyle(.videoSapphire)
                .frame(width: 13 * u, height: 40 * u)
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
                    .offset(y: 16 * u)
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
            .offset(x: -46 * u, y: 50 * u)
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

/// Wavy helmet plume sweeping toward the upper right, like the knight sprites.
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
