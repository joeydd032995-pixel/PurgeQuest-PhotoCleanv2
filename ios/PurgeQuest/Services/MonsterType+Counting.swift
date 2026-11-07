//
//  MonsterType+Counting.swift
//  PurgeQuest
//
//  Which slain monsters count toward a quest or achievement written for a given monster.
//

import Foundation

extension MonsterType {

    /// True when slaying `self` counts toward content written for `target`.
    ///
    /// The Duplicate Dragon quest and achievement were written when the Duplicate Dragon was the
    /// only duplicate monster. The roster has since split duplicates into eight (pairs, bursts,
    /// edited copies, hoards, ...), and most real duplicate groups are one of the others, so content
    /// that names the Duplicate Dragon counts the whole Duplicate Dragons family. Every other
    /// target still means exactly that one monster.
    func counts(as target: MonsterType) -> Bool {
        self == target || (target == .duplicateDragon && family == .duplicateDragons)
    }
}
