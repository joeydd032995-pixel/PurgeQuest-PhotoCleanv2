//
//  XPBarView.swift
//  PurgeQuest
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
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.questAmber)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.textSecondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.dungeonStone)
                        .overlay(Capsule().stroke(Color.dungeonAsh, lineWidth: 1))
                    Capsule()
                        .fill(LinearGradient.amberGlow)
                        .frame(width: max(0, geo.size.width * progress))
                        .shadow(color: .questAmber.opacity(0.7), radius: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: compact ? 6 : 10)
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
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dungeonStone)
                        .overlay(Capsule().stroke(Color.dungeonAsh, lineWidth: 1))
                    Capsule()
                        .fill(LinearGradient.crimsonGlow)
                        .frame(width: Swift.max(0, geo.size.width * fraction))
                        .shadow(color: .combatCrimson.opacity(0.7), radius: 5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: fraction)
                }
            }
            .frame(height: 8)
        }
    }
}
