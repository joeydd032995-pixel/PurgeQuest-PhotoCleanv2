//
//  EconomyTests.swift
//  PurgeQuestTests
//
//  The economy the owner set on 17 November 2026: every shop price is 2.25x to 2.75x what it was, and deleting
//  a photo pays 2 gems and a video 3. These drive SwiftData and CombatViewModel, so they run in Xcode and CI
//  only; ShopPricingTests and DiveRulesTests hold the arithmetic and run in the Linux harness too.
//

import Testing
import SwiftData
import Foundation
@testable import PurgeQuest

@MainActor
struct EconomyTests {

    private func makeStore() throws -> (container: ModelContainer, context: ModelContext) {
        let schema = Schema([
            Hero.self, Achievement.self, CosmeticItem.self, Quest.self, DeletedMediaRecord.self,
            CombatSession.self, SparedMediaRecord.self, MediaFingerprintRecord.self, MonsterSightingRecord.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (container, ModelContext(container))
    }

    // MARK: Prices

    /// The staves and shields were priced by formula, 200 + set * 80 + (tier - 1) * 60 for a staff and
    /// 150 + set * 70 + (tier - 1) * 50 for a shield. Each is now between 2.25x and 2.75x that.
    @Test func everyStaffAndShieldCostsBetweenTwoAndAQuarterAndTwoAndThreeQuartersTimesItsOldPrice() {
        func inBand(_ price: Int, old: Int) -> Bool { price * 100 >= old * 225 && price * 100 <= old * 275 }
        for design in GearCatalog.staves {
            let parts = design.id.split(separator: ".").compactMap { Int($0) }   // weapon.staff.<set>.<tier>
            let old = 200 + (parts[0] - 1) * 80 + (parts[1] - 1) * 60
            #expect(inBand(design.priceGems, old: old), "\(design.id): \(old) → \(design.priceGems)")
        }
        for design in GearCatalog.shields {
            let parts = design.id.split(separator: ".").compactMap { Int($0) }   // shield.set.<set>.<tier>
            let old = 150 + (parts[0] - 1) * 70 + (parts[1] - 1) * 50
            #expect(inBand(design.priceGems, old: old), "\(design.id): \(old) → \(design.priceGems)")
        }
    }

    @Test func signatureWeaponsAndArmorFollowTheSameRule() {
        #expect(GearCatalog.signatureWeapons.allSatisfy { $0.priceGems == 1000 }, "400 → 1000")
        let expected = ["helm": 630, "chest": 880, "legs": 700, "hands": 550]   // 250, 350, 280, 220
        for design in GearCatalog.armorSets {
            let suffix = String(design.id.split(separator: ".").last ?? "")
            #expect(design.priceGems == expected[suffix], design.id)
        }
    }

    @Test func existingInstallsGetTheNewPricesAndKeepWhatTheyOwn() throws {
        let store = try makeStore()
        // A player who installed before the change: the Shadow Hood at its old price, already bought.
        store.context.insert(CosmeticItem(id: "head.hood", name: "Shadow Hood", subtitle: "x", type: .head,
                                          iconName: "theatermasks.fill", priceGems: 500, isUnlocked: true))
        try store.context.save()

        GameDataService.seedCosmeticsIfNeeded(in: store.context)

        let items = try store.context.fetch(FetchDescriptor<CosmeticItem>())
        let hood = try #require(items.first { $0.id == "head.hood" })
        #expect(hood.priceGems == 1250, "the new price reaches an existing install")
        #expect(hood.isUnlocked, "what the player owns stays owned")
        #expect(items.filter { $0.id == "head.hood" }.count == 1)
        withExtendedLifetime(store.container) {}
    }

    @Test func seedingTwiceDoesNotScaleThePricesAgain() throws {
        let store = try makeStore()
        GameDataService.seedCosmeticsIfNeeded(in: store.context)
        GameDataService.seedCosmeticsIfNeeded(in: store.context)
        let titan = try #require(try store.context.fetch(FetchDescriptor<CosmeticItem>()).first { $0.id == "upgrade.titanBlade" })
        #expect(titan.priceGems == 7500)
        withExtendedLifetime(store.container) {}
    }

    // MARK: Gems

    @Test func aPhotoPaysTwoGemsAndAVideoThreeWhateverItsSizeOrTheCombo() throws {
        let store = try makeStore()
        let hero = Hero()
        store.context.insert(hero)
        let combat = CombatViewModel()

        var photo = MediaItem(id: "p", kind: .photo, creationDate: nil, pixelWidth: 4000, pixelHeight: 3000,
                              durationSeconds: 0, estimatedBytes: 80_000_000, isFavorite: false, playbackStyle: 1)
        photo.monsterType = .blurBeast
        var tiny = MediaItem(id: "t", kind: .photo, creationDate: nil, pixelWidth: 100, pixelHeight: 100,
                             durationSeconds: 0, estimatedBytes: 20_000, isFavorite: false, playbackStyle: 1)
        tiny.monsterType = .blurBeast
        var video = MediaItem(id: "v", kind: .video, creationDate: nil, pixelWidth: 1920, pixelHeight: 1080,
                              durationSeconds: 900, estimatedBytes: 900_000_000, isFavorite: false, playbackStyle: 4)
        video.monsterType = .longTakeLeviathan

        for step in [0, 4, 9, 30] {
            #expect(combat.previewReward(for: photo, comboStep: step, hero: hero).gems == 2, "a big photo, step \(step)")
            #expect(combat.previewReward(for: tiny, comboStep: step, hero: hero).gems == 2, "a tiny photo, step \(step)")
            #expect(combat.previewReward(for: video, comboStep: step, hero: hero).gems == 3, "a long video, step \(step)")
        }
        withExtendedLifetime(store.container) {}
    }
}
