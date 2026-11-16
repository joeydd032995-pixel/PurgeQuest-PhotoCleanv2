# Phase 1.2 expanded: Undo, equal-weight decisions, the coach mark, and the combat card (plan only)

**Status:** built, 16 November 2026. Tasks 1 to 5 are in PR #42 (merged); tasks 6 to 8 are in PR #43. The step-by-step code was written just before each task ran, as in 1.1. Measured results are in the section at the end. It expands sub-plan 1.2 of `2026-11-14-phase-1-clarity.md` (slice A, chosen by the owner) and folds in work package E3 of `2026-11-16-visual-elevation.md` (decision E-1, owner: yes), so the card was rebuilt once.

**Goal:** a decision can be reversed for five seconds; Keep and Delete are equal in weight and size; the first card teaches the gesture; and the card announces the monster in a frame with a nameplate instead of a photo with a small chip. It also fixes the Light duplicate-card text (1.20:1) that the E0 tour exposed.

**Honest size.** The master plan sizes 1.2 at M (1 to 2 days). With the card redesign, the duplicate card and the tour work it is closer to **8 to 10 engineer-days** at the spec's scale (task sizes below). That is the owner's call under E-1; this plan makes the cost visible so it can be traded against the rest of slice A.

## Source of truth

- Spec: `docs/design/UI_ASSESSMENT.md` 10.2 ("Undo: glass pill above the buttons for 5 s after any decision; rewinds one step", "Coach mark: first card only: two arrows with labels, dismissed by the first swipe or tap", "Keep and Delete equal width, 56 pt", "no reward preview anywhere on the card").
- Look: the approved mockups (`docs/design/mockups/elevation-combat-*.jpg`) and E3 in the elevation plan. Real before: `tour-*-11-combat.png` and the E0 shots (`before-duplicate-card-and-room-summary.jpg`).
- Tokens: today's semantic colour names, so the later palette swap (E1) is a token change, not a rework.

## Global constraints

