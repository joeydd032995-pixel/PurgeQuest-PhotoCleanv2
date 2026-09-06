//
//  MiniAvatarView.swift
//  PurgeQuest
//
//  Painted-sprite renderer for the hero mini figure. Every surface is drawn
//  through a shared material pipeline: a top-left key light with stepped
//  base gradients, a soft lower-right fill light, warm ground bounce on
//  lower surfaces, a wrapping rim highlight, a core shadow on the dark edge,
//  and thin contour lines. Metals add a brushed polish; leather adds grain;
//  gems use radial catchlights with internal refraction. Ambient occlusion
//  bands sit under the helmet overhang, pauldrons, and collar; the ground
//  uses a tight radial contact shadow. Gear (skin, head, armor, weapon,
//  shield, pet, effect) recolors and re-equips the figure live.
//

import SwiftUI

struct MiniAvatarView: View {
    let hero: Hero
    let equipped: [CosmeticItem]
    /// Size of the orb the figure is drawn for; the figure scales proportionally.
    var size: CGFloat = 210
    /// Set to false for static previews (armory tiles) that skip gear transitions.
    var isAnimated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Base design unit so every dimension scales with the orb size.
    private var u: CGFloat { size / 200 }

    private var isKnight: Bool { hero.archetype == .knight }

    private func item(_ type: CosmeticType) -> CosmeticItem? {
        equipped.first { $0.type == type }
    }

    // MARK: - Palette

    private var accent: Color { isKnight ? .questAmber : .xpViolet }
    private var skinTone: Color { Color(red: 0.95, green: 0.82, blue: 0.58) }
    private var steel: Color { Color(red: 0.78, green: 0.85, blue: 0.81) }
    private var steelDeep: Color { Color(red: 0.47, green: 0.56, blue: 0.51) }
    private var helmetDark: Color { Color(red: 0.28, green: 0.33, blue: 0.30) }
    private var charcoal: Color { Color(red: 0.21, green: 0.26, blue: 0.23) }
    private var leather: Color { Color(red: 0.42, green: 0.26, blue: 0.15) }
    private var bootColor: Color { Color(red: 0.16, green: 0.22, blue: 0.19) }
    private var mittColor: Color { Color(red: 0.30, green: 0.36, blue: 0.32) }
    private var wood: Color { Color(red: 0.55, green: 0.38, blue: 0.22) }
    private var outline: Color { Color(red: 0.06, green: 0.09, blue: 0.08) }
    /// Warm ground-bounce light used on lower surfaces.
    private var bounceWarm: Color { Color(red: 1.0, green: 0.86, blue: 0.64) }

    /// Tunic color driven by the equipped skin; falls back to the archetype standard.
    private var tunicColor: Color {
        switch item(.skin)?.id {
        case "skin.iron": return steelDeep
        case "skin.embers": return Color(red: 0.72, green: 0.20, blue: 0.22)
        case "skin.archivist": return Color(red: 0.40, green: 0.31, blue: 0.22)
        case "skin.warden": return Color(red: 0.24, green: 0.30, blue: 0.26)
        case "skin.wraithcloak": return Color(red: 0.16, green: 0.19, blue: 0.18)
        case "skin.sandblade": return Color(red: 0.78, green: 0.66, blue: 0.45)
        default: return isKnight ? Color(red: 0.33, green: 0.37, blue: 0.34) : Color(red: 0.22, green: 0.44, blue: 0.41)
        }
    }

    private var petColor: Color {
        switch item(.pet)?.id {
        case "pet.reel": return .videoSapphire
        case "pet.owl": return Color(red: 0.62, green: 0.46, blue: 0.28)
        case "pet.beachSpirit": return Color(red: 0.45, green: 0.70, blue: 0.78)
        default: return .gemEmerald
        }
    }

    private var isRobed: Bool {
        item(.armor)?.id == "armor.arcanist" || item(.skin)?.id == "skin.archivist"
    }

    private var isWraith: Bool { item(.skin)?.id == "skin.wraithcloak" }

    // MARK: - Material pipeline

