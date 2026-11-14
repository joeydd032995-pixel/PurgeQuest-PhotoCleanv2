//
//  AchievementCopyTests.swift
//  PurgeQuestTests
//
//  What the trophies say. A fix to a trophy's wording has to reach a store that was seeded before the
//  fix, without touching what the player earned, and no trophy may promise a rule the game dropped
//  (keeping a photo no longer deals damage, D1). Needs SwiftData, so it runs in Xcode and CI only.
//

import Testing
import SwiftData
import Foundation
@testable import PurgeQuest

@MainActor
struct AchievementCopyTests {

    /// The trophies in an in-memory store, so seeding behaves as it does in the real one.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Achievement.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: Seeding

    @Test func aFirstLaunchSeedsEveryTrophyExactlyOnce() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        GameDataService.seedAchievementsIfNeeded(in: context)
        GameDataService.seedAchievementsIfNeeded(in: context)
        let stored = try context.fetch(FetchDescriptor<Achievement>())
        #expect(stored.count == GameDataService.achievementSeeds().count)
        #expect(Set(stored.map(\.id)).count == stored.count)
    }

    // MARK: Wording reaches an older store

    @Test func aStoreSeededBeforeAWordingFixIsBroughtUpToDateWithoutLosingProgress() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // A trophy as an earlier build saved it: the old wording, and progress the player earned.
        let old = Achievement(id: "perfect.room", title: "Perfect Room",
                              subtitle: "Clear a room without taking damage.",
                              iconName: "checkmark.seal.fill", goal: 1)
        old.progress = 1
        old.isUnlocked = true
        context.insert(old)
        try context.save()

        GameDataService.seedAchievementsIfNeeded(in: context)

        let stored = try context.fetch(FetchDescriptor<Achievement>())
        let perfect = try #require(stored.first(where: { $0.id == "perfect.room" }))
        #expect(perfect.subtitle == "Clear a room without keeping a single item.")
        #expect(perfect.isUnlocked, "refreshing the wording must not take back an unlock")
        #expect(perfect.progress == 1)
        // Only wording is refreshed: a store that already has trophies is not topped up with the rest.
        #expect(stored.count == 1)
    }

    // MARK: Honest copy

    @Test func noTrophyPromisesDamageThatKeepingNoLongerDeals() {
        for seed in GameDataService.achievementSeeds() {
            let words = "\(seed.title) \(seed.subtitle)".lowercased()
            #expect(!words.contains("damage"), "\(seed.id) still talks about damage")
        }
    }

    @Test func everyTrophyHasAUniqueIdAndSomethingToSay() {
        let seeds = GameDataService.achievementSeeds()
        #expect(Set(seeds.map(\.id)).count == seeds.count, "two trophies share an id")
        for seed in seeds {
            #expect(!seed.title.isEmpty, "\(seed.id) has no title")
            #expect(!seed.subtitle.isEmpty, "\(seed.id) has no subtitle")
            #expect(seed.goal > 0, "\(seed.id) can never be earned")
        }
    }
}
