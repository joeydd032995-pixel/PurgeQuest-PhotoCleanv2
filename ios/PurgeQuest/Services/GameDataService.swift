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

    /// Gets the store ready for the main tabs: seeds the achievement, cosmetic and quest
    /// catalogs, makes sure a hero exists, and applies the choices onboarding saved.
    ///
    /// Every step is idempotent, so this runs at launch and again when onboarding finishes.
    /// The second call matters. "Reset all PurgeQuest data" deletes the hero and every seed
    /// and then shows onboarding again, and the race, class, name and look picked there exist
    /// only as UserDefaults until this applies them. Without it the main tabs open on an
    /// empty store and the Hero tab says "No hero found.".
    ///
    /// The saved choices are applied once and then cleared, so a later change (the Forge can
    /// change race, for one) is never undone by the next launch.
    @discardableResult
    static func provision(in context: ModelContext, defaults: UserDefaults = .standard) -> Hero {
        seedAchievementsIfNeeded(in: context)
        seedCosmeticsIfNeeded(in: context)
        refreshDailyQuestsIfNeeded(in: context)

        let hero = loadOrCreateHero(in: context)
        applyOnboardingChoices(to: hero, defaults: defaults)
        try? context.save()

        // Bring achievement progress in line with lifetime stats and the deletion log.
        syncAchievements(hero: hero, in: context)
        return hero
    }

    /// The UserDefaults keys onboarding writes. Each choice lives there only until `provision`
    /// applies it; reset clears any that are still waiting.
    static let onboardingChoiceKeys = [
        "pq.selectedClass", "pq.race", "pq.appearanceDraft", "pq.archetype", "pq.heroName"
    ]

    static func clearOnboardingChoices(from defaults: UserDefaults = .standard) {
        for key in onboardingChoiceKeys { defaults.removeObject(forKey: key) }
    }

    /// Copies the choices onboarding saved in UserDefaults onto the hero, then clears them so
    /// later changes (a new race from the Forge, say) always win over what was saved here.
    private static func applyOnboardingChoices(to hero: Hero, defaults: UserDefaults) {
        if let className = defaults.string(forKey: "pq.selectedClass") {
            let cls = HeroClass(rawValue: className) ?? HeroClass.legacyClass(forRaw: className)
            if let cls { hero.heroClass = cls }
        }
        if let raceRaw = defaults.string(forKey: "pq.race") {
            // legacyRaw migrates the removed Skeleton Warrior pack.
            hero.race = HeroRace(legacyRaw: raceRaw)
        }
        if let lookData = defaults.data(forKey: "pq.appearanceDraft") {
            hero.appearance = HeroAppearance.decode(lookData, for: hero.archetype)
        }
        if let archetypeRaw = defaults.string(forKey: "pq.archetype"),
           let archetype = CharacterArchetype(rawValue: archetypeRaw) {
            hero.archetype = archetype
        }
        if let name = defaults.string(forKey: "pq.heroName"), !name.isEmpty {
            hero.name = name
        }
        clearOnboardingChoices(from: defaults)
    }

    /// "Reset all PurgeQuest data": erases the hero, the progress and the seeded catalogs, and
    /// forgets that onboarding ever ran, including any choices still waiting to be applied, so
    /// the player starts again from a clean slate. The caller sends the UI back to onboarding.
    static func resetAllData(in context: ModelContext, defaults: UserDefaults = .standard) {
        for hero in (try? context.fetch(FetchDescriptor<Hero>())) ?? [] { context.delete(hero) }
        for record in (try? context.fetch(FetchDescriptor<DeletedMediaRecord>())) ?? [] { context.delete(record) }
        for record in (try? context.fetch(FetchDescriptor<SparedMediaRecord>())) ?? [] { context.delete(record) }
        for quest in (try? context.fetch(FetchDescriptor<Quest>())) ?? [] { context.delete(quest) }
        for achievement in (try? context.fetch(FetchDescriptor<Achievement>())) ?? [] { context.delete(achievement) }
        for item in (try? context.fetch(FetchDescriptor<CosmeticItem>())) ?? [] { context.delete(item) }
        try? context.save()
        defaults.removeObject(forKey: "pq.hasOnboarded")
        clearOnboardingChoices(from: defaults)
    }

    // MARK: - Cosmetics

    static func seedCosmeticsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<CosmeticItem>()
        var existing = (try? context.fetch(descriptor)) ?? []
        var didChange = false

        // One-time migration: Skeleton Crusader and Skeleton Warrior merged
        // into Skeletal Undead, so owned gear re-points to the merged catalog
        // ids. Ownership, equip state, and unlock state are preserved.
        let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for item in existing {
            let migrated = GearCatalog.migratedID(for: item.id)
            guard migrated != item.id else { continue }
            if let counterpart = byID[migrated] {
                counterpart.isEquipped = counterpart.isEquipped || item.isEquipped
                context.delete(item)
            } else {
                item.id = migrated
            }
            didChange = true
        }
        if didChange {
            try? context.save()
            existing = (try? context.fetch(descriptor)) ?? []
        }

        let existingByID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for seed in Self.cosmeticSeeds {
            if let item = existingByID[seed.id] {
                // Sync display copy so catalog updates reach existing installs.
                // Unlock, equip, and type state are never overwritten.
                if item.name != seed.name || item.subtitle != seed.subtitle || item.iconName != seed.iconName {
                    item.name = seed.name
                    item.subtitle = seed.subtitle
                    item.iconName = seed.iconName
                    didChange = true
                }
            } else {
                context.insert(seed)
                didChange = true
            }
        }
        if didChange { try? context.save() }
    }

    /// Full cosmetic catalog. Inserted on first launch and topped up on app updates
    /// so new wearables appear without wiping player progress.
    private static var cosmeticSeeds: [CosmeticItem] {
        let base: [CosmeticItem] = [
        CosmeticItem(id: "skin.iron",      name: "Iron Vestments",     subtitle: "Default armor. Sturdy and bold.",      type: .skin,   iconName: "shield.lefthalf.filled", priceGems: 0,    isUnlocked: true),
        CosmeticItem(id: "skin.embers",    name: "Ember Cloak",        subtitle: "Heat-treated weave. Pairs with ember headgear.", type: .skin, iconName: "flame.fill",             priceGems: 250),
        CosmeticItem(id: "skin.archivist", name: "Archivist Robes",    subtitle: "Catalog-grade cloth for methodical purges.", type: .skin, iconName: "books.vertical.fill",    priceGems: 400),
        CosmeticItem(id: "skin.warden",    name: "Warden Guise",       subtitle: "Heavy plate built for deep vault runs.", type: .skin,   iconName: "person.crop.rectangle.stack.fill", priceGems: 550),
        CosmeticItem(id: "head.iron",      name: "Iron Helm",          subtitle: "Standard issue. Battle-scarred plating.", type: .head,  iconName: "crown.fill",             priceGems: 0,    isUnlocked: true),
        CosmeticItem(id: "head.starhat",   name: "Starlit Cap",        subtitle: "Enchanted brim. Survey-grade focus.",  type: .head,   iconName: "graduationcap.fill",     priceGems: 300),
        CosmeticItem(id: "head.hood",      name: "Shadow Hood",        subtitle: "Low-profile hood for stealth runs.",    type: .head,   iconName: "theatermasks.fill",      priceGems: 500),
        CosmeticItem(id: "head.dragoncrest", name: "Dragoncrest Helm", subtitle: "Scaled plating forged from elite kills.", type: .head,  iconName: "flame.fill",             priceGems: 650),
        CosmeticItem(id: "armor.iron",     name: "Purge Plate",        subtitle: "Standard cuirass. Reliable in every room.", type: .armor,  iconName: "tshirt.fill",            priceGems: 0,    isUnlocked: true),
        CosmeticItem(id: "armor.arcanist", name: "Arcanist Robes",     subtitle: "Mana-woven layers with verdigris trim.", type: .armor,  iconName: "moon.stars.fill",        priceGems: 450),
        CosmeticItem(id: "armor.dragonhide", name: "Dragonhide Cloak", subtitle: "Reinforced seams. Tailored from elite kills.", type: .armor, iconName: "lizard.fill",         priceGems: 800),
        CosmeticItem(id: "weapon.shard",   name: "Crystal Shard",      subtitle: "Standard issue. Sharp and dependable.", type: .weapon, iconName: "rhombus.fill",           priceGems: 0,    isUnlocked: true),
        CosmeticItem(id: "weapon.reel",    name: "Film Reel Blade",    subtitle: "Video-themed edge for media purges.",  type: .weapon, iconName: "film.fill",              priceGems: 600,  isVideoThemed: true),
        CosmeticItem(id: "weapon.gem",     name: "Gem Hammer",         subtitle: "+10% gems on critical hits.",          type: .weapon, iconName: "hammer.fill",            priceGems: 800),
        CosmeticItem(id: "weapon.staff",   name: "Archmage Staff",     subtitle: "Channels deletion magic at range.",    type: .weapon, iconName: "wand.and.stars",         priceGems: 500),
        CosmeticItem(id: "weapon.stormblade", name: "Storm Cleaver",   subtitle: "Conductive edge for fast clears.",      type: .weapon, iconName: "bolt.fill",              priceGems: 700),
        CosmeticItem(id: "weapon.chevron", name: "Oathbreaker Greatsword", subtitle: "Oathbound steel with a chevron-forged edge.", type: .weapon, iconName: "chevron.up.chevron.down", priceGems: 750),
        CosmeticItem(id: "weapon.ruby",    name: "Ruby Fang",              subtitle: "Crimson steel, reinforced point.",      type: .weapon, iconName: "diamond.fill",            priceGems: 700),
        CosmeticItem(id: "weapon.arcane",  name: "Arcane Edge",            subtitle: "Verdigris-forged longsword. Mage pairing.", type: .weapon, iconName: "wand.and.rays",           priceGems: 900),
        CosmeticItem(id: "shield.crux",    name: "Azure Aegis",            subtitle: "Gilded cross guard on a blue field.",   type: .shield, iconName: "shield.fill",             priceGems: 500),
        CosmeticItem(id: "shield.templar", name: "Templar Bulwark",        subtitle: "Oathbound. Scarlet cross on a white field.", type: .shield, iconName: "checkmark.shield.fill", priceGems: 850),
        CosmeticItem(id: "pet.familiar",   name: "Pixel Familiar",     subtitle: "Loyal scout. Flags clutter on approach.", type: .pet,    iconName: "pawprint.fill",           priceGems: 350,  isUnlocked: true),
        CosmeticItem(id: "pet.reel",       name: "Reel Spirit",        subtitle: "Spectral reel. Hovers over video rooms.", type: .pet,    iconName: "video.circle.fill",      priceGems: 550,  isVideoThemed: true),
        CosmeticItem(id: "pet.owl",        name: "Nocturne Owl",       subtitle: "Night watch. Never misses a duplicate.", type: .pet,    iconName: "bird.fill",              priceGems: 450),
        // Forest Spirits: pixel-art sprouts that bob beside the hero.
        CosmeticItem(id: "pet.spiritBlue",   name: "Bluebell Sprout", subtitle: "A calm forest spirit in a river-blue tunic.", type: .pet, iconName: "leaf.fill", priceGems: 400),
        CosmeticItem(id: "pet.spiritGreen",  name: "Mossy Sprout",    subtitle: "A forest spirit who naps on mossy stones.",   type: .pet, iconName: "leaf.fill", priceGems: 400),
        CosmeticItem(id: "pet.spiritRed",    name: "Ember Sprout",    subtitle: "A forest spirit with a warm red tunic.",      type: .pet, iconName: "leaf.fill", priceGems: 400),
        CosmeticItem(id: "pet.spiritYellow", name: "Sunny Sprout",    subtitle: "A forest spirit that follows the light.",     type: .pet, iconName: "leaf.fill", priceGems: 400),
        CosmeticItem(id: "fx.sparks",      name: "Golden Sparks",      subtitle: "Default delete burst.",                type: .effect, iconName: "flame.fill",              priceGems: 0,    isUnlocked: true),
        CosmeticItem(id: "fx.filmstrip",   name: "Film Strip Burst",   subtitle: "Video-themed burst on delete.",        type: .effect, iconName: "film.stack.fill",        priceGems: 450,  isVideoThemed: true),
        CosmeticItem(id: "fx.aurora",      name: "Aurora Trail",       subtitle: "Cool-toned trail on delete.",          type: .effect, iconName: "moon.haze.fill",         priceGems: 700),
        // Seasonal exclusives. Seeded year-round so event screens can reference
        // them; the Armory surfaces them when the matching event is live.
        CosmeticItem(id: "skin.wraithcloak",    name: "Wraithcloak",     subtitle: "Ash-gray weave from the Phantom Purge.", type: .skin,   iconName: "moon.stars.fill",          priceGems: 600),
        CosmeticItem(id: "skin.sandblade",      name: "Sandblade Garb",  subtitle: "Sun-bleached cloth for summer runs.",    type: .skin,   iconName: "sun.max.fill",             priceGems: 550),
        CosmeticItem(id: "weapon.fireworkBlade", name: "Firework Blade", subtitle: "New Year steel with a bursting edge.",   type: .weapon, iconName: "fireworks",                priceGems: 750),
        CosmeticItem(id: "pet.beachSpirit",     name: "Beach Spirit",    subtitle: "A wave-shaped companion that drifts.",   type: .pet,    iconName: "fish.fill",                 priceGems: 500),
        CosmeticItem(id: "pet.ghost",           name: "Sheet Ghost",     subtitle: "A bobbing sheet from the Phantom Purge.", type: .pet,   iconName: "moon.stars.fill",           priceGems: 600),
        CosmeticItem(id: "pet.bat",             name: "Cave Bat",        subtitle: "A flapping scout from the Phantom Purge.", type: .pet,  iconName: "bird.fill",                 priceGems: 500),
        CosmeticItem(id: "fx.spectral",         name: "Spectral Wisps",  subtitle: "Pale wisps rise on every delete.",       type: .effect, iconName: "ghost.fill",               priceGems: 600),
        CosmeticItem(id: "fx.confetti",         name: "Confetti Vault",  subtitle: "New Year burst on every delete.",        type: .effect, iconName: "party.popper.fill",        priceGems: 550),
        CosmeticItem(id: "fx.hearts",           name: "Heartbreak Trail", subtitle: "A Valentine trail follows the blade.",  type: .effect, iconName: "heart.fill",               priceGems: 550),
        // Permanent character upgrades. Ownership lives on the hero record;
        // the Titan Blade additionally requires an earned achievement.
        CosmeticItem(id: "upgrade.titanBlade",  name: "Titan Blade",     subtitle: "Doubles the size of your held weapon.",  type: .upgrade, iconName: "arrow.up.left.and.arrow.down.right", priceGems: 3000),
        ]
        // Race gear: 40 staves, 40 shields, each race's signature weapon, and
        // the eight race armor sets. Seeded alongside the classic cosmetics so
        // everything shares one economy and nothing is ever lost once owned.
        return base + GearCatalog.cosmeticSeeds
    }

    /// Base cosmetic catalog (icon-only classics + seasonal + upgrades).

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

    /// Recomputes every stat-driven achievement from lifetime hero stats and the
    /// deletion log. Called after each confirmed room and at app start, so progress
    /// never depends on a single event firing.
    static func syncAchievements(
        hero: Hero,
        in context: ModelContext,
        videosDeletedThisRoom: Int = 0,
        perfectRoom: Bool = false
    ) {
        let records = (try? context.fetch(FetchDescriptor<DeletedMediaRecord>())) ?? []
        let dragons = records.filter { $0.monsterType.counts(as: .duplicateDragon) }.count
        let longTakes = records.filter { $0.mediaKind == .video && $0.durationSeconds >= 600 }.count
        let fiveYearsAgo = Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date()
        let ancient = records.filter { record in
            record.mediaKind == .photo && (record.creationDate ?? .distantFuture) < fiveYearsAgo
        }.count

        let progress: [String: Int] = [
            "first.blood":       hero.totalPhotosPurged,
            "scene.cut":         hero.totalVideosPurged,
            "duplicate.slayer":  dragons,
            "video.vault":       hero.totalVideosPurged,
            "great.purge":       Int(hero.totalMBFreed.rounded()),
            "long.take.term":    longTakes,
            "combo.king":        hero.highestCombo,
            "ancient.archivist": ancient,
            "streak.warrior":    hero.streakDays,
            "perfect.room":     perfectRoom ? 1 : 0,
            "video.speedrun":    videosDeletedThisRoom >= 20 ? 1 : 0
        ]

        let all = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        var didChange = false
        for ach in all {
            guard let value = progress[ach.id] else { continue }
            // Progress only ever rises; one-off conditions (perfect rooms) stay banked.
            if value > ach.progress { ach.progress = value }
            if !ach.isUnlocked && ach.progress >= ach.goal {
                ach.isUnlocked = true
                ach.unlockedAt = Date()
                didChange = true
            }
        }
        if didChange { try? context.save() }
    }

    // MARK: - Daily Quests

    /// Every quest the daily draw can pick from, as fresh models. The data is QuestCatalog.daily.
    static var dailyQuestPool: [Quest] { QuestCatalog.daily.map(Quest.init(template:)) }

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

        let pool = dailyQuestPool

        // Pick 4 distinct quests
        for quest in pool.shuffled().prefix(4) {
            context.insert(quest)
        }
        try? context.save()
    }

    /// Whether slaying `slain` counts toward the quest's target monster (see `MonsterType.counts(as:)`).
    private static func counts(_ slain: MonsterType, for quest: Quest) -> Bool {
        quest.monsterType.map(slain.counts(as:)) ?? false
    }

    static func updateQuests(_ quests: [Quest], for slainMonster: MonsterType, mbFreedThisAction: Double) {
        for q in quests where !q.completed {
            switch q.kind {
            case .photoSlay:
                if slainMonster.kind == .photo, counts(slainMonster, for: q) {
                    q.currentCount += 1
                }
            case .videoSlay:
                if slainMonster.kind == .video, counts(slainMonster, for: q) {
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
