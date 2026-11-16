//
//  CoachMark.swift
//  PurgeQuest
//
//  The two arrows on the very first card ("Swipe left to delete", "Swipe right to keep") and the rule for when
//  they show (sub-plan 1.2, task 6). They are shown once: the flag is saved, so they never return after the first
//  card has been decided or touched, and "Reset all PurgeQuest data" starts them over with the rest of the
//  player's progress. Every other note waits for them: the card never carries two notes at once. Foundation only,
//  so the Linux harness checks it.
//

import Foundation

nonisolated enum CoachMark {

    /// Whether the arrows show on this card: only on the first card of the first room, and only until they have
    /// been seen.
    static func shows(isFirstCardOfDive: Bool, seen: Bool) -> Bool {
        isFirstCardOfDive && !seen
    }

    /// Whether a game-word note (the Room note, "Elite", "Shade") may show on this card. Notes wait while the arrows
    /// are up and come on the next card, so a first-time player is given one thing at a time.
    static func notesMayShow(arrowsShowing: Bool) -> Bool {
        !arrowsShowing
    }

    static let swipeLeftLabel = "Swipe left to delete"
    static let swipeRightLabel = "Swipe right to keep"
}

/// Where the "seen" flag lives: `UserDefaults`, under one key, like the glossary ledger.
nonisolated enum CoachMarkStore {
    static let key = "pq.coachmark.swipe.seen"

    static func hasSeen(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func markSeen(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
