//
//  AchievementsView.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query(sort: \Achievement.title) private var allAchievements: [Achievement]

    private var achievements: [Achievement] {
        allAchievements.sorted { lhs, rhs in
            if lhs.isUnlocked != rhs.isUnlocked { return lhs.isUnlocked }
            return lhs.title < rhs.title
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(achievements) { a in
                        AchievementCard(achievement: a)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
        .navigationTitle("Trophies")
    }

    private var header: some View {
        let unlocked = achievements.filter { $0.isUnlocked }.count
        let total = achievements.count
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hall of Trophies")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.textPrimary)
                Text("\(unlocked) of \(total) unlocked")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient.amberGlow)
                .shadow(color: .questAmber.opacity(0.5), radius: 10)
        }
    }
}

private struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? AnyShapeStyle(LinearGradient.amberGlow) : AnyShapeStyle(Color.dungeonStoneLight))
                    .frame(width: 56, height: 56)
                Image(systemName: achievement.iconName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(achievement.isUnlocked ? .dungeonVoid : .textSecondary)
            }
            .shadow(color: achievement.isUnlocked ? .questAmber.opacity(0.5) : .clear, radius: 12)

            Text(achievement.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            Text(achievement.subtitle)
                .font(.caption)
                .foregroundStyle(.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            ProgressView(value: min(Double(achievement.progress) / Double(max(1, achievement.goal)), 1.0))
                .tint(achievement.isUnlocked ? Color.gemEmerald : Color.questAmber)
            Text("\(min(achievement.progress, achievement.goal)) / \(achievement.goal)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dungeonStone.opacity(achievement.isUnlocked ? 1.0 : 0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(achievement.isUnlocked ? Color.questAmber.opacity(0.7) : Color.dungeonAsh, lineWidth: 1)
                )
        )
        .opacity(achievement.isUnlocked ? 1.0 : 0.85)
    }
}
