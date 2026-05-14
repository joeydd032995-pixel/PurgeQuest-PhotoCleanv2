//
//  CombatHUD.swift
//  PurgeQuest
//

import SwiftUI

struct CombatHUD: View {
    let heroHP: Int
    let heroMaxHP: Int
    let combo: Int
    let roomNumber: Int
    let totalRooms: Int
    let remaining: Int
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.callout.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.dungeonStone))
                        .overlay(Circle().stroke(Color.dungeonAsh, lineWidth: 1))
                        .foregroundStyle(.textPrimary)
                }
                .accessibilityLabel("Exit dungeon")

                VStack(alignment: .leading, spacing: 6) {
                    HPBarView(current: heroHP, max: heroMaxHP, label: "HERO")
                    HStack {
                        Text("Room \(roomNumber)/\(totalRooms)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.textPrimary)
                        Text("· \(remaining) remaining")
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                        Spacer()
                    }
                }

                comboBadge
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.dungeonVoid.opacity(0.7))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.dungeonAsh, lineWidth: 1))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            )
        }
    }

    private var comboBadge: some View {
        let multiplier = max(1, min(combo / 5 + 1, 3))
        let tint: Color = combo >= 20 ? .combatCrimson : (combo >= 10 ? .questAmber : .textSecondary)
        return VStack(spacing: 2) {
            Text("\(combo)x")
                .font(.title3.weight(.black).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText(value: Double(combo)))
            Text(multiplier > 1 ? "×\(multiplier) BONUS" : "COMBO")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.textSecondary)
        }
        .frame(width: 76)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.5), lineWidth: 1))
        )
    }
}
