//
//  RecolorMath.swift
//  PurgeQuest
//
//  Pure math behind mask-aware recoloring (OKLab, shading-preserving) and the
//  Forge's material-region helpers. MaterialRecolorer applies it per pixel.
//

import Foundation

/// Mean OKLab lightness and chroma of one material region (measured over the whole art pack by the asset tools,
/// so parts of one material keep their relative brightness after a recolor).
nonisolated struct RegionTone: Equatable, Sendable {
    let lightness: Double
    let chroma: Double

    init(lightness: Double, chroma: Double) {
        self.lightness = lightness
        self.chroma = chroma
    }

    /// Manifest form: [lightness, chroma].
    init?(_ values: [Double]?) {
        guard let values, values.count == 2, values.allSatisfy(\.isFinite) else { return nil }
        self.init(lightness: values[0], chroma: values[1])
    }

    /// Used when a manifest has no measurement for a region: a mid-tone, lightly saturated reference.
    static let fallback = RegionTone(lightness: 0.6, chroma: 0.1)
}

/// Shading-preserving recolor in OKLab. Mirrors tools/modular_assets/imgops.py `recolor_pixels` step for step.
///
/// Inside a mask, a pixel keeps its lightness *offset from the region mean* but is re-centred on the target's
/// lightness (so shadows, highlights, and painted texture survive); its hue becomes the target's; its chroma follows
/// the target, modulated by how the source's chroma varied around the region mean and fitted into the sRGB gamut so
/// saturated targets desaturate instead of clipping. Outside the mask the pixel is untouched, and outlines are never
/// in a mask, so linework stays intact.
nonisolated enum RecolorMath {
    static let gamutEpsilon = 1e-4
    static let gamutSteps = 7

    static func srgbToLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static func linearToSrgb(_ value: Double) -> Double {
        let c = min(max(value, 0), 1)
        return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    static func toOKLab(r: Double, g: Double, b: Double) -> (l: Double, a: Double, b: Double) {
        let lr = srgbToLinear(r), lg = srgbToLinear(g), lb = srgbToLinear(b)
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    /// Linear (unclamped) sRGB of an OKLab colour; out-of-gamut values fall outside 0...1.
    static func toLinear(l L: Double, a: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let l = pow(L + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(L - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(L - 0.0894841775 * a - 1.2914855480 * b, 3)
        return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    }

    static func fromOKLab(l: Double, a: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let lin = toLinear(l: l, a: a, b: b)
        return (linearToSrgb(lin.r), linearToSrgb(lin.g), linearToSrgb(lin.b))
    }

    /// Identity inside [lo, hi]; compresses smoothly toward 0 and 1 outside so highlights and shadows never clip flat.
    static func softLimit(_ x: Double, lo: Double = 0.1, hi: Double = 0.9) -> Double {
        if x > hi { return hi + (1 - hi) * tanh((x - hi) / (1 - hi)) }
        if x < lo { return lo - lo * tanh((lo - x) / lo) }
        return x
    }

    private static func inGamut(_ lightness: Double, _ chroma: Double, _ hue: Double) -> Bool {
        let lin = toLinear(l: lightness, a: chroma * cos(hue), b: chroma * sin(hue))
        let lo = -gamutEpsilon, hi = 1 + gamutEpsilon
        return lin.r >= lo && lin.r <= hi && lin.g >= lo && lin.g <= hi && lin.b >= lo && lin.b <= hi
    }

    /// Largest chroma <= `chroma` (7-step bisection) that stays inside the sRGB gamut at this lightness and hue.
    static func fitChroma(lightness: Double, chroma: Double, hue: Double) -> Double {
        if inGamut(lightness, chroma, hue) { return chroma }
        var lo = 0.0, hi = chroma
        for _ in 0..<gamutSteps {
            let mid = (lo + hi) / 2
            if inGamut(lightness, mid, hue) { lo = mid } else { hi = mid }
        }
        return lo
    }

    /// Recolors one straight-alpha pixel (channels 0...1). `mask` is the region's soft weight at this pixel.
    static func recolor(pixel src: (r: Double, g: Double, b: Double), target: MaterialRGBA,
                        tone: RegionTone?, mask: Double) -> (r: Double, g: Double, b: Double) {
        let m = min(max(mask, 0), 1)
        guard m > 0 else { return src }
        let tone = tone ?? .fallback
        let s = toOKLab(r: src.r, g: src.g, b: src.b)
        let t = toOKLab(r: target.red, g: target.green, b: target.blue)
        let chroma = hypot(s.a, s.b)
        let targetChroma = hypot(t.a, t.b)
        let hue = atan2(t.b, t.a)

        let lightness = softLimit(t.l + (s.l - tone.lightness))
        let ratio = tone.chroma > 0.02 ? min(max(chroma / tone.chroma, 0.5), 1.6) : 1
        let extremes = 1 - 1.3 * max(0, lightness - 0.85) - 1.3 * max(0, 0.2 - lightness)
        let wanted = targetChroma * ratio * min(max(extremes, 0.2), 1)
        let fitted = fitChroma(lightness: lightness, chroma: wanted, hue: hue)
        let out = fromOKLab(l: lightness, a: fitted * cos(hue), b: fitted * sin(hue))
        return (src.r * (1 - m) + out.r * m, src.g * (1 - m) + out.g * m, src.b * (1 - m) + out.b * m)
    }
}

/// Blend soft material boundaries from the same original pixel. Recolouring
/// the result of another region changes shading twice and makes mask order visible.
nonisolated struct MaterialRecolorBlend {
    let source: (r: Double, g: Double, b: Double)
    private var red = 0.0
    private var green = 0.0
    private var blue = 0.0
    private var weight = 0.0

    init(source: (r: Double, g: Double, b: Double)) {
        self.source = source
    }

    mutating func add(target: MaterialRGBA, tone: RegionTone?, mask: Double) {
        let m = min(max(mask, 0), 1)
        guard m > 0 else { return }
        let color = RecolorMath.recolor(pixel: source, target: target, tone: tone, mask: 1)
        red += color.r * m
        green += color.g * m
        blue += color.b * m
        weight += m
    }

    var result: (r: Double, g: Double, b: Double) {
        let originalWeight = max(0, 1 - weight)
        let divisor = max(1, weight)
        return (source.r * originalWeight + red / divisor,
                source.g * originalWeight + green / divisor,
                source.b * originalWeight + blue / divisor)
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
