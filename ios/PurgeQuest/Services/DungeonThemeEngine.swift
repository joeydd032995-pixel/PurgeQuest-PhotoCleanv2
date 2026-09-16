//
//  DungeonThemeEngine.swift
//  PurgeQuest
//
//  Automatic dungeon themes (stage 1+2 supporting system). A theme is chosen
//  per dive from the library's composition and affects encounter weighting
//  and presentation only — never the player's decisions. Wild Gallery is the
//  fallback when no signal dominates.
//

import Foundation
import SwiftUI

/// Aggregated composition signals for one library batch.
struct LibraryComposition: Sendable, Equatable {
    var total: Int = 0
    var screenshotCount: Int = 0
    var oldCount: Int = 0
    var largeCount: Int = 0
    var videoCount: Int = 0
    /// Broken media: unloadable renders, empty files, or videos without
    /// playable metadata (stages 3–5 broaden this beyond video metadata).
    var brokenCount: Int = 0
    /// Share of items that belong to a duplicate cluster (0…1).
    var duplicateShare: Double = 0

    var screenshotShare: Double { total == 0 ? 0 : Double(screenshotCount) / Double(total) }
    var oldShare: Double { total == 0 ? 0 : Double(oldCount) / Double(total) }
    var largeShare: Double { total == 0 ? 0 : Double(largeCount) / Double(total) }
    var videoShare: Double { total == 0 ? 0 : Double(videoCount) / Double(total) }
    var brokenShare: Double { total == 0 ? 0 : Double(brokenCount) / Double(total) }
}

enum DungeonTheme: String, CaseIterable, Codable, Sendable {
    case wildGallery
    case clutterCatacombs
    case archiveDepths
    case vaultOfExcess
    case dragonsHoard
    case phantomTheater
    case glitchAbyss

    var displayName: String {
        switch self {
        case .wildGallery:      return "Wild Gallery"
        case .clutterCatacombs: return "Clutter Catacombs"
        case .archiveDepths:    return "Archive Depths"
        case .vaultOfExcess:    return "Vault of Excess"
        case .dragonsHoard:     return "Dragon's Hoard"
        case .phantomTheater:   return "Phantom Theater"
        case .glitchAbyss:      return "Glitch Abyss"
        }
    }

    var symbol: String {
        switch self {
        case .wildGallery:      return "sparkles.rectangle.stack.fill"
        case .clutterCatacombs: return "trash.stack.fill"
        case .archiveDepths:    return "hourglass"
        case .vaultOfExcess:    return "externaldrive.fill"
        case .dragonsHoard:     return "square.on.square"
        case .phantomTheater:   return "play.rectangle.fill"
        case .glitchAbyss:      return "exclamationmark.triangle.fill"
        }
    }

    /// One-line intro shown on the theme banner and dashboard card.
    var tagline: String {
        switch self {
        case .wildGallery:      return "A mixed haul from every corner of your library."
        case .clutterCatacombs: return "Screenshots and blurry snaps crowd the halls."
        case .archiveDepths:    return "A memory from years past awaits judgment."
        case .vaultOfExcess:    return "Colossal files guard the deep vaults."
        case .dragonsHoard:     return "Twin scales gleam — copies cluster in the dark."
        case .phantomTheater:   return "Reels of half-forgotten footage flicker."
        case .glitchAbyss:      return "Something here could not be fully loaded."
        }
    }

    var tintColor: Color {
        switch self {
        case .wildGallery:      return .questAmber
        case .clutterCatacombs: return .questAmber
        case .archiveDepths:    return .xpViolet
        case .vaultOfExcess:    return .gemEmerald
        case .dragonsHoard:     return .combatCrimson
        case .phantomTheater:   return .videoSapphire
        case .glitchAbyss:      return .combatCrimsonDeep
        }
    }

    /// Monster family this theme emphasizes, for encounter weighting.
    var emphasizedFamily: MonsterFamily? {
        switch self {
        case .wildGallery: return nil
        case .clutterCatacombs: return .clutterUndead
        case .archiveDepths: return .archiveRelics
        case .vaultOfExcess: return .storageBehemoths
        case .dragonsHoard: return .duplicateDragons
        case .phantomTheater: return .videoPhantoms
        case .glitchAbyss: return .glitchborn
        }
    }
}

enum DungeonThemeEngine {

    /// Share thresholds. Order is priority: the most actionable signal wins.
    static let brokenShareThreshold = 0.05
    static let duplicateShareThreshold = 0.12
    static let largeShareThreshold = 0.06
    static let screenshotShareThreshold = 0.25
    static let oldShareThreshold = 0.35
    static let videoShareThreshold = 0.5

    /// Minimum batch size before any theme can trigger.
    static let minimumBatch = 8

    static func composition(for items: [MediaItem], now: Date = Date()) -> LibraryComposition {
        var c = LibraryComposition()
        c.total = items.count
        let threeYearsAgo = Calendar.current.date(byAdding: .year, value: -MonsterClassifier.archiveYears, to: now) ?? .distantPast

        for item in items {
            if item.isScreenshot { c.screenshotCount += 1 }
            if (item.creationDate ?? .distantFuture) < threeYearsAgo { c.oldCount += 1 }
            if item.estimatedBytes >= MonsterClassifier.hundredMegabyte { c.largeCount += 1 }
            let isBroken = item.loadFailed || item.estimatedBytes <= 0
                || (item.kind == .video && item.durationSeconds <= 0)
            if isBroken { c.brokenCount += 1 }
            if item.kind == .video {
                c.videoCount += 1
            }
        }
        return c
    }

    /// Chooses the dungeon theme for a dive. Clusters raise the duplicate
    /// share so Dragon's Hoard can trigger even on mixed libraries.
    static func theme(for composition: LibraryComposition) -> DungeonTheme {
        guard composition.total >= minimumBatch else { return .wildGallery }
        if composition.brokenShare >= brokenShareThreshold { return .glitchAbyss }
        if composition.duplicateShare >= duplicateShareThreshold { return .dragonsHoard }
        if composition.largeShare >= largeShareThreshold { return .vaultOfExcess }
        if composition.screenshotShare >= screenshotShareThreshold { return .clutterCatacombs }
        if composition.oldShare >= oldShareThreshold { return .archiveDepths }
        if composition.videoShare >= videoShareThreshold { return .phantomTheater }
        return .wildGallery
    }

    /// True when an item belongs to the theme's emphasized family — used to
    /// order the encounter queue (presentation only, decisions unchanged).
    static func isThemed(_ item: MediaItem, theme: DungeonTheme) -> Bool {
        guard let family = theme.emphasizedFamily else { return false }
        return item.monsterType.family == family
    }
}
