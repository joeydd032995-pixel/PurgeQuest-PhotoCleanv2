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

    /// A tour starts with a date range through `-UITestDateScope '<json>'`. The value is read from the
    /// process arguments themselves: read through UserDefaults, a `-key value` argument is taken for a
    /// property list, JSON is not one, and the range never arrived.
    @Test @MainActor func aTourDateRangeIsReadFromTheLaunchArguments() {
        let json = #"{"mode":"exclude","from":{"year":2025,"month":10,"day":12}}"#
        let scope = UITestSupport.dateScope(in: ["-UITestTour", "-UITestDateScope", json, "-pq.appearance", "dark"])
        #expect(scope == DateScope(mode: .exclude, from: CalendarDay(year: 2025, month: 10, day: 12), to: nil))
    }

    @Test @MainActor func noTourDateRangeMeansNoneIsForced() {
        #expect(UITestSupport.dateScope(in: ["-UITestTour"]) == nil)
        #expect(UITestSupport.dateScope(in: ["-UITestTour", "-UITestDateScope"]) == nil)   // a flag with no value
        #expect(UITestSupport.dateScope(in: ["-UITestDateScope", "not json"]) == nil)
        // The unit-test host is not a tour launch, so nothing is forced on the player.
        #expect(UITestSupport.forcedDateScope == nil)
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
