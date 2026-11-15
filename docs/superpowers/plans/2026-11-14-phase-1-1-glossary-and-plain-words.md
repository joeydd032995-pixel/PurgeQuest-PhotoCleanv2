# Phase 1.1: Glossary and Plain Words Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every game word a first-time player meets is explained in plain words the first time they see it, and the text they read says what to do, not what the lore calls it.

**Architecture:** The rules are pure Foundation (the four glossary words and their sentences, the ledger of which have been explained, the scan-wait phrase) so the Linux harness proves them. The SwiftUI on top is thin: one small note view shown in two places, and string changes. Every string change is guarded by a test or by `repo_guard.py`, so the old wording cannot drift back.

**Tech Stack:** Swift 6.2 (Swift Testing in the Linux harness), SwiftUI, SwiftData, `tools/ci/repo_guard.py`, GitHub Actions.

**Parent plan:** `docs/superpowers/plans/2026-11-14-phase-1-clarity.md`, sub-plan **1.1** (slice A, chosen by the owner on 14 November 2026). Sizing: M (1 to 2 days), dominated by two CI cycles.

## How this plan was checked

Every pure-logic step below was run, not just written: the tests were seen failing for the stated reason, then passing, in the Linux harness on a throwaway branch; every Swift file was parsed with `swiftc -parse` (Swift 6.2); `repo_guard.py` passes; the final harness run is **368 tests in 27 suites**. The code blocks and diffs in this document are taken from that validated change (24 files, 464 insertions), not retyped. **Not checked locally:** nothing compiles or renders SwiftUI on Linux, and the CI-only tests need SwiftData. `build-and-analyze` (about 3 minutes) is the compile check, `unit-tests` (about 35) runs the CI-only tests, and the `tour` (about 27) is the only look at the new notes.

## Global Constraints

Every task's requirements implicitly include this section.

