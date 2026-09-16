//
//  Hero.swift
//  PurgeQuest
//

import Foundation
import SwiftData

/// The player's visual persona, chosen at launch. Purely cosmetic identity —
/// gameplay bonuses come from HeroClass.
enum CharacterArchetype: String, CaseIterable, Codable {
    case knight
    case magician

    var displayName: String {
        switch self {
        case .knight:   return "Knight"
        case .magician: return "Magician"
        }
    }

    var symbol: String {
        switch self {
        case .knight:   return "figure.fencing"
        case .magician: return "wand.and.stars"
        }
    }

    var tagline: String {
        switch self {
        case .knight:   return "Steel, shield and stubborn courage."
        case .magician: return "Sigils, spells and storage sorcery."
        }
    }
}

/// The three class disciplines, shown as groups in pickers.
enum HeroDiscipline: String, CaseIterable, Codable {
    case melee
    case ranged
    case magic

    var displayName: String {
        switch self {
        case .melee:  return "Melee"
        case .ranged: return "Ranged"
        case .magic:  return "Magic"
        }
    }

    var symbol: String {
        switch self {
        case .melee:  return "sword.fill"
        case .ranged: return "target"
        case .magic:  return "wand.and.stars"
        }
    }
}

/// The playable class roster: 17 variants across three disciplines.
/// Each class grants a passive XP or gem bonus applied at purge time.
enum HeroClass: String, CaseIterable, Codable {
    // Melee
    case paladinHoly
    case paladinUnholy
    case warriorBlood
    case warriorShadow
    case roguePoison
    case rogueAssassin
    // Ranged
    case hunter
    case windrunner
    case voidstalker
    // Magic
    case mageIce
    case mageInferno
    case priestPlague
    case priestDivine
    case shamanEarth
    case shamanWind
    case shamanFire
    case shamanWater

    var discipline: HeroDiscipline {
        switch self {
        case .paladinHoly, .paladinUnholy, .warriorBlood, .warriorShadow, .roguePoison, .rogueAssassin:
            return .melee
        case .hunter, .windrunner, .voidstalker:
            return .ranged
        case .mageIce, .mageInferno, .priestPlague, .priestDivine, .shamanEarth, .shamanWind, .shamanFire, .shamanWater:
            return .magic
        }
    }

    var displayName: String {
        switch self {
        case .paladinHoly:    return "Holy Paladin"
        case .paladinUnholy:  return "Unholy Paladin"
        case .warriorBlood:   return "Blood Warrior"
        case .warriorShadow:  return "Shadow Warrior"
        case .roguePoison:    return "Poison Rogue"
        case .rogueAssassin:  return "Assassin"
        case .hunter:         return "Hunter"
        case .windrunner:     return "Windrunner"
        case .voidstalker:    return "Voidstalker"
        case .mageIce:        return "Ice Mage"
        case .mageInferno:    return "Inferno Mage"
        case .priestPlague:   return "Plague Priest"
        case .priestDivine:   return "Divine Battle Priest"
        case .shamanEarth:    return "Earth Shaman"
        case .shamanWind:     return "Wind Shaman"
        case .shamanFire:     return "Fire Shaman"
        case .shamanWater:    return "Water Shaman"
        }
    }

    var symbol: String {
        switch self {
        case .paladinHoly:    return "shield.lefthalf.filled"
        case .paladinUnholy:  return "flame.fill"
        case .warriorBlood:   return "drop.fill"
        case .warriorShadow:  return "moon.fill"
        case .roguePoison:    return "sparkles"
        case .rogueAssassin:  return "burst.fill"
        case .hunter:         return "leaf.fill"
        case .windrunner:     return "wind"
        case .voidstalker:    return "theatermasks.fill"
        case .mageIce:        return "snowflake"
        case .mageInferno:    return "flame.fill"
        case .priestPlague:   return "cross.vial.fill"
        case .priestDivine:   return "sun.max.fill"
        case .shamanEarth:    return "mountain.2.fill"
        case .shamanWind:     return "wind"
        case .shamanFire:     return "flame.fill"
        case .shamanWater:    return "drop.fill"
        }
    }

    var perkDescription: String {
        switch self {
        case .paladinHoly:    return "+30% XP from elite monsters"
        case .paladinUnholy:  return "+25% XP from Glitchborn monsters"
        case .warriorBlood:   return "+20% XP from Clutter Undead"
        case .warriorShadow:  return "+20% XP from Storage Behemoths"
        case .roguePoison:    return "+20% XP from uncommon monsters"
        case .rogueAssassin:  return "+25% XP from common monsters"
        case .hunter:         return "+20% XP from photo monsters"
        case .windrunner:     return "+20% XP from video monsters"
        case .voidstalker:    return "+15% Gem multiplier"
        case .mageIce:        return "+20% XP from Archive Relics"
        case .mageInferno:    return "+20% XP from rare monsters"
        case .priestPlague:   return "+20% XP from Duplicate Dragons"
        case .priestDivine:   return "+20% XP from elite monsters"
        case .shamanEarth:    return "+10% Gem multiplier"
        case .shamanWind:     return "+20% XP from Video Phantoms"
        case .shamanFire:     return "+20% XP from uncommon monsters"
        case .shamanWater:    return "+15% Gem multiplier"
        }
    }

