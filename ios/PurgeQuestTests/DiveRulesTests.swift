//
//  DiveRulesTests.swift
//  PurgeQuestTests
//
//  D1 in numbers: keeping a photo is free, and the combo is a smaller reward than it was. These pin
//  the rules in DiveRules.swift. Foundation only, so they run in Xcode and in the Linux harness
//  (tools/swift_harness/run.sh).
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct DiveRulesTests {

    // MARK: Keeping is free

    @Test func keepingAPhotoNeverCostsHP() {
        for monster in MonsterType.allCases {
            #expect(DiveRules.damageForKeeping(monster) == 0, "\(monster) hurts the hero for being kept")
        }
    }

    @Test func theOldDamageIsParkedBehindItsFlagNotDeleted() {
        // Flip the flag and every monster bites for what it always did, so the rule can come back.
        for monster in MonsterType.allCases {
            #expect(monster.attackDamage > 0, "\(monster) has no damage to restore")
            #expect(DiveRules.damageForKeeping(monster, costsHP: true) == monster.attackDamage)
        }
    }

    @Test func theFlagIsOffByDecision() {
        // D1. If this ever needs to be true, the owner has changed the decision, and so does this test.
        #expect(DiveRules.keepingCostsHP == false)
    }

    // MARK: The combo is lesser

    @Test func theComboStepsUpEveryFiveDeletionsAndStopsAtDouble() {
        let expected: [(combo: Int, multiplier: Int)] = [
            (0, 1), (1, 1), (4, 1),   // the first four pay base
            (5, 2), (6, 2), (9, 2),   // the fifth steps up
            (10, 2), (15, 2), (99, 2) // and it stays there; it used to reach 3 at ten
        ]
        for (combo, multiplier) in expected {
            #expect(DiveRules.comboMultiplier(forCombo: combo) == multiplier, "combo \(combo)")
        }
    }

    @Test func noStreakEverPaysMoreThanDouble() {
        #expect(DiveRules.maxComboMultiplier == 2)
        for combo in 0...500 {
            let multiplier = DiveRules.comboMultiplier(forCombo: combo)
            #expect((1...DiveRules.maxComboMultiplier).contains(multiplier), "combo \(combo) pays ×\(multiplier)")
        }
    }

    @Test func aLongerStreakNeverPaysLess() {
        var previous = 0
        for combo in 0...200 {
            let multiplier = DiveRules.comboMultiplier(forCombo: combo)
            #expect(multiplier >= previous, "combo \(combo) pays less than combo \(combo - 1)")
            previous = multiplier
        }
    }

    @Test func aStreakThatIsNotOneIsWorthNothingExtra() {
        #expect(DiveRules.comboMultiplier(forCombo: -1) == 1)
        #expect(DiveRules.comboMultiplier(forCombo: -50) == 1)
    }
}
