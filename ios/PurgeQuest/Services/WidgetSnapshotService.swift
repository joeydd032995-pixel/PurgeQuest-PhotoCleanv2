//
//  WidgetSnapshotService.swift
//  PurgeQuest
//
//  Writes a tiny snapshot of hero/quest/streak state into the shared App Group
//  container so the WidgetKit extension can render an up-to-date timeline.
//
//  The snapshot is intentionally small (a single Codable struct, well under 4KB).
//  Whenever it's written we also kick `WidgetCenter.shared.reloadAllTimelines()`
//  so installed widgets refresh immediately.
//

import Foundation
import WidgetKit

/// Shared between the host app and the widget extension.
nonisolated struct PurgeQuestWidgetSnapshot: Codable, Hashable {
    var heroName: String
    var heroLevel: Int
    var levelProgress: Double
    var gems: Int
    var streakDays: Int
    var totalMBFreed: Double
    // Featured daily quest
    var questTitle: String
    var questSubtitle: String
    var questCurrent: Int
    var questTarget: Int
    var questIsVideo: Bool
    var updatedAt: Date

    nonisolated static let placeholder = PurgeQuestWidgetSnapshot(
        heroName: "Hero",
        heroLevel: 1,
        levelProgress: 0.42,
        gems: 240,
        streakDays: 3,
        totalMBFreed: 1842,
        questTitle: "Blur Beast Hunter",
        questSubtitle: "Slay 8 blurry photo monsters.",
        questCurrent: 3,
        questTarget: 8,
        questIsVideo: false,
        updatedAt: .now
    )
}

@MainActor
enum WidgetSnapshotService {

    static let appGroupID = "group.com.purgequest.app"
    static let snapshotKey = "purgequest.widget.snapshot.v1"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Build a snapshot from the current SwiftData state and persist it.
    static func write(hero: Hero?, quests: [Quest]) {
        let featured: Quest? = quests
            .filter { !$0.completed }
            .sorted { $0.progressFraction > $1.progressFraction }
            .first ?? quests.first

        let snapshot = PurgeQuestWidgetSnapshot(
            heroName: hero?.name ?? "Hero",
            heroLevel: hero?.level ?? 1,
            levelProgress: hero?.levelProgress ?? 0,
            gems: hero?.gems ?? 0,
            streakDays: hero?.streakDays ?? 0,
            totalMBFreed: hero?.totalMBFreed ?? 0,
            questTitle: featured?.title ?? "No active quest",
            questSubtitle: featured?.subtitle ?? "Enter the dungeon to begin.",
            questCurrent: featured?.currentCount ?? 0,
            questTarget: featured?.targetCount ?? 1,
            questIsVideo: featured?.kind == .videoSlay,
            updatedAt: .now
        )
        persist(snapshot)
    }

    static func persist(_ snapshot: PurgeQuestWidgetSnapshot) {
        guard let defaults = sharedDefaults else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func read() -> PurgeQuestWidgetSnapshot {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: snapshotKey),
              let decoded = try? JSONDecoder().decode(PurgeQuestWidgetSnapshot.self, from: data)
        else {
            return .placeholder
        }
        return decoded
    }
}
