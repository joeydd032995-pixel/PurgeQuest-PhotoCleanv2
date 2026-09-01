# PurgeQuest

**A native iOS dungeon-crawler RPG that turns Camera Roll cleanup into combat.**

Photos and videos in your library appear as monsters. Swipe left to slay (delete) or right to spare. Nothing is ever permanently destroyed by the app — every "kill" simply moves the item to Photos' **Recently Deleted**, where it stays recoverable for 30 days.

- **Platform:** iOS 18.0+, iPhone only (Dynamic Island devices fully supported)
- **Language:** 100% Swift (Swift 5), ~7,100 lines across 50 files
- **UI:** SwiftUI · **Persistence:** SwiftData · **Dependencies:** none — first-party Apple frameworks only
- **Bundle ID:** `com.purgequest.app` · **Version:** 1.0.0
- **Network activity:** none — the app is fully offline, with no analytics, ads, or third-party SDKs

> Built and iterated on via [Rork](https://rork.com), an AI-native iOS app builder (see `rork.json`). Several files and `.gitignore` entries in this repo carry Rork's fingerprints — see [Known Issues & Recommendations](#known-issues--recommendations).

---

## Table of Contents

- [Features](#features)
- [Privacy & Safety Model](#privacy--safety-model)
- [Technical Stack](#technical-stack)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Asset Organization](#asset-organization)
- [Getting Started](#getting-started)
- [Testing](#testing)
- [Known Issues & Recommendations](#known-issues--recommendations)
- [Roadmap](#roadmap)
- [License](#license)

---

## Features

### Core combat loop
- Your Camera Roll is split into **dungeon dives**: 5 rooms per session, 18 items per room (`ViewModels/CombatViewModel.swift`).
- Each item is classified into one of **13 monster types** (below) and rendered as a swipeable combat card (`Views/Combat/SwipeMediaCard.swift`) — swipe left to slay (queue for deletion), right to spare.
- A **combo multiplier** ramps your XP/gem rewards every 5 consecutive slays without sparing; sparing resets the combo.
- Before anything is deleted, a **Room Summary** screen lists every queued item and requires explicit user confirmation (`Views/Combat/RoomSummaryView.swift`) — individual items can be flipped from delete → spare right up until that point.

### Monster classification (on-device, heuristic)
`Services/MLAnalysisService.swift` classifies each photo/video using cheap on-device heuristics — no bundled ML model yet (see [Known Issues](#known-issues--recommendations)):

| Photo monsters | Trigger | Video monsters | Trigger |
|---|---|---|---|
| Duplicate Dragon | *(defined but never assigned — see Known Issues)* | Video Vampire | large file, medium duration |
| Blur Beast | Laplacian-variance blur estimate | LongTake Leviathan | duration > 2 min |
| Screenshot Specter | `PHAsset` screenshot subtype flag | Shaky Ghost | default video fallback |
| Low-Quality Lich | narrow aspect ratio | Boring Blooper | duration < 5s |
| Ancient Archive | photo older than 3 years | Memory Hog Minotaur | file size > 500 MB |
| Dark Wraith | low average luminance | Timelapse Phantom | timelapse/high-frame-rate subtype |
| | | Corrupted Codec | *(defined but never assigned — see Known Issues)* |

Classification is behind a pluggable `PhotoClassifier`/`VideoClassifier` protocol (`Services/MediaClassifier.swift`), explicitly designed as a strategy-pattern seam for swapping in real Core ML models later.

### RPG progression
- **4 hero classes** (`Models/Hero.swift`), each with a passive perk: Archivist (+20% photo XP), Cinematographer (+20% video XP), Purge Knight (+30% elite-monster XP), Digital Hermit (+10% gems).
- **2 cosmetic character archetypes** (Knight, Magician) — purely visual, independent of hero class.
- XP/leveling curve, HP, gems, purge/streak stats, all persisted on the `Hero` SwiftData model.
- **Daily quests** — 4 randomly drawn each day from a pool of 7 (`Services/GameDataService.swift`), e.g. "Blur Beast Hunter," "Storage Liberation" (free 500 MB), refreshed once expired.
- **11 achievements/trophies** (`Views/Achievements/AchievementsView.swift`), e.g. "First Blood," "The Great Purge" (free 1 GB), "Combo King" (20× combo).
- **Daily login streak** tracking (`Hero.streakDays`).

### Cosmetics & avatar
- A **27-item cosmetic catalog** across 7 gear slots — skin, head, armor, weapon, shield, pet, FX (`Models/CosmeticItem.swift`, seeded in `GameDataService.swift`) — purchased with in-game "Storage Gems" earned by freeing space.
- `Views/Hero/MiniAvatarView.swift` hand-draws the entire hero avatar in pure SwiftUI vector shapes, changing live as gear is equipped — see [Asset Organization](#asset-organization).

### Monetization
- **StoreKit 2** consumable gem packs and non-consumable cosmetic bundles (`Services/StoreKitService.swift`, local test config in `Configuration.storekit`). Core gameplay is entirely free; purchases are cosmetic-only.

### Seasonal events
- 4 date-based limited-time events — Halloween ("Phantom Purge"), New Year ("Resolution Purge"), Summer ("Vacation Bloat"), Valentine's ("Heartbreak Hunt") — each applying an XP multiplier to specific monster types (`Services/SeasonalEventService.swift`). No remote config; pure local date matching.

### Widgets & Live Activities
- **Home Screen widgets** (Daily Quest, Streak) and two **Lock Screen** accessory widgets, fed via an App Group snapshot (`Services/WidgetSnapshotService.swift`, `PurgeQuestWidget/` target).
- **Live Activities / Dynamic Island** support showing HP, combo, and room progress during an active dive (`Services/CombatLiveActivityService.swift`, gated behind iOS 16.1+/`ActivityKit` availability).

### Other features
- **Apple Intelligence flavor text** (iOS 26+) — on-device `FoundationModels` generates witty per-monster taunts, with a static-string fallback when unavailable (`Services/FoundationFlavorService.swift`).
- **7-day undo/audit log** of deletions, surfaced in Settings with a deep link to Photos' Recently Deleted (`Models/DeletedMediaRecord.swift`).
- **Spared-item memory** — re-entering the dungeon skips previously-spared items rather than re-showing them; resettable in Settings (`Models/SparedMediaRecord.swift`).
- **Muted, looping video previews** on combat cards via a single pooled `AVQueuePlayer` (`Services/VideoPreviewService.swift`).
- **Custom haptics** for delete/spare/combo events, respecting Reduce Motion (`Services/HapticsService.swift`).
- **Shareable Hero Card** — an `ImageRenderer`-based stat card shared via `ShareLink` (`Views/Settings/SettingsView.swift`).
- **5-page onboarding**: intro → photo-permission request → class selection → archetype/avatar selection → animated swipe tutorial (`Views/Onboarding/OnboardingView.swift`).
- **Settings**: video-only "Focus Mode" toggle, lifetime stats, privacy statement, full data reset.

---

## Privacy & Safety Model

- **Deletion is always recoverable.** Every delete action calls `PHAssetChangeRequest.deleteAssets` (`Services/PhotoLibraryService.swift`), which Apple's Photos framework routes to **Recently Deleted** — a 30-day recovery window. PurgeQuest never bypasses this; nothing is permanently erased by the app itself.
- **Explicit confirmation required.** The Room Summary screen must be confirmed before any deletion is committed.
- **Fully offline.** No network requests, no analytics, no third-party SDKs, no cloud sync — restated both in `ios/README-SETUP.md`'s App Review notes and in-app in the Settings privacy section.
- **Permissions requested** (`NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`, configured directly as `INFOPLIST_KEY_*` build settings): read/write Photos access for gameplay, and add-only access for saving the shareable Hero Card.

---

## Technical Stack

| Layer | Choice |
|---|---|
| Language | Swift 5.0 |
| UI framework | SwiftUI (iOS 18.0+ deployment target) |
| State management | Swift's `@Observable` macro (no Combine/Redux/MVVM library) |
| Persistence | SwiftData — 7-model schema, on-device only, with in-memory fallback if disk init fails |
| Media access | `Photos` / `PhotosUI` (`PHPhotoLibrary`, `PHCachingImageManager`, `PHAssetChangeRequest`) |
| Video | `AVFoundation` (pooled `AVQueuePlayer` for card previews) |
| Haptics | `CoreHaptics` |
| Classification | `Vision` / `CoreImage` (heuristic blur & luminance analysis) |
| Widgets | `WidgetKit` (Home Screen + Lock Screen), shared via App Group `group.com.purgequest.app` |
| Live Activities | `ActivityKit` (conditionally compiled, `#if canImport(ActivityKit)`) |
| In-app purchases | `StoreKit` 2 (async API) |
| On-device generative text | `FoundationModels` (Apple Intelligence, iOS 26+, conditionally compiled) |
| Testing | Swift `Testing` framework (unit) + `XCUITest` (UI) — scaffolds only, see [Testing](#testing) |
| Build system | Xcode project (`.xcodeproj`) — no SwiftPM `Package.swift`, no CocoaPods, no Carthage |
| Third-party dependencies | **None.** Every framework above is first-party Apple. |
| Backend | **None.** 100% on-device, no server component. |

---

## Project Structure

```
PurgeQuest-PhotoCleanv2/
├── .gitignore
├── rork.json                        # Rork platform manifest ({"apps":[{"name":"PurgeQuest","path":"ios","framework":"swift"}]})
└── ios/                              # The entire Xcode project — this is the whole app
    ├── README-SETUP.md               # Original setup doc (partially stale — see Known Issues)
    ├── .gitignore
    ├── PurgeQuest.xcodeproj/         # Xcode project, shared scheme
    │
    ├── PurgeQuest/                   # Main app target
    │   ├── PurgeQuestApp.swift       # @main entry point — builds the SwiftData ModelContainer
    │   ├── ContentView.swift         # Root view: splash → onboarding → 5-tab TabView
    │   ├── Config.swift              # Empty build-time env placeholder (Rork-injected; see Known Issues)
    │   ├── PurgeQuest.entitlements   # App Group entitlement
    │   ├── Configuration.storekit    # Local StoreKit testing config (mock IAP products)
    │   ├── Assets.xcassets/          # App icon + accent color — the only bitmap asset in the repo
    │   ├── Models/                   # 9 files — SwiftData models + value types (Hero, Quest, Achievement,
    │   │                             #   CosmeticItem, DeletedMediaRecord, CombatSession, SparedMediaRecord,
    │   │                             #   MediaItem, MonsterType)
    │   ├── Services/                 # 11 files — singleton/enum services (PhotoLibraryService,
    │   │                             #   MLAnalysisService, GameDataService, StoreKitService,
    │   │                             #   SeasonalEventService, WidgetSnapshotService, CombatLiveActivityService,
    │   │                             #   FoundationFlavorService, HapticsService, VideoPreviewService,
    │   │                             #   MediaClassifier protocol)
    │   ├── ViewModels/                # AppState (root @Observable), CombatViewModel
    │   ├── Views/
    │   │   ├── Onboarding/            ├── Achievements/
    │   │   ├── Dashboard/             ├── Hero/            (incl. 1,109-line MiniAvatarView.swift)
    │   │   ├── Combat/                ├── Shop/
    │   │   ├── Settings/              └── Components/      (shared: XPBarView, GemCounterView, etc.)
    │   └── Extensions/
    │       └── Color+Theme.swift      # Entire app color palette, code-based (no design-token file)
    │
    ├── PurgeQuestTests/               # Swift Testing unit test target — scaffold only
    ├── PurgeQuestUITests/             # XCUITest UI test target — scaffold only
    └── PurgeQuestWidget/               # WidgetKit extension target
        ├── PurgeQuestWidget.swift      # Daily Quest + Streak widget views
        ├── PurgeQuestWidgetBundle.swift # @main widget bundle entry
        └── SharedSnapshot.swift        # Codable snapshot struct (duplicated from the app target —
                                         #   widget extensions can't import the app module)
```

---

## Architecture

- **Pattern:** Feature-folder MVVM. Two `@Observable` view models drive the whole app — `AppState` (root: app phase, active tab, photo-library authorization) and `CombatViewModel` (room/session state, swipe outcomes, reward math) — injected via `.environment(...)`.
- **Navigation:** `ContentView.swift` switches on an `AppPhase` enum (`.launching` → `.onboarding` → `.main`) and hosts a 5-tab `TabView`: **Dungeon** (Dashboard) → **Hero** → **Trophies** (Achievements) → **Shop** → **Settings**. Combat is pushed via `NavigationStack.navigationDestination(isPresented:)`.
- **Data layer:** SwiftData is the *only* persistence mechanism — `PurgeQuestApp.swift` builds a `ModelContainer` from a 7-model schema (`Hero`, `Achievement`, `CosmeticItem`, `Quest`, `DeletedMediaRecord`, `CombatSession`, `SparedMediaRecord`), falling back to an in-memory store if disk creation fails. There is no backend, cache layer, or API client anywhere.
- **Cross-process sharing:** the app and the widget extension can't share Swift modules, so state crosses that boundary via `UserDefaults(suiteName: "group.com.purgequest.app")` and a duplicated `Codable` snapshot struct on each side.
- **Design patterns in use:**
  - **Strategy pattern** — `PhotoClassifier`/`VideoClassifier` protocols (`MediaClassifier.swift`) abstract monster classification, explicitly built so heuristic logic can be swapped for real Core ML models without touching call sites.
  - **Singleton services** — `PhotoLibraryService.shared`, `HapticsService.shared`, `VideoPreviewService.shared`, `StoreKitService.shared`, `SeasonalEventService.shared`.
  - **Stateless enum-namespaced services** — `GameDataService`, `MLAnalysisService`, `WidgetSnapshotService` (all `@MainActor enum` with static functions — no instance state).

---

## Asset Organization

**This project has no traditional image-asset pipeline.** A repo-wide search turns up exactly one bitmap file:

```
ios/PurgeQuest/Assets.xcassets/AppIcon.appiconset/icon.png   ← the only image asset in the entire repo
```

Everything else you'd normally expect to find as artwork is instead **generated in code**:
- The hero avatar, all gear, and equipment previews are hand-drawn using SwiftUI `Shape` primitives in `Views/Hero/MiniAvatarView.swift` (1,109 lines — the largest file in the project by a wide margin; see [Known Issues](#known-issues--recommendations)).
- Monster icons and cosmetic-item icons use **SF Symbols** by name (e.g. `"drop.halffull"`, `"flame.fill"`) rather than custom illustrations.
- The entire color palette is a Swift file, not a design-token or asset-catalog entry: `Extensions/Color+Theme.swift` (13 named colors + 3 gradients).

If you're expecting a `Resources/`, `Assets/Images`, or similar folder full of PNGs/SVGs, it doesn't exist — this is a deliberate architectural choice (zero art-pipeline dependency), not a gap. Future contributors adding new visual content should decide explicitly whether to continue the vector-in-SwiftUI approach or introduce a real asset catalog.

---

## Getting Started

**Requirements**
- Xcode 16+
- iOS 18.0+ SDK
- iPhone 12 or newer recommended (for Dynamic Island / Live Activities testing)
- A **real device is strongly recommended** — the iOS Simulator's Photos library is limited, and several features (haptics, Live Activities, widgets) don't fully exercise on Simulator.

**Build & run**
1. Open `ios/PurgeQuest.xcodeproj` in Xcode.
2. Under *Signing & Capabilities*, set your own Development Team — `DEVELOPMENT_TEAM` is blank in every build configuration in this repo.
3. If you want to exercise the `PurgeQuestWidget` target, its App Group entitlement (`group.com.purgequest.app`) needs to be provisioned under your own team.
4. To test in-app purchases locally without an App Store Connect record, select `Configuration.storekit` in the run scheme's StoreKit configuration (defines mock gem-pack and cosmetic-bundle products).
5. Build & run (⌘R) on device.

**Manual QA checklist** (there's no automated test coverage yet — see [Testing](#testing)):
- Use a library with mixed photos and videos of varying sizes/durations.
- Include photos older than 3 years (exercises Ancient Archive) and a video over 2 minutes / over 500 MB (LongTake Leviathan / Memory Hog Minotaur).
- Test with **Limited Photo Access** granted — the app should degrade gracefully.
- Run a full swipe loop through a Room Summary confirmation, then verify deleted items land in Photos → Recently Deleted.

---

## Testing

Two test targets exist and build, but **contain no real assertions** — this is pre-test-suite, MVP-stage software:

- `PurgeQuestTests/PurgeQuestTests.swift` — Swift `Testing` framework, exactly one empty `@Test func example()`.
- `PurgeQuestUITests/` — default Xcode-generated XCUITest launch/performance tests only, nothing app-specific.

**Recommended first targets for real coverage**, since both are pure logic with no UI/framework dependency:
- `Services/MLAnalysisService.swift`'s heuristic functions (`isLikelyBlurry`, `averageLuminance`, classification thresholds) — deterministic, easily unit-testable against known inputs.
- `Models/Hero.swift`'s `xpForLevel`/`xpForNextLevel` curve and `Services/GameDataService.updateQuests(...)` quest-progress logic.
- The two data-consistency bugs below — unit tests asserting "every referenced monster type is reachable by the classifier" and "every referenced cosmetic ID exists in the catalog" would have caught both, and would prevent regressions.

---

## Known Issues & Recommendations

Evidence-based findings from reading the current source — not speculative:

1. **"Duplicate Dragon" content is unreachable.** `MonsterType.duplicateDragon` has a daily quest ("Duplicate Dragon Slayer," `GameDataService.swift:113`), an achievement ("Duplicate Slayer," `GameDataService.swift:81`), and a seasonal-event bonus entry (`SeasonalEventService.swift:72`) — but `MLAnalysisService.classifyPhoto()` never returns `.duplicateDragon`, and no duplicate-detection logic (hashing, similarity comparison) exists anywhere in `Services/`. As shipped, that quest and achievement can never be completed. Same issue applies to `MonsterType.corruptedCodec`, referenced as a Halloween bonus monster but never returned by `classifyVideo()`.
2. **Seasonal events reference cosmetic IDs that don't exist.** All 4 events in `SeasonalEventService.swift` declare `exclusiveCosmeticIDs` (e.g. `"fx.spectral"`, `"weapon.fireworkBlade"`, `"pet.beachSpirit"`) — none of these 7 IDs appear in the 27-item catalog seeded by `GameDataService.cosmeticSeeds`. Seasonal events currently cannot grant their advertised exclusive cosmetics.
3. **`ios/README-SETUP.md` is stale.** Its "Known v1 limitations" section lists StoreKit IAPs, WidgetKit, Live Activities, and the Foundation Models flavor-text generator as unbuilt "future v2" work — all four are fully implemented in current code (`StoreKitService.swift`, `PurgeQuestWidget/`, `CombatLiveActivityService.swift`, `FoundationFlavorService.swift`). Its "Architecture" section also predates the `Views/Hero/`, `SeasonalEventService`, and widget-extension additions. This file is left untouched by design (documentation-only change) — worth refreshing separately.
4. **`Config.swift` is both git-tracked and gitignored.** It's committed to the repo (as an intentionally-empty placeholder — see its header comment) *and* listed in `ios/.gitignore`. This means `git status` will look clean even if the file's real, build-injected values differ locally — worth knowing so it doesn't cause confusion.
5. **Both `.gitignore` files carry unused React Native/Expo patterns** (`node_modules/`, `.expo/`, `babel.config.js`, `package.json`, etc.) — leftovers from Rork's cross-platform template generator, self-acknowledged in `ios/.gitignore`'s own comment ("should not exist in Swift projects"). Harmless, but dead weight worth cleaning up.
6. **`MiniAvatarView.swift` is disproportionately large** — 1,109 lines vs. the next-largest file at 426 (`ShopView.swift`). It mixes avatar-rendering logic with roughly 10 private `Shape` struct definitions. Worth splitting (e.g. shapes into their own file, or per-gear-slot rendering functions) if the avatar system keeps growing.
7. **No LICENSE file exists.** The legal terms under which this code may be used, modified, or redistributed are currently unspecified. Recommend the project owner add one.

---

## Roadmap

Genuinely open items, verified against current code (not simply copied from the older setup doc — several previously-listed "future" items turned out to already be shipped, see Known Issue #3 above):

- Replace heuristic photo/video classifiers with real bundled Core ML models (`BlurClassifier.mlmodel`, `VideoQualityScorer.mlmodel`) — flagged with `// TODO` in `Services/MLAnalysisService.swift`.
- Real motion/shake analysis (via `AVFoundation` + `Vision` feature points) for the "Shaky Ghost" video classification, which currently is just the default fallback rather than a genuine shake detector — also flagged with a `// TODO` in the same file.
- Actual duplicate-photo detection, to make the existing "Duplicate Dragon" quest/achievement completable (see Known Issue #1).
- Reconciling seasonal-event exclusive cosmetics with the real catalog (see Known Issue #2).

---

## License

No LICENSE file is currently present in this repository. All rights are reserved by default under copyright law unless the project owner adds explicit licensing terms.
