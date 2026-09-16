//
//  HeroRace.swift
//  PurgeQuest
//
//  The nine playable races, one per illustrated art pack. Each race maps to a
//  bundled sprite set (`Art/Races/<rawValue>/v1..v3`) rendered by SpriteEngine.
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
    case forestRanger = "forest_ranger"
    case seer
    case bloodAlchemist = "blood_alchemist"
    case darkOracle = "dark_oracle"
    case necromancer
    case skeletonCrusader = "skeleton_crusader"
    case skeletonWarrior = "skeleton_warrior"
    case golem

    /// Maps a pre-race save to its designed default race.
    init(legacyArchetype: CharacterArchetype) {
        self = legacyArchetype == .knight ? .valkyrie : .seer
    }

    var displayName: String {
        switch self {
        case .valkyrie:         return "Valkyrie"
        case .forestRanger:     return "Forest Ranger"
        case .seer:             return "Seer"
        case .bloodAlchemist:   return "Blood Alchemist"
        case .darkOracle:       return "Dark Oracle"
        case .necromancer:      return "Necromancer"
        case .skeletonCrusader: return "Skeleton Crusader"
        case .skeletonWarrior:  return "Skeleton Warrior"
        case .golem:            return "Golem"
        }
    }

    var tagline: String {
        switch self {
        case .valkyrie:         return "Winged judgment in gilded steel."
        case .forestRanger:     return "A bowstring whispered between trees."
        case .seer:             return "Reads the archive's hidden fates."
        case .bloodAlchemist:   return "Transmutes clutter into reclaimed space."
        case .darkOracle:       return "Prophecies written in deleted bytes."
        case .necromancer:      return "Commands the shadows of dead media."
        case .skeletonCrusader: return "An oath that outlived its body."
        case .skeletonWarrior:  return "Old bones, sharper edge."
        case .golem:            return "Carved from the dungeon's deepest vault."
        }
    }

    /// SF Symbol fallback used before sprite art loads.
    var symbol: String {
        switch self {
        case .valkyrie:         return "shield.lefthalf.filled"
        case .forestRanger:     return "leaf.fill"
        case .seer:             return "eye.fill"
        case .bloodAlchemist:   return "flask.fill"
        case .darkOracle:       return "moon.stars.fill"
        case .necromancer:      return "wand.and.stars"
        case .skeletonCrusader: return "helmet.fill"
        case .skeletonWarrior:  return "sword.fill"
        case .golem:            return "square.stack.3d.up.fill"
        }
    }

    /// Accent color from the existing dungeon palette — no new hues.
    var accent: Color {
        switch self {
        case .valkyrie:         return .questAmber
        case .forestRanger:     return .gemEmerald
        case .seer:             return .xpViolet
        case .bloodAlchemist:   return .combatCrimson
        case .darkOracle:       return .videoSapphire
        case .necromancer:      return .videoSapphire
        case .skeletonCrusader: return .questAmberDeep
        case .skeletonWarrior:  return .dungeonAsh
        case .golem:            return .gemEmerald
        }
    }

    /// Which recolor palette the forge shows for this race.
    var palette: BodyPalette {
        switch self {
        case .skeletonCrusader, .skeletonWarrior: return .bone
        case .golem: return .stone
        default: return .flesh
        }
    }

    /// Bundled attack animation name in the Spriter project.
    var attackAnimationName: String { self == .forestRanger ? "Shooting" : "Slashing" }

    /// The class the forge recommends for this race's silhouette.
    var recommendedClass: HeroClass {
        switch self {
        case .valkyrie:         return .paladinHoly
        case .forestRanger:     return .hunter
        case .seer:             return .priestDivine
        case .bloodAlchemist:   return .roguePoison
        case .darkOracle:       return .mageIce
        case .necromancer:      return .paladinUnholy
        case .skeletonCrusader: return .paladinHoly
        case .skeletonWarrior:  return .warriorBlood
        case .golem:            return .shamanEarth
        }
    }
}
