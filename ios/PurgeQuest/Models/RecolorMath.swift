//
//  RecolorMath.swift
//  PurgeQuest
//
//  Pure math behind mask-aware recoloring. Inside a material region the
//  output is the target colour scaled by the source's luminance relative to
//  the region's mean luminance, so shading, highlights and painted texture
//  survive; outside the mask (and on outlines, which masks exclude) pixels
//  are untouched. Mirrors tools/modular_assets/qa.py `recolor`, and feeds
//  the CIColorMatrix coefficients used by MaterialRecolorer.
//

import Foundation

nonisolated enum RecolorMath {
    static let lumaWeights: (r: Double, g: Double, b: Double) = (0.299, 0.587, 0.114)

    static func luminance(r: Double, g: Double, b: Double) -> Double {
        lumaWeights.r * r + lumaWeights.g * g + lumaWeights.b * b
    }

    /// Floor on the reference luminance so near-black regions can't blow up the gain.
    static func safeReference(_ luma: Double?) -> Double {
        guard let luma, luma.isFinite else { return 0.5 }
        return max(luma, 0.05)
    }

    /// Rows of a CIColorMatrix (R', G', B') mapping source RGB to `target * (Y(src) / referenceLuma)`.
    static func matrixRows(target: MaterialRGBA, referenceLuma: Double?) -> (r: [Double], g: [Double], b: [Double]) {
        let gain = 1 / safeReference(referenceLuma)
        func row(_ channel: Double) -> [Double] {
            [channel * lumaWeights.r * gain, channel * lumaWeights.g * gain, channel * lumaWeights.b * gain, 0]
        }
        return (row(target.red), row(target.green), row(target.blue))
    }

    /// Scalar reference used by tests: blend of the source and the tinted pixel by mask weight (0...1).
    static func recolor(pixel src: (r: Double, g: Double, b: Double), target: MaterialRGBA,
                        referenceLuma: Double?, mask: Double) -> (r: Double, g: Double, b: Double) {
        let y = luminance(r: src.r, g: src.g, b: src.b) / safeReference(referenceLuma)
        let m = min(max(mask, 0), 1)
        func mix(_ s: Double, _ t: Double) -> Double { s * (1 - m) + min(max(t * y, 0), 1) * m }
        return (mix(src.r, target.red), mix(src.g, target.green), mix(src.b, target.blue))
    }
}

/// Material regions a piece of gear can expose in the Forge, in display order.
nonisolated enum MaterialPalette {
    static let displayOrder: [MaterialRegion] = [.skin, .hair, .eyes, .primary, .secondary, .trim, .leather, .emissive]

    static func displayName(_ region: MaterialRegion) -> String {
        switch region {
        case .skin: return "Skin"
        case .hair: return "Hair"
        case .eyes: return "Eyes"
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        case .trim: return "Trim"
        case .leather: return "Leather"
        case .emissive: return "Glow"
        }
    }

    static func selection(_ set: CharacterMaterialSet?, _ region: MaterialRegion) -> MaterialSelection? {
        guard let set else { return nil }
        switch region {
        case .skin: return set.skin
        case .hair: return set.hair
        case .eyes: return set.eyes
        case .primary: return set.armorPrimary
        case .secondary: return set.armorSecondary
        case .trim: return set.armorTrim
        case .leather: return set.leather
        case .emissive: return set.emissive
        }
    }

    static func setting(_ set: CharacterMaterialSet?, _ region: MaterialRegion, to value: MaterialSelection?) -> CharacterMaterialSet {
        var out = set ?? CharacterMaterialSet()
        switch region {
        case .skin: out.skin = value
        case .hair: out.hair = value
        case .eyes: out.eyes = value
        case .primary: out.armorPrimary = value
        case .secondary: out.armorSecondary = value
        case .trim: out.armorTrim = value
        case .leather: out.leather = value
        case .emissive: out.emissive = value
        }
        return out
    }

    /// nil when no region has a colour (so an untouched look encodes identically to a v3 save).
    static func normalized(_ set: CharacterMaterialSet?) -> CharacterMaterialSet? {
        guard let set, set != CharacterMaterialSet() else { return nil }
        return set
    }

    /// Stable cache key for a set of colours across every region.
    static func fingerprint(_ set: CharacterMaterialSet?) -> String {
        guard let set else { return "-" }
        return displayOrder.map { region in
            guard let s = selection(set, region) else { return "0" }
            let c = s.color
            return "\(s.id):\(c.red),\(c.green),\(c.blue),\(c.alpha)"
        }.joined(separator: "|")
    }
}
