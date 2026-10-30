//
//  MaterialRecolorer.swift
//  PurgeQuest
//
//  Mask-aware recolor with Core Image. For each region the player coloured,
//  the layer is run through a colour matrix (target * luminance ratio, see
//  RecolorMath) and blended back through that region's soft mask. Outlines,
//  highlights and painted texture survive because the mask excludes outlines
//  and the matrix preserves relative luminance. Replaces the whole-part
//  semi-transparent `sourceAtop` tint for any asset that ships masks.
//

import UIKit
import CoreImage

@MainActor
final class MaterialRecolorer {
    struct Region {
        let region: MaterialRegion
        let mask: UIImage
        let referenceLuma: Double?
    }

    /// Colour management is off so the matrix runs on the same gamma-encoded values the offline
    /// tools use (tools/modular_assets/qa.py recolor), keeping previews and device output aligned.
    private let context = CIContext(options: [
        .workingColorSpace: NSNull(),
        .outputColorSpace: NSNull()
    ])

    /// Returns `base` unchanged when nothing applies, so callers never get a blank image.
    func recolor(_ base: UIImage, regions: [Region], colors: CharacterMaterialSet?) -> UIImage {
        guard let colors, var current = CIImage(image: base) else { return base }
        var applied = false
        for entry in regions {
            guard let selection = MaterialPalette.selection(colors, entry.region),
                  let maskCI = CIImage(image: entry.mask) else { continue }
            let rows = RecolorMath.matrixRows(target: selection.color, referenceLuma: entry.referenceLuma)
            let tinted = current.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(values: rows.r.map { CGFloat($0) }, count: 4),
                "inputGVector": CIVector(values: rows.g.map { CGFloat($0) }, count: 4),
                "inputBVector": CIVector(values: rows.b.map { CGFloat($0) }, count: 4),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
            ])
            let alphaMask = maskCI.applyingFilter("CIMaskToAlpha")
            current = tinted.applyingFilter("CIBlendWithAlphaMask", parameters: [
                kCIInputBackgroundImageKey: current,
                kCIInputMaskImageKey: alphaMask
            ])
            applied = true
        }
        guard applied else { return base }
        let extent = CGRect(origin: .zero, size: CGSize(width: base.size.width * base.scale, height: base.size.height * base.scale))
        guard let cg = context.createCGImage(current, from: extent) else { return base }
        return UIImage(cgImage: cg, scale: base.scale, orientation: .up)
    }
}
