//
//  HeroAppearance+Unlockables.swift
//  PurgeQuest
//
//  Achievement gating for cosmetic dyes. Each gated dye family unlocks from
//  one lifetime achievement — the same one across hair, eyes, and armor — so
//  the rule stays easy to follow. Free traits return nil.
//

import Foundation

extension HairColor {
    /// The achievement id that unlocks this dye, or nil when always available.
    var requiredAchievementID: String? {
        switch self {
        case .gilded:    return "great.purge"
        case .verdigris: return "duplicate.slayer"
        case .crimson:   return "combo.king"
        case .bone:      return "video.vault"
        default:         return nil
        }
    }
}

extension EyeColor {
    /// The achievement id that unlocks this iris color, or nil when always available.
    var requiredAchievementID: String? {
        switch self {
        case .gilded:    return "great.purge"
        case .verdigris: return "duplicate.slayer"
        case .crimson:   return "combo.king"
        default:         return nil
        }
    }
}

extension ArmorDye {
    /// The achievement id that unlocks this dye, or nil when always available.
    var requiredAchievementID: String? {
        switch self {
        case .gilded:    return "great.purge"
        case .verdigris: return "duplicate.slayer"
        case .crimson:   return "combo.king"
        case .bone:      return "video.vault"
        default:         return nil
        }
    }
}

enum DyeGate {
    /// The achievement gating the Titan Blade upgrade.
    static let titanWeaponAchievementID = "streak.warrior"

    /// Fallback titles so lock hints stay meaningful even before the
    /// Achievement records are queried.
    static func achievementTitle(for id: String) -> String {
        switch id {
        case "great.purge":     return "The Great Purge"
        case "duplicate.slayer": return "Duplicate Slayer"
        case "combo.king":      return "Combo King"
        case "video.vault":     return "Video Vault Vanquisher"
        case "streak.warrior":  return "Streak Warrior"
        default:                return "an achievement"
        }
    }

    /// Human-readable requirement, e.g. "Requires The Great Purge".
    static func requirementText(for achievementID: String) -> String {
        "Requires \(achievementTitle(for: achievementID))"
    }
}
