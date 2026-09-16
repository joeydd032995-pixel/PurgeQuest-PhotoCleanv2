//
//  BestiaryService.swift
//  PurgeQuest
//
//  Encounter stats for the Bestiary tab. Encounters come from a sighting
//  record; spared/slain counts and reclaimed bytes aggregate from the
//  existing spare and deletion logs. 100% on-device.
//

import Foundation
import SwiftData

@MainActor
enum BestiaryService {

    struct MonsterStats: Equatable, Sendable {
        var encountered: Int = 0
        var spared: Int = 0
        var slain: Int = 0
        var bytesReclaimed: Int64 = 0

        var isDiscovered: Bool { encountered > 0 || spared > 0 || slain > 0 }
    }

    /// Counts every presented asset as an encounter. Called once per dive
    /// with the full classified batch (group members included).
    static func recordEncounters(for items: [MediaItem], context: ModelContext) {
        guard !items.isEmpty else { return }
        let all = (try? context.fetch(FetchDescriptor<MonsterSightingRecord>())) ?? []
        var byType = Dictionary(
            all.compactMap { rec in rec.monsterType.map { ($0, rec) } },
            uniquingKeysWith: { first, _ in first }
        )
        var didChange = false
        for item in items {
            if let sighting = byType[item.monsterType] {
                sighting.encounteredCount += 1
                sighting.bytesSeen += item.estimatedBytes
                sighting.lastEncounteredAt = Date()
                didChange = true
            } else {
                let rec = MonsterSightingRecord(monsterType: item.monsterType)
                rec.encounteredCount = 1
                rec.bytesSeen = item.estimatedBytes
                context.insert(rec)
                if let t = rec.monsterType { byType[t] = rec }
                didChange = true
            }
        }
        if didChange { try? context.save() }
    }

    static func stats(for type: MonsterType, context: ModelContext) -> MonsterStats {
        var stats = MonsterStats()
        stats.encountered = sightingCount(for: type, in: context)

        let spared = (try? context.fetch(FetchDescriptor<SparedMediaRecord>())) ?? []
        stats.spared = spared.filter { $0.monsterType == type }.count

        let deleted = (try? context.fetch(FetchDescriptor<DeletedMediaRecord>())) ?? []
        let slainRecords = deleted.filter { $0.monsterType == type }
        stats.slain = slainRecords.count
        stats.bytesReclaimed = slainRecords.reduce(0) { $0 + $1.fileSizeBytes }
        return stats
    }

    static func isDiscovered(_ type: MonsterType, context: ModelContext) -> Bool {
        sightingCount(for: type, in: context) > 0
    }

    private static func sightingCount(for type: MonsterType, in context: ModelContext) -> Int {
        var descriptor = FetchDescriptor<MonsterSightingRecord>(
            predicate: #Predicate { $0.monsterTypeRaw == type.rawValue }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first?.encounteredCount) ?? 0
    }
}
