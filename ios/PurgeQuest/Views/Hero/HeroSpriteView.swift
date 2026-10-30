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

    private var renderer: SpriteRenderer { SpriteRenderer.shared }
    private var attackAnimation: String { renderer.attackAnimation(race: race, variant: variant) }
    private var animationName: String { attackFrame != nil ? attackAnimation : "Idle" }
    private var frameIndex: Int { attackFrame ?? idleFrame }

    /// Held gear and headwear by catalog id; the renderer resolves art, grip fit, and Titan scaling.
    private var loadout: SpriteLoadout {
        SpriteLoadout(
            weaponID: equipped.first(where: { $0.type == .weapon })?.id,
            shieldID: equipped.first(where: { $0.type == .shield })?.id,
            titanWeapon: hero.titanWeaponUnlocked,
            gearMaterials: look.gearMaterials
        )
    }

    var body: some View {
        Group {
            if let frame = renderer.frame(
                race: race,
                variant: variant,
                animation: animationName,
                frameIndex: frameIndex,
                appearance: look,
                loadout: loadout
            ) {
                spriteImage(frame)
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
                let count = renderer.frameCount(race: race, variant: variant, animation: attackAnimation)
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
            guard renderer.frameCount(race: race, variant: variant, animation: attackAnimation) > 0 else { return }
            attackFrame = 0
        }
        .task(id: "\(race.rawValue)-\(variant)") {
            // Warm the document + first frame so the first appearance doesn't hitch.
            _ = SpriteRenderer.shared.document(race: race, variant: variant)
        }
        .accessibilityLabel("\(race.displayName) hero sprite")
    }

    /// Keeps the character the same size when a Titan blade enlarges the canvas: the extra
    /// canvas overflows the layout box instead of shrinking the hero to fit it.
    @ViewBuilder private func spriteImage(_ frame: SpriteFrame) -> some View {
        if frame.layout == .zero {
            Image(uiImage: frame.image)
                .resizable()
                .scaledToFit()
        } else {
            let base = renderer.canvasSize(race: race, variant: variant) ?? frame.image.size
            let k = CGFloat(SpriteCanvasLayout.pointsPerUnit(height: Double(size), baseHeight: Double(base.height)))
            Image(uiImage: frame.image)
                .resizable()
                .frame(width: frame.image.size.width * k, height: frame.image.size.height * k)
                .offset(x: -CGFloat(frame.layout.left) * k, y: -CGFloat(frame.layout.top) * k)
                .frame(width: base.width * k, height: size, alignment: .topLeading)
        }
    }
}
