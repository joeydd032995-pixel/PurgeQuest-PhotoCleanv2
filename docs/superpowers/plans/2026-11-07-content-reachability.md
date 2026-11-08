# Content Reachability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove that every monster, quest, achievement and seasonal cosmetic in PurgeQuest can actually be reached by a player, and fix the places where it cannot.

**Architecture:** A witness-table test builds, for each of the 36 `MonsterType`s, a situation the classifier turns into exactly that monster, then audits quests and seasonal bonuses against it. Three real defects the audit exposes are fixed with small, pure changes: duplicate copies take their cluster's monster, the Duplicate Dragon quest and achievement count the whole Duplicate Dragons family, and the Armory sells seasonal gear only while its event runs.

**Tech Stack:** Swift 5 language mode, SwiftUI, SwiftData, Swift Testing (`import Testing`). No new dependencies.

**Roadmap item:** 1 of 4 ("Fix unreachable content"). Recommended order for the four plans: this one, then duplicate detection, then Shaky Ghost motion analysis, then the Core ML blur model. The plans touch different code and can also land in any order; where one edits a line another adds, the step says so.

## What the code actually does today (verified against the tree, not the README)

The README's Known Issues #1 and #2 are stale. Reading the source:

| README says | The code says |
|---|---|
| `duplicateDragon` is "never assigned" | Assigned: `MonsterClassifier.monsterType(for:members:)` ends with `return .duplicateDragon` (`MonsterClassifier.swift:368`). |
| `corruptedCodec` is "never assigned" | Assigned: `classifyVideo` returns it for `duration <= 0` and for `loadFailed` (`MonsterClassifier.swift:217-237`), with tests in `BestiaryTests.swift`. |
| 7 seasonal cosmetic IDs "don't exist" | All 9 exist: `GameDataService.swift:187-195`, with art in `MiniAvatar*.swift` and `SpriteSheetView.swift`. `tools/ci/repo_guard.py` check 4 already fails CI if one goes missing. |
| Seasonal events "cannot grant" their cosmetics | Closer to the truth, for a different reason: nothing reads `exclusiveCosmeticIDs`. Only `SpriteArtTests` does. The Armory (`ShopView.swift`) is unaware of events, so event gear is on sale all year and an event never surfaces its own gear. |

Three defects are real and are what this plan fixes:

1. **Only a cluster's oldest copy takes the cluster's monster.** `MonsterClassifier.classify` returns a verdict for the oldest copy only (`classifications[oldest.id]`, `MonsterClassifier.swift:81`), and `CombatViewModel.classifyAndGroup` applies just those. The other copies keep the provisional monster the library builder gave each alone (usually a Blur Beast). `commitGroupDecisions` then pays XP from `member.monsterType`, `confirmRoom` writes `DeletedMediaRecord(monsterType: item.monsterType)` and advances quests by the same field, and `BestiaryService.recordEncounters` counts it. A six-copy Hoard Hydra is booked as one Hoard Hydra and five Blur Beasts.
2. **The Duplicate Dragon quest and "Duplicate Slayer" achievement count the literal `.duplicateDragon` only** (`GameDataService.swift:241`, `:295`). That is one of eight duplicate monsters, and it is the fallthrough case: it is summoned only by a group of two to five copies captured one to thirty days apart (or with no capture dates). Most real groups are pairs, bursts, edited copies or hoards. Combined with defect 1, the quest and achievement are practically unwinnable.
3. **Seasonal gear is not linked to its event** (see the table).

## Verification environment

- **Linux harness** (pure Foundation code only): needs Swift 6.2 or newer. `https://download.swift.org/swift-6.2.1-release/ubuntu2404/swift-6.2.1-RELEASE/swift-6.2.1-RELEASE-ubuntu24.04.tar.gz` for Ubuntu 24.04. Run `SWIFT_BIN=/path/to/swift tools/swift_harness/run.sh --filter <Suite>`. Nothing in this plan runs there; every test below needs `MediaItem`, SwiftData or SwiftUI types.
- **Xcode** (all tests in this plan): `xcodebuild -project ios/PurgeQuest.xcodeproj -scheme PurgeQuest -configuration Debug -destination 'platform=iOS Simulator,name=<an iOS 18+ iPhone>' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:PurgeQuestTests/<Suite> test`. `tools/ci/xcode-test.sh` runs the whole unit-test target on whichever simulator it finds.
- **No Mac available** (for example a cloud sandbox): push the branch and read the "iOS Unit Tests" workflow on the pull request. Do not report an Xcode step as passed unless it ran.
- **What was verified while writing this plan:** every edit's `old` text was applied to a copy of the real files and matched exactly once; every changed file was syntax-checked with `swiftc -parse`; `tools/ci/repo_guard.py` stays green. The code was **not** compiled against the Apple SDKs (no Xcode in the planning environment), so a compile error on the first Xcode run is possible; fix it in place and say so in the commit.

## Global Constraints

- iOS 18.0+ deployment target; Swift 5 language mode; the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`, so declarations are main-actor unless marked `nonisolated`.
- The app is fully offline with no third-party dependencies (`tools/ci/repo_guard.py` checks 1 and 2).
- Deletion stays recoverable and goes through `PhotoLibraryService` only (`repo_guard.py` check 3).
- SwiftData schema changes are additive. This plan makes none.
- New Swift files under `ios/PurgeQuest/` and `ios/PurgeQuestTests/` are picked up automatically (Xcode synchronized folders). Do not edit `project.pbxproj`.
- Tests use Swift Testing (`@Test`, `#expect`), and suites that touch app types are `@MainActor`, as in `BestiaryTests.swift`.
- Commit messages are plain sentences in the imperative, as in `git log`.

## Decisions this plan makes (change them before executing if you disagree)

