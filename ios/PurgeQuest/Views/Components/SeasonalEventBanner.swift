//
//  SeasonalEventBanner.swift
//  PurgeQuest
//
//  Static framed event banner. No shimmer, no pulsing symbols.
//

import SwiftUI

struct SeasonalEventBanner: View {
    let event: SeasonalEvent

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: event.symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(event.primary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(event.primary.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(event.primary.opacity(0.5), lineWidth: 1))
                )

            VStack(alignment: .leading, spacing: 4) {
                // On its own line: beside the title it squeezed both into two-line wraps next to the art.
                // Primary text on the event tint, not the event hue, which measured under 4.5:1 there.
                Text("LIMITED EVENT")
                    .font(.dungeonCaption)
                    .tracking(0.8)
                    .lineLimit(1)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(event.primary.opacity(0.18)))
                    .foregroundStyle(.textPrimary)
                Text(event.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                Text(event.tagline)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if !event.decor.isEmpty {
                // Still frames: the banner stays static by design.
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(event.decor, id: \.asset) { sheet in
                        SpriteSheetView(sheet: sheet, height: 30, animated: false)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonStone)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(event.primary.opacity(0.5), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(event.primary.opacity(0.25), lineWidth: 1)
                        .padding(2)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.name). \(event.tagline)")
    }
}
