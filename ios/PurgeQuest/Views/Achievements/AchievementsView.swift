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
                    .font(.dungeonTitle)
                    .foregroundStyle(.textPrimary)
                Text("\(unlocked) of \(total) unlocked")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(.questAmber)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dungeonStone)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.questAmber.opacity(0.6), lineWidth: 1))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmber.opacity(0.3), lineWidth: 1).padding(2))
                )
        }
    }
}

private struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: achievement.isUnlocked ? "medal.fill" : achievement.iconName)
                .font(.title2.weight(.bold))
                .foregroundStyle(achievement.isUnlocked ? AnyShapeStyle(Color.questAmber) : AnyShapeStyle(Color.textSecondary))
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(achievement.isUnlocked ? Color.questAmber.opacity(0.14) : Color.dungeonStoneLight)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(achievement.isUnlocked ? Color.questAmber.opacity(0.5) : Color.dungeonAsh, lineWidth: 1))
                )

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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonStone.opacity(achievement.isUnlocked ? 1.0 : 0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(achievement.isUnlocked ? Color.questAmber.opacity(0.7) : Color.dungeonAsh, lineWidth: 1)
                )
        )
        .opacity(achievement.isUnlocked ? 1.0 : 0.85)
    }
}