1. **The Duplicate Dragon quest and achievement count the whole Duplicate Dragons family.** The family is literally named "Duplicate Dragons", so the existing copy ("Vanquish 5 Duplicate Dragons.") reads correctly. Alternative: retire them. Rejected because the content is good and the fix is small.
2. **Copies take the group's monster everywhere, XP included.** A copy of a Hoard Hydra now pays Hoard Hydra XP (75) instead of Blur Beast XP (30). The card, the reward and the record agree, but duplicates now pay more than before. If you want the old payout, the smallest alternative is to price copies at the solo type they began as, which needs that type carried on `PendingDecision`; it keeps the card and the payout disagreeing, so it is not done here.
3. **Seasonal gear can be bought only while its event runs**, and stays equippable forever once owned. Alternative: keep it on sale all year and only highlight it during the event; to switch, make `SeasonalCatalog.isPurchasable` always return `true`.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `ios/PurgeQuest/Services/GameDataService.swift` | modify | Expose `dailyQuestPool`; family-aware quest matching and achievement counting |
| `ios/PurgeQuest/Services/MonsterType+Counting.swift` | create | `MonsterType.counts(as:)`: which kills count toward content written for a monster |
| `ios/PurgeQuest/Services/DuplicateGroupBuilder.swift` | create | Folds clusters into groups whose copies share the cluster's monster |
| `ios/PurgeQuest/ViewModels/CombatViewModel.swift` | modify | Use the builder |
| `ios/PurgeQuest/Services/SeasonalCatalog.swift` | create | Which event owns a cosmetic; whether it can be bought today |
| `ios/PurgeQuest/Views/Shop/ShopView.swift` | modify | Seasonal shelf, lock label, purchase guard |
| `ios/PurgeQuestTests/ContentReachabilityTests.swift` | create | The witness table and content audits |
| `ios/PurgeQuestTests/DuplicateGroupBuilderTests.swift` | create | Group typing |
| `ios/PurgeQuestTests/MonsterTypeCountingTests.swift` | create | Family-aware quests and achievement |
| `ios/PurgeQuestTests/SeasonalCatalogTests.swift` | create | Seasonal rules and catalog integrity |
| `README.md` | modify | Correct Known Issues #1 and #2 and the roadmap |

---

### Task 1: Prove every monster can be summoned

**Files:**
- Modify: `ios/PurgeQuest/Services/GameDataService.swift`
- Create: `ios/PurgeQuestTests/ContentReachabilityTests.swift`

**Interfaces:**
- Produces: `GameDataService.dailyQuestPool: [Quest]` (static, main actor): every quest the daily draw can pick from.

- [ ] **Step 1: Write the witness table and content audits**

Create `ios/PurgeQuestTests/ContentReachabilityTests.swift`:

