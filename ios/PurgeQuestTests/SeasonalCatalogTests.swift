//
//  SeasonalCatalogTests.swift
//  PurgeQuestTests
//
//  Seasonal exclusives exist, belong to one event each, and are sold only while that event runs.
//

import Testing
import SwiftData
@testable import PurgeQuest

@MainActor
struct SeasonalCatalogTests {

    @Test func everyExclusiveBelongsToExactlyOneEvent() {
        var owner: [String: String] = [:]
        for event in SeasonalEventService.allEvents {
            for id in event.exclusiveCosmeticIDs {
                #expect(owner[id] == nil, "\(id) is claimed by \(owner[id] ?? "") and \(event.id)")
                owner[id] = event.id
            }
        }
        #expect(!owner.isEmpty)
    }

    @Test func everyExclusiveIsInTheSeededCatalog() throws {
        let container = try ModelContainer(for: CosmeticItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        GameDataService.seedCosmeticsIfNeeded(in: context)
        let seeded = Set(try context.fetch(FetchDescriptor<CosmeticItem>()).map(\.id))
        for event in SeasonalEventService.allEvents {
            for id in event.exclusiveCosmeticIDs {
                #expect(seeded.contains(id), "\(event.name) offers \(id), which is not in the catalog")
            }
        }
    }

    @Test func eventsOwnTheirItems() {
        #expect(SeasonalCatalog.event(owning: "pet.ghost")?.id == "halloween")
        #expect(SeasonalCatalog.event(owning: "fx.confetti")?.id == "newyear")
        #expect(SeasonalCatalog.event(owning: "weapon.shard") == nil)
    }

    @Test func exclusivesAreBuyableOnlyWhileTheirEventRuns() {
        #expect(SeasonalCatalog.isPurchasable("fx.spectral", activeEventID: "halloween"))
        #expect(!SeasonalCatalog.isPurchasable("fx.spectral", activeEventID: nil))
        #expect(!SeasonalCatalog.isPurchasable("fx.spectral", activeEventID: "newyear"))
    }

    @Test func everythingElseIsAlwaysBuyable() {
        #expect(SeasonalCatalog.isPurchasable("weapon.shard", activeEventID: nil))
        #expect(SeasonalCatalog.isPurchasable("pet.owl", activeEventID: "halloween"))
    }

    /// The Linux harness audits SeasonalBonusCatalog.byEventID, so every event must be in it, with
    /// the bonus the event really pays. An event added without an entry would escape that audit.
    @Test func everyEventsBonusIsTheOneTheHarnessAudits() {
        let events = SeasonalEventService.allEvents
        #expect(Set(events.map(\.id)) == Set(SeasonalBonusCatalog.byEventID.keys))
        for event in events {
            #expect(SeasonalBonusCatalog.byEventID[event.id] == event.bonus, "\(event.name)")
        }
    }

    @Test func theDailyPoolIsBuiltFromTheCatalogTheHarnessAudits() {
        let pool = GameDataService.dailyQuestPool
        #expect(pool.count == QuestCatalog.daily.count)
        for (quest, template) in zip(pool, QuestCatalog.daily) {
            #expect(quest.title == template.title)
            #expect(quest.kind == template.kind)
            #expect(quest.monsterType == template.monsterType)
            #expect(quest.targetCount == template.targetCount)
            #expect(quest.rewardXP == template.rewardXP)
            #expect(quest.rewardGems == template.rewardGems)
            #expect(quest.currentCount == 0 && !quest.completed)
        }
    }
}
