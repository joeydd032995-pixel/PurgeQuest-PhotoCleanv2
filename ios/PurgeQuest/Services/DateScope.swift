//
//  DateScope.swift
//  PurgeQuest
//
//  Which capture dates a dive may draw from: every date (the default), only a range, or everything
//  except a range. A range is a first and a last calendar day, and either end may be left open
//  ("Oct 12 onward", "through Mar 3"). It is a standing setting, so it is saved as text in UserDefaults.
//
//  PhotoLibraryService turns `predicateParts` into the fetch predicate, then checks every asset it gets
//  back against the rule again. The predicate keeps the fetch cheap; the re-check is what makes an
//  excluded range a promise, whatever PhotoKit does with the predicate.
//
//  Pure Foundation (no Photos, no SwiftUI, no SwiftData) so the Linux harness runs it.
//

import Foundation

// MARK: - A calendar day

/// A calendar day with no time zone attached, always counted in the Gregorian calendar. A range kept as
/// days means the same local day after a flight, or after the device's calendar setting changes; kept as
/// instants it would slide by up to a day.
nonisolated struct CalendarDay: Codable, Hashable, Comparable, Sendable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`'s time zone.
    init(_ date: Date, calendar: Calendar = .current) {
        let parts = Self.gregorian(like: calendar).dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// The first instant of this day in `calendar`'s time zone. It is built from noon, which every day
    /// has, and rounded down, so a day whose midnight a clock change skipped still starts where it should.
    func start(in calendar: Calendar = .current) -> Date {
        let gregorian = Self.gregorian(like: calendar)
        let noon = gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
            ?? Date(timeIntervalSince1970: 0)
        return gregorian.startOfDay(for: noon)
    }

    /// The first instant of the following day: the exclusive end of this one.
    func nextDayStart(in calendar: Calendar = .current) -> Date {
        let gregorian = Self.gregorian(like: calendar)
        let begin = start(in: calendar)
        let next = gregorian.date(byAdding: .day, value: 1, to: begin) ?? begin.addingTimeInterval(86_400)
        return gregorian.startOfDay(for: next)
    }

    private static func gregorian(like calendar: Calendar) -> Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian
    }
}

// MARK: - The scope

nonisolated struct DateScope: Codable, Equatable, Sendable {

    nonisolated enum Mode: String, Codable, Sendable, CaseIterable {
        case all, only, exclude
    }

    let mode: Mode
    /// The first day of the range, included. Nil leaves the start open.
    let from: CalendarDay?
    /// The last day of the range, included. Nil leaves the end open.
    let to: CalendarDay?

    /// No restriction: every capture date is allowed.
    static let all = DateScope(mode: .all)

    /// Builds a scope in its one canonical form: reversed ends are swapped, and a mode with no day at all
    /// (or `.all` given days) is `.all`, so two scopes that mean the same thing are equal.
    init(mode: Mode, from: CalendarDay? = nil, to: CalendarDay? = nil) {
        guard mode != .all, from != nil || to != nil else {
            self.mode = .all
            self.from = nil
            self.to = nil
            return
        }
        self.mode = mode
        if let first = from, let last = to, last < first {
            self.from = last
            self.to = first
        } else {
            self.from = from
            self.to = to
        }
    }

    // MARK: Saved form

    private enum CodingKeys: String, CodingKey { case mode, from, to }

    /// Reads through the normalizing initializer, so saved data can never produce a scope the app could not build.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .all
        let from = try container.decodeIfPresent(CalendarDay.self, forKey: .from)
        let to = try container.decodeIfPresent(CalendarDay.self, forKey: .to)
        self.init(mode: mode, from: from, to: to)
    }

    // MARK: The rule

    /// True when a range is in force.
    var isActive: Bool { mode != .all }

    /// The first instant the range covers, or nil when its start is open.
    func lowerBound(in calendar: Calendar = .current) -> Date? { from?.start(in: calendar) }

    /// The first instant after the range, or nil when its end is open.
    func upperBound(in calendar: Calendar = .current) -> Date? { to?.nextDayStart(in: calendar) }

    /// The range worked out as instants once, so a loop over thousands of assets does not redo calendar
    /// arithmetic for each one.
    nonisolated struct Resolved: Sendable {
        let mode: Mode
        let lower: Date?
        let upper: Date?

        /// Whether an item captured at `date` may be dealt. An item with no capture date cannot be placed
        /// against a range, so it sits out whenever one is active.
        func admits(_ date: Date?) -> Bool {
            guard mode != .all else { return true }
            guard let date else { return false }
            var inside = true
            if let lower, date < lower { inside = false }
            if let upper, date >= upper { inside = false }
            return mode == .only ? inside : !inside
        }
    }

    func resolved(calendar: Calendar = .current) -> Resolved {
        Resolved(mode: mode, lower: lowerBound(in: calendar), upper: upperBound(in: calendar))
    }

    /// Whether an item captured at `date` may be dealt.
    func admits(_ date: Date?, calendar: Calendar = .current) -> Bool {
        resolved(calendar: calendar).admits(date)
    }

    // MARK: The fetch predicate

    /// The `creationDate` predicate PhotoKit fetches with, as a format and its dates. PhotoKit does the
    /// filtering, so the fetch limit and the oldest-first order apply to the dates a dive may draw from.
    nonisolated struct PredicateParts: Equatable, Sendable {
        var format: String
        var arguments: [Date]
    }

    /// Nil when no range is in force.
    func predicateParts(calendar: Calendar = .current) -> PredicateParts? {
        guard isActive else { return nil }
        let low = lowerBound(in: calendar)
        let high = upperBound(in: calendar)
        switch mode {
        case .all:
            return nil
        case .only:
            switch (low, high) {
            case let (low?, high?):
                return PredicateParts(format: "creationDate >= %@ AND creationDate < %@", arguments: [low, high])
            case let (low?, nil):
                return PredicateParts(format: "creationDate >= %@", arguments: [low])
            case let (nil, high?):
                return PredicateParts(format: "creationDate < %@", arguments: [high])
            case (nil, nil):
                return nil
            }
        case .exclude:
            switch (low, high) {
            case let (low?, high?):
                return PredicateParts(format: "creationDate < %@ OR creationDate >= %@", arguments: [low, high])
            case let (low?, nil):
                return PredicateParts(format: "creationDate < %@", arguments: [low])
            case let (nil, high?):
                return PredicateParts(format: "creationDate >= %@", arguments: [high])
            case (nil, nil):
                return nil
            }
        }
    }

    // MARK: Words

    /// A short label, for the Dashboard row: "All dates", "Only Jan 1, 2018 – Dec 31, 2018",
    /// "Exclude Oct 12, 2025 onward".
    func summary(calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard isActive else { return "All dates" }
        let verb = mode == .only ? "Only" : "Exclude"
        return "\(verb) \(rangeText(calendar: calendar, locale: locale, asSentence: false))"
    }

    /// What a dive will do, in a sentence, for the sheet.
    func explanation(calendar: Calendar = .current, locale: Locale = .current) -> String {
        switch mode {
        case .all:
            return "Dives can draw from every date in your library."
        case .only:
            return "Dives will show only photos and videos taken \(rangeText(calendar: calendar, locale: locale, asSentence: true))."
        case .exclude:
            return "Dives will never show photos or videos taken \(rangeText(calendar: calendar, locale: locale, asSentence: true))."
        }
    }

    private func rangeText(calendar: Calendar, locale: Locale, asSentence: Bool) -> String {
        let start = from.map { Self.format($0, calendar: calendar, locale: locale) }
        let end = to.map { Self.format($0, calendar: calendar, locale: locale) }
        switch (start, end) {
        case let (start?, end?):
            if from == to { return asSentence ? "on \(start)" : start }
            return asSentence ? "from \(start) through \(end)" : "\(start) – \(end)"
        case let (start?, nil):
            return asSentence ? "from \(start) onward" : "\(start) onward"
        case let (nil, end?):
            return "through \(end)"
        case (nil, nil):
            return ""   // not reachable: a scope with no day is `.all`
        }
    }

    private static func format(_ day: CalendarDay, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: day.start(in: calendar))
    }
}

// MARK: - Quick picks

/// Ready-made ranges for the sheet. They fill in concrete days from today's date and do not roll forward.
/// The ones that start at a day leave the end open, so photos taken later stay covered.
nonisolated enum DateQuickPick: CaseIterable, Sendable {
    case last30Days, thisYear, lastYear, olderThanAYear

    var title: String {
        switch self {
        case .last30Days:     return "Last 30 days"
        case .thisYear:       return "This year"
        case .lastYear:       return "Last year"
        case .olderThanAYear: return "Older than a year"
        }
    }

    func days(now: Date, calendar: Calendar = .current) -> (from: CalendarDay?, to: CalendarDay?) {
        let today = CalendarDay(now, calendar: calendar)
        switch self {
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (CalendarDay(start, calendar: calendar), nil)
        case .thisYear:
            return (CalendarDay(year: today.year, month: 1, day: 1), nil)
        case .lastYear:
            return (CalendarDay(year: today.year - 1, month: 1, day: 1),
                    CalendarDay(year: today.year - 1, month: 12, day: 31))
        case .olderThanAYear:
            // Strictly more than a year ago: the day a year back is not "older than" a year.
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            let before = calendar.date(byAdding: .day, value: -1, to: yearAgo) ?? yearAgo
            return (nil, CalendarDay(before, calendar: calendar))
        }
    }
}

// MARK: - Saving

/// Where the range is kept: JSON text under one UserDefaults key, readable in a defaults dump.
nonisolated enum DateScopeStore {
    static let key = "pq.dateScope"

    /// The saved range; anything missing or unreadable is all dates.
    static func load(from defaults: UserDefaults = .standard) -> DateScope {
        guard let text = defaults.string(forKey: key) else { return .all }
        return decode(text) ?? .all
    }

    /// A range from its saved text, or nil when the text is not one. A tour launch argument goes through
    /// here as well (see UITestSupport).
    static func decode(_ text: String) -> DateScope? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DateScope.self, from: data)
    }

    /// All dates is saved as nothing at all, so the defaults stay clean for anyone who never uses a range.
    static func save(_ scope: DateScope, to defaults: UserDefaults = .standard) {
        guard scope.isActive else {
            defaults.removeObject(forKey: key)
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(scope), let text = String(data: data, encoding: .utf8) else { return }
        defaults.set(text, forKey: key)
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
