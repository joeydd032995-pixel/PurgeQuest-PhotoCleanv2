//
//  GemCounterView.swift
//  PurgeQuest
//

import SwiftUI

struct GemCounterView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "diamond.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.gemEmerald)
            Text("\(count)")
                .font(.callout.weight(.bold).monospacedDigit())
                .foregroundStyle(.textPrimary)
                .contentTransition(.numericText(value: Double(count)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DungeonPanelBackground(cornerRadius: DungeonRadius.chip, accent: .gemEmerald, elevated: false))
    }
}

struct StatTile: View {
    let icon: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DungeonPanelBackground())
    }
}
