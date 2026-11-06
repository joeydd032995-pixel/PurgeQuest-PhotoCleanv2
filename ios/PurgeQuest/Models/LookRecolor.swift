//
//  LookRecolor.swift
//  PurgeQuest
//
//  How the skin, hair and armor-dye swatches become real recolors of the baked sprite parts.
//
//  Pure Foundation (compiled and tested by the Linux harness as well as Xcode). The renderer
//  (SpriteEngine) only moves pixels; every decision about WHICH colour goes through WHICH mask lives here.
//
//  Data model, agreed in docs/superpowers/specs/2026-11-05-hero-look-recolor-discussion.md:
//  - `materials` is the source of truth for skin and hair. A swatch tap stores a tagged entry
//    (`skin.honey`, `hair.raven`); "As painted" removes it, and nil means the art as painted.
//  - Armor dye is NOT stored: `armorDye` already has a native `.none`, so the dye is derived at render time.
//    That keeps saved heroes working and means nothing can drift.
//  - A stored entry the player picked elsewhere (the Forge's `custom` colours) always wins over the dye.
//

import Foundation

/// Recorded policy exception (docs/modular/README.md, "Legacy recolor of baked parts"): the planner may recolor
/// baked part pixels through masks whose assets are still `candidate`, exactly as held gear already does.
/// It never changes composition, `CharacterRenderPlanner`, or any approval record. Set to false to show the
/// art as painted everywhere in the legacy renderer.
nonisolated enum LookRecolorPolicy {
    static let candidateMasksMayRecolorBakedParts = true
}

// MARK: - Swatch colors

nonisolated extension SkinTone {
    /// The swatch colour, and the target the skin recolor aims for.
    var materialRGBA: MaterialRGBA {
        switch self {
        case .moonlit:   return MaterialRGBA(red: 0.96, green: 0.87, blue: 0.74)
        case .sandstone: return MaterialRGBA(red: 0.90, green: 0.74, blue: 0.54)
        case .honey:     return MaterialRGBA(red: 0.83, green: 0.63, blue: 0.42)
        case .umber:     return MaterialRGBA(red: 0.62, green: 0.44, blue: 0.29)
        case .ebony:     return MaterialRGBA(red: 0.42, green: 0.30, blue: 0.21)
        case .jadekin:   return MaterialRGBA(red: 0.62, green: 0.72, blue: 0.66)
        case .ashen:     return MaterialRGBA(red: 0.55, green: 0.57, blue: 0.55)
        }
    }
}

nonisolated extension HairColor {
    var materialRGBA: MaterialRGBA {
        switch self {
        case .bark:      return MaterialRGBA(red: 0.38, green: 0.26, blue: 0.15)
        case .raven:     return MaterialRGBA(red: 0.19, green: 0.18, blue: 0.19)
        case .wheat:     return MaterialRGBA(red: 0.84, green: 0.72, blue: 0.44)
        case .rust:      return MaterialRGBA(red: 0.60, green: 0.33, blue: 0.19)
        case .jade:      return MaterialRGBA(red: 0.24, green: 0.58, blue: 0.45)
        case .ember:     return MaterialRGBA(red: 0.76, green: 0.36, blue: 0.22)
        case .sapphire:  return MaterialRGBA(red: 0.36, green: 0.51, blue: 0.63)
        case .ash:       return MaterialRGBA(red: 0.62, green: 0.64, blue: 0.62)
        case .gilded:    return MaterialRGBA(red: 0.84, green: 0.64, blue: 0.22)
        case .verdigris: return MaterialRGBA(red: 0.31, green: 0.57, blue: 0.47)
        case .crimson:   return MaterialRGBA(red: 0.58, green: 0.17, blue: 0.19)
        case .bone:      return MaterialRGBA(red: 0.88, green: 0.86, blue: 0.77)
        }
    }
}

