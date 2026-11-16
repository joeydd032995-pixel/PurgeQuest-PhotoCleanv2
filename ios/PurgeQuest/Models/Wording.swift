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

    // MARK: Undo

    /// The Undo pill: what it takes back.
    static func undo(_ kind: DecisionHistory.Kind) -> String {
        switch kind {
        case .delete: return "Undo delete"
        case .keep:   return "Undo keep"
        case .group:  return "Undo choices"
        }
    }

    /// What VoiceOver says after the Undo pill's name: what actually happens.
    static func undoHint(_ kind: DecisionHistory.Kind) -> String {
        switch kind {
        case .delete: return "Puts the photo back as the top card."
        case .keep:   return "Puts the photo back as the top card and forgets you kept it."
        case .group:  return "Puts the whole group back as the top card."
        }
    }

    /// Announced when the pill appears, so a VoiceOver user knows there is a way back and for how long.
    static func undoAvailable(seconds: Int) -> String {
        seconds == 1 ? "Undo available for 1 second" : "Undo available for \(seconds) seconds"
    }

    /// The wait while the library is read. The count is how many items this dive is reading, once it is
    /// known; before that it is the plain "Scanning your library…". It never says anything about monsters.
    static func scanning(count: Int) -> String {
        switch count {
        case ..<1: return "Scanning your library…"
        case 1:    return "Scanning 1 item…"
        default:   return "Scanning \(count) items…"
        }
    }

    // MARK: The card

    /// Under the monster's name on the card: how rare it is and which family it belongs to.
    static func nameplateLine(rarity: String, family: String) -> String {
        "\(rarity) · \(family)"
    }

    /// The glass chip on the photo: how big it is and how old it is.
    static func exhibitChip(size: String, age: String) -> String {
        "\(size) · \(age)"
    }
}
