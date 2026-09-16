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
    case defeated
    case error(String)

    static func == (lhs: CombatPhase, rhs: CombatPhase) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.empty, .empty), (.fighting, .fighting),
             (.roomSummary, .roomSummary), (.purging, .purging), (.sessionComplete, .sessionComplete),
             (.defeated, .defeated):
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

    // Duplicate group encounters keyed by representative asset ID
    var groupsByID: [String: DuplicateGroup] = [:]

    // Dungeon theme for this dive — presentation and weighting only.
    var theme: DungeonTheme = .wildGallery

    // Session record — one row per dive, finalized when the run ends.
    private var activeSession: CombatSession?
    private var sessionContext: ModelContext?
    private var roomsCompleted: Int = 0

    // MARK: - Setup

    /// Gem cost to rally after defeat: restores full HP and resumes the room.
    static let rallyCostGems: Int = 100

    func bootstrap(includeVideos: Bool, videoOnly: Bool, hero: Hero, context: ModelContext) async {
        phase = .loading
        heroCurrentHP = hero.maxHP
        heroMaxHP = hero.maxHP
        hero.currentHP = hero.maxHP
        CombatLiveActivityService.shared.start(heroName: hero.name)

        // Open a session record for this dive.
        sessionContext = context
        let session = CombatSession()
        context.insert(session)
        activeSession = session
        roomsCompleted = 0

        // Resume progress: skip everything already swiped (spared) or purged, so
        // re-entering the dungeon continues where the last session left off.
        var seenIDs = Set<String>()
        if let spared = try? context.fetch(FetchDescriptor<SparedMediaRecord>()) {
            seenIDs.formUnion(spared.map(\.assetIdentifier))
        }
        if let purged = try? context.fetch(FetchDescriptor<DeletedMediaRecord>()) {
            seenIDs.formUnion(purged.map(\.assetIdentifier))
        }

        let svc = PhotoLibraryService.shared
        // Over-fetch by the seen count — seen items cluster at the oldest end of
        // the library, so this guarantees a full batch of fresh monsters.
        let assets = svc.fetchAssets(
            limit: Self.initialFetchLimit + seenIDs.count,
            includeVideos: includeVideos,
            videoOnly: videoOnly
        )
        let fresh = assets.filter { !seenIDs.contains($0.localIdentifier) }
        if fresh.isEmpty {
            phase = .empty
            return
        }
        let thumbSize = CGSize(width: 600, height: 600)
        let items = await svc.buildMediaItems(from: fresh, thumbSize: thumbSize)
        let batch = await classifyAndGroup(items, context: context)
        self.groupsByID = batch.groups
        self.theme = batch.theme
        self.allItems = batch.queueItems
        BestiaryService.recordEncounters(for: batch.allItems, context: context)
        self.queueIndex = 0
        loadNextRoom()
    }

    private func loadNextRoom() {
        let remaining = allItems.count - queueIndex
        if remaining <= 0 {
            phase = .sessionComplete
            finalizeSession()
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

    /// Stamps the session record with its end time. Idempotent — safe to call
    /// from every exit path (complete, defeat, manual exit).
    private func finalizeSession() {
        guard let session = activeSession, session.endedAt == nil else { return }
        session.roomsCompleted = roomsCompleted
        session.endedAt = Date()
        try? sessionContext?.save()
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
        let classBonus = hero.heroClass.xpMultiplier(photo: item.kind == .photo, monsterType: item.monsterType)
        if classBonus > 1.0 { xp = Int(Double(xp) * classBonus) }
        let seasonalBonus = SeasonalEventService.shared.xpMultiplier(for: item.monsterType)
        if seasonalBonus > 1.0 { xp = Int(Double(xp) * seasonalBonus) }

        let mb = Double(item.estimatedBytes) / 1_048_576.0
        var gems = Int(mb.rounded()) * multiplier
        let gemBonus = hero.heroClass.gemMultiplier
        if gemBonus > 1.0 { gems = Int(Double(gems) * gemBonus) }

        return (xp, gems)
    }

    func decideSpare(_ item: MediaItem, hero: Hero, context: ModelContext) {
        combo = 0
        perfectRoom = false
        let dmg = item.monsterType.attackDamage
        heroCurrentHP = max(0, heroCurrentHP - dmg)
        hero.currentHP = heroCurrentHP
        pendingDecisions.append(PendingDecision(item: item, willDelete: false))
        // Persist the spare so this monster is skipped on every future dive.
        context.insert(SparedMediaRecord(assetIdentifier: item.id, monsterType: item.monsterType))
        try? context.save()
        spareFlashTrigger &+= 1
        screenShakeTrigger &+= 1
        if heroCurrentHP <= 0 {
            enterDefeat(context: context)
            return
        }
        HapticsService.shared.medium()
        pushLiveActivityUpdate()
        advance()
    }

    /// The duplicate group this asset represents, if any.
    func group(for item: MediaItem) -> DuplicateGroup? {
        groupsByID[item.id]
    }

    /// True when the top encounter is a duplicate group card.
    var topItemIsGroup: Bool {
        guard let top = topItem else { return false }
        return groupsByID[top.id] != nil
    }

    /// Confirms explicit per-copy decisions for a duplicate group encounter.
    /// The suggested survivor is never auto-applied — each copy the player
    /// marked for deletion is recorded individually, and every spare persists
    /// a record so the copies never resurface.
    func commitGroupDecisions(_ group: DuplicateGroup, decisions: [String: Bool], hero: Hero, context: ModelContext) {
        var slays = 0
        var spares = 0
        for member in group.members {
            if decisions[member.id] ?? false {
                combo += 1
                peakCombo = max(peakCombo, combo)
                hero.highestCombo = max(hero.highestCombo, peakCombo)
                let earned = reward(for: member, hero: hero, combo: combo)
                pendingDecisions.append(
                    PendingDecision(item: member, willDelete: true, xpReward: earned.xp, gemReward: earned.gems)
                )
                slays += 1
            } else {
                pendingDecisions.append(PendingDecision(item: member, willDelete: false))
                context.insert(SparedMediaRecord(assetIdentifier: member.id, monsterType: member.monsterType))
                spares += 1
            }
        }
        if slays > 0 {
            deleteFlashTrigger &+= 1
            HapticsService.shared.light()
            if combo > 0 && combo % 5 == 0 { HapticsService.shared.comboBurst() }
        }
        if spares > 0 {
            perfectRoom = false
            heroCurrentHP = max(0, heroCurrentHP - group.monsterType.attackDamage)
            hero.currentHP = heroCurrentHP
            spareFlashTrigger &+= 1
            screenShakeTrigger &+= 1
        }
        try? context.save()
        pushLiveActivityUpdate()
        if heroCurrentHP <= 0 {
            enterDefeat(context: context)
            return
        }
        advance()
    }

    /// HP hit zero: the run ends here. The defeat screen offers a paid rally
    /// (full heal, resume the room) or a retreat back to the Library.
    private func enterDefeat(context: ModelContext) {
        phase = .defeated
        HapticsService.shared.warning()
        finalizeSession()
        CombatLiveActivityService.shared.end()
        try? context.save()
    }

    /// Spends gems to fully heal and pick the run back up mid-room.
    func rally(hero: Hero, context: ModelContext) {
        guard phase == .defeated, hero.gems >= Self.rallyCostGems else { return }
        hero.gems -= Self.rallyCostGems
        heroCurrentHP = heroMaxHP
        hero.currentHP = heroMaxHP
        try? context.save()
        phase = .fighting
        HapticsService.shared.success()
        CombatLiveActivityService.shared.start(heroName: hero.name)
        pushLiveActivityUpdate()
    }

    private func advance() {
        currentRoomIndex += 1
        if currentRoomIndex >= currentRoomItems.count {
            phase = .roomSummary
            HapticsService.shared.success()
        }
    }

    // MARK: - Classification pipeline

    private struct ClassifiedBatch {
        let allItems: [MediaItem]
        let queueItems: [MediaItem]
        let groups: [String: DuplicateGroup]
        let theme: DungeonTheme
    }

    /// Runs the two-stage duplicate pipeline and the metadata classifier,
    /// folds clusters into single group encounters, picks the dungeon theme,
    /// and orders the queue so the theme's family leads (presentation only —
    /// ordering never changes what the player may decide).
    private func classifyAndGroup(_ items: [MediaItem], context: ModelContext) async -> ClassifiedBatch {
        let cached = MediaFingerprintStore.loadCached(in: context)

        var fingerprints: [MediaFingerprint] = []
        fingerprints.reserveCapacity(items.count)
        for item in items {
            let dHash = cached[item.id]?.dHash ?? item.thumbnail.flatMap(MediaFingerprinter.dHash)
            fingerprints.append(MediaFingerprint(
                assetID: item.id,
                byteSize: item.estimatedBytes,
                pixelWidth: item.pixelWidth,
                pixelHeight: item.pixelHeight,
                durationSeconds: item.durationSeconds,
                creationDate: item.creationDate,
                isFavorite: item.isFavorite,
                isScreenshot: item.isScreenshot,
                hasEdits: item.hasEdits,
                isScreenRecording: item.isScreenRecording,
                dHash: dHash,
                sharpness: item.sharpness,
                contentHash: cached[item.id]?.contentHash
            ))
        }

        // Stage A confirmation: hash metadata-equal candidates only (bounded IO).
        let alreadyHashed = Set(cached.compactMap { $0.value.contentHash == nil ? nil : $0.key })
        let candidateIDs = DuplicateDetectionEngine.metadataExactCandidates(in: fingerprints)
            .flatMap { $0.map(\.assetID) }
            .filter { !alreadyHashed.contains($0) }
        for id in candidateIDs.prefix(80) {
            guard let index = fingerprints.firstIndex(where: { $0.assetID == id }),
                  let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
                  let hash = await PhotoLibraryService.shared.contentHash(for: asset) else { continue }
            fingerprints[index] = fingerprints[index].withContentHash(hash)
        }
        MediaFingerprintStore.persist(fingerprints, in: context)

        let library = MonsterClassifier.classify(items: items, fingerprints: fingerprints)
        var classified = items
        for i in classified.indices {
            if let c = library.classifications[classified[i].id] {
                classified[i].classification = c
                classified[i].monsterType = c.monsterType
            }
        }
        let byID = Dictionary(uniqueKeysWithValues: classified.map { ($0.id, $0) })

        // Fold clusters into one group encounter each (representative = oldest).
        var groups: [String: DuplicateGroup] = [:]
        var nonRepresentatives = Set<String>()
        for cluster in library.clusters where cluster.memberIDs.count >= 2 {
            let members = cluster.memberIDs.compactMap { byID[$0] }
            guard let representative = members.first else { continue }
            groups[representative.id] = DuplicateGroup(
                representativeID: representative.id,
                members: members,
                survivorID: library.recommendedSurvivorIDs[representative.id]
            )
            nonRepresentatives.formUnion(cluster.memberIDs.dropFirst())
        }

        // Theme from composition, with duplicate share raised by cluster membership.
        var composition = DungeonThemeEngine.composition(for: classified)
        if !classified.isEmpty {
            composition.duplicateShare = Double(nonRepresentatives.count) / Double(classified.count)
        }
        let theme = DungeonThemeEngine.theme(for: composition)

        // Stable partition: the theme's family leads the encounter queue.
        var themed: [MediaItem] = []
        var rest: [MediaItem] = []
        for item in classified where !nonRepresentatives.contains(item.id) {
            if DungeonThemeEngine.isThemed(item, theme: theme) {
                themed.append(item)
            } else {
                rest.append(item)
            }
        }

        return ClassifiedBatch(
            allItems: classified,
            queueItems: themed + rest,
            groups: groups,
            theme: theme
        )
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
                    fileSizeBytes: item.estimatedBytes,
                    durationSeconds: item.durationSeconds,
                    creationDate: item.creationDate
                )
                context.insert(rec)
                let mb = Double(item.estimatedBytes) / 1_048_576.0
                GameDataService.updateQuests(quests, for: item.monsterType, mbFreedThisAction: mb)
            }
            // Apply rewards to hero
            applyRewardsToHero(hero: hero)
            let videosThisRoom = pendingDecisions.filter { $0.willDelete && $0.item.kind == .video }.count
            GameDataService.syncAchievements(
                hero: hero,
                in: context,
                videosDeletedThisRoom: videosThisRoom,
                perfectRoom: perfectRoom
            )
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

    /// True when the library queue still holds unseen monsters after a run ends —
    /// powers the "Continue Deeper" option on the session-complete screen.
    var hasMoreItems: Bool { queueIndex < allItems.count }

    /// Keeps the hero in the dungeon after a completed run: refills HP, resets the
    /// room counter, and continues through the remaining unseen queue. Lifetime
    /// rewards are already banked; session tallies keep accumulating across dives.
    func continueDeeper(hero: Hero) {
        roomNumber = 1
        combo = 0
        perfectRoom = true
        heroCurrentHP = heroMaxHP
        hero.currentHP = heroMaxHP
        // Each dive gets its own session record; on-screen tallies keep rolling.
        if let context = sessionContext {
            finalizeSession()
            let session = CombatSession()
            context.insert(session)
            activeSession = session
            roomsCompleted = 0
            try? context.save()
        }
        loadNextRoom()
        pushLiveActivityUpdate()
    }

    func endSessionActivity() {
        finalizeSession()
        CombatLiveActivityService.shared.end()
    }

    private func proceedToNextRoom(hero: Hero, context: ModelContext, quests: [Quest]) async {
        roomsCompleted += 1
        activeSession?.roomsCompleted = roomsCompleted
        roomNumber += 1
        if roomNumber > Self.totalRoomsPerSession || queueIndex >= allItems.count {
            phase = .sessionComplete
            finalizeSession()
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

        // Mirror the tallies onto the persisted session record.
        if let session = activeSession {
            session.photosDeleted += photos
            session.videosDeleted += videos
            session.bytesFreed += roomBytes
            session.xpEarned += roomXP
            session.gemsEarned += roomGems
            session.peakCombo = max(session.peakCombo, peakCombo)
        }

        // A single fat room can pop multiple levels; +10 max HP each, full heal on level-up.
        while hero.totalXP >= Hero.xpForLevel(hero.level + 1) {
            hero.level += 1
            hero.maxHP += 10
            hero.currentHP = hero.maxHP
        }
    }
}
