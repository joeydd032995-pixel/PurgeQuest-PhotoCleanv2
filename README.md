# PurgeQuest

**A native iOS dungeon-crawler RPG that turns Camera Roll cleanup into combat.**

Photos and videos in your library appear as monsters. Swipe left to slay (delete) or right to spare. Nothing is ever permanently destroyed by the app: every "kill" moves the item to Photos' **Recently Deleted**, where it stays recoverable for 30 days, and nothing moves until you confirm the room.

- **Platform:** iOS 18.0+, iPhone only, portrait
- **Language:** Swift (language mode 5, built with the Swift 6.2 toolchain), about 27,000 lines across 151 files, tests included
- **UI:** SwiftUI · **Persistence:** SwiftData · **Dependencies:** none, first-party Apple frameworks only
- **Bundle ID:** `com.purgequest.app` · **Version:** 1.0.0
- **Network activity:** none. No analytics, ads, accounts or third-party SDKs. `tools/ci/repo_guard.py` fails the build if that changes.

> Built and iterated on via [Rork](https://rork.com), an AI-native iOS app builder (see `rork.json`), which still syncs commits into this repository.

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
- [Open Items](#open-items)
- [License](#license)

---

## Features

### Core combat loop
- Your Camera Roll is split into **dungeon dives**: 5 rooms per session, 20 items per room (`ViewModels/CombatViewModel.swift`).
- **Rooms lean toward clutter, without going predictable.** A dive loads the 150 oldest unseen items. Before each room is dealt it counts what is left in four buckets: blurry photos, screenshots, videos over 100 MB or 2 minutes, and photos three or more years old. It then fills 30–50% of the room from the largest bucket and the rest at random. A bucket with nothing left means a pure random room (`Services/RoomTargeting.swift`). The dashboard's **Focused Dive** menu (Blur / Screenshots / Large Video / Old) names a bucket instead and fills rooms from it first; it applies to that one dive, and "Enter the Dungeon" stays the mixed default. A focus can only lean on what the dive's 150 items hold, and hand-picked hunts are dealt exactly as chosen.
- Each item is classified into one of **36 monsters in six families** (below) and rendered as a swipeable combat card (`Views/Combat/SwipeMediaCard.swift`): swipe left to slay (queue for deletion), right to spare. Duplicates are dealt as one group card with a suggested keeper (`Views/Combat/DuplicateGroupCard.swift`).
- A **combo multiplier** ramps your XP/gem rewards every 5 consecutive slays without sparing; sparing resets the combo.
- Before anything is deleted, a **Room Summary** screen lists every queued item and requires explicit confirmation (`Views/Combat/RoomSummaryView.swift`). Individual items can be flipped from delete to spare right up until that point. Photos then shows its own delete prompt; rewards are booked only after that succeeds.

### Monster classification (on-device)

Classification is two steps with a hard line between them. **Signals** are measured from PhotoKit, a thumbnail, three sampled video frames and an on-device Vision pass. **`Services/MonsterClassifier.swift`** then turns signals into a monster and the reasons for it. The classifier is pure Foundation over plain values, so every rule runs in the Linux test harness.

| Family | Monsters | What summons them |
|---|---|---|
| Duplicate Dragons (8) | Perfect Pair Wyrmling, Duplicate Dragon, Burst Hydra, Clone Chimera, Screenshot Twin, Download Drake, Album Echo, Hoard Hydra | A cluster of look-alikes: identical files, a burst seconds apart, cropped or edited copies, the same picture saved again later, six or more copies |
| Clutter Undead (8) | Screenshot Specter, Live Photo Lycan, Tome Wraith, Sigil Specter, Thumb Goblin, Low-Quality Lich, Blur Beast, Dark Wraith | The screenshot flag; a Live Photo; dense text (a photographed document); a QR or barcode; a long edge under 640 px; a tall, small image saved from elsewhere; a focus score under 55; a frame that is dark even at its highlights |
| Archive Relics (1) | Ancient Archive | A photo at least three years old **with none of the defects above** |
| Storage Behemoths (5) | Gigabyte Gorgon, Memory Hog Minotaur, 4K Kraken, LongTake Leviathan, Panorama Colossus | A video of 1 GB or more; 500 MB or more; a 3840 px edge; over two minutes. A panorama (Photos' flag, or 2.5 times wider than tall) |
| Video Phantoms (11) | Screen Recording Shade, Timelapse Phantom, Flicker Wraith, Framed Phantom, Pocket Poltergeist, Shaky Ghost, Boring Blooper, Video Vampire, Mist / Tatter / Void Wraith | Photos' screen-recording flag (or the file names iOS gives recordings); a time-lapse, slow-motion or looping clip; brightness strobing between sampled frames; sampled frames that hold still; near-black or under two seconds; a large brightness jump between samples; under five seconds; 100 MB or more; otherwise a Wraith by length (under 20 s, under 60 s, longer) |
| Glitchborn (3) | Corrupted Codec, Null Portrait, Static Husk | A video with no duration or that will not load; a photo that will not render; an empty file |

Rule order, briefly: broken media first, then what the item *is* (a code, a Live Photo, a screenshot, a document, a panorama, a thumbnail), then what is *wrong* with it (proportions, focus, exposure), and only then its age. Age is true of every photo in an old library and dives are dealt oldest first, so an age rule ahead of the defects would hide them for years of photos. An old photo with a defect is named for the defect, says it is old as well, and keeps the careful-review flag.

Every verdict carries its reasons (`Models/MonsterClassification.swift`), shown on the card as "why did this appear?". Fragile kinds (old photos, broken media, anything with a code) are flagged for careful review. The only verdict that is a guess is the fallback for a photo or clip with no signal at all, and it says so. See [Open Items](#open-items) for the weak spots.

**Where a Core ML model would go.** There is no bundled model. A model replaces a *signal*, not the classifier: the focus score (`ThumbnailAnalysis`), the frame signals (`VideoFrameSignals`) or the text signals (`VisionTextSignals`) each have one producer and one plain struct the classifier reads. Keep the heuristic as the fallback when the model is missing or fails (`.agents/skills/coreml-model-swap`).

### Detection quality

The scan's measurements live in pure-Foundation files (`Services/ThumbnailAnalysis.swift`, `Services/DuplicateDetection.swift`) so the same code runs in the app, in the Linux test harness and in a real-photo benchmark (`tools/detection_bench`, see its README).

- **Blur** is the fraction of fine detail lost to a light re-blur of a 256×256 grayscale render, scored 0–100 (`ThumbnailAnalysis.focusScore`). A picture with almost no edges (a clear sky, a black frame) is *not judged*, which is different from blurry.
- **Dark** needs the mean luminance below 0.18 *and* the brightest 5% of the frame below 0.30 (`PhotoRules.isDark`). A night scene with lights is not a dead frame. Both numbers are single constants in `PhotoRules`.
- **Duplicates** compare a 64-bit difference hash and a 16×16 luminance signature. Two copies match when the hashes are within 14 bits *and* the signatures correlate at 0.88 or better; an asset without a signature falls back to the dHash alone at 10 bits. Groups stay complete-linkage and deterministic.

Measured on 157 real photographs from INRIA CopyDays plus edited and degraded copies of them (`tools/detection_bench`; numbers are from a release build of the app's own Swift, on thumbnails rendered with Pillow rather than CoreGraphics, so treat absolute values as estimates and the before/after comparison as exact):

| | before | after |
|---|---|---|
| Different-scene pairs wrongly grouped (all 857 images in one batch) | 12 pairs, 16 images | **1 pair, 2 images** |
| Pair precision in the app's 150-photo batches | 98.7% (49 false pairs) | **100.0%** (1 false pair) |
| Mild 8% crop found with its original | 63.7% | **79.6%** |
| Re-saved (1600 px, JPEG 70) and brightened copies found | 98.7% / 99.4% | 99.4% / 99.4% |
| Blur flagged: Gaussian σ = 3 / 5 / 8 px at 600 px thumbnail scale | 0% / 0% / 2.5% | **74.5% / 98.7% / 98.1%** |
| Blur flagged: 15 / 31 px horizontal motion blur, same scale | 0% / 0% | **51.0% / 96.8%** |
| Sharp photographs flagged blurry | 0% (the old rule effectively never fired) | 0.6% (1 of 157, a hazy sunrise) |
| Ordinary photographs flagged dark | 1.3% | **0%** |
| Underexposed copies flagged dark: 4.6 / 3.6 / 2.7 stops under | 99.4% / 94.3% / 30.6% | 99.4% / **80.9% / 17.2%** |
| Duplicate engine, 5,000 / 20,000 assets | 89 ms / 2,072 ms | **20 ms / 243 ms** |

What this does **not** show:

- The dark rule trades recall for precision: it spares low-key photographs with real highlights at the cost of missing some moderately underexposed ones (the table says by how much). Raise `PhotoRules.darkHighlight` to flag more.
- The 157 scenes are one small collection. The thresholds (14 bits, 0.88, 55, 0.30) sit at the measured knee with margin, not at the optimum of a large library, and should be re-measured on a real one before being tightened. The benchmark contains no burst sequences and no hard negatives beyond what CopyDays happens to hold.
- The strongest CopyDays edits (paintings, print-and-scan, heavy crops) are still found about 5% of the time. No cheap hash does better, and they are not typical library duplicates.
- Duplicates are still only found among a dive's 150 assets (see `docs/superpowers/plans/2026-11-07-duplicate-detection-hardening.md`, "Not in this plan"): a twin elsewhere in the library is not seen.
- Not measured, because there is no iPhone or Vision framework here: the scan-time effect of the scan-pipeline changes below, and the text-recognition changes. They are reasoned, not benchmarked.

**Scan pipeline** (`Services/PhotoLibraryService.swift`, `VisionAnalysisService.swift`, `MLAnalysisService.swift`): the app builds with approachable concurrency, under which a plain `nonisolated async` function runs on its caller's actor, so the Vision pass was running on the main actor, one photo at a time. It is now `@concurrent`, assets are enriched four at a time (`BoundedConcurrency`), a photo's resources are listed once instead of twice, the three separate bitmap renders became one, the text pass is skipped for Live Photos and screenshots (the classifier names them before it reads text) and Vision is skipped for videos (their verdict never uses it). Text density now needs real words behind many regions (≥ 60 characters), so a street of shop signs is not a document.

**Since those numbers were measured**, two things changed that the benchmark does not cover, and no threshold moved:

- *Rule order.* Blur, dark and tall-download now run before the three-year age rule (see above). The benchmark measures each rule on its own, so its figures stand; what changed is which photos reach those rules.
- *Motionless video.* The Framed Phantom was decided from the change in each sampled frame's **average brightness**, which movement does not alter. The three frames are now compared cell by cell on a 16×16 grid, with the same 0.015 threshold. A frame difference is never smaller than the difference of the averages, so the new rule's motionless clips are a subset of the old rule's. **This is not measured on real video**: none is available off a device.

### RPG progression
- **17 hero classes** in three styles (melee, ranged, magic), each with one passive perk such as +20% XP from a monster family or a gem multiplier (`Models/Hero.swift`).
- **8 races** with three paints each (Skeletal Undead has six), 27 art packs in all. Race and paint are cosmetic and independent of class.
- XP and levels, HP, gems, purge and streak stats, all on the `Hero` SwiftData model.
- **Daily quests**: 4 drawn each day from a pool of 7 (`QuestCatalog` in `Models/GameContent.swift`). A quest that names the Duplicate Dragon counts the whole Duplicate Dragons family.
- **11 achievements** (`Services/GameDataService.swift`), recomputed from lifetime stats and the deletion log after each room, so progress never depends on one event firing.
- **Anti-farm ledger**: an item deleted once never pays again if it is restored and deleted a second time.
- **Bestiary**: every monster met, with its signal, lore and review guidance (`Views/Bestiary/`).

### Cosmetics & avatar
- A **41-item cosmetic catalog** (skin, head, armor, legs, hands, weapon, shield, pet, effect, upgrade), bought with gems earned by freeing space.
- The hero is drawn from layered sprite art with skin, hair, eye and armor-dye recoloring, held weapons and shields, and a **Forge** for editing a look as a draft until saved (`Views/Hero/`). A hand-drawn vector avatar (`MiniAvatarView` and its `MiniAvatar+…` files) serves compact contexts.
- Two color themes (Classic, Verdigris) and a Light / Dark / System appearance setting.

### Monetization
- **StoreKit 2**: three consumable gem packs and three non-consumable cosmetic unlocks (`Services/StoreKitService.swift`, local test configuration in `Configuration.storekit`). All gameplay and all cleanup is free; purchases are cosmetic, and nothing bought is random.

### Seasonal events
- Four date-based events (Halloween, New Year, Summer, Valentine's), each paying bonus XP for a few monsters and selling event gear only while it runs (`Services/SeasonalEventService.swift`, bonuses in `SeasonalBonusCatalog`). No remote config; local date matching only. A bonus for the Duplicate Dragon pays for the whole family, as quests do.

### Widgets
- **Home Screen widgets** (Daily Quest, Streak) and two **Lock Screen** widgets, fed by a small snapshot in the App Group (`Services/WidgetSnapshotService.swift`, `PurgeQuestWidget/`). They show level, streak, gems and the current quest, never photos.
- **Live Activities are not shipped.** `CombatLiveActivityService` requests one, but the widget extension declares no activity UI and the app lacks the `NSSupportsLiveActivities` key, so nothing appears. See [Open Items](#open-items).

### Other features
- **Apple Intelligence flavor text** (iOS 26+): the system's on-device model writes a one-line taunt per monster, with fixed strings when it is unavailable (`Services/FoundationFlavorService.swift`).
- **7-day deletion log** in Settings, with a button that opens Photos.
- **Spared-item memory**: re-entering the dungeon skips items you already spared; resettable in Settings.
- **Muted, looping video previews** on combat cards from a single pooled player (`Services/VideoPreviewService.swift`).
- **Haptics** for delete, spare and combo, respecting Reduce Motion.
- **Shareable Hero Card** rendered with `ImageRenderer` and shared through `ShareLink`.
- **Storage measurement**: free space is read before and after a purge, so the dashboard separates what was measured from what is estimated (`Services/StorageMeasurementService.swift`).

---

## Privacy & Safety Model

- **Deletion is always recoverable.** The only delete call is `PHAssetChangeRequest.deleteAssets`, in `Services/PhotoLibraryService.swift`, which Photos routes to **Recently Deleted**. `repo_guard.py` fails if any other file deletes assets.
- **Two confirmations.** The Room Summary must be confirmed, and then the system's own delete prompt. Declining either deletes nothing.
- **Fully offline.** No network requests, analytics, third-party SDKs or cloud sync. `repo_guard.py` fails on any networking API or package reference. (Photos itself may download an iCloud original when a thumbnail is requested.)
- **Privacy manifests.** The app and the widget each ship a `PrivacyInfo.xcprivacy`: no tracking, no collected data, and a declared reason for the two required-reason APIs in use (user defaults, free disk space).
- **Permissions:** read/write Photos access for gameplay, add-only access for saving the Hero Card, both set as `INFOPLIST_KEY_*` build settings.

Submission material, including the privacy-label answers and App Review notes, is in [`docs/appstore/`](docs/appstore/).

---

## Technical Stack

| Layer | Choice |
|---|---|
| Language | Swift, language mode 5, approachable concurrency with default main-actor isolation; needs the Swift 6.2 toolchain (Xcode 26) |
| UI framework | SwiftUI (iOS 18.0+ deployment target) |
| State management | Swift's `@Observable` macro |
| Persistence | SwiftData, 9-model schema, on-device only, with an in-memory fallback if disk init fails |
| Media access | `Photos` / `PhotosUI` |
| Video | `AVFoundation` (pooled preview player; three sampled frames per clip for classification) |
| Haptics | `CoreHaptics` |
| Classification | Pure-Swift rules over signals from `Photos`, `CoreGraphics` thumbnails, `AVFoundation` frames and `Vision` (text, barcodes). No bundled model. |
| Widgets | `WidgetKit`, sharing one snapshot through App Group `group.com.purgequest.app` |
| In-app purchases | `StoreKit` 2 |
| On-device generative text | `FoundationModels` (iOS 26+, conditionally compiled) |
| Testing | Swift Testing (unit), XCUITest (UI), a Linux harness for the pure logic, Python checks for assets and repository contracts |
| Build system | Xcode project with file-system-synchronized groups; no SwiftPM, CocoaPods or Carthage |
| Third-party dependencies | **None** |
| Backend | **None** |

---

## Project Structure

```
PurgeQuest-PhotoCleanv2/
├── LICENSE                       proprietary notice
├── rork.json                     Rork manifest
├── .agents/skills/               working notes for agents on this codebase
├── .github/workflows/            ios.yml (unit + UI tests), objective-c-xcode.yml (build + analyze),
│                                 modular-assets.yml (asset checks + Linux harness), repo-guard.yml
├── docs/
│   ├── appstore/                 submission checklist, review notes, privacy answers, screenshot plan
│   ├── modular/                  modular character pipeline: README, REVIEW.md (start here to approve), CHECKLIST.md, ledger
│   ├── CREDITS.md, licenses/     third-party art
│   └── superpowers/              design specs and plans
├── tools/
│   ├── ci/                       repo_guard.py (offline, no deps, recoverable deletion, ship-path invariants), xcode-test.sh
│   ├── swift_harness/            run.sh: the pure-Foundation sources and suites on a Linux toolchain
│   ├── detection_bench/          duplicate, blur and dark rules measured on real photographs
│   └── modular_assets/           Python pipeline, validator, approvals, review guide generator
└── ios/
    ├── README-SETUP.md           build, sign, run, device test pass
    ├── PurgeQuest.xcodeproj/
    ├── PurgeQuest/               app target
    │   ├── PurgeQuestApp.swift, ContentView.swift, PrivacyInfo.xcprivacy, Configuration.storekit
    │   ├── Models/               SwiftData models and value types; GameContent.swift (quests, seasonal bonuses)
    │   ├── Services/             PhotoLibraryService, MonsterClassifier and the signal types, DuplicateDetection,
    │   │                         ThumbnailAnalysis, RoomTargeting, SpriteEngine, StoreKitService, widgets, haptics
    │   ├── ViewModels/           AppState, CombatViewModel
    │   ├── Views/                Onboarding, Dashboard, Combat, Hero, Bestiary, Shop, Achievements, Settings, Components
    │   ├── Extensions/           palette, fonts
    │   └── Art/, Assets.xcassets race packs, gear, modular layers and masks, sprite sheets, icons
    ├── PurgeQuestWidget/         WidgetKit extension (its own copy of the snapshot struct)
    ├── PurgeQuestTests/          Swift Testing suites
    └── PurgeQuestUITests/        Forge flows, onboarding reset, Light/Dark screenshot tour
```

---

## Architecture

- **Pattern:** feature-folder MVVM. Two `@Observable` view models drive the app: `AppState` (phase, tab, photo authorization) and `CombatViewModel` (room and session state, swipe outcomes, rewards).
- **Navigation:** `ContentView.swift` switches on `AppPhase` (launching, onboarding, main) and hosts six tabs: **Library**, **Hero**, **Bestiary**, **Armory**, **Trophies**, **Settings**. Combat is pushed from the Library tab.
- **Data:** SwiftData only. `PurgeQuestApp.swift` builds a container for `Hero`, `Achievement`, `CosmeticItem`, `Quest`, `DeletedMediaRecord`, `CombatSession`, `SparedMediaRecord`, `MediaFingerprintRecord` and `MonsterSightingRecord`.
- **App and widget:** the widget cannot import the app module, so state crosses through `UserDefaults(suiteName:)` and a snapshot struct duplicated on each side. `repo_guard.py` fails if the two copies, the key or the App Group name drift apart.
- **Pure logic apart from frameworks.** Anything that decides (classification, duplicate clustering, thumbnail metrics, room targeting, fitting, recolor math, game content) is Foundation-only and has no PhotoKit, UIKit or SwiftData in it. Framework-facing services measure and persist; they do not decide. That line is what lets the Linux harness run the rules.

---

## Asset Organization

The hero is rendered from layered PNG parts plus Spriter (SCML) animation projects, composited at runtime by `Services/SpriteEngine.swift`. `Views/Hero/MiniAvatarView.swift` and its `MiniAvatar+…` files hand-draw a vector avatar for compact contexts. UI icons use SF Symbols; the palette lives in `Extensions/Color+Theme.swift`. Composition rules and the shared surface, bar and hero-stage components are in [`docs/design/DESIGN_SYSTEM.md`](docs/design/DESIGN_SYSTEM.md).

```
ios/PurgeQuest/Art/Races/<race>/v1..v3/   baked race parts + .scml animation (27 packs; Skeletal Undead ships two)
ios/PurgeQuest/Art/Gear/{staves,shields}/ 40 staves, 40 shields (held gear, swapped in at the weapon/shield anchor)
ios/PurgeQuest/Art/Gear/store/            the 11 store weapons and shields (generated sprites)
ios/PurgeQuest/Art/Modular/               separated anatomy / armor / headgear layers, recolor masks, and the two bundled manifests
```

The modular character pipeline (separated anatomy and armor, material masks, per-body-profile fits, held-gear grips, Titan Blade scaling) is generated by `tools/modular_assets/` and documented in [`docs/modular/README.md`](docs/modular/README.md).

**Its assets are candidates until a person approves them.** Approval is one art pack at a time: an approved pack renders through the modular path and unlocks its body colors in the Forge; every other pack keeps the legacy renderer and looks as it does today. Today **0 of 27 packs are approved**, so every hero uses the legacy renderer, which is a complete state. Each approval is pinned to a hash of the files reviewed, so regenerating an asset strands its approval rather than silently keeping it. To review, start at [`docs/modular/REVIEW.md`](docs/modular/REVIEW.md).

---

## Third-party art

The Wraith monsters, Forest Spirit pets and Phantom Purge event art come from outside packs, converted
to sprite sheets. Authors, licenses and what is still unconfirmed are listed in [`docs/CREDITS.md`](docs/CREDITS.md).

## Getting Started

Full steps, the StoreKit configuration and the device test pass are in [`ios/README-SETUP.md`](ios/README-SETUP.md). In short:

1. Xcode 26 or later; open `ios/PurgeQuest.xcodeproj`.
2. Set your team on **PurgeQuest** and **PurgeQuestWidget** (`DEVELOPMENT_TEAM` is blank in the repository) and provision the App Group `group.com.purgequest.app`.
3. Run on a real iPhone. The Simulator's library has no screen recordings, time-lapses or Live Photos, and several features (haptics, widgets) do not fully exercise there.

---

## Testing

| What | Where | Runs in |
|---|---|---|
| Unit tests (Swift Testing): classification, duplicates, thumbnail rules, room targeting, XP, bestiary, hero identity and migration, modular foundation, held gear, recolor, Forge logic, seasonal catalog, bundled resources | `ios/PurgeQuestTests/` | `.github/workflows/ios.yml` |
| UI tests: Forge draft/save/cancel, onboarding after a reset, a Light/Dark screenshot tour (artifact `ui-snapshots`) | `ios/PurgeQuestUITests/` | `ios.yml` |
| Build and static analysis | | `.github/workflows/objective-c-xcode.yml` |
| Screenshots of every screen, Light and Dark, with a synthetic photo library in the simulator (artifact `ui-snapshots-tour`; not a merge gate) | `tools/ci/make_library_fixtures.py` | `.github/workflows/ui-snapshots.yml`, on pull requests that touch the app |
| **Linux harness**: the pure-Foundation sources and their suites, no Xcode or simulator. 275 tests in 20 suites, including the classifier, the audit that every monster named by a quest or event can be summoned, capture rules, rule precedence, video frame signals and the scan's bounded-concurrency and deadline helpers | `tools/swift_harness/run.sh` | `.github/workflows/modular-assets.yml` |
| Asset checks: manifests, masks, fits, the approval gate (content-pinned), catalog drift, generated docs up to date. 72 tests | `tools/modular_assets/` | `modular-assets.yml` |
| Repository contracts: offline, no dependencies, recoverable deletion, StoreKit IDs, App Group and snapshot agreement, privacy manifests, versions | `tools/ci/repo_guard.py` | `.github/workflows/repo-guard.yml` |
| Detection benchmark on real photographs (not in CI) | `tools/detection_bench/` | by hand |

Not automated: visual approval of art, anything on a physical iPhone, and video classification on real footage.

---

## Open Items

What is known to be unfinished or weak, checked against the source. The submission blockers that only the owner can close (art licenses, signing, App Store Connect products, a privacy policy URL, a device pass) are listed in [`docs/appstore/README.md`](docs/appstore/README.md).

**Classification**

1. **An ordinary photo is called a Blur Beast.** A sharp, recent photo with no signal falls back to the Blur Beast with the reason "no strong signals". It then counts toward the "Blur Beast Hunter" quest and the Valentine's bonus. Videos have three Wraiths for this case; photos need a neutral monster of their own. Not done because it adds a monster (name, lore, art), which is a content decision.
2. **The Shaky Ghost does not measure shake.** It fires when average brightness jumps by 0.14 between sampled frames. Real shake needs adjacent frames and motion between them.
3. **Video rules are unmeasured.** The photo rules have a benchmark; the video thresholds (flicker, dark, the brightness jump) have never been run against real footage.
4. **Dense text is read from a thumbnail.** A photographed page whose text is small at thumbnail size may not reach the 60-character line and so will not become a Tome Wraith.
5. **Duplicates are found within a dive's 150 items only**; a twin elsewhere in the library is not seen.
6. **No Core ML model.** The seam is described above.

**Product**

7. **Live Activities are not wired** (see Widgets). Either build the widget-side UI and add the plist key, tested on a device, or remove the service.
8. **`photos-redirect://`.** Settings opens Photos with an undocumented URL scheme, under a label that promises Recently Deleted.
9. **Modular characters: 0 of 27 packs approved.** The path, the tooling and the review guide exist; the looking has to be done by a person.

**Repository**

10. **Art provenance.** The Forest Spirit pets have no known license, and the 27 hero packs and 80 staves and shields are not in `docs/CREDITS.md`.
11. **The shared scheme selects no StoreKit configuration**, so local purchase testing needs one manual step (`ios/README-SETUP.md`).
12. **Test bundle identifiers** still carry Rork's generated prefix (`app.rork.…`). Harmless; left alone.

---

## License

Proprietary, all rights reserved: see [`LICENSE`](LICENSE). The app is a commercial game that bundles third-party art whose licenses forbid redistributing it as assets, so an open-source license over the repository could not cover those files. Third-party art keeps its own terms, listed in [`docs/CREDITS.md`](docs/CREDITS.md).
