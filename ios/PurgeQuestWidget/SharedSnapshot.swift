//
//  SharedSnapshot.swift
//  PurgeQuestWidget
//
//  Mirror of the snapshot struct/decoder so the widget extension can
//  read shared App Group data without depending on the main app target.
//

import Foundation

nonisolated struct PurgeQuestWidgetSnapshot: Codable, Hashable {
    var heroName: String
    var heroLevel: Int
    var levelProgress: Double
    var gems: Int
    var streakDays: Int
    var totalMBFreed: Double
    var questTitle: String
    var questSubtitle: String
    var questCurrent: Int
    var questTarget: Int
    var questIsVideo: Bool
    var updatedAt: Date

    nonisolated static let placeholder = PurgeQuestWidgetSnapshot(
        heroName: "Hero",
        heroLevel: 4,
        levelProgress: 0.62,
        gems: 480,
        streakDays: 5,
        totalMBFreed: 3640,
        questTitle: "Video Vampire Purge",
        questSubtitle: "Banish 6 Video Vampires.",
        questCurrent: 4,
        questTarget: 6,
        questIsVideo: true,
        updatedAt: .now
    )
}

nonisolated enum WidgetSnapshotReader {
    static let appGroupID = "group.com.purgequest.app"
    static let snapshotKey = "purgequest.widget.snapshot.v1"

    static func read() -> PurgeQuestWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey),
              let decoded = try? JSONDecoder().decode(PurgeQuestWidgetSnapshot.self, from: data)
        else {
            return .placeholder
        }
        return decoded
    }
}
