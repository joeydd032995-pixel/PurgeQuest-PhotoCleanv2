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

    private var identity: HeroAppearance { appearance ?? hero.appearance }

    /// Tier derived from the most valuable equipped item; drives the plaque
    /// accent so the backdrop celebrates progression.
    private var tier: GearTier {
        HeroAppearance.gearTier(
            maxEquippedPrice: equipped.map(\.priceGems).max() ?? 0,
            hasPremium: equipped.contains { $0.isPremium }
        )
    }

    private var accent: Color { tier.accent }

    var body: some View {
        ZStack {
            backdrop
            HeroSpriteView(hero: hero, appearance: appearance, equipped: equipped, size: size * 0.8)
                .frame(width: size * 0.62, height: size * 0.72)

            if let head = equipped.first(where: { $0.type == .head }) {
                badge(head, tint: .questAmber)
                    .offset(y: -size * 0.52)
            }
            if let skin = equipped.first(where: { $0.type == .skin }) {
                badge(skin, tint: .xpViolet)
                    .offset(x: -size * 0.52, y: -size * 0.22)
            }
            if let effect = equipped.first(where: { $0.type == .effect }) {
                badge(effect, tint: .questAmberDeep)
                    .offset(x: size * 0.52, y: -size * 0.22)
            }
            if let pet = equipped.first(where: { $0.type == .pet }) {
                badge(pet, tint: .gemEmerald)
                    .offset(x: -size * 0.48, y: size * 0.42)
            }
            if let weapon = equipped.first(where: { $0.type == .weapon }) {
                badge(weapon, tint: .combatCrimson)
                    .offset(x: size * 0.48, y: size * 0.42)
            }
        }
        .frame(width: size + 120, height: size + 100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
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
            equipped.first { $0.type == type }?.name
        }
        let gear = worn.isEmpty ? "default gear" : worn.joined(separator: ", ")
        return "Hero \(hero.name), \(gear), \(tier.displayName) plaque backdrop"
    }
}
