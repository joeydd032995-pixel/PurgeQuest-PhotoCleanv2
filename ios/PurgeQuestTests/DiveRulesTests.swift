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

    @Test func aRunStartsAtPlainRewards() {
        let combo = ComboMultiplier()
        #expect(combo.tenths == 10)
        #expect(combo.value == 1.0)
        #expect(combo.display == "×1.0")
    }

    @Test func everyDeletionAddsATenthAndTheTenthReachesDouble() {
        var combo = ComboMultiplier()
        for deletion in 1...10 {
            combo.afterDeletion()
            #expect(combo.tenths == 10 + deletion, "deletion \(deletion)")
        }
        #expect(combo.value == 2.0, "the tenth deletion reaches ×2.0")
    }

    @Test func noStreakEverPaysMoreThanDouble() {
        // D1: it used to reach ×3.
        var combo = ComboMultiplier()
        for deletion in 1...500 {
            combo.afterDeletion()
            #expect(combo.tenths <= ComboMultiplier.capTenths, "deletion \(deletion) pays ×\(combo.value)")
        }
        #expect(ComboMultiplier.capTenths == 20)
        #expect(combo.display == "×2.0")
    }

    @Test func aKeepTakesTwelvePercentRoundedToTheNearestTenth() {
        // (before, after) in tenths: ×2.0 becomes ×1.8, ×1.5 becomes ×1.3, and so on.
        let expected: [(before: Int, after: Int)] = [
            (20, 18), (19, 17), (18, 16), (17, 15), (16, 14), (15, 13),
            (14, 12), (13, 11), (12, 11), (11, 10), (10, 10)
        ]
        for (before, after) in expected {
            var combo = ComboMultiplier(tenths: before)
            combo.afterKeep()
            #expect(combo.tenths == after, "×\(Double(before) / 10) after a keep")
        }
    }

    @Test func aKeepNeverRaisesAndNeverGoesBelowPlainRewards() {
        for tenths in ComboMultiplier.floorTenths...ComboMultiplier.capTenths {
            var combo = ComboMultiplier(tenths: tenths)
            combo.afterKeep()
            #expect(combo.tenths <= tenths, "a keep raised ×\(Double(tenths) / 10)")
            #expect(combo.tenths >= ComboMultiplier.floorTenths, "a keep took ×\(Double(tenths) / 10) below ×1.0")
        }
        var combo = ComboMultiplier(tenths: ComboMultiplier.capTenths)
        for _ in 1...100 { combo.afterKeep() }
        #expect(combo.tenths == ComboMultiplier.floorTenths, "keeping over and over bottoms out at ×1.0")
    }

    @Test func oneKeepDoesNotEraseTheStreakThatBuiltTheCombo() {
        // The point of the rule: a careful keep costs a little, not everything.
        var combo = ComboMultiplier()
        for _ in 1...10 { combo.afterDeletion() }
        combo.afterKeep()
        #expect(combo.tenths == 18)
        combo.afterDeletion()
        #expect(combo.tenths == 19)
    }

    @Test func aScaledRewardIsExactlyTheOldOneAtTheEnds() {
        // ×1.0 pays base and ×2.0 pays double, as before; in between it rounds to the nearest whole number.
        #expect(ComboMultiplier(tenths: 10).scaled(78) == 78)
        #expect(ComboMultiplier(tenths: 20).scaled(78) == 156)
        #expect(ComboMultiplier(tenths: 15).scaled(3) == 5, "4.5 rounds up")
        #expect(ComboMultiplier(tenths: 12).scaled(3) == 4, "3.6 rounds to 4")
        #expect(ComboMultiplier(tenths: 14).scaled(0) == 0)
    }

    @Test func aPreviewLooksAheadWithoutMovingTheRealCombo() {
        let combo = ComboMultiplier()
        #expect(combo.afterDeletions(3).tenths == 13)
        #expect(combo.afterDeletions(0).tenths == 10)
        #expect(combo.afterDeletions(99).tenths == ComboMultiplier.capTenths)
        #expect(combo.tenths == 10, "looking ahead must not move the real combo")
    }

    @Test func aValueOutsideTheRangeIsClamped() {
        #expect(ComboMultiplier(tenths: 5).tenths == 10)
        #expect(ComboMultiplier(tenths: 99).tenths == 20)
        #expect(ComboMultiplier(tenths: -3).tenths == 10)
    }

    @Test func itIsShownWithATimesSignAndSpokenWithout() {
        #expect(ComboMultiplier(tenths: 18).display == "×1.8")
        #expect(ComboMultiplier(tenths: 18).plain == "1.8")
        #expect(ComboMultiplier(tenths: 20).plain == "2.0")
    }

    // MARK: Gems

    @Test func aPhotoPaysTwoGemsAndAVideoThree() {
        #expect(DiveRules.gemsForDeleting(isVideo: false) == 2)
        #expect(DiveRules.gemsForDeleting(isVideo: true) == 3)
    }
}