```swift
//
//  ContentReachabilityTests.swift
//  PurgeQuestTests
//
//  Every monster has a way to be summoned, and every quest and seasonal bonus names only monsters
//  that can be. The table below builds, for each MonsterType, a situation the classifier turns into
//  exactly that monster. A new MonsterType without a witness fails the first test, so game content
//  can never again point at a monster nothing summons.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct ContentReachabilityTests {

    // MARK: - Building blocks

    private static let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let day: TimeInterval = 86_400
    private static let lookAlike: UInt64 = 0xAAAA_5555_AAAA_5555

    private func item(
        _ id: String = "a",
        kind: MediaKind = .photo,
        width: Int = 4000,
        height: Int = 3000,
        bytes: Int64 = 2_000_000,
        duration: Double = 0,
        capturedAt: Date? = ContentReachabilityTests.epoch,
        screenshot: Bool = false,
        livePhoto: Bool = false,
        screenRecording: Bool = false,
        looping: Bool = false,
        sharpness: Double? = 60,
        luminance: Double? = 0.5
    ) -> MediaItem {
        MediaItem(
            id: id, kind: kind, creationDate: capturedAt, pixelWidth: width, pixelHeight: height,
            durationSeconds: duration, estimatedBytes: bytes, isFavorite: false, playbackStyle: 1,
            isScreenshot: screenshot, isScreenRecording: screenRecording, isLivePhoto: livePhoto,
            isLooping: looping, sharpness: sharpness, luminance: luminance
        )
    }

    /// What the classifier calls a lone item, judged one day after the epoch.
    private func alone(_ item: MediaItem) -> MonsterType {
        MonsterClassifier.classifySolo(item, now: Self.epoch.addingTimeInterval(Self.day)).monsterType
    }

    private func clip(
        duration: Double = 30, bytes: Int64 = 20_000_000, width: Int = 1920, height: Int = 1080,
        luminances: [Double]? = nil, screenRecording: Bool = false, looping: Bool = false
    ) -> MonsterType {
        var video = item("clip", kind: .video, width: width, height: height, bytes: bytes,
                         duration: duration, screenRecording: screenRecording, looping: looping)
        if let luminances { video.frameSignals = VideoFrameSignals.evaluate(luminances: luminances) }
        return alone(video)
    }

    /// What the classifier calls the oldest of several look-alike photos captured `gap` seconds apart.
    private func summonedByCopies(
        count: Int, gap: TimeInterval, screenshots: Bool = false, cropped: Bool = false, identicalFiles: Bool = false
    ) -> MonsterType? {
        var items: [MediaItem] = []
        var prints: [MediaFingerprint] = []
        for i in 0..<count {
            let date = Self.epoch.addingTimeInterval(Double(i) * gap)
            let width = cropped && i == 1 ? 3000 : 4000
            let height = cropped && i == 1 ? 2000 : 3000
            let size = Int64(2_000_000 + i * 1_001)
            let copy = item("copy\(i)", width: width, height: height, bytes: size, capturedAt: date, screenshot: screenshots)
            items.append(copy)
            prints.append(MediaFingerprint(
                assetID: copy.id, byteSize: size, pixelWidth: width, pixelHeight: height, durationSeconds: 0,
                creationDate: date, isFavorite: false, isScreenshot: screenshots, hasEdits: false,
                isScreenRecording: false, dHash: Self.lookAlike, sharpness: 60,
                contentHash: identicalFiles ? "same" : nil
            ))
        }
        return MonsterClassifier.classify(items: items, fingerprints: prints).classifications["copy0"]?.monsterType
    }

    /// One witness per monster: the monster we expect, and the one the classifier actually gives.
    private func witnesses() -> [(expected: MonsterType, actual: MonsterType?)] {
        var w: [(expected: MonsterType, actual: MonsterType?)] = []

        // Duplicate Dragons: clusters of look-alikes.
        w.append((.perfectPairWyrmling, summonedByCopies(count: 2, gap: 3_600, identicalFiles: true)))
        w.append((.duplicateDragon, summonedByCopies(count: 2, gap: 10 * Self.day)))
        w.append((.burstHydra, summonedByCopies(count: 3, gap: 1)))
        w.append((.cloneChimera, summonedByCopies(count: 2, gap: 60, cropped: true)))
        w.append((.screenshotTwin, summonedByCopies(count: 2, gap: Self.day, screenshots: true)))
        w.append((.downloadDrake, summonedByCopies(count: 2, gap: 3_600)))
        w.append((.albumEcho, summonedByCopies(count: 2, gap: 60 * Self.day)))
        w.append((.hoardHydra, summonedByCopies(count: 6, gap: Self.day)))

        // Photos on their own.
        w.append((.blurBeast, alone(item(sharpness: 3))))
        w.append((.screenshotSpecter, alone(item(screenshot: true))))
        w.append((.lowQualityLich, alone(item(width: 1_000, height: 3_000))))
        w.append((.darkWraith, alone(item(luminance: 0.1))))
        w.append((.thumbGoblin, alone(item(width: 400, height: 300))))
        w.append((.livePhotoLycan, alone(item(livePhoto: true))))
        w.append((.ancientArchive, alone(item(capturedAt: Self.epoch.addingTimeInterval(-4 * 365 * Self.day)))))
        w.append((.panoramaColossus, alone(item(width: 10_000, height: 3_000))))
        w.append((.staticHusk, alone(item(bytes: 0))))
        var unloadable = item()
        unloadable.loadFailed = true
        w.append((.nullPortrait, alone(unloadable)))
        var document = item()
        document.visionSignals = VisionTextSignals(characterCount: 500, regionCount: 8, hasBarcode: false)
        w.append((.tomeWraith, alone(document)))
        var ticket = item()
        ticket.visionSignals = VisionTextSignals(characterCount: 0, regionCount: 0, hasBarcode: true)
        w.append((.sigilSpecter, alone(ticket)))

        // Videos.
        w.append((.gigabyteGorgon, clip(bytes: 1_200_000_000)))
        w.append((.memoryHogMinotaur, clip(bytes: 600_000_000)))
        w.append((.fourKKraken, clip(width: 3_840, height: 2_160)))
        w.append((.longTakeLeviathan, clip(duration: 200)))
        w.append((.screenRecordingShade, clip(screenRecording: true)))
        w.append((.timelapsePhantom, clip(looping: true)))
        w.append((.flickerWraith, clip(duration: 10, luminances: [0.2, 0.9, 0.15])))
        w.append((.framedPhantom, clip(duration: 10, luminances: [0.5, 0.501, 0.502])))
        w.append((.shakyGhost, clip(duration: 10, luminances: [0.3, 0.5, 0.35])))
        w.append((.pocketPoltergeist, clip(duration: 1.2)))
        w.append((.boringBlooper, clip(duration: 3.5)))
        w.append((.videoVampire, clip(bytes: 150_000_000)))
        w.append((.mistWraith, clip(duration: 10)))
        w.append((.tatterWraith, clip(duration: 45)))
        w.append((.voidWraith, clip(duration: 90)))
        w.append((.corruptedCodec, clip(duration: 0)))
        return w
    }

    // MARK: - The roster

    @Test func everyMonsterHasExactlyOneWitness() {
        let expected = witnesses().map(\.expected)
        #expect(Set(expected) == Set(MonsterType.allCases), "monsters without a witness: \(Set(MonsterType.allCases).subtracting(expected))")
        #expect(expected.count == Set(expected).count, "a monster has two witnesses")
    }

    @Test func theClassifierSummonsEveryMonster() {
        for witness in witnesses() {
            #expect(witness.actual == witness.expected, "expected \(witness.expected), the classifier gave \(String(describing: witness.actual))")
        }
    }

    // MARK: - Content that names monsters

    @Test func everyQuestNamesAMonsterItsKindCanSlay() {
        let pool = GameDataService.dailyQuestPool
        #expect(!pool.isEmpty)
        for quest in pool {
            switch quest.kind {
            case .photoSlay:
                let target = quest.monsterType
                #expect(target?.kind == .photo, "\(quest.title) is a photo quest but names \(String(describing: target))")
            case .videoSlay:
                let target = quest.monsterType
                #expect(target?.kind == .video, "\(quest.title) is a video quest but names \(String(describing: target))")
            case .mbFreed, .anySlay:
                #expect(quest.monsterType == nil, "\(quest.title) should not name a monster")
            }
        }
    }

    @Test func everySeasonalBonusNamesAMonsterThatCanBeSummoned() {
        let summonable = Set(witnesses().filter { $0.actual == $0.expected }.map(\.expected))
        for event in SeasonalEventService.allEvents {
            #expect(!event.bonusMonsters.isEmpty, "\(event.name) rewards no monster")
            for monster in event.bonusMonsters {
                #expect(summonable.contains(monster), "\(event.name) rewards \(monster), which nothing summons")
            }
        }
    }
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `xcodebuild … -only-testing:PurgeQuestTests/ContentReachabilityTests test`
Expected: FAIL to compile with `type 'GameDataService' has no member 'dailyQuestPool'`.

- [ ] **Step 3: Expose the quest pool**

In `ios/PurgeQuest/Services/GameDataService.swift`, inside `refreshDailyQuestsIfNeeded`, replace the inline pool:

```swift
        let pool: [Quest] = [
            Quest(title: "Blur Beast Hunter",      subtitle: "Slay 8 blurry photo monsters.",      kind: .photoSlay, monsterType: .blurBeast,      targetCount: 8, rewardXP: 120, rewardGems: 60),
            Quest(title: "Duplicate Dragon Slayer", subtitle: "Vanquish 5 Duplicate Dragons.",     kind: .photoSlay, monsterType: .duplicateDragon, targetCount: 5, rewardXP: 160, rewardGems: 80),
            Quest(title: "Video Vampire Purge",    subtitle: "Banish 6 Video Vampires.",           kind: .videoSlay, monsterType: .videoVampire,    targetCount: 6, rewardXP: 200, rewardGems: 100),
            Quest(title: "Long-Take Leviathan",    subtitle: "Defeat 3 Leviathans over 2 minutes.", kind: .videoSlay, monsterType: .longTakeLeviathan, targetCount: 3, rewardXP: 240, rewardGems: 140),
            Quest(title: "Storage Liberation",     subtitle: "Free 500 MB in a single session.",   kind: .mbFreed,    monsterType: nil,             targetCount: 500, rewardXP: 180, rewardGems: 120),
            Quest(title: "Dungeon Clear",          subtitle: "Defeat 25 monsters of any kind.",    kind: .anySlay,    monsterType: nil,             targetCount: 25, rewardXP: 150, rewardGems: 70),
            Quest(title: "Memory Hog Hunter",      subtitle: "Slay 2 Memory Hog Minotaurs.",       kind: .videoSlay,  monsterType: .memoryHogMinotaur, targetCount: 2, rewardXP: 220, rewardGems: 140)
        ]
```

with:

```swift
        let pool = dailyQuestPool
