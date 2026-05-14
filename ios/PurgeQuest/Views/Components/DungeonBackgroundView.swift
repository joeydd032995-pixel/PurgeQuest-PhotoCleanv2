//
//  DungeonBackgroundView.swift
//  PurgeQuest
//

import SwiftUI

struct DungeonBackgroundView: View {
    var intensity: Double = 0.0   // 0 = calm cool tones, 1 = warm danger
    @State private var swirl: Double = 0

    var body: some View {
        ZStack {
            LinearGradient.dungeonBackground
                .ignoresSafeArea()

            // Layer 1: ambient warm glow that intensifies with depth
            RadialGradient(
                colors: [
                    Color.questAmberDeep.opacity(0.18 + intensity * 0.25),
                    .clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 480
            )
            .ignoresSafeArea()
            .blendMode(.screen)

            // Layer 2: floor crimson glow that emerges in deeper rooms
            RadialGradient(
                colors: [
                    Color.combatCrimsonDeep.opacity(0.10 + intensity * 0.22),
                    .clear
                ],
                center: .bottom,
                startRadius: 10,
                endRadius: 520
            )
            .ignoresSafeArea()
            .blendMode(.screen)

            // Layer 3: faint stone vignette
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center,
                startRadius: 200,
                endRadius: 700
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Layer 4: drifting embers
            EmbersLayer(swirl: swirl, intensity: intensity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                swirl = 1
            }
        }
    }
}

private struct EmbersLayer: View {
    let swirl: Double
    let intensity: Double

    var body: some View {
        Canvas { ctx, size in
            let count = 28
            for i in 0..<count {
                let seed = Double(i)
                let x = (sin(seed * 1.31 + swirl * .pi * 2) * 0.45 + 0.5) * size.width
                let y = (1.0 - ((swirl + seed * 0.073).truncatingRemainder(dividingBy: 1.0))) * size.height
                let r = 1.5 + (i.isMultiple(of: 3) ? 1.5 : 0)
                let alpha = 0.18 + 0.25 * intensity
                let rect = CGRect(x: x, y: y, width: r * 2, height: r * 2)
                let color = i.isMultiple(of: 4) ? Color.combatCrimson : Color.questAmber
                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
            }
        }
    }
}
