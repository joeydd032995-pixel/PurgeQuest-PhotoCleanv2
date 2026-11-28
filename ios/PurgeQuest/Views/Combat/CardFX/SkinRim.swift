//
//  SkinRim.swift
//  PurgeQuest
//
//  The frame treatment of a family skin (design section 5). It is drawn on the frame's rim and nowhere else: the
//  canvas first clips to the ring between the frame's outer edge and the photo's edge, so nothing it draws can reach
//  the picture. Every shape is deterministic (seeded from the card's id), so a card looks the same each time. The
//  first version drew hairlines on a 4 pt rim and was almost invisible in the tour; the second added a wider rim and
//  a wash of the monster's accent; this third pass makes each family unmistakable at a glance (the 1:1 crops showed the
//  Behemoths and the Phantoms barely changed): a stone slab with seams, glass with a moving shimmer, scanlines and
//  slices, patina, rot.
//

import SwiftUI

struct SkinRim: View {
    let kind: FamilySkinKind
    /// The card's id; seeds every crack, chip and notch.
    let seedKey: String
    /// The monster's accent. A wash of it over the rim ties the frame to its family (the design allows a family's hue
    /// on the frame and the edge layer, never on the photo, a chip or a control).
    let accent: Color
    /// Degrees the light swings with the card's tilt (moves the Duplicate Dragons' glint and the Phantoms' shimmer).
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
        case .dragons:   return 0.36
        case .undead:    return 0.45
        case .relics:    return 0.34
        case .behemoths: return 0.28
        case .phantoms:  return 0.50
        case .glitch:    return 0.34
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
            drawPatina(&context, size: size, seed: seed)
            drawCracks(&context, size: size, seed: seed, count: 14, amount: 1, color: Color.black.opacity(0.7),
                       base: 0, reach: 22, lineWidth: 1.5)
            drawCornerLight(&context, size: size, outerRect: outerRect)
        case .behemoths:
            drawHeavyBevel(&context, size: size, outerRect: outerRect, innerRect: innerRect, outerCorner: outerCorner, innerCorner: innerCorner)
            drawSeams(&context, size: size)
            drawCracks(&context, size: size, seed: seed, count: 8, amount: crack, color: Color.black.opacity(0.8),
                       base: 100, reach: 16, lineWidth: 1.6)
        case .phantoms:
            drawGlass(&context, size: size, outerRect: outerRect, outerCorner: outerCorner,
                      innerRect: innerRect, innerCorner: innerCorner)
        case .glitch:
            drawScanlines(&context, size: size)
            drawNotches(&context, size: size, seed: seed)
            drawSlices(&context, size: size, seed: seed)
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

