//
//  DeletedMediaRecord.swift
//  PurgeQuest
//

import Foundation
import SwiftData

@Model
final class DeletedMediaRecord {
    @Attribute(.unique) var id: UUID
    var assetIdentifier: String
    var mediaKindRaw: String
    var monsterTypeRaw: String
    var fileSizeBytes: Int64
    var deletedAt: Date

    var mediaKind: MediaKind { MediaKind(rawValue: mediaKindRaw) ?? .photo }
    var monsterType: MonsterType { MonsterType(rawValue: monsterTypeRaw) ?? .blurBeast }
    var isInUndoWindow: Bool {
        // Recently Deleted is 30 days; we surface a 7-day "fresh" window.
        Date().timeIntervalSince(deletedAt) < 7 * 86_400
    }

    init(assetIdentifier: String, mediaKind: MediaKind, monsterType: MonsterType, fileSizeBytes: Int64) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.mediaKindRaw = mediaKind.rawValue
        self.monsterTypeRaw = monsterType.rawValue
        self.fileSizeBytes = fileSizeBytes
        self.deletedAt = Date()
    }
}
