//
//  HeroAppearance.swift
//  PurgeQuest
//
//  The hero's customizable identity: race, paint variant, skin/eye/hair
//  hue shifts, face traits, expression, and backdrop. A versioned value
//  type that is saved alongside the hero. Decoding is lenient: any missing
//  key, unknown value, corrupt bytes, or older schema decodes to a designed
//  default, so no player can end up with a blank or broken avatar. Newer
//  fields (race, paint variant, hue shifts) default sensibly for pre-v3 saves.
//

import Foundation

/// Skin tones: grounded naturals plus fantasy jade and ash tints.
nonisolated enum SkinTone: String, CaseIterable, Codable {
    case moonlit
    case sandstone
    case honey
    case umber
    case ebony
    case jadekin
    case ashen

    var displayName: String {
        switch self {
        case .moonlit:   return "Moonlit"
        case .sandstone: return "Sandstone"
        case .honey:     return "Honey"
        case .umber:     return "Umber"
        case .ebony:     return "Ebony"
        case .jadekin:   return "Jadekin"
        case .ashen:     return "Ashen"
        }
    }
}

/// Face silhouettes for the bare head and face windows.
nonisolated enum FaceShape: String, CaseIterable, Codable {
    case round
    case boulder
    case nimble

    var displayName: String {
        switch self {
        case .round:   return "Round"
        case .boulder: return "Boulder"
        case .nimble:  return "Nimble"
        }
    }
}

/// Eye render styles.
nonisolated enum EyeStyle: String, CaseIterable, Codable {
    case bright
    case keen
    case gentle

    var displayName: String {
        switch self {
        case .bright: return "Bright"
        case .keen:   return "Keen"
        case .gentle: return "Gentle"
        }
    }
}

/// Iris colors. No purple: the palette stays inside the Verdigris world.
/// Achievement-gated dyes sit after the free colors.
nonisolated enum EyeColor: String, CaseIterable, Codable {
    case bark
    case moss
    case jade
    case ember
    case sapphire
    case slate
    case gilded
    case verdigris
    case crimson

    var displayName: String {
        switch self {
        case .bark:      return "Bark"
        case .moss:      return "Moss"
        case .jade:      return "Jade"
        case .ember:     return "Ember"
        case .sapphire:  return "Sapphire"
        case .slate:     return "Slate"
        case .gilded:    return "Gilded"
        case .verdigris: return "Verdigris"
        case .crimson:   return "Crimson"
        }
    }
}

/// Brow shapes. Angles are mirrored per side by the renderer.
nonisolated enum BrowStyle: String, CaseIterable, Codable {
    case steady
    case fierce
    case worried
    case stern

    var displayName: String {
        switch self {
        case .steady:  return "Steady"
        case .fierce:  return "Fierce"
        case .worried: return "Worried"
        case .stern:   return "Stern"
        }
    }
}

/// Mouth shapes.
nonisolated enum MouthStyle: String, CaseIterable, Codable {
    case smile
    case grin
    case neutral
    case frown

    var displayName: String {
        switch self {
        case .smile:   return "Smile"
        case .grin:    return "Grin"
        case .neutral: return "Neutral"
        case .frown:   return "Frown"
        }
    }
}

/// Hair silhouettes drawn over (and behind) the head.
nonisolated enum HairStyle: String, CaseIterable, Codable {
    case short
    case swept
    case long
    case buzz
    case bald

    var displayName: String {
        switch self {
        case .short: return "Short"
        case .swept: return "Swept"
        case .long:  return "Long"
        case .buzz:  return "Buzz"
        case .bald:  return "Bald"
        }
    }
}

