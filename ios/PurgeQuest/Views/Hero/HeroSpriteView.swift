//
//  HeroSpriteView.swift
//  PurgeQuest
//
//  SwiftUI wrapper around SpriteEngine: renders the hero's illustrated race
//  sprite with equipped weapon/shield overlays. Loops the idle animation at
//  ~9fps when animated, and can play the attack animation once via
//  `attackPulse`. Falls back to the race's SF Symbol when art is missing.
//

import SwiftUI
import Combine

struct HeroSpriteView: View {
    let hero: Hero
    /// Draft appearance override for live editor previews.
    var appearance: HeroAppearance? = nil
    var equipped: [CosmeticItem] = []
    /// Height of the rendered sprite.
    var size: CGFloat = 200
    var isAnimated: Bool = true
    /// Increment to play the race's attack animation once.
    var attackPulse: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var idleFrame: Int = 0
    @State private var attackFrame: Int? = nil

    private var look: HeroAppearance { appearance ?? hero.appearance }
    private var race: HeroRace { look.race ?? hero.race }
    private var variant: Int { min(max(look.paintVariant, 1), race.variantCount) }

    private static let heartbeat = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    private var animationName: String { attackFrame != nil ? race.attackAnimationName : "Idle" }
    private var frameIndex: Int { attackFrame ?? idleFrame }

    private var weaponResource: String? {
        guard let item = equipped.first(where: { $0.type == .weapon }) else { return nil }
        return GearCatalog.design(id: item.id)?.resourceName
    }

    private var shieldResource: String? {
        guard let item = equipped.first(where: { $0.type == .shield }) else { return nil }
        return GearCatalog.design(id: item.id)?.resourceName
    }

    var body: some View {
        Group {
            if let image = SpriteRenderer.shared.frame(
                race: race,
                variant: variant,
                animation: animationName,
                frameIndex: frameIndex,
                appearance: look,
                weaponResource: weaponResource,
                shieldResource: shieldResource,
                titanWeapon: hero.titanWeaponUnlocked
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: race.symbol)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(race.accent)
                    .frame(width: size, height: size)
            }
        }
        .frame(height: size)
        .onReceive(Self.heartbeat) { _ in
            guard isAnimated, !reduceMotion else { return }
            if let current = attackFrame {
                let count = SpriteRenderer.shared.frameCount(race: race, variant: variant, animation: race.attackAnimationName)
                if current + 1 >= max(count, 1) {
                    attackFrame = nil
                } else {
                    attackFrame = current + 1
                }
            } else {
                let count = SpriteRenderer.shared.frameCount(race: race, variant: variant, animation: "Idle")
                guard count > 0 else { return }
                idleFrame = (idleFrame + 1) % count
            }
        }
        .onChange(of: attackPulse) { _, newValue in
            guard isAnimated, !reduceMotion, newValue > 0 else { return }
            guard SpriteRenderer.shared.frameCount(race: race, variant: variant, animation: race.attackAnimationName) > 0 else { return }
            attackFrame = 0
        }
        .task(id: "\(race.rawValue)-\(variant)") {
            // Warm the document + first frame so the first appearance doesn't hitch.
            _ = SpriteRenderer.shared.document(race: race, variant: variant)
        }
        .accessibilityLabel("\(race.displayName) hero sprite")
    }
}