    /// True while `t` is on the frame's top or bottom edge, where a line across the rim runs vertically.
    private func isOnHorizontalEdge(_ t: Double, size: CGSize) -> Bool {
        let w: CGFloat = size.width - rim
        let h: CGFloat = size.height - rim
        let d: CGFloat = CGFloat(t) * 2 * (w + h)
        return d < w || (d >= w + h && d < 2 * w + h)
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
            context.stroke(upper, with: .color(Color.white.opacity(0.65)), lineWidth: 1.2)
            let lowerCenter = CGPoint(x: p.x + 1.8, y: p.y + 2.2)
            let lower = Path { path in
                path.addArc(center: lowerCenter, radius: radius, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            }
            context.stroke(lower, with: .color(Color.black.opacity(0.45)), lineWidth: 1.1)
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

    // MARK: Clutter Undead: a worn, chipped rim with rot patches and a darkened inner edge

    private func drawChips(_ context: inout GraphicsContext, size: CGSize, seed: SeededGeometry,
                           innerRect: CGRect, innerCorner: CGSize) {
        for i in 0..<60 {
            let p = rimPoint(seed.value(i * 3), size: size)
            let r: CGFloat = CGFloat(0.8 + 1.8 * seed.value(i * 3 + 1))
            let isDark: Bool = seed.value(i * 3 + 2) < 0.7
            let blob = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            let color: Color = isDark ? Color.black.opacity(0.6) : Color.white.opacity(0.3)
            context.fill(blob, with: .color(color))
        }
        // Larger patches of rot and moss, half of them the family's own colour.
        for i in 0..<14 {
            let p = rimPoint(seed.value(200 + i * 2), size: size)
            let r: CGFloat = CGFloat(2.2 + 2.0 * seed.value(200 + i * 2 + 1))
            let patch = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            let color: Color = i.isMultiple(of: 2) ? Color.black.opacity(0.5) : accent.opacity(0.6)
            context.fill(patch, with: .color(color))
        }
        let decay = Path(roundedRect: innerRect, cornerSize: innerCorner)
        context.stroke(decay, with: .color(Color.black.opacity(0.5)), lineWidth: 3.4)
    }

    // MARK: Archive Relics: patina, cracks and one corner of light. Storage Behemoths: pressure cracks from the drag.

    private func drawPatina(_ context: inout GraphicsContext, size: CGSize, seed: SeededGeometry) {
        for i in 0..<22 {
            let p = rimPoint(seed.value(300 + i * 3), size: size)
            let r: CGFloat = CGFloat(1.2 + 1.4 * seed.value(300 + i * 3 + 1))
            let speck = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            let color: Color = i.isMultiple(of: 2) ? Color.white.opacity(0.4) : Color.black.opacity(0.35)
            context.fill(speck, with: .color(color))
        }
    }

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
        let colors: [Color] = [Color.white.opacity(0.5), Color.clear]
        let band = GraphicsContext.Shading.linearGradient(
            Gradient(colors: colors),
            startPoint: CGPoint.zero,
            endPoint: CGPoint(x: size.width * 0.45, y: size.height * 0.45)
        )
        context.fill(Path(outerRect), with: band)
    }

    // MARK: Storage Behemoths: a dark stone slab, a heavy bevel, mortar seams and eight rivets

    private func drawHeavyBevel(_ context: inout GraphicsContext, size: CGSize, outerRect: CGRect, innerRect: CGRect,
                                outerCorner: CGSize, innerCorner: CGSize) {
        context.fill(Path(outerRect), with: .color(Color.black.opacity(0.42)))
        let shadowEdge = Path(roundedRect: innerRect.insetBy(dx: -1, dy: -1), cornerSize: innerCorner)
        context.stroke(shadowEdge, with: .color(Color.black.opacity(0.75)), lineWidth: 3.0)
        let litEdge = Path(roundedRect: outerRect.insetBy(dx: 0.8, dy: 0.8), cornerSize: outerCorner)
        context.stroke(litEdge, with: .color(Color.white.opacity(0.55)), lineWidth: 1.8)
        let half: CGFloat = rim / 2
        let w: CGFloat = size.width
        let h: CGFloat = size.height
        let centers: [CGPoint] = [
            CGPoint(x: half, y: half),
            CGPoint(x: w - half, y: half),
            CGPoint(x: half, y: h - half),
            CGPoint(x: w - half, y: h - half),
            CGPoint(x: w / 2, y: half),
            CGPoint(x: w / 2, y: h - half),
            CGPoint(x: half, y: h / 2),
            CGPoint(x: w - half, y: h / 2)
        ]
        for center in centers {
            let rivet = Path(ellipseIn: CGRect(x: center.x - 3.0, y: center.y - 3.0, width: 6.0, height: 6.0))
            context.fill(rivet, with: .color(Color.white.opacity(0.65)))
            context.stroke(rivet, with: .color(Color.black.opacity(0.8)), lineWidth: 1.0)
        }
    }

    /// Mortar seams across the rim every few dozen points, so the frame reads as laid stone blocks.
    private func drawSeams(_ context: inout GraphicsContext, size: CGSize) {
        let count = 40
        for i in 0..<count {
            let t: Double = (Double(i) + 0.5) / Double(count)
            let p = rimPoint(t, size: size)
            var seam = Path()
            if isOnHorizontalEdge(t, size: size) {
                seam.move(to: CGPoint(x: p.x, y: p.y - rim / 2))
                seam.addLine(to: CGPoint(x: p.x, y: p.y + rim / 2))
            } else {
                seam.move(to: CGPoint(x: p.x - rim / 2, y: p.y))
                seam.addLine(to: CGPoint(x: p.x + rim / 2, y: p.y))
            }
            context.stroke(seam, with: .color(Color.black.opacity(0.6)), lineWidth: 1.5)
        }
    }

    // MARK: Video Phantoms: a glassy rim with a shimmer that moves with the tilt (the cool glow is in ExhibitFrame)

    private func drawGlass(_ context: inout GraphicsContext, size: CGSize, outerRect: CGRect, outerCorner: CGSize,
                           innerRect: CGRect, innerCorner: CGSize) {
        let colors: [Color] = [Color.white.opacity(0.5), Color.white.opacity(0.08)]
        let glass = GraphicsContext.Shading.linearGradient(
            Gradient(colors: colors),
            startPoint: CGPoint.zero,
            endPoint: CGPoint(x: 0, y: size.height)
        )
        context.fill(Path(outerRect), with: glass)
        let shift: CGFloat = CGFloat(highlightShift) / 100
        let shimmerColors: [Color] = [Color.clear, Color.white.opacity(0.65), Color.clear]
        let shimmer = GraphicsContext.Shading.linearGradient(
            Gradient(colors: shimmerColors),
            startPoint: CGPoint(x: size.width * (0.05 + shift), y: 0),
            endPoint: CGPoint(x: size.width * (0.6 + shift), y: size.height)
        )
        context.fill(Path(outerRect), with: shimmer)
        let edge = Path(roundedRect: outerRect.insetBy(dx: 0.8, dy: 0.8), cornerSize: outerCorner)
        context.stroke(edge, with: .color(Color.white.opacity(0.8)), lineWidth: 1.6)
        let inner = Path(roundedRect: innerRect, cornerSize: innerCorner)
        context.stroke(inner, with: .color(Color.white.opacity(0.75)), lineWidth: 2.4)
    }

    // MARK: Glitchborn: scanlines, notches, shifted slices and a chromatic split on the frame stroke

    private func drawScanlines(_ context: inout GraphicsContext, size: CGSize) {
        var lines = Path()
        var y: CGFloat = 0
        while y < size.height {
            lines.move(to: CGPoint(x: 0, y: y))
            lines.addLine(to: CGPoint(x: size.width, y: y))
            y += 3
        }
        context.stroke(lines, with: .color(Color.black.opacity(0.3)), lineWidth: 1)
    }

    private func drawNotches(_ context: inout GraphicsContext, size: CGSize, seed: SeededGeometry) {
        let count: Int = seed.value(0) > 0.5 ? 8 : 7
        for i in 0..<count {
            let p = rimPoint(seed.value(10 + i), size: size)
            let w: CGFloat = CGFloat(8 + 10 * seed.value(20 + i))
            let notch = Path(CGRect(x: p.x - w / 2, y: p.y - rim / 2, width: w, height: rim))
            context.fill(notch, with: .color(Color.black.opacity(0.85)))
        }
    }

    /// Thin slices of the family's two glitch colours, as if a few lines of the frame had slipped sideways.
    private func drawSlices(_ context: inout GraphicsContext, size: CGSize, seed: SeededGeometry) {
        for i in 0..<6 {
            let p = rimPoint(seed.value(40 + i), size: size)
            let w: CGFloat = CGFloat(18 + 26 * seed.value(50 + i))
            let slice = Path(CGRect(x: p.x - w / 2, y: p.y - rim * 0.2, width: w, height: rim * 0.4))
            let color: Color = i.isMultiple(of: 2) ? Color.glitchRose : Color.videoSapphire
            context.fill(slice, with: .color(color.opacity(0.75)))
        }
    }

    private func drawChromaticSplit(_ context: inout GraphicsContext, outerRect: CGRect, outerCorner: CGSize) {
        let outline = Path(roundedRect: outerRect.insetBy(dx: 0.8, dy: 0.8), cornerSize: outerCorner)
        var warm = context
        warm.translateBy(x: 3.2, y: 0)
        warm.stroke(outline, with: .color(Color.glitchRose.opacity(0.85)), lineWidth: 2.2)
        var cool = context
        cool.translateBy(x: -3.2, y: 0)
        cool.stroke(outline, with: .color(Color.videoSapphire.opacity(0.85)), lineWidth: 2.2)
    }
}
