//
//  MiniAvatarView.swift
//  PurgeQuest
//

import SwiftUI

/// A chibi vector mini-figure of the hero, drawn entirely with SwiftUI shapes.
/// Tunic, armor, headgear, weapon and pet visually change with equipped items.
struct MiniAvatarView: View {
    let hero: Hero
    let equipped: [CosmeticItem]
    /// Size of the orb the figure is drawn for; the figure scales proportionally.
    var size: CGFloat = 210

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBobbing = false

    /// Base design unit so every dimension scales with the orb size.
    private var u: CGFloat { size / 200 }

    private func item(_ type: CosmeticType) -> CosmeticItem? {
        equipped.first { $0.type == type }
    }

    // MARK: - Palette

    private var accent: Color { hero.archetype == .knight ? .questAmber : .xpViolet }
    private var skinTone: Color { Color(red: 0.95, green: 0.79, blue: 0.64) }
    private var steel: Color { Color(red: 0.64, green: 0.68, blue: 0.74) }
    private var steelDeep: Color { Color(red: 0.40, green: 0.44, blue: 0.52) }
    private var charcoal: Color { Color(red: 0.15, green: 0.14, blue: 0.19) }
    private var wood: Color { Color(red: 0.52, green: 0.36, blue: 0.21) }
    private var leather: Color { Color(red: 0.36, green: 0.28, blue: 0.20) }

    /// Tunic color driven by the equipped skin; falls back to the archetype accent.
    private var tunicColor: Color {
        switch item(.skin)?.id {
        case "skin.iron": return steelDeep
        case "skin.embers": return .combatCrimsonDeep
        case "skin.archivist": return leather
        case "skin.warden": return Color(red: 0.23, green: 0.25, blue: 0.32)
        default: return accent
        }
    }

    private var petColor: Color {
        switch item(.pet)?.id {
        case "pet.reel": return .videoSapphire
        case "pet.owl": return .questAmberDeep
        default: return .gemEmerald
        }
    }

