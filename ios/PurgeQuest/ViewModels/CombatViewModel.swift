//
//  CombatViewModel.swift
//  PurgeQuest
//

import Foundation
import SwiftUI
import SwiftData
import Photos
import os

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
    static let roomSize: Int = 20
    static let totalRoomsPerSession: Int = 5
    static let initialFetchLimit: Int = 150

    private static let log = Logger(subsystem: "PurgeQuest", category: "Combat")

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

    // Room targeting (see RoomTargeting): the kind of clutter this dive leans toward (nil is the default
    // mixed dive), and whether rooms are targeted at all. A hand-picked hunt is dealt exactly as chosen.
    private var roomFocus: RoomBucket?
    private var targetsRooms = true

    // MARK: - Setup

    /// Gem cost to rally after defeat: restores full HP and resumes the room.
    static let rallyCostGems: Int = 100

    // MARK: - Secured vs pending rewards
    //
    // SECURED rewards are banked onto the Hero the moment a Room Summary
    // confirmation successfully deletes the assets: base XP (with the combo
    // multiplier live at confirmation), gems, quest/achievement progress, and
    // lifetime purge counters. They can never be lost, even if the hero later
    // falls. On the session record these live in `xpEarned`/`gemsEarned` and
    // the purge tallies.
    //
    // PENDING bonuses are dive-scoped: Perfect Room bonuses accrue per room
    // and the Full Dive bonus is sized by rooms cleared. They only convert to
    // secured when the dive completes (`applyFullDiveBonus`) and are discarded
    // when HP drains (`enterDefeat`), which also resets the combo to 1×.
    static let perfectRoomBonusXP: Int = 30
    static let perfectRoomBonusGems: Int = 15
    static let fullDiveBonusXPPerRoom: Int = 20
    static let fullDiveBonusGemsPerRoom: Int = 10

    private var pendingBonusXP = 0
    private var pendingBonusGems = 0
    /// Bonuses discarded by the last defeat, shown once on the Salvage screen.
    private(set) var lostBonusXP = 0
    private(set) var lostBonusGems = 0
    /// Bonuses converted on the last completed dive, shown on the results screen.
    private(set) var diveBonusXP = 0
    private(set) var diveBonusGems = 0
    /// Monsters marked for deletion (left swipes) that were discarded by the
    /// last defeat — never confirmed at a Room Summary, so nothing was deleted
    /// and no rewards were earned from them.
    private(set) var releasedMarkedCount = 0

    func bootstrap(includeVideos: Bool, videoOnly: Bool, focus: RoomBucket? = nil, hero: Hero, context: ModelContext) async {
        roomFocus = focus
        targetsRooms = true
        openSession(hero: hero, context: context)

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
        Self.log.info("dive: fetched \(assets.count, privacy: .public), \(fresh.count, privacy: .public) fresh after seen-filter")
        if fresh.isEmpty {
            phase = .empty
            return
        }
        let thumbSize = CGSize(width: 600, height: 600)
        let items = await svc.buildMediaItems(from: fresh, thumbSize: thumbSize)
        await loadBatch(items, context: context)
    }

    /// A hand-picked hunt: the player chose specific media in the Photos
    /// picker and wants exactly those monsters, seen or not.
    func bootstrapPicked(assetIDs: [String], hero: Hero, context: ModelContext) async {
        roomFocus = nil
        targetsRooms = false
        openSession(hero: hero, context: context)
        Self.log.info("picked hunt: resolving \(assetIDs.count, privacy: .public) chosen assets")

        func fetchPicked() -> [PHAsset] {
            var fetched: [PHAsset] = []
            PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
                .enumerateObjects { asset, _, _ in fetched.append(asset) }
            return fetched
        }

        var picked = fetchPicked()

        // Limited (or still-undetermined) photo access hides the chosen assets
        // from PhotoKit even though the picker offered them. Ask once for full
        // access so the identifiers resolve.
        if picked.count < assetIDs.count,
           PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized {
            Self.log.info("picked hunt: photo access not full; requesting authorization")
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            if status == .authorized { picked = fetchPicked() }
        }

        guard !picked.isEmpty else {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            Self.log.error("picked hunt: resolved 0 of \(assetIDs.count, privacy: .public) assets, access \(status.rawValue, privacy: .public)")
            phase = status == .authorized
                ? .error("The chosen monsters slipped away before the dive. Pick them again from the dashboard.")
                : .error("PurgeQuest can't see the photos you chose because photo access is limited. Allow all photos in Settings, then pick them again.")
            return
        }
        Self.log.info("picked hunt: resolved \(picked.count, privacy: .public) assets; building monsters")
        let thumbSize = CGSize(width: 600, height: 600)
        let items = await PhotoLibraryService.shared.buildMediaItems(from: picked, thumbSize: thumbSize)
        await loadBatch(items, context: context)
    }

    /// Shared setup for both entry paths: HP, session record, Live Activity.
    private func openSession(hero: Hero, context: ModelContext) {
        phase = .loading
        heroCurrentHP = hero.maxHP
        heroMaxHP = hero.maxHP
        hero.currentHP = hero.maxHP
        CombatLiveActivityService.shared.start(heroName: hero.name)

        sessionContext = context
        let session = CombatSession()
        context.insert(session)
        activeSession = session
        roomsCompleted = 0
        // A new dive always starts clean: combo back to 1× and no leftover
        // pending bonuses from a previous run.
        combo = 0
        pendingBonusXP = 0
        pendingBonusGems = 0
        lostBonusXP = 0
        lostBonusGems = 0
        releasedMarkedCount = 0
        diveBonusXP = 0
        diveBonusGems = 0
    }

    /// Runs classification + duplicate folding on fetched items and opens room one.
    private func loadBatch(_ items: [MediaItem], context: ModelContext) async {
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
        if targetsRooms { arrangeNextRoom() }
        currentRoomItems = Array(allItems[queueIndex..<(queueIndex + take)])
        queueIndex += take
        currentRoomIndex = 0
        pendingDecisions = []
        perfectRoom = true
        phase = .fighting
    }

    /// Moves this room's picks to the front of what is left (see RoomTargeting). Nothing is added or
    /// dropped: only the order of the unseen part of the queue changes.
    private func arrangeNextRoom() {
        let now = Date()
        let memberships = allItems.map { RoomTargeting.buckets(for: RoomTargetFacts(item: $0), now: now) }
        // Say what the deal had to work with, so a focus with nothing left to lean on is visible in the log.
        let left = RoomTargeting.counts(Array(memberships[queueIndex...]))
        let tally = RoomBucket.allCases.map { "\($0.rawValue)=\(left[$0] ?? 0)" }.joined(separator: " ")
        let focusName = roomFocus?.rawValue ?? "none"
        Self.log.info("deal: focus \(focusName, privacy: .public), left \(tally, privacy: .public)")
        var rng = SystemRandomNumberGenerator()
        let order = RoomTargeting.arrangedOrder(
            memberships: memberships, roomStart: queueIndex, roomSize: Self.roomSize,
            focus: roomFocus, using: &rng
        )
        allItems = order.map { allItems[$0] }
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
        // SALVAGE RULES — what the hero keeps vs loses on HP drain:
        // • Secured rewards (banked at each Room Summary confirmation: base
        //   XP, gems, quest/achievement progress, lifetime counters) are
        //   untouched and stay on the hero forever.
        // • Pending dive bonuses (Perfect Room / Full Dive) are discarded and
        //   stashed for the Salvage screen.
        // • The live combo resets to 1× (combo 0 in the reward formula).
        // No quest tracks "complete a dungeon" today; if one is added, its
        // advancement belongs in `applyFullDiveBonus` only, never here.
        lostBonusXP = pendingBonusXP
        lostBonusGems = pendingBonusGems
        pendingBonusXP = 0
        pendingBonusGems = 0
        // Marks never confirmed at a Room Summary are discarded with the run:
        // the photos stay in the library untouched, and no rewards were earned.
        releasedMarkedCount = pendingDecisions.filter { $0.willDelete }.count
        if let session = activeSession {
            session.pendingXP = 0
            session.pendingGems = 0
        }
        combo = 0
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
    /// ordering never changes what the player may decide). Targeted dives
    /// (everything but a hand-picked hunt) redeal the unseen queue before every
    /// room (`arrangeNextRoom`), so this lead only holds for hand-picked hunts.
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
                contentHash: cached[item.id]?.contentHash,
                isVideo: item.kind == .video,
                signature: item.signature
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
        // Fold clusters into one group encounter each (representative = oldest); every copy takes
        // the cluster's verdict so rewards, quests and the bestiary agree with the card.
        let folded = DuplicateGroupBuilder.fold(items: items, library: library)
        let classified = folded.items
        let groups = folded.groups
        let nonRepresentatives = folded.nonRepresentatives

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

    /// Monsters marked for deletion so far this room (awaiting confirmation
    /// at the Room Summary).
    var markedCount: Int {
        pendingDecisions.filter { $0.willDelete }.count
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
            let completedBefore = Set(quests.filter(\.completed).map(\.id))
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
            // Quest payouts are SECURED: any quest this confirmation completed
            // pays immediately, and its progress can never be lost to a later defeat.
            let newlyCompleted = quests.filter { !completedBefore.contains($0.id) && $0.completed }
            let questXP = newlyCompleted.reduce(0) { $0 + $1.rewardXP }
            let questGems = newlyCompleted.reduce(0) { $0 + $1.rewardGems }
            if questXP > 0 || questGems > 0 {
                bank(xp: questXP, gems: questGems, hero: hero)
                sessionXP += questXP
                sessionGems += questGems
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
            // Dives after the first start their bonus ledger fresh too.
            diveBonusXP = 0
            diveBonusGems = 0
            pendingBonusXP = 0
            pendingBonusGems = 0
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
            // The dive completed: pending Perfect Room bonuses convert to
            // secured, plus the Full Dive bonus for every room cleared.
            applyFullDiveBonus(hero: hero)
            phase = .sessionComplete
            finalizeSession()
            CombatLiveActivityService.shared.end()
            return
        }
        loadNextRoom()
    }

    /// Banks every SECURED reward the player confirmed in the current room: base XP
    /// (captured at swipe time, so combo / class / seasonal bonuses all carry
    /// through), gems, and lifetime purge counters. Any items toggled off in the
    /// summary are simply excluded. Perfect Room bonuses accrue as PENDING here —
    /// they only pay out when the dive completes.
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

        bank(xp: roomXP, gems: roomGems, hero: hero)

        // Perfect Room bonus is PENDING, not secured: it accrues for the dive's
        // end and only converts to secured if the dive completes.
        if perfectRoom {
            pendingBonusXP += Self.perfectRoomBonusXP
            pendingBonusGems += Self.perfectRoomBonusGems
            if let session = activeSession {
                session.pendingXP += Self.perfectRoomBonusXP
                session.pendingGems += Self.perfectRoomBonusGems
            }
        }
    }

    /// Banks XP and gems onto the hero's lifetime totals, applying any
    /// level-ups. A single payout can pop multiple levels; +10 max HP each,
    /// full heal on level-up. Shared by secured room rewards, quest payouts,
    /// and converted dive bonuses.
    private func bank(xp: Int, gems: Int, hero: Hero) {
        hero.totalXP += xp
        hero.gems += gems
        while hero.totalXP >= Hero.xpForLevel(hero.level + 1) {
            hero.level += 1
            hero.maxHP += 10
            hero.currentHP = hero.maxHP
        }
    }

    /// Converts all PENDING bonuses into SECURED rewards because the dive
    /// completed: accrued Perfect Room bonuses plus the Full Dive bonus for
    /// every room cleared. Mirrors onto the session record and clears pending.
    private func applyFullDiveBonus(hero: Hero) {
        let bonusXP = pendingBonusXP + roomsCompleted * Self.fullDiveBonusXPPerRoom
        let bonusGems = pendingBonusGems + roomsCompleted * Self.fullDiveBonusGemsPerRoom
        guard bonusXP > 0 || bonusGems > 0 else { return }

        bank(xp: bonusXP, gems: bonusGems, hero: hero)
        sessionXP += bonusXP
        sessionGems += bonusGems
        diveBonusXP = bonusXP
        diveBonusGems = bonusGems
        if let session = activeSession {
            session.xpEarned += bonusXP
            session.gemsEarned += bonusGems
            session.pendingXP = 0
            session.pendingGems = 0
        }
        pendingBonusXP = 0
        pendingBonusGems = 0
        try? sessionContext?.save()
    }
}