    /// The core renderer: a stepped gradient base fill, a fill light from the
    /// lower-right so dark flanks never flatten, a warm ground bounce on lower
    /// surfaces, a wrapping rim highlight, a core shadow on the dark edge, and
    /// the contour line. Metals add a brushed polish; leather adds grain.
    private func lit<S: Shape>(
        _ shape: S,
        _ base: Color,
        lineWidth: CGFloat = 1.8,
        metal: Bool = false,
        grain: Bool = false
    ) -> some View {
        let fill = metal
            ? LinearGradient(
                stops: [
                    .init(color: base.lighter(0.62), location: 0),
                    .init(color: base.lighter(0.34), location: 0.16),
                    .init(color: base.lighter(0.12), location: 0.36),
                    .init(color: base, location: 0.56),
                    .init(color: base.darker(0.24), location: 0.78),
                    .init(color: base.darker(0.46), location: 1)
                ],
                startPoint: UnitPoint(x: 0.22, y: 0.04),
                endPoint: UnitPoint(x: 0.74, y: 0.96)
            )
            : LinearGradient(
                stops: [
                    .init(color: base.lighter(0.30), location: 0),
                    .init(color: base.lighter(0.12), location: 0.26),
                    .init(color: base, location: 0.54),
                    .init(color: base.darker(0.14), location: 0.80),
                    .init(color: base.darker(0.28), location: 1)
                ],
                startPoint: UnitPoint(x: 0.22, y: 0.04),
                endPoint: UnitPoint(x: 0.78, y: 0.96)
            )
        let fillLight = LinearGradient(
            stops: [
                .init(color: .white.opacity(0.0), location: 0),
                .init(color: .white.opacity(0.09), location: 0.68),
                .init(color: .white.opacity(0.15), location: 1)
            ],
            startPoint: UnitPoint(x: 0.30, y: 0.15),
            endPoint: UnitPoint(x: 0.85, y: 0.95)
        )
        let bounce = LinearGradient(
            stops: [
                .init(color: bounceWarm.opacity(0.0), location: 0),
                .init(color: bounceWarm.opacity(0.10), location: 0.82),
                .init(color: bounceWarm.opacity(0.20), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        let polish = LinearGradient(
            stops: [
                .init(color: .white.opacity(0.05), location: 0.10),
                .init(color: .black.opacity(0.03), location: 0.20),
                .init(color: .white.opacity(0.045), location: 0.30),
                .init(color: .black.opacity(0.03), location: 0.40),
                .init(color: .white.opacity(0.04), location: 0.52),
                .init(color: .black.opacity(0.03), location: 0.62),
                .init(color: .white.opacity(0.035), location: 0.74),
                .init(color: .black.opacity(0.03), location: 0.86),
                .init(color: .white.opacity(0.03), location: 0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        let weave = LinearGradient(
            stops: [
                .init(color: .white.opacity(0.05), location: 0.15),
                .init(color: .black.opacity(0.05), location: 0.32),
                .init(color: .white.opacity(0.04), location: 0.48),
                .init(color: .black.opacity(0.05), location: 0.64),
                .init(color: .white.opacity(0.04), location: 0.80),
                .init(color: .black.opacity(0.09), location: 0.97)
            ],
            startPoint: UnitPoint(x: 0.2, y: 0.2),
            endPoint: UnitPoint(x: 0.8, y: 0.8)
        )
        let rim = LinearGradient(
            stops: [
                .init(color: .white.opacity(0.80), location: 0),
                .init(color: .white.opacity(0.40), location: 0.30),
                .init(color: .white.opacity(0.0), location: 0.56)
            ],
            startPoint: .topLeading,
            endPoint: UnitPoint(x: 0.64, y: 0.60)
        )
        let coreShadow = LinearGradient(
            stops: [
                .init(color: .black.opacity(0.0), location: 0.36),
                .init(color: .black.opacity(0.22), location: 0.70),
                .init(color: .black.opacity(0.42), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        return shape
            .fill(fill)
            .overlay(shape.fill(fillLight).allowsHitTesting(false))
            .overlay(shape.fill(bounce).allowsHitTesting(false))
            .overlay(shape.fill(polish).opacity(metal ? 1 : 0).allowsHitTesting(false))
            .overlay(shape.fill(weave).opacity(grain ? 1 : 0).allowsHitTesting(false))
            .overlay(shape.stroke(rim, lineWidth: 1.6 * u).allowsHitTesting(false))
            .overlay(
                shape.stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.9), location: 0),
                            .init(color: .white.opacity(0.0), location: 0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.45, y: 0.45)
                    ),
                    lineWidth: 0.8 * u
                )
                .allowsHitTesting(false)
            )
            .overlay(shape.stroke(coreShadow, lineWidth: 1.6 * u).allowsHitTesting(false))
            .overlay(shape.stroke(outline, lineWidth: lineWidth * u))
    }

    /// Spherical material for orbs, gems, and domes: a stepped radial body
    /// light offset toward the key, a secondary internal refraction plane,
    /// a subtle chromatic edge, and a crisp catchlight with a satellite glint.
    private func orb<S: Shape>(_ shape: S, _ base: Color, radius: CGFloat, lineWidth: CGFloat = 1.8) -> some View {
        let body = RadialGradient(
            colors: [
                base.lighter(0.62),
                base.lighter(0.30),
                base,
                base.darker(0.20),
                base.darker(0.48)
            ],
            center: UnitPoint(x: 0.34, y: 0.28),
            startRadius: 0,
            endRadius: radius * u
        )
        let chroma = LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.94, blue: 0.80).opacity(0.5),
                Color(red: 0.72, green: 0.86, blue: 1.0).opacity(0.42)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let glint = max(1.2, radius * 0.24)
        return shape
            .fill(body)
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [Color(white: 1.0).opacity(0.0), Color(white: 1.0).opacity(0.14)],
                        startPoint: UnitPoint(x: 0.4, y: 0.3),
                        endPoint: UnitPoint(x: 0.9, y: 0.95)
                    )
                )
                .allowsHitTesting(false)
            )
            .overlay(shape.stroke(chroma, lineWidth: 0.9 * u).allowsHitTesting(false))
            .overlay(shape.stroke(outline, lineWidth: lineWidth * u))
            .overlay(
                ZStack {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.95), .white.opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: glint * u
                            )
                        )
                        .frame(width: glint * 2.4 * u, height: glint * 1.7 * u)
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: glint * 0.5 * u, height: glint * 0.5 * u)
                        .offset(x: glint * 1.3 * u, y: glint * 0.9 * u)
                }
                .offset(x: -radius * 0.26 * u, y: -radius * 0.3 * u)
                .allowsHitTesting(false)
            )
    }

    /// A two-lobe specular streak: a broad soft wash under a narrow bright
    /// core, used on metal surfaces.
    private func sheen(width: CGFloat, height: CGFloat, at point: CGPoint, angle: Double = 36, opacity: Double = 0.45) -> some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(opacity * 0.4), .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width * 1.6 * u, height: height * 1.9 * u)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(opacity), .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width * u, height: height * u)
        }
        .rotationEffect(.degrees(angle))
        .offset(x: point.x * u, y: point.y * u)
    }

    /// Soft ambient-occlusion wash fading downward from an overhang. Fill a
    /// shape with it, or frame and clip it to the receiving surface.
    private func aoWash(height: CGFloat, strength: Double = 0.30) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(strength), location: 0),
                .init(color: .black.opacity(strength * 0.45), location: 0.5),
                .init(color: .black.opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A small soft dark ellipse cast onto the surface beneath an overhang.
    private func castShadow(width: CGFloat, height: CGFloat, at point: CGPoint, opacity: Double = 0.25) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [.black.opacity(opacity), .black.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(width, height) * u / 2
                )
            )
            .frame(width: width * u, height: height * u)
            .offset(x: point.x * u, y: point.y * u)
            .allowsHitTesting(false)
    }

    /// A soft warm patch faking subsurface scattering on skin.
    private func subsurfaceGlow(at point: CGPoint, small: Bool = false) -> some View {
        let w: CGFloat = small ? 7 : 11
        let h: CGFloat = small ? 4 : 5.5
        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [skinTone.lighter(0.30).opacity(0.45), skinTone.lighter(0.30).opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: w * u / 2
                )
            )
            .frame(width: w * u, height: h * u)
            .offset(x: point.x * u, y: point.y * u)
            .allowsHitTesting(false)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            groundShadow
            figure
        }
        .frame(width: 118 * u, height: 140 * u)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// Radial contact shadow: dense and tight at the feet, feathering out.
    private var groundShadow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [.black.opacity(0.55), .black.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 30 * u
                )
            )
            .frame(width: 56 * u, height: 12 * u)
            .offset(y: 57.5 * u)
    }

    private var accessibilitySummary: String {
        let worn = CosmeticType.allCases.compactMap { slot -> String? in
            item(slot)?.name
        }
        if worn.isEmpty { return "Hero figure, default gear" }
        return "Hero figure wearing \(worn.joined(separator: ", "))"
    }

    // MARK: - Figure

    private var figure: some View {
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
                ? .spring(response: 0.4, dampingFraction: 0.75)
                : nil,
            value: equipped.map(\.id)
        )
    }

    // MARK: Legs — shaded limbs, greaves, and dome boots with toe caps

    private var legs: some View {
        ZStack {
            leg(x: -7)
            leg(x: 7)
            boot(x: -8)
            boot(x: 8)
        }
    }

    private func leg(x: CGFloat) -> some View {
        lit(Capsule(), charcoal.darker(0.1), lineWidth: 1.1)
            .frame(width: 5 * u, height: 11 * u)
            .offset(x: x * u, y: 39 * u)
    }

    private func boot(x: CGFloat) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 6.5 * u,
            bottomLeadingRadius: 2 * u,
            bottomTrailingRadius: 2 * u,
            topTrailingRadius: 6.5 * u,
            style: .continuous
        )
        return ZStack {
            lit(shape, bootColor, lineWidth: 2.0)
            // Ankle occlusion where the boot meets the greave.
            Rectangle()
                .fill(aoWash(height: 2.6, strength: 0.28))
                .frame(width: 13 * u, height: 2.6 * u)
                .offset(y: -2.6 * u)
            // Toe cap: a light kiss on the front edge where the key light lands.
            Ellipse()
                .fill(Color.white.opacity(0.22))
                .frame(width: 6 * u, height: 3.2 * u)
                .offset(x: x < 0 ? -3.8 * u : 3.8 * u, y: -2 * u)
            // Sole line grounds the boot.
            Rectangle()
                .fill(outline.opacity(0.85))
                .frame(width: 13.5 * u, height: 1.2 * u)
                .offset(y: 3.8 * u)
        }
        .frame(width: 15.5 * u, height: 10 * u)
        .offset(x: x * u, y: 47 * u)
    }

    // MARK: Torso — cloth tunic with folds, collar dome, belt and buckle

    private var torso: some View {
        ZStack {
            lit(TaperedShape(topWidth: 0.78, bottomWidth: 1), tunicColor, lineWidth: 2.4)
                .frame(width: 30 * u, height: 24 * u)
                .overlay(
                    // Fabric folds: two quiet vertical shades, clipped to the tunic.
                    TaperedShape(topWidth: 0.78, bottomWidth: 1)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.0), location: 0),
                                    .init(color: .black.opacity(0.16), location: 0.55),
                                    .init(color: .black.opacity(0.0), location: 0.7),
                                    .init(color: .black.opacity(0.2), location: 0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .allowsHitTesting(false)
                )
                .overlay(
                    TaperedShape(topWidth: 0.78, bottomWidth: 1)
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.black.opacity(0.32), .black.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: UnitPoint(x: 0.5, y: 0.42)
                                    )
                                )
                                .frame(height: 10 * u)
                                .frame(maxHeight: .infinity, alignment: .top)
                        )
                        .allowsHitTesting(false)
                )
                .overlay(
                    // Lit ridges between the fold shades.
                    HStack(spacing: 9 * u) {
                        Capsule().fill(Color.white.opacity(0.10)).frame(width: 1.2 * u, height: 15 * u)
                        Capsule().fill(Color.white.opacity(0.10)).frame(width: 1.2 * u, height: 15 * u)
                    }
                    .offset(x: 1.5 * u, y: 2 * u)
                    .clipShape(TaperedShape(topWidth: 0.78, bottomWidth: 1))
                    .allowsHitTesting(false)
                )

            skinTrim
            armorLayer
            belt

            // Collar dome: metal-ringed accent half-disc on the tunic's top edge.
            orb(Circle(), accent, radius: 9, lineWidth: 2.0)
                .frame(width: 17 * u, height: 17 * u)
                .offset(y: -8 * u)
            sheen(width: 8, height: 2.4, at: CGPoint(x: -2, y: -12), angle: -20, opacity: 0.6)
            NotchShape()
                .fill(outline)
                .frame(width: 5 * u, height: 3.5 * u)
                .offset(y: -12.5 * u)
        }
        .offset(y: 21 * u)
    }

    /// Slot-specific cloth details drawn on the tunic before armor.
    @ViewBuilder private var skinTrim: some View {
        if item(.skin)?.id == "skin.embers" {
            // Heat-tempered hem band along the tunic's lower edge.
            TaperedShape(topWidth: 0.9, bottomWidth: 1)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .combatCrimson.lighter(0.18), location: 0),
                            .init(color: .combatCrimson, location: 0.45),
                            .init(color: .combatCrimson.darker(0.28), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 28.5 * u, height: 5 * u)
                .overlay(
                    // Heat-scale stitching ticks along the band.
                    HStack(spacing: 3 * u) {
                        ForEach(0..<6, id: \.self) { _ in
                            Rectangle()
                                .fill(outline.opacity(0.35))
                                .frame(width: 0.8 * u, height: 3.2 * u)
                        }
                    }
                    .offset(y: -0.6 * u)
                    .clipShape(TaperedShape(topWidth: 0.9, bottomWidth: 1))
                    .allowsHitTesting(false)
                )
                .offset(y: 9.5 * u)
        }
        if item(.skin)?.id == "skin.sandblade" {
            // Sun-bleached sash crossing the torso, clipped to the tunic.
            Color.clear
                .frame(width: 30 * u, height: 24 * u)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.95, green: 0.89, blue: 0.75), location: 0),
                                    .init(color: Color(red: 0.88, green: 0.80, blue: 0.63), location: 0.55),
                                    .init(color: Color(red: 0.78, green: 0.69, blue: 0.50), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 5 * u, height: 32 * u)
                        .overlay(
                            // Edge darkening along the sash's trailing side.
                            Rectangle()
                                .fill(Color.black.opacity(0.18))
                                .frame(width: 0.8 * u)
                                .frame(maxHeight: .infinity, alignment: .trailing)
                        )
                        .overlay(
                            // A lit ridge along its leading side.
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 0.8 * u)
                                .frame(maxHeight: .infinity, alignment: .leading)
                        )
                        .rotationEffect(.degrees(28))
                )
                .clipShape(TaperedShape(topWidth: 0.78, bottomWidth: 1))
        }
        if item(.skin)?.id == "skin.warden" {
            // Vault plate: horizontal reinforcing ribs across the chest.
            VStack(spacing: 3 * u) {
                capsuleRib
                capsuleRib
                capsuleRib
            }
            .offset(y: -2 * u)
        }
    }

    private var capsuleRib: some View {
        let highlight = Color.white.opacity(0.14)
        let shade = Color.black.opacity(0.20)
        let ribWidth = 20 * u
        return ZStack {
            // Occlusion above each rib where the plate catches the chest.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.black.opacity(0.18), .black.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: ribWidth, height: 2.2 * u)
                .offset(y: -1.8 * u)
            Capsule()
                .fill(highlight)
                .frame(width: ribWidth, height: 1.6 * u)
            Capsule()
                .fill(shade)
                .frame(width: ribWidth, height: 1.2 * u)
                .offset(y: 0.8 * u)
        }
    }

    /// Gold chest plate worn over the tunic in the knight's default kit:
    /// brushed treasure-gold metal with a center ridge, specular sweep, and
    /// anchoring rivets.
    private var goldChestPlate: some View {
        let plate = RoundedRectangle(cornerRadius: 5 * u, style: .continuous)
        return ZStack {
            // Occlusion where the collar dome overhangs the plate.
            castShadow(width: 20, height: 5, at: CGPoint(x: 0, y: -5), opacity: 0.3)
            lit(plate, .questAmber, lineWidth: 2.0, metal: true)
                .frame(width: 21 * u, height: 13.5 * u)
                .overlay(
                    // Center ridge with a lit lip and shaded flank.
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.30))
                            .frame(width: 1.2 * u, height: 7 * u)
                        Rectangle()
                            .fill(Color.black.opacity(0.16))
                            .frame(width: 2.2 * u, height: 2 * u)
                    }
                    .offset(y: -1 * u)
                    .allowsHitTesting(false)
                )
                .overlay(
                    sheen(width: 12, height: 3, at: CGPoint(x: -2, y: -3.6), angle: -14, opacity: 0.55)
                        .clipShape(plate)
                )
                .overlay(
                    // Bottom edge darkening where the plate meets the tunic.
                    Rectangle()
                        .fill(Color.black.opacity(0.22))
                        .frame(height: 1.6 * u)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .clipShape(plate)
                        .allowsHitTesting(false)
                )
            // Rivets anchoring the plate to the leather underlayer.
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 3 * u, height: 3 * u)
                        .offset(y: 0.3 * u)
                    Circle()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: Color.questAmber.lighter(0.55), location: 0),
                                    .init(color: Color.questAmber, location: 0.55),
                                    .init(color: Color.questAmber.darker(0.38), location: 1)
                                ],
                                center: UnitPoint(x: 0.35, y: 0.3),
                                startRadius: 0,
                                endRadius: 1.6 * u
                            )
                        )
                        .frame(width: 2.2 * u, height: 2.2 * u)
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 0.7 * u, height: 0.7 * u)
                        .offset(x: -0.3 * u, y: -0.4 * u)
                }
                .offset(x: side * 8 * u, y: -2.5 * u)
            }
        }
        .offset(y: -1.5 * u)
    }

    @ViewBuilder private var armorLayer: some View {
        switch item(.armor)?.id {
        case "armor.iron":
            ironPauldron(x: -14.5)
            ironPauldron(x: 14.5)
        case "armor.dragonhide":
            scalePauldron(x: -14.5, mirrored: false)
            scalePauldron(x: 14.5, mirrored: true)
        case "armor.arcanist":
            arcanistTrim
        default:
            if isKnight {
                goldChestPlate
            }
            castShadow(width: 11, height: 5, at: CGPoint(x: -15, y: -5), opacity: 0.22)
            castShadow(width: 11, height: 5, at: CGPoint(x: 15, y: -5), opacity: 0.22)
            lit(Ellipse(), mittColor, lineWidth: 2.0)
                .frame(width: 12 * u, height: 10 * u)
                .overlay(
                    Circle().fill(outline).frame(width: 2.4 * u, height: 2.4 * u).offset(y: 3 * u)
                )
                .offset(x: -15.5 * u, y: -9.5 * u)
            lit(Ellipse(), mittColor, lineWidth: 2.0)
                .frame(width: 12 * u, height: 10 * u)
                .overlay(
                    Circle().fill(outline).frame(width: 2.4 * u, height: 2.4 * u).offset(y: 3 * u)
                )
                .offset(x: 15.5 * u, y: -9.5 * u)
        }
    }

    /// Purge Plate pauldron: two stacked steel plates with a riveted lower rim.
    private func ironPauldron(x: CGFloat) -> some View {
        ZStack {
            castShadow(width: 13, height: 5, at: CGPoint(x: 0, y: 6.5), opacity: 0.3)
            lit(Ellipse(), steelDeep, lineWidth: 2.0, metal: true)
                .frame(width: 12.5 * u, height: 10.5 * u)
            lit(Ellipse(), steel, lineWidth: 1.4, metal: true)
                .frame(width: 9 * u, height: 7 * u)
                .offset(x: x < 0 ? -1 * u : 1 * u, y: -2 * u)
            Circle()
                .fill(Color.black.opacity(0.24))
                .frame(width: 3.4 * u, height: 3.4 * u)
                .offset(y: 3.6 * u)
            Circle()
                .fill(outline)
                .frame(width: 2.2 * u, height: 2.2 * u)
                .offset(y: 3.4 * u)
            Circle()
                .fill(steel)
                .frame(width: 1 * u, height: 1 * u)
                .offset(x: -0.4 * u, y: 3 * u)
        }
        .offset(x: x * u, y: -9.5 * u)
    }

    /// Dragonhide pauldron: three overlapping scales descending outward.
    private func scalePauldron(x: CGFloat, mirrored: Bool) -> some View {
        let dir: CGFloat = mirrored ? 1 : -1
        return ZStack {
            scale(size: 12, at: CGPoint(x: 0, y: 0))
            scale(size: 10, at: CGPoint(x: dir * 3.2, y: 3.2))
            scale(size: 8, at: CGPoint(x: dir * 5.8, y: 6))
        }
        .offset(x: x * u, y: -9.5 * u)
    }

    private func scale(size: CGFloat, at point: CGPoint) -> some View {
        let tint: Color = Color.gemEmerald.darker(0.12)
        let plateWidth = size * u
        let plateHeight = size * 0.72 * u
        let shineWidth = size * 0.62 * u
        let shineHeight = size * 0.4 * u
        return ZStack {
            // Layering shadow: each scale casts onto the one below it.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.black.opacity(0.28), .black.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: plateWidth / 2
                    )
                )
                .frame(width: plateWidth * 1.1, height: plateHeight * 0.7)
                .offset(y: plateHeight * 0.5)
            lit(Ellipse(), tint, lineWidth: 1.4)
                .frame(width: plateWidth, height: plateHeight)
                .overlay(
                    Ellipse()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.9 * u)
                        .frame(width: shineWidth, height: shineHeight)
                        .offset(y: -size * 0.1 * u)
                )
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: size * 0.12 * u, height: size * 0.12 * u)
                        .offset(x: -size * 0.18 * u, y: -size * 0.16 * u)
                )
        }
        .offset(x: point.x * u, y: point.y * u)
    }

    /// Arcanist trim: jade edging down the robe plus a rune emblem.
    private var arcanistTrim: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.xpViolet.lighter(0.3), .xpViolet.darker(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2.2 * u, height: 18 * u)
                .offset(x: -10 * u, y: 4 * u)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.xpViolet.lighter(0.3), .xpViolet.darker(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2.2 * u, height: 18 * u)
                .offset(x: 10 * u, y: 4 * u)
            // Rune emblem: faceted diamond with a bright core.
            DiamondShape()
                .fill(
                    RadialGradient(
                        colors: [.xpViolet.lighter(0.55), .xpViolet, .xpViolet.darker(0.4)],
                        center: UnitPoint(x: 0.4, y: 0.32),
                        startRadius: 0,
                        endRadius: 7 * u
                    )
                )
                .overlay(DiamondShape().stroke(outline, lineWidth: 1.3 * u))
                .frame(width: 8 * u, height: 8 * u)
                .offset(y: 5 * u)
            DiamondShape()
                .fill(Color.white.opacity(0.20))
                .frame(width: 3.2 * u, height: 3.2 * u)
                .offset(x: -0.9 * u, y: 4.4 * u)
            DiamondShape()
                .fill(Color.white.opacity(0.75))
                .frame(width: 2.2 * u, height: 2.2 * u)
                .offset(x: -0.8 * u, y: 4.2 * u)
        }
    }

    private var belt: some View {
        ZStack {
            lit(Rectangle(), leather, lineWidth: 1.5, grain: true)
                .frame(width: 30 * u, height: 6 * u)
                .overlay(
                    // Stitch line along the belt's top edge.
                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 26 * u, height: 0.9 * u)
                        .offset(y: -1.9 * u)
                )
                .overlay(
                    // Edge darkening grounds the strap.
                    Rectangle()
                        .fill(Color.black.opacity(0.24))
                        .frame(height: 1.1 * u)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                )
                .offset(y: 8 * u)
            lit(Capsule(), .questAmber, lineWidth: 1.6, metal: true)
                .frame(width: 9 * u, height: 6 * u)
                .overlay(
                    Rectangle()
                        .fill(outline.opacity(0.8))
                        .frame(width: 0.9 * u, height: 3.6 * u)
                )
                .offset(y: 8 * u)
        }
    }

    // MARK: Cloak (behind body) — robes, archivist cloth, wraith cape

    @ViewBuilder private var cloakBack: some View {
        if isRobed {
            TaperedShape(topWidth: 0.55, bottomWidth: 1)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: robeColor.lighter(0.28), location: 0),
                            .init(color: robeColor, location: 0.45),
                            .init(color: robeColor.darker(0.12), location: 0.75),
                            .init(color: robeColor.darker(0.34), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottom
                    )
                )
                .overlay(TaperedShape(topWidth: 0.55, bottomWidth: 1).stroke(outline, lineWidth: 2.2 * u))
                .overlay(
                    TaperedShape(topWidth: 0.55, bottomWidth: 1)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.4), location: 0),
                                    .init(color: .white.opacity(0.0), location: 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            ),
                            lineWidth: 1 * u
                        )
                )
                .overlay(
                    // Quiet vertical cloth folds down the robe.
                    TaperedShape(topWidth: 0.55, bottomWidth: 1)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.0), location: 0.1),
                                    .init(color: .black.opacity(0.14), location: 0.3),
                                    .init(color: .black.opacity(0.0), location: 0.45),
                                    .init(color: .black.opacity(0.10), location: 0.68),
                                    .init(color: .black.opacity(0.0), location: 0.82)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .allowsHitTesting(false)
                )
                .overlay(
                    // Hem occlusion along the robe's bottom edge.
                    TaperedShape(topWidth: 0.55, bottomWidth: 1)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.0), location: 0),
                                    .init(color: .black.opacity(0.22), location: 1)
                                ],
                                startPoint: UnitPoint(x: 0.5, y: 0.72),
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                )
                .frame(width: 44 * u, height: 40 * u)
                .offset(y: 24 * u)
        } else if isWraith {
            TaperedShape(topWidth: 0.62, bottomWidth: 1.12)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.15, green: 0.18, blue: 0.17), location: 0),
                            .init(color: Color(red: 0.12, green: 0.15, blue: 0.14), location: 0.45),
                            .init(color: Color(red: 0.08, green: 0.10, blue: 0.09), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(TaperedShape(topWidth: 0.62, bottomWidth: 1.12).stroke(outline, lineWidth: 2.2 * u))
                .overlay(
                    // Lit edge catching the key light on the cloak's shoulder.
                    TaperedShape(topWidth: 0.62, bottomWidth: 1.12)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.35), location: 0),
                                    .init(color: .white.opacity(0.0), location: 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            ),
                            lineWidth: 1 * u
                        )
                )
                .overlay(
                    // Ash weave: faint horizontal threads.
                    TaperedShape(topWidth: 0.62, bottomWidth: 1.12)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.0), location: 0),
                                    .init(color: .white.opacity(0.09), location: 0.4),
                                    .init(color: .white.opacity(0.0), location: 0.55),
                                    .init(color: .white.opacity(0.07), location: 0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    // Hanging folds under the shoulders.
                    TaperedShape(topWidth: 0.62, bottomWidth: 1.12)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.0), location: 0.08),
                                    .init(color: .black.opacity(0.30), location: 0.30),
                                    .init(color: .black.opacity(0.0), location: 0.48),
                                    .init(color: .black.opacity(0.22), location: 0.72),
                                    .init(color: .black.opacity(0.0), location: 0.88)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .allowsHitTesting(false)
                )
                .frame(width: 48 * u, height: 42 * u)
                .offset(y: 26 * u)
        }
    }

    private var robeColor: Color {
        item(.armor)?.id == "armor.arcanist"
            ? Color(red: 0.20, green: 0.42, blue: 0.40)
            : Color(red: 0.33, green: 0.25, blue: 0.17)
    }

    // MARK: Arms — sleeves with cloth shading, gauntlet mitts

    private var leftArm: some View { arm(side: -1) }

    /// Drawn before the weapon layer so the blade overlays the front of the mitt.
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
            lit(Capsule(), tunicColor.darker(0.12), lineWidth: 1.1)
                .frame(width: 5 * u, height: 14 * u)
                .overlay(
                    // Elbow fold catching a soft shade mid-sleeve.
                    Capsule()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 4.2 * u, height: 1.1 * u)
                        .offset(y: 3.4 * u)
                )
                .rotationEffect(.degrees(side * 30))
                .offset(x: side * 3.5 * u, y: 3 * u)

            ZStack {
                castShadow(width: 8, height: 4, at: CGPoint(x: side * -1.2, y: -5.4), opacity: 0.24)
                orb(Circle(), mittColor, radius: 6, lineWidth: 2.0)
                // Knuckle crease on the lit side.
                Capsule()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 4.4 * u, height: 1.1 * u)
                    .offset(x: side * -1.2 * u, y: 2.2 * u)
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 1.6 * u, height: 1.6 * u)
                    .offset(x: side * 1.6 * u, y: -1.6 * u)
            }
            .frame(width: 10.5 * u, height: 10.5 * u)
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

    /// Eyes: deep-set dark ovals with a primary catchlight and a faint
    /// secondary glint, reading as glass under the key light.
    private var eyes: some View {
        ZStack {
            eye(x: -9.5)
            eye(x: 9.5)
        }
    }

    private func eye(x: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.14, green: 0.18, blue: 0.16), outline],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: 5.6 * u
                    )
                )
                .frame(width: 9.4 * u, height: 9.8 * u)
            // Lower-lid reflected light keeps the eye reading as glass.
            Ellipse()
                .fill(Color.white.opacity(0.16))
                .frame(width: 6 * u, height: 2.2 * u)
                .offset(y: 3.1 * u)
            Circle()
                .fill(Color.white)
                .frame(width: 2.9 * u, height: 2.9 * u)
                .offset(x: 1.6 * u, y: -2 * u)
            Circle()
                .fill(Color.white.opacity(0.42))
                .frame(width: 1.4 * u, height: 1.4 * u)
                .offset(x: -1.9 * u, y: 2 * u)
        }
        .offset(x: x * u)
    }

    /// Face under the helmet: warm skin with a radial light, cheek blush,
    /// and a shadow band where the dome overhangs.
    private func faceWindow() -> some View {
        let shape = FaceWindowShape()
        return ZStack {
            shape
                .fill(
                    RadialGradient(
                        colors: [skinTone.lighter(0.18), skinTone, skinTone.darker(0.2)],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: 30 * u
                    )
                )
                .frame(width: 48 * u, height: 36 * u)
                .overlay(
                    // Ambient occlusion cast by the helmet brim.
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.black.opacity(0.4), .black.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 13 * u)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipShape(shape)
                )
                .overlay(shape.stroke(outline, lineWidth: 2.2 * u))
                .offset(y: 10.5 * u)

            // Cheeks catch a soft blush on both sides.
            Ellipse()
                .fill(Color.combatCrimson.opacity(0.14))
                .frame(width: 7 * u, height: 4 * u)
                .offset(x: -13 * u, y: 14 * u)
            Ellipse()
                .fill(Color.combatCrimson.opacity(0.1))
                .frame(width: 7 * u, height: 4 * u)
                .offset(x: 13 * u, y: 14 * u)

            // Subsurface warmth: light scattering under the eyes and nose bridge.
            subsurfaceGlow(at: CGPoint(x: -9.5, y: 11))
            subsurfaceGlow(at: CGPoint(x: 9.5, y: 11))
            subsurfaceGlow(at: CGPoint(x: 0, y: 7), small: true)

            // A small confident smile under the key light.
            Capsule()
                .fill(outline.opacity(0.9))
                .frame(width: 3.6 * u, height: 1.3 * u)
                .offset(y: 16.5 * u)

            eyes.offset(y: 6 * u)
        }
    }

    /// Knight helmet: metal dome with a sweeping rim light, optional crest,
    /// riveted band, and a shadowed face window.
    private func knightHelmet(dome: Color, crest: Crest, band: Bool) -> some View {
        ZStack {
            // Signature gold ear points peeking past the dome's upper flanks.
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { side in
                ZStack {
                    lit(ConeShape(), accent, lineWidth: 1.4, metal: true)
                        .frame(width: 9 * u, height: 13 * u)
                    // Inner shade on the ear's shadow flank.
                    ConeShape()
                        .fill(Color.black.opacity(0.16))
                        .frame(width: 5.5 * u, height: 8.5 * u)
                        .offset(x: side * -1.1 * u, y: 1.5 * u)
                    // Tip glint where the key light grazes the point.
                    Circle()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: 1.5 * u, height: 1.5 * u)
                        .offset(x: side * -1.4 * u, y: -3.2 * u)
                }
                .rotationEffect(.degrees(side * 32))
                .offset(x: side * 30 * u, y: -16 * u)
            }

            switch crest {
            case .orange:
                finCrest(color: .questAmber)
            case .crimson:
                finCrest(color: .combatCrimson)
            case .none:
                EmptyView()
            }

            ZStack {
                Ellipse()
                    .fill(
                        EllipticalGradient(
                            stops: [
                                .init(color: dome.lighter(0.55), location: 0),
                                .init(color: dome.lighter(0.28), location: 0.18),
                                .init(color: dome, location: 0.42),
                                .init(color: dome.darker(0.18), location: 0.66),
                                .init(color: dome.darker(0.48), location: 1)
                            ],
                            center: UnitPoint(x: 0.34, y: 0.24),
                            startRadiusFraction: 0,
                            endRadiusFraction: 0.88
                        )
                    )
                    .overlay(
                        // Fill light from the lower-right keeps the dark flank alive.
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.0), location: 0),
                                        .init(color: .white.opacity(0.10), location: 0.7),
                                        .init(color: .white.opacity(0.16), location: 1)
                                    ],
                                    startPoint: UnitPoint(x: 0.35, y: 0.25),
                                    endPoint: UnitPoint(x: 0.85, y: 0.9)
                                )
                            )
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        // Brushed polish bands across the dome.
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.05), location: 0.2),
                                        .init(color: .black.opacity(0.03), location: 0.3),
                                        .init(color: .white.opacity(0.04), location: 0.44),
                                        .init(color: .black.opacity(0.03), location: 0.56),
                                        .init(color: .white.opacity(0.035), location: 0.7),
                                        .init(color: .black.opacity(0.03), location: 0.84)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        // Warm bounce off the ground onto the dome's underside.
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: bounceWarm.opacity(0.0), location: 0),
                                        .init(color: bounceWarm.opacity(0.16), location: 1)
                                    ],
                                    startPoint: UnitPoint(x: 0.5, y: 0.6),
                                    endPoint: .bottom
                                )
                            )
                            .allowsHitTesting(false)
                    )
                    .overlay(Ellipse().stroke(outline, lineWidth: 2.6 * u))
                // Rim light: a soft spread under a clean bright core.
                Ellipse()
                    .trim(from: 0.02, to: 0.40)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3.2 * u, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-12))
                Ellipse()
                    .trim(from: 0.02, to: 0.36)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.95), .white.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1.6 * u, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-12))
                sheen(width: 15, height: 4.5, at: CGPoint(x: 15, y: -20), opacity: 0.5)
                sheen(width: 8, height: 3.2, at: CGPoint(x: 6, y: -26), opacity: 0.4)
            }
            .frame(width: 74 * u, height: 68 * u)

            // Crest base occlusion where the fin meets the dome.
            castShadow(width: 20, height: 7, at: CGPoint(x: 2, y: -29), opacity: 0.28)

            if band {
                lit(
                    RoundedRectangle(cornerRadius: 4.5 * u, style: .continuous),
                    steelDeep,
                    lineWidth: 1.8,
                    metal: true
                )
                .frame(width: 50 * u, height: 9 * u)
                .offset(y: -16 * u)
                bandRivet(x: -16)
                bandRivet(x: 0)
                bandRivet(x: 16)
            }

            faceWindow()
        }
    }

    /// Two-lobed crest with a shaded sweep and the dark center slice.
    private func finCrest(color: Color) -> some View {
        ZStack {
            FinShape()
                .fill(
                    LinearGradient(
                        colors: [color.lighter(0.35), color, color.darker(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            NotchShape()
                .fill(outline)
                .frame(width: 4.5 * u, height: 12 * u)
                .rotationEffect(.degrees(14))
                .offset(x: -3 * u, y: -2 * u)
            // Lit edge along the crest's leading curve.
            FinShape()
                .trim(from: 0.05, to: 0.4)
                .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1.6 * u, lineCap: .round))
        }
        .overlay(FinShape().stroke(outline, lineWidth: 2.2 * u))
        .frame(width: 36 * u, height: 22 * u)
        .offset(x: 2 * u, y: -36 * u)
    }

    private func bandRivet(x: CGFloat) -> some View {
        ZStack {
            // Seat occlusion around the rivet head.
            Circle()
                .fill(Color.black.opacity(0.25))
                .frame(width: 3.8 * u, height: 3.8 * u)
                .offset(y: 0.3 * u)
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: steel.lighter(0.5), location: 0),
                            .init(color: steel, location: 0.55),
                            .init(color: steel.darker(0.35), location: 1)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: 2 * u
                    )
                )
                .frame(width: 2.8 * u, height: 2.8 * u)
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 0.8 * u, height: 0.8 * u)
                .offset(x: -0.4 * u, y: -0.5 * u)
            Circle()
                .fill(outline.opacity(0.6))
                .frame(width: 1 * u, height: 1 * u)
                .offset(y: 0.5 * u)
        }
        .offset(x: x * u, y: -16 * u)
    }

    /// Magician head: radially lit face, blush, layered beard, pointed hat.
    private var wizardHead: some View {
        ZStack {
            wizardHat

            Circle()
                .fill(
                    RadialGradient(
                        colors: [skinTone.lighter(0.2), skinTone, skinTone.darker(0.22)],
                        center: UnitPoint(x: 0.36, y: 0.3),
                        startRadius: 0,
                        endRadius: 30 * u
                    )
                )
                .overlay(Circle().stroke(outline, lineWidth: 2.4 * u))
                .frame(width: 50 * u, height: 50 * u)
                .offset(y: 5 * u)

            eyes.offset(y: 2 * u)

            subsurfaceGlow(at: CGPoint(x: -10, y: 7))
            subsurfaceGlow(at: CGPoint(x: 10, y: 7))
            subsurfaceGlow(at: CGPoint(x: 0, y: 2), small: true)

            // Cheek blush under the key light.
            Ellipse()
                .fill(Color.combatCrimson.opacity(0.13))
                .frame(width: 8 * u, height: 4.5 * u)
                .offset(x: -14 * u, y: 9 * u)
            Ellipse()
                .fill(Color.combatCrimson.opacity(0.1))
                .frame(width: 8 * u, height: 4.5 * u)
                .offset(x: 14 * u, y: 9 * u)

            // Mustache: two combed lobes with a shaded underside.
            ZStack {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Ellipse().stroke(outline, lineWidth: 1.4 * u))
                    .frame(width: 12 * u, height: 5 * u)
                    .rotationEffect(.degrees(14))
                    .offset(x: -6 * u, y: 12 * u)
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Ellipse().stroke(outline, lineWidth: 1.4 * u))
                    .frame(width: 12 * u, height: 5 * u)
                    .rotationEffect(.degrees(-14))
                    .offset(x: 6 * u, y: 12 * u)
            }

            // Beard: a shaded volume with a bright crown and side comb folds.
            ZStack {
                Ellipse()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(white: 0.97), location: 0),
                                .init(color: Color(white: 0.86), location: 0.45),
                                .init(color: Color(white: 0.68), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Ellipse().stroke(outline, lineWidth: 2 * u))
                Ellipse()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 14 * u, height: 5 * u)
                    .offset(y: -5 * u)
                Capsule()
                    .fill(Color(white: 0.58).opacity(0.55))
                    .frame(width: 1.2 * u, height: 8 * u)
                    .offset(x: -5 * u, y: 2.5 * u)
                Capsule()
                    .fill(Color(white: 0.58).opacity(0.55))
                    .frame(width: 1.2 * u, height: 8 * u)
                    .offset(x: 5 * u, y: 2.5 * u)
                Capsule()
                    .fill(Color(white: 0.6).opacity(0.6))
                    .frame(width: 1.4 * u, height: 9 * u)
                    .offset(y: 3 * u)
                // Warm bounce off the ground into the beard's underside.
                Ellipse()
                    .fill(bounceWarm.opacity(0.16))
                    .frame(width: 16 * u, height: 3.5 * u)
                    .offset(y: 7.5 * u)
            }
            .frame(width: 27 * u, height: 20 * u)
            .offset(y: 22 * u)
        }
    }

    /// Starlit Cap: the wizard hat embroidered with three stars.
    private var starWizardHead: some View {
        ZStack {
            wizardHead
            starGlyph(size: 8, at: CGPoint(x: 8, y: -32))
            starGlyph(size: 5, at: CGPoint(x: -7, y: -26))
            starGlyph(size: 4, at: CGPoint(x: 1, y: -21))
        }
    }

    private func starGlyph(size: CGFloat, at point: CGPoint) -> some View {
        Image(systemName: "star.fill")
            .font(.system(size: size * u, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [.questAmber.lighter(0.4), .questAmber.darker(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(x: point.x * u, y: point.y * u)
    }

    /// Pointed wizard hat: shaded cone, lit brim, gold band, pompom.
    private var wizardHat: some View {
        ZStack {
            orb(Circle(), Color(red: 0.20, green: 0.42, blue: 0.40), radius: 5, lineWidth: 1.8)
                .frame(width: 9 * u, height: 9 * u)
                .offset(x: -5 * u, y: -44 * u)

            lit(ConeShape(), Color(red: 0.26, green: 0.52, blue: 0.49), lineWidth: 2.2)
                .frame(width: 54 * u, height: 36 * u)
                .overlay(
                    // Fabric fold shading across the cone.
                    ConeShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.0), location: 0),
                                    .init(color: .black.opacity(0.18), location: 0.5),
                                    .init(color: .black.opacity(0.0), location: 0.65)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .frame(width: 54 * u, height: 36 * u)
                .offset(y: -26 * u)

            lit(Ellipse(), Color(red: 0.20, green: 0.42, blue: 0.40), lineWidth: 2.2)
                .frame(width: 60 * u, height: 13 * u)
                .overlay(
                    Ellipse()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1 * u)
                        .frame(width: 52 * u, height: 8 * u)
                        .offset(y: -2 * u)
                )
                .overlay(
                    // Underside occlusion where the brim shades the crown.
                    Ellipse()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 52 * u, height: 4.5 * u)
                        .offset(y: 3 * u)
                )
                .offset(y: -9 * u)

            lit(Rectangle(), .questAmber, lineWidth: 1.3, metal: true)
                .frame(width: 24 * u, height: 5 * u)
                .overlay(
                    HStack(spacing: 8 * u) {
                        Circle().fill(Color(white: 0.95).opacity(0.8)).frame(width: 1 * u, height: 1 * u)
                        Circle().fill(Color(white: 0.95).opacity(0.8)).frame(width: 1 * u, height: 1 * u)
                    }
                )
                .offset(y: -15 * u)
        }
    }

    /// Shadow Hood: cloth dome with a deep shadowed face and pale eyes.
    private var hoodedHead: some View {
        ZStack {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: charcoal.lighter(0.34), location: 0),
                                .init(color: charcoal, location: 0.4),
                                .init(color: charcoal.darker(0.18), location: 0.72),
                                .init(color: charcoal.darker(0.45), location: 1)
                            ],
                            center: UnitPoint(x: 0.36, y: 0.28),
                            startRadius: 0,
                            endRadius: 36 * u
                        )
                    )
                    .overlay(Circle().stroke(outline, lineWidth: 2.6 * u))
                // Hanging cloth folds under the crown.
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.0), location: 0.12),
                                .init(color: .black.opacity(0.16), location: 0.34),
                                .init(color: .black.opacity(0.0), location: 0.52),
                                .init(color: .black.opacity(0.12), location: 0.74),
                                .init(color: .black.opacity(0.0), location: 0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                // Rim light: soft spread under a bright core.
                Circle()
                    .trim(from: 0.02, to: 0.38)
                    .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2.6 * u, lineCap: .round))
                    .rotationEffect(.degrees(-12))
                Circle()
                    .trim(from: 0.02, to: 0.32)
                    .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.2 * u, lineCap: .round))
                    .rotationEffect(.degrees(-12))
            }
            .frame(width: 62 * u, height: 62 * u)

            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .foregroundStyle(
                    LinearGradient(
                        colors: [charcoal.lighter(0.25), charcoal.darker(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 14 * u, height: 15 * u)
                .offset(y: -34 * u)

            // Face sunk into the hood: near-black with a faint warm falloff.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [skinTone.darker(0.42), skinTone.darker(0.6)],
                        center: UnitPoint(x: 0.4, y: 0.34),
                        startRadius: 0,
                        endRadius: 20 * u
                    )
                )
                .frame(width: 34 * u, height: 34 * u)
                .offset(y: 9 * u)
                .overlay(
                    // Faint brow shadow deepening the V of the hood.
                    Ellipse()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: 22 * u, height: 7 * u)
                        .offset(y: -12 * u)
                )

            // Pale eyes read through the shadow.
            ZStack {
                Ellipse()
                    .fill(Color(white: 0.88))
                    .frame(width: 6.4 * u, height: 6.4 * u)
                Circle()
                    .fill(outline)
                    .frame(width: 3 * u, height: 3 * u)
                    .offset(x: 0.8 * u, y: 0.4 * u)
            }
            .offset(x: -7 * u, y: 8 * u)
            ZStack {
                Ellipse()
                    .fill(Color(white: 0.88))
                    .frame(width: 6.4 * u, height: 6.4 * u)
                Circle()
                    .fill(outline)
                    .frame(width: 3 * u, height: 3 * u)
                    .offset(x: 0.8 * u, y: 0.4 * u)
            }
            .offset(x: 7 * u, y: 8 * u)
        }
    }

    // MARK: Weapon

    /// Anchored so the grip passes through the right fist at (81.5, 95);
    /// held tilted slightly inward, blade resting against the helmet.
    /// Small mace held in the knight's off hand when no shield is equipped:
    /// leather-wrapped haft, gold collar and pommel, spiked steel head.
    @ViewBuilder private var maceLayer: some View {
        if isKnight && item(.shield) == nil {
            ZStack {
                lit(Capsule(), leather, lineWidth: 1.3, grain: true)
                    .frame(width: 3.2 * u, height: 16 * u)
                // Pommel cap grounding the haft's lower end.
                lit(Capsule(), .questAmber, lineWidth: 1.1, metal: true)
                    .frame(width: 4.4 * u, height: 2.8 * u)
                    .offset(y: 7 * u)
                // Gold collar where the head seats onto the haft.
                lit(Capsule(), .questAmber, lineWidth: 1.1, metal: true)
                    .frame(width: 4.4 * u, height: 2.4 * u)
                    .offset(y: -5.4 * u)
                ZStack {
                    ForEach(0..<6, id: \.self) { i in
                        lit(ConeShape(), steelDeep, lineWidth: 0.9, metal: true)
                            .frame(width: 3.4 * u, height: 5.5 * u)
                            .offset(y: -8.6 * u)
                            .rotationEffect(.degrees(Double(i) * 60))
                    }
                    orb(Circle(), steel, radius: 6.2, lineWidth: 1.7)
                        .frame(width: 11.5 * u, height: 11.5 * u)
                }
                .offset(y: -12 * u)
            }
            .rotationEffect(.degrees(-26))
            .offset(x: -25.5 * u, y: 17 * u)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    @ViewBuilder private var weaponLayer: some View {
        ZStack {
            weaponModel
        }
        .rotationEffect(.degrees(2), anchor: .center)
        .offset(x: 25.5 * u, y: 10.5 * u)
    }

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

    /// Default Knight blade: two-facet steel with a bright fuller and edge light.
    private var simpleSword: some View {
        VStack(spacing: 0) {
            ZStack {
                BladeShape()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: steelDeep.darker(0.15), location: 0),
                                .init(color: steelDeep, location: 0.22),
                                .init(color: steel, location: 0.45),
                                .init(color: steel.lighter(0.28), location: 0.6),
                                .init(color: steel, location: 0.78),
                                .init(color: steelDeep.darker(0.3), location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 14 * u, height: 30 * u)
                // Fuller groove with light fall-off on its lit lip.
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.30), location: 0),
                                .init(color: .black.opacity(0.12), location: 0.45),
                                .init(color: .black.opacity(0.26), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1.6 * u, height: 22 * u)
                Rectangle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 0.8 * u, height: 21 * u)
                    .offset(x: 1.2 * u)
                // Thin bevel plus a secondary streak along the cutting edge.
                Rectangle()
                    .fill(Color.white.opacity(0.34))
                    .frame(width: 0.9 * u, height: 25 * u)
                    .offset(x: 5.1 * u)
                sheen(width: 2.6, height: 19, at: CGPoint(x: 2.6, y: -1), angle: 0, opacity: 0.65)
            }
            .frame(width: 14 * u, height: 30 * u)
            .clipShape(BladeShape())
            .overlay(BladeShape().stroke(outline, lineWidth: 2 * u))
            lit(Rectangle(), .questAmber, lineWidth: 1.6, metal: true)
                .frame(width: 20 * u, height: 6 * u)
                .overlay(
                    DiamondShape()
                        .fill(Color.questAmber.lighter(0.45))
                        .frame(width: 2.4 * u, height: 2.4 * u)
                )
            lit(Rectangle(), leather, lineWidth: 1.5, grain: true)
                .frame(width: 6 * u, height: 9 * u)
            lit(Rectangle(), Color(red: 0.30, green: 0.18, blue: 0.10), lineWidth: 1.4, grain: true)
                .frame(width: 6 * u, height: 3.5 * u)
        }
    }

    /// Default Magician wand: turned wood with a lit orb and a rune ring.
    private var simpleWand: some View {
        VStack(spacing: 2 * u) {
            orb(Circle(), .xpViolet, radius: 5.5, lineWidth: 1.6)
                .frame(width: 9 * u, height: 9 * u)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 0.9 * u)
                        .frame(width: 12 * u, height: 12 * u)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.7 * u)
                        .frame(width: 14.5 * u, height: 14.5 * u)
                )
            lit(Capsule(), wood, lineWidth: 1.4, grain: true)
                .frame(width: 4 * u, height: 32 * u)
                .overlay(
                    // Grain lines.
                    VStack(spacing: 7 * u) {
                        Rectangle().fill(Color.black.opacity(0.2)).frame(width: 1 * u, height: 4 * u)
                        Rectangle().fill(Color.black.opacity(0.2)).frame(width: 1 * u, height: 4 * u)
                    }
                )
        }
    }

    @ViewBuilder private func heldWeapon(id: String) -> some View {
        switch id {
        case "weapon.staff":
            // Archmage Staff: claw-set orb over a grained haft.
            VStack(spacing: 0) {
                ZStack {
                    orb(Circle(), .xpViolet, radius: 7.5, lineWidth: 1.8)
                        .frame(width: 13 * u, height: 13 * u)
                    Circle()
                        .stroke(Color.white.opacity(0.45), lineWidth: 1 * u)
                        .frame(width: 17 * u, height: 17 * u)
                    // Claw prongs cradling the orb.
                    claw(x: -5.5, angle: -32)
                    claw(x: 5.5, angle: 32)
                }
                lit(Capsule(), wood, lineWidth: 1.6, grain: true)
                    .frame(width: 4.5 * u, height: 42 * u)
                    .overlay(
                        // Occlusion under the overhanging orb head.
                        Rectangle()
                            .fill(aoWash(height: 4, strength: 0.32))
                            .frame(width: 4.5 * u, height: 4 * u)
                            .frame(maxHeight: .infinity, alignment: .top)
                    )
                    .overlay(
                        VStack(spacing: 9 * u) {
                            Rectangle().fill(Color.black.opacity(0.22)).frame(width: 1.1 * u, height: 6 * u)
                            Rectangle().fill(Color.black.opacity(0.22)).frame(width: 1.1 * u, height: 6 * u)
                            Rectangle().fill(Color.black.opacity(0.22)).frame(width: 1.1 * u, height: 6 * u)
                        }
                    )
                lit(Rectangle(), leather, lineWidth: 1.4, grain: true)
                    .frame(width: 5.5 * u, height: 4 * u)
            }
        case "weapon.gem":
            // Gem Hammer: forged head with gold cheeks and a socketed jewel.
            VStack(spacing: 0) {
                ZStack {
                    lit(
                        RoundedRectangle(cornerRadius: 3.5 * u, style: .continuous),
                        steel,
                        lineWidth: 2,
                        metal: true
                    )
                    .frame(width: 19 * u, height: 12 * u)
                    lit(Rectangle(), .questAmber, lineWidth: 1.2, metal: true)
                        .frame(width: 3.4 * u, height: 11 * u)
                        .offset(x: -6.5 * u)
                    lit(Rectangle(), .questAmber, lineWidth: 1.2, metal: true)
                        .frame(width: 3.4 * u, height: 11 * u)
                        .offset(x: 6.5 * u)
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 1.1 * u, height: 1.1 * u)
                        .offset(x: -6.5 * u, y: -3.4 * u)
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 1.1 * u, height: 1.1 * u)
                        .offset(x: 6.5 * u, y: -3.4 * u)
                    DiamondShape()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 8.4 * u, height: 8.4 * u)
                        .offset(y: 0.5 * u)
                    DiamondShape()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: .questAmber.lighter(0.6), location: 0),
                                    .init(color: .questAmber.lighter(0.2), location: 0.4),
                                    .init(color: .questAmber, location: 0.68),
                                    .init(color: .questAmber.darker(0.4), location: 1)
                                ],
                                center: UnitPoint(x: 0.4, y: 0.3),
                                startRadius: 0,
                                endRadius: 5 * u
                            )
                        )
                        .overlay(DiamondShape().stroke(outline, lineWidth: 1.1 * u))
                        .frame(width: 6.5 * u, height: 6.5 * u)
                        .overlay(
                            DiamondShape()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 2 * u, height: 2 * u)
                                .offset(x: -0.8 * u, y: -0.9 * u)
                        )
                }
                lit(Capsule(), wood, lineWidth: 1.6, grain: true)
                    .frame(width: 4.5 * u, height: 32 * u)
                    .overlay(
                        // Occlusion under the overhanging hammer head.
                        Rectangle()
                            .fill(aoWash(height: 4, strength: 0.32))
                            .frame(width: 4.5 * u, height: 4 * u)
                            .frame(maxHeight: .infinity, alignment: .top)
                    )
                    .overlay(
                        VStack(spacing: 6 * u) {
                            Rectangle().fill(Color.black.opacity(0.22)).frame(width: 1.1 * u, height: 5 * u)
                            Rectangle().fill(Color.black.opacity(0.22)).frame(width: 1.1 * u, height: 5 * u)
                        }
                    )
                lit(Rectangle(), leather, lineWidth: 1.3, grain: true)
                    .frame(width: 6 * u, height: 3.5 * u)
            }
        case "weapon.reel":
            // Film Reel Blade: machined reel hub over a steel edge.
            VStack(spacing: 0) {
                ZStack {
                    orb(Circle(), .videoSapphire, radius: 8.5, lineWidth: 1.8)
                        .frame(width: 15 * u, height: 15 * u)
                    // Sprocket punches around the hub.
                    sprocketHole(angle: 0)
                    sprocketHole(angle: 90)
                    sprocketHole(angle: 180)
                    sprocketHole(angle: 270)
                    Circle()
                        .fill(outline)
                        .frame(width: 4.6 * u, height: 4.6 * u)
                    Circle()
                        .fill(steel)
                        .frame(width: 1.4 * u, height: 1.4 * u)
                        .offset(x: -0.5 * u, y: -0.5 * u)
                }
                lit(BladeShape(), steel, lineWidth: 1.8, metal: true)
                    .frame(width: 8 * u, height: 20 * u)
                    .overlay(
                        BladeShape()
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.9 * u)
                            .frame(width: 5 * u, height: 15 * u)
                            .frame(width: 8 * u, height: 20 * u, alignment: .top)
                            .clipped()
                    )
                    .overlay(
                        // Cutting-edge bevel cropped to the blade silhouette.
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 0.9 * u, height: 15 * u)
                            .offset(x: 2.4 * u)
                            .frame(width: 8 * u, height: 20 * u)
                            .clipShape(BladeShape())
                            .allowsHitTesting(false)
                    )
                lit(Rectangle(), .questAmber, lineWidth: 1.3, metal: true)
                    .frame(width: 15 * u, height: 4 * u)
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 1 * u, height: 1 * u)
                    )
                lit(Rectangle(), charcoal, lineWidth: 1.3, grain: true)
                    .frame(width: 5 * u, height: 8 * u)
            }
        case "weapon.stormblade":
            // Storm Cleaver: wide blue-steel cleaver with a charged bolt core.
            VStack(spacing: 0) {
                ZStack {
                    BladeShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.videoSapphire.darker(0.42), location: 0),
                                    .init(color: Color.videoSapphire.darker(0.12), location: 0.28),
                                    .init(color: .videoSapphire, location: 0.5),
                                    .init(color: .videoSapphire.lighter(0.38), location: 0.66),
                                    .init(color: .videoSapphire, location: 0.82),
                                    .init(color: Color.videoSapphire.darker(0.34), location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 16 * u, height: 32 * u)
                    Image(systemName: "bolt.fill")
                        .resizable()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.white.opacity(0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 7 * u, height: 19 * u)
                        .offset(y: 2 * u)
                    Rectangle()
                        .fill(Color.white.opacity(0.30))
                        .frame(width: 1 * u, height: 27 * u)
                        .offset(x: 6.2 * u)
                    Rectangle()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: 1.2 * u, height: 27 * u)
                        .offset(x: -6.4 * u)
                }
                .frame(width: 16 * u, height: 32 * u)
                .clipShape(BladeShape())
                .overlay(BladeShape().stroke(outline, lineWidth: 2 * u))
                lit(Rectangle(), steelDeep, lineWidth: 1.6, metal: true)
                    .frame(width: 19 * u, height: 5 * u)
                wrappedGrip(width: 6, height: 9)
                orb(Circle(), steelDeep, radius: 5, lineWidth: 1.5)
                    .frame(width: 9 * u, height: 9 * u)
            }
        case "weapon.chevron":
            // Oathbreaker: blackened blade, white chevron column, steel edge.
            VStack(spacing: 0) {
                ZStack {
                    BladeShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.13, green: 0.15, blue: 0.14), location: 0),
                                    .init(color: Color(red: 0.18, green: 0.21, blue: 0.19), location: 0.3),
                                    .init(color: Color(red: 0.14, green: 0.17, blue: 0.15), location: 0.55),
                                    .init(color: Color(red: 0.20, green: 0.24, blue: 0.22), location: 0.7),
                                    .init(color: Color(red: 0.07, green: 0.09, blue: 0.08), location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 14 * u, height: 30 * u)
                    VStack(spacing: 1.4 * u) {
                        ForEach(0..<4, id: \.self) { _ in
                            ChevronShape()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.65)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 8 * u, height: 4.2 * u)
                        }
                    }
                    .offset(y: 3.5 * u)
                    Rectangle()
                        .fill(steel.opacity(0.4))
                        .frame(width: 0.9 * u, height: 25 * u)
                        .offset(x: 5.2 * u)
                }
                .frame(width: 14 * u, height: 30 * u)
                .clipShape(BladeShape())
                .overlay(BladeShape().stroke(steel, lineWidth: 1.8 * u))
                .overlay(BladeShape().stroke(outline, lineWidth: 1 * u))
                lit(Capsule(), steel, lineWidth: 1.6, metal: true)
                    .frame(width: 21 * u, height: 5 * u)
                wrappedGrip(width: 6.5, height: 9.5)
                pommelBall(diameter: 9.5)
            }
        case "weapon.ruby":
            // Ruby Fang: crimson steel with a hot specular line.
            VStack(spacing: 0) {
                ZStack {
                    BladeShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.combatCrimson.darker(0.5), location: 0),
                                    .init(color: Color.combatCrimson.darker(0.15), location: 0.25),
                                    .init(color: .combatCrimson, location: 0.45),
                                    .init(color: .combatCrimson.lighter(0.32), location: 0.6),
                                    .init(color: .combatCrimson, location: 0.78),
                                    .init(color: Color.combatCrimson.darker(0.4), location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 14 * u, height: 30 * u)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.7), Color.white.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2.8 * u, height: 22 * u)
                        .offset(x: 2.4 * u, y: 1 * u)
                    Rectangle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 1.1 * u, height: 24 * u)
                        .offset(x: 3.8 * u, y: 1 * u)
                    Rectangle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 0.9 * u, height: 26 * u)
                        .offset(x: 5.4 * u)
                }
                .frame(width: 14 * u, height: 30 * u)
                .clipShape(BladeShape())
                .overlay(BladeShape().stroke(outline, lineWidth: 2 * u))
                lit(Capsule(), steelDeep, lineWidth: 1.6, metal: true)
                    .frame(width: 21 * u, height: 5.5 * u)
                wrappedGrip(width: 6, height: 9)
                ZStack {
                    lit(
                        RoundedRectangle(cornerRadius: 3 * u, style: .continuous),
                        steelDeep,
                        lineWidth: 1.6,
                        metal: true
                    )
                    .frame(width: 9.5 * u, height: 9.5 * u)
                    DiamondShape()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 4.6 * u, height: 4.6 * u)
                        .offset(y: 0.3 * u)
                    DiamondShape()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: .combatCrimson.lighter(0.55), location: 0),
                                    .init(color: .combatCrimson, location: 0.55),
                                    .init(color: .combatCrimson.darker(0.4), location: 1)
                                ],
                                center: UnitPoint(x: 0.4, y: 0.3),
                                startRadius: 0,
                                endRadius: 4 * u
                            )
                        )
                        .frame(width: 3.6 * u, height: 3.6 * u)
                }
            }
        case "weapon.arcane":
            // Arcane Edge: verdigris steel, rune chevron, clawed guard, heart core.
            VStack(spacing: 0) {
                ZStack {
                    BladeShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.34, green: 0.50, blue: 0.48), location: 0),
                                    .init(color: Color(red: 0.46, green: 0.62, blue: 0.60), location: 0.28),
                                    .init(color: Color(red: 0.56, green: 0.72, blue: 0.70), location: 0.5),
                                    .init(color: Color(red: 0.66, green: 0.82, blue: 0.78), location: 0.64),
                                    .init(color: Color(red: 0.48, green: 0.64, blue: 0.62), location: 0.82),
                                    .init(color: Color(red: 0.28, green: 0.42, blue: 0.40), location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 15 * u, height: 32 * u)
                    ChevronShape()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.95), Color.white.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 9 * u, height: 9 * u)
                        .offset(y: 8 * u)
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 1.6 * u, height: 22 * u)
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 0.9 * u, height: 27 * u)
                        .offset(x: 5.6 * u)
                }
                .frame(width: 15 * u, height: 32 * u)
                .clipShape(BladeShape())
                .overlay(BladeShape().stroke(outline, lineWidth: 2 * u))
                ZStack {
                    lit(Capsule(), steelDeep, lineWidth: 1.6, metal: true)
                        .frame(width: 22 * u, height: 5 * u)
                    guardCube(x: -10)
                    guardCube(x: 10)
                }
                ZStack {
                    Rectangle()
                        .fill(outline)
                        .frame(width: 6.5 * u, height: 9 * u)
                    VStack(spacing: 2.6 * u) {
                        Capsule().fill(steel).frame(width: 6.5 * u, height: 1.4 * u)
                        Capsule().fill(steel).frame(width: 6.5 * u, height: 1.4 * u)
                    }
                }
                .overlay(Rectangle().stroke(outline, lineWidth: 1.2 * u))
                ZStack {
                    orb(Circle(), Color(red: 0.19, green: 0.24, blue: 0.21), radius: 5, lineWidth: 1.6)
                        .frame(width: 9.5 * u, height: 9.5 * u)
                        .overlay(
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.combatCrimson.opacity(0.4), Color.combatCrimson.opacity(0.0)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 5 * u
                                    )
                                )
                        )
                    Image(systemName: "heart.fill")
                        .resizable()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.white.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4 * u, height: 3.6 * u)
                }
            }
        case "weapon.fireworkBlade":
            // Firework Blade: bright steel with a bursting crown at the tip.
            VStack(spacing: 0) {
                ZStack {
                    sparkBurst
                        .offset(y: -13 * u)
                    BladeShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: steelDeep.darker(0.28), location: 0),
                                    .init(color: steelDeep, location: 0.26),
                                    .init(color: steel.lighter(0.16), location: 0.5),
                                    .init(color: steel.lighter(0.3), location: 0.62),
                                    .init(color: steelDeep.darker(0.1), location: 0.82),
                                    .init(color: steelDeep.darker(0.3), location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 14 * u, height: 30 * u)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2.4 * u, height: 21 * u)
                        .offset(x: 2.2 * u)
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 0.9 * u, height: 25 * u)
                        .offset(x: 5.2 * u)
                }
                .frame(width: 14 * u, height: 30 * u)
                .clipShape(BladeShape())
                .overlay(BladeShape().stroke(outline, lineWidth: 2 * u))
                lit(Capsule(), .questAmber, lineWidth: 1.6, metal: true)
                    .frame(width: 20 * u, height: 5.5 * u)
                wrappedGrip(width: 6, height: 9)
                pommelBall(diameter: 9)
            }
        default:
            // Crystal Shard: a faceted gem with internal planes and a gold cap.
            VStack(spacing: 0) {
                ZStack {
                    CrystalShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .videoSapphire.lighter(0.25), location: 0),
                                    .init(color: .videoSapphire, location: 0.55),
                                    .init(color: .videoSapphire.darker(0.35), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 12 * u, height: 22 * u)
                    // Facet planes: a lit left face and a dark right face.
                    CrystalShape()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 5.5 * u, height: 19 * u)
                        .offset(x: -2.4 * u, y: -1 * u)
                    CrystalShape()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: 3.4 * u, height: 19 * u)
                        .offset(x: 3.4 * u, y: 0.5 * u)
                    CrystalShape()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 8 * u, height: 21 * u)
                        .offset(x: 0.6 * u, y: -0.5 * u)
                    DiamondShape()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: 2.6 * u, height: 2.6 * u)
                        .offset(x: -1.8 * u, y: -5.5 * u)
                }
                .frame(width: 12 * u, height: 22 * u)
                .clipShape(CrystalShape())
                .overlay(
                    CrystalShape()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.94, blue: 0.80).opacity(0.5),
                                    Color(red: 0.72, green: 0.86, blue: 1.0).opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9 * u
                        )
                )
                .overlay(CrystalShape().stroke(outline, lineWidth: 1.8 * u))
                lit(Rectangle(), .questAmber, lineWidth: 1.4, metal: true)
                    .frame(width: 9 * u, height: 3.5 * u)
                lit(Capsule(), wood, lineWidth: 1.3, grain: true)
                    .frame(width: 4 * u, height: 10 * u)
            }
        }
    }

    private func sprocketHole(angle: Double) -> some View {
        ZStack {
            // Machined rim catching light around each punch.
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 3.0 * u, height: 3.0 * u)
                .offset(y: 0.2 * u)
            Circle()
                .fill(Color.black.opacity(0.45))
                .frame(width: 2.4 * u, height: 2.4 * u)
        }
        .offset(y: -4.6 * u)
        .rotationEffect(.degrees(angle))
    }

    private func claw(x: CGFloat, angle: Double) -> some View {
        let prong = LinearGradient(
            colors: [steel.lighter(0.3), steelDeep.darker(0.2)],
            startPoint: .top,
            endPoint: .bottom
        )
        let microHighlight = Capsule()
            .fill(Color.white.opacity(0.35))
            .frame(width: 0.7 * u, height: 2.2 * u)
            .offset(x: -0.4 * u, y: -1.2 * u)
        return Capsule()
            .fill(prong)
            .overlay(microHighlight)
            .frame(width: 2 * u, height: 7 * u)
            .rotationEffect(.degrees(angle))
            .offset(x: x * u, y: -1.5 * u)
            .overlay(Capsule().stroke(outline, lineWidth: 0.9 * u))
    }

    /// Radiating spark crown for the Firework Blade: alternating gold, jade,
    /// and crimson rays with bright tips.
    private var sparkBurst: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.questAmber.opacity(0.28), Color.questAmber.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 9 * u
                    )
                )
                .frame(width: 18 * u, height: 18 * u)
            sparkRay(angle: -90, color: .questAmber, length: 8)
            sparkRay(angle: -55, color: .gemEmerald, length: 6.5)
            sparkRay(angle: -125, color: .gemEmerald, length: 6.5)
            sparkRay(angle: -25, color: .combatCrimson, length: 5)
            sparkRay(angle: -155, color: .combatCrimson, length: 5)
            Circle()
                .fill(Color.questAmber.lighter(0.5))
                .frame(width: 3 * u, height: 3 * u)
        }
    }

    private func sparkRay(angle: Double, color: Color, length: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [color.lighter(0.45), color.darker(0.15)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .overlay(Capsule().stroke(outline, lineWidth: 0.6 * u))
            .frame(width: 1.7 * u, height: length * u)
            .rotationEffect(.degrees(angle))
            .offset(y: -(length / 2 + 2.5) * u)
    }

    /// Black leather grip with lit wrap lines, grain ticks, and edge
    /// darkening, shared by the reference swords.
    private func wrappedGrip(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color(white: 0.14))
            .frame(width: width * u, height: height * u)
            .overlay(
                VStack(spacing: 2.2 * u) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.38), Color.white.opacity(0.12)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: (width - 1) * u, height: 1.1 * u)
                    }
                }
            )
            .overlay(
                // Leather grain ticks between the wraps.
                VStack(spacing: 2.2 * u) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 1.6 * u) {
                            Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1 * u, height: 0.8 * u)
                            Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1 * u, height: 0.8 * u)
                            Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1 * u, height: 0.8 * u)
                        }
                    }
                }
                .offset(x: 0.8 * u)
            )
            .overlay(
                // Edge darkening keeps the grip reading as a cylinder.
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.black.opacity(0.45), .black.opacity(0.0), .black.opacity(0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(Rectangle().stroke(outline, lineWidth: 1.2 * u))
    }

    /// Turned-steel pommel ball with a catchlight.
    private func pommelBall(diameter: CGFloat) -> some View {
        ZStack {
            orb(Circle(), steel, radius: diameter / 2, lineWidth: 1.5)
                .frame(width: diameter * u, height: diameter * u)
            Circle()
                .fill(steelDeep)
                .frame(width: diameter * 0.4 * u, height: diameter * 0.4 * u)
                .offset(y: -diameter * 0.08 * u)
        }
    }

    private func guardCube(x: CGFloat) -> some View {
        ZStack {
            lit(
                RoundedRectangle(cornerRadius: 1.5 * u, style: .continuous),
                steelDeep,
                lineWidth: 1.4,
                metal: true
            )
            .frame(width: 5.5 * u, height: 7.5 * u)
            Circle()
                .fill(Color.white)
                .frame(width: 1.8 * u, height: 1.8 * u)
                .offset(x: -0.5 * u, y: -0.5 * u)
        }
        .offset(x: x * u)
    }

    // MARK: Shield — strapped over the left arm

    @ViewBuilder private var shieldLayer: some View {
        if item(.shield) != nil {
            Group {
                if item(.shield)?.id == "shield.templar" {
                    templarShield
                } else {
                    cruxShield
                }
            }
            .rotationEffect(.degrees(-10))
            .offset(x: -27 * u, y: 26 * u)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    /// Azure Aegis: gilded rim, royal-blue field, embossed gold cross, rivets.
    private var cruxShield: some View {
        ZStack {
            lit(HeaterShieldShape(), .questAmber, lineWidth: 2.2, metal: true)
            HeaterShieldShape()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.30, green: 0.50, blue: 0.70), location: 0),
                            .init(color: Color(red: 0.24, green: 0.43, blue: 0.62), location: 0.38),
                            .init(color: Color(red: 0.19, green: 0.36, blue: 0.54), location: 0.66),
                            .init(color: Color(red: 0.12, green: 0.25, blue: 0.41), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 17 * u, height: 22 * u)
                .offset(y: 1.5 * u)
                .overlay(
                    // Field sheen sweeping the lit half.
                    HeaterShieldShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.18), location: 0),
                                    .init(color: .white.opacity(0.0), location: 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 17 * u, height: 22 * u)
                        .offset(y: 1.5 * u)
                )
                .overlay(
                    // Narrow secondary lobe hugging the lit flank.
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.16), .white.opacity(0.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 4.5 * u, height: 15 * u)
                        .rotationEffect(.degrees(-16))
                        .offset(x: -3.5 * u, y: 0.5 * u)
                        .frame(width: 17 * u, height: 22 * u)
                        .clipShape(HeaterShieldShape())
                        .offset(y: 1.5 * u)
                        .allowsHitTesting(false)
                )
                .overlay(
                    // Inner rim occlusion along the lower shell.
                    HeaterShieldShape()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.0), location: 0.35),
                                    .init(color: .black.opacity(0.30), location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.6 * u
                        )
                        .frame(width: 20 * u, height: 25 * u)
                )
                .overlay(HeaterShieldShape().stroke(outline.opacity(0.7), lineWidth: 1 * u))
                .offset(y: 0)
            castShadow(width: 14, height: 18, at: CGPoint(x: 0.8, y: 1.4), opacity: 0.18)
            embossedCross(.questAmber)
            shieldRivet(CGPoint(x: -7, y: -5))
            shieldRivet(CGPoint(x: 7, y: -5))
        }
        .frame(width: 22 * u, height: 27 * u)
    }

    /// Templar Bulwark: steel rim, white field, black cross with a scarlet core.
    private var templarShield: some View {
        ZStack {
            lit(HeaterShieldShape(), Color(red: 0.43, green: 0.50, blue: 0.46), lineWidth: 2.2, metal: true)
            HeaterShieldShape()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(white: 1.0), location: 0),
                            .init(color: Color(white: 0.95), location: 0.35),
                            .init(color: Color(white: 0.87), location: 0.68),
                            .init(color: Color(white: 0.77), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 17.5 * u, height: 22.5 * u)
                .offset(y: 1.5 * u)
                .overlay(
                    HeaterShieldShape()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.1), location: 0),
                                    .init(color: .black.opacity(0.0), location: 0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 17.5 * u, height: 22.5 * u)
                        .offset(y: 1.5 * u)
                )
                .overlay(
                    HeaterShieldShape()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0.0), location: 0.35),
                                    .init(color: .black.opacity(0.25), location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.6 * u
                        )
                        .frame(width: 20.5 * u, height: 25.5 * u)
                )
                .overlay(HeaterShieldShape().stroke(outline.opacity(0.7), lineWidth: 1 * u))
            castShadow(width: 14, height: 18, at: CGPoint(x: 0.8, y: 1.4), opacity: 0.15)
            embossedCross(outline, inner: .combatCrimson)
            shieldRivet(CGPoint(x: -7, y: -5))
            shieldRivet(CGPoint(x: 7, y: -5))
        }
        .frame(width: 22 * u, height: 27 * u)
    }

    /// Cross with an embossed feel: a dark offset plate beneath a lit face.
    private func embossedCross(_ color: Color, inner: Color? = nil) -> some View {
        ZStack {
            crossPlate(color.darker(0.45), inner: inner.map { $0.darker(0.4) })
                .offset(x: 0.7 * u, y: 0.9 * u)
            crossPlate(color, inner: inner)
        }
    }

    private func crossPlate(_ color: Color, inner: Color?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.5 * u, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: color.lighter(0.30), location: 0),
                            .init(color: color, location: 0.5),
                            .init(color: color.darker(0.20), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4.5 * u, height: 17 * u)
                .overlay(
                    // Lit bevel along the vertical arm's leading edge.
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 0.8 * u)
                        .frame(maxHeight: .infinity, alignment: .leading)
                )
            RoundedRectangle(cornerRadius: 1.5 * u, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: color.lighter(0.30), location: 0),
                            .init(color: color, location: 0.5),
                            .init(color: color.darker(0.20), location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 12 * u, height: 4.5 * u)
                .offset(y: -2.5 * u)
            if let inner {
                RoundedRectangle(cornerRadius: 1 * u, style: .continuous)
                    .fill(inner)
                    .frame(width: 2.4 * u, height: 13 * u)
                RoundedRectangle(cornerRadius: 1 * u, style: .continuous)
                    .fill(inner)
                    .frame(width: 8.5 * u, height: 2.4 * u)
                    .offset(y: -2.5 * u)
            }
        }
    }

    private func shieldRivet(_ point: CGPoint) -> some View {
        ZStack {
            // Seat occlusion around the rivet head.
            Circle()
                .fill(Color.black.opacity(0.28))
                .frame(width: 3.6 * u, height: 3.6 * u)
                .offset(y: 0.4 * u)
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(white: 0.98), location: 0),
                            .init(color: Color(white: 0.8), location: 0.55),
                            .init(color: Color(white: 0.5), location: 1)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: 2 * u
                    )
                )
                .frame(width: 2.6 * u, height: 2.6 * u)
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 0.7 * u, height: 0.7 * u)
                .offset(x: -0.4 * u, y: -0.5 * u)
            Circle()
                .fill(outline.opacity(0.5))
                .frame(width: 0.9 * u, height: 0.9 * u)
                .offset(y: 0.6 * u)
        }
        .offset(x: point.x * u, y: point.y * u)
    }

    // MARK: Effect trail — static particles matching the equipped delete burst

    @ViewBuilder private var fxLayer: some View {
        if let fx = item(.effect) {
            fxParticles(id: fx.id)
                .transition(.opacity)
        }
    }

    @ViewBuilder private func fxParticles(id: String) -> some View {
        switch id {
        case "fx.sparks":
            fxGlyph("diamond.fill", .questAmber, size: 6, at: CGPoint(x: -34, y: -52))
            fxGlyph("diamond.fill", .questAmber, size: 4, at: CGPoint(x: -42, y: -40))
            fxGlyph("circle.fill", .questAmber, size: 3, at: CGPoint(x: -26, y: -60))
        case "fx.filmstrip":
            fxGlyph("rectangle.fill", .videoSapphire, size: 7, at: CGPoint(x: -36, y: -52))
            fxGlyph("rectangle.fill", .videoSapphire, size: 5, at: CGPoint(x: -44, y: -38))
            fxGlyph("rectangle.fill", .videoSapphire, size: 4, at: CGPoint(x: -28, y: -62))
        case "fx.aurora":
            Capsule()
                .fill(Color.xpViolet.opacity(0.5))
                .frame(width: 12 * u, height: 2.4 * u)
                .rotationEffect(.degrees(-30))
                .offset(x: -36 * u, y: -52 * u)
            Capsule()
                .fill(Color.videoSapphire.opacity(0.45))
                .frame(width: 9 * u, height: 2 * u)
                .rotationEffect(.degrees(-30))
                .offset(x: -44 * u, y: -40 * u)
        case "fx.spectral":
            WispShape()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.92), Color(white: 0.72).opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(WispShape().stroke(outline.opacity(0.4), lineWidth: 0.8 * u))
                .frame(width: 9 * u, height: 12 * u)
                .offset(x: -36 * u, y: -50 * u)
            WispShape()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.88), Color(white: 0.7).opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(WispShape().stroke(outline.opacity(0.35), lineWidth: 0.7 * u))
                .frame(width: 6.5 * u, height: 8.5 * u)
                .offset(x: -44 * u, y: -36 * u)
        case "fx.confetti":
            fxSquare(.questAmber, size: 4.5, at: CGPoint(x: -34, y: -54), angle: 18)
            fxSquare(.gemEmerald, size: 3.5, at: CGPoint(x: -43, y: -42), angle: -24)
            fxSquare(.combatCrimson, size: 3.5, at: CGPoint(x: -27, y: -61), angle: 40)
            fxSquare(.videoSapphire, size: 3, at: CGPoint(x: -48, y: -52), angle: -10)
        case "fx.hearts":
            fxGlyph("heart.fill", .combatCrimson, size: 7, at: CGPoint(x: -35, y: -52))
            fxGlyph("heart.fill", .combatCrimson, size: 5, at: CGPoint(x: -44, y: -40))
            fxGlyph("heart.fill", .combatCrimson.opacity(0.7), size: 3.5, at: CGPoint(x: -27, y: -61))
        default:
            EmptyView()
        }
    }

    private func fxGlyph(_ symbol: String, _ color: Color, size: CGFloat, at point: CGPoint) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * u, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [color.lighter(0.3), color.darker(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(x: point.x * u, y: point.y * u)
    }

    private func fxSquare(_ color: Color, size: CGFloat, at point: CGPoint, angle: Double) -> some View {
        RoundedRectangle(cornerRadius: 0.8 * u, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color.lighter(0.3), color.darker(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * u, height: size * u)
            .rotationEffect(.degrees(angle))
            .offset(x: point.x * u, y: point.y * u)
    }

    // MARK: Pet

    @ViewBuilder private var petLayer: some View {
        if item(.pet) != nil {
            petModel
                .offset(x: -46 * u, y: 48 * u)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }

    @ViewBuilder private var petModel: some View {
        switch item(.pet)?.id {
        case "pet.owl":
            // Nocturne Owl: feathered dome, lit chest, ringed eyes, amber beak.
            ZStack {
                ear(x: -5)
                ear(x: 5)
                orb(Ellipse(), petColor, radius: 9, lineWidth: 2.0)
                    .frame(width: 17 * u, height: 16 * u)
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [petColor.lighter(0.35), petColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8 * u, height: 7 * u)
                    .offset(y: 4 * u)
                // Chest feather chevrons.
                VStack(spacing: 1.4 * u) {
                    ChevronShape()
                        .fill(Color.black.opacity(0.14))
                        .frame(width: 5.5 * u, height: 2 * u)
                        .rotationEffect(.degrees(180))
                    ChevronShape()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 4.2 * u, height: 1.6 * u)
                        .rotationEffect(.degrees(180))
                }
                .offset(y: 4 * u)
                owlEye(x: -3.6)
                owlEye(x: 3.6)
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 4 * u, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.questAmber.lighter(0.3), Color.questAmber.darker(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: 2.5 * u)
            }
        case "pet.reel":
            // Reel Spirit: machined sapphire disc with a bright hub ring.
            ZStack {
                orb(Circle(), petColor, radius: 8.5, lineWidth: 2.0)
                    .frame(width: 15 * u, height: 15 * u)
                Circle()
                    .stroke(Color.white.opacity(0.45), lineWidth: 1 * u)
                    .frame(width: 10 * u, height: 10 * u)
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.7 * u)
                    .frame(width: 7.2 * u, height: 7.2 * u)
                Circle().fill(outline).frame(width: 3.4 * u, height: 3.4 * u)
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 1 * u, height: 1 * u)
                    .offset(x: -0.6 * u, y: -0.6 * u)
                sprocketHole(angle: 0)
                sprocketHole(angle: 120)
                sprocketHole(angle: 240)
            }
        case "pet.beachSpirit":
            // Beach Spirit: aqua dome with a foam cap and a dark eye.
            ZStack {
                ear(x: -4.5)
                ear(x: 4.5)
                orb(Circle(), petColor, radius: 8.5, lineWidth: 2.0)
                    .frame(width: 15 * u, height: 15 * u)
                Capsule()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 10 * u, height: 2.6 * u)
                    .offset(y: -4.5 * u)
                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 5.5 * u, height: 1.6 * u)
                    .offset(x: -2 * u, y: -6.3 * u)
                Circle().fill(outline).frame(width: 2.6 * u, height: 2.6 * u).offset(x: -3 * u, y: -0.5 * u)
                Circle().fill(outline).frame(width: 2.6 * u, height: 2.6 * u).offset(x: 3 * u, y: -0.5 * u)
                Circle().fill(Color.white.opacity(0.7)).frame(width: 0.8 * u, height: 0.8 * u).offset(x: -3.6 * u, y: -1.1 * u)
                Circle().fill(Color.white.opacity(0.7)).frame(width: 0.8 * u, height: 0.8 * u).offset(x: 2.4 * u, y: -1.1 * u)
            }
        default:
            // Pixel Familiar: shaded dome, ears, curling tail.
            ZStack {
                ear(x: -4.5)
                ear(x: 4.5)
                // Tail curling behind on the ground.
                Capsule()
                    .fill(petColor.darker(0.25))
                    .frame(width: 9 * u, height: 2 * u)
                    .rotationEffect(.degrees(24))
                    .offset(x: 8 * u, y: 6 * u)
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 5 * u, height: 0.8 * u)
                    .rotationEffect(.degrees(24))
                    .offset(x: 8.4 * u, y: 5.4 * u)
                orb(Circle(), petColor, radius: 8.5, lineWidth: 2.0)
                    .frame(width: 15 * u, height: 15 * u)
                Ellipse()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 7 * u, height: 4 * u)
                    .offset(y: 4.2 * u)
                Circle().fill(outline).frame(width: 2.8 * u, height: 2.8 * u).offset(x: -3.2 * u, y: -1 * u)
                Circle().fill(outline).frame(width: 2.8 * u, height: 2.8 * u).offset(x: 3.2 * u, y: -1 * u)
                Circle().fill(Color.white).frame(width: 1 * u, height: 1 * u).offset(x: -2.6 * u, y: -1.8 * u)
                Circle().fill(Color.white).frame(width: 1 * u, height: 1 * u).offset(x: 3.8 * u, y: -1.8 * u)
            }
        }
    }

    private func owlEye(x: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.95))
                .overlay(Circle().stroke(outline, lineWidth: 1 * u))
                .frame(width: 5.6 * u, height: 5.6 * u)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [charcoal, outline],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: 3 * u
                    )
                )
                .frame(width: 3 * u, height: 3 * u)
                .offset(x: 0.4 * u, y: 0.2 * u)
            Circle()
                .fill(Color.white)
                .frame(width: 1 * u, height: 1 * u)
                .offset(x: -0.4 * u, y: -0.6 * u)
        }
        .offset(x: x * u, y: -1 * u)
    }

    private func ear(x: CGFloat) -> some View {
        Image(systemName: "arrowtriangle.up.fill")
            .resizable()
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: petColor.lighter(0.2), location: 0),
                        .init(color: petColor, location: 0.5),
                        .init(color: petColor.darker(0.35), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
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

/// Four-point diamond used for rune emblems, gems, and catchlights.
private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
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
            to: CGPoint(x: rect.maxX - w * 0.02, y: rect.maxY),
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

/// Upward-pointing chevron band used on the Oathbreaker's blade and the Arcane Edge.
private struct ChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h = rect.height
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.5))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.5))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.5))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Classic heater shield: gently arced top, sides curving to a bottom point.
private struct HeaterShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.16))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - w * 0.04, y: rect.minY + h * 0.16),
            control: CGPoint(x: rect.midX, y: rect.minY - h * 0.02)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - w * 0.01, y: rect.minY + h * 0.66)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.16),
            control: CGPoint(x: rect.minX + w * 0.01, y: rect.minY + h * 0.66)
        )
        path.closeSubpath()
        return path
    }
}

/// Elongated hexagonal crystal for the default shard weapon.
private struct CrystalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.28))
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.08, y: rect.maxY - h * 0.06))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.08, y: rect.maxY - h * 0.06))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.28))
        path.closeSubpath()
        return path
    }
}

/// Soft teardrop wisp used by the Spectral Wisps effect.
private struct WispShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.55),
            control: CGPoint(x: rect.maxX - w * 0.05, y: rect.minY + h * 0.2)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX + w * 0.1, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.55),
            control: CGPoint(x: rect.minX - w * 0.1, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.2)
        )
        path.closeSubpath()
        return path
    }
}

private extension Color {
    /// Returns a lighter variant by blending toward white.
    func lighter(_ amount: Double) -> Color {
        mix(with: .white, by: amount)
    }

    /// Returns a darker variant by blending toward black.
    func darker(_ amount: Double) -> Color {
        mix(with: .black, by: amount)
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
