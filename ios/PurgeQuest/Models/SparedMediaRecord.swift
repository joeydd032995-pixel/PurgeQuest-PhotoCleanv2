//
//  SparedMediaRecord.swift
//  PurgeQuest
//

import Foundation
import SwiftData

/// Marks a library asset the hero deliberately spared, so re-entering the dungeon
/// resumes with unseen monsters instead of replaying items from the top of the
/// camera roll. Purely a local progress marker — never leaves the device.
@Model
final class SparedMediaRecord {
    @Attribute(.unique) var assetIdentifier: String
    var sparedAt: Date
    /// Which monster the spared asset summoned, for bestiary stats.
    /// Optional so pre-expansion rows migrate as nil without loss.
    var monsterTypeRaw: String?

    var monsterType: MonsterType? {
        monsterTypeRaw.flatMap(MonsterType.init(rawValue:))
    }

    init(assetIdentifier: String, sparedAt: Date = Date(), monsterType: MonsterType? = nil) {
        self.assetIdentifier = assetIdentifier
        self.sparedAt = sparedAt
        self.monsterTypeRaw = monsterType?.rawValue
    }
}
