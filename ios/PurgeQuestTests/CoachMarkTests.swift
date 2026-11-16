import Testing
import Foundation
@testable import PurgeQuest

@Suite struct CoachMarkTests {

    @Test func theArrowsShowOnTheFirstCardUntilSeen() {
        #expect(CoachMark.shows(isFirstCardOfDive: true, seen: false))
        #expect(!CoachMark.shows(isFirstCardOfDive: true, seen: true), "never again once seen")
        #expect(!CoachMark.shows(isFirstCardOfDive: false, seen: false), "only on the very first card")
        #expect(!CoachMark.shows(isFirstCardOfDive: false, seen: true))
    }

    @Test func everyOtherNoteWaitsForTheArrows() {
        #expect(!CoachMark.notesMayShow(arrowsShowing: true), "never two notes on one card")
        #expect(CoachMark.notesMayShow(arrowsShowing: false))
    }

    @Test func aFirstTimePlayerSeesTheArrowsThenTheRoomNoteThenNeitherAgain() {
        // Card one: the arrows, no Room note.
        var seen = false
        let cardOneArrows = CoachMark.shows(isFirstCardOfDive: true, seen: seen)
        #expect(cardOneArrows)
        #expect(!CoachMark.notesMayShow(arrowsShowing: cardOneArrows))
        // The first decision marks the arrows seen. Card two: the Room note, no arrows.
        seen = true
        let cardTwoArrows = CoachMark.shows(isFirstCardOfDive: false, seen: seen)
        #expect(!cardTwoArrows)
        #expect(CoachMark.notesMayShow(arrowsShowing: cardTwoArrows))
    }

    @Test func theLabelsNameTheDirectionAndWhatItDoes() {
        #expect(CoachMark.swipeLeftLabel == "Swipe left to delete")
        #expect(CoachMark.swipeRightLabel == "Swipe right to keep")
    }

    @Test func theFlagIsSavedAndClearedLikeTheRestOfTheProgress() throws {
        let suite = "CoachMarkTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(!CoachMarkStore.hasSeen(in: defaults), "a first launch has seen nothing")
        CoachMarkStore.markSeen(in: defaults)
        #expect(CoachMarkStore.hasSeen(in: defaults))
        CoachMarkStore.clear(in: defaults)
        #expect(!CoachMarkStore.hasSeen(in: defaults), "Reset all data starts the arrows over")
    }
}
