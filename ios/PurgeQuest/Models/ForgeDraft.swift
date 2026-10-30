//
//  ForgeDraft.swift
//  PurgeQuest
//
//  Pure logic behind the Hero Forge so it can be unit-tested without UI or
//  SwiftData: the editable draft (appearance + equipment), the atomic save
//  with rollback and a surfaced error, the ancestry-change choices, and
//  held-gear compatibility. Nothing here touches persistence directly.
//

import Foundation

/// Everything the Forge edits before Save. Cancel simply drops the draft.
nonisolated struct ForgeDraft: Equatable, Sendable {
    var appearance: HeroAppearance
    /// Cosmetic slot raw value ("weapon", "shield", "head", ...) -> equipped item id. Absent = nothing equipped.
    var equipped: [String: String]

    func isDirty(comparedTo original: ForgeDraft) -> Bool { self != original }

    mutating func equip(_ itemID: String?, slot: String) {
        if let itemID { equipped[slot] = itemID } else { equipped.removeValue(forKey: slot) }
    }
}

nonisolated enum ForgeSaveOutcome: Equatable, Sendable {
    case saved
    case failed(message: String)
}

nonisolated enum ForgeSaveCoordinator {
    /// Applies the draft to the live models, persists, and restores the previous state if persisting throws.
    /// The caller dismisses the Forge only for `.saved`; a failure keeps it open with the message shown.
    static func commit(apply: () -> Void, persist: () throws -> Void, rollback: () -> Void) -> ForgeSaveOutcome {
        apply()
        do {
            try persist()
            return .saved
        } catch {
            rollback()
            return .failed(message: error.localizedDescription)
        }
    }
}

nonisolated enum AncestryChoice: String, CaseIterable, Sendable {
    case wholeLook
    case anatomyOnly
    case cancel
}

nonisolated enum AncestryChange {
    /// True when switching ancestry would discard something the player customised.
    static func hasCustomization(_ draft: HeroAppearance, currentRace: HeroRace) -> Bool {
        draft != HeroAppearance.default(for: currentRace)
    }

    /// Whole look adopts the new ancestry's designed default. Anatomy only changes race and paint
    /// variant but keeps face traits, hue shifts, dyes, and material colours. Cancel changes nothing.
    static func apply(_ choice: AncestryChoice, to draft: HeroAppearance, newRace: HeroRace) -> HeroAppearance {
        switch choice {
        case .cancel:
            return draft
        case .wholeLook:
            return HeroAppearance.default(for: newRace)
        case .anatomyOnly:
            var look = draft
            look.race = newRace
            look.paintVariant = min(max(draft.paintVariant, 1), newRace.variantCount)
            return look
        }
    }
}

nonisolated enum GearCompatibility {
    /// Art pack id for a race/variant, matching the manifest's pack ids ("forest_ranger_v1", "skeleton_warrior_v2").
    static func packID(race: HeroRace, variant: Int) -> String {
        race.artBase(variant: variant)
    }

    static func isSupported(_ item: HeldGearEntry, race: HeroRace, variant: Int) -> Bool {
        item.supportedPacks.contains(packID(race: race, variant: variant))
    }
}
