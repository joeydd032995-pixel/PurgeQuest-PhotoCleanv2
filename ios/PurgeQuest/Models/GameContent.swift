//
//  GameContent.swift
//  PurgeQuest
//
//  The game content that names monsters, as plain data: the daily quest pool and each seasonal
//  event's XP bonus. It lives apart from SwiftData (Quest) and SwiftUI (SeasonalEvent) so the Linux
//  harness can check, without a simulator, that everything it names is a monster the classifier can
//  summon (ContentReachabilityTests).
//

import Foundation

enum QuestKind: String, Codable, Sendable {
    case photoSlay     // delete N photo monsters of a specific type
    case videoSlay     // delete N video monsters of a specific type
    case mbFreed       // free X MB
    case anySlay       // delete N items, any kind
}

/// One quest the daily draw can pick. `Quest(template:)` turns it into the stored model.
struct QuestTemplate: Sendable, Equatable {
    let title: String
    let subtitle: String
    let kind: QuestKind
    let monsterType: MonsterType?
    let targetCount: Int
    let rewardXP: Int
    let rewardGems: Int
}

enum QuestCatalog {
    /// Every quest the daily draw can pick from.
    static let daily: [QuestTemplate] = [
        QuestTemplate(title: "Blur Beast Hunter", subtitle: "Slay 8 blurry photo monsters.",
                      kind: .photoSlay, monsterType: .blurBeast, targetCount: 8, rewardXP: 120, rewardGems: 60),
        QuestTemplate(title: "Duplicate Dragon Slayer", subtitle: "Vanquish 5 Duplicate Dragons.",
                      kind: .photoSlay, monsterType: .duplicateDragon, targetCount: 5, rewardXP: 160, rewardGems: 80),
        QuestTemplate(title: "Video Vampire Purge", subtitle: "Banish 6 Video Vampires.",
                      kind: .videoSlay, monsterType: .videoVampire, targetCount: 6, rewardXP: 200, rewardGems: 100),
        QuestTemplate(title: "Long-Take Leviathan", subtitle: "Defeat 3 Leviathans over 2 minutes.",
                      kind: .videoSlay, monsterType: .longTakeLeviathan, targetCount: 3, rewardXP: 240, rewardGems: 140),
        QuestTemplate(title: "Storage Liberation", subtitle: "Move 500 MB to Recently Deleted in one session.",
                      kind: .mbFreed, monsterType: nil, targetCount: 500, rewardXP: 180, rewardGems: 120),
        QuestTemplate(title: "Dungeon Clear", subtitle: "Defeat 25 monsters of any kind.",
                      kind: .anySlay, monsterType: nil, targetCount: 25, rewardXP: 150, rewardGems: 70),
        QuestTemplate(title: "Memory Hog Hunter", subtitle: "Slay 2 Memory Hog Minotaurs.",
                      kind: .videoSlay, monsterType: .memoryHogMinotaur, targetCount: 2, rewardXP: 220, rewardGems: 140)
    ]
}

/// The monsters a seasonal event pays extra XP for, and by how much.
struct SeasonalBonus: Sendable, Equatable {
    let monsters: Set<MonsterType>
    let multiplier: Double

    /// True when slaying `slain` earns the bonus. A bonus written for the Duplicate Dragon covers the
    /// whole Duplicate Dragons family, exactly as quests and achievements do (`MonsterType.counts(as:)`);
    /// most real duplicate groups are a pair, a burst or an edited copy, not the literal Dragon.
    func applies(to slain: MonsterType) -> Bool {
        monsters.contains { slain.counts(as: $0) }
    }

    /// The XP multiplier for `slain`: the bonus when it applies, otherwise 1.
    func multiplier(for slain: MonsterType) -> Double {
        applies(to: slain) ? multiplier : 1.0
    }
}

enum SeasonalBonusCatalog {
    static let halloween = SeasonalBonus(
        monsters: [.darkWraith, .corruptedCodec, .shakyGhost, .mistWraith, .tatterWraith, .voidWraith],
        multiplier: 1.5
    )
    static let newYear = SeasonalBonus(monsters: [.ancientArchive, .duplicateDragon], multiplier: 1.75)
    static let summer = SeasonalBonus(monsters: [.longTakeLeviathan, .videoVampire, .timelapsePhantom], multiplier: 1.5)
    static let valentine = SeasonalBonus(monsters: [.screenshotSpecter, .blurBeast, .lowQualityLich], multiplier: 1.6)

    /// Keyed by `SeasonalEvent.id`. SeasonalCatalogTests checks that every event has an entry here.
    static let byEventID: [String: SeasonalBonus] = [
        "halloween": halloween,
        "newyear": newYear,
        "summer": summer,
        "valentine": valentine
    ]
}