/// Hair colors: naturals plus fantasy dyes. Achievement-gated dyes sit
/// after the free colors.
nonisolated enum HairColor: String, CaseIterable, Codable {
    case bark
    case raven
    case wheat
    case rust
    case jade
    case ember
    case sapphire
    case ash
    case gilded
    case verdigris
    case crimson
    case bone

    var displayName: String {
        switch self {
        case .bark:      return "Bark"
        case .raven:     return "Raven"
        case .wheat:     return "Wheat"
        case .rust:      return "Rust"
        case .jade:      return "Jade Dye"
        case .ember:     return "Ember Dye"
        case .sapphire:  return "Sapphire Dye"
        case .ash:       return "Ash"
        case .gilded:    return "Gilded Dye"
        case .verdigris: return "Verdigris Dye"
        case .crimson:   return "Crimson Dye"
        case .bone:      return "Bone Dye"
        }
    }
}

/// Outfit dyes that tint the worn armor's cloth and plating. Every family
/// except None unlocks through an achievement.
nonisolated enum ArmorDye: String, CaseIterable, Codable {
    case none
    case gilded
    case verdigris
    case crimson
    case bone

    var displayName: String {
        switch self {
        case .none:      return "None"
        case .gilded:    return "Gilded"
        case .verdigris: return "Verdigris"
        case .crimson:   return "Crimson"
        case .bone:      return "Bone"
        }
    }
}

/// Overall mood that nudges brows, blush, and eye rendering.
nonisolated enum Expression: String, CaseIterable, Codable {
    case calm
    case fierce
    case happy
    case weary

    var displayName: String {
        switch self {
        case .calm:   return "Calm"
        case .fierce: return "Fierce"
        case .happy:  return "Happy"
        case .weary:  return "Weary"
        }
    }
}

/// One-tap looks that set a matched expression, brows, and mouth together.
/// Presets edit the draft like any other trait, so Cancel still discards.
nonisolated enum ExpressionPreset: String, CaseIterable, Codable {
    case valor
    case battleFrenzy
    case triumph
    case exhausted

    var displayName: String {
        switch self {
        case .valor:        return "Valor"
        case .battleFrenzy: return "Battle Frenzy"
        case .triumph:      return "Triumph"
        case .exhausted:    return "Exhausted"
        }
    }

    var expression: Expression {
        switch self {
        case .valor:        return .calm
        case .battleFrenzy: return .fierce
        case .triumph:      return .happy
        case .exhausted:    return .weary
        }
    }

    var browStyle: BrowStyle {
        switch self {
        case .valor:        return .steady
        case .battleFrenzy: return .fierce
        case .triumph:      return .steady
        case .exhausted:    return .worried
        }
    }

    var mouthStyle: MouthStyle {
        switch self {
        case .valor:        return .smile
        case .battleFrenzy: return .grin
        case .triumph:      return .grin
        case .exhausted:    return .neutral
        }
    }

    /// Applies the full preset to a draft look.
    func apply(to look: inout HeroAppearance) {
        look.expression = expression
        look.browStyle = browStyle
        look.mouthStyle = mouthStyle
    }

    /// Whether a look already carries this preset's full combination.
    func matches(_ look: HeroAppearance) -> Bool {
        look.expression == expression
            && look.browStyle == browStyle
            && look.mouthStyle == mouthStyle
    }
}

/// Backdrop style for portrait-style avatar contexts.
nonisolated enum BackdropStyle: String, CaseIterable, Codable {
    case plaque
    case medallion
    case banner

    var displayName: String {
        switch self {
        case .plaque:    return "Rarity Plaque"
        case .medallion: return "Medallion"
        case .banner:    return "Banner"
        }
    }
}

/// Gear tier derived from the most valuable equipped item; drives the plaque
/// accent color.
nonisolated enum GearTier: String, CaseIterable, Codable {
    case standard
    case seasoned
    case elite
    case legendary
    case mythic
}

