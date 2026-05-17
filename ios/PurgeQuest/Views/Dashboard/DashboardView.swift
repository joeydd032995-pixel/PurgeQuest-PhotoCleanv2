//
//  DashboardView.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var heroes: [Hero]
    @Query private var quests: [Quest]

    @State private var libraryStats: LibraryStats = .init()
    @State private var heroBob: Bool = false

    private var hero: Hero? { heroes.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroHeader
                if let event = SeasonalEventService.shared.activeEvent {
                    SeasonalEventBanner(event: event)
                }
                statsGrid
                questsPanel
                enterDungeonButton
                Color.clear.frame(height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
        .task {
            libraryStats = PhotoLibraryService.shared.fetchLibraryStats()
            updateStreak()
            SeasonalEventService.shared.refresh()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                heroBob.toggle()
            }
        }
    }

    private var heroHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient.amberGlow)
                    .frame(width: 160, height: 160)
                    .blur(radius: 50)
                    .opacity(0.7)
                Circle()
                    .strokeBorder(LinearGradient.amberGlow, lineWidth: 2)
                    .frame(width: 130, height: 130)
                Image(systemName: hero?.heroClass.symbol ?? "shield.lefthalf.filled")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(LinearGradient.amberGlow)
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: .questAmber.opacity(0.6), radius: 14)
                    .offset(y: heroBob ? -4 : 4)
            }

            VStack(spacing: 4) {
                Text(hero?.name ?? "Hero")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.textPrimary)
                Text("\(hero?.heroClass.displayName ?? "Purge Knight") · LV \(hero?.level ?? 1)")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }

            if let hero {
                XPBarView(progress: hero.levelProgress, level: hero.level)
                    .padding(.horizontal, 8)
            }

            HStack(spacing: 10) {
                GemCounterView(count: hero?.gems ?? 0)
                streakChip
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.dungeonStone.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.dungeonAsh, lineWidth: 1))
        )
    }

    private var streakChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(LinearGradient.crimsonGlow)
                .symbolEffect(.pulse, options: .repeating)
            Text("\(hero?.streakDays ?? 0) day streak")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.textPrimary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color.dungeonStone).overlay(Capsule().stroke(Color.combatCrimson.opacity(0.4), lineWidth: 1)))
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Camera Roll Dungeon")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.textPrimary)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatTile(icon: "photo.fill", label: "Photos", value: "\(libraryStats.photoCount)", tint: .questAmber)
                StatTile(icon: "video.fill", label: "Videos", value: "\(libraryStats.videoCount)", tint: .videoSapphire)
                StatTile(icon: "internaldrive.fill", label: "Estimated clutter", value: String(format: "%.1f GB", libraryStats.estimatedGB), tint: .gemEmerald)
                StatTile(icon: "trophy.fill", label: "Total freed", value: formattedFreed, tint: .questAmberDeep)
            }
        }
    }

    private var formattedFreed: String {
        let mb = hero?.totalMBFreed ?? 0
        if mb >= 1024 { return String(format: "%.2f GB", mb / 1024.0) }
        return String(format: "%.0f MB", mb)
    }

    private var questsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Quests")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.textPrimary)
                Spacer()
                Image(systemName: "scroll.fill").foregroundStyle(.questAmber)
            }
            VStack(spacing: 8) {
                ForEach(quests) { q in
                    QuestRow(quest: q)
                }
                if quests.isEmpty {
                    Text("Generating today's quests…")
                        .font(.callout).foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }
    }

    private var enterDungeonButton: some View {
        Button {
            HapticsService.shared.medium()
            appState.combatRequested = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                Text("Enter the Dungeon")
                    .font(.title3.weight(.heavy))
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    LinearGradient.amberGlow
                    LinearGradient(colors: [.combatCrimsonDeep.opacity(0.4), .clear], startPoint: .bottom, endPoint: .top)
                }
            )
            .foregroundStyle(.dungeonVoid)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .questAmber.opacity(0.55), radius: 18)
        }
        .accessibilityLabel("Enter the dungeon and start a combat session")
    }

    private func updateStreak() {
        guard let hero else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let last = hero.lastPlayedDate {
            let lastDay = cal.startOfDay(for: last)
            let dayDiff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if dayDiff == 0 {
                // already counted today
            } else if dayDiff == 1 {
                hero.streakDays += 1
                hero.lastPlayedDate = Date()
            } else {
                hero.streakDays = 1
                hero.lastPlayedDate = Date()
            }
        } else {
            hero.streakDays = 1
            hero.lastPlayedDate = Date()
        }
        try? modelContext.save()
    }
}

private struct QuestRow: View {
    let quest: Quest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(quest.completed ? .gemEmerald : .textPrimary)
                    Text(quest.subtitle)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill").font(.caption2)
                        Text("+\(quest.rewardGems)").font(.caption2.monospacedDigit().weight(.bold))
                    }.foregroundStyle(.gemEmerald)
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle").font(.caption2)
                        Text("+\(quest.rewardXP) XP").font(.caption2.monospacedDigit().weight(.bold))
                    }.foregroundStyle(.questAmber)
                }
            }
            ProgressView(value: quest.progressFraction)
                .tint(quest.completed ? Color.gemEmerald : Color.questAmber)
            Text("\(quest.currentCount) / \(quest.targetCount)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.dungeonStone)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(quest.completed ? Color.gemEmerald.opacity(0.6) : Color.dungeonAsh, lineWidth: 1)
                )
        )
    }
}
