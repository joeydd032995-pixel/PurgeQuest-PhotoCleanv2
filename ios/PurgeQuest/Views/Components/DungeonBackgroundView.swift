//
//  DungeonBackgroundView.swift
//  PurgeQuest
//
//  Static tonal canvas: the palette's base (green-black or charcoal in Dark, cream in Light), a
//  faint vignette, and one soft pool of brand gold falling from the top edge, as if from a torch
//  above the screen. It is a few percent strong and never moves: no particles, no dot grids, no
//  animation anywhere on the canvas.
//

import SwiftUI

struct DungeonBackgroundView: View {
    var intensity: Double = 0.0   // Kept for call-site compatibility; the canvas is intentionally static.

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient.dungeonBackground
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.goldInk.opacity(colorScheme == .dark ? 0.10 : 0.06), Color.goldInk.opacity(0)],
                center: .top,
                startRadius: 0,
                endRadius: 420
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
        }
    }
}