- Owner decisions in force: keeping is free (D1); combo is +0.1 per deletion to ×2.0 and a keep takes 12% (never below ×1.0); Perfect Room stays as is; nothing merges without an explicit ask; "Delete" is the action word.
- **Undo is a snapshot, not an inverse.** Each decision records what it overwrote and undo puts it back (the master plan's design rule). It stays correct whatever the combo formula becomes.
- Minimum tap target 44 pt; no fixed font under 12 pt in new code; Reduce Motion respected; Light and Dark both measured on the tour.
- The pure parts go in the Linux harness (`tools/swift_harness/run.sh`, both lists); the SwiftData parts are CI-only tests. No change to the economy, rewards or quest accounting.

## Decisions this plan makes (the owner can veto any)

1. **The coach mark wins the very first card; the Room note moves to the second card.** (Resolves the hazard recorded in the Phase 1 plan: both on one card crowd the 44 pt "Got it", the arrows and the buttons, and the card jumps about 56 pt when the note leaves.) The coach mark is the stronger teacher.
2. **Undo is not offered once the Room Summary is showing.** After the room's last card the summary already lets the player flip any item, which is the same rescue with more room. So undo covers cards within a room only, never across rooms.
3. **A duplicate group commit is one undoable step.** Undo restores every copy's decision and removes every `SparedMediaRecord` that commit inserted.
4. **The duplicate card loses its per-copy reward line too** ("Reward for deleting: +X XP"). It sits next to the confirm control, which the principle "a reward never shares a surface with a safeguard" forbids, and the copy is chosen by the "Suggested keep" star, size and date, not by payout. Rewards are shown once, in the Room Summary.
4b. **Undo after a keep puts the photo back in the queue and removes its saved "kept" record**, so it will appear again this dive and on later dives, as if never decided. (That is what "rewinds one step" has to mean.)
5. **The Undo window is a named constant** (`DiveRules.undoWindowSeconds = 5`), tested with an injected clock.

## File structure

| File | Change |
|---|---|
| Create `ios/PurgeQuest/Models/DecisionHistory.swift` (pure) | The history of one room's decisions and the five-second rule |
| Create `ios/PurgeQuestTests/DecisionHistoryTests.swift` | Harness tests; add to both lists in `run.sh` |
| Modify `ios/PurgeQuest/Models/DiveRules.swift` | `undoWindowSeconds` |
| Modify `ios/PurgeQuest/ViewModels/CombatViewModel.swift` | Snapshot in `decideDelete`, `decideSpare`, `commitGroupDecisions`; `undoLastDecision`; `canUndo` |
| Create `ios/PurgeQuestTests/UndoDecisionTests.swift` (CI only) | Keep then undo leaves no `SparedMediaRecord`; delete then undo restores combo, multiplier and `hero.highestCombo` |
| Create `ios/PurgeQuest/Views/Components/UndoPill.swift` | The glass pill with its countdown |
| Create `ios/PurgeQuest/Views/Components/ExhibitFrame.swift`, `Nameplate.swift` | The framed photo and the monster plate (E2 components, built here first) |
| Modify `ios/PurgeQuest/Views/Combat/SwipeMediaCard.swift` | Frame and nameplate; remove the dark strip and the reward preview; remove `rewardXP`, `rewardGems` |
| Modify `ios/PurgeQuest/Views/Combat/CombatView.swift`, `CombatHUD` | HUD restyle; equal-width 56 pt buttons; Undo pill; the coach mark; the Room note moved |
| Modify `ios/PurgeQuest/Views/Combat/DuplicateGroupCard.swift` | Same frame, equal per-copy controls, no reward line, the Light text-contrast fix |
| Create `ios/PurgeQuest/Views/Components/CoachMark.swift`, `Models/CoachMarkStore` (pure) | The first-card teaching arrows and their saved flag |
| Modify `ios/PurgeQuest/Services/GameDataService.swift` | "Reset all PurgeQuest data" also clears the coach flag (as it does the glossary) |
| Modify `ios/PurgeQuestUITests/AppearanceTourUITests.swift` | Shots: the new card, the Undo pill, the coach mark |
| Modify `README.md`, the plans | Test counts and wording |

## Tasks

Each task is test-first and runs as one subagent with a review, as in 1.1. Order matters: the tasks share `CombatView` and `SwipeMediaCard`, so they run in sequence.

### Task 1: `DecisionHistory` and the Undo window (pure) (S)
**Built (16 November 2026):** `Models/DecisionHistory.swift` (`DecisionSnapshot`, `DecisionHistory`, `Entry`, `Kind`), `DiveRules.undoWindowSeconds = 5`, and 12 harness tests in `DecisionHistoryTests`; harness 399 tests in 29 suites. Not yet used by the view-model (Task 2).
**Produces:** `struct DecisionHistory { mutating func record(_ entry: Entry); mutating func undoLast(now: Date) -> Entry?; func canUndo(now: Date) -> Bool; mutating func clear() }`. `Entry` holds the item ids affected (one, or a group's), whether it was a delete, keep or group commit, the **previous** `combo`, `peakCombo`, `ComboMultiplier`, `perfectRoom`, `hero.highestCombo`, the persisted records it inserted, and `recordedAt`.
**Tests (harness):**
- `undoLast` returns the most recent entry within `undoWindowSeconds` and nothing after it.
- One step only: after an undo, a second undo returns nothing until a new decision is recorded.
- A new decision replaces what could be undone (undo never reaches two steps back).
- `clear()` (a new room) empties it.
- The boundary: exactly at the window is still undoable, one tick after is not.

### Task 2: View-model integration (M)
**Built (16 November 2026, awaiting the CI unit-tests job):** `CombatViewModel` snapshots in `decideDelete` (including the shade path), `decideSpare` and `commitGroupDecisions`; `canUndo(now:)` and `undoLastDecision(hero:context:now:)`; history is cleared when a room starts or the run is defeated. A keep that would cost HP (the old rule, off under D1) clears the history instead of recording, because the snapshot does not cover HP. `UndoDecisionTests`: 8 CI-only tests (keep, perfect room, streak and multiplier, delete, one step only, the window, the Room Summary, a group commit). No shade test: `rewardedIDs` is private and only filled by the async bootstrap.
`decideDelete`, `decideSpare` and `commitGroupDecisions` record a snapshot before they change anything, including the shade early-return path (a shade changes nothing but still advances, so it is undoable too). `undoLastDecision` restores `combo`, `peakCombo`, `comboMultiplier`, `perfectRoom`, `hero.highestCombo` (only if this decision raised it), removes the `PendingDecision`(s), deletes the `SparedMediaRecord`(s) the step inserted and saves, steps `currentRoomIndex` back, and pushes the Live Activity update. It refuses (and the pill never shows) once the phase is not `.fighting`.
**CI-only tests (`UndoDecisionTests`):** keep then undo leaves no `SparedMediaRecord` and the item is back on top; delete then undo restores combo, multiplier, peak and `hero.highestCombo`; a keep's lost `perfectRoom` is restored; a shade undo changes nothing else; a group commit undoes as one step; undo after the last card is refused.

### Task 3: The Undo pill (S to M)
**Built (16 November 2026, Task 2 confirmed in CI first: all 8 undo tests and the 12 `DecisionHistory` tests passed):** `Views/Components/UndoPill.swift` (glass capsule, 44 pt minimum height, a thin time-left line that is not drawn when Reduce Motion is on); `CombatView` shows it as an **overlay** just above the Delete and Keep row (so it never moves the card), driven by `.task(id:)` on the last decision's time, cleared after `undoWindowSeconds`; VoiceOver gets a label, a hint and an announcement through `Wording.undo`, `undoHint` and `undoAvailable` (3 new harness tests; harness 402 in 29). **Not yet seen on screen:** the tour shot and the measurements (pill clear of the buttons, contrast) are Task 7; for a duplicate-group commit the pill overlays the next card's lower edge, since a group has no Delete and Keep row.
A glass pill above the buttons for five seconds after any decision ("Undo delete" or "Undo keep"), fading out; one tap rewinds one step. Accessibility: announced when it appears and when it is used; reachable as a VoiceOver action; Reduce Motion replaces the fade with an instant hide. The timer pauses while the app is backgrounded and never outlives the card.
**Acceptance:** tapping within five seconds returns the card with everything as before; after five seconds, or after a second decision, there is nothing to undo.

### Task 4: The card (L)
`ExhibitFrame` (bronze frame, inner mat, the photo; a glass chip with size and date); `Nameplate` (monster name in Cinzel, rarity and family line, one plain "why" line from the classification); the HUD restyled (one slim gold progress line, "Room N of M", "N left", combo as the display numeral). Remove the dark text strip and the reward preview from `SwipeMediaCard` (and its inputs). Equal-width Delete and Keep, 56 pt, as VoiceOver actions too. Swipe, haptics and the swipe overlays are unchanged.
**Acceptance:** keep or delete behaves exactly as before; every control is at least 44 pt; Delete and Keep are the same size and fully on screen at the largest Dynamic Type that fits; text is at least 4.5:1 in Light and Dark; the nameplate never truncates a monster name (the longest is checked).

### Task 5: The duplicate card (M)
The same frame; the per-copy controls equal in weight; the reward line removed (decision 4); the explanatory line fixed in Light (it is near-white on parchment, 1.20:1 on the E0 shot; it must be at least 4.5:1). Confirm keeps its meaning and its exact wording ("Confirm — keep all copies" and "Confirm — delete N copies").
**Acceptance:** the E0 shot `light-13-duplicate-card` measures at least 4.5:1 for every line of text.

### Task 6: The coach mark and the Room note (S)
First card only: two arrows with labels ("Swipe left to delete", "Swipe right to keep") that disappear on the first swipe or tap. Its flag is saved (`CoachMarkStore`, pure, UserDefaults-backed like `GlossaryStore`) and cleared by "Reset all PurgeQuest data" and on every tour launch. The Room note ("Room: up to 20 items.") moves to the second card (decision 1). Both are tested for "shown once, never again" in the harness.
**Acceptance:** a first-time player sees the arrows and no Room note on card one; the Room note shows on card two; neither shows again after the first dive.

### Task 7: The tour and the measured result (S)
Extend the E0 room-summary test so the tour also shoots the new card, the Undo pill (decide one card, shoot before the five seconds pass) and the coach mark. Measure in Light and Dark: contrast of every new text, control sizes, the pill clear of the buttons, the card jump (there should be none). Update the PR with the measured result and the before and after.

### Task 8: Docs and counts (S)
README test counts, the plan and the assessment's 10.2 text updated to what was built.

**Sizes (spec scale, estimates):** T1 S, T2 M, T3 S to M, T4 L, T5 M, T6 S, T7 S, T8 S: about 8 to 10 days.

## Acceptance for the whole sub-plan

Keep or delete, tap Undo within five seconds, and the card returns with the combo, multiplier, perfect-room state and saved records exactly as before; after five seconds or one step back there is nothing to undo; the coach mark appears on the very first card only and never again; Delete and Keep are equal; no reward appears anywhere on the card; every new text passes 4.5:1 in Light and Dark; the tour shows all of it.

## Risks

| Risk | Mitigation |
|---|---|
| Undo misses a mutation and corrupts the combo or the saved kept list | Snapshot design, CI tests for every path including shades, groups and the perfect room |
| The frame and nameplate crowd the screen on a small phone | Measure on the tour at the smallest size; the buttons must stay fully on screen |
| A long monster name truncates in the nameplate | Test the longest name; allow two lines or scale |
| The card rebuild regresses swipe handling or accessibility | The swipe code is untouched; add VoiceOver action tests where possible and a device pass |
| 1.2 balloons slice A | Sizes are stated up front; the owner can split Task 4 and 5 (visuals) into a follow-up, keeping Tasks 1 to 3 and 6 as the 1.0 floor |

## Self-review

- Every spec line from 10.2 is covered: Undo (T1 to T3), the coach mark (T6), equal decisions (T4), no reward on the card (T4, T5).
- The Phase 1 hazard (coach mark vs Room note) is resolved by decision 1; the duplicate reward line by decision 4; the Light contrast bug by T5.
- E3 of the elevation plan is T4 and T5; the components `ExhibitFrame` and `Nameplate` are built here and reused later, not rebuilt in E2.
- Nothing here changes rewards, the combo rule or quest accounting.

## Execution handoff

Plan only until the owner says go. Recommended: subagent per task in the order above, with a review after each (as in 1.1), then a whole-branch review, then the tour. Tasks 1 to 3 and 6 can ship as the 1.0 floor if the visual tasks (4 and 5) are split out.

## Built and measured (16 November 2026)

What the tour measured on the simulator (402 × 874 pt screen, iPhone, Dark and Light), and what it found.

| Check | Result |
|---|---|
| Delete and Keep size | 177 × 56 pt each, equal, fully on screen |
| Undo pill | 149 × 44 pt at y 704; overlaps neither Delete nor Keep on a single card |
| Undo pill on a duplicate group | The first real shot showed it covering "Delete this copy" and "Keep this copy"; it now sits at the bottom edge, under the card, and covers nothing |
| Nameplate text, Light | name 16.5:1, rarity line 6.9:1, reason line 16.5:1 |
| Nameplate text, Dark | name 12.7:1, rarity line 7.4:1, reason line 12.7:1 |
| Coach mark chips | 16.1:1 (Dark), 15.9:1 (Light) |
| Undo label | 9.8:1 (Dark), 15.2:1 (Light) |
| Delete and Keep labels, first build | Dark **4.24:1** (Delete) and **2.15:1** (Keep): both under 4.5:1. Fixed by filling both with the deep shade and white text: 7.2:1 or better in Dark, 9.4:1 in Light (computed from the palette; confirmed by the next tour) |
| Duplicate card reason line, Light | was 1.20:1 (E0); now the theme text color, 16.5:1 class (same `Nameplate`) |

Re-measured on the fix build (`82dc99f`, Dark): Delete label 7.23:1, Keep label 8.57:1 (the first build: 4.24:1 and 2.15:1), coach chips 15.9:1 and 15.2:1, nameplate name and reason line 12.7:1, rarity line 7.4:1, Undo label 10.9:1. The Light tour's first card was a duplicate group in that run, so it has no coach-mark shot; Light was measured on the first build.

Found and fixed along the way: the Undo pill covering the duplicate card's per-copy buttons; "1 companion copy await judgment together" (now "awaits"); the Dark Delete and Keep contrast above; the coach chips overlapping the photo frame's edge; the Elite note showing over the arrows on an Elite first card (every note now waits for the arrows).

Still to check on a device (not simulator): VoiceOver reading of the nameplate and the group card, the pill's announcement, Reduce Motion with the pill's time-left line, and the largest Dynamic Type sizes (the buttons are built to fit, `minimumScaleFactor` 0.8, but only a device pass confirms it).

One thing to know: on a single card the pill briefly covers the lower lines of the nameplate (the reason line) for up to five seconds. It never covers a button. Moving it would mean either covering the photo's chip and badges or taking layout space, which the owner can decide.
