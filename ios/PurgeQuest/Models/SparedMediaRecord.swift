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

    init(assetIdentifier: String, sparedAt: Date = Date()) {
        self.assetIdentifier = assetIdentifier
        self.sparedAt = sparedAt
    }
}
