//
//  MonsterSightingRecord.swift
//  PurgeQuest
//
//  Aggregated encounter counters per monster type, feeding the Bestiary.
//  Spared/slain counts and reclaimed bytes come from the existing spare and
//  deletion logs; this record only tracks that a monster was encountered.
//

import Foundation
import SwiftData

@Model
final class MonsterSightingRecord {
    @Attribute(.unique) var monsterTypeRaw: String
    var encounteredCount: Int
    var bytesSeen: Int64
    var firstEncounteredAt: Date
    var lastEncounteredAt: Date

    var monsterType: MonsterType? { MonsterType(rawValue: monsterTypeRaw) }

    init(monsterType: MonsterType) {
        self.monsterTypeRaw = monsterType.rawValue
        self.encounteredCount = 0
        self.bytesSeen = 0
        self.firstEncounteredAt = Date()
        self.lastEncounteredAt = Date()
    }
}
