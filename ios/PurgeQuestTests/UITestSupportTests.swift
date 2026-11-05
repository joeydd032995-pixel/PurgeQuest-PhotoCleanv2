//
//  UITestSupportTests.swift
//  PurgeQuestTests
//
//  The screenshot tour's launch hooks: argument parsing, and the promise that
//  outside a tour they change nothing about the player's items or Bestiary.
//

import Testing
import SwiftData
@testable import PurgeQuest

struct UITestSupportTests {

    @Test func idsAreSplitTrimmedAndBlanksDropped() {
        #expect(UITestSupport.ids(from: "pet.spiritBlue") == ["pet.spiritBlue"])
        #expect(UITestSupport.ids(from: " a , b,,c ,") == ["a", "b", "c"])
        #expect(UITestSupport.ids(from: "") == [])
        #expect(UITestSupport.ids(from: nil) == [])
    }

    @Test @MainActor func loadoutDoesNothingOutsideATour() throws {
        // The unit-test host is not launched with -UITestTour.
        #expect(!UITestSupport.isTour)
        #expect(UITestSupport.forcedEventID == nil)

        let container = try ModelContainer(
            for: CosmeticItem.self, MonsterSightingRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        GameDataService.seedCosmeticsIfNeeded(in: context)
        let before = try context.fetch(FetchDescriptor<CosmeticItem>()).filter { $0.isEquipped }.map(\.id).sorted()

        UITestSupport.applyTourLoadout(in: context)

        let after = try context.fetch(FetchDescriptor<CosmeticItem>()).filter { $0.isEquipped }.map(\.id).sorted()
        #expect(after == before)
        #expect(try context.fetch(FetchDescriptor<MonsterSightingRecord>()).isEmpty)
    }
}
