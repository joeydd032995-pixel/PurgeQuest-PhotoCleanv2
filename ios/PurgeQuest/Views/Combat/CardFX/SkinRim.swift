//
//  SkinRim.swift
//  PurgeQuest
//
//  The frame treatment of a family skin (design section 5). It is drawn on the frame's rim and nowhere else: the
//  canvas first clips to the ring between the frame's outer edge and the photo's edge, so nothing it draws can reach
//  the picture. Every shape is deterministic (seeded from the card's id), so a card looks the same each time. The
//  first version drew hairlines on a 4 pt rim and was almost invisible in the tour; this one has a wider rim (see
//  `FamilySkinKind.extraRim`), a wash of the monster's accent, and heavier, larger marks.
//

import SwiftUI

struct SkinRim: View {
    let kind: FamilySkinKind
    /// The card's id; seeds every crack, chip and notch.
    let seedKey: String
    /// The monster's accent. A wash of it over the rim ties the frame to its family (the design allows a family's hue
    /// on the frame and the edge layer, never on the photo, a chip or a control).
    let accent: Color
    /// Degrees the light swings with the card's tilt (moves the Duplicate Dragons' glint).
    let highlightShift: Double
    /// 0...1 pressure cracks on the Storage Behemoths' rim, from the drag.
    let crack: Double
    let outerRadius: CGFloat
    let rim: CGFloat

