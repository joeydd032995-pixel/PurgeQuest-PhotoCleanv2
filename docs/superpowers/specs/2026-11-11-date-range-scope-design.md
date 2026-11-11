# Date range for dives: design

**Date:** 2026-11-11 · **Status:** built, not yet run under Xcode or on a device (see Verification)

The design was agreed in conversation in three parts (the rule and the fetch; the Dashboard row, the
sheet and the empty states; edge cases and tests). The separate "review the written spec" step was
skipped at the owner's request, so this file records what was built.

## Goal

Let the player narrow what dives show by the date each photo or video was taken: **Only** a range, or
**Exclude** a range. Either one protects or targets a stretch of the library across several dives, so it
is a standing setting, not a per-dive choice.

## What the code did before (verified against the tree)

- A dive fetches the **150 oldest unseen** items from PhotoKit (`PhotoLibraryService.fetchAssets`, sorted
  by `creationDate` ascending, `fetchLimit = 150 + seenCount`), deals them in rooms, and the Focused Dive
  only *reorders* those 150 (`RoomTargeting`). So a date filter has to act at the fetch: filtering the
  finished queue would find nothing for "Only 2023" and merely thin the dive for "Exclude".
- Three entry points on the Dashboard: Enter the Dungeon (`bootstrap`), Focused Dive (`bootstrap` with a
  bucket) and Hunt Chosen (`bootstrapPicked`, exact picks). `includeVideos` and `videoOnlyMode` in
  `AppState` shape the same fetch.
- The Dashboard's "Identified opportunity" figure and the "Next dive" theme strip each read the library
  on their own (`fetchOpportunityBytes`, `fetchLibraryComposition`).

## Decisions (change them before merging if you disagree)

1. **A standing setting on the Dashboard**, not per dive and not in Settings. It stays on until cleared,
   survives a relaunch, and the Dates row names it, so it cannot narrow the dungeon unseen. Alternatives
   offered: a row in Settings > Cleanup (easy to forget it is on); a per-dive prompt (a year of photos
   takes many dives, and there is no lasting "protect these dates").
2. **One mode at a time:** All dates, Only, or Exclude, over **one** range. Several ranges at once is left out.
3. **Filter inside PhotoKit**, with a re-check of every fetched asset against the same rule. Rejected:
   filtering in memory after a wide fetch (walks most of the library for a recent range) and filtering
   the 150 already fetched (wrong, see above).
4. **Whole calendar days, both ends included, either end optional.** Stored as `CalendarDay`
   (year-month-day, always Gregorian), not as instants, so a range keeps its meaning after a flight or a
   change of the device's calendar. Boundaries are worked out in the current time zone each time.
5. **A photo with no capture date sits out whenever a range is on** (both modes). It cannot be placed
   against a range, and a database leaves a missing value out of every comparison, so the rule and the
   predicate agree.
6. **Hunt Chosen ignores the range.** Hand-picked items are dealt exactly as chosen.
7. **The Dashboard previews follow the range** (opportunity figure, next-dive theme). The
   "N photos · M videos" header stays whole-library.
8. **"Reset all PurgeQuest data" clears it**, since it also wipes the spared and purged memory the range
   narrows. Leaving a dive does not (unlike `diveFocus`).
9. **Saved as JSON text** under `pq.dateScope` in `UserDefaults` (already declared in the privacy
   manifest). Text rather than `Data` so a UI test can preset it with `-pq.dateScope '<json>'`.

## Behaviour

| Mode | Admits a dated item when | Predicate (on `creationDate`) |
|---|---|---|
| All dates | always, even undated | none |
| Only, both ends | `from 00:00 <= t < day-after-to 00:00` | `>= first AND < afterLast` |
| Only, open end | the same with that bound dropped | `>= first` or `< afterLast` |
| Exclude, both ends | not the above | `< first OR >= afterLast` |
| Exclude, open end | the complement of the open range | `< first` or `>= afterLast` |

A scope is built in one canonical form: reversed ends are swapped, a mode with no day at all (or All
dates given days) is All dates. Unreadable saved data is All dates.

