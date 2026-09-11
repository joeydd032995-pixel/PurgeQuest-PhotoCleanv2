//
//  PurgeQuestTests.swift
//  PurgeQuest
//
//  Focused tests for the hero identity system: designed defaults, safe
//  decoding of legacy/corrupt data, persistence through the hero record,
//  draft save/cancel behavior, and gear tier mapping.
//

import Testing
import SwiftData
import Foundation
@testable import PurgeQuest

@MainActor
struct HeroAppearanceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Hero.self, configurations: configuration)
    }

    @Test func designedDefaultsDifferPerArchetype() {
        let knight = HeroAppearance.default(for: .knight)
        let magician = HeroAppearance.default(for: .magician)
        #expect(knight != magician)
        #expect(knight.schemaVersion == HeroAppearance.currentSchemaVersion)
        #expect(magician.schemaVersion == HeroAppearance.currentSchemaVersion)
    }

    @Test func roundTripEncodingPreservesConfiguration() {
        var look = HeroAppearance.default(for: .knight)
        look.hairStyle = .long
        look.hairColor = .jade
        look.eyeStyle = .keen
        look.eyeColor = .sapphire
        look.browStyle = .fierce
        look.mouthStyle = .grin
        look.expression = .fierce
        look.backdropStyle = .banner

        let decoded = HeroAppearance.decode(look.encoded(), for: .knight)
        #expect(decoded == look)
    }

    @Test func nilDataFallsBackToArchetypeDefault() {
        #expect(HeroAppearance.decode(nil, for: .knight) == .default(for: .knight))
        #expect(HeroAppearance.decode(nil, for: .magician) == .default(for: .magician))
    }

    @Test func emptyDataFallsBackToArchetypeDefault() {
        #expect(HeroAppearance.decode(Data(), for: .knight) == .default(for: .knight))
    }

    @Test func corruptDataFallsBackToArchetypeDefault() {
        let corrupt = Data([0x00, 0x01, 0x02, 0x03, 0xFF])
        #expect(HeroAppearance.decode(corrupt, for: .magician) == .default(for: .magician))
    }

    @Test func legacyPartialDataFallsBackToArchetypeDefault() throws {
        // A record written by an older schema with missing fields cannot
        // satisfy the decoder and must fall back to the designed default.
        let partial = Data("{\"schemaVersion\":1,\"skinTone\":\"sandstone\"}".utf8)
        #expect(HeroAppearance.decode(partial, for: .knight) == .default(for: .knight))
    }

    @Test func futureSchemaFallsBackToArchetypeDefault() throws {
        var look = HeroAppearance.default(for: .knight)
        look.schemaVersion = HeroAppearance.currentSchemaVersion + 5
        #expect(HeroAppearance.decode(look.encoded(), for: .knight) == .default(for: .knight))
    }

    @Test func appearanceSurvivesRelaunchThroughTheModel() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let hero = Hero()
        hero.appearance = .default(for: .magician)
        context.insert(hero)
        try context.save()

        // A fresh context against the same store simulates the next launch.
        let relaunchedContext = ModelContext(container)
        let fetched = try relaunchedContext.fetch(FetchDescriptor<Hero>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.appearance == .default(for: .magician))
    }

    @Test func draftEditingLeavesHeroUntouchedUntilSave() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let hero = Hero()
        hero.appearance = .default(for: .knight)
        context.insert(hero)
        try context.save()

        // The forge edits a draft; the saved look must not move until commit.
        var draft = hero.appearance
        draft.hairColor = .ember
        draft.expression = .happy
        #expect(hero.appearance == .default(for: .knight))

        // Save commits the draft exactly as previewed.
        hero.appearance = draft
        try context.save()
        #expect(hero.appearance == draft)
        #expect(hero.appearanceData != nil)

        // Relaunch keeps the committed configuration.
        let relaunchedContext = ModelContext(container)
        let fetched = try relaunchedContext.fetch(FetchDescriptor<Hero>())
        #expect(fetched.first?.appearance == draft)
    }

    @Test func gearTierMappingFollowsEquippedValue() {
        #expect(HeroAppearance.gearTier(maxEquippedPrice: 0, hasPremium: false) == .standard)
        #expect(HeroAppearance.gearTier(maxEquippedPrice: 249, hasPremium: false) == .standard)
        #expect(HeroAppearance.gearTier(maxEquippedPrice: 250, hasPremium: false) == .seasoned)
        #expect(HeroAppearance.gearTier(maxEquippedPrice: 600, hasPremium: false) == .elite)
        #expect(HeroAppearance.gearTier(maxEquippedPrice: 750, hasPremium: false) == .legendary)
        #expect(HeroAppearance.gearTier(maxEquippedPrice: 900, hasPremium: false) == .mythic)
        #expect(HeroAppearance.gearTier(maxEquippedPrice: 0, hasPremium: true) == .mythic)
    }
}
