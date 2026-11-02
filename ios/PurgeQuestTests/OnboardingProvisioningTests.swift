//
//  OnboardingProvisioningTests.swift
//  PurgeQuest
//
//  The hero, the seeded catalogs and the choices made in onboarding must all be in the
//  store whenever the main tabs open: at launch, after a first-run onboarding, and after
//  "Reset all PurgeQuest data" followed by onboarding (the Hero tab used to say
//  "No hero found." there, because the hero was only ever created at launch).
//

import Testing
import SwiftData
import Foundation
@testable import PurgeQuest

@MainActor
struct OnboardingProvisioningTests {

    // MARK: - Helpers

    /// The app's full schema in memory, so seeding behaves as it does in the real store.
    private func makeContainer() throws -> ModelContainer {
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
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Runs `body` against a fresh in-memory store and a private UserDefaults suite, so tests
    /// never touch real data or each other (Swift Testing runs them in parallel).
    private func withStore(_ body: (ModelContext, UserDefaults) throws -> Void) throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suite = "OnboardingProvisioningTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try withExtendedLifetime(container) { try body(context, defaults) }
    }

    private func all<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    private struct Counts: Equatable {
        var heroes = 0
        var achievements = 0
        var cosmetics = 0
        var quests = 0
    }

    private func counts(in context: ModelContext) throws -> Counts {
        Counts(
            heroes: try all(Hero.self, in: context).count,
            achievements: try all(Achievement.self, in: context).count,
            cosmetics: try all(CosmeticItem.self, in: context).count,
            quests: try all(Quest.self, in: context).count
        )
    }

    /// What OnboardingView saves when the player picks a race and taps "Enter the Dungeon".
    private func saveOnboardingChoices(
        race: HeroRace,
        name: String = "Hero",
        paintVariant: Int = 1,
        to defaults: UserDefaults
    ) throws {
        var look = HeroAppearance.default(for: race)
        look.race = race
        look.paintVariant = paintVariant
        let draft = try JSONEncoder().encode(look)
        defaults.set(race.recommendedClass.rawValue, forKey: "pq.selectedClass")
        defaults.set(race.rawValue, forKey: "pq.race")
        defaults.set(draft, forKey: "pq.appearanceDraft")
        defaults.set(name, forKey: "pq.heroName")
    }

    // MARK: - Tests

    @Test func aFreshStoreGetsAHeroAndEverySeed() throws {
        try withStore { context, defaults in
            let hero = GameDataService.provision(in: context, defaults: defaults)

            let heroes = try all(Hero.self, in: context)
            #expect(heroes.count == 1)
            #expect(heroes.first?.id == hero.id)
            #expect(hero.name == "Hero")
            #expect(hero.race == .valkyrie)

            let found = try counts(in: context)
            #expect(found.achievements > 0)
            #expect(found.cosmetics > 0)
            #expect(found.quests > 0)
        }
    }

    @Test func theChoicesMadeInOnboardingLandOnTheHero() throws {
        try withStore { context, defaults in
            try saveOnboardingChoices(race: .lostSouls, name: "Morrigan", paintVariant: 2, to: defaults)

            let hero = GameDataService.provision(in: context, defaults: defaults)

            #expect(hero.race == .lostSouls)
            #expect(hero.heroClass == .paladinUnholy)
            #expect(hero.name == "Morrigan")
            #expect(hero.appearance.race == .lostSouls)
            #expect(hero.appearance.paintVariant == 2)
            // The drafted look is applied once, so later Forge edits always win.
            #expect(defaults.data(forKey: "pq.appearanceDraft") == nil)
        }
    }