/// The full saved identity of a hero. Equipped gear is stored separately and
/// renders over this identity.
nonisolated struct HeroAppearance: Equatable, Codable {
    static let currentSchemaVersion = 3

    var schemaVersion: Int
    /// The hero's race. nil on pre-v3 saves; falls back to the legacy
    /// archetype's designed default at read time.
    var race: HeroRace?
    /// Pre-painted art variant (1...3) shipped with each race pack.
    var paintVariant: Int
    /// Custom hue sliders, -1...1 mapping to ±180° of hue rotation.
    var skinHueShift: Double
    var eyeHueShift: Double
    var hairHueShift: Double
    var skinTone: SkinTone
    var faceShape: FaceShape
    var eyeStyle: EyeStyle
    var eyeColor: EyeColor
    var browStyle: BrowStyle
    var mouthStyle: MouthStyle
    var hairStyle: HairStyle
    var hairColor: HairColor
    var expression: Expression
    var backdropStyle: BackdropStyle
    var armorDye: ArmorDye

    init(
        schemaVersion: Int = HeroAppearance.currentSchemaVersion,
        race: HeroRace? = nil,
        paintVariant: Int = 1,
        skinHueShift: Double = 0,
        eyeHueShift: Double = 0,
        hairHueShift: Double = 0,
        skinTone: SkinTone,
        faceShape: FaceShape,
        eyeStyle: EyeStyle,
        eyeColor: EyeColor,
        browStyle: BrowStyle,
        mouthStyle: MouthStyle,
        hairStyle: HairStyle,
        hairColor: HairColor,
        expression: Expression,
        backdropStyle: BackdropStyle,
        armorDye: ArmorDye = .none
    ) {
        self.schemaVersion = schemaVersion
        self.race = race
        self.paintVariant = paintVariant
        self.skinHueShift = skinHueShift
        self.eyeHueShift = eyeHueShift
        self.hairHueShift = hairHueShift
        self.skinTone = skinTone
        self.faceShape = faceShape
        self.eyeStyle = eyeStyle
        self.eyeColor = eyeColor
        self.browStyle = browStyle
        self.mouthStyle = mouthStyle
        self.hairStyle = hairStyle
        self.hairColor = hairColor
        self.expression = expression
        self.backdropStyle = backdropStyle
        self.armorDye = armorDye
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, race, paintVariant
        case skinHueShift, eyeHueShift, hairHueShift
        case skinTone, faceShape, eyeStyle, eyeColor, browStyle, mouthStyle
        case hairStyle, hairColor, expression, backdropStyle, armorDye
    }

    /// Lenient decode: every field falls back to its designed default when
    /// missing or corrupt, so schema-1 and schema-2 records decode in place
    /// with all traits preserved.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? HeroAppearance.currentSchemaVersion
        // Race raw values decode through the migration path: the removed
        // Skeleton Warrior pack folds into Skeletal Undead, shifting its
        // paint job into the warrior variant range (4-6).
        let raceRaw = (try? c.decodeIfPresent(String.self, forKey: .race)) ?? nil
        race = raceRaw.map { HeroRace(legacyRaw: $0) }
        paintVariant = (try? c.decodeIfPresent(Int.self, forKey: .paintVariant)) ?? 1
        if raceRaw == "skeleton_warrior" {
            paintVariant = min(max(paintVariant + 3, 1), HeroRace.skeletalUndead.variantCount)
        }
        skinHueShift = (try? c.decodeIfPresent(Double.self, forKey: .skinHueShift)) ?? 0
        eyeHueShift = (try? c.decodeIfPresent(Double.self, forKey: .eyeHueShift)) ?? 0
        hairHueShift = (try? c.decodeIfPresent(Double.self, forKey: .hairHueShift)) ?? 0
        skinTone = (try? c.decodeIfPresent(SkinTone.self, forKey: .skinTone)) ?? .sandstone
        faceShape = (try? c.decodeIfPresent(FaceShape.self, forKey: .faceShape)) ?? .boulder
        eyeStyle = (try? c.decodeIfPresent(EyeStyle.self, forKey: .eyeStyle)) ?? .bright
        eyeColor = (try? c.decodeIfPresent(EyeColor.self, forKey: .eyeColor)) ?? .bark
        browStyle = (try? c.decodeIfPresent(BrowStyle.self, forKey: .browStyle)) ?? .steady
        mouthStyle = (try? c.decodeIfPresent(MouthStyle.self, forKey: .mouthStyle)) ?? .smile
        hairStyle = (try? c.decodeIfPresent(HairStyle.self, forKey: .hairStyle)) ?? .short
        hairColor = (try? c.decodeIfPresent(HairColor.self, forKey: .hairColor)) ?? .bark
        expression = (try? c.decodeIfPresent(Expression.self, forKey: .expression)) ?? .calm
        backdropStyle = (try? c.decodeIfPresent(BackdropStyle.self, forKey: .backdropStyle)) ?? .plaque
        armorDye = (try? c.decodeIfPresent(ArmorDye.self, forKey: .armorDye)) ?? .none
    }

    /// Clamps a hue slider into its storage range.
    static func clampedHue(_ value: Double) -> Double {
        min(max(value, -1), 1)
    }

    /// The designed default look for a race, so a fresh or broken record
    /// still shows an intentional character.
    static func `default`(for race: HeroRace) -> HeroAppearance {
        switch race.palette {
        case .bone:
            return HeroAppearance(
                race: race,
                skinTone: .moonlit,
                faceShape: .boulder,
                eyeStyle: .keen,
                eyeColor: .sapphire,
                browStyle: .stern,
                mouthStyle: .neutral,
                hairStyle: .bald,
                hairColor: .bone,
                expression: .fierce,
                backdropStyle: .plaque
            )
        case .stone:
            return HeroAppearance(
                race: race,
                skinTone: .ashen,
                faceShape: .boulder,
                eyeStyle: .bright,
                eyeColor: .moss,
                browStyle: .steady,
                mouthStyle: .neutral,
                hairStyle: .bald,
                hairColor: .ash,
                expression: .calm,
                backdropStyle: .plaque
            )
        case .flesh:
            let knightish = race == .valkyrie || race == .skeletalUndead
            return HeroAppearance(
                race: race,
                skinTone: knightish ? .sandstone : .honey,
                faceShape: knightish ? .boulder : .nimble,
                eyeStyle: .bright,
                eyeColor: knightish ? .bark : .jade,
                browStyle: .steady,
                mouthStyle: knightish ? .smile : .grin,
                hairStyle: knightish ? .short : .swept,
                hairColor: knightish ? .bark : .raven,
                expression: .calm,
                backdropStyle: .plaque
            )
        }
    }

    /// Back-compat: maps a legacy archetype to its designed race default.
    static func `default`(for archetype: CharacterArchetype) -> HeroAppearance {
        .default(for: HeroRace(legacyArchetype: archetype))
    }

    /// Encoded for storage on the hero record.
    func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Safe decode: any missing key, unknown value, corrupt bytes, or future
    /// schema falls back to the archetype default. Older schemas decode
    /// in place via the lenient decoder, preserving every trait.
    static func decode(_ data: Data?, for archetype: CharacterArchetype) -> HeroAppearance {
        guard let data, !data.isEmpty else { return .default(for: archetype) }
        guard let decoded = try? JSONDecoder().decode(HeroAppearance.self, from: data) else {
            return .default(for: archetype)
        }
        guard decoded.schemaVersion <= HeroAppearance.currentSchemaVersion else {
            return .default(for: archetype)
        }
        return decoded
    }

    /// Maps equipped gear value to a plaque tier.
    static func gearTier(maxEquippedPrice: Int, hasPremium: Bool) -> GearTier {
        if hasPremium || maxEquippedPrice >= 900 { return .mythic }
        if maxEquippedPrice >= 750 { return .legendary }
        if maxEquippedPrice >= 500 { return .elite }
        if maxEquippedPrice >= 250 { return .seasoned }
        return .standard
    }
}