    private var hasRobe: Bool {
        item(.armor)?.id == "armor.arcanist" || item(.skin)?.id == "skin.archivist"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.4))
                .frame(width: 46 * u, height: 10 * u)
                .blur(radius: 3 * u)
                .offset(y: 62 * u)

            figure
                .offset(y: isBobbing ? -2.5 * u : 0)
        }
        .frame(width: 118 * u, height: 132 * u)
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
            arms
            headGroup
            weaponLayer
            petLayer
        }
        .frame(width: 112 * u, height: 130 * u)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: equipped.map(\.id))
    }

    // MARK: Legs & boots

    private var legs: some View {
        ZStack {
            shadedCapsule(width: 9, height: 22).offset(x: -9 * u, y: -4 * u)
            shadedCapsule(width: 9, height: 22).offset(x: 9 * u, y: -4 * u)
            boot(x: -9)
            boot(x: 9)
        }
        .offset(y: 31 * u)
    }

    private func boot(x: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4 * u, style: .continuous)
            .fill(charcoal)
            .frame(width: 16 * u, height: 8 * u)
            .overlay(
                RoundedRectangle(cornerRadius: 4 * u, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 3 * u)
                    .offset(y: -2 * u)
            )
            .offset(x: x * u, y: 6 * u)
    }

    private func shadedCapsule(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(tunicColor)
            .overlay(Capsule().fill(Color.black.opacity(0.3)))
            .frame(width: width * u, height: height * u)
    }

    // MARK: Torso & armor

    private var torso: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13 * u, style: .continuous)
                .fill(tunicColor)
                .frame(width: 42 * u, height: 46 * u)

            armorLayer
        }
        .offset(y: 1 * u)
    }

    @ViewBuilder private var armorLayer: some View {
        switch item(.armor)?.id {
        case "armor.iron":
            pauldrons(color: steel)
            chestPlate(fill: steel, stroke: steelDeep)
            rivets
        case "armor.dragonhide":
            pauldrons(color: .gemEmerald)
            chestPlate(fill: .gemEmeraldDeep, stroke: .gemEmerald)
            scaleDots
        case "armor.arcanist":
            RoundedRectangle(cornerRadius: 6 * u, style: .continuous)
                .fill(Color(red: 0.42, green: 0.28, blue: 0.72))
                .frame(width: 34 * u, height: 10 * u)
                .offset(y: -17 * u)
            Circle()
                .fill(.questAmber)
                .frame(width: 5 * u, height: 5 * u)
                .offset(y: -8 * u)
        default:
            EmptyView()
        }
    }

    private func pauldrons(color: Color) -> some View {
        ZStack {
            Circle().fill(color).frame(width: 15 * u, height: 15 * u)
                .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1.2 * u))
                .offset(x: -20 * u, y: -17 * u)
            Circle().fill(color).frame(width: 15 * u, height: 15 * u)
                .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1.2 * u))
                .offset(x: 20 * u, y: -17 * u)
        }
    }

    private func chestPlate(fill: Color, stroke: Color) -> some View {
        RoundedRectangle(cornerRadius: 8 * u, style: .continuous)
            .fill(
                LinearGradient(colors: [fill.lighter(0.15), fill], startPoint: .top, endPoint: .bottom)
            )
            .frame(width: 32 * u, height: 24 * u)
            .overlay(RoundedRectangle(cornerRadius: 8 * u, style: .continuous).stroke(stroke, lineWidth: 1.4 * u))
            .offset(y: 2 * u)
    }

    private var rivets: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.5)).frame(width: 2.6 * u, height: 2.6 * u).offset(x: -8 * u, y: -2 * u)
            Circle().fill(Color.white.opacity(0.5)).frame(width: 2.6 * u, height: 2.6 * u).offset(x: 8 * u, y: -2 * u)
            Circle().fill(Color.white.opacity(0.5)).frame(width: 2.6 * u, height: 2.6 * u).offset(y: 7 * u)
        }
    }

    private var scaleDots: some View {
        ZStack {
            Circle().fill(.gemEmerald).frame(width: 3 * u, height: 3 * u).offset(x: -6 * u, y: -1 * u)
            Circle().fill(.gemEmerald).frame(width: 3 * u, height: 3 * u).offset(x: 0, y: -1 * u)
            Circle().fill(.gemEmerald).frame(width: 3 * u, height: 3 * u).offset(x: 6 * u, y: -1 * u)
            Circle().fill(.gemEmerald).frame(width: 3 * u, height: 3 * u).offset(x: -3 * u, y: 6 * u)
            Circle().fill(.gemEmerald).frame(width: 3 * u, height: 3 * u).offset(x: 3 * u, y: 6 * u)
        }
        .offset(y: 2 * u)
    }

    // MARK: Robe (behind body)

    @ViewBuilder private var robeBack: some View {
        if hasRobe {
            TaperedShape(topWidth: 0.62, bottomWidth: 1)
                .fill(
                    item(.armor)?.id == "armor.arcanist"
                        ? Color(red: 0.36, green: 0.23, blue: 0.62)
                        : Color(red: 0.30, green: 0.22, blue: 0.15)
                )
                .frame(width: 60 * u, height: 48 * u)
                .offset(y: 4 * u)
        }
    }

    // MARK: Arms

    private var arms: some View {
        ZStack {
            Capsule()
                .fill(tunicColor)
                .frame(width: 9 * u, height: 30 * u)
                .rotationEffect(.degrees(16))
                .offset(x: -25 * u, y: 0)
            Circle().fill(skinTone).frame(width: 7 * u, height: 7 * u).offset(x: -31 * u, y: 13 * u)

            Capsule()
                .fill(tunicColor)
                .frame(width: 9 * u, height: 30 * u)
                .rotationEffect(.degrees(-16))
                .offset(x: 25 * u, y: 0)
            Circle().fill(skinTone).frame(width: 7 * u, height: 7 * u).offset(x: 31 * u, y: 13 * u)
        }
        .offset(y: -1 * u)
    }

    // MARK: Head

    private var headGroup: some View {
        ZStack {
            if item(.head)?.id == "head.hood" {
                hoodBack
            }

            Circle()
                .fill(skinTone)
                .frame(width: 40 * u, height: 40 * u)

            face
            headwear
        }
        .offset(y: -39 * u)
    }

    private var face: some View {
        ZStack {
            Circle().fill(Color.dungeonVoid.opacity(0.85)).frame(width: 4.2 * u, height: 4.2 * u).offset(x: -7.5 * u, y: -3 * u)
            Circle().fill(Color.dungeonVoid.opacity(0.85)).frame(width: 4.2 * u, height: 4.2 * u).offset(x: 7.5 * u, y: -3 * u)

            Circle()
                .trim(from: 0.08, to: 0.42)
                .stroke(Color.dungeonVoid.opacity(0.75), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))
                .frame(width: 12 * u, height: 12 * u)
                .offset(y: 4 * u)
        }
    }

    @ViewBuilder private var headwear: some View {
        switch item(.head)?.id {
        case "head.iron":
            ironDome
            Rectangle()
                .fill(steelDeep)
                .frame(width: 5 * u, height: 14 * u)
                .offset(y: 5 * u)
        case "head.dragoncrest":
            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .foregroundStyle(.questAmber)
                .frame(width: 8 * u, height: 9 * u)
                .rotationEffect(.degrees(-38))
                .offset(x: -21 * u, y: -14 * u)
            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .foregroundStyle(.questAmber)
                .frame(width: 8 * u, height: 9 * u)
                .rotationEffect(.degrees(38))
                .offset(x: 21 * u, y: -14 * u)
            dome(fill: .questAmber, deep: .questAmberDeep)
        case "head.starhat":
            wizardHat
        case "head.hood":
            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .foregroundStyle(charcoal)
                .frame(width: 13 * u, height: 15 * u)
                .offset(y: -26 * u)
        default:
            Circle()
                .fill(charcoal)
                .frame(width: 40 * u, height: 40 * u)
                .mask(alignment: .top) { Rectangle().frame(width: 40 * u, height: 17 * u) }
                .offset(y: -3 * u)
        }
    }

    private var ironDome: some View {
        dome(fill: steel, deep: steelDeep)
    }

    private func dome(fill: Color, deep: Color) -> some View {
        Circle()
            .fill(
                LinearGradient(colors: [fill.lighter(0.18), deep], startPoint: .top, endPoint: .bottom)
            )
            .frame(width: 42 * u, height: 42 * u)
            .mask(alignment: .top) { Rectangle().frame(width: 42 * u, height: 19 * u) }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(deep)
                    .frame(width: 42 * u, height: 2.5 * u)
                    .offset(y: 18 * u)
            }
            .offset(y: -2 * u)
    }

    private var wizardHat: some View {
        ZStack {
            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .foregroundStyle(
                    LinearGradient(colors: [.xpViolet, .videoSapphire], startPoint: .bottom, endPoint: .top)
                )
                .frame(width: 26 * u, height: 25 * u)
                .offset(y: -2 * u)
            Image(systemName: "sparkle")
                .font(.system(size: 9 * u, weight: .bold))
                .foregroundStyle(.questAmber)
                .offset(x: 5 * u, y: -8 * u)
            Ellipse()
                .fill(Color(red: 0.42, green: 0.28, blue: 0.72))
                .frame(width: 36 * u, height: 8 * u)
                .offset(y: 10 * u)
        }
        .offset(y: -12 * u)
    }

    private var hoodBack: some View {
        Circle()
            .fill(charcoal)
            .frame(width: 49 * u, height: 49 * u)
            .offset(y: -2 * u)
    }

    // MARK: Weapon

    @ViewBuilder private var weaponLayer: some View {
        if let weapon = item(.weapon) {
            ZStack {
                weaponModel(id: weapon.id)
                Circle()
                    .fill(skinTone)
                    .frame(width: 7.5 * u, height: 7.5 * u)
                    .offset(y: 14 * u)
            }
            .offset(x: 37 * u, y: 5 * u)
            .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder private func weaponModel(id: String) -> some View {
        switch id {
        case "weapon.staff":
            VStack(spacing: 1.5 * u) {
                Circle()
                    .fill(
                        RadialGradient(colors: [.xpViolet, .dungeonVoid], center: .center, startRadius: 0, endRadius: 7 * u)
                    )
                    .frame(width: 12 * u, height: 12 * u)
                    .shadow(color: .xpViolet.opacity(0.7), radius: 4 * u)
                Capsule().fill(wood).frame(width: 3.5 * u, height: 42 * u)
            }
        case "weapon.gem":
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3 * u, style: .continuous)
                    .fill(LinearGradient(colors: [.questAmber, .questAmberDeep], startPoint: .top, endPoint: .bottom))
                    .frame(width: 17 * u, height: 10 * u)
                Capsule().fill(wood).frame(width: 4 * u, height: 30 * u)
            }
        case "weapon.reel":
            ZStack {
                RoundedRectangle(cornerRadius: 2 * u, style: .continuous)
                    .fill(LinearGradient(colors: [steel.lighter(0.2), steelDeep], startPoint: .top, endPoint: .bottom))
                    .frame(width: 5 * u, height: 44 * u)
                Circle()
                    .fill(.videoSapphire)
                    .frame(width: 13 * u, height: 13 * u)
                    .overlay(Circle().fill(Color.dungeonVoid).frame(width: 5 * u, height: 5 * u))
                    .offset(y: -9 * u)
            }
        case "weapon.stormblade":
            Image(systemName: "bolt.fill")
                .resizable()
                .foregroundStyle(
                    LinearGradient(colors: [.videoSapphire, .textPrimary], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 13 * u, height: 42 * u)
                .shadow(color: .videoSapphire.opacity(0.8), radius: 4 * u)
        default:
            ZStack {
                Rectangle()
                    .fill(.videoSapphire)
                    .frame(width: 11 * u, height: 11 * u)
                    .rotationEffect(.degrees(45))
                    .scaleEffect(y: 1.55)
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 4 * u, height: 4 * u)
                    .rotationEffect(.degrees(45))
                    .scaleEffect(y: 1.55)
                    .offset(x: -2 * u, y: -3 * u)
            }
        }
    }

    // MARK: Pet

    @ViewBuilder private var petLayer: some View {
        if item(.pet) != nil {
            ZStack {
                Image(systemName: "arrowtriangle.up.fill")
                    .resizable()
                    .foregroundStyle(petColor)
                    .frame(width: 6 * u, height: 7 * u)
                    .offset(x: -4.5 * u, y: -9 * u)
                Image(systemName: "arrowtriangle.up.fill")
                    .resizable()
                    .foregroundStyle(petColor)
                    .frame(width: 6 * u, height: 7 * u)
                    .offset(x: 4.5 * u, y: -9 * u)
                Circle()
                    .fill(
                        LinearGradient(colors: [petColor.lighter(0.2), petColor], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 15 * u, height: 15 * u)
                Circle().fill(Color.dungeonVoid).frame(width: 2.6 * u, height: 2.6 * u).offset(x: -3.2 * u, y: -1 * u)
                Circle().fill(Color.dungeonVoid).frame(width: 2.6 * u, height: 2.6 * u).offset(x: 3.2 * u, y: -1 * u)
            }
            .offset(x: -45 * u, y: 46 * u)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }
}

// MARK: - Helpers

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
