//
//  KeepingIsFreeTests.swift
//  PurgeQuestTests
//
//  D1 across a whole room: a player who keeps everything they are shown reaches the end of the room
//  with the hero untouched. Under the old rule thirteen keeps ended the run and the room's marked
//  deletions were released. These drive CombatViewModel (SwiftData, UIKit), so they run in Xcode and
//  CI only; DiveRulesTests holds the arithmetic and runs in the Linux harness too.
//

import Testing
import SwiftData
import Foundation
@testable import PurgeQuest

@MainActor
struct KeepingIsFreeTests {

    /// The app's full schema in memory, as the other store-backed tests build it.
    private func makeStore() throws -> (container: ModelContainer, context: ModelContext) {
        let schema = Schema([
            Hero.self,
            Achievement.self,
            CosmeticItem.self,
            Quest.self,
            DeletedMediaRecord.self,
            CombatSession.self,
            SparedMediaRecord.self,
            MediaFingerprintRecord.self,
            MonsterSightingRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (container, ModelContext(container))
    }

    /// `count` videos that each summon the hardest-hitting monster the old rule had (18 damage), so
    /// these tests fail at the sixth keep if keeping ever starts to hurt again.
    private func heavyHitters(_ count: Int) -> [MediaItem] {
        (0..<count).map { index in
            var item = MediaItem(
                id: "heavy\(index)", kind: .video, creationDate: nil, pixelWidth: 1920, pixelHeight: 1080,
                durationSeconds: 900, estimatedBytes: 50_000_000, isFavorite: false, playbackStyle: 4
            )
            item.monsterType = .longTakeLeviathan
            return item
        }
    }

    // MARK: Keeping

    @Test func keepingEveryItemInARoomNeverHurtsTheHeroOrEndsTheDive() throws {
        let store = try makeStore()
        let hero = Hero()
        store.context.insert(hero)
        let combat = CombatViewModel()
        let room = heavyHitters(CombatViewModel.roomSize)
        combat.currentRoomItems = room
        combat.phase = .fighting

        for item in room {
            combat.decideSpare(item, hero: hero, context: store.context)
        }

        #expect(combat.phase == .roomSummary, "keeping every item should reach the end of the room")
        #expect(combat.heroCurrentHP == combat.heroMaxHP)
        #expect(hero.currentHP == hero.maxHP)
        #expect(combat.screenShakeTrigger == 0, "a keep must not shake the screen")
        withExtendedLifetime(store.container) {}
    }

    @Test func keepingEndsTheStreakAndTakesAPieceOfTheMultiplier() throws {
        let store = try makeStore()
        let hero = Hero()
        store.context.insert(hero)
        let combat = CombatViewModel()
        let items = heavyHitters(3)
        combat.currentRoomItems = items
        combat.phase = .fighting

        combat.decideDelete(items[0], hero: hero)
        combat.decideDelete(items[1], hero: hero)
        #expect(combat.combo == 2)
        #expect(combat.comboMultiplier.tenths == 12, "each deletion adds a tenth")

        combat.decideSpare(items[2], hero: hero, context: store.context)

        #expect(combat.combo == 0, "a keep ends the streak")
        #expect(combat.comboMultiplier.tenths == 11, "and takes 12% of the multiplier, to the nearest tenth, instead of ending it")
        #expect(combat.heroCurrentHP == combat.heroMaxHP, "and costs no HP")
        withExtendedLifetime(store.container) {}
    }

    // MARK: The combo

    @Test func theComboRisesATenthPerDeletionAndStopsAtDouble() throws {
        let store = try makeStore()
        let hero = Hero()
        store.context.insert(hero)
        let combat = CombatViewModel()
        let item = heavyHitters(1)[0]

        // comboStep 0 is the first deletion of a streak (×1.1), so comboStep 9 is the tenth (×2.0).
        func reward(deletion number: Int) -> (xp: Int, gems: Int) {
            combat.previewReward(for: item, comboStep: number - 1, hero: hero)
        }

        #expect(reward(deletion: 1).xp < reward(deletion: 5).xp, "a longer streak pays more")
        #expect(reward(deletion: 5).xp < reward(deletion: 10).xp)
        #expect(reward(deletion: 10).xp == reward(deletion: 11).xp, "×2.0 is the top; it used to reach ×3")
        #expect(reward(deletion: 10).xp == reward(deletion: 41).xp)
        #expect(reward(deletion: 10).gems == reward(deletion: 41).gems)
        withExtendedLifetime(store.container) {}
    }

    @Test func deletionsBuildTheMultiplierAndAKeepTakesOnlyAPieceOfIt() throws {
        let store = try makeStore()
        let hero = Hero()
        store.context.insert(hero)
        let combat = CombatViewModel()
        let items = heavyHitters(12)
        combat.currentRoomItems = items
        combat.phase = .fighting

        for item in items.prefix(10) { combat.decideDelete(item, hero: hero) }
        #expect(combat.comboMultiplier.tenths == 20, "ten deletions reach ×2.0")

        combat.decideSpare(items[10], hero: hero, context: store.context)
        #expect(combat.comboMultiplier.tenths == 18, "a keep takes 12%, not everything")
        #expect(combat.combo == 0, "the streak itself still ends")

        combat.decideDelete(items[11], hero: hero)
        #expect(combat.comboMultiplier.tenths == 19, "and the next deletion builds on what is left")
        withExtendedLifetime(store.container) {}
    }
}
