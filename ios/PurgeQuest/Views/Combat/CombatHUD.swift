//
//  CombatHUD.swift
//  PurgeQuest
//
//  The one-line bar over a dive: exit, which room of how many with a bar that fills as cards are
//  decided, and the combo. It used to carry the theme name a second time, the count of marked cards and
//  an HP bar, and it wrapped and truncated ("Wild Gall…"). The theme is named once, in the banner on the
//  first room; the cards marked for deletion are counted on the Room Summary; HP is hidden while keeping
//  costs none (DiveRules.keepingCostsHP).
//

import SwiftUI

struct CombatHUD: View {
    let heroHP: Int
    let heroMaxHP: Int
    let combo: Int
    let progress: DiveProgress
    let onExit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            exitButton
            roomColumn
            comboBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonVoid.opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dungeonAsh, lineWidth: 1))
        )
    }

    /// 44 x 44 pt, the smallest target Apple recommends. It was 36.
    private var exitButton: some View {
        Button(action: onExit) {
            Image(systemName: "xmark")
                .font(.callout.weight(.bold))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.dungeonStone))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
                .foregroundStyle(.textPrimary)
        }
        .accessibilityLabel("Exit dungeon")
    }

    private var roomColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            // D1: keeping costs no HP, so the bar would sit full for the whole dive and say nothing.
            // It returns only if the rule that makes HP matter does.
            if DiveRules.keepingCostsHP {
                HPBarView(current: heroHP, max: heroMaxHP, label: "HERO")
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Room \(progress.room) of \(progress.totalRooms)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(progress.remaining) left")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            RoomBar(progress: progress)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.summary)
    }

    private var comboBadge: some View {
        let multiplier = DiveRules.comboMultiplier(forCombo: combo)
        let tint: Color = combo >= 20 ? .combatCrimson : (combo >= 10 ? .questAmber : .textSecondary)
        return VStack(spacing: 1) {
            Text("\(combo)")
                .font(.title3.weight(.black).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText(value: Double(combo)))
            Text(multiplier > 1 ? "COMBO ×\(multiplier)" : "COMBO")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 76)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.5), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(multiplier > 1 ? "Combo \(combo), rewards times \(multiplier)" : "Combo \(combo)")
    }
}

/// One segment per room in the dive: rooms played are full, the current one fills as its cards are
/// decided, and rooms still to come are empty.
private struct RoomBar: View {
    let progress: DiveProgress

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<progress.totalRooms, id: \.self) { index in
                Capsule()
                    .fill(Color.dungeonAsh)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color.questAmber)
                                .frame(width: proxy.size.width * progress.fill(ofSegment: index))
                        }
                    }
                    .frame(height: 5)
            }
        }
        .animation(.easeOut(duration: 0.2), value: progress)
    }
}
