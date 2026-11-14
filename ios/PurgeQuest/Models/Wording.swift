//
//  Wording.swift
//  PurgeQuest
//
//  Small phrases that screens build out of a number, so each one is right at 0, 1 and many and says
//  the same thing wherever it appears. Foundation only, so the Linux harness checks them
//  (tools/swift_harness/run.sh).
//

import Foundation

nonisolated enum Wording {

    /// "1 day", "2 days". The Settings screen once said "1 days".
    static func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    /// What is still missing before something can be bought: "150 more gems". Never "+150 gems", which
    /// reads as a gain.
    static func moreGems(_ count: Int) -> String {
        count == 1 ? "1 more gem" : "\(count) more gems"
    }

    /// A streak of deletions without a keep. It is a count, not a multiplier, so it is "20 in a row"
    /// and never "20×" (the combo's multiplier tops out at ×2, which "20×" would contradict).
    static func inARow(_ count: Int) -> String {
        count > 0 ? "\(count) in a row" : "None yet"
    }

    /// The Room Summary's commit button: it says how many and where. "Confirm Purge" said neither.
    static func moveToRecentlyDeleted(_ count: Int) -> String {
        "Move \(count) to Recently Deleted"
    }

    /// Under the commit button: what it moves, and that it can be undone.
    static func recoverableNote(size: String) -> String {
        "\(size) · recoverable for 30 days"
    }

    /// The Room Summary's subtitle: "12 marked, 8 kept", "12 marked", "Nothing marked, 20 kept".
    static func roomVerdict(marked: Int, kept: Int) -> String {
        if marked <= 0 { return kept > 0 ? "Nothing marked, \(kept) kept" : "Nothing marked" }
        return kept > 0 ? "\(marked) marked, \(kept) kept" : "\(marked) marked"
    }
}
