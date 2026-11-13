# PurgeQuest — building and running

The product, its architecture and its safety model are described in the [root README](../README.md).
This file is only what you need to get the app onto a device. Submission material is in
[`docs/appstore/`](../docs/appstore/).

## Requirements

- Xcode 26 or later. The sources use Swift 6.2's `@concurrent`, and the project sets approachable
  concurrency and a default main-actor isolation; older Xcode versions will not build it.
- iOS 18.0 deployment target, iPhone only, portrait.
- A real iPhone for anything involving the Photo Library, haptics or widgets. The Simulator's
  library is small and has no screen recordings, time-lapses or Live Photos.

## Open and run

1. Open `ios/PurgeQuest.xcodeproj`.
2. In *Signing & Capabilities*, set your team on **PurgeQuest** and **PurgeQuestWidget**.
   `DEVELOPMENT_TEAM` is blank in the repository on purpose.
3. Both targets use the App Group `group.com.purgequest.app` (widget data). Provision it under your
   team, or change it in both `.entitlements` files and in `appGroupID` in
   `PurgeQuest/Services/WidgetSnapshotService.swift` and `PurgeQuestWidget/SharedSnapshot.swift`.
   `tools/ci/repo_guard.py` fails if the four disagree.
4. Build and run.

The project has no package dependencies and uses file-system-synchronized groups: a Swift file
added under `PurgeQuest/`, `PurgeQuestWidget/` or the test folders joins its target without editing
the project file.

## In-app purchases without App Store Connect

The shared scheme does not select a StoreKit configuration. To buy the gem packs and cosmetic
bundles locally: *Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration*, choose
`PurgeQuest/Configuration.storekit`. Its six product IDs are the ones `StoreKitService.ProductID`
lists; `repo_guard.py` keeps the two in step. Leave it unselected to test against the sandbox.

## Permissions

Set as `INFOPLIST_KEY_*` build settings (there is no hand-written Info.plist for the app):

- `NSPhotoLibraryUsageDescription`: read and delete access, and says deleted items go to Recently
  Deleted for 30 days.

The app never adds anything to the library, so it has no `NSPhotoLibraryAddUsageDescription`. If App
Store Connect ever reports a missing purpose string for it (ITMS-90683), add the key back with an
accurate sentence.

The app follows the system appearance unless the player picks Light or Dark in Settings; nothing
pins it.

## Checks

```sh
python3 -I tools/ci/repo_guard.py            # offline, no dependencies, recoverable deletion, ship-path invariants
tools/ci/xcode-test.sh                       # the same unit tests CI runs (add --ui for the UI tests)
SWIFT_BIN=/path/to/swift tools/swift_harness/run.sh   # the pure-logic suites on Linux or macOS, no simulator
```

## Device test pass

Use a library with a mix of photos and videos, and include:

- photos more than three years old, some of them blurry or very dark (they should appear as Blur
  Beasts and Dark Wraiths flagged for careful review, not only as Ancient Archives);
- a screen recording, a time-lapse, a slow-motion clip and a panorama;
- a video over two minutes, one over 500 MB if you have it, and one in 4K;
- a burst and a few edited copies (Duplicate Dragons).

Then:

1. Grant **Limited** photo access once and **Full** access once.
2. Swipe through a room, flip one item back to spare on the Room Summary, confirm, accept the
   system's delete prompt, and find the items in Photos > Recently Deleted.
3. Decline the system's delete prompt once: nothing should be deleted and no reward paid.
4. Add the Daily Quest and Streak widgets and a Lock Screen widget; finish a room and check they update.
5. Buy a gem pack and a cosmetic with the local StoreKit configuration, delete the app, reinstall,
   and tap Restore in the Armory: the cosmetic returns, the gems do not double.
6. **Dates, Only.** On the Library screen tap **Dates**, choose **Only**, pick a year you know has
   photos and apply. Enter the Dungeon, then a Focused Dive: every card should be from that year,
   oldest first. The Identified opportunity figure and the Next dive strip should change with it.
   (This is the one check that exercises PhotoKit's date predicate on a real library; CI cannot.)
7. **Dates, Exclude.** Choose **Exclude** over a range you know has photos and dive several times,
   including Focused Dive > Blur, Screenshots and Old: nothing from that range may ever appear.
   **Hunt Chosen** still deals exactly what you pick, from any date.
8. **Open ends, saving, clearing.** Exclude from a date onward with the end switched off: photos taken
   after you set it stay covered. Force-quit and relaunch with a range on: it is still on, and the row
   shows it. Clear it with the x; then set one again and run **Reset all PurgeQuest data**: it is gone.
9. **The Dates sheet** at the largest Dynamic Type size, in Light and Dark: nothing clipped, Apply
   reachable. Pick a start date after the end date: the end follows it.
10. **Credits.** Settings, About, Credits: the list shows the CraftPix, Mica, LumioLab and Cinzel
    credits, the Cinzel license row expands to the full license text and scrolls, and Close dismisses it.
