//
//  GlossaryTests.swift
//  PurgeQuestTests
//
//  The four game words a first-time player meets and the plain sentence each one gets (Glossary.swift),
//  and the ledger that explains each word once. Foundation only, so these run in Xcode and in the Linux
//  harness (tools/swift_harness/run.sh).
//

import Testing
import Foundation
@testable import PurgeQuest

struct GlossaryTests {

    // MARK: The sentences

    // Appendix B, with two owner-approved corrections (15 November 2026): a room is "up to 20" (a library of 19 items
    // shows "16 left" beside it), and a Shade can be a video too.
    @Test func theSentencesAreAppendixBAsCorrected() {
        #expect(Glossary.sentence(.dive)  == "Dive: one session of up to five rooms.")
        #expect(Glossary.sentence(.room)  == "Room: up to 20 items.")
        #expect(Glossary.sentence(.elite) == "Elite: a boss-tier monster that pays more.")
        #expect(Glossary.sentence(.shade) == "Shade: a photo or video you deleted before; deleting it again pays nothing.")
    }

    @Test func everyTermIsNamedAndExplained() {
        #expect(Glossary.Term.allCases.count == 4)
        for term in Glossary.Term.allCases {
            #expect(!Glossary.name(term).isEmpty)
            #expect(!Glossary.gloss(term).isEmpty)
            #expect(Glossary.sentence(term).hasPrefix("\(Glossary.name(term)): "))
            #expect(Glossary.sentence(term).hasSuffix("."))
        }
    }

    @Test func aGlossNeverUsesTheWordItExplains() {
        for term in Glossary.Term.allCases {
            #expect(!Glossary.gloss(term).lowercased().contains(Glossary.name(term).lowercased()),
                    "the gloss for \(term) uses the word it is explaining")
        }
    }

    @Test func theShapeOfADiveIsTheOneTheGameUses() {
        #expect(Glossary.itemsPerRoom == 20)
        #expect(Glossary.maxRoomsPerDive == 5)
    }

    // MARK: The ledger

    @Test func aNewLedgerHasExplainedNothing() {
        let ledger = GlossaryLedger()
        for term in Glossary.Term.allCases { #expect(!ledger.hasSeen(term)) }
        #expect(ledger.storedValue.isEmpty)
    }

    @Test func aTermIsExplainedOnceAndThenNeverAgain() {
        var ledger = GlossaryLedger()
        #expect(ledger.nextTip(among: [.elite]) == .elite)
        ledger.markSeen(.elite)
        #expect(ledger.hasSeen(.elite))
        #expect(ledger.nextTip(among: [.elite]) == nil)
        ledger.markSeen(.elite)   // marking twice changes nothing
        #expect(ledger.storedValue == ["elite"])
    }

    @Test func theCallersOrderIsThePriorityAndOnlyOneTipShowsAtATime() {
        var ledger = GlossaryLedger()
        let visible: [Glossary.Term] = [.room, .elite, .shade]
        #expect(ledger.nextTip(among: visible) == .room)
        ledger.markSeen(.room)
        #expect(ledger.nextTip(among: visible) == .elite)
        ledger.markSeen(.elite)
        #expect(ledger.nextTip(among: visible) == .shade)
        ledger.markSeen(.shade)
        #expect(ledger.nextTip(among: visible) == nil)
    }

    @Test func onlyAWordThatIsOnScreenCanBeOffered() {
        let ledger = GlossaryLedger()
        #expect(ledger.nextTip(among: []) == nil)
        #expect(ledger.nextTip(among: [.room]) == .room)
    }

    @Test func theLedgerSurvivesBeingSavedAndRestored() {
        var ledger = GlossaryLedger()
        ledger.markSeen(.shade)
        ledger.markSeen(.dive)
        #expect(ledger.storedValue == ["dive", "shade"], "stored sorted, so the value is stable")
        #expect(GlossaryLedger(storedValue: ledger.storedValue) == ledger)
    }

    @Test func aWordThisBuildDoesNotKnowIsIgnoredNotACrash() {
        let ledger = GlossaryLedger(storedValue: ["elite", "someFutureWord", ""])
        #expect(ledger.seen == [.elite])
    }

    // MARK: Persistence

    @Test func theStoreRoundTripsThroughUserDefaultsAndCanBeCleared() throws {
        let suite = "GlossaryTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(GlossaryStore.load(from: defaults) == GlossaryLedger(), "a first launch has explained nothing")

        var ledger = GlossaryLedger()
        ledger.markSeen(.room)
        GlossaryStore.save(ledger, to: defaults)
        #expect(GlossaryStore.load(from: defaults) == ledger)

        GlossaryStore.clear(in: defaults)
        #expect(GlossaryStore.load(from: defaults) == GlossaryLedger(), "Reset all data starts the words over")
    }

    @Test func markingOneWordKeepsTheWordsAnotherScreenSaved() throws {
        let suite = "GlossaryTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        // The Library loaded its copy before any dive: nothing explained yet.
        let stale = GlossaryStore.load(from: defaults)
        #expect(stale.seen.isEmpty)

        // A dive then explained two words and saved them.
        GlossaryStore.markSeen(.room, in: defaults)
        GlossaryStore.markSeen(.elite, in: defaults)

        // Explaining "dive" reads the store first, so the dive's words survive.
        let saved = GlossaryStore.markSeen(.dive, in: defaults)
        #expect(saved.seen == [.room, .elite, .dive])
        #expect(GlossaryStore.load(from: defaults) == saved)

        // What saving the Library's stale copy would have stored instead: the dive's words are gone.
        var oldWay = stale
        oldWay.markSeen(.dive)
        #expect(oldWay.seen == [.dive], "saving a stale copy would have forgotten the dive's words")
    }
}
