//
//  DashboardView.swift
//  PurgeQuest
//
//  Storage-first. A compact storage ledger leads, then the hero on its stage and the one primary
//  action, Enter the Dungeon, all above the fold. The two optional ways in sit beside each other
//  under it; the next dive and the daily quests follow.
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
    @Query private var sparedRecords: [SparedMediaRecord]
    @Query private var deletedRecords: [DeletedMediaRecord]

    @State private var libraryStats: LibraryStats = .init()
    @State private var scoutedTheme: DungeonTheme? = nil
    /// Hand-picked media for a targeted hunt.
    @State private var pickedItems: [PhotosPickerItem] = []
    /// Shown when the picker returned choices that carry no asset identifiers —
    /// the signature of missing photo-library access.
    @State private var showAccessHint = false
    /// The date range sheet (see DatesSheet).
    @State private var showDatesSheet = false

    // The three storage measurements (identified / pending / reclaimed).
    @State private var opportunityBytes: Int64 = 0
    @State private var pendingDeletionBytes: Int64 = 0
    @State private var reclaim = StorageMeasurementService.Reading(verifiedBytes: 0, unverifiedBytes: 0, isMeasurable: true)

    private var hero: Hero? { heroes.first }
    private var equippedItems: [CosmeticItem] { cosmetics.filter { $0.isEquipped } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                libraryOverview
                heroStrip
                enterDungeonButton
                HStack(spacing: 10) {
                    focusedDiveMenu
                    pickedHuntPicker
                }
                datesRow
                if let event = SeasonalEventService.shared.activeEvent {
                    SeasonalEventBanner(event: event)
                }
                themeStrip
                questsPanel
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
            WidgetSnapshotService.write(hero: hero, quests: quests)
            refreshStorageMeasurements()
        }
        // The theme strip and the opportunity figure describe the dive the player is about to start, so
        // they follow the date range: worked out when the screen appears and again whenever it changes.
        .task(id: appState.dateScope) {
            refreshScopedPreviews()
        }
        // Access can change while the app is away (the player flips it in Settings): reload what it describes.
        .onChange(of: appState.photoAuthStatus) { _, _ in
            libraryStats = PhotoLibraryService.shared.fetchLibraryStats()
            refreshScopedPreviews()
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
        .sheet(isPresented: $showDatesSheet) {
            DatesSheet(initial: appState.dateScope)
        }
    }

    // MARK: - Library overview (utility surface)

    /// The three storage measurements, kept deliberately separate: the
    /// estimated opportunity is a heuristic, pending deletion is what the app
    /// moved to Recently Deleted (still recoverable, still occupying space),
    /// and only the third row is a real measurement of freed device storage.
    private var libraryOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Library")
                .font(.dungeonScreenTitle)
                .foregroundStyle(.textPrimary)

            // Anything short of full access: say so here, for as long as it holds. A library the app
            // cannot open must never look like a clean one.
            PhotoAccessNotice(access: appState.photoAccess) { handleAccessAction() }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Storage")
                        .font(.dungeonHeader)
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text("\(libraryStats.photoCount) photos · \(libraryStats.videoCount) videos")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.textSecondary)
                }
                .padding(.bottom, 4)

                measurementRow(
                    title: "Identified opportunity",
                    value: opportunityValue,
                    caption: appState.dateScope.isActive
                        ? "Estimated size of items selected for cleanup, within your date range."
                        : "Estimated size of items selected for cleanup.",
                    tint: .questAmber
                )
                hairline
                measurementRow(
                    title: "Pending deletion",
                    value: formattedBytes(pendingDeletionBytes),
                    caption: "Items moved into Recently Deleted, still potentially occupying storage.",
                    tint: .videoSapphire
                )
                hairline
                measurementRow(
                    title: "Actually reclaimed",
                    value: reclaimValue,
                    caption: "Confirmed reduction in device storage, measured separately.",
                    tint: .gemEmerald
                )
            }
            .padding(14)
            .background(DungeonPanelBackground())
        }
    }

    /// The estimate for the next dive. "All reviewed" means the app looked and found nothing, so it is
    /// never said when the app was not allowed to look.
    private var opportunityValue: String {
        guard appState.photoAccess.canReview else { return "Needs access" }
        if opportunityBytes > 0 { return formattedBytes(opportunityBytes) }
        return appState.dateScope.isActive ? "None in range" : "All reviewed"
    }

    /// The notice's button: ask if access was never asked for, otherwise Settings is the only place to change it.
    private func handleAccessAction() {
        switch appState.photoAccess {
        case .notAsked:
            Task { await appState.refreshPhotoAuth() }
        default:
            SystemSettings.open()
        }
    }

    /// One labeled storage measurement inside the overview card.
    private func measurementRow(title: String, value: String, caption: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(title.uppercased())
                        .font(.dungeonCaption.weight(.bold))
                        .foregroundStyle(.textSecondary)
                }
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private var hairline: some View {
        Rectangle().fill(Color.dungeonAsh.opacity(0.4)).frame(height: 1)
    }

    /// The measured number only shows once a verification cleared the noise
    /// threshold; until then the honest answer is "not yet verified".
    private var reclaimValue: String {
        guard reclaim.isMeasurable else { return "No reading yet" }
        return reclaim.verifiedBytes > 0 ? formattedBytes(reclaim.verifiedBytes) : "Not yet verified"
    }

    /// Recomputes the measurements that do not depend on the date range: what is pending in Recently
    /// Deleted and what was actually reclaimed. (The opportunity figure follows the range; see
    /// `refreshScopedPreviews`.)
    private func refreshStorageMeasurements() {
        // Recently Deleted keeps items for 30 days; until then they still
        // occupy space even though the dungeon already banked them.
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        pendingDeletionBytes = deletedRecords
            .filter { $0.deletedAt >= cutoff }
            .reduce(0) { $0 + $1.fileSizeBytes }
        reclaim = StorageMeasurementService.shared.refresh()
    }

    /// Recomputes the figures that describe the next dive, which follow the date range: the estimated
    /// opportunity and the scouted dungeon theme.
    private func refreshScopedPreviews() {
        let scope = appState.dateScope
        let seen = Set(sparedRecords.map(\.assetIdentifier))
            .union(deletedRecords.map(\.assetIdentifier))
        opportunityBytes = PhotoLibraryService.shared.fetchOpportunityBytes(excluding: seen, scope: scope)
        scoutedTheme = DungeonThemeEngine.theme(for: PhotoLibraryService.shared.fetchLibraryComposition(scope: scope))
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576.0
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return "0 MB"
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
                HStack(alignment: .center, spacing: 8) {
                    HeroStageView(hero: hero, equipped: equippedItems, height: 84, accent: hero.race.accent, isAnimated: false)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(hero.name)
                                .font(.dungeonHeader)
                                .foregroundStyle(.textPrimary)
                                .lineLimit(1)
                            LevelChip(level: hero.level)
                        }
                        Text("\(hero.race.displayName) · \(hero.heroClass.displayName)")
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                        XPBarView(progress: hero.levelProgress, level: hero.level, compact: true)
                        HStack(spacing: 8) {
                            GemCounterView(count: hero.gems)
                            StreakChip(days: hero.streakDays)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DungeonPanelBackground(cornerRadius: DungeonRadius.hero, accent: hero.race.accent))
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
            .background(DungeonPanelBackground(accent: theme.tintColor))
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
            appState.diveFocus = nil   // the default dive is always mixed, whatever an earlier dive left behind
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

    /// Optional: lean this dive toward one kind of clutter. "Enter the Dungeon" above stays the mixed
    /// default. Choosing a bucket starts the dive at once; the choice applies to that dive only.
    private var focusedDiveMenu: some View {
        Menu {
            ForEach(RoomBucket.allCases, id: \.self) { bucket in
                Button {
                    HapticsService.shared.medium()
                    appState.diveFocus = bucket
                    appState.combatRequested = true
                } label: {
                    Label(focusTitle(bucket), systemImage: focusIcon(bucket))
                }
                .disabled(!canFocus(on: bucket))
            }
        } label: {
            Label("Focused Dive", systemImage: "scope")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DungeonPanelBackground())
                .foregroundStyle(.textPrimary)
        }
        .accessibilityLabel("Focused dive: choose one kind of clutter to hunt first")
    }

    /// A bucket the dive's settings would never fetch is not offered: video-only dives hold no photos,
    /// and photo-only dives hold no videos.
    private func canFocus(on bucket: RoomBucket) -> Bool {
        switch bucket {
        case .largeVideo: return appState.includeVideos || appState.videoOnlyMode
        case .blur, .screenshots, .old: return !appState.videoOnlyMode
        }
    }

    private func focusTitle(_ bucket: RoomBucket) -> String {
        switch bucket {
        case .blur: return "Blur"
        case .screenshots: return "Screenshots"
        case .largeVideo: return "Large Video"
        case .old: return "Old"
        }
    }

    private func focusIcon(_ bucket: RoomBucket) -> String {
        switch bucket {
        case .blur: return "camera.filters"
        case .screenshots: return "camera.viewfinder"
        case .largeVideo: return "film.stack"
        case .old: return "clock.arrow.circlepath"
        }
    }

    // MARK: - Dates

    /// The smallest tap target Apple recommends, in points. The clear button gets this much.
    private static let clearTapTarget: CGFloat = 44

    /// The standing date range (see DateScope). A quiet panel button like its neighbours. While a range
    /// is on it names the range, takes an accent border and offers a one-tap clear, so a range can never
    /// narrow the dungeon without the player seeing it.
    private var datesRow: some View {
        let scope = appState.dateScope
        return HStack(spacing: 8) {
            Button {
                HapticsService.shared.light()
                showDatesSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: datesIcon(for: scope.mode))
                        .font(.headline)
                        .foregroundStyle(scope.isActive ? Color.questAmber : Color.textSecondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DATES")
                            .font(.dungeonCaption.weight(.bold))
                            .foregroundStyle(.textSecondary)
                        Text(scope.summary())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    if !scope.isActive {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.textSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dates, \(scope.summary())")
            .accessibilityHint("Opens the date range options")
            .accessibilityIdentifier("dashboard.dates")

            if scope.isActive {
                Button {
                    HapticsService.shared.light()
                    appState.setDateScope(.all)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.textSecondary)
                        // The glyph sits in a 44 pt square so a thumb can find it. The row gives up padding
                        // to make room (below).
                        .frame(minWidth: Self.clearTapTarget, minHeight: Self.clearTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear date range")
                .accessibilityIdentifier("dashboard.dates.clear")
            }
        }
        .padding(.leading, 14)
        // The clear button's 44 pt target is taller than the two lines of text, so while a range is on the
        // row trades padding for it. That lands the row a little shorter than it is with no range: 56.0 pt
        // against 58.3 pt at the default text size (measured), and up to 10 pt shorter at larger sizes. At
        // the default size the glyph sits 14 pt from the edge, where the chevron does.
        .padding(.trailing, scope.isActive ? 6 : 14)
        .padding(.vertical, scope.isActive ? 6 : 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DungeonPanelBackground(accent: scope.isActive ? Color.questAmber : nil))
    }

    /// A different calendar glyph per mode, so the mode never depends on color alone.
    private func datesIcon(for mode: DateScope.Mode) -> String {
        switch mode {
        case .all:     return "calendar"
        case .only:    return "calendar.badge.checkmark"
        case .exclude: return "calendar.badge.minus"
        }
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
            Label("Hunt Chosen", systemImage: "hand.raised.fill")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DungeonPanelBackground())
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

    /// What the quest asks for, as a glyph.
    private var icon: String {
        switch quest.kind {
        case .photoSlay: return "photo.fill"
        case .videoSlay: return "video.fill"
        case .mbFreed:   return "internaldrive.fill"
        case .anySlay:   return "shield.lefthalf.filled"
        }
    }

    private var tint: Color { quest.completed ? Color.gemEmerald : Color.questAmber }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: quest.completed ? "checkmark.seal.fill" : icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: DungeonRadius.chip, style: .continuous).fill(Color.dungeonStoneLight))
                .overlay(RoundedRectangle(cornerRadius: DungeonRadius.chip, style: .continuous).strokeBorder(tint.opacity(0.45), lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(quest.title)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(quest.completed ? .gemEmerald : .textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(quest.currentCount) / \(quest.targetCount)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.textSecondary)
                }
                Text(quest.subtitle)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
                DungeonProgressBar(value: quest.progressFraction, tint: tint, height: 6)
                HStack(spacing: 10) {
                    Label("+\(quest.rewardGems)", systemImage: "diamond.fill")
                        .foregroundStyle(.gemEmerald)
                    Text("+\(quest.rewardXP) XP")
                        .foregroundStyle(.questAmber)
                }
                .font(.caption2.monospacedDigit().weight(.bold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DungeonPanelBackground(accent: quest.completed ? Color.gemEmerald : nil))
    }
}
