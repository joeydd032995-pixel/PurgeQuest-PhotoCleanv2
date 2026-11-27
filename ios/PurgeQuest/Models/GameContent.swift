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

/// How a storage quest adds up. Its target is in megabytes as Photos shows them (1 MB = 1,000,000 bytes, the
/// unit the classifier's size lines use too), and a confirmed room adds the total size of what it deleted,
/// rounded once to the nearest megabyte. Each file used to be rounded on its own, in mebibytes, so a file under
/// half a megabyte added nothing: 600 screenshots of 470 KB (282 MB) moved the quest by 0.
nonisolated enum QuestProgress {
    static let bytesPerMegabyte: Int64 = 1_000_000

    /// Whole megabytes for a room's total deleted bytes; halves round up. Nothing (or less) adds nothing.
    static func megabytes(forBytes bytes: Int64) -> Int {
        guard bytes > 0 else { return 0 }
        return Int((bytes + bytesPerMegabyte / 2) / bytesPerMegabyte)
    }
}

enum QuestCatalog {
    /// Every quest the daily draw can pick from.
    ///
    /// Gem rewards (17 November 2026). Deleting now pays a flat 2 gems for a photo and 3 for a video
    /// (`DiveRules`), so a quest's gems are set against what the deletions it asks for already pay. A quest
    /// pays 1.5 to 3.5 times that, the rarer the ask the more, rounded to 5. They were 60 to 140 when a photo
    /// paid about 2.7 gems and a video tens, which would now be worth 30 to 70 photos each.
    ///
    ///   quest                   asks            deletions pay   quest pays   times
    ///   Blur Beast Hunter       8 photos        16              25           1.6
    ///   Duplicate Dragon        5 items         10              25           2.5
    ///   Video Vampire           6 videos        18              40           2.2
    ///   LongTake Leviathan      3 videos         9              25           2.8
    ///   Dungeon Clear           25 items        50              75           1.5
    ///   Memory Hog Hunter       2 videos         6              20           3.3
    ///   Storage Liberation      500 MB          (about 50 items, 100)        100
    ///
    /// XP rewards are unchanged.
    static let daily: [QuestTemplate] = [
        QuestTemplate(title: "Blur Beast Hunter", subtitle: "Delete 8 Blur Beasts: photos that no other monster claims, blurry or sharp. A Live Photo, a screenshot or a duplicate is a different monster.",
                      kind: .photoSlay, monsterType: .blurBeast, targetCount: 8, rewardXP: 120, rewardGems: 25),
        QuestTemplate(title: "Duplicate Dragon Slayer", subtitle: "Delete 5 items from duplicate groups, photos or videos. Copies, bursts, edits and repeats all count.",
                      kind: .photoSlay, monsterType: .duplicateDragon, targetCount: 5, rewardXP: 160, rewardGems: 25),
        QuestTemplate(title: "Video Vampire Purge", subtitle: "Delete 6 Video Vampires: videos of 100 MB or more but under 500 MB that fit no other monster.",
                      kind: .videoSlay, monsterType: .videoVampire, targetCount: 6, rewardXP: 200, rewardGems: 40),
        QuestTemplate(title: "LongTake Leviathan", subtitle: "Delete 3 LongTake Leviathans: videos over two minutes, under 500 MB, not 4K and not duplicates.",
                      kind: .videoSlay, monsterType: .longTakeLeviathan, targetCount: 3, rewardXP: 240, rewardGems: 25),
        QuestTemplate(title: "Storage Liberation", subtitle: "Delete 500 MB of photos and videos today. Each room you confirm adds the size of what you deleted.",
                      kind: .mbFreed, monsterType: nil, targetCount: 500, rewardXP: 180, rewardGems: 100),
        QuestTemplate(title: "Dungeon Clear", subtitle: "Delete 25 photos or videos. Any monster counts; Shades do not.",
                      kind: .anySlay, monsterType: nil, targetCount: 25, rewardXP: 150, rewardGems: 75),
        QuestTemplate(title: "Memory Hog Hunter", subtitle: "Delete 2 Memory Hog Minotaurs: videos of 500 MB or more but under 1 GB, not duplicates.",
                      kind: .videoSlay, monsterType: .memoryHogMinotaur, targetCount: 2, rewardXP: 220, rewardGems: 20)
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
