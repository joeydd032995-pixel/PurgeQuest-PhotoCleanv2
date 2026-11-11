//
//  XPBarView.swift
//  PurgeQuest
//
//  The XP and HP bars, drawn with DungeonProgressBar. Motion is limited to a spring fill
//  when the value actually changes.
//

import SwiftUI

struct XPBarView: View {
    let progress: Double          // 0...1
    let level: Int
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !compact {
                HStack {
                    Text("LV \(level)")
                        .font(.dungeonCaption.weight(.bold))
                        .foregroundStyle(.questAmber)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.textSecondary)
                }
            }
            DungeonProgressBar(value: progress, tint: .questAmber, height: compact ? 6 : 10)
        }
    }
}

struct HPBarView: View {
    let current: Int
    let max: Int
    var label: String = "HP"

    private var fraction: Double {
        guard max > 0 else { return 0 }
        return Double(current) / Double(max)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.combatCrimson)
                Text("\(label)  \(current)/\(max)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            DungeonProgressBar(value: fraction, tint: .combatCrimson, height: 8)
        }
    }
}
