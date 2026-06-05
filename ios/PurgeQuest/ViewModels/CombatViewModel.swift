//
//  CombatViewModel.swift
//  PurgeQuest
//

import Foundation
import SwiftUI
import SwiftData
import Photos

enum CombatPhase: Equatable {
    case loading
    case empty
    case fighting
    case roomSummary
    case purging
    case sessionComplete
    case error(String)

    static func == (lhs: CombatPhase, rhs: CombatPhase) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.empty, .empty), (.fighting, .fighting),
             (.roomSummary, .roomSummary), (.purging, .purging), (.sessionComplete, .sessionComplete):
            return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

struct PendingDecision: Identifiable {
    let item: MediaItem
    var willDelete: Bool
    /// Full reward captured at the instant of the swipe (base × combo × class perk × seasonal bonus).
    /// Stored per-decision so toggling items off in the room summary keeps rewards exact.
    var xpReward: Int = 0
    var gemReward: Int = 0
    var id: String { item.id }
}

@Observable
@MainActor
final class CombatViewModel {

    // MARK: - Configurable
    static let roomSize: Int = 18
    static let totalRoomsPerSession: Int = 5
    static let initialFetchLimit: Int = 150

    // MARK: - State
    var phase: CombatPhase = .loading

    // Library queue
    var allItems: [MediaItem] = []
    private var queueIndex: Int = 0

    // Current room
    var currentRoomItems: [MediaItem] = []
    private var currentRoomIndex: Int = 0
    var roomNumber: Int = 1

    // Pending decisions for the current room (populated as we swipe)
    var pendingDecisions: [PendingDecision] = []

    // Combat stats
    var heroCurrentHP: Int = 100
    var heroMaxHP: Int = 100
    var combo: Int = 0
    var peakCombo: Int = 0

    // Session totals
    var sessionPhotosDeleted: Int = 0
    var sessionVideosDeleted: Int = 0
    var sessionBytesFreed: Int64 = 0
    var sessionXP: Int = 0
    var sessionGems: Int = 0
    var perfectRoom: Bool = true

    // FX flags
    var deleteFlashTrigger: Int = 0
    var spareFlashTrigger: Int = 0
    var screenShakeTrigger: Int = 0

    // MARK: - Setup

    func bootstrap(includeVideos: Bool, videoOnly: Bool, hero: Hero) async {
        phase = .loading
        heroCurrentHP = hero.maxHP
        heroMaxHP = hero.maxHP
        CombatLiveActivityService.shared.start(heroName: hero.name)

        let svc = PhotoLibraryService.shared
        let assets = svc.fetchAssets(limit: Self.initialFetchLimit, includeVideos: includeVideos, videoOnly: videoOnly)
        if assets.isEmpty {
            phase = .empty
            return
        }
        let thumbSize = CGSize(width: 600, height: 600)
        let items = await svc.buildMediaItems(from: assets, thumbSize: thumbSize)
        self.allItems = items
        self.queueIndex = 0
        loadNextRoom()
    }

    private func loadNextRoom() {
        let remaining = allItems.count - queueIndex
        if remaining <= 0 {
            phase = .sessionComplete
            return
        }
        let take = min(Self.roomSize, remaining)
        currentRoomItems = Array(allItems[queueIndex..<(queueIndex + take)])
        queueIndex += take
        currentRoomIndex = 0
        pendingDecisions = []
        perfectRoom = true
        phase = .fighting
    }

    // MARK: - Combat actions

    var topItem: MediaItem? {
        guard currentRoomIndex < currentRoomItems.count else { return nil }
        return currentRoomItems[currentRoomIndex]
    }

    var nextItem: MediaItem? {
        let idx = currentRoomIndex + 1
        guard idx < currentRoomItems.count else { return nil }
        return currentRoomItems[idx]
    }

    var roomRemaining: Int {
        max(0, currentRoomItems.count - currentRoomIndex)
    }

    func decideDelete(_ item: MediaItem, hero: Hero) {
        // Combo gains
        combo += 1
        peakCombo = max(peakCombo, combo)
        hero.highestCombo = max(hero.highestCombo, peakCombo)

        // Capture the full reward now, while this combo is live. It rides along on the
        // decision so it survives any toggles in the room summary and is banked verbatim
        // when the room is confirmed.
        let earned = reward(for: item, hero: hero, combo: combo)
        pendingDecisions.append(
            PendingDecision(item: item, willDelete: true, xpReward: earned.xp, gemReward: earned.gems)
        )
        deleteFlashTrigger &+= 1

        if item.kind == .video {
            HapticsService.shared.videoSlash()
        } else {
            HapticsService.shared.light()
        }
        if combo > 0 && combo % 5 == 0 { HapticsService.shared.comboBurst() }

        pushLiveActivityUpdate()
        advance()
    }

    /// XP + gems for slaying one monster at the given combo, with class perks and the active
    /// seasonal event folded in. Combo multiplier ramps 1× → 2× (combo 5) → 3× (combo 10+).
    private func reward(for item: MediaItem, hero: Hero, combo: Int) -> (xp: Int, gems: Int) {
        let multiplier = max(1, min(combo / 5 + 1, 3))

        var xp = item.monsterType.xpReward * multiplier
        if hero.heroClass == .archivist, item.kind == .photo { xp = Int(Double(xp) * 1.20) }
        if hero.heroClass == .cinematographer, item.kind == .video { xp = Int(Double(xp) * 1.20) }
        if hero.heroClass == .purgeKnight, item.monsterType.isElite { xp = Int(Double(xp) * 1.30) }
        let seasonalBonus = SeasonalEventService.shared.xpMultiplier(for: item.monsterType)
        if seasonalBonus > 1.0 { xp = Int(Double(xp) * seasonalBonus) }

        let mb = Double(item.estimatedBytes) / 1_048_576.0
        var gems = Int(mb.rounded()) * multiplier
        if hero.heroClass == .digitalHermit { gems = Int(Double(gems) * 1.10) }

        return (xp, gems)
    }