    /// The reported bug: reset, pick Lost Souls, open the Hero tab > "No hero found.".
    @Test func resettingAndThenChoosingARaceStillLeavesAHero() throws {
        try withStore { context, defaults in
            // The app launches on an existing install and the player has earned some gems.
            let original = GameDataService.provision(in: context, defaults: defaults)
            original.gems = 500
            try context.save()
            // Read before the reset: SwiftData traps on a deleted model's properties.
            let originalID = original.id

            // Settings > "Reset all PurgeQuest data": onboarding starts from an empty store.
            GameDataService.resetAllData(in: context, defaults: defaults)
            let afterReset = try all(Hero.self, in: context)
            #expect(afterReset.isEmpty)

            // Onboarding: pick Lost Souls, then "Enter the Dungeon".
            try saveOnboardingChoices(race: .lostSouls, to: defaults)
            let hero = GameDataService.provision(in: context, defaults: defaults)

            let heroes = try all(Hero.self, in: context)
            #expect(heroes.count == 1)
            #expect(heroes.first?.id == hero.id)
            // A new character with none of the old progress, wearing the chosen race.
            #expect(hero.id != originalID)
            #expect(hero.gems == 0)
            #expect(hero.race == .lostSouls)
            #expect(hero.heroClass == .paladinUnholy)

            // The seeds come back too, so Armory, Trophies and the daily quests are not empty.
            let found = try counts(in: context)
            #expect(found.achievements > 0)
            #expect(found.cosmetics > 0)
            #expect(found.quests > 0)
        }
    }

    @Test func provisioningTwiceDoesNotDuplicateOrResetAnything() throws {
        try withStore { context, defaults in
            let first = GameDataService.provision(in: context, defaults: defaults)
            first.gems = 250
            try context.save()
            let before = try counts(in: context)

            let second = GameDataService.provision(in: context, defaults: defaults)

            let after = try counts(in: context)
            #expect(second.id == first.id)
            #expect(second.gems == 250)
            #expect(after == before)
        }
    }

    @Test func savedLegacyValuesStillMigrate() throws {
        try withStore { context, defaults in
            defaults.set("skeleton_warrior", forKey: "pq.race")
            defaults.set("purgeKnight", forKey: "pq.selectedClass")

            let hero = GameDataService.provision(in: context, defaults: defaults)

            #expect(hero.race == .skeletalUndead)
            #expect(hero.heroClass == .paladinHoly)
        }
    }

    /// The Forge can change race. Launch used to re-apply the onboarding race every time, so the
    /// change was undone at the next launch.
    @Test func aRaceChangedAfterOnboardingSurvivesTheNextLaunch() throws {
        try withStore { context, defaults in
            try saveOnboardingChoices(race: .lostSouls, to: defaults)
            let hero = GameDataService.provision(in: context, defaults: defaults)
            #expect(hero.race == .lostSouls)

            // The player picks another race in the Forge and saves.
            hero.race = .golem
            try context.save()

            // The next launch provisions again.
            let relaunched = GameDataService.provision(in: context, defaults: defaults)

            #expect(relaunched.id == hero.id)
            #expect(relaunched.race == .golem)
        }
    }

    @Test func onboardingChoicesAreClearedOnceApplied() throws {
        try withStore { context, defaults in
            try saveOnboardingChoices(race: .lostSouls, name: "Morrigan", to: defaults)
            defaults.set("magician", forKey: "pq.archetype") // written by older versions

            GameDataService.provision(in: context, defaults: defaults)

            for key in ["pq.selectedClass", "pq.race", "pq.appearanceDraft", "pq.archetype", "pq.heroName"] {
                #expect(defaults.object(forKey: key) == nil, "\(key) should be cleared once it is applied")
            }
        }
    }

    @Test func resetForgetsOnboardingAndAnyChoicesStillSaved() throws {
        try withStore { context, defaults in
            GameDataService.provision(in: context, defaults: defaults)
            defaults.set(true, forKey: "pq.hasOnboarded")
            // Choices saved but not applied yet, for example if the app was closed in between.
            try saveOnboardingChoices(race: .lostSouls, name: "Morrigan", to: defaults)

            GameDataService.resetAllData(in: context, defaults: defaults)

            let heroes = try all(Hero.self, in: context)
            #expect(heroes.isEmpty)
            for key in GameDataService.onboardingChoiceKeys + ["pq.hasOnboarded"] {
                #expect(defaults.object(forKey: key) == nil, "\(key) should be cleared by a reset")
            }
        }
    }
}
