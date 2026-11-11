//
//  DungeonChips.swift
//  PurgeQuest
//
//  Small inline badges shared by the Library and Hero screens.
//

import SwiftUI

/// The hero's level, as a gold-tinted capsule.
struct LevelChip: View {
    let level: Int

    var body: some View {
        Text("LV \(level)")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(.questAmber)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.questAmber.opacity(0.16)))
            .overlay(Capsule().strokeBorder(Color.questAmber.opacity(0.45), lineWidth: 1))
            .accessibilityLabel("Level \(level)")
    }
}

/// The daily streak: a flame and a count.
struct StreakChip: View {
    let days: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.combatCrimson)
            Text("\(days)")
                .font(.callout.weight(.bold).monospacedDigit())
                .foregroundStyle(.textPrimary)
                .contentTransition(.numericText(value: Double(days)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DungeonPanelBackground(cornerRadius: DungeonRadius.chip, accent: .combatCrimson, elevated: false))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days) day streak")
    }
}