    func decideSpare(_ item: MediaItem) {
        combo = 0
        perfectRoom = false
        let dmg = item.monsterType.attackDamage
        heroCurrentHP = max(0, heroCurrentHP - dmg)
        pendingDecisions.append(PendingDecision(item: item, willDelete: false))
        spareFlashTrigger &+= 1
        screenShakeTrigger &+= 1
        HapticsService.shared.medium()
        pushLiveActivityUpdate()
        advance()
    }

    private func advance() {
        currentRoomIndex += 1
        if currentRoomIndex >= currentRoomItems.count {
            phase = .roomSummary
            HapticsService.shared.success()
        }
    }

    func toggleDecision(for id: String) {
        if let idx = pendingDecisions.firstIndex(where: { $0.id == id }) {
            pendingDecisions[idx].willDelete.toggle()
        }
    }

    var pendingDeletionItems: [MediaItem] {
        pendingDecisions.filter { $0.willDelete }.map { $0.item }
    }

    var pendingDeleteByteTotal: Int64 {
        pendingDeletionItems.reduce(0) { $0 + $1.estimatedBytes }
    }

    var pendingPhotoCount: Int { pendingDeletionItems.filter { $0.kind == .photo }.count }
    var pendingVideoCount: Int { pendingDeletionItems.filter { $0.kind == .video }.count }

    /// Confirms the room: actually moves selected items to Recently Deleted and persists records.
    func confirmRoom(hero: Hero, context: ModelContext, quests: [Quest]) async {
        let toDelete = pendingDeletionItems
        guard !toDelete.isEmpty else {
            await proceedToNextRoom(hero: hero, context: context, quests: [])
            return
        }
        phase = .purging
        do {
            let identifiers = toDelete.map { $0.id }
            try await PhotoLibraryService.shared.deleteAssets(identifiers: identifiers)
            // Persist deletion records
            for item in toDelete {
                let rec = DeletedMediaRecord(
                    assetIdentifier: item.id,
                    mediaKind: item.kind,
                    monsterType: item.monsterType,
                    fileSizeBytes: item.estimatedBytes
                )
                context.insert(rec)
                let mb = Double(item.estimatedBytes) / 1_048_576.0
                GameDataService.updateQuests(quests, for: item.monsterType, mbFreedThisAction: mb)
            }
            // Apply rewards to hero
            applyRewardsToHero(hero: hero)
            try? context.save()
            HapticsService.shared.success()
            await proceedToNextRoom(hero: hero, context: context, quests: quests)
        } catch {
            phase = .error((error as? PhotoLibraryError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Skip purge and continue (rare, but handle gracefully).
    func skipRoom(hero: Hero, context: ModelContext, quests: [Quest]) async {
        await proceedToNextRoom(hero: hero, context: context, quests: quests)
    }

    private func pushLiveActivityUpdate() {
        CombatLiveActivityService.shared.update(
            heroHP: heroCurrentHP,
            heroMaxHP: heroMaxHP,
            combo: combo,
            room: roomNumber,
            total: Self.totalRoomsPerSession,
            remaining: roomRemaining,
            mb: Double(sessionBytesFreed) / 1_048_576.0
        )
    }

    func endSessionActivity() {
        CombatLiveActivityService.shared.end()
    }

    private func proceedToNextRoom(hero: Hero, context: ModelContext, quests: [Quest]) async {
        if perfectRoom {
            // Perfect room achievement bump
            await MainActor.run {
                if let ach = (try? context.fetch(FetchDescriptor<Achievement>(predicate: #Predicate { $0.id == "perfect.room" })))?.first {
                    if !ach.isUnlocked {
                        ach.progress = 1
                        ach.isUnlocked = true
                        ach.unlockedAt = Date()
                    }
                }
            }
        }
        roomNumber += 1
        if roomNumber > Self.totalRoomsPerSession || queueIndex >= allItems.count {
            phase = .sessionComplete
            CombatLiveActivityService.shared.end()
            return
        }
        loadNextRoom()
    }

    /// Banks every reward the player confirmed in the current room. Because each reward was
    /// captured at swipe time, combo / class / seasonal bonuses all carry through — and any
    /// items toggled off in the summary are simply excluded.
    private func applyRewardsToHero(hero: Hero) {
        let confirmed = pendingDecisions.filter { $0.willDelete }
        guard !confirmed.isEmpty else { return }

        var roomXP = 0
        var roomGems = 0
        var roomBytes: Int64 = 0
        var photos = 0, videos = 0
        for d in confirmed {
            roomXP += d.xpReward
            roomGems += d.gemReward
            roomBytes += d.item.estimatedBytes
            if d.item.kind == .photo { photos += 1 } else { videos += 1 }
        }

        // Bank onto the hero's lifetime totals.
        hero.totalXP += roomXP
        hero.gems += roomGems
        hero.totalMBFreed += Double(roomBytes) / 1_048_576.0
        hero.totalPhotosPurged += photos
        hero.totalVideosPurged += videos

        // Roll the session tallies forward — only what was actually purged this room.
        sessionXP += roomXP
        sessionGems += roomGems
        sessionBytesFreed += roomBytes
        sessionPhotosDeleted += photos
        sessionVideosDeleted += videos

        // A single fat room can pop multiple levels; +10 max HP each, full heal on level-up.
        while hero.totalXP >= Hero.xpForLevel(hero.level + 1) {
            hero.level += 1
            hero.maxHP += 10
            hero.currentHP = hero.maxHP
        }
    }
}
