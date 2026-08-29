//
//  CharacterAvatarView.swift
//  PurgeQuest
//

import SwiftUI

/// The hero's layered avatar: a chibi mini-figure on a glowing stage inside the
/// orb, with small badges for each equipped wearable slot orbiting the figure.
/// Gear worn by the figure changes live with equipped items.
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
                .fill(LinearGradient(
                    colors: [accent.opacity(0.7), .dungeonVoid.opacity(0.1)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: size + 110, height: size + 110)
                .blur(radius: 45)
                .opacity(0.65)

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .frame(width: size, height: size)

            Circle()
                .fill(Color.dungeonStone.opacity(0.75))
                .frame(width: size - 14, height: size - 14)

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
        .frame(width: size + 130, height: size + 110)
    }

    private func badge(_ item: CosmeticItem, tint: Color) -> some View {
        Image(systemName: item.iconName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(Color.dungeonStoneLight)
                    .overlay(Circle().stroke(tint.opacity(0.8), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
            )
            .accessibilityLabel("\(item.name) equipped")
    }
}
