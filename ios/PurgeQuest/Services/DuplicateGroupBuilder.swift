//
//  DuplicateGroupBuilder.swift
//  PurgeQuest
//
//  Turns a classified batch into duplicate encounters. Each cluster becomes one group whose copies
//  all carry the cluster's verdict, so whatever the player does to a copy (XP, quest progress, the
//  deletion log, the bestiary) is booked against the monster the group card shows, not against
//  whatever that copy would have been on its own.
//

import Foundation

enum DuplicateGroupBuilder {

    struct Result {
        /// Every item of the batch. Cluster copies carry their cluster's monster type and verdict.
        let items: [MediaItem]
        /// One group per cluster, keyed by the oldest copy's asset ID.
        let groups: [String: DuplicateGroup]
        /// Copies shown inside a group instead of as encounters of their own.
        let nonRepresentatives: Set<String>
    }

    static func fold(items: [MediaItem], library: ClassifiedLibrary) -> Result {
        var typed = items
        var indexByID: [String: Int] = [:]
        for index in typed.indices { indexByID[typed[index].id] = index }

        // The classifier gives every solo item its own verdict and each cluster's oldest copy the
        // cluster's verdict.
        for index in typed.indices {
            if let verdict = library.classifications[typed[index].id] {
                typed[index].classification = verdict
                typed[index].monsterType = verdict.monsterType
            }
        }

        var groups: [String: DuplicateGroup] = [:]
        var nonRepresentatives = Set<String>()
        for cluster in library.clusters where cluster.memberIDs.count >= 2 {
            let present = cluster.memberIDs.compactMap { indexByID[$0] }
            guard let first = present.first else { continue }
            let representative = typed[first]

            // The other copies take the representative's verdict.
            for index in present.dropFirst() {
                typed[index].classification = representative.classification
                typed[index].monsterType = representative.monsterType
            }
            groups[representative.id] = DuplicateGroup(
                representativeID: representative.id,
                members: present.map { typed[$0] },
                survivorID: library.recommendedSurvivorIDs[representative.id]
            )
            nonRepresentatives.formUnion(cluster.memberIDs.dropFirst())
        }
        return Result(items: typed, groups: groups, nonRepresentatives: nonRepresentatives)
    }
}
