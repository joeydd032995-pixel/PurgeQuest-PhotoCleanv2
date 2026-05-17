//
//  SeasonalEventService.swift
//  PurgeQuest
//
//  Time-limited seasonal events. Each event re-skins the dungeon, adds
//  bonus XP for specific monsters, and exposes exclusive cosmetics.
//  Pure date-based — no remote config required.
//

import Foundation
import SwiftUI

struct SeasonalEvent: Identifiable, Sendable {
    enum Tone: Sendable { case spooky, festive, summery, newYear }

    let id: String
    let name: String
    let tagline: String
    let symbol: String
    let tone: Tone
    let primary: Color
    let secondary: Color
    let bonusMonsters: Set<MonsterType>
    let bonusXPMultiplier: Double
    /// Closure-based date matcher so we don't bake any specific year in.
    let matches: @Sendable (DateComponents) -> Bool
    let exclusiveCosmeticIDs: [String]
}

@MainActor
@Observable
final class SeasonalEventService {
    static let shared = SeasonalEventService()

    private(set) var activeEvent: SeasonalEvent?

    private init() {
        refresh()
    }

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    static let allEvents: [SeasonalEvent] = [
        SeasonalEvent(
            id: "halloween",
            name: "Phantom Purge",
            tagline: "Wraiths roam the deep dungeon. +50% XP on shadowy foes.",
            symbol: "moon.stars.fill",
            tone: .spooky,
            primary: Color(red: 1.0, green: 0.42, blue: 0.05),
            secondary: Color(red: 0.36, green: 0.13, blue: 0.55),
            bonusMonsters: [.darkWraith, .corruptedCodec, .shakyGhost],
            bonusXPMultiplier: 1.5,
            matches: { dc in
                guard let m = dc.month, let d = dc.day else { return false }
                return m == 10 && d >= 20 || (m == 11 && d <= 1)
            },
            exclusiveCosmeticIDs: ["fx.spectral", "skin.wraithcloak"]
        ),
        SeasonalEvent(
            id: "newyear",
            name: "Resolution Purge",
            tagline: "Slay Ancient Archives for +75% XP. Out with the old.",
            symbol: "sparkles",
            tone: .newYear,
            primary: Color(red: 1.0, green: 0.84, blue: 0.32),
            secondary: Color(red: 0.6, green: 0.84, blue: 1.0),
            bonusMonsters: [.ancientArchive, .duplicateDragon],
            bonusXPMultiplier: 1.75,
            matches: { dc in
                guard let m = dc.month, let d = dc.day else { return false }
                return (m == 12 && d >= 27) || (m == 1 && d <= 7)
            },
            exclusiveCosmeticIDs: ["fx.confetti", "weapon.fireworkBlade"]
        ),
        SeasonalEvent(
            id: "summer",
            name: "Vacation Bloat",
            tagline: "Beach reels & sunset selfies overflowing. +50% video XP.",
            symbol: "sun.max.fill",
            tone: .summery,
            primary: Color(red: 1.0, green: 0.66, blue: 0.27),
            secondary: Color(red: 0.18, green: 0.71, blue: 0.94),
            bonusMonsters: [.longTakeLeviathan, .videoVampire, .timelapsePhantom],
            bonusXPMultiplier: 1.5,
            matches: { dc in
                guard let m = dc.month else { return false }
                return m >= 6 && m <= 8
            },
            exclusiveCosmeticIDs: ["pet.beachSpirit", "skin.sandblade"]
        ),
        SeasonalEvent(
            id: "valentine",
            name: "Heartbreak Hunt",
            tagline: "Old screenshots haunt the catacombs. +60% photo XP.",
            symbol: "heart.fill",
            tone: .festive,
            primary: Color(red: 0.95, green: 0.32, blue: 0.55),
            secondary: Color(red: 0.42, green: 0.13, blue: 0.49),
            bonusMonsters: [.screenshotSpecter, .blurBeast, .lowQualityLich],
            bonusXPMultiplier: 1.6,
            matches: { dc in
                guard let m = dc.month, let d = dc.day else { return false }
                return m == 2 && d >= 10 && d <= 16
            },
            exclusiveCosmeticIDs: ["fx.hearts"]
        )
    ]

    func refresh(now: Date = .now) {
        let dc = Self.calendar.dateComponents([.month, .day], from: now)
        activeEvent = Self.allEvents.first { $0.matches(dc) }
    }

    /// Bonus XP multiplier the combat VM should apply for a slain monster.
    func xpMultiplier(for monster: MonsterType) -> Double {
        guard let e = activeEvent, e.bonusMonsters.contains(monster) else { return 1.0 }
        return e.bonusXPMultiplier
    }
}
