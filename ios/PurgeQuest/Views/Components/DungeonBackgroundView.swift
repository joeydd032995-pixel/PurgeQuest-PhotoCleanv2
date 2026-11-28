//
//  DungeonBackgroundView.swift
//  PurgeQuest
//
//  Static tonal canvas: the palette's base (green-black or charcoal in Dark, cream in Light), a faint vignette,
//  and one soft pool of brand gold falling from the top edge, as if from a torch above the screen's top left
//  (`LightSource`: the card's light, the panels' sheen and every shadow agree with it). In Dark the torch is a gold
//  light; in Light it is a warm wash and the side away from it shades a little deeper. It never moves: no particles,
//  no dot grids, no animation anywhere on the canvas.
//
//  The pool used to be drawn in the gold plate's dark-brown ink, so it shifted the Dark top edge by about two levels
//  and darkened the Light one: no light at all (docs/superpowers/specs/2026-11-28-atmosphere-and-light-design.md).
//

import SwiftUI

struct DungeonBackgroundView: View {
    var intensity: Double = 0.0   // Kept for call-site compatibility; the canvas is intentionally static.

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Every value is typed on its own line: one expression mixing Double, CGFloat and literals is more than the
        // compiler will type-check in reasonable time.
        let isDark: Bool = colorScheme == .dark
        let torch = Color(LightSource.torchColor(isDark: isDark))
        let torchAlpha: Double = LightSource.torchAlpha(isDark: isDark)
        let torchCenter = UnitPoint(x: CGFloat(LightSource.torchX), y: 0)
        let torchReach = CGFloat(LightSource.torchReach)
        let farShadeReach = CGFloat(LightSource.farShadeReach)
        ZStack {
            LinearGradient.dungeonBackground
                .ignoresSafeArea()

            RadialGradient(
                colors: [torch.opacity(torchAlpha), torch.opacity(0)],
                center: torchCenter,
                startRadius: 0,
                endRadius: torchReach
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            RadialGradient(
                colors: [.clear, .canvasVignette],
                center: .center,
                startRadius: 260,
                endRadius: 720
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Light only: the side away from the torch shades a little deeper. Dark keeps the vignette it has.
            if !isDark {
                RadialGradient(
                    colors: [.canvasVignette, .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: farShadeReach
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }
}
