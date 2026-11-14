//
//  WordingTests.swift
//  PurgeQuestTests
//
//  The phrases screens build from a number (Wording.swift): right at 0, 1 and many. Foundation only,
//  so these run in Xcode and in the Linux harness.
//

import Testing
import Foundation
@testable import PurgeQuest

struct WordingTests {

    @Test func daysAreSingularExactlyAtOne() {
        #expect(Wording.days(0) == "0 days")
        #expect(Wording.days(1) == "1 day")
        #expect(Wording.days(2) == "2 days")
        #expect(Wording.days(365) == "365 days")
    }

    @Test func aShortfallSaysMoreAndNeverLooksLikeAGain() {
        #expect(Wording.moreGems(1) == "1 more gem")
        #expect(Wording.moreGems(150) == "150 more gems")
        for count in [1, 2, 150, 9_999] {
            #expect(!Wording.moreGems(count).contains("+"), "a shortfall must not read as a gain")
        }
    }

    @Test func aStreakOfDeletionsIsACountNeverAMultiplier() {
        #expect(Wording.inARow(0) == "None yet")
        #expect(Wording.inARow(1) == "1 in a row")
        #expect(Wording.inARow(20) == "20 in a row")
        for count in [0, 1, 5, 20, 100] {
            let text = Wording.inARow(count)
            #expect(!text.contains("×") && !text.contains("x"), "\"\(text)\" reads as a multiplier")
        }
    }
}
