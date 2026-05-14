//
//  GameDataService.swift
//  PurgeQuest
//
//  Seeds and refreshes daily quests, achievements, and the cosmetic catalog.
//

import Foundation
import SwiftData

@MainActor
enum GameDataService {

    // MARK: - Hero

    static func loadOrCreateHero(in context: ModelContext) -> Hero {
        let descriptor = FetchDescriptor<Hero>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let hero = Hero()
        context.insert(hero)
        try? context.save()
        return hero
    }

    // MARK: - Cosmetics

    static func seedCosmeticsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<CosmeticItem>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty { return }

        let seeds: [CosmeticItem] = [
            CosmeticItem(id: "skin.iron",      name: "Iron Vestments",     subtitle: "Default armor — sturdy and bold.",     type: .skin,   iconName: "shield.lefthalf.filled", priceGems: 0,    isUnlocked: true),
            CosmeticItem(id: "skin.embers",    name: "Ember Cloak",        subtitle: "Crimson flames trail your steps.",     type: .skin,   iconName: "flame.fill",             priceGems: 250),
            CosmeticItem(id: "skin.archivist", name: "Archivist Robes",    subtitle: "For the patient cataloguer.",          type: .skin,   iconName: "books.vertical.fill",    priceGems: 400),
            CosmeticItem(id: "weapon.shard",   name: "Crystal Shard",      subtitle: "Default weapon. Sharp and reliable.",  type: .weapon, iconName: "sparkle",                priceGems: 0,    isUnlocked: true),
            CosmeticItem(id: "weapon.reel",    name: "Film Reel Blade",    subtitle: "Slices videos with cinematic flair.",  type: .weapon, iconName: "film.fill",              priceGems: 600,  isVideoThemed: true),
            CosmeticItem(id: "weapon.gem",     name: "Gem Hammer",         subtitle: "+10% gem flair on critical hits.",     type: .weapon, iconName: "hammer.fill",            priceGems: 800),
            CosmeticItem(id: "pet.familiar",   name: "Pixel Familiar",     subtitle: "A loyal companion of pure light.",     type: .pet,    iconName: "pawprint.fill",          priceGems: 350,  isUnlocked: true),
            CosmeticItem(id: "pet.reel",       name: "Reel Spirit",        subtitle: "A spectral film reel that hovers.",    type: .pet,    iconName: "video.circle.fill",      priceGems: 550,  isVideoThemed: true),
            CosmeticItem(id: "fx.sparks",      name: "Golden Sparks",      subtitle: "Default delete particle.",             type: .effect, iconName: "sparkles",               priceGems: 0,    isUnlocked: true),
            CosmeticItem(id: "fx.filmstrip",   name: "Film Strip Burst",   subtitle: "Strips of film cascade on delete.",    type: .effect, iconName: "film.stack.fill",        priceGems: 450,  isVideoThemed: true),
            CosmeticItem(id: "fx.aurora",      name: "Aurora Trail",       subtitle: "Soft northern-light particles.",       type: .effect, iconName: "moon.haze.fill",         priceGems: 700)
        ]
        for item in seeds { context.insert(item) }
        try? context.save()
    }

    // MARK: - Achievements

    static func seedAchievementsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Achievement>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty { return }

        let seeds: [Achievement] = [
            Achievement(id: "first.blood",         title: "First Blood",          subtitle: "Delete your first photo.",           iconName: "drop.fill",            goal: 1),
            Achievement(id: "scene.cut",           title: "Scene Cut",            subtitle: "Delete your first video.",           iconName: "scissors",             goal: 1),
            Achievement(id: "duplicate.slayer",   title: "Duplicate Slayer",     subtitle: "Slay 50 Duplicate Dragons.",          iconName: "square.on.square",     goal: 50),
            Achievement(id: "video.vault",        title: "Video Vault Vanquisher", subtitle: "Delete 100 videos total.",         iconName: "film.stack.fill",      goal: 100),
            Achievement(id: "great.purge",        title: "The Great Purge",      subtitle: "Free 1 GB of storage.",               iconName: "internaldrive.fill",   goal: 1024),
            Achievement(id: "long.take.term",     title: "Longest Take Terminated", subtitle: "Delete a video over 10 minutes.",  iconName: "video.badge.checkmark", goal: 1),
            Achievement(id: "combo.king",         title: "Combo King",            subtitle: "Reach a 20× combo.",                 iconName: "bolt.fill",            goal: 20),
            Achievement(id: "ancient.archivist",  title: "Ancient Archivist",     subtitle: "Delete 25 photos older than 5 yrs.", iconName: "hourglass",            goal: 25),
            Achievement(id: "streak.warrior",     title: "Streak Warrior",        subtitle: "Maintain a 7-day streak.",           iconName: "flame.fill",           goal: 7),
            Achievement(id: "perfect.room",       title: "Perfect Room",          subtitle: "Clear a room without taking damage.", iconName: "checkmark.seal.fill", goal: 1),
            Achievement(id: "video.speedrun",     title: "Video Speedrun",        subtitle: "Delete 20 videos in one room.",      iconName: "hare.fill",            goal: 1)
        ]
        for a in seeds { context.insert(a) }
        try? context.save()
    }

    // MARK: - Daily Quests

    static func refreshDailyQuestsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Quest>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let now = Date()
        let stillFresh = existing.filter { $0.expiresAt > now }
        if !stillFresh.isEmpty {
            // expire the old ones if any
            for q in existing where q.expiresAt <= now { context.delete(q) }
            try? context.save()
            return
        }
        // wipe and reseed
        for q in existing { context.delete(q) }

        let pool: [Quest] = [
            Quest(title: "Blur Beast Hunter",      subtitle: "Slay 8 blurry photo monsters.",      kind: .photoSlay, monsterType: .blurBeast,      targetCount: 8, rewardXP: 120, rewardGems: 60),
            Quest(title: "Duplicate Dragon Slayer", subtitle: "Vanquish 5 Duplicate Dragons.",     kind: .photoSlay, monsterType: .duplicateDragon, targetCount: 5, rewardXP: 160, rewardGems: 80),
            Quest(title: "Video Vampire Purge",    subtitle: "Banish 6 Video Vampires.",           kind: .videoSlay, monsterType: .videoVampire,    targetCount: 6, rewardXP: 200, rewardGems: 100),
            Quest(title: "Long-Take Leviathan",    subtitle: "Defeat 3 Leviathans over 2 minutes.", kind: .videoSlay, monsterType: .longTakeLeviathan, targetCount: 3, rewardXP: 240, rewardGems: 140),
            Quest(title: "Storage Liberation",     subtitle: "Free 500 MB in a single session.",   kind: .mbFreed,    monsterType: nil,             targetCount: 500, rewardXP: 180, rewardGems: 120),
            Quest(title: "Dungeon Clear",          subtitle: "Defeat 25 monsters of any kind.",    kind: .anySlay,    monsterType: nil,             targetCount: 25, rewardXP: 150, rewardGems: 70),
            Quest(title: "Memory Hog Hunter",      subtitle: "Slay 2 Memory Hog Minotaurs.",       kind: .videoSlay,  monsterType: .memoryHogMinotaur, targetCount: 2, rewardXP: 220, rewardGems: 140)
        ]

        // Pick 4 distinct quests
        for quest in pool.shuffled().prefix(4) {
            context.insert(quest)
        }
        try? context.save()
    }

    static func updateQuests(_ quests: [Quest], for slainMonster: MonsterType, mbFreedThisAction: Double) {
        for q in quests where !q.completed {
            switch q.kind {
            case .photoSlay:
                if slainMonster.kind == .photo, q.monsterType == slainMonster {
                    q.currentCount += 1
                }
            case .videoSlay:
                if slainMonster.kind == .video, q.monsterType == slainMonster {
                    q.currentCount += 1
                }
            case .anySlay:
                q.currentCount += 1
            case .mbFreed:
                q.currentCount += Int(mbFreedThisAction.rounded())
            }
            if q.currentCount >= q.targetCount {
                q.currentCount = q.targetCount
                q.completed = true
            }
        }
    }
}
