//
//  CombatSession.swift
//  PurgeQuest
//

import Foundation
import SwiftData

@Model
final class CombatSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var photosDeleted: Int
    var videosDeleted: Int
    var bytesFreed: Int64
    var xpEarned: Int
    var gemsEarned: Int
    var peakCombo: Int
    var roomsCompleted: Int

    init() {
        self.id = UUID()
        self.startedAt = Date()
        self.endedAt = nil
        self.photosDeleted = 0
        self.videosDeleted = 0
        self.bytesFreed = 0
        self.xpEarned = 0
        self.gemsEarned = 0
        self.peakCombo = 0
        self.roomsCompleted = 0
    }
}
