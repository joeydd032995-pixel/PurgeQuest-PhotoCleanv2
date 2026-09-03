//
//  DungeonBackgroundView.swift
//  PurgeQuest
//
//  Static tonal canvas: flat steel base with a faint vignette. No radial glows,
//  drifting particles, or dot grids anywhere in the app.
//

import SwiftUI

struct DungeonBackgroundView: View {
    var intensity: Double = 0.0   // Kept for call-site compatibility; the canvas is intentionally static.

    var body: some View {
        ZStack {
            LinearGradient.dungeonBackground
                .ignoresSafeArea()

            RadialGradient(
                colors: [.clear, .black.opacity(0.35)],
                center: .center,
                startRadius: 260,
                endRadius: 720
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
