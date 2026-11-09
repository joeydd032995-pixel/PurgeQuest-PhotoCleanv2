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

    // SECURED vs PENDING rewards — see CombatViewModel.
    // The tallies above plus `xpEarned`/`gemsEarned` are SECURED: banked onto
    // the Hero at each Room Summary confirmation, they survive a defeat.
    // `pendingXP`/`pendingGems` are PENDING dive bonuses (Perfect Room); they
    // convert to secured when the dive completes and are discarded on defeat.
    var pendingXP: Int = 0
    var pendingGems: Int = 0

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
        self.pendingXP = 0
        self.pendingGems = 0
    }
}
