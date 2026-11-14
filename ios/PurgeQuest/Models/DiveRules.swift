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
//  The combo rule (owner, 14 November 2026): the multiplier rises a tenth per deletion from ×1.0 to
//  ×2.0, and keeping a photo takes 12% of it instead of ending it. A careful keep costs a little; it no
//  longer erases the streak that built the bonus.
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
}

/// How much a reward is multiplied by the run of deletions behind it.
///
/// Kept in tenths, not as a `Double`, so the cap is exactly ×2.0, ten deletions reach it exactly, and
/// nothing drifts over a long dive. The streak itself (how many deletions in a row) is a separate count
/// in CombatViewModel that still ends on a keep, so "20 in a row" and Combo King mean what they say.
struct ComboMultiplier: Equatable, Sendable {

    /// ×1.0: plain rewards. A run starts here and a keep never takes it lower.
    static let floorTenths = 10

    /// ×2.0. D1 lowered the top from ×3.
    static let capTenths = 20

    /// A deletion adds a tenth, so ten of them take ×1.0 to ×2.0.
    static let gainPerDeletionTenths = 1

    /// What a keep leaves of the multiplier, as a percentage: it takes 12%.
    static let keptPercentAfterAKeep = 88

    /// The multiplier in tenths: 10 is ×1.0, 18 is ×1.8, 20 is ×2.0.
    private(set) var tenths: Int

    /// Out-of-range values are clamped into ×1.0 to ×2.0.
    init(tenths: Int = ComboMultiplier.floorTenths) {
        self.tenths = min(max(tenths, Self.floorTenths), Self.capTenths)
    }

    var value: Double { Double(tenths) / 10 }

    /// A deletion that earns a reward. A shade (a photo deleted before) earns nothing and does not call this.
    mutating func afterDeletion() {
        tenths = min(Self.capTenths, tenths + Self.gainPerDeletionTenths)
    }

    /// Keeping a photo takes 12% of the multiplier, to the nearest tenth, never below ×1.0.
    mutating func afterKeep() {
        let kept = (tenths * Self.keptPercentAfterAKeep + 50) / 100
        tenths = max(Self.floorTenths, kept)
    }

    /// What the multiplier would be after this many more deletions, without moving the real one. The
    /// reward chips on the cards look ahead with this.
    func afterDeletions(_ count: Int) -> ComboMultiplier {
        let steps = min(max(count, 0), Self.capTenths)
        return ComboMultiplier(tenths: tenths + steps * Self.gainPerDeletionTenths)
    }

    /// A whole reward (XP or gems) multiplied, to the nearest whole number with halves rounding up. At ×1.0
    /// and ×2.0 it is exactly the base and double the base, as before.
    func scaled(_ amount: Int) -> Int {
        (amount * tenths + 5) / 10
    }

    /// "1.8": what VoiceOver says after "rewards times".
    var plain: String { "\(tenths / 10).\(tenths % 10)" }

    /// "×1.8": always one decimal, because it only ever moves in tenths.
    var display: String { "×" + plain }
}