```

Then replace the line that opens `refreshDailyQuestsIfNeeded`:

```swift
    static func refreshDailyQuestsIfNeeded(in context: ModelContext) {
```

with the pool itself, moved above it so tests can read it:

```swift
    /// Every quest the daily draw can pick from. Exposed so tests can audit that each one can be completed.
    static var dailyQuestPool: [Quest] {
        [
            Quest(title: "Blur Beast Hunter",      subtitle: "Slay 8 blurry photo monsters.",      kind: .photoSlay, monsterType: .blurBeast,      targetCount: 8, rewardXP: 120, rewardGems: 60),
            Quest(title: "Duplicate Dragon Slayer", subtitle: "Vanquish 5 Duplicate Dragons.",     kind: .photoSlay, monsterType: .duplicateDragon, targetCount: 5, rewardXP: 160, rewardGems: 80),
            Quest(title: "Video Vampire Purge",    subtitle: "Banish 6 Video Vampires.",           kind: .videoSlay, monsterType: .videoVampire,    targetCount: 6, rewardXP: 200, rewardGems: 100),
            Quest(title: "Long-Take Leviathan",    subtitle: "Defeat 3 Leviathans over 2 minutes.", kind: .videoSlay, monsterType: .longTakeLeviathan, targetCount: 3, rewardXP: 240, rewardGems: 140),
            Quest(title: "Storage Liberation",     subtitle: "Free 500 MB in a single session.",   kind: .mbFreed,    monsterType: nil,             targetCount: 500, rewardXP: 180, rewardGems: 120),
            Quest(title: "Dungeon Clear",          subtitle: "Defeat 25 monsters of any kind.",    kind: .anySlay,    monsterType: nil,             targetCount: 25, rewardXP: 150, rewardGems: 70),
            Quest(title: "Memory Hog Hunter",      subtitle: "Slay 2 Memory Hog Minotaurs.",       kind: .videoSlay,  monsterType: .memoryHogMinotaur, targetCount: 2, rewardXP: 220, rewardGems: 140)
        ]
    }

    static func refreshDailyQuestsIfNeeded(in context: ModelContext) {
```

- [ ] **Step 4: Run it and confirm it passes**

Run: `xcodebuild … -only-testing:PurgeQuestTests/ContentReachabilityTests test`
Expected: PASS, four tests. If a witness fails, the message names the monster and what the classifier returned instead; fix the witness only if the classifier's behaviour is intended, otherwise you have found an unreachable monster and should fix the classifier.

- [ ] **Step 5: Commit**

```bash
git add ios/PurgeQuest/Services/GameDataService.swift ios/PurgeQuestTests/ContentReachabilityTests.swift
git commit -m "Test that every monster can be summoned and every quest is completable"
```

---

### Task 2: Copies take their cluster's monster

**Files:**
- Create: `ios/PurgeQuest/Services/DuplicateGroupBuilder.swift`
- Modify: `ios/PurgeQuest/ViewModels/CombatViewModel.swift`
- Create: `ios/PurgeQuestTests/DuplicateGroupBuilderTests.swift`

**Interfaces:**
- Consumes: `ClassifiedLibrary` (`MonsterClassifier.swift`), `MediaItem`, `DuplicateGroup`.
- Produces: `DuplicateGroupBuilder.fold(items: [MediaItem], library: ClassifiedLibrary) -> DuplicateGroupBuilder.Result` with `items: [MediaItem]`, `groups: [String: DuplicateGroup]`, `nonRepresentatives: Set<String>`.

- [ ] **Step 1: Write the failing tests**

Create `ios/PurgeQuestTests/DuplicateGroupBuilderTests.swift`:

```swift
//
//  DuplicateGroupBuilderTests.swift
//  PurgeQuestTests
//
//  Every copy in a duplicate group is booked as the monster the group card shows.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct DuplicateGroupBuilderTests {

    private static let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func photo(_ id: String, bytes: Int64, screenshot: Bool = false, favorite: Bool = false) -> MediaItem {
        MediaItem(
            id: id, kind: .photo, creationDate: Self.epoch, pixelWidth: 4000, pixelHeight: 3000,
            durationSeconds: 0, estimatedBytes: bytes, isFavorite: favorite, playbackStyle: 1,
            isScreenshot: screenshot, sharpness: 60, luminance: 0.5
        )
    }

    private func print(_ item: MediaItem, content: String?) -> MediaFingerprint {
        MediaFingerprint(
            assetID: item.id, byteSize: item.estimatedBytes, pixelWidth: item.pixelWidth,
            pixelHeight: item.pixelHeight, durationSeconds: 0, creationDate: item.creationDate,
            isFavorite: item.isFavorite, isScreenshot: item.isScreenshot, hasEdits: false,
            isScreenRecording: false, dHash: nil, sharpness: item.sharpness, contentHash: content
        )
    }

    @Test func everyCopyOfAGroupTakesTheClustersMonster() throws {
        // Three identical files. Each starts as the Blur Beast the library builder gave it alone.
        let items = [photo("c0", bytes: 2_000_000), photo("c1", bytes: 2_000_001), photo("c2", bytes: 2_000_002)]
        #expect(items.allSatisfy { $0.monsterType == .blurBeast })
        let library = MonsterClassifier.classify(items: items, fingerprints: items.map { print($0, content: "same") })
        let clusterMonster = try #require(library.classifications["c0"]?.monsterType)
        #expect(clusterMonster.family == .duplicateDragons)

        let folded = DuplicateGroupBuilder.fold(items: items, library: library)
        let group = try #require(folded.groups["c0"])
        #expect(group.members.map(\.id) == ["c0", "c1", "c2"])
        #expect(group.members.allSatisfy { $0.monsterType == clusterMonster })
        #expect(folded.items.allSatisfy { $0.monsterType == clusterMonster })
        #expect(folded.items.allSatisfy { $0.classification?.monsterType == clusterMonster })
        #expect(folded.nonRepresentatives == ["c1", "c2"])
    }

    @Test func aLoneItemKeepsItsOwnVerdict() throws {
        let twins = [photo("t0", bytes: 3_000_000), photo("t1", bytes: 3_000_001)]
        let shot = photo("shot", bytes: 400_000, screenshot: true)
        let items = twins + [shot]
        let prints = twins.map { print($0, content: "same") } + [print(shot, content: nil)]
        let library = MonsterClassifier.classify(items: items, fingerprints: prints)
        let folded = DuplicateGroupBuilder.fold(items: items, library: library)

        let kept = try #require(folded.items.first { $0.id == "shot" })
        #expect(kept.monsterType == .screenshotSpecter)
        #expect(folded.groups.keys.sorted() == ["t0"])
        #expect(!folded.nonRepresentatives.contains("shot"))
    }

    @Test func theSuggestedKeeperRidesAlongWithoutBeingDecided() throws {
        let items = [photo("c0", bytes: 2_000_000), photo("c1", bytes: 2_000_001, favorite: true)]
        let library = MonsterClassifier.classify(items: items, fingerprints: items.map { print($0, content: "same") })
        let group = try #require(DuplicateGroupBuilder.fold(items: items, library: library).groups["c0"])
        #expect(group.survivorID == "c1")
    }

    @Test func aBatchWithoutDuplicatesIsJustClassified() {
        let items = [photo("a", bytes: 1_000_000), photo("b", bytes: 2_000_000)]
        let library = MonsterClassifier.classify(items: items, fingerprints: items.map { print($0, content: nil) })
        let folded = DuplicateGroupBuilder.fold(items: items, library: library)
        #expect(folded.groups.isEmpty)
        #expect(folded.nonRepresentatives.isEmpty)
        #expect(folded.items.count == 2)
    }
}
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `xcodebuild … -only-testing:PurgeQuestTests/DuplicateGroupBuilderTests test`
Expected: FAIL to compile with `cannot find 'DuplicateGroupBuilder' in scope`.

- [ ] **Step 3: Create the builder**

Create `ios/PurgeQuest/Services/DuplicateGroupBuilder.swift`:

```swift
//
//  DuplicateGroupBuilder.swift
//  PurgeQuest
//
//  Turns a classified batch into duplicate encounters. Each cluster becomes one group whose copies
//  all carry the cluster's verdict, so whatever the player does to a copy (XP, quest progress, the
//  deletion log, the bestiary) is booked against the monster the group card shows, not against
//  whatever that copy would have been on its own.
//

import Foundation

enum DuplicateGroupBuilder {

    struct Result {
        /// Every item of the batch. Cluster copies carry their cluster's monster type and verdict.
        let items: [MediaItem]
        /// One group per cluster, keyed by the oldest copy's asset ID.
        let groups: [String: DuplicateGroup]
        /// Copies shown inside a group instead of as encounters of their own.
        let nonRepresentatives: Set<String>
    }

    static func fold(items: [MediaItem], library: ClassifiedLibrary) -> Result {
        var typed = items
        var indexByID: [String: Int] = [:]
        for index in typed.indices { indexByID[typed[index].id] = index }

        // The classifier gives every solo item its own verdict and each cluster's oldest copy the
        // cluster's verdict.
        for index in typed.indices {
            if let verdict = library.classifications[typed[index].id] {
                typed[index].classification = verdict
                typed[index].monsterType = verdict.monsterType
            }
        }

        var groups: [String: DuplicateGroup] = [:]
        var nonRepresentatives = Set<String>()
        for cluster in library.clusters where cluster.memberIDs.count >= 2 {
            let present = cluster.memberIDs.compactMap { indexByID[$0] }
            guard let first = present.first else { continue }
            let representative = typed[first]

            // The other copies take the representative's verdict.
            for index in present.dropFirst() {
                typed[index].classification = representative.classification
                typed[index].monsterType = representative.monsterType
            }
            groups[representative.id] = DuplicateGroup(
                representativeID: representative.id,
                members: present.map { typed[$0] },
                survivorID: library.recommendedSurvivorIDs[representative.id]
            )
            nonRepresentatives.formUnion(cluster.memberIDs.dropFirst())
        }
        return Result(items: typed, groups: groups, nonRepresentatives: nonRepresentatives)
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `xcodebuild … -only-testing:PurgeQuestTests/DuplicateGroupBuilderTests test`
Expected: PASS, four tests.

- [ ] **Step 5: Use it in the dive**

In `ios/PurgeQuest/ViewModels/CombatViewModel.swift`, in `classifyAndGroup`, replace the block that applies verdicts and folds clusters:

```swift
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
```

with:

```swift
        let library = MonsterClassifier.classify(items: items, fingerprints: fingerprints)
        // Fold clusters into one group encounter each (representative = oldest); every copy takes
        // the cluster's verdict so rewards, quests and the bestiary agree with the card.
        let folded = DuplicateGroupBuilder.fold(items: items, library: library)
        let classified = folded.items
        let groups = folded.groups
        let nonRepresentatives = folded.nonRepresentatives
```

Everything after it in the function (theme, ordering) keeps using `classified`, `groups` and `nonRepresentatives`. `byID`, which the removed block defined, is not used anywhere else in the function.

- [ ] **Step 6: Run the whole unit-test target**

Run: `tools/ci/xcode-test.sh` (or `xcodebuild … -only-testing:PurgeQuestTests test`)
Expected: PASS. `BestiaryTests` still passes because it exercises `MonsterClassifier` directly, not the view model.

- [ ] **Step 7: Commit**

```bash
git add ios/PurgeQuest/Services/DuplicateGroupBuilder.swift ios/PurgeQuest/ViewModels/CombatViewModel.swift ios/PurgeQuestTests/DuplicateGroupBuilderTests.swift
git commit -m "Book every copy in a duplicate group as the group's monster"
```

---

### Task 3: The Duplicate Dragon quest and achievement count the whole family

**Files:**
- Create: `ios/PurgeQuest/Services/MonsterType+Counting.swift`
- Modify: `ios/PurgeQuest/Services/GameDataService.swift`
- Create: `ios/PurgeQuestTests/MonsterTypeCountingTests.swift`

**Interfaces:**
- Consumes: `MonsterType.family`, `GameDataService.updateQuests(_:for:mbFreedThisAction:)`, `GameDataService.syncAchievements(hero:in:)`.
- Produces: `MonsterType.counts(as target: MonsterType) -> Bool`.

- [ ] **Step 1: Write the failing tests**

Create `ios/PurgeQuestTests/MonsterTypeCountingTests.swift`:

```swift
//
//  MonsterTypeCountingTests.swift
//  PurgeQuestTests
//
//  Quests and achievements written for the Duplicate Dragon count the whole Duplicate Dragons family.
//

import Testing
import Foundation
import SwiftData
@testable import PurgeQuest

@MainActor
struct MonsterTypeCountingTests {

    private let family: [MonsterType] = [
        .perfectPairWyrmling, .duplicateDragon, .burstHydra, .cloneChimera,
        .screenshotTwin, .downloadDrake, .albumEcho, .hoardHydra
    ]

    @Test func theDuplicateDragonTargetCountsTheWholeFamilyAndNothingElse() {
        #expect(Set(family) == Set(MonsterType.allCases.filter { $0.family == .duplicateDragons }))
        for type in MonsterType.allCases {
            #expect(type.counts(as: .duplicateDragon) == family.contains(type), "\(type)")
        }
    }

    @Test func everyOtherTargetMeansExactlyThatMonster() {
        #expect(MonsterType.blurBeast.counts(as: .blurBeast))
        #expect(!MonsterType.darkWraith.counts(as: .blurBeast))
        #expect(!MonsterType.burstHydra.counts(as: .hoardHydra))
        #expect(MonsterType.hoardHydra.counts(as: .hoardHydra))
    }

    @Test func aDuplicateDragonQuestProgressesOnAnyCopy() {
        let quest = Quest(title: "Duplicate Dragon Slayer", subtitle: "", kind: .photoSlay,
                          monsterType: .duplicateDragon, targetCount: 3, rewardXP: 1, rewardGems: 1)
        GameDataService.updateQuests([quest], for: .burstHydra, mbFreedThisAction: 1)
        GameDataService.updateQuests([quest], for: .hoardHydra, mbFreedThisAction: 1)
        GameDataService.updateQuests([quest], for: .blurBeast, mbFreedThisAction: 1)
        #expect(quest.currentCount == 2)
        #expect(!quest.completed)
        GameDataService.updateQuests([quest], for: .duplicateDragon, mbFreedThisAction: 1)
        #expect(quest.completed)
    }

    @Test func aBlurBeastQuestIgnoresDuplicates() {
        let quest = Quest(title: "Blur Beast Hunter", subtitle: "", kind: .photoSlay,
                          monsterType: .blurBeast, targetCount: 2, rewardXP: 1, rewardGems: 1)
        GameDataService.updateQuests([quest], for: .burstHydra, mbFreedThisAction: 1)
        #expect(quest.currentCount == 0)
        GameDataService.updateQuests([quest], for: .blurBeast, mbFreedThisAction: 1)
        #expect(quest.currentCount == 1)
    }

    @Test func theDuplicateSlayerAchievementCountsEveryCopy() throws {
        let schema = Schema([
            Hero.self, Achievement.self, CosmeticItem.self, Quest.self, DeletedMediaRecord.self,
            CombatSession.self, SparedMediaRecord.self, MediaFingerprintRecord.self, MonsterSightingRecord.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        context.insert(Achievement(id: "duplicate.slayer", title: "Duplicate Slayer", subtitle: "", iconName: "square.on.square", goal: 50))
        for type in [MonsterType.burstHydra, .burstHydra, .hoardHydra, .duplicateDragon, .blurBeast] {
            context.insert(DeletedMediaRecord(assetIdentifier: UUID().uuidString, mediaKind: .photo, monsterType: type, fileSizeBytes: 1))
        }
        let hero = Hero()
        context.insert(hero)
        try context.save()

        GameDataService.syncAchievements(hero: hero, in: context)

        let achievement = try #require(try context.fetch(FetchDescriptor<Achievement>()).first { $0.id == "duplicate.slayer" })
        #expect(achievement.progress == 4)
    }
}
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `xcodebuild … -only-testing:PurgeQuestTests/MonsterTypeCountingTests test`
Expected: FAIL to compile with `value of type 'MonsterType' has no member 'counts'`.

- [ ] **Step 3: Add the rule**

Create `ios/PurgeQuest/Services/MonsterType+Counting.swift`:

```swift
//
//  MonsterType+Counting.swift
//  PurgeQuest
//
//  Which slain monsters count toward a quest or achievement written for a given monster.
//

import Foundation

extension MonsterType {

    /// True when slaying `self` counts toward content written for `target`.
    ///
    /// The Duplicate Dragon quest and achievement were written when the Duplicate Dragon was the
    /// only duplicate monster. The roster has since split duplicates into eight (pairs, bursts,
    /// edited copies, hoards, ...), and most real duplicate groups are one of the others, so content
    /// that names the Duplicate Dragon counts the whole Duplicate Dragons family. Every other
    /// target still means exactly that one monster.
    func counts(as target: MonsterType) -> Bool {
        self == target || (target == .duplicateDragon && family == .duplicateDragons)
    }
}
```

- [ ] **Step 4: Run them again and see the quest and achievement still fail**

Run: `xcodebuild … -only-testing:PurgeQuestTests/MonsterTypeCountingTests test`
Expected: the two rule tests pass; `aDuplicateDragonQuestProgressesOnAnyCopy` fails (`quest.currentCount == 2` is `0`) and `theDuplicateSlayerAchievementCountsEveryCopy` fails (`achievement.progress == 4` is `1`), because `GameDataService` still compares with `==`.

- [ ] **Step 5: Use the rule in quests and the achievement**

In `ios/PurgeQuest/Services/GameDataService.swift`, replace the quest matching in `updateQuests`:

```swift
            case .photoSlay:
                if slainMonster.kind == .photo, q.monsterType == slainMonster {
                    q.currentCount += 1
                }
            case .videoSlay:
                if slainMonster.kind == .video, q.monsterType == slainMonster {
                    q.currentCount += 1
                }
```

with:

```swift
            case .photoSlay:
                if slainMonster.kind == .photo, counts(slainMonster, for: q) {
                    q.currentCount += 1
                }
            case .videoSlay:
                if slainMonster.kind == .video, counts(slainMonster, for: q) {
                    q.currentCount += 1
                }
```

Add the helper above `updateQuests` by replacing its declaration line:

```swift
    static func updateQuests(_ quests: [Quest], for slainMonster: MonsterType, mbFreedThisAction: Double) {
```

with:

```swift
    /// Whether slaying `slain` counts toward the quest's target monster (see `MonsterType.counts(as:)`).
    private static func counts(_ slain: MonsterType, for quest: Quest) -> Bool {
        quest.monsterType.map(slain.counts(as:)) ?? false
    }

    static func updateQuests(_ quests: [Quest], for slainMonster: MonsterType, mbFreedThisAction: Double) {
```

In `syncAchievements`, replace:

```swift
        let dragons = records.filter { $0.monsterType == .duplicateDragon }.count
```

with:

```swift
        let dragons = records.filter { $0.monsterType.counts(as: .duplicateDragon) }.count
```

- [ ] **Step 6: Run the tests and confirm they pass**

Run: `xcodebuild … -only-testing:PurgeQuestTests/MonsterTypeCountingTests -only-testing:PurgeQuestTests/ContentReachabilityTests test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add ios/PurgeQuest/Services/MonsterType+Counting.swift ios/PurgeQuest/Services/GameDataService.swift ios/PurgeQuestTests/MonsterTypeCountingTests.swift
git commit -m "Count every Duplicate Dragon family copy toward the Duplicate Dragon quest and achievement"
```

---

### Task 4: The Armory shows and sells event gear only during its event

**Files:**
- Create: `ios/PurgeQuest/Services/SeasonalCatalog.swift`
- Modify: `ios/PurgeQuest/Views/Shop/ShopView.swift`
- Create: `ios/PurgeQuestTests/SeasonalCatalogTests.swift`

**Interfaces:**
- Consumes: `SeasonalEventService.allEvents`, `SeasonalEvent.exclusiveCosmeticIDs`, `SeasonalEventService.shared.activeEvent`.
- Produces: `SeasonalCatalog.event(owning:) -> SeasonalEvent?` and `SeasonalCatalog.isPurchasable(_:activeEventID:) -> Bool`.

- [ ] **Step 1: Write the failing tests**

Create `ios/PurgeQuestTests/SeasonalCatalogTests.swift`:

```swift
//
//  SeasonalCatalogTests.swift
//  PurgeQuestTests
//
//  Seasonal exclusives exist, belong to one event each, and are sold only while that event runs.
//

import Testing
import SwiftData
@testable import PurgeQuest

@MainActor
struct SeasonalCatalogTests {

    @Test func everyExclusiveBelongsToExactlyOneEvent() {
        var owner: [String: String] = [:]
        for event in SeasonalEventService.allEvents {
            for id in event.exclusiveCosmeticIDs {
                #expect(owner[id] == nil, "\(id) is claimed by \(owner[id] ?? "") and \(event.id)")
                owner[id] = event.id
            }
        }
        #expect(!owner.isEmpty)
    }

    @Test func everyExclusiveIsInTheSeededCatalog() throws {
        let container = try ModelContainer(for: CosmeticItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        GameDataService.seedCosmeticsIfNeeded(in: context)
        let seeded = Set(try context.fetch(FetchDescriptor<CosmeticItem>()).map(\.id))
        for event in SeasonalEventService.allEvents {
            for id in event.exclusiveCosmeticIDs {
                #expect(seeded.contains(id), "\(event.name) offers \(id), which is not in the catalog")
            }
        }
    }

    @Test func eventsOwnTheirItems() {
        #expect(SeasonalCatalog.event(owning: "pet.ghost")?.id == "halloween")
        #expect(SeasonalCatalog.event(owning: "fx.confetti")?.id == "newyear")
        #expect(SeasonalCatalog.event(owning: "weapon.shard") == nil)
    }

    @Test func exclusivesAreBuyableOnlyWhileTheirEventRuns() {
        #expect(SeasonalCatalog.isPurchasable("fx.spectral", activeEventID: "halloween"))
        #expect(!SeasonalCatalog.isPurchasable("fx.spectral", activeEventID: nil))
        #expect(!SeasonalCatalog.isPurchasable("fx.spectral", activeEventID: "newyear"))
    }

    @Test func everythingElseIsAlwaysBuyable() {
        #expect(SeasonalCatalog.isPurchasable("weapon.shard", activeEventID: nil))
        #expect(SeasonalCatalog.isPurchasable("pet.owl", activeEventID: "halloween"))
    }
}
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `xcodebuild … -only-testing:PurgeQuestTests/SeasonalCatalogTests test`
Expected: FAIL to compile with `cannot find 'SeasonalCatalog' in scope`.

- [ ] **Step 3: Create the catalog rules**

Create `ios/PurgeQuest/Services/SeasonalCatalog.swift`:

```swift
//
//  SeasonalCatalog.swift
//  PurgeQuest
//
//  Which cosmetics belong to which seasonal event, and when they may be bought. The catalog seeds
//  every seasonal item all year so that one a player owns never disappears; the rules here decide
//  whether a player who does not own it yet can buy it today.
//

import Foundation

enum SeasonalCatalog {

    /// The event that owns this cosmetic, if it is a seasonal exclusive.
    static func event(owning cosmeticID: String) -> SeasonalEvent? {
        SeasonalEventService.allEvents.first { $0.exclusiveCosmeticIDs.contains(cosmeticID) }
    }

    /// True when the cosmetic can be bought now: it is not a seasonal exclusive, or its event is live.
    static func isPurchasable(_ cosmeticID: String, activeEventID: String?) -> Bool {
        guard let owner = event(owning: cosmeticID) else { return true }
        return owner.id == activeEventID
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `xcodebuild … -only-testing:PurgeQuestTests/SeasonalCatalogTests test`
Expected: PASS, five tests.

- [ ] **Step 5: Wire the Armory**

Apply these ten edits to `ios/PurgeQuest/Views/Shop/ShopView.swift`. Each `old` block occurs exactly once.

5a. Add the filter case. Replace:

```swift
    case video = "Video"
```

with:

```swift
    case video = "Video"
    case seasonal = "Seasonal"
```

5b. Add the event helpers above `filtered`. Replace:

```swift
    private var filtered: [CosmeticItem] {
```

with:

```swift
    /// The seasonal event running today, if any.
    private var activeEvent: SeasonalEvent? { SeasonalEventService.shared.activeEvent }

    /// The Seasonal chip only exists while an event is live.
    private var visibleFilters: [ShopFilter] {
        ShopFilter.allCases.filter { $0 != .seasonal || activeEvent != nil }
    }

    /// The event an unowned seasonal exclusive waits for, or nil when the item can be bought now.
    private func seasonalLockName(for item: CosmeticItem) -> String? {
        guard !item.isUnlocked,
              !SeasonalCatalog.isPurchasable(item.id, activeEventID: activeEvent?.id),
              let owner = SeasonalCatalog.event(owning: item.id) else { return nil }
        return owner.name
    }

    private var filtered: [CosmeticItem] {
```

5c. Filter the shelf. Replace:

```swift
            case .video: return c.isVideoThemed
```

with:

```swift
            case .video: return c.isVideoThemed
            case .seasonal: return activeEvent?.exclusiveCosmeticIDs.contains(c.id) ?? false
```

5d. Show the chip only while an event runs. Replace:

```swift
                ForEach(ShopFilter.allCases, id: \.self) { f in
```

with:

```swift
                ForEach(visibleFilters, id: \.self) { f in
```

5e. Never point the "next goal" outline at gear that cannot be bought. Replace:

```swift
            .filter { !$0.isUnlocked && $0.type != .upgrade && $0.priceGems > (hero?.gems ?? 0) }
```

with:

```swift
            .filter { !$0.isUnlocked && $0.type != .upgrade && $0.priceGems > (hero?.gems ?? 0) && seasonalLockName(for: $0) == nil }
```

5f. Refuse the purchase off-season. Replace:

```swift
            HapticsService.shared.success()
        } else {
            if hero.gems >= item.priceGems {
```

with:

```swift
            HapticsService.shared.success()
        } else {
            if let eventName = seasonalLockName(for: item) {
                purchaseError = "\(item.name) returns with \(eventName)."
                HapticsService.shared.warning()
                return
            }
            if hero.gems >= item.priceGems {
```

5g. Tell the tile about the lock. Replace:

```swift
            isGateLocked: gateLocked,
            onPreviewChange: { previewChange(item, holding: $0) },
```

with:

```swift
            isGateLocked: gateLocked,
            seasonalLockEventName: seasonalLockName(for: item),
            onPreviewChange: { previewChange(item, holding: $0) },
```

5h. Add the tile property. Replace:

```swift
    var isGateLocked: Bool = false
    /// Reports hold/release so the Armory can raise and revert a full-size preview.
```

with:

```swift
    var isGateLocked: Bool = false
    /// Set for an unowned seasonal exclusive whose event is not running: the event it waits for.
    var seasonalLockEventName: String? = nil
    /// Reports hold/release so the Armory can raise and revert a full-size preview.
```

5i. Do not show a gem shortfall on locked gear. Replace:

```swift
        !item.isUnlocked && item.type != .upgrade && gems < item.priceGems
    }

    // The tile is deliberately assembled
```

with:

```swift
        !item.isUnlocked && item.type != .upgrade && gems < item.priceGems && seasonalLockEventName == nil
    }

    // The tile is deliberately assembled
```

5j. Show the lock label. Replace:

```swift
                .foregroundStyle(.questAmber)
        } else {
            priceChip
        }
    }

    private var priceChip: some View {
```

with:

```swift
                .foregroundStyle(.questAmber)
        } else if let eventName = seasonalLockEventName {
            Label("Returns with \(eventName)", systemImage: "calendar.badge.clock")
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.dungeonStoneLight).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dungeonAsh, lineWidth: 1)))
                .foregroundStyle(.textSecondary)
        } else {
            priceChip
        }
    }

    private var priceChip: some View {
```

- [ ] **Step 6: Build and run the unit tests**

Run: `tools/ci/xcode-test.sh`
Expected: PASS. `ShopView` is large and its `body` is tuned to stay inside the type-checker's budget (see the comment above `CosmeticTile.body`); if the compiler reports "unable to type-check this expression in reasonable time", move the new `if let` into its own `@ViewBuilder` property as the neighbouring code does.

- [ ] **Step 7: Check it by eye in the simulator**

Build a Debug run on a simulator with the launch arguments `-UITestTour -UITestEvent halloween` (Xcode: Product, Scheme, Edit Scheme, Run, Arguments). Open the Armory (Shop tab) and confirm:

1. A **Seasonal** chip appears after **Video**, and selecting it lists Wraithcloak, Sheet Ghost, Cave Bat and Spectral Wisps.
2. Tapping one with enough gems unlocks it (the tile celebrates).
3. Relaunch with `-UITestEvent newyear`: the Seasonal chip lists the New Year pair, and a Halloween item you did not buy shows **Returns with Phantom Purge** and cannot be bought (an alert says so).
4. Relaunch with only `-UITestTour`: no Seasonal chip; every unowned event item shows its lock label; an item bought earlier still shows **Tap to equip**.

- [ ] **Step 8: Commit**

```bash
git add ios/PurgeQuest/Services/SeasonalCatalog.swift ios/PurgeQuest/Views/Shop/ShopView.swift ios/PurgeQuestTests/SeasonalCatalogTests.swift
git commit -m "Sell seasonal gear in the Armory only while its event runs"
```

---

### Task 5: Correct the README and open the pull request

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Correct the monster table rows**

In `README.md`, replace:

```markdown
| Duplicate Dragon | *(defined but never assigned — see Known Issues)* | Video Vampire | large file, medium duration |
```

with:

```markdown
| Duplicate Dragon family (8 monsters) | near-identical groups: exact pairs, bursts, edited copies, hoards, echoes (see Duplicate detection) | Video Vampire | large file, medium duration |
```

and replace:

```markdown
| | | Corrupted Codec | *(defined but never assigned — see Known Issues)* |
```

with:

```markdown
| | | Corrupted Codec | video that cannot be read or reports no duration |
```

- [ ] **Step 2: Replace Known Issues #1 and #2**

Replace these two consecutive list items:

```markdown
1. **"Duplicate Dragon" content is unreachable.** `MonsterType.duplicateDragon` has a daily quest ("Duplicate Dragon Slayer," `GameDataService.swift:113`), an achievement ("Duplicate Slayer," `GameDataService.swift:81`), and a seasonal-event bonus entry (`SeasonalEventService.swift:72`) — but `MLAnalysisService.classifyPhoto()` never returns `.duplicateDragon`, and no duplicate-detection logic (hashing, similarity comparison) exists anywhere in `Services/`. As shipped, that quest and achievement can never be completed. Same issue applies to `MonsterType.corruptedCodec`, referenced as a Halloween bonus monster but never returned by `classifyVideo()`.
2. **Seasonal events reference cosmetic IDs that don't exist.** All 4 events in `SeasonalEventService.swift` declare `exclusiveCosmeticIDs` (e.g. `"fx.spectral"`, `"weapon.fireworkBlade"`, `"pet.beachSpirit"`) — none of these 7 IDs appear in the 27-item catalog seeded by `GameDataService.cosmeticSeeds`. Seasonal events currently cannot grant their advertised exclusive cosmetics.
```

with:

```markdown
1. **"Duplicate Dragon" and "Corrupted Codec" are never assigned.** *Resolved in code; this note was stale.* `MonsterClassifier` summons the Duplicate Dragon from duplicate clusters and the Corrupted Codec from unreadable video, and `ContentReachabilityTests` proves all 36 monsters can be summoned. What was really wrong: only a cluster's oldest copy took the cluster's monster (the other copies were booked as whatever each would be alone), and the Duplicate Dragon quest and "Duplicate Slayer" achievement counted only the literal Duplicate Dragon, one of eight duplicate monsters. Copies now share their cluster's monster, and the quest and achievement count the whole Duplicate Dragons family.
2. **Seasonal events reference cosmetic IDs that don't exist.** *Resolved in code; this note was stale.* All nine exclusive IDs are seeded and have art (`tools/ci/repo_guard.py` fails CI if one goes missing). What was missing was the link between an event and its gear: the Armory now shows a Seasonal shelf while an event runs and sells event gear only then. Items a player already owns stay theirs.
```

- [ ] **Step 3: Drop the finished roadmap bullet**

Delete this line (and the newline before it) from the Roadmap list:

```markdown

- Reconciling seasonal-event exclusive cosmetics with the real catalog (see Known Issue #2).
```

- [ ] **Step 4: Run the repository guard**

Run: `python3 -I tools/ci/repo_guard.py`
Expected: `repo_guard ok (…)`.

- [ ] **Step 5: Commit, push and open the pull request**

```bash
git add README.md
git commit -m "Correct the README on unreachable content and seasonal gear"
git push -u origin HEAD
```

Open a pull request. In its description list the three decisions above so the reviewer can overrule them, and paste the four `PurgeQuestTests` results. Then watch the "iOS Unit Tests" and "Repo guard" workflows.

## Not in this plan

- **Library-wide duplicate matching.** Duplicates are paired only within a dive's batch of unseen photos, so an Album Echo whose twin is far away in the library is rarely found. See the duplicate-detection plan.
- **A refreshed monster table in the README.** The README still describes 13 monsters; there are 36. This plan corrects only the lines it makes false.

## Self-review

- Spec coverage: "Duplicate Dragon never assigned" is answered by Tasks 1 to 3 (it is assigned; the audit proves it, and the real defects behind it are fixed). "Corrupted Codec never assigned" is answered by Task 1's witness. "Seasonal cosmetics that don't exist" is answered by the table (they exist) plus Task 4 (the real gap).
- Placeholder scan: none. Every code step carries the code.
- Type consistency: `counts(as:)` is defined in Task 3 and used only after it; `dailyQuestPool` is defined in Task 1 and used by Task 1's tests; `DuplicateGroupBuilder.Result` fields match their use in Task 2's wiring (`items`, `groups`, `nonRepresentatives`).
- Cross-plan: the shaky-ghost plan replaces one line of `ContentReachabilityTests` (the Shaky Ghost witness); its Task 5 says so.