- **Baseline:** this plan is written against a base that has PR #40's combo rule: **352 tests in 26 suites**. On a base without it the baseline is 346, so subtract 6 from every harness count below.
- **Principle (assessment section 6, verbatim):** "Plain words first, lore second; one measurement vocabulary. Every game term carries a plain gloss at first sight. 'Freed' only ever means measured."
- **Polish floor (verbatim):** "No truncation, no clipped lists, no text below 12 pt, 4.5:1 for every text role." The new note uses `.caption` (12 pt) and a 44 pt dismiss control.
- **Names that match the card:** a quest that names a monster uses `MonsterType.displayName` exactly, because the chip on the card is what a player matches it to.
- **New Swift files need no project-file edit:** the Xcode project uses file-system synchronized folders (PR #39 added many files and did not touch `project.pbxproj`). Pure Foundation files go in **both** lists in `tools/swift_harness/run.sh`; SwiftData and SwiftUI files and tests do not.
- **No identifier that UI tests use is renamed here.** The tour will show new rows (the Dive note on the Library, the Room note on the first card). That is expected.
- Commit messages end with the attribution lines the session gives. No model identifier anywhere else. Nothing merges without the owner's explicit ask.

## Decisions this plan makes (the owner can veto any)

1. **Quest wording deviates from Appendix B.** Appendix B suggests "Delete 3 videos longer than 2 minutes". `MonsterClassifier` checks a gigabyte, then 500 MB, then 4K resolution *before* `duration > 120`, so a long large video is a Memory Hog Minotaur or a Kraken, not a Leviathan, and would not count toward that quest. "Delete 3 LongTake Leviathans: recordings over two minutes." names the monster the card will show and says what it is, so it never over-promises. Every monster quest follows that shape; the Duplicate Dragon quest counts a whole family (`MonsterType.counts(as:)`), so it says "duplicate photos".
2. **"Standard gear tier" becomes "Standard gear"**, not "Gear" as Appendix B says, because "Gear" alone would drop which tier the hero is on.
3. **"Palette" stays** until Phase 2 (D2 retires the switch). **"Identified opportunity / Pending deletion / Actually reclaimed"** stay until 1.4, which rebuilds the storage strip.
4. **S-16 (the scan wait) is only partly fixed.** The wait now says how many items it is reading. A real progress bar needs callbacks through classification and is not built here.
5. **Bestiary stats read "Met / Kept / Deleted"** (they were "Met / Spared / Slain"), so the labels are all plain words.
6. **How the glossary shows:** a one-line note in the flow of the screen (never over the photo or the buttons), one at a time. It goes away when the player taps "Got it" or decides the card it sits over, and the word is never explained again. "Reset all PurgeQuest data" starts the words over.

## File structure

| File | Responsibility |
|---|---|
| Create `ios/PurgeQuest/Models/Glossary.swift` | Pure: the four words, their Appendix B sentences, the ledger of explained words, its `UserDefaults` store |
| Create `ios/PurgeQuest/Views/Components/GlossaryTip.swift` | The one-line note view |
| Create `ios/PurgeQuestTests/GlossaryTests.swift` | Harness: sentences, ledger rules, store round trip |
| Create `ios/PurgeQuestTests/GlossaryAppConstantsTests.swift` | CI only: the glossary's "20 items" and "five rooms" are the dive's real numbers |
| Modify `ios/PurgeQuest/Models/Wording.swift` and `WordingTests.swift` | The scan-wait phrase at 0, 1 and many |
| Modify `ios/PurgeQuest/Models/GameContent.swift`, `GameDataService.swift`, `SeasonalEventService.swift`, `WidgetSnapshotService.swift`, `ios/PurgeQuestWidget/SharedSnapshot.swift` | Quest, trophy, event and widget copy in plain words |
| Modify `ios/PurgeQuestTests/GameContentTests.swift`, `AchievementCopyTests.swift` | Copy tests (harness and CI only) |
| Modify `SettingsView.swift`, `FamilyDetailView.swift`, `DuplicateGroupCard.swift`, `HeroForgeView.swift` | "Kept" for "spared", and plain labels |
| Modify `tools/ci/repo_guard.py` | Check 17: no "spare" in anything the player reads |
| Modify `CombatViewModel.swift`, `CombatView.swift`, `DashboardView.swift` | Scan count, and the two note placements |
| Modify `DateScopeIntegrationTests.swift` | CI only: Reset starts the glossary over |
| Modify `tools/swift_harness/run.sh`, `README.md` | Harness lists and the test count |

---

### Task 1: The glossary, its ledger and its store (pure)

**Files:**
- Create: `ios/PurgeQuest/Models/Glossary.swift`
- Create: `ios/PurgeQuestTests/GlossaryTests.swift`
- Modify: `tools/swift_harness/run.sh` (both lists)

**Interfaces:**
- Produces: `Glossary.Term` (`dive`, `room`, `elite`, `shade`); `Glossary.name(_:)`, `.gloss(_:)`, `.sentence(_:) -> String`; `Glossary.itemsPerRoom` (20) and `.maxRoomsPerDive` (5); `GlossaryLedger` (`seen`, `init(seen:)`, `init(storedValue:)`, `storedValue`, `hasSeen(_:)`, `markSeen(_:)`, `nextTip(among:) -> Glossary.Term?`); `GlossaryStore` (`key`, `load(from:)`, `save(_:to:)`, `clear(in:)`). Task 5 consumes all of these.

- [ ] **Step 1: Write the failing tests.** Create `ios/PurgeQuestTests/GlossaryTests.swift`:

```swift
//
//  GlossaryTests.swift
//  PurgeQuestTests
//
//  The four game words a first-time player meets and the plain sentence each one gets (Glossary.swift),
//  and the ledger that explains each word once. Foundation only, so these run in Xcode and in the Linux
//  harness (tools/swift_harness/run.sh).
//

import Testing
import Foundation
@testable import PurgeQuest

struct GlossaryTests {

    // MARK: The sentences

    @Test func theSentencesAreExactlyAppendixB() {
        #expect(Glossary.sentence(.dive)  == "Dive: one session of up to five rooms.")
        #expect(Glossary.sentence(.room)  == "Room: 20 items.")
        #expect(Glossary.sentence(.elite) == "Elite: a boss-tier monster that pays more.")
        #expect(Glossary.sentence(.shade) == "Shade: a photo you deleted before; deleting it again pays nothing.")
    }

    @Test func everyTermIsNamedAndExplained() {
        #expect(Glossary.Term.allCases.count == 4)
        for term in Glossary.Term.allCases {
            #expect(!Glossary.name(term).isEmpty)
            #expect(!Glossary.gloss(term).isEmpty)
            #expect(Glossary.sentence(term).hasPrefix("\(Glossary.name(term)): "))
            #expect(Glossary.sentence(term).hasSuffix("."))
        }
    }

    @Test func aGlossNeverUsesTheWordItExplains() {
        for term in Glossary.Term.allCases {
            #expect(!Glossary.gloss(term).lowercased().contains(Glossary.name(term).lowercased()),
                    "the gloss for \(term) uses the word it is explaining")
        }
    }

    @Test func theShapeOfADiveIsTheOneTheGameUses() {
        #expect(Glossary.itemsPerRoom == 20)
        #expect(Glossary.maxRoomsPerDive == 5)
    }

    // MARK: The ledger

    @Test func aNewLedgerHasExplainedNothing() {
        let ledger = GlossaryLedger()
        for term in Glossary.Term.allCases { #expect(!ledger.hasSeen(term)) }
        #expect(ledger.storedValue.isEmpty)
    }

    @Test func aTermIsExplainedOnceAndThenNeverAgain() {
        var ledger = GlossaryLedger()
        #expect(ledger.nextTip(among: [.elite]) == .elite)
        ledger.markSeen(.elite)
        #expect(ledger.hasSeen(.elite))
        #expect(ledger.nextTip(among: [.elite]) == nil)
        ledger.markSeen(.elite)   // marking twice changes nothing
        #expect(ledger.storedValue == ["elite"])
    }

    @Test func theCallersOrderIsThePriorityAndOnlyOneTipShowsAtATime() {
        var ledger = GlossaryLedger()
        let visible: [Glossary.Term] = [.room, .elite, .shade]
        #expect(ledger.nextTip(among: visible) == .room)
        ledger.markSeen(.room)
        #expect(ledger.nextTip(among: visible) == .elite)
        ledger.markSeen(.elite)
        #expect(ledger.nextTip(among: visible) == .shade)
        ledger.markSeen(.shade)
        #expect(ledger.nextTip(among: visible) == nil)
    }

    @Test func onlyAWordThatIsOnScreenCanBeOffered() {
        let ledger = GlossaryLedger()
        #expect(ledger.nextTip(among: []) == nil)
        #expect(ledger.nextTip(among: [.room]) == .room)
    }

    @Test func theLedgerSurvivesBeingSavedAndRestored() {
        var ledger = GlossaryLedger()
        ledger.markSeen(.shade)
        ledger.markSeen(.dive)
        #expect(ledger.storedValue == ["dive", "shade"], "stored sorted, so the value is stable")
        #expect(GlossaryLedger(storedValue: ledger.storedValue) == ledger)
    }

    @Test func aWordThisBuildDoesNotKnowIsIgnoredNotACrash() {
        let ledger = GlossaryLedger(storedValue: ["elite", "someFutureWord", ""])
        #expect(ledger.seen == [.elite])
    }

    // MARK: Persistence

    @Test func theStoreRoundTripsThroughUserDefaultsAndCanBeCleared() throws {
        let suite = "GlossaryTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(GlossaryStore.load(from: defaults) == GlossaryLedger(), "a first launch has explained nothing")

        var ledger = GlossaryLedger()
        ledger.markSeen(.room)
        GlossaryStore.save(ledger, to: defaults)
        #expect(GlossaryStore.load(from: defaults) == ledger)

        GlossaryStore.clear(in: defaults)
        #expect(GlossaryStore.load(from: defaults) == GlossaryLedger(), "Reset all data starts the words over")
    }
}
```

- [ ] **Step 2: Register both files in the harness.** The source list gets `Models/Glossary` and the test list gets `GlossaryTests`:

```diff
--- a/tools/swift_harness/run.sh
+++ b/tools/swift_harness/run.sh
@@ -14,7 +14,7 @@ APP="$REPO/ios/PurgeQuest"
 TESTS="$REPO/ios/PurgeQuestTests"
 mkdir -p "$WORK/Sources/PurgeQuest" "$WORK/Tests/PurgeQuestTests"
 cd "$WORK"
-for f in Models/ModularCharacterFoundation Models/ModularAssetCatalog Models/HeldGearFit Models/RecolorMath Models/ForgeDraft Models/HeroAppearance Models/LookRecolor Models/ThemePalette Models/AppearanceMode Models/ColorTheme Models/MediaItem Models/MonsterClassification Models/GameContent Models/SpriteBodyBounds Services/DuplicateDetection Services/ThumbnailAnalysis Services/BoundedConcurrency Services/BlockingCall Services/RoomTargeting Services/DateScope Services/MonsterClassifier Services/MonsterType+Counting Services/CaptureSignals Services/VideoFrameSignals Services/VisionTextSignals Models/ThirdPartyCredits Models/PhotoAccess Models/DiveRules Models/Wording Models/DiveProgress; do
+for f in Models/ModularCharacterFoundation Models/ModularAssetCatalog Models/HeldGearFit Models/RecolorMath Models/ForgeDraft Models/HeroAppearance Models/LookRecolor Models/ThemePalette Models/AppearanceMode Models/ColorTheme Models/MediaItem Models/MonsterClassification Models/GameContent Models/SpriteBodyBounds Services/DuplicateDetection Services/ThumbnailAnalysis Services/BoundedConcurrency Services/BlockingCall Services/RoomTargeting Services/DateScope Services/MonsterClassifier Services/MonsterType+Counting Services/CaptureSignals Services/VideoFrameSignals Services/VisionTextSignals Models/ThirdPartyCredits Models/PhotoAccess Models/DiveRules Models/Wording Models/DiveProgress Models/Glossary; do
   ln -sf "$APP/$f.swift" "Sources/PurgeQuest/$(basename "$f").swift"
 done
 # These import SwiftUI only for a Color (an accent, a frame tint); compile them against Foundation + the stub Color.
@@ -22,7 +22,7 @@ for s in Models/HeroRace Models/MonsterType Models/MonsterFamily Models/MonsterR
   sed 's/^import SwiftUI$/import Foundation/' "$APP/$s.swift" > "Sources/PurgeQuest/$(basename "$s").swift"
 done
 cp "$HERE/Stubs.swift" Sources/PurgeQuest/Stubs.swift
-for t in ModularCharacterFoundationTests ModularGearTests ModularManifestFileTests LookRecolorTests ThemePaletteTests DuplicateEngineTests ThumbnailAnalysisTests BoundedConcurrencyTests BlockingCallTests RoomTargetingTests ClassifierRulesTests ClusterReasonTests ContentReachabilityTests CaptureSignalTests ClassifierPrecedenceTests GameContentTests VideoFrameSignalTests SpriteBodyBoundsTests DateScopeTests ThirdPartyCreditsTests PhotoAccessTests DiveRulesTests WordingTests DiveProgressTests; do ln -sf "$TESTS/$t.swift" "Tests/PurgeQuestTests/$t.swift"; done
+for t in ModularCharacterFoundationTests ModularGearTests ModularManifestFileTests LookRecolorTests ThemePaletteTests DuplicateEngineTests ThumbnailAnalysisTests BoundedConcurrencyTests BlockingCallTests RoomTargetingTests ClassifierRulesTests ClusterReasonTests ContentReachabilityTests CaptureSignalTests ClassifierPrecedenceTests GameContentTests VideoFrameSignalTests SpriteBodyBoundsTests DateScopeTests ThirdPartyCreditsTests PhotoAccessTests DiveRulesTests WordingTests DiveProgressTests GlossaryTests; do ln -sf "$TESTS/$t.swift" "Tests/PurgeQuestTests/$t.swift"; done
 cat > Package.swift <<'PKG'
 // swift-tools-version: 6.0
 import PackageDescription
```

- [ ] **Step 3: Run it and watch it fail.**

Run: `SWIFT_BIN=/path/to/swift-6.2/usr/bin/swift tools/swift_harness/run.sh`
Expected: FAIL to compile, `error: cannot find 'Glossary' in scope` (and `cannot find 'GlossaryLedger'`, `cannot find 'GlossaryStore'`).

(No local Swift 6.2? Download `swift-6.2-RELEASE-ubuntu24.04` from swift.org, about 1 GB, or push and read the `swift-pure-logic` CI job, about a minute.)

- [ ] **Step 4: Write the implementation.** Create `ios/PurgeQuest/Models/Glossary.swift`:

```swift
//
//  Glossary.swift
//  PurgeQuest
//
//  The four game words a first-time player meets before anything explains them, each with the plain
//  sentence that goes with it (docs/design/UI_ASSESSMENT.md, Appendix B), and the ledger that remembers
//  which ones have been explained so each is explained once. Foundation only, so the Linux harness
//  checks it (tools/swift_harness/run.sh).
//

import Foundation

nonisolated enum Glossary {

    enum Term: String, CaseIterable, Sendable {
        case dive, room, elite, shade
    }

    /// A room is this many items. CombatViewModel's `roomSize` must agree (GlossaryAppConstantsTests).
    static let itemsPerRoom = 20

    /// A dive is up to this many rooms. CombatViewModel's `totalRoomsPerSession` must agree.
    static let maxRoomsPerDive = 5

    /// The word as the player sees it on screen.
    static func name(_ term: Term) -> String {
        switch term {
        case .dive:  return "Dive"
        case .room:  return "Room"
        case .elite: return "Elite"
        case .shade: return "Shade"
        }
    }

    /// The plain meaning, without the word it explains.
    static func gloss(_ term: Term) -> String {
        switch term {
        case .dive:  return "one session of up to \(spelled(maxRoomsPerDive)) rooms"
        case .room:  return "\(itemsPerRoom) items"
        case .elite: return "a boss-tier monster that pays more"
        case .shade: return "a photo you deleted before; deleting it again pays nothing"
        }
    }

    /// The sentence a player reads: "Dive: one session of up to five rooms."
    static func sentence(_ term: Term) -> String {
        "\(name(term)): \(gloss(term))."
    }

    /// 0 to 10 in words, for prose ("up to five rooms"); anything larger stays digits.
    private static func spelled(_ number: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return words.indices.contains(number) ? words[number] : String(number)
    }
}

/// Which words have been explained. A word is explained the first time it is on screen, then never again.
nonisolated struct GlossaryLedger: Equatable, Sendable {

    private(set) var seen: Set<Glossary.Term>

    init(seen: Set<Glossary.Term> = []) {
        self.seen = seen
    }

    /// Restores a ledger saved as raw values. Anything this build does not know is ignored, so a ledger
    /// written by a newer build never crashes an older one.
    init(storedValue: [String]) {
        self.seen = Set(storedValue.compactMap(Glossary.Term.init(rawValue:)))
    }

    /// What to save: sorted, so the stored value is stable.
    var storedValue: [String] {
        seen.map(\.rawValue).sorted()
    }

    func hasSeen(_ term: Glossary.Term) -> Bool {
        seen.contains(term)
    }

    mutating func markSeen(_ term: Glossary.Term) {
        seen.insert(term)
    }

    /// The word to explain now: the first of `visible` that has not been explained. The caller's order is
    /// the priority, and only one word is offered at a time, so two notes never stack.
    func nextTip(among visible: [Glossary.Term]) -> Glossary.Term? {
        visible.first { !seen.contains($0) }
    }
}

/// Where the ledger lives: `UserDefaults`, under one key, so it survives launches and is wiped by
/// "Reset all PurgeQuest data" with the rest of the player's progress.
nonisolated enum GlossaryStore {
    static let key = "pq.glossary.seen"

    static func load(from defaults: UserDefaults = .standard) -> GlossaryLedger {
        GlossaryLedger(storedValue: defaults.stringArray(forKey: key) ?? [])
    }

    static func save(_ ledger: GlossaryLedger, to defaults: UserDefaults = .standard) {
        defaults.set(ledger.storedValue, forKey: key)
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
```

- [ ] **Step 5: Run it and watch it pass.**

Run: `SWIFT_BIN=/path/to/swift-6.2/usr/bin/swift tools/swift_harness/run.sh` then `python3 tools/ci/repo_guard.py`
Expected: `Test run with 363 tests in 27 suites passed` (352 + 11 new tests, one new suite); `repo_guard ok (...)`. The guard's check 5 fails if a file named in `run.sh` does not exist, which is why both lists change in the same commit as the files.

- [ ] **Step 6: Commit.**

```bash
git add ios/PurgeQuest/Models/Glossary.swift ios/PurgeQuestTests/GlossaryTests.swift tools/swift_harness/run.sh
git commit -m "Add the glossary of game words, its ledger and its store"
```

---

### Task 2: Quests, trophy, event and widget copy in plain words

**Files:**
- Modify: `ios/PurgeQuestTests/GameContentTests.swift` (harness)
- Modify: `ios/PurgeQuestTests/AchievementCopyTests.swift` (CI only)
- Modify: `ios/PurgeQuest/Models/GameContent.swift`, `ios/PurgeQuest/Services/GameDataService.swift`, `ios/PurgeQuest/Services/SeasonalEventService.swift`, `ios/PurgeQuest/Services/WidgetSnapshotService.swift`, `ios/PurgeQuestWidget/SharedSnapshot.swift`

**Interfaces:** Consumes `QuestCatalog.daily`, `MonsterType.displayName`, `MonsterClassifier.halfGigabyte` and `.hundredMegabyte` (all existing). Produces nothing new.

**Why these numbers.** The figures in the new quest text are the classifier's own: `MonsterClassifier.halfGigabyte` is 500,000,000 bytes and `hundredMegabyte` 100,000,000 (`MonsterClassifier.swift:50-51`), and the Leviathan rule is `duration > 120` seconds (`:282`), which `MonsterType` already describes as "Recordings over two minutes". The criteria wording after each colon is each monster's own plain description in `MonsterType.swift` (lines 285-297).

- [ ] **Step 1: Write the failing tests.** Four harness tests (plain verb and no lore words; names the monster the card shows; states its own target; quotes the classifier's own sizes) and one CI-only test (no trophy asks for a lore verb):

```diff
--- a/ios/PurgeQuestTests/GameContentTests.swift
+++ b/ios/PurgeQuestTests/GameContentTests.swift
@@ -61,4 +61,50 @@ struct GameContentTests {
             #expect(!quest.subtitle.isEmpty)
         }
     }
+
+    // MARK: - Plain words first
+
+    /// The old quests said "Slay 8 blurry photo monsters" and "Vanquish 5 Duplicate Dragons": a first-time
+    /// player cannot tell what to do. A quest now starts with what to do, in plain words.
+    @Test func everyQuestStartsWithAPlainVerb() {
+        let loreWords = ["slay", "slain", "vanquish", "banish", "defeat", "monsters"]
+        for quest in QuestCatalog.daily {
+            #expect(quest.subtitle.hasPrefix("Delete ") || quest.subtitle.hasPrefix("Move "),
+                    "\(quest.title) starts with \"\(quest.subtitle)\"")
+            let words = quest.subtitle.lowercased()
+            for word in loreWords {
+                #expect(!words.contains(word), "\(quest.title) still says \"\(word)\"")
+            }
+        }
+    }
+
+    /// A quest counts the monster the card shows, so it names that monster (the chip on the card is the
+    /// handle a player matches) and says in plain words what the monster is. The Duplicate Dragon quest
+    /// counts a whole family (`MonsterType.counts(as:)`), so it says duplicates instead.
+    @Test func aMonsterQuestNamesTheMonsterTheCardWillShow() {
+        for quest in QuestCatalog.daily {
+            guard let monster = quest.monsterType else { continue }
+            if monster == .duplicateDragon {
+                #expect(quest.subtitle.lowercased().contains("duplicate"), "\(quest.title) never says duplicates")
+            } else {
+                #expect(quest.subtitle.contains(monster.displayName), "\(quest.title) never names \(monster.displayName)")
+            }
+        }
+    }
+
+    @Test func aQuestSubtitleStatesItsOwnTarget() {
+        for quest in QuestCatalog.daily {
+            #expect(quest.subtitle.contains("\(quest.targetCount)"),
+                    "\(quest.title) says a different number than \(quest.targetCount)")
+        }
+    }
+
+    /// The sizes a quest quotes are the classifier's own lines, not a rounding of them. (The two-minute
+    /// line of the Leviathan is `duration > 120` inline in MonsterClassifier, so it has no constant to pin.)
+    @Test func theSizesAQuestQuotesAreTheClassifiersOwn() throws {
+        let minotaur = try #require(QuestCatalog.daily.first { $0.monsterType == .memoryHogMinotaur })
+        #expect(minotaur.subtitle.contains("\(MonsterClassifier.halfGigabyte / 1_000_000) MB"))
+        let vampire = try #require(QuestCatalog.daily.first { $0.monsterType == .videoVampire })
+        #expect(vampire.subtitle.contains("\(MonsterClassifier.hundredMegabyte / 1_000_000) MB"))
+    }
 }
```

```diff
--- a/ios/PurgeQuestTests/AchievementCopyTests.swift
+++ b/ios/PurgeQuestTests/AchievementCopyTests.swift
@@ -68,6 +68,18 @@ struct AchievementCopyTests {
         }
     }
 
+    /// "Slay 50 Duplicate Dragons" cannot be read by someone who has not met the monsters. A trophy says what
+    /// to do in plain words; the lore stays in its title.
+    @Test func noTrophyAsksForALoreVerb() {
+        let loreWords = ["slay", "slain", "vanquish", "banish", "defeat"]
+        for seed in GameDataService.achievementSeeds() {
+            let words = seed.subtitle.lowercased()
+            for word in loreWords {
+                #expect(!words.contains(word), "\(seed.id) still says \"\(word)\"")
+            }
+        }
+    }
+
     @Test func everyTrophyHasAUniqueIdAndSomethingToSay() {
         let seeds = GameDataService.achievementSeeds()
         #expect(Set(seeds.map(\.id)).count == seeds.count, "two trophies share an id")
```

- [ ] **Step 2: Run the harness and watch the new tests fail.**

Run: `SWIFT_BIN=/path/to/swift-6.2/usr/bin/swift tools/swift_harness/run.sh`
Expected: FAIL, 18 issues in 3 tests, each quoting today's wording: `everyQuestStartsWithAPlainVerb` (14), `aMonsterQuestNamesTheMonsterTheCardWillShow` (2), `theSizesAQuestQuotesAreTheClassifiersOwn` (2), e.g. `Expectation failed: !((words → "slay 8 blurry photo monsters.").contains(word → "slay") → true)`. `aQuestSubtitleStatesItsOwnTarget` already passes (the old text had the numbers); it is there to keep them true.

- [ ] **Step 3: Change the copy.** The six quest subtitles, the one trophy, the one event tagline and the two widget placeholders:

```diff
--- a/ios/PurgeQuest/Models/GameContent.swift
+++ b/ios/PurgeQuest/Models/GameContent.swift
@@ -31,19 +31,19 @@ struct QuestTemplate: Sendable, Equatable {
 enum QuestCatalog {
     /// Every quest the daily draw can pick from.
     static let daily: [QuestTemplate] = [
-        QuestTemplate(title: "Blur Beast Hunter", subtitle: "Slay 8 blurry photo monsters.",
+        QuestTemplate(title: "Blur Beast Hunter", subtitle: "Delete 8 Blur Beasts: out-of-focus photos.",
                       kind: .photoSlay, monsterType: .blurBeast, targetCount: 8, rewardXP: 120, rewardGems: 60),
-        QuestTemplate(title: "Duplicate Dragon Slayer", subtitle: "Vanquish 5 Duplicate Dragons.",
+        QuestTemplate(title: "Duplicate Dragon Slayer", subtitle: "Delete 5 duplicate photos.",
                       kind: .photoSlay, monsterType: .duplicateDragon, targetCount: 5, rewardXP: 160, rewardGems: 80),
-        QuestTemplate(title: "Video Vampire Purge", subtitle: "Banish 6 Video Vampires.",
+        QuestTemplate(title: "Video Vampire Purge", subtitle: "Delete 6 Video Vampires: videos draining 100 MB or more.",
                       kind: .videoSlay, monsterType: .videoVampire, targetCount: 6, rewardXP: 200, rewardGems: 100),
-        QuestTemplate(title: "Long-Take Leviathan", subtitle: "Defeat 3 Leviathans over 2 minutes.",
+        QuestTemplate(title: "Long-Take Leviathan", subtitle: "Delete 3 LongTake Leviathans: recordings over two minutes.",
                       kind: .videoSlay, monsterType: .longTakeLeviathan, targetCount: 3, rewardXP: 240, rewardGems: 140),
         QuestTemplate(title: "Storage Liberation", subtitle: "Move 500 MB to Recently Deleted in one session.",
                       kind: .mbFreed, monsterType: nil, targetCount: 500, rewardXP: 180, rewardGems: 120),
-        QuestTemplate(title: "Dungeon Clear", subtitle: "Defeat 25 monsters of any kind.",
+        QuestTemplate(title: "Dungeon Clear", subtitle: "Delete 25 photos or videos.",
                       kind: .anySlay, monsterType: nil, targetCount: 25, rewardXP: 150, rewardGems: 70),
-        QuestTemplate(title: "Memory Hog Hunter", subtitle: "Slay 2 Memory Hog Minotaurs.",
+        QuestTemplate(title: "Memory Hog Hunter", subtitle: "Delete 2 Memory Hog Minotaurs: files over 500 MB.",
                       kind: .videoSlay, monsterType: .memoryHogMinotaur, targetCount: 2, rewardXP: 220, rewardGems: 140)
     ]
 }
```

```diff
--- a/ios/PurgeQuest/Services/GameDataService.swift
+++ b/ios/PurgeQuest/Services/GameDataService.swift
@@ -215,7 +216,7 @@ enum GameDataService {
         [
             Achievement(id: "first.blood",         title: "First Blood",          subtitle: "Delete your first photo.",           iconName: "drop.fill",            goal: 1),
             Achievement(id: "scene.cut",           title: "Scene Cut",            subtitle: "Delete your first video.",           iconName: "scissors",             goal: 1),
-            Achievement(id: "duplicate.slayer",   title: "Duplicate Slayer",     subtitle: "Slay 50 Duplicate Dragons.",          iconName: "square.on.square",     goal: 50),
+            Achievement(id: "duplicate.slayer",   title: "Duplicate Slayer",     subtitle: "Delete 50 duplicates.",          iconName: "square.on.square",     goal: 50),
             Achievement(id: "video.vault",        title: "Video Vault Vanquisher", subtitle: "Delete 100 videos total.",         iconName: "film.stack.fill",      goal: 100),
             Achievement(id: "great.purge",        title: "The Great Purge",      subtitle: "Move 1 GB to Recently Deleted.",       iconName: "internaldrive.fill",   goal: 1024),
             Achievement(id: "long.take.term",     title: "Longest Take Terminated", subtitle: "Delete a video over 10 minutes.",  iconName: "video.badge.checkmark", goal: 1),
```

```diff
--- a/ios/PurgeQuest/Services/SeasonalEventService.swift
+++ b/ios/PurgeQuest/Services/SeasonalEventService.swift
@@ -69,7 +69,7 @@ final class SeasonalEventService {
         SeasonalEvent(
             id: "newyear",
             name: "Resolution Purge",
-            tagline: "Slay Ancient Archives for +75% XP. Out with the old.",
+            tagline: "Delete Ancient Archives (captures from years past) for +75% XP. Out with the old.",
             symbol: "bell.fill",
             tone: .newYear,
             primary: Color(red: 0.79, green: 0.64, blue: 0.15),
```

```diff
--- a/ios/PurgeQuest/Services/WidgetSnapshotService.swift
+++ b/ios/PurgeQuest/Services/WidgetSnapshotService.swift
@@ -37,7 +37,7 @@ nonisolated struct PurgeQuestWidgetSnapshot: Codable, Hashable {
         streakDays: 3,
         totalMBFreed: 1842,
         questTitle: "Blur Beast Hunter",
-        questSubtitle: "Slay 8 blurry photo monsters.",
+        questSubtitle: "Delete 8 Blur Beasts: out-of-focus photos.",
         questCurrent: 3,
         questTarget: 8,
         questIsVideo: false,
```

```diff
--- a/ios/PurgeQuestWidget/SharedSnapshot.swift
+++ b/ios/PurgeQuestWidget/SharedSnapshot.swift
@@ -30,7 +30,7 @@ nonisolated struct PurgeQuestWidgetSnapshot: Codable, Hashable {
         streakDays: 5,
         totalMBFreed: 3640,
         questTitle: "Video Vampire Purge",
-        questSubtitle: "Banish 6 Video Vampires.",
+        questSubtitle: "Delete 6 Video Vampires: videos draining 100 MB or more.",
         questCurrent: 4,
         questTarget: 6,
         questIsVideo: true,
```

Quests already drawn today keep their old text until the next daily draw (at most a day). The trophy's text reaches an existing store at launch through `GameDataService.refreshAchievementText`, the same path the Phase 0 trophy fixes used.

- [ ] **Step 4: Run the harness and watch it pass.**

Run: `SWIFT_BIN=/path/to/swift-6.2/usr/bin/swift tools/swift_harness/run.sh`
Expected: `Test run with 367 tests in 27 suites passed` (363 + 4).

- [ ] **Step 5: Parse the changed files and commit.**

```bash
for f in ios/PurgeQuest/Models/GameContent.swift ios/PurgeQuest/Services/GameDataService.swift ios/PurgeQuest/Services/SeasonalEventService.swift ios/PurgeQuest/Services/WidgetSnapshotService.swift ios/PurgeQuestWidget/SharedSnapshot.swift ios/PurgeQuestTests/GameContentTests.swift ios/PurgeQuestTests/AchievementCopyTests.swift; do swiftc -parse "$f" && echo "parse ok: $f"; done
git add -A && git commit -m "Say what to do in plain words in quests, the duplicate trophy, the New Year event and the widget"
```

---

### Task 3: "Kept" for "spared", and plain labels, with a guard

**Files:**
- Modify: `tools/ci/repo_guard.py`
- Modify: `ios/PurgeQuest/Views/Settings/SettingsView.swift`, `ios/PurgeQuest/Views/Bestiary/FamilyDetailView.swift`, `ios/PurgeQuest/Views/Combat/DuplicateGroupCard.swift`, `ios/PurgeQuest/Views/Hero/HeroForgeView.swift`

**Interfaces:** none. Check 17 only reads string literals: comments and the code inside `\( )` interpolations are removed first, because `stats.spared` is a property name the player never reads while "Forget spared monsters" is something they do. `SparedMediaRecord` and the other code names stay.

- [ ] **Step 1: Add the guard.**

```diff
--- a/tools/ci/repo_guard.py
+++ b/tools/ci/repo_guard.py
@@ -26,6 +26,8 @@ Checks:
  15. Rork's build-time Config.swift is not used by the app, and a copy in the tree holds no values.
  16. Cinzel license: the Credits screen shows the SIL Open Font License from a data asset, and that
      asset is byte-identical to the copy kept in docs/licenses.
+ 17. Visible wording: nothing the player reads says "spare" (keeping a photo is free, D1, so there is
+     nothing to be spared from). Names in code, such as SparedMediaRecord, are not visible and stay.
 """
 import json
 import plistlib
@@ -370,6 +372,18 @@ elif ofl_asset is None or not ofl_asset.exists():
 elif ofl_docs.read_bytes() != ofl_asset.read_bytes():
     failures.append(f"cinzel license: {ofl_asset.relative_to(ROOT)} differs from docs/licenses/cinzel-OFL.txt")
 
+# 17. visible wording
+# D1 made keeping a photo free, so the player-facing word is "keep". Only text inside string literals is
+# checked, with comments and the code inside \( ) interpolations removed: `stats.spared` is a property name
+# the player never reads, "Forget spared monsters" is something they do.
+STRING_LITERAL = re.compile(r'"(?:[^"\\\n]|\\.)*"')
+INTERPOLATION = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
+SPARE_WORD = re.compile(r"\bspar(?:e|ed|es|ing)\b", re.I)
+for f in swift_files("PurgeQuest", "PurgeQuestWidget"):
+    for literal in STRING_LITERAL.findall(strip_comments(f.read_text())):
+        if SPARE_WORD.search(INTERPOLATION.sub("", literal)):
+            failures.append(f"visible wording: {f.relative_to(ROOT)} says \"spare\" to the player in {literal[:60]}")
+
 if failures:
     print("repo_guard FAILED:")
     for f in failures:
```

- [ ] **Step 2: Run it and watch it fail on today's strings.**

Run: `python3 -I tools/ci/repo_guard.py`
Expected: `repo_guard FAILED:` with exactly five lines: three in `SettingsView.swift` (`"Forget spared monsters"`, `"Forget spared monsters?"`, `"Monsters you previously spared will reappear at the top of …`) and two in `FamilyDetailView.swift` (the accessibility sentence and `"Spared"`).

- [ ] **Step 3: Change the strings.** Settings and the Bestiary lose "spared"; the duplicate card's "Slay this copy" becomes "Delete this copy" (it sat beside a plain "Keep this copy"); the Forge's "Standard gear tier" and "Dashboard Strip" become "Standard gear" and "Home preview":

```diff
--- a/ios/PurgeQuest/Views/Settings/SettingsView.swift
+++ b/ios/PurgeQuest/Views/Settings/SettingsView.swift
@@ -84,7 +84,7 @@ struct SettingsView: View {
                     Button(role: .destructive) {
                         confirmForgetSpared = true
                     } label: {
-                        Label("Forget spared monsters", systemImage: "arrow.uturn.backward")
+                        Label("Show kept photos again", systemImage: "arrow.uturn.backward")
                             .frame(maxWidth: .infinity, alignment: .leading)
                     }
                 }
@@ -172,11 +172,11 @@ struct SettingsView: View {
         } message: {
             Text("This will erase your hero, achievements, and quests. Your Photos library is unaffected.")
         }
-        .alert("Forget spared monsters?", isPresented: $confirmForgetSpared) {
+        .alert("Show kept photos again?", isPresented: $confirmForgetSpared) {
             Button("Cancel", role: .cancel) {}
-            Button("Forget", role: .destructive) { forgetSpared() }
+            Button("Show again", role: .destructive) { forgetSpared() }
         } message: {
-            Text("Monsters you previously spared will reappear at the top of your next dive.")
+            Text("Photos you kept before will come back at the top of your next dive.")
         }
         .sheet(isPresented: $showHeroCard) {
             if let hero { HeroCardSheet(hero: hero) }
```

```diff
--- a/ios/PurgeQuest/Views/Bestiary/FamilyDetailView.swift
+++ b/ios/PurgeQuest/Views/Bestiary/FamilyDetailView.swift
@@ -143,7 +143,7 @@ private struct MonsterEntryCard: View {
         .accessibilityElement(children: .combine)
         .accessibilityLabel(
             isDiscovered
-                ? "\(type.rarity.displayName) monster \(type.displayName). \(type.lore). Encountered \(stats.encountered) times, spared \(stats.spared), slain \(stats.slain)."
+                ? "\(type.rarity.displayName) monster \(type.displayName). \(type.lore). Met \(stats.encountered) times, kept \(stats.spared), deleted \(stats.slain)."
                 : "Undiscovered \(type.rarity.displayName) monster."
         )
     }
@@ -195,8 +195,8 @@ private struct MonsterEntryCard: View {
         VStack(alignment: .leading, spacing: 5) {
             HStack(spacing: 14) {
                 statBlock(value: "\(stats.encountered)", label: "Met", tint: .textPrimary)
-                statBlock(value: "\(stats.spared)", label: "Spared", tint: .gemEmerald)
-                statBlock(value: "\(stats.slain)", label: "Slain", tint: .combatCrimson)
+                statBlock(value: "\(stats.spared)", label: "Kept", tint: .gemEmerald)
+                statBlock(value: "\(stats.slain)", label: "Deleted", tint: .combatCrimson)
                 Spacer()
             }
             HStack(spacing: 8) {
```

```diff
--- a/ios/PurgeQuest/Views/Combat/DuplicateGroupCard.swift
+++ b/ios/PurgeQuest/Views/Combat/DuplicateGroupCard.swift
@@ -234,7 +234,7 @@ struct DuplicateGroupCard: View {
                 Button {
                     setDecision(true)
                 } label: {
-                    Label("Slay this copy", systemImage: "xmark")
+                    Label("Delete this copy", systemImage: "xmark")
                         .font(.subheadline.weight(.heavy))
                         .frame(maxWidth: .infinity).padding(.vertical, 11)
                         .background(RoundedRectangle(cornerRadius: 9).fill(decisionForSelected == true ? Color.combatCrimson : Color.dungeonStone))
```

```diff
--- a/ios/PurgeQuest/Views/Hero/HeroForgeView.swift
+++ b/ios/PurgeQuest/Views/Hero/HeroForgeView.swift
@@ -212,7 +212,7 @@ struct HeroForgeView: View {
                 Text("Hero Forge")
                     .font(.dungeonTitle)
                     .foregroundStyle(.textPrimary)
-                Text(tier.displayName + " gear tier")
+                Text(tier.displayName + " gear")
                     .font(.caption2.weight(.semibold))
                     .foregroundStyle(tier.labelColor)
             }
@@ -268,7 +268,7 @@ struct HeroForgeView: View {
         VStack(spacing: 6) {
             Picker("Preview context", selection: $showStripPreview) {
                 Text("Portrait").tag(false)
-                Text("Dashboard Strip").tag(true)
+                Text("Home preview").tag(true)
             }
             .pickerStyle(.segmented)
             .frame(maxWidth: 300)
```

- [ ] **Step 4: Run the guard again and parse the files.**

Run: `python3 -I tools/ci/repo_guard.py` and `swiftc -parse` on the four view files.
Expected: `repo_guard ok (...)`; four `parse ok`.

- [ ] **Step 5: Commit, push, and read `build-and-analyze`.** This is the first SwiftUI change, and parsing is not compiling.

```bash
git add -A && git commit -m "Say kept, not spared, and plain labels in Settings, the Bestiary, the duplicate card and the Forge"
git push origin HEAD
```
Expected: `build-and-analyze` green in about 3 minutes. If it is red, find the root cause in its log (`grep -n "error:"`) before going on.

---

### Task 4: The scan wait says how many items it is reading

**Files:**
- Modify: `ios/PurgeQuest/Models/Wording.swift`, `ios/PurgeQuestTests/WordingTests.swift` (harness)
- Modify: `ios/PurgeQuest/ViewModels/CombatViewModel.swift`, `ios/PurgeQuest/Views/Combat/CombatView.swift`

**Interfaces:** Produces `Wording.scanning(count: Int) -> String` and `CombatViewModel.scanCount: Int`. `scanCount` is 0 until the fetch has answered, then the number of fresh items the dive will read (a picked hunt sets it to the number picked). It is a count of items, not progress; real progress is not built (see decision 4).

- [ ] **Step 1: Write the failing test.**

```diff
--- a/ios/PurgeQuestTests/WordingTests.swift
+++ b/ios/PurgeQuestTests/WordingTests.swift
@@ -51,4 +51,13 @@ struct WordingTests {
         #expect(Wording.roomVerdict(marked: 0, kept: 20) == "Nothing marked, 20 kept")
         #expect(Wording.roomVerdict(marked: 0, kept: 0) == "Nothing marked")
     }
+
+    // MARK: The scan wait
+
+    @Test func theScanWaitCountsWhatItIsReading() {
+        #expect(Wording.scanning(count: 0) == "Scanning your library…")
+        #expect(Wording.scanning(count: -4) == "Scanning your library…")
+        #expect(Wording.scanning(count: 1) == "Scanning 1 item…")
+        #expect(Wording.scanning(count: 150) == "Scanning 150 items…")
+    }
 }
```

- [ ] **Step 2: Run it and watch it fail.**

Run: `SWIFT_BIN=/path/to/swift-6.2/usr/bin/swift tools/swift_harness/run.sh`
Expected: FAIL to compile: `Wording` has no member `scanning`.

- [ ] **Step 3: Write the phrase.**

```diff
--- a/ios/PurgeQuest/Models/Wording.swift
+++ b/ios/PurgeQuest/Models/Wording.swift
@@ -43,4 +43,14 @@ nonisolated enum Wording {
         if marked <= 0 { return kept > 0 ? "Nothing marked, \(kept) kept" : "Nothing marked" }
         return kept > 0 ? "\(marked) marked, \(kept) kept" : "\(marked) marked"
     }
+
+    /// The wait while the library is read. The count is how many items this dive is reading, once it is
+    /// known; before that it is the plain "Scanning your library…". It never says anything about monsters.
+    static func scanning(count: Int) -> String {
+        switch count {
+        case ..<1: return "Scanning your library…"
+        case 1:    return "Scanning 1 item…"
+        default:   return "Scanning \(count) items…"
+        }
+    }
 }
```

- [ ] **Step 4: Run it and watch it pass.**

Expected: `Test run with 368 tests in 27 suites passed`.

- [ ] **Step 5: Wire the count into the loading screen.**

```diff
--- a/ios/PurgeQuest/ViewModels/CombatViewModel.swift
+++ b/ios/PurgeQuest/ViewModels/CombatViewModel.swift
@@ -61,6 +61,8 @@ final class CombatViewModel {
 
     // Library queue
     var allItems: [MediaItem] = []
+    /// How many items this dive is reading while the library is scanned; 0 until the fetch has answered.
+    var scanCount: Int = 0
     private var queueIndex: Int = 0
 
     // Current room
@@ -187,6 +189,7 @@ final class CombatViewModel {
             phase = .empty
             return
         }
+        scanCount = fresh.count
         let thumbSize = CGSize(width: 600, height: 600)
         let items = await svc.buildMediaItems(from: fresh, thumbSize: thumbSize)
         await loadBatch(items, context: context)
@@ -204,6 +207,7 @@ final class CombatViewModel {
             rewardedIDs = Set(purged.map(\.assetIdentifier))
         }
         openSession(hero: hero, context: context)
+        scanCount = assetIDs.count
         Self.log.info("picked hunt: resolving \(assetIDs.count, privacy: .public) chosen assets")
 
         func fetchPicked() -> [PHAsset] {
@@ -254,6 +258,7 @@ final class CombatViewModel {
         roomsCompleted = 0
         // A new dive always starts clean: combo back to 1× and no leftover
         // pending bonuses from a previous run.
+        scanCount = 0
         combo = 0
         comboMultiplier = ComboMultiplier()
         pendingBonusXP = 0
```

```diff
--- a/ios/PurgeQuest/Views/Combat/CombatView.swift
+++ b/ios/PurgeQuest/Views/Combat/CombatView.swift
@@ -101,7 +104,7 @@ struct CombatView: View {
     private var loadingView: some View {
         VStack(spacing: 18) {
             ProgressView().tint(.questAmber).scaleEffect(1.4)
-            Text("Summoning monsters from your library…")
+            Text(Wording.scanning(count: combat.scanCount))
                 .font(.callout).foregroundStyle(.textSecondary)
             // The tab bar is hidden during a dive, so a scan that stalls needs its own way out.
             Button("Cancel") { exit() }
```

- [ ] **Step 6: Parse and commit.**

```bash
swiftc -parse ios/PurgeQuest/ViewModels/CombatViewModel.swift && swiftc -parse ios/PurgeQuest/Views/Combat/CombatView.swift
git add -A && git commit -m "Say how many items the scan is reading, and drop the monster words from the wait"
```

---

### Task 5: Each game word explained once, where it first appears

**Files:**
- Create: `ios/PurgeQuest/Views/Components/GlossaryTip.swift`
- Create: `ios/PurgeQuestTests/GlossaryAppConstantsTests.swift` (CI only)
- Modify: `ios/PurgeQuest/Views/Combat/CombatView.swift`, `ios/PurgeQuest/Views/Dashboard/DashboardView.swift`, `ios/PurgeQuest/Services/GameDataService.swift`
- Modify: `ios/PurgeQuestTests/DateScopeIntegrationTests.swift` (CI only)

**Interfaces:** Consumes everything Task 1 produces. Produces `GlossaryTip(term:onDismiss:)`.

**Behaviour.** *Library:* "Dive: one session of up to five rooms." sits under the Enter button until the player taps "Got it" or starts a dive. *Combat:* one note at a time over the card on top, in this priority: Room (every first dive), then Elite when an Elite is on top, then Shade when a Shade is. A note is counted as explained once the card it sat over has been decided, or when "Got it" is tapped, so it never nags. "Reset all PurgeQuest data" clears the ledger.

**Why no failing-first run here.** The logic these views use is the ledger from Task 1, already seen failing and passing. The views and the CI-only tests can only run in CI, where a failing-first cycle would cost a 35-minute `unit-tests` run for no extra information, so they are written with the code and read in CI.

- [ ] **Step 1: Create the note view.**

```swift
//
//  GlossaryTip.swift
//  PurgeQuest
//
//  A one-line note that explains a game word the first time it is on screen: "Elite: a boss-tier monster
//  that pays more." It sits in the flow of the screen (never over the photo or the buttons), has one
//  44 pt control to dismiss it, and the screens that show it remember that the word was explained
//  (Glossary.swift), so it is never repeated.
//

import SwiftUI

struct GlossaryTip: View {
    let term: Glossary.Term
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
            Text(Glossary.sentence(term))
                .font(.caption)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Got it", action: onDismiss)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.textSecondary)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Got it, hide this note about \(Glossary.name(term))")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
        )
    }
}
```

- [ ] **Step 2: Show "Dive" under the Enter button.**

```diff
--- a/ios/PurgeQuest/Views/Dashboard/DashboardView.swift
+++ b/ios/PurgeQuest/Views/Dashboard/DashboardView.swift
@@ -27,6 +27,8 @@ struct DashboardView: View {
     /// Shown when the picker returned choices that carry no asset identifiers —
     /// the signature of missing photo-library access.
     @State private var showAccessHint = false
+    /// Which game words have been explained; "dive" is explained once, under the Enter button.
+    @State private var glossary = GlossaryStore.load()
     /// The date range sheet (see DatesSheet).
     @State private var showDatesSheet = false
 
@@ -44,6 +46,9 @@ struct DashboardView: View {
                 libraryOverview
                 heroStrip
                 enterDungeonButton
+                if glossary.nextTip(among: [.dive]) != nil {
+                    GlossaryTip(term: .dive) { markDiveExplained() }
+                }
                 HStack(spacing: 10) {
                     focusedDiveMenu
                     pickedHuntPicker
@@ -354,6 +359,7 @@ struct DashboardView: View {
 
     private var enterDungeonButton: some View {
         Button {
+            markDiveExplained()
             HapticsService.shared.medium()
             appState.diveFocus = nil   // the default dive is always mixed, whatever an earlier dive left behind
             appState.combatRequested = true
@@ -367,6 +373,13 @@ struct DashboardView: View {
         .accessibilityLabel("Enter the dungeon and start a cleanup session")
     }
 
+    /// Starting a dive means the player has met the word, so it is explained once and never again.
+    private func markDiveExplained() {
+        guard glossary.nextTip(among: [.dive]) != nil else { return }
+        glossary.markSeen(.dive)
+        GlossaryStore.save(glossary)
+    }
+
     /// Optional: lean this dive toward one kind of clutter. "Enter the Dungeon" above stays the mixed
     /// default. Choosing a bucket starts the dive at once; the choice applies to that dive only.
     private var focusedDiveMenu: some View {
```

- [ ] **Step 3: Show the Room, Elite and Shade notes over the card.**

```diff
--- a/ios/PurgeQuest/Views/Combat/CombatView.swift
+++ b/ios/PurgeQuest/Views/Combat/CombatView.swift
@@ -17,6 +17,9 @@ struct CombatView: View {
     @State private var shakeOffset: CGFloat = 0
     @State private var fxTrigger: Int = 0
     @State private var confirmingExit = false
+    /// Which game words have been explained, and the one being explained over the card on top right now.
+    @State private var glossary = GlossaryStore.load()
+    @State private var tipTerm: Glossary.Term? = nil
 
     var body: some View {
         ZStack {
@@ -166,6 +169,14 @@ struct CombatView: View {
             .padding(.horizontal, 14)
             .padding(.top, combat.roomNumber == 1 ? 0 : 8)
 
+            if let term = tipTerm {
+                GlossaryTip(term: term) {
+                    markExplained(term)
+                    tipTerm = nextGlossaryTip()
+                }
+                .padding(.horizontal, 14)
+            }
+
             ZStack {
                 if let next = combat.nextItem {
                     SwipeMediaCard(item: next, isFront: false, onDelete: {}, onSpare: {})
@@ -232,6 +243,29 @@ struct CombatView: View {
                 .padding(.bottom, 14)
             }
         }
+        .onAppear { tipTerm = nextGlossaryTip() }
+        .onChange(of: combat.topItem?.id) { _, _ in
+            // The card the note was shown over has been decided, so the word has been seen: it is not repeated.
+            if let shown = tipTerm { markExplained(shown) }
+            tipTerm = nextGlossaryTip()
+        }
+    }
+
+    // MARK: Game words, explained once
+
+    /// The one word to explain over the card on top, if any: the room first, then an Elite or a Shade.
+    private func nextGlossaryTip() -> Glossary.Term? {
+        var visible: [Glossary.Term] = [.room]
+        if let top = combat.topItem {
+            if top.monsterType.isElite { visible.append(.elite) }
+            if combat.isShade(top) { visible.append(.shade) }
+        }
+        return glossary.nextTip(among: visible)
+    }
+
+    private func markExplained(_ term: Glossary.Term) {
+        glossary.markSeen(term)
+        GlossaryStore.save(glossary)
     }
 
     /// Dive-start banner naming the auto-detected dungeon theme.
```

- [ ] **Step 4: Make Reset start the words over, and pin both behaviours with CI-only tests.**

```diff
--- a/ios/PurgeQuest/Services/GameDataService.swift
+++ b/ios/PurgeQuest/Services/GameDataService.swift
@@ -100,6 +100,7 @@ enum GameDataService {
         defaults.removeObject(forKey: "pq.hasOnboarded")
         clearOnboardingChoices(from: defaults)
         DateScopeStore.clear(in: defaults)
+        GlossaryStore.clear(in: defaults)
     }
 
     // MARK: - Cosmetics
```

```diff
--- a/ios/PurgeQuestTests/DateScopeIntegrationTests.swift
+++ b/ios/PurgeQuestTests/DateScopeIntegrationTests.swift
@@ -141,4 +141,19 @@ struct DateScopeIntegrationTests {
             #expect(DateScopeStore.load(from: defaults) == DateScope.all)
         }
     }
+
+    /// The same reset starts the glossary over: a player who resets sees each game word explained again.
+    @Test func resettingAllDataStartsTheGlossaryOver() throws {
+        let container = try makeContainer()
+        let context = ModelContext(container)
+        try withDefaults { defaults in
+            var ledger = GlossaryLedger()
+            ledger.markSeen(.elite)
+            GlossaryStore.save(ledger, to: defaults)
+            try withExtendedLifetime(container) {
+                GameDataService.resetAllData(in: context, defaults: defaults)
+            }
+            #expect(GlossaryStore.load(from: defaults) == GlossaryLedger())
+        }
+    }
 }
```

Create `ios/PurgeQuestTests/GlossaryAppConstantsTests.swift` (the glossary's "20 items" and "five rooms" must be the dive's real numbers):

```swift
//
//  GlossaryAppConstantsTests.swift
//  PurgeQuestTests
//
//  The glossary says "Room: 20 items" and "up to five rooms". Those numbers must be the ones the dive
//  actually uses. Needs the app target (CombatViewModel), so it runs in Xcode and CI only.
//

import Testing
@testable import PurgeQuest

@MainActor
struct GlossaryAppConstantsTests {

    @Test func theGlossaryDescribesTheDiveTheGameRuns() {
        #expect(Glossary.itemsPerRoom == CombatViewModel.roomSize)
        #expect(Glossary.maxRoomsPerDive == CombatViewModel.totalRoomsPerSession)
    }
}
```

- [ ] **Step 5: Parse, run the local checks, commit and push.**

```bash
for f in ios/PurgeQuest/Views/Components/GlossaryTip.swift ios/PurgeQuest/Views/Combat/CombatView.swift ios/PurgeQuest/Views/Dashboard/DashboardView.swift ios/PurgeQuest/Services/GameDataService.swift ios/PurgeQuestTests/DateScopeIntegrationTests.swift ios/PurgeQuestTests/GlossaryAppConstantsTests.swift; do swiftc -parse "$f" && echo "parse ok: $f"; done
python3 tools/ci/repo_guard.py
SWIFT_BIN=/path/to/swift-6.2/usr/bin/swift tools/swift_harness/run.sh   # still 368 tests in 27 suites
git add -A && git commit -m "Explain each game word once, where it first appears"
git push origin HEAD
```
Expected: `build-and-analyze` green in about 3 minutes. Read it before waiting for the rest.

---

### Task 6: The count, the PR, and the measured result

**Files:** Modify `README.md`.

- [ ] **Step 1: Update the harness count in the README.**

```diff
--- a/README.md
+++ b/README.md
@@ -259,7 +259,7 @@ Full steps, the StoreKit configuration and the device test pass are in [`ios/REA
 | UI tests: Forge draft/save/cancel, onboarding after a reset, a Light/Dark screenshot tour (artifact `ui-snapshots`) | `ios/PurgeQuestUITests/` | `ios.yml` |
 | Build and static analysis | | `.github/workflows/objective-c-xcode.yml` |
 | Screenshots of every screen, Light and Dark, with a synthetic photo library in the simulator (artifact `ui-snapshots-tour`; not a merge gate) | `tools/ci/make_library_fixtures.py` | `.github/workflows/ui-snapshots.yml`, on pull requests that touch the app |
-| **Linux harness**: the pure-Foundation sources and their suites, no Xcode or simulator. 352 tests in 26 suites, including the date range, the classifier, the audit that every monster named by a quest or event can be summoned, capture rules, rule precedence, video frame signals, the scan's bounded-concurrency and deadline helpers, what the app may say about photo access, the dive's keep and combo rules and room count, and the wording of its numbers | `tools/swift_harness/run.sh` | `.github/workflows/modular-assets.yml` |
+| **Linux harness**: the pure-Foundation sources and their suites, no Xcode or simulator. 368 tests in 27 suites, including the date range, the classifier, the audit that every monster named by a quest or event can be summoned, capture rules, rule precedence, video frame signals, the scan's bounded-concurrency and deadline helpers, what the app may say about photo access, the dive's keep and combo rules and room count, the wording of its numbers, the glossary of game words, and the plain wording of the quests | `tools/swift_harness/run.sh` | `.github/workflows/modular-assets.yml` |
 | Asset checks: manifests, masks, fits, the approval gate (content-pinned), catalog drift, generated docs up to date. 72 tests | `tools/modular_assets/` | `modular-assets.yml` |
 | Repository contracts: offline, no dependencies, recoverable deletion, StoreKit IDs, App Group and snapshot agreement, privacy manifests, versions | `tools/ci/repo_guard.py` | `.github/workflows/repo-guard.yml` |
 | Detection benchmark on real photographs (not in CI) | `tools/detection_bench/` | by hand |
```

- [ ] **Step 2: Run every local check once more and push.**

```bash
SWIFT_BIN=/path/to/swift-6.2/usr/bin/swift tools/swift_harness/run.sh   # 368 tests in 27 suites
python3 tools/ci/repo_guard.py
git add -A && git commit -m "Update the harness count for the glossary and plain-words tests" && git push origin HEAD
```

- [ ] **Step 3: Open the PR, ready for review (not draft).** Title: `Phase 1.1: a plain-words glossary and copy`. Body headings `## Summary` and `## Test plan`; say what changed (the glossary notes, the quests and trophy, "kept" for "spared", the scan count), list decisions 1 to 6 above for the owner to veto, what was and was not checked, and end with the required footer. Subscribe to the PR.

- [ ] **Step 4: When CI finishes, read it in this order:** `build-and-analyze`, then `unit-tests` (this runs the CI-only tests: `GlossaryAppConstantsTests`, `resettingAllDataStartsTheGlossaryOver`, `noTrophyAsksForALoreVerb`), then `tour`. A red job gets a root cause from its log, never a skip.

- [ ] **Step 5: Measure the tour, in Light and Dark.** Download the `ui-snapshots-tour` artifact into a new empty directory, verify its sha256 against the one GitHub reports, then check, with the same scripts as the Phase 0 review:
  1. The Library shot has the "Dive" note under the Enter button, its text clears 4.5:1, and nothing is clipped.
  2. The first combat card has the "Room: 20 items." note, and **DELETE and KEEP are still fully on screen** (compare their position with the Phase 0 combat shot).
  3. The Settings and Bestiary shots contain no "spared" and no "Slain".
  4. The quests on the Library read "Delete …", and name the monster with its plain gloss.

- [ ] **Step 6: Update the PR body with what was measured, and stop.** The owner decides about merging.

---

## Self-review

**Parent plan acceptance for 1.1, checked against this plan:**

| Acceptance (parent plan, 1.1) | Where |
|---|---|
| "no 'spared' left in user-visible text" | Task 3, and `repo_guard.py` check 17 keeps it so |
| "every term in the glossary is explained at first encounter and never again" | Tasks 1 and 5 (Dive, Room, Elite, Shade; the ledger is tested) |
| "quests read in plain words" | Task 2, with the deviation from Appendix B explained in decision 1 |
| "harness suites cover each phrase at 0, 1 and many" | Task 4 (`Wording.scanning`), Task 1 (the ledger), Task 2 (the copy) |
| S-16 scan wait | Task 4, partly (decision 4) |

**Appendix B rows:** "Summoning monsters from your library…" is Task 4; "Defeat 3 Leviathans over 2 minutes" is Task 2 (decision 1); "Standard gear tier / Dashboard Strip" is Task 3 (decision 2); "SPARE / Spare this item" was Phase 0; "Palette", "Focused Dive / Hunt Chosen" and the storage ledger rows are 1.4 or Phase 2 (decision 3).

**Placeholder scan:** none; every code step has the code, and every run step has its expected output.

**Type consistency:** `Glossary.Term`, `GlossaryLedger`, `GlossaryStore`, `Glossary.sentence(_:)`, `Wording.scanning(count:)` and `CombatViewModel.scanCount` are spelled the same in every task that uses them (the whole change compiles in the harness and parses in all of its Swift files).

**Known gap, owned by 1.2:** the combat card still shows "+33 XP · +0 on confirm" under the photo, while the assessment's combat-card spec (10.2) says no reward preview appears on the card. That is not a wording change, so it is not here.

## Execution handoff

**Plan complete and saved to `docs/superpowers/plans/2026-11-14-phase-1-1-glossary-and-plain-words.md`. Two execution options:**

1. **Subagent-driven (recommended):** a fresh subagent per task, with a review between tasks (REQUIRED SUB-SKILL: superpowers:subagent-driven-development).
2. **Inline execution:** the tasks run in one session with checkpoints (REQUIRED SUB-SKILL: superpowers:executing-plans).

## Amendments after the owner's answers (15 November 2026)

The plan above is kept as it was executed. The owner then answered the five open questions from PR #41, and the code now differs from the plan's embedded snippets in these ways:

1. **Room gloss:** "Room: up to 20 items." (the tour showed "16 left" beside "20 items"). Same commit as 4.
2. **Quests state exactly what they count** (decision 1 above is superseded for the wording). The lines are pinned to the classifier by `QuestRulesTests`, and the Bestiary's `signalDescription` for the same monsters says the same:
   - Blur Beast: photos that no other monster claims, blurry or sharp (the classifier's catch-all). A blurry Live Photo, screenshot or duplicate is a different monster, because those are checked before focus.
   - Duplicate Dragon: items from duplicate groups, photos or videos (videos are clustered too, and a copy takes the group's photo-typed monster); copies, bursts, edits and repeats all count.
   - Video Vampire: videos of 100 MB or more but under 500 MB that fit no other monster.
   - LongTake Leviathan: videos over two minutes, under 500 MB, not 4K and not duplicates.
   - Memory Hog Minotaur: videos of 500 MB or more but under 1 GB, not duplicates (two identical 1.2 GB videos are a Perfect Pair Wyrmling, not a Gorgon).
   - Storage Liberation: "Delete 500 MB of photos and videos today. Each room you confirm adds the size of what you deleted." (it said "in one session", but the count builds across the day and across dives; see 6).
   - Dungeon Clear: "Delete 25 photos or videos. Any monster counts; Shades do not." A caption under the list says Shades never count toward any quest.
   The Library's quest row has no line limit, so a rule is never cut off.
3. **"Delete", not "purged", wherever the player reads an action or a count.** The app name and the names PurgeQuest, Phantom Purge, Resolution Purge, Purge Plate, The Great Purge and the Video Vampire Purge quest keep "Purge". `repo_guard` check 18 holds the line.
4. **Shade gloss:** "a photo or video you deleted before; deleting it again pays nothing."
5. **Lore text left as is:** `MonsterType.lore` still says "Slay one, the other vanishes."
6. **Storage quest bookkeeping fixed (owner: yes, 15 November 2026).** `CombatViewModel` booked each file as `Int((bytes / 1,048,576).rounded())`, so 600 screenshots of 470 KB (282 MB) added 0 and one 500,000,000-byte video added 477, not 500. A confirmed room now adds up the bytes of everything that awards progress and rounds once to the nearest megabyte of 1,000,000 bytes, like Photos and the classifier (`QuestProgress`, `GameDataService.addStorageProgress`); the Room Summary's quest preview adds up the same way. Rounding per room, not per file, needs no new stored property, so no saved data changes; the error is at most half a megabyte per confirmed room, and it does not lean one way. `updateQuests` no longer takes a megabyte argument.

**Still open (found while doing 2, not changed):**
- The event taglines and the medium widget's two-line cut are postponed by the owner ("future update", "postpone widget work").
- A quest lasts 24 hours from when it is drawn (`Quest.expiresAt`), and `updateQuests` never checks it, so "today" is approximate.
- The four seasonal event taglines make the same kind of claim and some overstate: Summer says "+50% video XP" but the bonus covers three video monsters; Valentine says "+60% photo XP" for three photo monsters; Halloween says "shadowy foes"; New Year's "captures from years past" is really photos three or more years old with nothing else wrong.
- The medium widget shows the quest line at two lines of small text, so the longer rules are cut with an ellipsis there. The small widget shows only the title and count.
- A quest already stored on a device keeps its old line until the day's quests are redrawn (at most a day).
