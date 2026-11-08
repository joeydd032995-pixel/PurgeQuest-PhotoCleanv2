//
//  MonsterTypeCountingTests.swift
//  PurgeQuestTests
//
//  Quests and achievements written for the Duplicate Dragon count the whole Duplicate Dragons family.
//

import Testing
import Foundation
import SwiftData
@testable import PurgeQuest

@MainActor
struct MonsterTypeCountingTests {

    private let family: [MonsterType] = [
        .perfectPairWyrmling, .duplicateDragon, .burstHydra, .cloneChimera,
        .screenshotTwin, .downloadDrake, .albumEcho, .hoardHydra
    ]

    @Test func theDuplicateDragonTargetCountsTheWholeFamilyAndNothingElse() {
        #expect(Set(family) == Set(MonsterType.allCases.filter { $0.family == .duplicateDragons }))
        for type in MonsterType.allCases {
            #expect(type.counts(as: .duplicateDragon) == family.contains(type), "\(type)")
        }
    }

    @Test func everyOtherTargetMeansExactlyThatMonster() {
        #expect(MonsterType.blurBeast.counts(as: .blurBeast))
        #expect(!MonsterType.darkWraith.counts(as: .blurBeast))
        #expect(!MonsterType.burstHydra.counts(as: .hoardHydra))
        #expect(MonsterType.hoardHydra.counts(as: .hoardHydra))
    }

    @Test func aDuplicateDragonQuestProgressesOnAnyCopy() {
        let quest = Quest(title: "Duplicate Dragon Slayer", subtitle: "", kind: .photoSlay,
                          monsterType: .duplicateDragon, targetCount: 3, rewardXP: 1, rewardGems: 1)
        GameDataService.updateQuests([quest], for: .burstHydra, mbFreedThisAction: 1)
        GameDataService.updateQuests([quest], for: .hoardHydra, mbFreedThisAction: 1)
        GameDataService.updateQuests([quest], for: .blurBeast, mbFreedThisAction: 1)
        #expect(quest.currentCount == 2)
        #expect(!quest.completed)
        GameDataService.updateQuests([quest], for: .duplicateDragon, mbFreedThisAction: 1)
        #expect(quest.completed)
    }

    @Test func aBlurBeastQuestIgnoresDuplicates() {
        let quest = Quest(title: "Blur Beast Hunter", subtitle: "", kind: .photoSlay,
                          monsterType: .blurBeast, targetCount: 2, rewardXP: 1, rewardGems: 1)
        GameDataService.updateQuests([quest], for: .burstHydra, mbFreedThisAction: 1)
        #expect(quest.currentCount == 0)
        GameDataService.updateQuests([quest], for: .blurBeast, mbFreedThisAction: 1)
        #expect(quest.currentCount == 1)
    }

    @Test func theDuplicateSlayerAchievementCountsEveryCopy() throws {
        let schema = Schema([
            Hero.self, Achievement.self, CosmeticItem.self, Quest.self, DeletedMediaRecord.self,
            CombatSession.self, SparedMediaRecord.self, MediaFingerprintRecord.self, MonsterSightingRecord.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        context.insert(Achievement(id: "duplicate.slayer", title: "Duplicate Slayer", subtitle: "", iconName: "square.on.square", goal: 50))
        for type in [MonsterType.burstHydra, .burstHydra, .hoardHydra, .duplicateDragon, .blurBeast] {
            context.insert(DeletedMediaRecord(assetIdentifier: UUID().uuidString, mediaKind: .photo, monsterType: type, fileSizeBytes: 1))
        }
        let hero = Hero()
        context.insert(hero)
        try context.save()

        GameDataService.syncAchievements(hero: hero, in: context)

        let achievement = try #require(try context.fetch(FetchDescriptor<Achievement>()).first { $0.id == "duplicate.slayer" })
        #expect(achievement.progress == 4)
    }
}
