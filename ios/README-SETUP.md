# PurgeQuest — Setup

PurgeQuest is a native iOS dungeon-crawler RPG that turns Camera Roll cleanup into combat. Photos and videos appear as monsters; swipe left to delete (move to Recently Deleted) and right to spare.

## Requirements
- Xcode 16+
- iOS 18.0+ deployment target
- iPhone 12 or newer (Dynamic Island devices fully supported)
- Real device strongly recommended for testing — the iOS Simulator's Photos library is limited.

## Open & run
1. Open `ios/PurgeQuest.xcodeproj` in Xcode.
2. Set your signing team in *Signing & Capabilities*.
3. Build & run on a real device.

## Permissions
Configured in `project.pbxproj` via `INFOPLIST_KEY_*`:
- `NSPhotoLibraryUsageDescription` — required, mentions photos and videos and the 30-day Recently Deleted recovery window.
- `NSPhotoLibraryAddUsageDescription` — for sharing the Hero Card.
- Portrait-only iPhone, dark-mode forced via `INFOPLIST_KEY_UIUserInterfaceStyle = Dark`.

## Testing checklist (real device)
- Library with **mixed** photos and videos of varying durations and sizes.
- Include some old (>3yr) photos to exercise the Ancient Archive classification.
- Include at least one video > 2 minutes (LongTake Leviathan) and one > 500 MB if possible (Memory Hog Minotaur).
- Try with **Limited Photo Access** — the app degrades gracefully.
- Try the swipe loop, the room summary deletion confirmation, and verify items appear in Photos → Recently Deleted afterward.

## Architecture
- `Models/` — SwiftData persistent types (Hero, Achievement, Quest, CosmeticItem, DeletedMediaRecord, CombatSession) plus value-types for in-memory media (`MediaItem`, `MonsterType`).
- `Services/` — `PhotoLibraryService` (PHPhotoLibrary wrapper), `MLAnalysisService` (heuristic blur/duration classifier — see `// TODO` markers for Core ML hooks), `HapticsService`, `GameDataService` (seed/refresh).
- `ViewModels/` — `AppState` (root @Observable), `CombatViewModel` (room/session state, swipe outcomes).
- `Views/Onboarding|Dashboard|Combat|Achievements|Shop|Settings` — feature screens.
- `Views/Components` — `DungeonBackgroundView`, `XPBarView`/`HPBarView`, `GemCounterView`/`StatTile`, `ParticleBurstView`.

## Safety model
- All deletion goes through `PHAssetChangeRequest.deleteAssets`, which moves items to **Recently Deleted** (recoverable for 30 days). Nothing is permanently erased by PurgeQuest.
- The user must explicitly confirm each room's purge in the Room Summary screen. Individual items can be flipped from delete → spare before the alert appears.
- A 7-day local undo log lives in SwiftData (`DeletedMediaRecord`) so users can audit their recent purges in Settings.

## App Review notes
- All gameplay is offline; there are no network requests, third-party SDKs, or analytics.
- Photo/video access uses standard `PHPhotoLibrary` authorization.
- Deleted items always go to Recently Deleted — never permanently erased by the app.

## Known v1 limitations / future v2 prompts
- StoreKit 2 IAPs (gem packs, premium cosmetic bundles) are scaffolded conceptually but not wired — add the `Services/StoreKitService.swift` and a paywall flow.
- WidgetKit (daily quest widget) and Live Activities for active combat sessions — add via `swiftAddTarget` (widget extension).
- Foundation Models (Apple Intelligence) flavor text generator for monster encounters and quest descriptions — add an `LLMNarrationService` gated behind `iOS 18.1+`.
- Replace heuristic classifiers in `MLAnalysisService` with bundled Core ML models (`BlurClassifier.mlmodel`, `VideoQualityScorer.mlmodel`) for production accuracy.
- Inline AVPlayer-driven looping video previews in `SwipeMediaCard` (currently uses the static thumbnail with a play badge).
- Seasonal events framework, achievement glow-reveal animation, and full-fat parallax via gyroscope.
