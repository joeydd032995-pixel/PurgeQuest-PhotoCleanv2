//
//  SpriteBodyFraming.swift
//  PurgeQuest
//
//  Finds, once per art pack, where the standing hero sits inside the pack's canvas. The answer is
//  measured from the first idle frame with nothing in the hands, so a sword or shield never changes
//  it, and cached: every later frame of that pack is placed with the same box and does not jitter.
//
//  The arithmetic is SpriteBodyBounds (Foundation, tested on Linux); this file only reads the alpha
//  bytes out of the rendered bitmap.
//

import UIKit

@MainActor
enum SpriteBodyFraming {
    private static var cache: [String: CGRect] = [:]
    private static var unmeasurable: Set<String> = []

    /// The standing hero's box in the pack's base canvas, in canvas units with the origin at the
    /// top-left. Nil when the pack cannot be rendered; the caller then falls back to canvas framing.
    static func bodyRect(race: HeroRace, variant: Int, appearance: HeroAppearance) -> CGRect? {
        let key = "\(race.rawValue)-\(variant)"
        if let known = cache[key] { return known }
        if unmeasurable.contains(key) { return nil }

        let renderer = SpriteRenderer.shared
        guard let frame = renderer.frame(
                race: race, variant: variant, animation: "Idle", frameIndex: 0,
                appearance: appearance, loadout: .none),
              frame.layout == .zero,
              let fractions = normalizedBounds(of: frame.image) else {
            unmeasurable.insert(key)
            return nil
        }
        let base = renderer.canvasSize(race: race, variant: variant) ?? frame.image.size
        let rect = CGRect(
            x: CGFloat(fractions.x) * base.width,
            y: CGFloat(fractions.y) * base.height,
            width: CGFloat(fractions.width) * base.width,
            height: CGFloat(fractions.height) * base.height
        )
        guard rect.width > 0, rect.height > 0 else {
            unmeasurable.insert(key)
            return nil
        }
        cache[key] = rect
        return rect
    }

    /// The opaque box of `image`, as fractions. Read at no more than 256 pixels wide: the box only
    /// needs to be right to about a pixel of the drawn size.
    private static func normalizedBounds(of image: UIImage) -> NormalizedRect? {
        guard let cg = image.cgImage, cg.width > 0, cg.height > 0 else { return nil }
        let width = min(cg.width, 256)
        let height = max(1, Int((Double(cg.height) * Double(width) / Double(cg.width)).rounded()))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var alpha = [UInt8](repeating: 0, count: width * height)
        for index in 0..<alpha.count { alpha[index] = pixels[index * 4 + 3] }
        return SpriteBodyBounds.normalizedRect(alpha: alpha, width: width, height: height)
    }
}
