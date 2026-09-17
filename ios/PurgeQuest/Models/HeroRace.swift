//
//  HeroRace.swift
//  PurgeQuest
//
//  The eight playable races, built from the illustrated art packs. Each race
//  maps to a bundled sprite set (`Art/Races/<rawValue>/v1..v3`) rendered by
//  SpriteEngine. The Skeleton Crusader and Skeleton Warrior packs merged into
//  a single Skeletal Undead race with six paint jobs: variants 1-3 use the
//  crusader art, variants 4-6 the warrior art.
//

import SwiftUI

/// Palette family driving which recolor sliders make sense for a race.
nonisolated enum BodyPalette: String, Codable {
    case flesh
    case bone
    case stone
}

nonisolated enum HeroRace: String, CaseIterable, Codable, Sendable {
    case valkyrie
    case elven = "forest_ranger"
    case seer
    case vampyri = "blood_alchemist"
    case scarredOnes = "dark_oracle"
    case lostSouls = "necromancer"
    case skeletalUndead = "skeleton_crusader"
    case golem

    /// Maps a pre-race save to its designed default race.
    init(legacyArchetype: CharacterArchetype) {
        self = legacyArchetype == .knight ? .valkyrie : .seer
    }

    /// Decodes a stored raw value. The removed Skeleton Warrior pack folds
    /// into the merged Skeletal Undead race; unknown values fall back to the
    /// Valkyrie default so old saves always decode to a real character.
    init(legacyRaw: String) {
        self = legacyRaw == "skeleton_warrior"
            ? .skeletalUndead
            : (HeroRace(rawValue: legacyRaw) ?? .valkyrie)
    }

    var displayName: String {
        switch self {
        case .valkyrie:       return "Valkyrie"
        case .elven:          return "Elven"
        case .seer:           return "Seer"
        case .vampyri:        return "Vampyri"
        case .scarredOnes:    return "The Scarred Ones"
        case .lostSouls:      return "Lost Souls"
        case .skeletalUndead: return "Skeletal Undead"
        case .golem:          return "Golem"
        }
    }

    var tagline: String {
        switch self {
        case .valkyrie:       return "Winged judgment in gilded steel."
        case .elven:          return "A bowstring whispered between trees."
        case .seer:           return "Reads the archive's hidden fates."
        case .vampyri:        return "Transmutes clutter into reclaimed space."
        case .scarredOnes:    return "Prophecies written in deleted bytes."
        case .lostSouls:      return "Commands the shadows of dead media."
        case .skeletalUndead: return "Old bones, one undying oath."
        case .golem:          return "Carved from the dungeon's deepest vault."
        }
    }

    /// SF Symbol fallback used before sprite art loads.
    var symbol: String {
        switch self {
        case .valkyrie:       return "shield.lefthalf.filled"
        case .elven:          return "leaf.fill"
        case .seer:           return "eye.fill"
        case .vampyri:        return "flask.fill"
        case .scarredOnes:    return "moon.stars.fill"
        case .lostSouls:      return "wand.and.stars"
        case .skeletalUndead: return "helmet.fill"
        case .golem:          return "square.stack.3d.up.fill"
        }
    }

    /// Accent color from the existing dungeon palette — no new hues.
    var accent: Color {
        switch self {
        case .valkyrie:       return .questAmber
        case .elven:          return .gemEmerald
        case .seer:           return .xpViolet
        case .vampyri:        return .combatCrimson
        case .scarredOnes:    return .videoSapphire
        case .lostSouls:      return .videoSapphire
        case .skeletalUndead: return .questAmberDeep
        case .golem:          return .gemEmerald
        }
    }

    /// Which recolor palette the forge shows for this race.
    var palette: BodyPalette {
        switch self {
        case .skeletalUndead: return .bone
        case .golem:          return .stone
        default:              return .flesh
        }
    }

    /// Bundled attack animation name in the Spriter project.
    var attackAnimationName: String { self == .elven ? "Shooting" : "Slashing" }

    /// The class the forge recommends for this race's silhouette.
    var recommendedClass: HeroClass {
        switch self {
        case .valkyrie:       return .paladinHoly
        case .elven:          return .hunter
        case .seer:           return .priestDivine
        case .vampyri:        return .roguePoison
        case .scarredOnes:    return .mageIce
        case .lostSouls:      return .paladinUnholy
        case .skeletalUndead: return .paladinHoly
        case .golem:          return .shamanEarth
        }
    }

    /// Number of bundled paint variants. Skeletal Undead merges the crusader
    /// and warrior packs, so it ships six.
    var variantCount: Int { self == .skeletalUndead ? 6 : 3 }

    /// The bundle base name ("<prefix>_v<n>") for this race's art. Variants
    /// 4-6 of the merged Skeletal Undead resolve into the warrior pack.
    func artBase(variant: Int) -> String {
        if self == .skeletalUndead, variant > 3 {
            return "skeleton_warrior_v\(min(variant - 3, 3))"
        }
        return "\(rawValue)_v\(min(max(variant, 1), 3))"
    }
}
