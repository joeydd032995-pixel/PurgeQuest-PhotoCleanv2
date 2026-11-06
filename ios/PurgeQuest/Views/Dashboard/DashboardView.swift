//
//  DashboardView.swift
//  PurgeQuest
//
//  Storage-first. The Library overview (recoverable space, media counts) leads;
//  the hero strip and daily quests follow as framed dungeon panels.
//

import SwiftUI
import SwiftData
import PhotosUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var heroes: [Hero]
    @Query private var quests: [Quest]
    @Query private var cosmetics: [CosmeticItem]

    @State private var libraryStats: LibraryStats = .init()
    @State private var scoutedTheme: DungeonTheme? = nil
    /// Hand-picked media for a targeted hunt.
    @State private var pickedItems: [PhotosPickerItem] = []
    /// Shown when the picker returned choices that carry no asset identifiers —
    /// the signature of missing photo-library access.
    @State private var showAccessHint = false

    private var hero: Hero? { heroes.first }
    private var equippedItems: [CosmeticItem] { cosmetics.filter { $0.isEquipped } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                libraryOverview
                if let event = SeasonalEventService.shared.activeEvent {
                    SeasonalEventBanner(event: event)
                }
                heroStrip
                themeStrip
                questsPanel
                enterDungeonButton
                pickedHuntPicker
                Color.clear.frame(height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
        .task {
            libraryStats = PhotoLibraryService.shared.fetchLibraryStats()
            scoutedTheme = DungeonThemeEngine.theme(for: PhotoLibraryService.shared.fetchLibraryComposition())
            updateStreak()
            SeasonalEventService.shared.refresh()
            WidgetSnapshotService.write(hero: hero, quests: quests)
        }
        .onChange(of: hero?.gems ?? 0) { _, _ in
            WidgetSnapshotService.write(hero: hero, quests: quests)
        }
        .onChange(of: hero?.streakDays ?? 0) { _, _ in
            WidgetSnapshotService.write(hero: hero, quests: quests)
        }
        .onChange(of: quests.map(\.currentCount)) { _, _ in
            WidgetSnapshotService.write(hero: hero, quests: quests)
        }
        .alert("Photo access needed", isPresented: $showAccessHint) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("PurgeQuest needs full photo access to hunt the monsters you choose. Allow all photos in Settings, then pick them again.")
        }
    }

    // MARK: - Library overview (utility surface)

    private var libraryOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Library")
                .font(.title.weight(.bold))
                .foregroundStyle(.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f GB", libraryStats.estimatedGB))
                    .font(.system(size: 40, weight: .bold).monospacedDigit())
                    .foregroundStyle(.textPrimary)
                Text("estimated recoverable space")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dungeonStone)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dungeonAsh, lineWidth: 1))
            )

            HStack(spacing: 10) {
                StatTile(icon: "photo.fill", label: "Photos", value: "\(libraryStats.photoCount)", tint: .questAmber)
                StatTile(icon: "video.fill", label: "Videos", value: "\(libraryStats.videoCount)", tint: .videoSapphire)
            }
            HStack(spacing: 10) {
                StatTile(icon: "internaldrive.fill", label: "Freed so far", value: formattedFreed, tint: .gemEmerald)
                StatTile(icon: "flame.fill", label: "Day streak", value: "\(hero?.streakDays ?? 0)", tint: .combatCrimson)
            }
        }
    }

    private var formattedFreed: String {
        let mb = hero?.totalMBFreed ?? 0
        if mb >= 1024 { return String(format: "%.2f GB", mb / 1024.0) }
        return String(format: "%.0f MB", mb)
    }

    // MARK: - Hero strip (dungeon panel)

    private var heroStrip: some View {
        Group {
            if let hero {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.dungeonStoneLight)
                            .overlay(Circle().stroke(Color.questAmber.opacity(0.6), lineWidth: 1))
                            .overlay(Circle().stroke(Color.questAmber.opacity(0.3), lineWidth: 1).padding(3))
                        MiniAvatarView(hero: hero, equipped: equippedItems, size: 88)
                            .frame(width: 52, height: 62)
                            .clipped()
                    }
                    .frame(width: 68, height: 68)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(hero.name)
                                .font(.dungeonHeader)
                                .foregroundStyle(.textPrimary)
                            Text("LV \(hero.level)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.questAmber.opacity(0.15)))
                                .foregroundStyle(.questAmber)
                        }
                        Text("\(hero.race.displayName) · \(hero.heroClass.displayName)")
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                        XPBarView(progress: hero.levelProgress, level: hero.level, compact: true)
                    }

                    Spacer()

                    GemCounterView(count: hero.gems)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dungeonStone.opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.questAmber.opacity(0.35), lineWidth: 1))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmber.opacity(0.18), lineWidth: 1).padding(2))
                )
            }
        }
    }

    // MARK: - Dungeon theme (auto-scouted)

    @ViewBuilder
    private var themeStrip: some View {
        if let theme = scoutedTheme {
            HStack(spacing: 12) {
                Image(systemName: theme.symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.tintColor)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.dungeonStoneLight))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(theme.tintColor.opacity(0.5), lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEXT DIVE · \(theme.displayName)")
                        .font(.dungeonCaption.weight(.bold))
                        .foregroundStyle(.textPrimary)
                    Text(theme.tagline)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dungeonStone.opacity(0.85))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.tintColor.opacity(0.35), lineWidth: 1))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Next dive: \(theme.displayName). \(theme.tagline)")
        }
    }

    // MARK: - Quests (dungeon panel)

    private var questsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Quests")
                    .font(.dungeonHeader)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Image(systemName: "scroll.fill").foregroundStyle(.questAmber)
            }
            VStack(spacing: 8) {
                ForEach(quests) { q in
                    QuestRow(quest: q)
                }
                if quests.isEmpty {
                    Text("Generating today's quests.")
                        .font(.callout).foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }
    }

    // MARK: - CTA

    private var enterDungeonButton: some View {
        Button {
            HapticsService.shared.medium()
            appState.combatRequested = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                Text("Enter the Dungeon")
            }
        }
        .buttonStyle(.gold(fullWidth: true))
        .accessibilityLabel("Enter the dungeon and start a cleanup session")
    }

    /// Photos picker: hand-pick specific media and dive against exactly those
    /// monsters — for when the player knows which corner of the library needs
    /// purging. Picking immediately launches the dungeon.
    private var pickedHuntPicker: some View {
        PhotosPicker(
            selection: $pickedItems,
            maxSelectionCount: 40,
            matching: .any(of: [.images, .videos])
        ) {
            Label("Hunt Chosen Monsters", systemImage: "hand.raised.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.dungeonStone)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
                )
                .foregroundStyle(.textPrimary)
        }
        .accessibilityLabel("Pick specific photos and videos to review")
        .onChange(of: pickedItems) { _, items in
            let ids = items.compactMap(\.itemIdentifier)
            pickedItems = []
            guard !ids.isEmpty else {
                // Choices without identifiers mean PhotoKit can't see them —
                // usually limited photo access. Say so instead of doing nothing.
                if !items.isEmpty { showAccessHint = true }
                return
            }
            HapticsService.shared.medium()
            appState.pickedAssetIDs = ids
            appState.combatRequested = true
        }
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
                    Text("+\(quest.rewardXP) XP")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.questAmber)
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
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dungeonStone)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(quest.completed ? Color.gemEmerald.opacity(0.6) : Color.dungeonAsh, lineWidth: 1)
                )
        )
    }
}