nonisolated extension ArmorDye {
    /// The dye colour; nil for `.none` (the armor as painted).
    var materialRGBA: MaterialRGBA? {
        switch self {
        case .none:      return nil
        case .gilded:    return MaterialRGBA(red: 0.78, green: 0.58, blue: 0.22)
        case .verdigris: return MaterialRGBA(red: 0.29, green: 0.54, blue: 0.45)
        case .crimson:   return MaterialRGBA(red: 0.62, green: 0.19, blue: 0.21)
        case .bone:      return MaterialRGBA(red: 0.86, green: 0.83, blue: 0.72)
        }
    }
}

// MARK: - Armor dye

/// Secondary armor regions (trims, panels, plates) keep their original lightness offset from the primary, so a
/// two-tone outfit stays two-tone after dyeing. Mirrors the Python reference (`shade` in the look-recolor reference).
nonisolated enum ArmorDyeShading {
    static let lightnessRange: ClosedRange<Double> = 0.12...0.92

    /// Same hue and chroma as `dye`, lightness moved by (secondary tone - primary tone) and clamped.
    /// Without both tones there is no offset to keep, so the secondary is the dye itself.
    static func secondary(of dye: MaterialRGBA, regionTones: [String: [Double]]) -> MaterialRGBA {
        guard let primary = regionTones["primary"]?.first, let secondary = regionTones["secondary"]?.first else { return dye }
        let lab = RecolorMath.toOKLab(r: dye.red, g: dye.green, b: dye.blue)
        let lightness = min(max(lab.l + (secondary - primary), lightnessRange.lowerBound), lightnessRange.upperBound)
        let rgb = RecolorMath.fromOKLab(l: lightness, a: lab.a, b: lab.b)
        return MaterialRGBA(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}

// MARK: - Swatch choices and render-time resolution

nonisolated extension HeroAppearance {
    /// Cloth and plating only: never the head (hood, helm, hair) or the hands (skin, or gloves that read as skin).
    static let armorDyeParts: Set<String> = ["body", "left_arm", "right_arm", "left_leg", "right_leg"]

    /// Picks a skin swatch, or restores the art as painted with nil. Other stored colours are untouched.
    func choosingSkin(_ tone: SkinTone?) -> HeroAppearance {
        var look = self
        if let tone { look.skinTone = tone }
        look.materials = MaterialPalette.normalized(MaterialPalette.setting(
            materials, .skin, to: tone.map { MaterialSelection(id: "skin.\($0.rawValue)", color: $0.materialRGBA) }))
        return look
    }

    /// Picks a hair swatch, or restores the art as painted with nil. Other stored colours are untouched.
    func choosingHair(_ color: HairColor?) -> HeroAppearance {
        var look = self
        if let color { look.hairColor = color }
        look.materials = MaterialPalette.normalized(MaterialPalette.setting(
            materials, .hair, to: color.map { MaterialSelection(id: "hair.\($0.rawValue)", color: $0.materialRGBA) }))
        return look
    }

    /// The skin swatch currently applied, read back from its tag; nil for the art as painted or a custom colour.
    var chosenSkinTone: SkinTone? {
        guard let id = materials?.skin?.id, id.hasPrefix("skin.") else { return nil }
        return SkinTone(rawValue: String(id.dropFirst("skin.".count)))
    }

    /// The hair swatch currently applied, read back from its tag; nil for the art as painted or a custom colour.
    var chosenHairColor: HairColor? {
        guard let id = materials?.hair?.id, id.hasPrefix("hair.") else { return nil }
        return HairColor(rawValue: String(id.dropFirst("hair.".count)))
    }

    /// The colours to apply to one sprite part: the stored materials, plus the derived dye on the parts it reaches.
    /// `regionTones` are the part's manifest tones, used to keep the secondary regions' lightness offset.
    func resolvedMaterials(forPart stem: String, regionTones: [String: [Double]]) -> CharacterMaterialSet? {
        var set = materials ?? CharacterMaterialSet()
        if let dye = armorDye.materialRGBA, Self.armorDyeParts.contains(stem),
           set.armorPrimary == nil, set.armorSecondary == nil {
            let id = "dye.\(armorDye.rawValue)"
            set.armorPrimary = MaterialSelection(id: id, color: dye)
            set.armorSecondary = MaterialSelection(id: id, color: ArmorDyeShading.secondary(of: dye, regionTones: regionTones))
        }
        return MaterialPalette.normalized(set)
    }
}

// MARK: - Face window

/// The visible skin of a head is the "window" the headgear layer cuts out. Its weight is the anatomy layer's skin
/// mask times (1 - headgear alpha), plus the headgear layer's own skin mask where the pack has one (ears, brow
/// bands). Alpha alone would also pick up dark linework. Buffers are 8-bit and one byte per pixel.
nonisolated enum FaceWindow {
    static func weights(anatomySkin: [UInt8], headgearAlpha: [UInt8], headgearSkin: [UInt8]?) -> [UInt8]? {
        guard anatomySkin.count == headgearAlpha.count else { return nil }
        if let headgearSkin, headgearSkin.count != anatomySkin.count { return nil }
        var out = [UInt8](repeating: 0, count: anatomySkin.count)
        for index in out.indices {
            var weight = Double(anatomySkin[index]) * Double(255 - Int(headgearAlpha[index])) / 255
            if let headgearSkin { weight += Double(headgearSkin[index]) }
            out[index] = UInt8(min((max(weight, 0) + 0.5).rounded(.down), 255))
        }
        return out
    }
}

// MARK: - Capabilities

nonisolated enum LookAvailability: Equatable {
    case available
    case unavailable(reason: String)

    var isAvailable: Bool { self == .available }
}

/// Which look controls do something visible on a paint. Computed from the shipped manifest, so a control that
/// cannot change the sprite is disabled with a stated reason instead of silently doing nothing.
nonisolated struct LookCapabilities: Equatable {
    var skin: LookAvailability
    var hair: LookAvailability
    var armorDye: LookAvailability

    static let noDyeableArmor = "This paint has no dyeable armor."
    static let noVisibleHair = "No visible hair on this paint."
    static let noSkinOnBoneOrStone = "Bone and stone take no skin tone."
    static let noSkinOnThisFace = "This face isn't skin."

    /// A face window measured below this chroma reads as shadow or void, not skin (Dark Oracle 2 and 3 sit at 0.010
    /// to 0.014; the dullest real skin, Necromancer 3, is 0.031).
    static let minimumSkinChroma = 0.02

    static func forPaint(race: HeroRace, variant: Int, parts: [PartManifest]) -> LookCapabilities {
        let pack = race.artBase(variant: variant)
        let layers = parts.filter { $0.pack == pack }
        let head = layers.filter { $0.part == "head" }
        let flesh = race.palette == .flesh

        let armorDye: LookAvailability = layers.contains {
            $0.part == "body" && $0.kind == "armor" && ($0.maskResources["primary"] != nil || $0.maskResources["secondary"] != nil)
        } ? .available : .unavailable(reason: noDyeableArmor)

        let hair: LookAvailability = flesh && head.contains { $0.kind == "headgear" && $0.maskResources["hair"] != nil }
            ? .available : .unavailable(reason: noVisibleHair)

        let skin: LookAvailability
        if !flesh {
            skin = .unavailable(reason: noSkinOnBoneOrStone)
        } else if let anatomy = head.first(where: { $0.kind == "anatomy" && $0.maskResources["skin"] != nil }),
                  let tone = RegionTone(anatomy.regionTone["skin"]), tone.chroma >= minimumSkinChroma {
            skin = .available
        } else {
            skin = .unavailable(reason: noSkinOnThisFace)
        }
        return LookCapabilities(skin: skin, hair: hair, armorDye: armorDye)
    }
}

// MARK: - Plans

/// One recolor the legacy renderer performs on a baked part: which colour region, through which mask, with which tone.
nonisolated struct PlannedRecolorRegion: Equatable {
    enum Source: Equatable {
        /// A layer mask the same size as the baked part (armor and headgear layers are pixel-identical to it).
        case mask(resource: String)
        /// The head's visible skin: see `FaceWindow`.
        case faceWindow(anatomySkinMask: String, headgearLayer: String, headgearSkinMask: String?)
    }

    let region: MaterialRegion
    let source: Source
    let tone: RegionTone?
}

/// Decides, for one baked part, which of the chosen colours can be applied and through which masks.
/// Everything here is data-driven from the manifest; the renderer only loads images and runs `MaterialRecolorer`.
nonisolated enum LegacyRecolorPlanner {
    static func plan(
        race: HeroRace, variant: Int, stem: String, materials: CharacterMaterialSet?, parts: [PartManifest],
        allowCandidateMasks: Bool = LookRecolorPolicy.candidateMasksMayRecolorBakedParts
    ) -> [PlannedRecolorRegion] {
        guard allowCandidateMasks, let materials else { return [] }
        let pack = race.artBase(variant: variant)
        let layers = parts.filter { $0.pack == pack && $0.part == stem }
        let flesh = race.palette == .flesh
        let bakedName = "\(pack)_\(stem)"
        func tone(_ layer: PartManifest, _ region: MaterialRegion) -> RegionTone? { RegionTone(layer.regionTone[region.rawValue]) }
        var plan: [PlannedRecolorRegion] = []

        for region in MaterialPalette.displayOrder where MaterialPalette.selection(materials, region) != nil {
            switch region {
            case .eyes:
                continue   // face overlays are not part of this recolor
            case .skin where !flesh, .hair where !flesh:
                continue   // bone and stone bodies take no skin tone or hair color
            case .skin:
                let anatomy = layers.first { $0.kind == "anatomy" && $0.maskResources["skin"] != nil }
                if let anatomy, let skinMask = anatomy.maskResources["skin"] {
                    if let headgear = layers.first(where: { $0.kind == "headgear" }) {
                        plan.append(PlannedRecolorRegion(
                            region: .skin,
                            source: .faceWindow(anatomySkinMask: skinMask, headgearLayer: headgear.resourceBaseName,
                                                headgearSkinMask: headgear.maskResources["skin"]),
                            tone: tone(anatomy, .skin)))
                    } else if anatomy.resourceBaseName == bakedName {
                        // Anatomy-only part (a bare head or hand): the layer IS the baked image.
                        plan.append(PlannedRecolorRegion(region: .skin, source: .mask(resource: skinMask), tone: tone(anatomy, .skin)))
                    }
                }
                for layer in layers where layer.kind == "armor" {
                    if let skinMask = layer.maskResources["skin"] {
                        plan.append(PlannedRecolorRegion(region: .skin, source: .mask(resource: skinMask), tone: tone(layer, .skin)))
                    }
                }
            default:
                for layer in layers where layer.kind == "armor" || layer.kind == "headgear" {
                    if let mask = layer.maskResources[region.rawValue] {
                        plan.append(PlannedRecolorRegion(region: region, source: .mask(resource: mask), tone: tone(layer, region)))
                    }
                }
            }
        }
        return plan
    }

    /// The tones the dye's secondary shading needs. Primary and secondary regions exist only on armor layers.
    static func armorTones(race: HeroRace, variant: Int, stem: String, parts: [PartManifest]) -> [String: [Double]] {
        let pack = race.artBase(variant: variant)
        return parts.first { $0.pack == pack && $0.part == stem && $0.kind == "armor" }?.regionTone ?? [:]
    }

    /// Cache key for a part's recolored image: only the regions this part actually uses, with their colours.
    /// A skin change must not re-render the body, and a dye change must not reuse the old body.
    static func fingerprint(plan: [PlannedRecolorRegion], materials: CharacterMaterialSet?) -> String {
        plan.map { entry -> String in
            guard let color = MaterialPalette.selection(materials, entry.region)?.color else { return "\(entry.region.rawValue):-" }
            return "\(entry.region.rawValue):\(color.red),\(color.green),\(color.blue),\(color.alpha)"
        }.joined(separator: "|")
    }
}
