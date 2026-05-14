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
                .foregroundStyle(LinearGradient.emeraldGlow)
                .shadow(color: .gemEmerald.opacity(0.7), radius: 4)
            Text("\(count)")
                .font(.callout.weight(.bold).monospacedDigit())
                .foregroundStyle(.textPrimary)
                .contentTransition(.numericText(value: Double(count)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.dungeonStone)
                .overlay(Capsule().stroke(Color.gemEmerald.opacity(0.4), lineWidth: 1))
        )
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
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.dungeonStone)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.dungeonAsh, lineWidth: 1)
                )
        )
    }
}
