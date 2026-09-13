//
//  HeroAppearance.swift
//  PurgeQuest
//
//  The hero's customizable identity: skin, face, eyes, brows, mouth, hair,
//  expression, and backdrop. A versioned value type that is saved alongside
//  the hero. Anything missing, corrupt, or written by a newer schema decodes
//  to the designed default for the hero's archetype, so no player can end up
//  with a blank or broken avatar.
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
    static let currentSchemaVersion = 2

    var schemaVersion: Int
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

    /// Mirror of the schema-1 record shape, used to migrate older saves
    /// forward without losing any trait.
    nonisolated struct LegacyV1: Codable {
        var schemaVersion: Int
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

        var migrated: HeroAppearance {
            HeroAppearance(
                schemaVersion: HeroAppearance.currentSchemaVersion,
                skinTone: skinTone,
                faceShape: faceShape,
                eyeStyle: eyeStyle,
                eyeColor: eyeColor,
                browStyle: browStyle,
                mouthStyle: mouthStyle,
                hairStyle: hairStyle,
                hairColor: hairColor,
                expression: expression,
                backdropStyle: backdropStyle
            )
        }
    }

    /// The designed default look per archetype, so a fresh or broken record
    /// still shows an intentional character.
    static func `default`(for archetype: CharacterArchetype) -> HeroAppearance {
        switch archetype {
        case .knight:
            return HeroAppearance(
                skinTone: .sandstone,
                faceShape: .boulder,
                eyeStyle: .bright,
                eyeColor: .bark,
                browStyle: .steady,
                mouthStyle: .smile,
                hairStyle: .short,
                hairColor: .bark,
                expression: .calm,
                backdropStyle: .plaque
            )
        case .magician:
            return HeroAppearance(
                skinTone: .honey,
                faceShape: .nimble,
                eyeStyle: .bright,
                eyeColor: .jade,
                browStyle: .steady,
                mouthStyle: .grin,
                hairStyle: .swept,
                hairColor: .raven,
                expression: .calm,
                backdropStyle: .plaque
            )
        }
    }

    /// Encoded for storage on the hero record.
    func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Safe decode: any missing key, unknown value, corrupt bytes, or future
    /// schema falls back to the archetype default. Schema-1 records migrate
    /// forward with every trait preserved (gaining the default None armor
    /// dye); only a partially-written legacy record falls all the way back.
    static func decode(_ data: Data?, for archetype: CharacterArchetype) -> HeroAppearance {
        guard let data, !data.isEmpty else { return .default(for: archetype) }
        if let decoded = try? JSONDecoder().decode(HeroAppearance.self, from: data) {
            guard decoded.schemaVersion <= HeroAppearance.currentSchemaVersion else {
                return .default(for: archetype)
            }
            return decoded
        }
        if let legacy = try? JSONDecoder().decode(LegacyV1.self, from: data) {
            return legacy.migrated
        }
        return .default(for: archetype)
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
