//
//  DateScopeTests.swift
//  PurgeQuestTests
//
//  Which capture dates a dive may draw from: all dates, only a range, or everything but a range. A
//  range is a first and a last calendar day, and either end may be open. Pure Foundation, so these
//  also run on the Linux harness (tools/swift_harness/run.sh): nothing here may touch UIKit,
//  SwiftData or Photos.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct DateScopeTests {

    // MARK: - Helpers

    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let english = Locale(identifier: "en_US")

    private func calendar(in zone: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        return calendar
    }

    /// An instant on a calendar day, noon UTC unless said otherwise.
    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0,
                    in calendar: Calendar? = nil) -> Date {
        let cal = calendar ?? utc
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
        CalendarDay(year: year, month: month, day: day)
    }

    private func only(_ from: CalendarDay?, _ to: CalendarDay?) -> DateScope {
        DateScope(mode: .only, from: from, to: to)
    }

    private func exclude(_ from: CalendarDay?, _ to: CalendarDay?) -> DateScope {
        DateScope(mode: .exclude, from: from, to: to)
    }

    /// A private UserDefaults suite, so tests never touch real data or each other.
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "DateScopeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    // MARK: - The rule

    @Test func allDatesAdmitsEverythingEvenAPhotoWithNoDate() {
        let scope = DateScope.all
        #expect(!scope.isActive)
        #expect(scope.admits(at(2018, 3, 1), calendar: utc))
        #expect(scope.admits(Date.distantPast, calendar: utc))
        #expect(scope.admits(nil, calendar: utc))
        #expect(scope.predicateParts(calendar: utc) == nil)
        #expect(scope.summary(calendar: utc, locale: english) == "All dates")
    }

    @Test func onlyAdmitsWholeDaysFromTheFirstSecondToTheLast() {
        let scope = only(day(2018, 3, 1), day(2018, 3, 31))
        #expect(scope.isActive)
        #expect(scope.admits(at(2018, 3, 1, 0, 0, 0), calendar: utc))
        #expect(scope.admits(at(2018, 3, 31, 23, 59, 59), calendar: utc))
        #expect(scope.admits(at(2018, 3, 31, 23, 59, 59).addingTimeInterval(0.9), calendar: utc))
        #expect(!scope.admits(at(2018, 2, 28, 23, 59, 59), calendar: utc))
        #expect(!scope.admits(at(2018, 4, 1, 0, 0, 0), calendar: utc))
    }

    @Test func excludeAdmitsExactlyWhatOnlyRefuses() {
        let samples = [
            at(2018, 2, 28, 23, 59, 59), at(2018, 3, 1, 0, 0, 0), at(2018, 3, 15),
            at(2018, 3, 31, 23, 59, 59), at(2018, 4, 1, 0, 0, 0), at(1999, 1, 1), at(2031, 6, 6)
        ]
        let inside = only(day(2018, 3, 1), day(2018, 3, 31))
        let outside = exclude(day(2018, 3, 1), day(2018, 3, 31))
        for sample in samples {
            #expect(inside.admits(sample, calendar: utc) != outside.admits(sample, calendar: utc))
        }
        #expect(!outside.admits(at(2018, 3, 1, 0, 0, 0), calendar: utc))
        #expect(!outside.admits(at(2018, 3, 31, 23, 59, 59), calendar: utc))
        #expect(outside.admits(at(2018, 2, 28, 23, 59, 59), calendar: utc))
        #expect(outside.admits(at(2018, 4, 1, 0, 0, 0), calendar: utc))
    }

    @Test func anOpenEndRunsOnForever() {
        let from = only(day(2025, 10, 12), nil)
        #expect(!from.admits(at(2025, 10, 11, 23, 59, 59), calendar: utc))
        #expect(from.admits(at(2025, 10, 12, 0, 0, 0), calendar: utc))
        #expect(from.admits(at(2040, 1, 1), calendar: utc))

        let through = only(nil, day(2020, 3, 3))
        #expect(through.admits(at(1970, 1, 1), calendar: utc))
        #expect(through.admits(at(2020, 3, 3, 23, 59, 59), calendar: utc))
        #expect(!through.admits(at(2020, 3, 4, 0, 0, 0), calendar: utc))
    }

    @Test func excludingFromADateKeepsProtectingPhotosTakenLater() {
        let scope = exclude(day(2025, 10, 12), nil)
        #expect(scope.admits(at(2025, 10, 11, 23, 59, 59), calendar: utc))
        #expect(!scope.admits(at(2025, 10, 12, 0, 0, 0), calendar: utc))
        #expect(!scope.admits(at(2031, 5, 5), calendar: utc))   // a photo that has not been taken yet
    }

    @Test func excludingThroughADateReleasesEverythingAfterIt() {
        let scope = exclude(nil, day(2020, 3, 3))
        #expect(!scope.admits(at(1999, 1, 1), calendar: utc))
        #expect(!scope.admits(at(2020, 3, 3, 23, 59, 59), calendar: utc))
        #expect(scope.admits(at(2020, 3, 4, 0, 0, 0), calendar: utc))
    }

    @Test func aSingleDayIsAWholeDay() {
        let scope = only(day(2020, 3, 3), day(2020, 3, 3))
        #expect(scope.admits(at(2020, 3, 3, 0, 0, 0), calendar: utc))
        #expect(scope.admits(at(2020, 3, 3, 23, 59, 59), calendar: utc))
        #expect(!scope.admits(at(2020, 3, 2, 23, 59, 59), calendar: utc))
        #expect(!scope.admits(at(2020, 3, 4, 0, 0, 0), calendar: utc))
    }

    @Test func aPhotoWithNoDateSitsOutWheneverARangeIsActive() {
        #expect(!only(day(2018, 1, 1), day(2018, 12, 31)).admits(nil, calendar: utc))
        #expect(!exclude(day(2018, 1, 1), day(2018, 12, 31)).admits(nil, calendar: utc))
        #expect(!exclude(day(2018, 1, 1), nil).admits(nil, calendar: utc))
        #expect(DateScope.all.admits(nil, calendar: utc))
    }

    // MARK: - One canonical form

    @Test func reversedEndsAreSwapped() {
        let scope = only(day(2018, 12, 31), day(2018, 1, 1))
        #expect(scope.from == day(2018, 1, 1))
        #expect(scope.to == day(2018, 12, 31))
        #expect(scope.admits(at(2018, 6, 6), calendar: utc))
    }

    @Test func aModeWithNoDayAtAllMeansAllDates() {
        #expect(only(nil, nil) == DateScope.all)
        #expect(exclude(nil, nil) == DateScope.all)
        #expect(!exclude(nil, nil).isActive)
    }

    @Test func allDatesForgetsAnyDaysItWasGiven() {
        #expect(DateScope(mode: .all, from: day(2018, 1, 1), to: day(2018, 2, 2)) == DateScope.all)
    }

    // MARK: - Days, not instants

    @Test func aCalendarDayIsTheLocalDayAnInstantFallsOn() throws {
        let tokyo = try calendar(in: "Asia/Tokyo")
        let newYork = try calendar(in: "America/New_York")
        let instant = at(2027, 1, 15, 20, 0, 0)   // 20:00 UTC
        #expect(CalendarDay(instant, calendar: utc) == day(2027, 1, 15))
        #expect(CalendarDay(instant, calendar: tokyo) == day(2027, 1, 16))   // already tomorrow there
        #expect(CalendarDay(instant, calendar: newYork) == day(2027, 1, 15))
    }

    /// A device set to the Buddhist (or Japanese, or Islamic) calendar counts years differently. A saved
    /// day is always Gregorian, so it keeps its meaning if that setting changes.
    @Test func aCalendarDayIsGregorianWhateverCalendarTheDeviceUses() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(CalendarDay(at(2027, 1, 15), calendar: buddhist) == day(2027, 1, 15))
        #expect(day(2027, 1, 15).start(in: buddhist) == at(2027, 1, 15, 0, 0, 0))
    }

    @Test func calendarDaysOrderByYearThenMonthThenDay() {
        #expect(day(2018, 1, 1) < day(2018, 1, 2))
        #expect(day(2018, 1, 31) < day(2018, 2, 1))
        #expect(day(2018, 12, 31) < day(2019, 1, 1))
        #expect(!(day(2018, 5, 5) < day(2018, 5, 5)))
    }

    @Test func theSameDaysMeanLocalDaysInAnyTimeZone() throws {
        let tokyo = try calendar(in: "Asia/Tokyo")
        let newYork = try calendar(in: "America/New_York")
        let scope = only(day(2025, 10, 12), day(2025, 10, 12))
        #expect(scope.lowerBound(in: tokyo) == at(2025, 10, 12, 0, 0, 0, in: tokyo))
        #expect(scope.lowerBound(in: newYork) == at(2025, 10, 12, 0, 0, 0, in: newYork))
        #expect(scope.lowerBound(in: tokyo) != scope.lowerBound(in: newYork))
    }

    @Test func aDayStaysWholeAcrossTheClockChanges() throws {
        let newYork = try calendar(in: "America/New_York")
        let springForward = only(day(2026, 3, 8), day(2026, 3, 8))   // 23 hours long
        let fallBack = only(day(2026, 11, 1), day(2026, 11, 1))      // 25 hours long

        let springStart = try #require(springForward.lowerBound(in: newYork))
        let springEnd = try #require(springForward.upperBound(in: newYork))
        #expect(springEnd.timeIntervalSince(springStart) == 23 * 3600)
        #expect(springForward.admits(at(2026, 3, 8, 23, 30, 0, in: newYork), calendar: newYork))
        #expect(!springForward.admits(at(2026, 3, 7, 23, 59, 59, in: newYork), calendar: newYork))
        #expect(!springForward.admits(at(2026, 3, 9, 0, 0, 0, in: newYork), calendar: newYork))

        let fallStart = try #require(fallBack.lowerBound(in: newYork))
        let fallEnd = try #require(fallBack.upperBound(in: newYork))
        #expect(fallEnd.timeIntervalSince(fallStart) == 25 * 3600)
        #expect(fallBack.admits(at(2026, 11, 1, 23, 59, 59, in: newYork), calendar: newYork))
        #expect(!fallBack.admits(at(2026, 11, 2, 0, 0, 0, in: newYork), calendar: newYork))
    }

    /// Havana's clocks jump from 00:00 to 01:00 on 2026-03-08, so that day has no midnight. The
    /// assertions hold wherever the clocks do jump: the day must start on the 8th, one second after the 7th.
    @Test func aDayWhoseMidnightWasSkippedStillStartsOnThatDay() throws {
        let havana = try calendar(in: "America/Havana")
        let scope = only(day(2026, 3, 8), day(2026, 3, 8))
        let start = try #require(scope.lowerBound(in: havana))
        #expect(havana.component(.day, from: start) == 8)
        #expect(havana.component(.day, from: start.addingTimeInterval(-1)) == 7)
        #expect(scope.admits(start, calendar: havana))
        #expect(!scope.admits(start.addingTimeInterval(-1), calendar: havana))
    }

    // MARK: - The fetch predicate

    @Test func thePredicateForEachShapeOfRange() {
        let first = at(2018, 3, 1, 0, 0, 0)
        let afterLast = at(2018, 4, 1, 0, 0, 0)
        let from = day(2018, 3, 1)
        let to = day(2018, 3, 31)

        #expect(only(from, to).predicateParts(calendar: utc)
                == DateScope.PredicateParts(format: "creationDate >= %@ AND creationDate < %@", arguments: [first, afterLast]))
        #expect(only(from, nil).predicateParts(calendar: utc)
                == DateScope.PredicateParts(format: "creationDate >= %@", arguments: [first]))
        #expect(only(nil, to).predicateParts(calendar: utc)
                == DateScope.PredicateParts(format: "creationDate < %@", arguments: [afterLast]))
        #expect(exclude(from, to).predicateParts(calendar: utc)
                == DateScope.PredicateParts(format: "creationDate < %@ OR creationDate >= %@", arguments: [first, afterLast]))
        #expect(exclude(from, nil).predicateParts(calendar: utc)
                == DateScope.PredicateParts(format: "creationDate < %@", arguments: [first]))
        #expect(exclude(nil, to).predicateParts(calendar: utc)
                == DateScope.PredicateParts(format: "creationDate >= %@", arguments: [afterLast]))
    }

    // The predicate and the rule drawing the same line is checked in DateScopeIntegrationTests, which
    // runs under Xcode only: swift-corelibs-foundation has no NSPredicate format strings.

    // MARK: - Quick picks

    @Test func quickPicksFillInTodaysDates() {
        let now = at(2026, 11, 11)

        let last30 = DateQuickPick.last30Days.days(now: now, calendar: utc)
        #expect(last30.from == day(2026, 10, 12))
        #expect(last30.to == nil)

        let thisYear = DateQuickPick.thisYear.days(now: now, calendar: utc)
        #expect(thisYear.from == day(2026, 1, 1))
        #expect(thisYear.to == nil)

        let lastYear = DateQuickPick.lastYear.days(now: now, calendar: utc)
        #expect(lastYear.from == day(2025, 1, 1))
        #expect(lastYear.to == day(2025, 12, 31))

        let older = DateQuickPick.olderThanAYear.days(now: now, calendar: utc)
        #expect(older.from == nil)
        #expect(older.to == day(2025, 11, 10))   // strictly more than a year ago
    }

    @Test func olderThanAYearSurvivesALeapDay() {
        let older = DateQuickPick.olderThanAYear.days(now: at(2028, 2, 29), calendar: utc)
        #expect(older.to == day(2027, 2, 27))
    }

    @Test func everyQuickPickHasATitle() {
        #expect(DateQuickPick.allCases.map(\.title) == ["Last 30 days", "This year", "Last year", "Older than a year"])
    }

    // MARK: - Words

    @Test func theSummaryNamesTheModeAndTheDays() {
        func summary(_ scope: DateScope) -> String { scope.summary(calendar: utc, locale: english) }
        #expect(summary(only(day(2018, 1, 1), day(2018, 12, 31))) == "Only Jan 1, 2018 – Dec 31, 2018")
        #expect(summary(only(day(2025, 10, 12), nil)) == "Only Oct 12, 2025 onward")
        #expect(summary(only(nil, day(2020, 3, 3))) == "Only through Mar 3, 2020")
        #expect(summary(only(day(2020, 3, 3), day(2020, 3, 3))) == "Only Mar 3, 2020")
        #expect(summary(exclude(day(2018, 1, 1), day(2018, 12, 31))) == "Exclude Jan 1, 2018 – Dec 31, 2018")
        #expect(summary(exclude(day(2025, 10, 12), nil)) == "Exclude Oct 12, 2025 onward")
    }

    @Test func theExplanationSaysWhatADiveWillDo() {
        func explanation(_ scope: DateScope) -> String { scope.explanation(calendar: utc, locale: english) }
        #expect(explanation(only(day(2018, 1, 1), day(2018, 12, 31)))
                == "Dives will show only photos and videos taken from Jan 1, 2018 through Dec 31, 2018.")
        #expect(explanation(only(day(2020, 3, 3), day(2020, 3, 3)))
                == "Dives will show only photos and videos taken on Mar 3, 2020.")
        #expect(explanation(exclude(day(2025, 10, 12), nil))
                == "Dives will never show photos or videos taken from Oct 12, 2025 onward.")
        #expect(explanation(exclude(nil, day(2020, 3, 3)))
                == "Dives will never show photos or videos taken through Mar 3, 2020.")
        #expect(explanation(DateScope.all) == "Dives can draw from every date in your library.")
    }

    // MARK: - Saving

    @Test func aSavedRangeComesBackAfterARelaunch() throws {
        try withDefaults { defaults in
            let scope = exclude(day(2025, 10, 12), nil)
            DateScopeStore.save(scope, to: defaults)
            #expect(DateScopeStore.load(from: defaults) == scope)

            let bounded = only(day(2018, 1, 1), day(2018, 12, 31))
            DateScopeStore.save(bounded, to: defaults)
            #expect(DateScopeStore.load(from: defaults) == bounded)
        }
    }

    @Test func allDatesIsSavedAsNothingAtAll() throws {
        try withDefaults { defaults in
            DateScopeStore.save(only(day(2018, 1, 1), nil), to: defaults)
            #expect(defaults.object(forKey: DateScopeStore.key) != nil)
            DateScopeStore.save(DateScope.all, to: defaults)
            #expect(defaults.object(forKey: DateScopeStore.key) == nil)
            #expect(DateScopeStore.load(from: defaults) == DateScope.all)
        }
    }

    @Test func clearingForgetsTheSavedRange() throws {
        try withDefaults { defaults in
            DateScopeStore.save(exclude(day(2025, 10, 12), nil), to: defaults)
            DateScopeStore.clear(in: defaults)
            #expect(defaults.object(forKey: DateScopeStore.key) == nil)
            #expect(DateScopeStore.load(from: defaults) == DateScope.all)
        }
    }

    /// The saved form is JSON text, because the UI tour presets the range with `-pq.dateScope '<json>'`
    /// and a launch argument reaches UserDefaults as a string.
    @Test func theSavedFormIsReadableJSONText() throws {
        try withDefaults { defaults in
            DateScopeStore.save(exclude(day(2025, 10, 12), nil), to: defaults)
            #expect(defaults.string(forKey: DateScopeStore.key) == #"{"from":{"day":12,"month":10,"year":2025},"mode":"exclude"}"#)
        }
    }

    @Test func aLaunchArgumentCanPresetTheRange() throws {
        try withDefaults { defaults in
            defaults.set(
                #"{"mode":"only","from":{"year":2018,"month":1,"day":1},"to":{"year":2018,"month":12,"day":31}}"#,
                forKey: DateScopeStore.key
            )
            #expect(DateScopeStore.load(from: defaults) == only(day(2018, 1, 1), day(2018, 12, 31)))
        }
    }

    @Test(arguments: ["", "not json", "{}", #"{"mode":"someday"}"#, #"{"mode":"only"}"#])
    func unreadableOrEmptySavedDataMeansAllDates(text: String) throws {
        try withDefaults { defaults in
            defaults.set(text, forKey: DateScopeStore.key)
            #expect(DateScopeStore.load(from: defaults) == DateScope.all)
        }
    }

    @Test func nothingSavedMeansAllDates() throws {
        try withDefaults { defaults in
            #expect(DateScopeStore.load(from: defaults) == DateScope.all)
        }
    }
}
