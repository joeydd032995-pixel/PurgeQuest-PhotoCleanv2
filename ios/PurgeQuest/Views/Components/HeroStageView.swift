//
//  HeroStageView.swift
//  PurgeQuest
//
//  The hero standing on a pedestal with a pool of light behind. `height` is the hero's own height,
//  not a canvas: the figure is the subject, so it is sized directly.
//

import SwiftUI

struct HeroStageView: View {
    let hero: Hero
    var equipped: [CosmeticItem] = []
    /// Draft appearance override, as in the Forge.
    var appearance: HeroAppearance? = nil
    /// Height of the standing hero.
    var height: CGFloat = 120
    /// Tints the light and the pedestal's rim. A race's accent reads best.
    var accent: Color = .questAmber
    var isAnimated: Bool = true

    private var raceName: String { (appearance?.race ?? hero.race).displayName }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Light pooling behind the hero. One still ellipse.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.22), accent.opacity(0)],
                        center: .center, startRadius: 0, endRadius: height * 0.75
                    )
                )
                .frame(width: height * 1.5, height: height * 1.25)

            // The pedestal the feet rest on.
            Ellipse()
                .fill(Color.dungeonVoid.opacity(0.55))
                .overlay(Ellipse().strokeBorder(accent.opacity(0.35), lineWidth: 1))
                .frame(width: height * 0.8, height: height * 0.16)
                .offset(y: height * 0.06)

            HeroSpriteView(
                hero: hero, appearance: appearance, equipped: equipped,
                size: height, isAnimated: isAnimated, framing: .body
            )
            .padding(.bottom, height * 0.04)
        }
        .frame(width: height * 1.5, height: height * 1.3, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(raceName) hero")
    }
}
