//
//  SkinEdgeLayer.swift
//  PurgeQuest
//
//  The family skins' moving parts (design section 5): slow motes, dust, wisps, glitch blocks, scale flakes, the
//  Phantoms' after-images, the Behemoths' stone chips. Everything is drawn in the two 10 pt bands at the card's left
//  and right edges, outside the frame: the canvas clips to those bands before it draws anything, so no particle or
//  ghost can ever be over the photo (the pure model's tests prove the particles, this clip covers the rest). Only
//  the front card runs a clock, and nothing runs under Reduce Motion or Low Power Mode.
//

import SwiftUI

struct SkinEdgeLayer: View {
    let kind: FamilySkinKind
    /// The card's id; seeds every position.
    let seedKey: String
    let accent: Color
    let gate: FXGate
    let isFront: Bool
    /// The drag, in points, for the parts that follow the finger instead of a clock.
    let dragX: Double
    let dragY: Double
    /// 0...1 lift from the drag.
    let lift: Double
    /// When the card was committed, for the Behemoths' stone chips; nil before.
    let burstStart: Date?

    private static let burstSeconds: Double = 0.3

    var body: some View {
        let live: Bool = isFront && !gate.isStill
        let ticking: Bool = live && (kind.isAmbient || burstStart != nil)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !ticking)) { timeline in
            Canvas { context, size in
                draw(into: &context, size: size, now: timeline.date, live: live)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(into context: inout GraphicsContext, size: CGSize, now: Date, live: Bool) {
        // Clip first: the left and right bands only. A little extra outside the card for the chips that fly off.
        let band: CGFloat = CGFloat(EdgeParticles.bandWidth)
        var bands = Path()
        bands.addRect(CGRect(x: -40, y: 0, width: 40 + band, height: size.height))
        bands.addRect(CGRect(x: size.width - band, y: 0, width: 40 + band, height: size.height))
        context.clip(to: bands)
        guard live else { return }

        let seed = SeededGeometry(key: seedKey)
        let width = Double(size.width)
        let height = Double(size.height)

        if kind.isAmbient {
            let time: Double = now.timeIntervalSinceReferenceDate
            paint(EdgeParticles.ambient(kind: kind, seed: seed, time: time, width: width, height: height), into: &context)
        }
        paint(EdgeParticles.dragDriven(kind: kind, lift: lift, seed: seed, width: width, height: height), into: &context)
        if kind == .phantoms {
            drawGhosts(into: &context, size: size)
        }
        if kind == .behemoths, let start = burstStart {
            let progress: Double = min(1, max(0, now.timeIntervalSince(start) / Self.burstSeconds))
            paint(EdgeParticles.chips(kind: kind, progress: progress, seed: seed, width: width, height: height), into: &context)
        }
    }

    /// How much larger and stronger the particles are drawn than the model's numbers: the first tour's were specks.
    /// The model's positions are untouched, and the band clip at the top of `draw` still cuts everything at 10 pt.
    private static let sizeBoost: CGFloat = 1.6
    private static let alphaBoost: Double = 1.7

    private func paint(_ particles: [EdgeParticle], into context: inout GraphicsContext) {
        for (index, particle) in particles.enumerated() {
            let r: CGFloat = CGFloat(particle.radius) * Self.sizeBoost
            let rect = CGRect(x: CGFloat(particle.x) - r, y: CGFloat(particle.y) - r, width: r * 2, height: r * 2)
            let alpha: Double = min(1, particle.alpha * Self.alphaBoost)
            let color: Color = tint(for: index).opacity(alpha)
            if kind == .glitch || kind == .behemoths {
                context.fill(Path(rect), with: .color(color))
            } else {
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }

    private func tint(for index: Int) -> Color {
        switch kind {
        case .glitch:
            return index.isMultiple(of: 2) ? Color.glitchRose : Color.videoSapphire
        case .behemoths, .dragons:
            return Color.white
        case .undead, .relics, .phantoms:
            return accent
        }
    }

    /// Two faint after-images of the card's outline, trailing the drag. Only the part inside the bands shows.
    private func drawGhosts(into context: inout GraphicsContext, size: CGSize) {
        let ghosts = SkinDrag.ghosts(dx: dragX, dy: dragY, lift: lift)
        for ghost in ghosts {
            let rect = CGRect(
                x: 8 + CGFloat(ghost.dx),
                y: 8 + CGFloat(ghost.dy),
                width: size.width - 16,
                height: size.height - 16
            )
            let outline = Path(roundedRect: rect, cornerSize: CGSize(width: 12, height: 12))
            let alpha: Double = min(1, ghost.alpha * 4)
            context.stroke(outline, with: .color(accent.opacity(alpha)), lineWidth: 2.5)
        }
    }
}
