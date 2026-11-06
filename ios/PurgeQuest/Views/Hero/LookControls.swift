//
//  LookControls.swift
//  PurgeQuest
//
//  Small pieces shared by the onboarding look page and the Hero Forge so the skin, hair and armor-dye rows
//  behave the same in both: an "As painted" choice that restores the art untouched, and a stated reason when
//  a control has nothing to change on the current paint (see LookCapabilities).
//

import SwiftUI

/// The "As painted" choice of a look swatch row: the art with no colour applied. Selected while no swatch is chosen.
struct AsPaintedChip: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("As painted")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Capsule().fill(isSelected ? Color.questAmber.opacity(0.16) : Color.dungeonStone))
                .overlay(Capsule().stroke(isSelected ? Color.questAmber : Color.dungeonAsh, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("As painted")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Why a look control does nothing on the current paint; empty when the control is available.
struct LookUnavailableNote: View {
    let availability: LookAvailability

    var body: some View {
        if case .unavailable(let reason) = availability {
            Text(reason)
                .font(.caption2)
                .foregroundStyle(.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
