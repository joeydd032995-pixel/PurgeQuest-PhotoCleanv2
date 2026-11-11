//
//  DateScopeIntegrationTests.swift
//  PurgeQuestTests
//
//  The parts of the date range that need Apple's frameworks, so they run under Xcode only (they are not
//  in the Linux harness): the fetch predicate draws the same line as the rule (swift-corelibs-foundation
//  has no NSPredicate format strings), AppState keeps the range across a relaunch, and "Reset all
//  PurgeQuest data" forgets it. The rule itself is covered by DateScopeTests.
//

import Testing
import SwiftData
import Foundation
@testable import PurgeQuest

@MainActor
struct DateScopeIntegrationTests {

    // MARK: - Helpers

    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
        CalendarDay(year: year, month: month, day: day)
    }

    /// A private UserDefaults suite, so tests never touch real data or each other (they run in parallel).
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "DateScopeIntegrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    /// The app's full schema in memory, as OnboardingProvisioningTests builds it.
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

    // MARK: - The predicate

    /// The predicate PhotoKit filters with and the rule the fetch re-checks must draw the same line.
    /// A photo with no date is left out of the comparison: a database leaves a missing value out of
    /// every comparison, and the rule keeps an undated photo out whenever a range is active.
    @Test func thePredicateAgreesWithTheRuleOnEveryBoundary() throws {
        let from = day(2018, 3, 1)
        let to = day(2018, 3, 31)
        let scopes = [
            DateScope(mode: .only, from: from, to: to),
            DateScope(mode: .only, from: from, to: nil),
            DateScope(mode: .only, from: nil, to: to),
            DateScope(mode: .exclude, from: from, to: to),
            DateScope(mode: .exclude, from: from, to: nil),
            DateScope(mode: .exclude, from: nil, to: to)
        ]
        let samples = [
            at(2018, 2, 28, 23, 59, 59), at(2018, 3, 1, 0, 0, 0), at(2018, 3, 1, 0, 0, 1), at(2018, 3, 15),
            at(2018, 3, 31, 23, 59, 59), at(2018, 4, 1, 0, 0, 0), at(1990, 1, 1), at(2035, 1, 1)
        ]
        for scope in scopes {
            let parts = try #require(scope.predicateParts(calendar: utc))
            let predicate = NSPredicate(format: parts.format, argumentArray: parts.arguments)
            for sample in samples {
                let viaPredicate = predicate.evaluate(with: ["creationDate": sample])
                #expect(viaPredicate == scope.admits(sample, calendar: utc),
                        "\(scope.summary(calendar: utc)) at \(sample)")
            }
        }
    }

    // MARK: - AppState

    @Test func appStateStartsWithTheSavedRange() throws {
        try withDefaults { defaults in
            let saved = DateScope(mode: .exclude, from: day(2025, 10, 12), to: nil)
            DateScopeStore.save(saved, to: defaults)
            #expect(AppState(defaults: defaults).dateScope == saved)
        }
    }

    @Test func appStateStartsOnAllDatesWhenNothingWasSaved() throws {
        try withDefaults { defaults in
            #expect(AppState(defaults: defaults).dateScope == DateScope.all)
        }
    }

    @Test func settingTheRangeSavesItForTheNextLaunch() throws {
        try withDefaults { defaults in
            let scope = DateScope(mode: .only, from: day(2018, 1, 1), to: day(2018, 12, 31))
            let state = AppState(defaults: defaults)
            state.setDateScope(scope)
            #expect(state.dateScope == scope)
            #expect(AppState(defaults: defaults).dateScope == scope)
        }
    }

    @Test func clearingTheRangeForgetsItForTheNextLaunch() throws {
        try withDefaults { defaults in
            let state = AppState(defaults: defaults)
            state.setDateScope(DateScope(mode: .exclude, from: day(2025, 10, 12), to: nil))
            state.setDateScope(.all)
            #expect(state.dateScope == DateScope.all)
            #expect(defaults.object(forKey: DateScopeStore.key) == nil)
            #expect(AppState(defaults: defaults).dateScope == DateScope.all)
        }
    }

    // MARK: - Reset

    /// Settings > "Reset all PurgeQuest data" wipes the spared and purged memory, so the clean slate
    /// includes the range.
    @Test func resettingAllDataForgetsTheSavedRange() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        try withDefaults { defaults in
            DateScopeStore.save(DateScope(mode: .exclude, from: day(2025, 10, 12), to: nil), to: defaults)
            try withExtendedLifetime(container) {
                GameDataService.resetAllData(in: context, defaults: defaults)
            }
            #expect(defaults.object(forKey: DateScopeStore.key) == nil)
            #expect(DateScopeStore.load(from: defaults) == DateScope.all)
        }
    }
}
