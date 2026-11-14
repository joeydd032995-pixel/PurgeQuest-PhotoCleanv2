//
//  CharacterAvatarView.swift
//  PurgeQuest
//
//  The hero's avatar: the mini figure on a backdrop chosen in the forge —
//  rarity plaque (accent reflects equipped gear tier), engraved medallion,
//  or heraldic banner — with small square-framed tags for each equipped
//  wearable slot. Gear and identity change live with the hero record; a
//  draft appearance can be injected for the forge's live preview.
//

import SwiftUI

struct CharacterAvatarView: View {
    let hero: Hero
    let equipped: [CosmeticItem]
    var size: CGFloat = 210
    /// Draft appearance override for live editor previews.
    var appearance: HeroAppearance? = nil

    /// What is worn and shown. Helm, chest, legs and hands items are not drawn or tagged in 1.0
    /// (`CosmeticType.hiddenFromHero`), and they do not set the plaque's tier either.
    private var shown: [CosmeticItem] { equipped.filter { $0.type.isShownOnHero } }

    private var identity: HeroAppearance { appearance ?? hero.appearance }

    /// Tier derived from the most valuable equipped item; drives the plaque
    /// accent so the backdrop celebrates progression.
    private var tier: GearTier {
        HeroAppearance.gearTier(
            maxEquippedPrice: shown.map(\.priceGems).max() ?? 0,
            hasPremium: shown.contains { $0.isPremium }
        )
    }

    private var accent: Color { tier.accent }

    var body: some View {
        ZStack {
            backdrop
            // The hero's own height is set here, not the canvas's: the figure stands 0.56 of the
            // portrait tall with its feet on the frame's bottom edge, which is the ground line the
            // pet below is placed on.
            HeroSpriteView(hero: hero, appearance: appearance, equipped: shown, size: size * 0.56, framing: .body)
                .frame(width: size * 0.62, height: size * 0.72, alignment: .bottom)
                .overlay(alignment: .bottom) { petCompanion }

            ForEach(AvatarBadgeLayout.slots, id: \.type) { slot in
                if let item = shown.first(where: { $0.type == slot.type }) {
                    badge(item, tint: badgeTint(for: slot.type))
                        .offset(x: size * slot.x, y: size * slot.y)
                }
            }
        }
        .frame(width: size + 120, height: size + 100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    /// The equipped companion hovering at the hero's lower left. MiniAvatarView
    /// owns the pet art (pixel sheets and vector drawings), so a figure-less
    /// instance supplies it, scaled to the hero sprite: its 132-unit hero
    /// matches this sprite's `size * 0.8`, and the 0.04 offset plants the pet
    /// on the sprite's ground line, which sits just below the layout frame.
    @ViewBuilder private var petCompanion: some View {
        if shown.contains(where: { $0.type == .pet }) {
            MiniAvatarView(
                hero: hero,
                equipped: shown,
                size: size * 0.8 * 200 / 132,
                appearance: appearance,
                showsFigure: false
            )
            .offset(y: size * 0.04)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Backdrops

    @ViewBuilder private var backdrop: some View {
        switch identity.backdropStyle {
        case .plaque:
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.dungeonStone.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accent.opacity(0.55), lineWidth: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accent.opacity(0.25), lineWidth: 1)
                        .padding(4)
                )
                .overlay(alignment: .topLeading) { plaqueStud }
                .overlay(alignment: .topTrailing) { plaqueStud }
                .overlay(alignment: .bottomLeading) { plaqueStud }
                .overlay(alignment: .bottomTrailing) { plaqueStud }
                .frame(width: size * 0.88, height: size * 0.94)
        case .medallion:
            ZStack {
                Circle()
                    .fill(Color.dungeonStone.opacity(0.75))
                    .frame(width: size - 14, height: size - 14)
                Circle()
                    .strokeBorder(accent.opacity(0.6), lineWidth: 2)
                    .frame(width: size, height: size)
                Circle()
                    .strokeBorder(accent.opacity(0.3), lineWidth: 1)
                    .frame(width: size - 8, height: size - 8)
            }
        case .banner:
            ZStack {
                BannerShape()
                    .fill(Color.dungeonStone.opacity(0.92))
                    .overlay(BannerShape().stroke(accent.opacity(0.55), lineWidth: 2))
                    .overlay(
                        BannerShape()
                            .stroke(accent.opacity(0.25), lineWidth: 1)
                            .padding(4)
                    )
                Image(systemName: hero.race.symbol)
                    .font(.system(size: size * 0.14, weight: .bold))
                    .foregroundStyle(accent.opacity(0.35))
                    .offset(y: size * 0.28)
            }
            .frame(width: size * 0.8, height: size * 0.98)
        }
    }

    /// Small carved stud anchoring a plaque corner.
    private var plaqueStud: some View {
        DiamondShape()
            .fill(accent.opacity(0.7))
            .frame(width: 7, height: 7)
            .padding(9)
    }

    // MARK: - Badges

    /// What you wear on your body is steel blue, the weapon is brick red, the rest keep their old hues.
    private func badgeTint(for type: CosmeticType) -> Color {
        switch type {
        case .head:                          return .questAmber
        case .skin:                          return .xpViolet
        case .effect:                        return .questAmberDeep
        case .pet:                           return .gemEmerald
        case .weapon:                        return .combatCrimson
        case .armor, .legs, .hands, .shield: return .videoSapphire
        case .upgrade:                       return .questAmber
        }
    }

    private func badge(_ item: CosmeticItem, tint: Color) -> some View {
        Image(systemName: item.iconName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.dungeonStoneLight)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.8), lineWidth: 1))
            )
            .accessibilityLabel("\(item.name) equipped")
    }

    private var accessibilitySummary: String {
        let worn = CosmeticType.allCases.compactMap { type -> String? in
            shown.first { $0.type == type }?.name
        }
        let gear = worn.isEmpty ? "default gear" : worn.joined(separator: ", ")
        return "Hero \(hero.name), \(gear), \(tier.displayName) plaque backdrop"
    }
}

/// Where the tag for each wearable slot sits around the backdrop, as a fraction of the avatar's `size` measured
/// from its centre. It is data so a test can prove every slot has a tag and no two tags overlap.
///
/// The shield tag is on the left and the weapon tag on the right because that is where the sprite holds them:
/// the sword is in the hand on the right of the screen, the shield in the one on the left.
nonisolated struct AvatarBadgeSlot: Equatable {
    let type: CosmeticType
    let x: Double
    let y: Double
}

nonisolated enum AvatarBadgeLayout {
    /// Side of one square tag, in points.
    static let tagSide: Double = 32

    /// No tags for head, armor, legs or hands: those items are hidden in 1.0 (`CosmeticType.hiddenFromHero`).
    static let slots: [AvatarBadgeSlot] = [
        AvatarBadgeSlot(type: .skin,   x: -0.52, y: -0.22),
        AvatarBadgeSlot(type: .effect, x:  0.52, y: -0.22),
        AvatarBadgeSlot(type: .shield, x: -0.52, y:  0.10),
        AvatarBadgeSlot(type: .pet,    x: -0.48, y:  0.42),
        AvatarBadgeSlot(type: .weapon, x:  0.48, y:  0.42)
    ]

    /// Slots that have a tag; `.upgrade` (the Titan Blade) is a property of the weapon, not something worn.
    static var taggedTypes: [CosmeticType] { slots.map(\.type) }
}
