//
//  CharacterAvatarView.swift
//  PurgeQuest
//
//  The hero's avatar: a chibi mini-figure on a flat engraved-frame medallion,
//  with small square-framed tags for each equipped wearable slot. Gear worn by
//  the figure changes live with equipped items.
//

import SwiftUI

struct CharacterAvatarView: View {
    let hero: Hero
    let equipped: [CosmeticItem]
    var size: CGFloat = 210

    private var archetype: CharacterArchetype { hero.archetype }

    private var accent: Color { archetype == .knight ? .questAmber : .xpViolet }

    private func item(for type: CosmeticType) -> CosmeticItem? {
        equipped.first { $0.type == type }
    }

    var body: some View {
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

            MiniAvatarView(hero: hero, equipped: equipped, size: size)
                .frame(width: size * 0.62, height: size * 0.72)

            if let head = item(for: .head) {
                badge(head, tint: .questAmber)
                    .offset(y: -size * 0.52)
            }
            if let skin = item(for: .skin) {
                badge(skin, tint: .xpViolet)
                    .offset(x: -size * 0.52, y: -size * 0.22)
            }
            if let effect = item(for: .effect) {
                badge(effect, tint: .questAmberDeep)
                    .offset(x: size * 0.52, y: -size * 0.22)
            }
            if let pet = item(for: .pet) {
                badge(pet, tint: .gemEmerald)
                    .offset(x: -size * 0.48, y: size * 0.42)
            }
            if let weapon = item(for: .weapon) {
                badge(weapon, tint: .combatCrimson)
                    .offset(x: size * 0.48, y: size * 0.42)
            }
        }
        .frame(width: size + 120, height: size + 100)
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
}
