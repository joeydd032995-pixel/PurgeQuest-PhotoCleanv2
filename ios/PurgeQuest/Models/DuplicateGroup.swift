//
//  DuplicateGroup.swift
//  PurgeQuest
//
//  One duplicate encounter in the dungeon: a cluster of near-identical copies
//  resolved with a single explicit decision per copy. The recommended
//  survivor is a suggestion only — the player always chooses.
//

import Foundation

struct DuplicateGroup: Identifiable, Equatable {
    /// Oldest member's asset ID — the encounter's stable identity.
    let representativeID: String
    /// All copies, oldest capture first. Includes the representative.
    let members: [MediaItem]
    /// Recommended best copy's asset ID (suggestion only, may be nil).
    let survivorID: String?

    var id: String { representativeID }

    var representative: MediaItem? { members.first }
    var monsterType: MonsterType { members.first?.monsterType ?? .duplicateDragon }
    var classification: MonsterClassification? { members.first?.classification }

    func member(id: String) -> MediaItem? {
        members.first { $0.id == id }
    }

    var recommendedSurvivor: MediaItem? {
        survivorID.flatMap { member(id: $0) }
    }
}
