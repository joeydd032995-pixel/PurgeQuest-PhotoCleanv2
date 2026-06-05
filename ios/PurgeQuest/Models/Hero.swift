//
//  Hero.swift
//  PurgeQuest
//

import Foundation
import SwiftData

enum HeroClass: String, CaseIterable, Codable {
    case archivist
    case cinematographer
    case purgeKnight
    case digitalHermit

    var displayName: String {
        switch self {
        case .archivist:       return "Archivist"
        case .cinematographer: return "Cinematographer"
        case .purgeKnight:     return "Purge Knight"
        case .digitalHermit:   return "Digital Hermit"
        }
    }

    var symbol: String {
        switch self {
        case .archivist:       return "books.vertical.fill"
        case .cinematographer: return "video.fill"
        case .purgeKnight:     return "shield.lefthalf.filled"
        case .digitalHermit:   return "moon.stars.fill"
        }
    }

    var perkDescription: String {
        switch self {
        case .archivist:       return "+20% XP from photo monsters"
        case .cinematographer: return "+20% XP from video monsters"
        case .purgeKnight:     return "+30% XP from elite monsters"
        case .digitalHermit:   return "+10% Gem multiplier"
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
    var createdAt: Date

    var heroClass: HeroClass {
        get { HeroClass(rawValue: heroClassRaw) ?? .purgeKnight }
        set { heroClassRaw = newValue.rawValue }
    }

    init(
        name: String = "Hero",
        heroClass: HeroClass = .purgeKnight
    ) {
        self.id = UUID()
        self.name = name
        self.heroClassRaw = heroClass.rawValue
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
