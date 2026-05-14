//
//  ParticleEffectView.swift
//  PurgeQuest
//

import SwiftUI

/// One-shot particle burst, driven by a TimelineView. Set `trigger` to a new value to fire it.
struct ParticleBurstView: View {
    var trigger: Int
    var palette: [Color] = [.questAmber, .questAmberDeep, .combatCrimson]
    var symbol: String? = nil    // optional small symbol for film-strip-style bursts
    var origin: UnitPoint = .center
    var duration: Double = 0.8

    @State private var startedAt: Date? = nil
    @State private var particles: [Particle] = []

    private struct Particle: Identifiable {
        let id = UUID()
        let dx: CGFloat
        let dy: CGFloat
        let rotation: Double
        let scale: CGFloat
        let color: Color
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1/60)) { context in
                let now = context.date
                let progress: Double = {
                    guard let start = startedAt else { return 1.0 }
                    return min(1.0, now.timeIntervalSince(start) / duration)
                }()
                ZStack {
                    ForEach(particles) { p in
                        Group {
                            if let symbol {
                                Image(systemName: symbol)
                                    .font(.system(size: 16 * p.scale, weight: .bold))
                                    .foregroundStyle(p.color)
                            } else {
                                Circle()
                                    .fill(p.color)
                                    .frame(width: 6 * p.scale, height: 6 * p.scale)
                            }
                        }
                        .opacity(1.0 - progress)
                        .offset(
                            x: p.dx * CGFloat(progress) * 1.6,
                            y: p.dy * CGFloat(progress) * 1.6 + CGFloat(progress * progress) * 80
                        )
                        .rotationEffect(.degrees(p.rotation * progress))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .position(x: geo.size.width * origin.x, y: geo.size.height * origin.y)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            spawn()
        }
    }

    private func spawn() {
        startedAt = Date()
        var new: [Particle] = []
        for _ in 0..<28 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 60...160)
            new.append(Particle(
                dx: CGFloat(cos(angle)) * speed,
                dy: CGFloat(sin(angle)) * speed,
                rotation: Double.random(in: -360...360),
                scale: CGFloat.random(in: 0.6...1.4),
                color: palette.randomElement() ?? .questAmber
            ))
        }
        particles = new
    }
}