## Where it lives

| File | Change |
|---|---|
| `ios/PurgeQuest/Services/DateScope.swift` | new, pure Foundation: `CalendarDay`, `DateScope` (rule, predicate parts, summary and explanation text), `DateQuickPick`, `DateScopeStore` |
| `ios/PurgeQuest/Services/PhotoLibraryService.swift` | `fetchAssets`, `fetchOpportunityBytes`, `fetchLibraryComposition` take a scope; predicate plus re-check |
| `ios/PurgeQuest/ViewModels/AppState.swift` | `dateScope` (read-only outside), `setDateScope`, `init(defaults:)` |
| `ios/PurgeQuest/ViewModels/CombatViewModel.swift`, `Views/Combat/CombatView.swift` | `bootstrap(... scope:)`; the empty state names the range and offers "Show all dates" |
| `ios/PurgeQuest/Views/Dashboard/DashboardView.swift` | the Dates row; previews recomputed when the range changes |
| `ios/PurgeQuest/Views/Dashboard/DatesSheet.swift` | new: the draft editor (mode, start/end switches and pickers, quick picks, Apply) |
| `GameDataService.swift`, `SettingsView.swift` | reset clears the saved range and AppState's copy |
| `tools/swift_harness/run.sh` | the new source and test file join the Linux harness |

`PhotoKit` never sees `DateScope` internals: it gets a format and dates from `predicateParts`, and each
fetched asset goes through `DateScope.Resolved.admits`, which is the line that makes an excluded range a
promise whatever the predicate does. `Resolved` exists so a loop over thousands of assets does not redo
calendar arithmetic per asset.

## The Dates row and sheet

Follows `docs/design/DESIGN_SYSTEM.md`: a quiet panel button under Focused Dive / Hunt Chosen (Enter the
Dungeon stays the one gold action), `DungeonPanelBackground(accent:)` for the active state (border only),
no new hues, a different calendar glyph per mode so mode never depends on colour. The sheet edits a draft
(the Forge's draft/save/cancel pattern): All dates / Only / Exclude, start and end switches with compact
pickers (never later than today; the other end follows if they would cross), four quick picks that fill
in today's concrete dates, a plain sentence saying what a dive will do, one gold Apply, and "Show all
dates" while a range is on.

## Edge cases

Time zones and clock changes (days, not instants; noon-then-round-down so a skipped midnight still
starts the day); the device on a non-Gregorian calendar; reversed or empty ranges; unreadable saved
data; photos dated in the future (an open end covers them); photos taken after an open-ended range was
set (covered); a dive in progress keeps its batch; the seen-memory is never written by a range.

## Verification

Run while building this (Swift 6.2.1 on Linux, the toolchain CI uses):

- `tools/swift_harness/run.sh`: 305 tests in 21 suites pass (the 275 that existed plus 30 in
  `DateScopeTests`). The new tests were written first and failed to compile before the implementation
  existed; four deliberate breakages of the rule (inclusive upper bound, device calendar instead of
  Gregorian, undated admitted, a wrong predicate boundary) were each caught.
- `tools/ci/repo_guard.py` passes; every touched Swift file parses with `swiftc -parse`.

**Not run, because it needs Xcode or a device** (CI runs the first two on the pull request):

- Compiling the SwiftUI, Photos and SwiftData code (`DatesSheet`, `DashboardView`, `AppState`,
  `PhotoLibraryService`, `CombatView`, `CombatViewModel`).
- `DateScopeIntegrationTests` (predicate agrees with the rule via `NSPredicate`, which swift-corelibs
  lacks; `AppState` persistence; reset) and the `testDatesRange` UI tour capture.
- PhotoKit accepting the predicate on a real library. It uses plain `creationDate` comparisons with
  AND/OR. Device-pass checks 6 to 9 in `ios/README-SETUP.md` cover this.

## Left out on purpose (each can be added without rework)

A banner for the active range inside a dive; a live "N items in range" count in the sheet; several ranges
at once; greying out the Old focus when the range cannot hold old photos; filtering by date added.
