//
//  CelebrationFX.swift
//  PurgeQuest
//
//  One-file celebration primitives (SwiftPieces-style, zero dependencies):
//
//  - `.unlockBurst(trigger:)` — angular shard burst, expanding ring, and a
//    spring pop for the Armory tile that just got purchased.
//  - `.forgePaintFlash(trigger:)` — a soft light sweep and gentle scale tick
//    on the Forge preview when a paint job, dye, or colour lands.
//
//  Both respect Reduce Motion by collapsing to a plain crossfade with no
//  scale or particle motion, and both render nothing until first triggered.
//

import SwiftUI

// MARK: - Shard burst

/// One-shot angular shard burst with an expanding ring, TimelineView-driven.
/// Fires whenever `trigger` increments to a value greater than zero.
private struct ShardBurstView: View {
    let trigger: Int
    var palette: [Color]
    var duration: Double = 0.9

    @State private var startedAt: Date? = nil
    @State private var shards: [Shard] = []

    private struct Shard: Identifiable {
        let id = UUID()
        let angle: Double
        let speed: CGFloat
        let length: CGFloat
        let width: CGFloat
        let spin: Double
        let color: Color
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 60)) { context in
                let progress: Double = {
                    guard let start = startedAt else { return 1.0 }
                    return min(1.0, context.date.timeIntervalSince(start) / duration)
                }()
                ZStack {
                    ForEach(shards) { shard in
                        RoundedRectangle(cornerRadius: shard.width / 2)
                            .fill(shard.color)
                            .frame(width: shard.width, height: shard.length)
                            .rotationEffect(.degrees(shard.spin * progress))
                            .offset(
                                x: cos(shard.angle) * shard.speed * eased(progress),
                                y: sin(shard.angle) * shard.speed * eased(progress)
                                    + CGFloat(progress * progress) * 60
                            )
                            .opacity((1.0 - progress) * 0.95)
                    }
                    Circle()
                        .stroke((palette.first ?? .questAmber).opacity(0.8), lineWidth: 2.5 * (1 - progress))
                        .frame(width: 34 + 150 * progress, height: 34 + 150 * progress)
                        .opacity((1 - progress) * 0.55)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, newValue in
            guard newValue > 0 else { return }
            spawn()
        }
    }

    /// Ease-out so shards leap out and then settle.
    private func eased(_ t: Double) -> Double {
        1 - pow(1 - t, 2.2)
    }

    private func spawn() {
        startedAt = Date()
        var new: [Shard] = []
        for _ in 0..<22 {
            let angle = Double.random(in: 0...(2 * .pi))
            new.append(Shard(
                angle: angle,
                speed: CGFloat.random(in: 70...170),
                length: CGFloat.random(in: 9...18),
                width: CGFloat.random(in: 2.5...4.5),
                spin: Double.random(in: -260...260),
                color: palette.randomElement() ?? .questAmber
            ))
        }
        shards = new
    }
}

// MARK: - Unlock burst modifier

private struct UnlockBurstModifier: ViewModifier {
    let trigger: Int
    var palette: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(popped && !reduceMotion ? 1.05 : 1)
            .overlay {
                if !reduceMotion {
                    ShardBurstView(trigger: trigger, palette: palette)
                }
            }
            .onChange(of: trigger) { _, newValue in
                guard newValue > 0, !reduceMotion else { return }
                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { popped = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 220_000_000)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { popped = false }
                }
            }
    }
}

// MARK: - Forge paint flash modifier

private struct PaintFlashModifier: ViewModifier {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flashing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(flashing && !reduceMotion ? 1.015 : 1)
            .overlay {
                // Light sweep: brighter at the top, gone by the bottom.
                LinearGradient(
                    colors: [.white.opacity(0.20), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .opacity(flashing ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .onChange(of: trigger) { _, newValue in
                guard newValue > 0 else { return }
                withAnimation(.easeOut(duration: reduceMotion ? 0.25 : 0.10)) { flashing = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: reduceMotion ? 260_000_000 : 130_000_000)
                    withAnimation(.easeOut(duration: 0.3)) { flashing = false }
                }
            }
    }
}

// MARK: - Convenience

extension View {
    /// Celebrates a purchase on this view: shard burst + ring + spring pop.
    /// Pass a shared tick that increments on each unlock; the burst only
    /// fires when the tick becomes this view's own positive value.
    func unlockBurst(trigger: Int, palette: [Color] = [.questAmber, .gemEmerald, .combatCrimson]) -> some View {
        modifier(UnlockBurstModifier(trigger: trigger, palette: palette))
    }

    /// A quick light sweep + scale tick on the Forge preview when the
    /// player applies a paint job, dye, or colour.
    func forgePaintFlash(trigger: Int) -> some View {
        modifier(PaintFlashModifier(trigger: trigger))
    }
}