    /// Maps pre-overhaul class raw values to their new equivalents so old
    /// saves keep an equivalent perk.
    static func legacyClass(forRaw raw: String) -> HeroClass? {
        switch raw {
        case "purgeKnight":     return .paladinHoly
        case "archivist":       return .priestDivine
        case "cinematographer": return .windrunner
        case "digitalHermit":   return .shamanEarth
        default:                return nil
        }
    }

    /// XP multiplier for a purge. `photo` is true for photo monsters.
    func xpMultiplier(photo: Bool, monsterType: MonsterType) -> Double {
        switch self {
        case .hunter:          return photo ? 1.20 : 1.0
        case .windrunner:      return photo ? 1.0 : 1.20
        case .paladinHoly:     return monsterType.isElite ? 1.30 : 1.0
        case .priestDivine:    return monsterType.isElite ? 1.20 : 1.0
        case .paladinUnholy:   return monsterType.family == .glitchborn ? 1.25 : 1.0
        case .warriorBlood:    return monsterType.family == .clutterUndead ? 1.20 : 1.0
        case .warriorShadow:   return monsterType.family == .storageBehemoths ? 1.20 : 1.0
        case .mageIce:         return monsterType.family == .archiveRelics ? 1.20 : 1.0
        case .shamanWind:      return monsterType.family == .videoPhantoms ? 1.20 : 1.0
        case .priestPlague:    return monsterType.family == .duplicateDragons ? 1.20 : 1.0
        case .rogueAssassin:   return monsterType.rarity == .common ? 1.25 : 1.0
        case .roguePoison, .shamanFire: return monsterType.rarity == .uncommon ? 1.20 : 1.0
        case .mageInferno:     return monsterType.rarity == .rare ? 1.20 : 1.0
        default:               return 1.0
        }
    }

    /// Gem multiplier applied to purge rewards.
    var gemMultiplier: Double {
        switch self {
        case .voidstalker, .shamanWater: return 1.15
        case .shamanEarth:               return 1.10
        default:                         return 1.0
        }
    }
}

@Model
final class Hero {
    @Attribute(.unique) var id: UUID
    var name: String
    var heroClassRaw: String
    var level: Int
    var totalXP: Int
    var currentHP: Int
    var maxHP: Int
    var gems: Int
    var streakDays: Int
    var lastPlayedDate: Date?
    var totalMBFreed: Double
    var totalPhotosPurged: Int
    var totalVideosPurged: Int
    var highestCombo: Int
    var equippedSkinID: String?
    var archetypeRaw: String = CharacterArchetype.knight.rawValue
    var createdAt: Date
    /// JSON-encoded HeroAppearance. nil or corrupt data decodes to the
    /// designed default for the archetype.
    var appearanceData: Data?
    /// Permanent Titan Blade upgrade: doubles the size of the held weapon.
    var titanWeaponUnlocked: Bool = false

    var heroClass: HeroClass {
        get {
            HeroClass(rawValue: heroClassRaw)
                ?? HeroClass.legacyClass(forRaw: heroClassRaw)
                ?? .paladinHoly
        }
        set { heroClassRaw = newValue.rawValue }
    }

    var archetype: CharacterArchetype {
        get { CharacterArchetype(rawValue: archetypeRaw) ?? .knight }
        set { archetypeRaw = newValue.rawValue }
    }

    /// The hero's illustrated race. Stored inside the appearance record;
    /// falls back to the legacy archetype's designed default.
    var race: HeroRace {
        get { appearance.race ?? HeroRace(legacyArchetype: archetype) }
        set {
            var look = appearance
            look.race = newValue
            if look.paintVariant < 1 || look.paintVariant > 3 { look.paintVariant = 1 }
            appearance = look
        }
    }

    /// The hero's saved identity. Always decodes to a valid look, even for
    /// records written before this field existed.
    var appearance: HeroAppearance {
        get { HeroAppearance.decode(appearanceData, for: archetype) }
        set { appearanceData = newValue.encoded() }
    }

    init(
        name: String = "Hero",
        heroClass: HeroClass = .paladinHoly,
        archetype: CharacterArchetype = .knight
    ) {
        self.id = UUID()
        self.name = name
        self.heroClassRaw = heroClass.rawValue
        self.archetypeRaw = archetype.rawValue
        self.level = 1
        self.totalXP = 0
        self.currentHP = 100
        self.maxHP = 100
        self.gems = 0
        self.streakDays = 0
        self.lastPlayedDate = nil
        self.totalMBFreed = 0
        self.totalPhotosPurged = 0
        self.totalVideosPurged = 0
        self.highestCombo = 0
        self.equippedSkinID = nil
        self.createdAt = Date()
        self.appearanceData = nil
        self.titanWeaponUnlocked = false
    }

    /// XP needed to reach a given level (cumulative).
    static func xpForLevel(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        return Int(100.0 * pow(Double(level - 1), 1.5))
    }

    static func xpForNextLevel(currentLevel: Int) -> Int {
        xpForLevel(currentLevel + 1) - xpForLevel(currentLevel)
    }

    var xpIntoCurrentLevel: Int {
        totalXP - Hero.xpForLevel(level)
    }

    var xpToNext: Int {
        Hero.xpForNextLevel(currentLevel: level)
    }

    var levelProgress: Double {
        let into = max(0, xpIntoCurrentLevel)
        let total = max(1, xpToNext)
        return min(1.0, Double(into) / Double(total))
    }
}
