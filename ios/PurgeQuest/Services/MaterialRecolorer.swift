//
//  MaterialRecolorer.swift
//  PurgeQuest
//
//  Mask-aware recolor. For every region the player coloured, each pixel is
//  re-toned in OKLab (RecolorMath.recolor): it keeps its lightness offset from
//  the region's mean, so shading, highlights and painted texture survive, takes
//  the target's hue, and blends in through that region's soft mask. Outlines are
//  never in a mask, and mask edges follow the fills (the offline tools snap
//  edge pixels to their interior neighbours), so colour sticks to the model.
//  The per-pixel math is pure and shared with the offline reference; this type
//  only moves pixels in and out of CoreGraphics.
//

import UIKit

@MainActor
final class MaterialRecolorer {
    struct Region {
        let region: MaterialRegion
        let mask: UIImage
        let tone: RegionTone?
    }

    private struct Active {
        let weights: [UInt8]
        let color: MaterialRGBA
        let tone: RegionTone?
    }

    /// Returns `base` unchanged when nothing applies or a buffer can't be built, so callers never get a blank image.
    func recolor(_ base: UIImage, regions: [Region], colors: CharacterMaterialSet?) -> UIImage {
        guard let colors, let source = base.cgImage else { return base }
        let width = source.width, height = source.height
        guard width > 0, height > 0 else { return base }

        var active: [Active] = []
        for entry in regions {
            guard let selection = MaterialPalette.selection(colors, entry.region),
                  let weights = Self.grayscale(entry.mask, width: width, height: height) else { continue }
            active.append(Active(weights: weights, color: selection.color, tone: entry.tone))
        }
        guard !active.isEmpty else { return base }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered: CGImage? = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            let bytes = buffer.bindMemory(to: UInt8.self)
            for index in 0..<(width * height) {
                let offset = index * 4
                let alpha = Double(bytes[offset + 3]) / 255
                guard alpha > 0 else { continue }
                // CoreGraphics stores premultiplied colour; the math wants straight colour.
                let rgb = (r: min(Double(bytes[offset]) / 255 / alpha, 1),
                           g: min(Double(bytes[offset + 1]) / 255 / alpha, 1),
                           b: min(Double(bytes[offset + 2]) / 255 / alpha, 1))
                var blend = MaterialRecolorBlend(source: rgb)
                var changed = false
                for layer in active {
                    let weight = Double(layer.weights[index]) / 255
                    guard weight > 0 else { continue }
                    blend.add(target: layer.color, tone: layer.tone, mask: weight)
                    changed = true
                }
                guard changed else { continue }
                let result = blend.result
                bytes[offset] = UInt8(min(max(result.r * alpha * 255 + 0.5, 0), 255))
                bytes[offset + 1] = UInt8(min(max(result.g * alpha * 255 + 0.5, 0), 255))
                bytes[offset + 2] = UInt8(min(max(result.b * alpha * 255 + 0.5, 0), 255))
            }
            return context.makeImage()
        }
        guard let rendered else { return base }
        return UIImage(cgImage: rendered, scale: base.scale, orientation: .up)
    }

    /// 8-bit grayscale weights for a mask image at the layer's pixel size; nil when the sizes disagree.
    private static func grayscale(_ image: UIImage, width: Int, height: Int) -> [UInt8]? {
        guard let cg = image.cgImage, cg.width == width, cg.height == height else { return nil }
        var weights = [UInt8](repeating: 0, count: width * height)
        let ok: Bool = weights.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? weights : nil
    }
}
