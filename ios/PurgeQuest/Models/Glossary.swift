//
//  Glossary.swift
//  PurgeQuest
//
//  The four game words a first-time player meets before anything explains them, each with the plain
//  sentence that goes with it (docs/design/UI_ASSESSMENT.md, Appendix B), and the ledger that remembers
//  which ones have been explained so each is explained once. Foundation only, so the Linux harness
//  checks it (tools/swift_harness/run.sh).
//

import Foundation

nonisolated enum Glossary {

    enum Term: String, CaseIterable, Sendable {
        case dive, room, elite, shade
    }

    /// A room is this many items. CombatViewModel's `roomSize` must agree (GlossaryAppConstantsTests).
    static let itemsPerRoom = 20

    /// A dive is up to this many rooms. CombatViewModel's `totalRoomsPerSession` must agree.
    static let maxRoomsPerDive = 5

    /// The word as the player sees it on screen.
    static func name(_ term: Term) -> String {
        switch term {
        case .dive:  return "Dive"
        case .room:  return "Room"
        case .elite: return "Elite"
        case .shade: return "Shade"
        }
    }

    /// The plain meaning, without the word it explains.
    static func gloss(_ term: Term) -> String {
        switch term {
        case .dive:  return "one session of up to \(spelled(maxRoomsPerDive)) rooms"
        case .room:  return "up to \(itemsPerRoom) items"
        case .elite: return "a boss-tier monster that pays more"
        case .shade: return "a photo or video you deleted before; deleting it again pays nothing"
        }
    }

    /// The sentence a player reads: "Dive: one session of up to five rooms."
    static func sentence(_ term: Term) -> String {
        "\(name(term)): \(gloss(term))."
    }

    /// 0 to 10 in words, for prose ("up to five rooms"); anything larger stays digits.
    private static func spelled(_ number: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return words.indices.contains(number) ? words[number] : String(number)
    }
}

/// Which words have been explained. A word is explained the first time it is on screen, then never again.
nonisolated struct GlossaryLedger: Equatable, Sendable {

    private(set) var seen: Set<Glossary.Term>

    init(seen: Set<Glossary.Term> = []) {
        self.seen = seen
    }

    /// Restores a ledger saved as raw values. Anything this build does not know is ignored, so a ledger
    /// written by a newer build never crashes an older one.
    init(storedValue: [String]) {
        self.seen = Set(storedValue.compactMap(Glossary.Term.init(rawValue:)))
    }

    /// What to save: sorted, so the stored value is stable.
    var storedValue: [String] {
        seen.map(\.rawValue).sorted()
    }

    func hasSeen(_ term: Glossary.Term) -> Bool {
        seen.contains(term)
    }

    mutating func markSeen(_ term: Glossary.Term) {
        seen.insert(term)
    }

    /// The word to explain now: the first of `visible` that has not been explained. The caller's order is
    /// the priority, and only one word is offered at a time, so two notes never stack.
    func nextTip(among visible: [Glossary.Term]) -> Glossary.Term? {
        visible.first { !seen.contains($0) }
    }
}

/// Where the ledger lives: `UserDefaults`, under one key, so it survives launches and is wiped by
/// "Reset all PurgeQuest data" with the rest of the player's progress.
nonisolated enum GlossaryStore {
    static let key = "pq.glossary.seen"

    static func load(from defaults: UserDefaults = .standard) -> GlossaryLedger {
        GlossaryLedger(storedValue: defaults.stringArray(forKey: key) ?? [])
    }

    static func save(_ ledger: GlossaryLedger, to defaults: UserDefaults = .standard) {
        defaults.set(ledger.storedValue, forKey: key)
    }

    /// Marks one word explained and saves it, reading the stored ledger first so a word another screen
    /// saved since this one loaded is never lost. Returns the ledger as saved.
    @discardableResult
    static func markSeen(_ term: Glossary.Term, in defaults: UserDefaults = .standard) -> GlossaryLedger {
        var ledger = load(from: defaults)
        ledger.markSeen(term)
        save(ledger, to: defaults)
        return ledger
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