    var body: some View {
        Canvas { context, size in
            draw(into: &context, size: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// How strongly the accent washes the rim, per skin.
    private var washAlpha: Double {
        switch kind {
        case .dragons:   return 0.30
        case .undead:    return 0.34
        case .relics:    return 0.24
        case .behemoths: return 0.20
        case .phantoms:  return 0.32
        case .glitch:    return 0.26
        }
    }

    private func draw(into context: inout GraphicsContext, size: CGSize) {
        let outerRect = CGRect(origin: .zero, size: size)
        let innerRect = outerRect.insetBy(dx: rim, dy: rim)
        let outerCorner = CGSize(width: outerRadius, height: outerRadius)
        let innerCorner = CGSize(width: max(0, outerRadius - rim), height: max(0, outerRadius - rim))
        var ring = Path()
        ring.addRoundedRect(in: outerRect, cornerSize: outerCorner)
        ring.addRoundedRect(in: innerRect, cornerSize: innerCorner)
        context.clip(to: ring, style: FillStyle(eoFill: true))

        context.fill(Path(outerRect), with: .color(accent.opacity(washAlpha)))

        let seed = SeededGeometry(key: seedKey)
        switch kind {
        case .dragons:
            drawScales(&context, size: size, outerRect: outerRect)
        case .undead:
            drawChips(&context, size: size, seed: seed, innerRect: innerRect, innerCorner: innerCorner)
        case .relics:
            drawCracks(&context, size: size, seed: seed, count: 10, amount: 1, color: Color.black.opacity(0.6),
                       base: 0, reach: 16, lineWidth: 1.1)
            drawCornerLight(&context, size: size, outerRect: outerRect)
        case .behemoths:
            drawHeavyBevel(&context, size: size, outerRect: outerRect, innerRect: innerRect, outerCorner: outerCorner, innerCorner: innerCorner)
            drawCracks(&context, size: size, seed: seed, count: 8, amount: crack, color: Color.black.opacity(0.7),
                       base: 100, reach: 14, lineWidth: 1.3)
        case .phantoms:
            drawGlass(&context, size: size, outerRect: outerRect, outerCorner: outerCorner)
        case .glitch:
            drawNotches(&context, size: size, seed: seed)
            drawChromaticSplit(&context, outerRect: outerRect, outerCorner: outerCorner)
        }
    }

    /// A point on the rim's midline; `t` runs 0 up to 1 once around the frame.
    private func rimPoint(_ t: Double, size: CGSize) -> CGPoint {
        let half: CGFloat = rim / 2
        let w: CGFloat = size.width - rim
        let h: CGFloat = size.height - rim
        let d: CGFloat = CGFloat(t) * 2 * (w + h)
        if d < w { return CGPoint(x: half + d, y: half) }
        if d < w + h { return CGPoint(x: half + w, y: half + (d - w)) }
        if d < 2 * w + h { return CGPoint(x: half + w - (d - w - h), y: half + h) }
        return CGPoint(x: half, y: half + h - (d - 2 * w - h))
    }

    // MARK: Duplicate Dragons: overlapping scales and a silver-gold glint that follows the tilt

    private func drawScales(_ context: inout GraphicsContext, size: CGSize, outerRect: CGRect) {
        let count = 200
        let radius: CGFloat = 3.6
        for i in 0..<count {
            let p = rimPoint(Double(i) / Double(count), size: size)
            let upper = Path { path in
                path.addArc(center: p, radius: radius, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            }
            context.stroke(upper, with: .color(Color.white.opacity(0.55)), lineWidth: 1.1)
            let lowerCenter = CGPoint(x: p.x + 1.8, y: p.y + 2.2)
            let lower = Path { path in
                path.addArc(center: lowerCenter, radius: radius, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            }
            context.stroke(lower, with: .color(Color.black.opacity(0.38)), lineWidth: 1.0)
        }
        let shift: CGFloat = CGFloat(highlightShift) / 100
        let glintColors: [Color] = [Color.clear, Color.white.opacity(0.6), Color.clear]
        let glint = GraphicsContext.Shading.linearGradient(
            Gradient(colors: glintColors),
            startPoint: CGPoint(x: size.width * (0.15 + shift), y: 0),
            endPoint: CGPoint(x: size.width * (0.55 + shift), y: size.height)
        )
        context.fill(Path(outerRect), with: glint)
    }

    // MARK: Clutter Undead: a worn, chipped rim with a darkened inner edge

    private func drawChips(_ context: inout GraphicsContext, size: CGSize, seed: SeededGeometry,
                           innerRect: CGRect, innerCorner: CGSize) {
        for i in 0..<46 {
            let p = rimPoint(seed.value(i * 3), size: size)
            let r: CGFloat = CGFloat(0.8 + 1.8 * seed.value(i * 3 + 1))
            let isDark: Bool = seed.value(i * 3 + 2) < 0.7
            let blob = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            let color: Color = isDark ? Color.black.opacity(0.55) : Color.white.opacity(0.25)
            context.fill(blob, with: .color(color))
        }
        let decay = Path(roundedRect: innerRect, cornerSize: innerCorner)
        context.stroke(decay, with: .color(Color.black.opacity(0.4)), lineWidth: 2.4)
    }

    // MARK: Archive Relics: cracks and one corner of light. Storage Behemoths: pressure cracks from the drag.

    private func drawCracks(_ context: inout GraphicsContext, size: CGSize, seed: SeededGeometry,
                            count: Int, amount: Double, color: Color, base: Int, reach: CGFloat, lineWidth: CGFloat) {
        guard amount > 0 else { return }
        for i in 0..<count {
            let start = rimPoint(seed.value(base + i * 4), size: size)
            let dx: CGFloat = CGFloat(seed.value(base + i * 4 + 1) - 0.5) * reach
            let dy: CGFloat = CGFloat(seed.value(base + i * 4 + 2) - 0.5) * reach
            let mid = CGPoint(x: start.x + dx, y: start.y + dy)
            let end = CGPoint(x: mid.x + dy * 0.8, y: mid.y - dx * 0.8)
            var path = Path()
            path.move(to: start)
            path.addLine(to: mid)
            path.addLine(to: end)
            let drawn: Path = amount >= 1 ? path : path.trimmedPath(from: 0, to: CGFloat(amount))
            context.stroke(drawn, with: .color(color), lineWidth: lineWidth)
        }
    }

    private func drawCornerLight(_ context: inout GraphicsContext, size: CGSize, outerRect: CGRect) {
        let colors: [Color] = [Color.white.opacity(0.32), Color.clear]
        let band = GraphicsContext.Shading.linearGradient(
            Gradient(colors: colors),
            startPoint: CGPoint.zero,
            endPoint: CGPoint(x: size.width * 0.45, y: size.height * 0.45)
        )
        context.fill(Path(outerRect), with: band)
    }

    // MARK: Storage Behemoths: a heavy bevel and four rivets

    private func drawHeavyBevel(_ context: inout GraphicsContext, size: CGSize, outerRect: CGRect, innerRect: CGRect,
                                outerCorner: CGSize, innerCorner: CGSize) {
        let shadowEdge = Path(roundedRect: innerRect.insetBy(dx: -1, dy: -1), cornerSize: innerCorner)
        context.stroke(shadowEdge, with: .color(Color.black.opacity(0.65)), lineWidth: 2.6)
        let litEdge = Path(roundedRect: outerRect.insetBy(dx: 0.8, dy: 0.8), cornerSize: outerCorner)
        context.stroke(litEdge, with: .color(Color.white.opacity(0.45)), lineWidth: 1.6)
        let half: CGFloat = rim / 2
        let corners: [CGPoint] = [
            CGPoint(x: half, y: half),
            CGPoint(x: size.width - half, y: half),
            CGPoint(x: half, y: size.height - half),
            CGPoint(x: size.width - half, y: size.height - half)
        ]
        for center in corners {
            let rivet = Path(ellipseIn: CGRect(x: center.x - 2.6, y: center.y - 2.6, width: 5.2, height: 5.2))
            context.fill(rivet, with: .color(Color.white.opacity(0.55)))
            context.stroke(rivet, with: .color(Color.black.opacity(0.65)), lineWidth: 0.8)
        }
    }

    // MARK: Video Phantoms: a glassy rim (the cool glow sits outside the frame, in ExhibitFrame)

    private func drawGlass(_ context: inout GraphicsContext, size: CGSize, outerRect: CGRect, outerCorner: CGSize) {
        let colors: [Color] = [Color.white.opacity(0.42), Color.white.opacity(0.06)]
        let glass = GraphicsContext.Shading.linearGradient(
            Gradient(colors: colors),
            startPoint: CGPoint.zero,
            endPoint: CGPoint(x: 0, y: size.height)
        )
        context.fill(Path(outerRect), with: glass)
        let edge = Path(roundedRect: outerRect.insetBy(dx: 0.8, dy: 0.8), cornerSize: outerCorner)
        context.stroke(edge, with: .color(Color.white.opacity(0.55)), lineWidth: 1.4)
    }

    // MARK: Glitchborn: notches cut into the rim, and a chromatic split on the frame stroke only

    private func drawNotches(_ context: inout GraphicsContext, size: CGSize, seed: SeededGeometry) {
        let count: Int = seed.value(0) > 0.5 ? 6 : 5
        for i in 0..<count {
            let p = rimPoint(seed.value(10 + i), size: size)
            let w: CGFloat = CGFloat(7 + 8 * seed.value(20 + i))
            let notch = Path(CGRect(x: p.x - w / 2, y: p.y - rim / 2, width: w, height: rim))
            context.fill(notch, with: .color(Color.black.opacity(0.8)))
        }
    }

    private func drawChromaticSplit(_ context: inout GraphicsContext, outerRect: CGRect, outerCorner: CGSize) {
        let outline = Path(roundedRect: outerRect.insetBy(dx: 0.8, dy: 0.8), cornerSize: outerCorner)
        var warm = context
        warm.translateBy(x: 2.2, y: 0)
        warm.stroke(outline, with: .color(Color.glitchRose.opacity(0.75)), lineWidth: 1.6)
        var cool = context
        cool.translateBy(x: -2.2, y: 0)
        cool.stroke(outline, with: .color(Color.videoSapphire.opacity(0.75)), lineWidth: 1.6)
    }
}
