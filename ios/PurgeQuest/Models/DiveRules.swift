//
//  DiveRules.swift
//  PurgeQuest
//
//  The arithmetic of a dive that the owner's decisions fix: what keeping a photo costs, and how far
//  a run of deletions can multiply a reward. Foundation only, so the Linux harness checks it
//  (tools/swift_harness/run.sh), and CombatViewModel, the HUD and the reward chips all read this one
//  source instead of each carrying a copy of the formula.
//
//  D1 (14 November 2026, docs/design/UI_ASSESSMENT.md section 1): keeping a photo is free. It costs
//  no HP, so being careful with your own photos is never punished. With that pressure gone the combo
//  has less to prove, so it pays less: it tops out at ×2, where it used to reach ×3.
//

import Foundation

enum DiveRules {

    // MARK: Keeping

    /// Whether keeping a photo (swiping it away from deletion) hurts the hero. D1 says no. The damage,
    /// defeat and Rally code stays in CombatViewModel behind this one flag until the owner decides to
    /// delete it, so turning the old rule back on is a one-word change.
    static let keepingCostsHP = false

    /// The HP a keep takes from the hero. Nothing, while `keepingCostsHP` is off.
    static func damageForKeeping(_ monster: MonsterType, costsHP: Bool = DiveRules.keepingCostsHP) -> Int {
        costsHP ? monster.attackDamage : 0
    }

    // MARK: Combo

    /// Every this many deletions in a row, the streak steps up one multiplier.
    static let deletionsPerComboStep = 5

    /// The most a streak can multiply a reward. D1 lowered it from 3.
    static let maxComboMultiplier = 2

    /// The multiplier a deletion earns when it makes the streak `combo` long: ×1 for the first four,
    /// ×2 from the fifth, never more than `maxComboMultiplier`, and ×1 for a streak that is not one.
    static func comboMultiplier(forCombo combo: Int) -> Int {
        max(1, min(combo / deletionsPerComboStep + 1, maxComboMultiplier))
    }
}
