//
//  UITestSupport.swift
//  PurgeQuest
//
//  Launch-argument hooks for the screenshot tour (AppearanceTourUITests). All of
//  it is compiled out of Release builds: `isTour` is a constant false there.
//
//    -UITestTour            in-memory store, no photo-permission prompt
//    -UITestPhase <phase>   splash | onboarding | main (default main)
//    -UITestEquip <ids>     comma-separated cosmetic ids to unlock and equip
//    -UITestMet <types>     comma-separated MonsterType raw values to mark as encountered
//    -UITestEvent <id>      seasonal event to show as running (e.g. halloween)
//    -UITestVariant <n>     paint variant (1...3) of the hero's race; pick the race with -pq.race
//    -UITestDateScope <json>  date range to start with, in the form a range is saved in (kept in memory only)
//

import Foundation
import SwiftData

enum UITestSupport {
    static var isTour: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("-UITestTour")
        #else
        return false
        #endif
    }

    /// The screen a tour launch should stop on, or nil outside a tour.
    static var requestedPhase: AppPhase? {
        #if DEBUG
        guard isTour else { return nil }
        switch UserDefaults.standard.string(forKey: "UITestPhase") {
        case "splash":     return .launching
        case "onboarding": return .onboarding
        default:           return .main
        }
        #else
        return nil
        #endif
    }

    /// Comma-separated ids from a launch argument, trimmed, without blanks.
    static func ids(from raw: String?) -> [String] {
        (raw ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// The seasonal event a tour launch pretends is running, or nil.
    static var forcedEventID: String? {
        #if DEBUG
        guard isTour else { return nil }
        return UserDefaults.standard.string(forKey: "UITestEvent")
        #else
        return nil
        #endif
    }

    /// The date range a tour launch starts with, or nil: `-UITestDateScope '<json>'`. It is held in memory
    /// only, so it never lands in the simulator's defaults to colour the next test's launch.
    static var forcedDateScope: DateScope? {
        #if DEBUG
        guard isTour else { return nil }
        return dateScope(in: CommandLine.arguments)
        #else
        return nil
        #endif
    }

    /// The range after `-UITestDateScope` in `arguments`, or nil. It is read from the arguments
    /// themselves: through UserDefaults a `-key value` argument is taken for a property list, JSON is
    /// not one, and the range never arrived.
    static func dateScope(in arguments: [String]) -> DateScope? {
        guard let flag = arguments.firstIndex(of: "-UITestDateScope"), arguments.indices.contains(flag + 1) else { return nil }
        return DateScopeStore.decode(arguments[flag + 1])
    }

    /// Wears the requested items and marks the requested monsters as met, so the tour can
    /// photograph art that a fresh install cannot reach. Does nothing outside a tour.
    @MainActor
    static func applyTourLoadout(in context: ModelContext) {
        #if DEBUG
        guard isTour else { return }
        let defaults = UserDefaults.standard
        let equipIDs = ids(from: defaults.string(forKey: "UITestEquip"))
        if !equipIDs.isEmpty, let items = try? context.fetch(FetchDescriptor<CosmeticItem>()) {
            for id in equipIDs {
                guard let item = items.first(where: { $0.id == id }) else { continue }
                for other in items where other.type == item.type { other.isEquipped = false }
                item.isUnlocked = true
                item.isEquipped = true
            }
        }
        if let raw = defaults.string(forKey: "UITestVariant"), let variant = Int(raw),
           let hero = (try? context.fetch(FetchDescriptor<Hero>()))?.first {
            var look = hero.appearance
            look.paintVariant = min(max(variant, 1), hero.race.variantCount)
            hero.appearance = look
        }
        for raw in ids(from: defaults.string(forKey: "UITestMet")) {
            guard let type = MonsterType(rawValue: raw) else { continue }
            let record = MonsterSightingRecord(monsterType: type)
            record.encounteredCount = 1
            context.insert(record)
        }
        try? context.save()
        #endif
    }
}
