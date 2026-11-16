//
//  DecisionHistory.swift
//  PurgeQuest
//
//  The rule behind Undo (sub-plan 1.2): the player can rewind ONE decision, for five seconds. Pure and
//  Foundation only, so the Linux harness checks the window and the one-step rule with an injected clock
//  (tools/swift_harness/run.sh); CombatViewModel does the actual rewinding.
//
//  Undo is a snapshot, not an inverse. Each decision records what it overwrote, and undo puts exactly that
//  back, so it stays correct whatever the combo formula becomes.
//

import Foundation

/// The dive state one decision overwrites. The multiplier is held in tenths and rebuilt with
/// `ComboMultiplier(tenths:)`.
nonisolated struct DecisionSnapshot: Equatable, Sendable {
    var combo: Int
    var peakCombo: Int
    var multiplierTenths: Int
    var perfectRoom: Bool
    var heroHighestCombo: Int
}

/// The most recent decision of the current room, and whether it can still be undone.
nonisolated struct DecisionHistory: Sendable {

    enum Kind: Equatable, Sendable {
        case delete
        case keep
        /// A duplicate group's per-copy decisions, committed together: one undoable step.
        case group
    }

    struct Entry: Equatable, Sendable {
        let kind: Kind
        /// The item the decision was about, or every copy of a group.
        let itemIDs: [String]
        /// What the decision overwrote.
        let before: DecisionSnapshot
        /// The assets whose saved "kept" record this decision inserted, so undo can delete exactly those.
        let keptRecordIDs: [String]
        let recordedAt: Date
    }

    /// Only the last decision is held: undo never reaches two steps back.
    private(set) var last: Entry?

    /// A new decision replaces whatever could have been undone.
    mutating func record(_ entry: Entry) {
        last = entry
    }

    /// Whether the last decision is still inside the window. Exactly at the window still counts.
    func canUndo(now: Date, window: TimeInterval = DiveRules.undoWindowSeconds) -> Bool {
        guard let last else { return false }
        return now.timeIntervalSince(last.recordedAt) <= window
    }

    /// Takes the last decision back out, if it can still be undone. A second call returns nil.
    mutating func undoLast(now: Date, window: TimeInterval = DiveRules.undoWindowSeconds) -> Entry? {
        guard canUndo(now: now, window: window), let entry = last else { return nil }
        last = nil
        return entry
    }

    /// A new room starts with nothing to undo.
    mutating func clear() {
        last = nil
    }
}
