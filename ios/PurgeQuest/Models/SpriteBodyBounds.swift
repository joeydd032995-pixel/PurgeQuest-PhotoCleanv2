//
//  SpriteBodyBounds.swift
//  PurgeQuest
//
//  Where the opaque part of an image sits inside it. An art pack's canvas is sized to hold every
//  animation frame (a jump, a swing with the sword out), so the standing hero fills only part of it.
//  Knowing the hero's own box lets a view size the hero, not the canvas.
//
//  Foundation only: the caller reads the alpha bytes out of the bitmap (SpriteBodyFraming), this
//  file only finds their bounds, so the Linux harness tests it.
//

import Foundation

/// A rectangle in fractions of an image: origin at the top-left, 0...1 on both axes.
nonisolated struct NormalizedRect: Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    static let full = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
}

nonisolated enum SpriteBodyBounds {
    /// Alpha at or below this is treated as empty: a soft shadow's edge, an antialiasing fringe.
    static let threshold: UInt8 = 24

    /// The smallest box holding every pixel whose alpha is above `threshold`, as fractions of the
    /// image. `alpha` is `width * height` bytes, row by row from the top. Nil when the image has no
    /// such pixel or the buffer is not that size.
    static func normalizedRect(
        alpha: [UInt8], width: Int, height: Int, threshold: UInt8 = SpriteBodyBounds.threshold
    ) -> NormalizedRect? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where alpha[row + x] > threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return NormalizedRect(
            x: Double(minX) / Double(width),
            y: Double(minY) / Double(height),
            width: Double(maxX - minX + 1) / Double(width),
            height: Double(maxY - minY + 1) / Double(height)
        )
    }
}
