//
//  MonsterRarity.swift
//  PurgeQuest
//
//  Rarity tiers frame every bestiary entry and drive the reward profile.
//  Comparable so rarity sorting and gating read naturally.
//

import SwiftUI

enum MonsterRarity: Int, Codable, Comparable, CaseIterable, Sendable {
    case common = 1
    case uncommon = 2
    case rare = 3
    case elite = 4
    case legendary = 5

    static func < (lhs: MonsterRarity, rhs: MonsterRarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .common:    return "Common"
        case .uncommon:  return "Uncommon"
        case .rare:      return "Rare"
        case .elite:     return "Elite"
        case .legendary: return "Legendary"
        }
    }

    /// Frame color for bestiary plaques and encounter cards.
    var frameColor: Color {
        switch self {
        case .common:    return .dungeonAsh
        case .uncommon:  return .gemEmerald
        case .rare:      return .videoSapphire
        case .elite:     return .questAmberDeep
        case .legendary: return .combatCrimson
        }
    }

    /// Plain-language reward profile shown in the bestiary.
    var rewardProfile: String {
        switch self {
        case .common:    return "Modest XP · light loot"
        case .uncommon:  return "Solid XP · fair loot"
        case .rare:      return "Rich XP · juicy loot"
        case .elite:     return "Heavy XP · boss loot"
        case .legendary: return "Massive XP · hoard loot"
        }
    }

    var hasCrownBadge: Bool { self >= .elite }
}
