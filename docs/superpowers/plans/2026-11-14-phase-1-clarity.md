# Phase 1: Clarity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the first session make sense to someone who has never seen the app: a first card within three taps, decisions that can be undone, one home screen with one next action, and a structure with no empty walls and no "More" list.

**Architecture:** Pure rules first, thin SwiftUI on top. Every rule that can be written in Foundation (undo history, the glossary, what a dive choice means, the next-dive description) lives in a Foundation-only file with a test suite that runs in the Linux harness. The SwiftUI that consumes it stays thin and is checked by CI (build-and-analyze is the compile check, the screenshot tour is the visual check, measured, not eyeballed). One PR per sub-plan, each shippable on its own.

**Tech Stack:** SwiftUI, SwiftData, PhotoKit, StoreKit 2, WidgetKit; Swift Testing in the Linux harness (`tools/swift_harness/run.sh`, Swift 6.2); GitHub Actions (`ios.yml`, `objective-c-xcode.yml`, `modular-assets.yml`, `repo-guard.yml`, `ui-snapshots.yml`).

**Source of truth:** `docs/design/UI_ASSESSMENT.md` (section 11 "Phase 1: clarity", the findings in section 5.1, the principles in section 6, the structural recommendations in section 8, the hand-off specs in section 10, the microcopy in Appendix B).

## Scope note (read this first)

This document is the **decomposition** the writing-plans scope check asks for. Phase 1 spans seven independent subsystems and about two or more weeks of work; one document with exact code for all of it would be wrong the moment the first sub-plan merges, because each sub-plan builds on the code the one before it leaves behind. So this plan fixes **what the sub-plans are, their order, their files, their interfaces, their acceptance criteria and what the owner must decide**. Each sub-plan is then written out in full bite-sized TDD form (failing test, run it, minimal code, run it, commit; complete code in every step) **just before it is executed**, against the code as it stands then. Nothing in section "Sub-plans" below is an implementation step.

Interfaces named under "Produces" are **proposals** to be finalized when the sub-plan is expanded; the file paths, existing symbols and acceptance criteria are checked against the repository and the assessment.

## Global Constraints

Every sub-plan's requirements implicitly include this section.

**Decisions already made (assessment section 1, recorded 14 November 2026)**

- D1: "Keeping is free: no HP loss. Combo rewards are lesser." In code: `DiveRules.keepingCostsHP = false`; the combo multiplier is x1 for the first four deletions and x2 from the fifth, never more (`DiveRules.deletionsPerComboStep` 5, `DiveRules.maxComboMultiplier` 2). **Approved change, 14 November 2026, built in its own PR and not part of Phase 1:** the multiplier rises 0.1 per deletion from x1.0, is capped at x2.0 (reached at the tenth deletion), and keeping takes 12% of it, rounded to the nearest tenth and never below x1.0. Until that PR merges, `main` still has the rule above. The old damage, defeat and Rally code stays parked behind the flag, not deleted.
- D3 (Phase 1): "Five tabs with Codex: Dungeon, Hero, Codex (Bestiary and Trophies), Armory, Settings. No More list."
- D2, D4, D5, D6 are **not Phase 1**: the Classic palette and the Palette switch stay (so Settings keeps Mode **and** Palette until Phase 2), gems stay green, no new hue, the app icon is untouched.
- Perfect Room keeps its logic (a room with no keeps) for 1.0, decided by the owner.

**Principles from assessment section 6 (verbatim)**

- "One job per screen, one next action."
- "Value before identity. The first card within three taps and about 45 seconds. Character creation is a reward after the first room, not a gate. Teach on the real card."
- "Safe by default, and visibly so. Keeping is free. Every destructive step names its count and destination. Decisions can be undone until the room commits. A reward never shares a surface with a safeguard."
- "Disclose progressively. Day-one UI shows only what a first-timer can use. Power tools sit one tap deeper, in one sheet. Progress screens explain themselves when they are empty."
- "Plain words first, lore second; one measurement vocabulary. Every game term carries a plain gloss at first sight. 'Freed' only ever means measured."
- "A polish floor is a feature. No truncation, no clipped lists, no text below 12 pt, 4.5:1 for every text role, a defined scale used 100% of the time and enforced by tests, not memory."

**Repository rules that bite**

- Minimum tap target 44 pt. No `.system(size:)` under 12 pt in new code (the lint arrives in Phase 2; new code obeys it now).
- The Linux harness cannot compile SwiftUI, SwiftData or UIKit. **CI `build-and-analyze` (about 3 minutes) is the compile check.** `swiftc -parse` passing is not evidence a view compiles (a past `LazyVGrid(alignment: .top)` passed it and failed CI).
- New pure Foundation files go in **both** lists in `tools/swift_harness/run.sh` (the source list and the test list). SwiftData- or UIKit-touching tests are CI-only and are not added to it.
- `tools/ci/repo_guard.py` must pass before every push. It mirrors the Classic palette into `ios/PurgeQuestWidget/WidgetPalette.swift`; Phase 1 does not touch palettes.
- Check Light **and** Dark. Measure screenshots (contrast ratios, pixel profiles) instead of judging by eye; the Phase 0 bar scrims passed review by eye and were measurably wrong.
- UI tests depend on these identifiers: the onboarding buttons "Continue" and "Enter the Dungeon", `onboarding.race.<race>`, "Choose Your Race", the tab names "Settings" and "Trophies", and the launch argument `-UITestTour` (`UITestSupport.isTour` forces `photoAuthStatus = .authorized`). **A sub-plan that changes one of these updates every test that uses it in the same task.**
- Never skip, disable or quarantine a test to get green. A CI job gets one re-run at most; "flake" is not a root cause.
- One PR per sub-plan, ready for review. Nothing merges without the owner's explicit ask. Commit messages end with the attribution lines the session gives; no model identifier anywhere else.

---

## Sub-plans

| ID | Sub-plan | Fixes | Effort* | Depends on | Slice |
|---|---|---|---|---|---|
| 1.1 | Glossary and microcopy | S-09, S-16 (verify first), leftover "spared" | M | none | A |
| 1.2 | Undo, equal-weight decisions, first-card coach mark | S-08 | M | none | A |
| 1.5 | Onboarding rebuild: 3 screens, deferred look, coached first room | S-03, S-15 | L | 1.2 (coach mark) | A |
| 1.3 | Codex and the five-tab structure, Settings order, empty states | S-10, S-11, S-12 | L | none | B |
| 1.6 | Hero stage at full size and one equip flow | S-10 (equip split), S-11 | M | 1.3 | B |
| 1.4 | Dungeon home and "Choose what to clean" | S-05, S-09, S-14 | L | 1.6 (stage component) | B |
| 1.7 | Tour and baseline consolidation | roadmap line "add Room Summary, the duplicate card" | S | all | B |

\* Spec scale: S at most half a day, M 1 to 2 days, L 3 to 5 days, one engineer using the CI screenshot loop. Estimates, not measurements. **Summed at the spec's own sizes (S 0.5, M 1.5, L 4 days) this is about 17 to 18 engineer-days, roughly 3.5 weeks, against the roadmap's "about 2 weeks".** Every CI cycle that needs a tour is about 35 minutes; plan on two cycles per sub-plan. Treat the roadmap's two weeks as optimistic.

**Recommended order: slice A, then slice B.** Slice A (1.1, 1.2, 1.5) is the first-session experience: S-03 is an S0 finding, and the roadmap itself says "the first-session experience is what App Store reviews will describe". It needs nothing from the structural work: the coached first room launches from the existing Dungeon button. Slice B (1.3, 1.6, 1.4, 1.7) is structure; 1.6 builds the shared hero-stage component before 1.4's Dungeon home consumes it.

## Slice A compared with all of Phase 1

| | Slice A (1.1, 1.2, 1.5) | Slice B (1.3, 1.6, 1.4, 1.7) | All of Phase 1 |
|---|---|---|---|
| Effort at the spec's sizes (estimates) | about 7 days (M + M + L), roughly 1.5 weeks | about 10 days (L + M + L + S), roughly 2 weeks | about 17 days, roughly 3.5 weeks |
| Findings closed | S-03 (S0, the last open S0), S-08 (S1), the glossary half of S-09, S-15, S-16 if it reproduces | S-05 (S1, the other open S1), S-10, S-11, S-12, S-14, the renames half of S-09 | all of them |
| What a new user sees | three screens; a coached first card in three taps; a five-second undo; Keep and Delete equal; terms explained when first met; the look picker after the first room | five tabs and no More; a Codex; one home screen with one next action; a full-size hero; empty screens that say what to do | both |
| What stays as it is | the nine-block Library home, six tabs with a "More" list, Dates, Focused Dive and Hunt Chosen on the surface, empty Bestiary and Trophies | today's six-page onboarding (nine taps to the first card) and the undo-less card | nothing on the Phase 1 list |
| Assessment section 12 validation | covers task 1 ("first card, under 60 seconds, nobody stuck at permission") and the "What is an Elite?" probe; tasks 2 and 3 and the other three probes already hold after Phase 0 | does not move any of the pass criteria | all of them |
| Main risk | first-run state and the reset test (1.5 is the riskiest sub-plan), contained: it launches from the existing Dungeon button | navigation: tab names, the tour, and an IA merge that could hide the shop | both |

My reading, not a measurement: the SUS target of 80 is a judgment on the whole experience, so slice A alone may not reach it, but slice A is what the five-person test's pass criteria depend on. That is why the plan recommends slice A before anything in slice B.

### 1.1 Glossary and microcopy

**Expanded in full, with validated code:** `docs/superpowers/plans/2026-11-14-phase-1-1-glossary-and-plain-words.md`.

**Goal:** Every game term carries a plain gloss at first sight, and the words in Appendix B are used everywhere.

**Files**
- Create: `ios/PurgeQuest/Models/Glossary.swift` (pure: the four terms and their glosses) and `ios/PurgeQuestTests/GlossaryTests.swift`; add both to `tools/swift_harness/run.sh`.
- Modify: `ios/PurgeQuest/Models/Wording.swift` (new phrases follow its house style: right at 0, 1 and many), `ios/PurgeQuestTests/WordingTests.swift`.
- Modify (strings found by search when expanded): `SettingsView.swift` ("Forget spared monsters"), the Bestiary stats ("Spared"), `GameDataService.swift` (quest and trophy text such as "Defeat 3 Leviathans over 2 minutes"), `CombatView.swift` (the scan wait).

**Interfaces**
- Produces (proposed): `Glossary.Term` (`dive`, `room`, `elite`, `shade`) with `Glossary.gloss(_:) -> String`, exactly the four glosses in Appendix B ("Dive: one session of up to five rooms. Room: 20 items. Elite: a boss-tier monster that pays more. Shade: a photo you deleted before; deleting it again pays nothing."). The first-seen flag lives in the app layer (`UserDefaults`, key `pq.glossary.seen.<term>`), not in the pure file.

**Scope notes**
- Appendix B renames "Focused Dive / Hunt Chosen" to "Choose what to clean / Pick items": that belongs to 1.4 (they become one sheet). "Palette" stays until Phase 2 (D2).
- S-16 ("Scan wait has no progress") is only partly fixed: the wait says how many items it is reading, which is true and cheap. A real progress bar needs callbacks through classification and is not built (expanded plan, decision 4).

**Acceptance:** no "spared" left in user-visible text; every term in the glossary is explained at first encounter and never again; quests read in plain words ("Delete 3 videos longer than 2 minutes"); harness suites cover each phrase at 0, 1 and many.

### 1.2 Undo, equal-weight decisions, first-card coach mark

**Goal:** A decision can be reversed for five seconds, Keep and Delete look equally important, and the first card teaches the gesture.

**Why it is not trivial.** `CombatViewModel.decideDelete` (`CombatViewModel.swift:358`) changes `combo`, `peakCombo` and `hero.highestCombo`, appends a `PendingDecision`, fires haptics and a Live Activity update, then `advance()`s the queue. `decideSpare` (`:427`) sets `combo = 0` and `perfectRoom = false` and **inserts and saves a `SparedMediaRecord`** (so the item is skipped on every future dive). Undo therefore has to restore the combo state, the queue position, the pending decision **and delete that persisted record**. Duplicate-group cards commit through `commitGroupDecisions` and need a defined rule (proposal: a group commit is one undoable step).

**Design rule: snapshot, not inverse.** Each decision records the values it overwrote, and undo puts them back. That keeps undo correct whatever the combo formula becomes; the owner's pending percentage-penalty combo idea (see "Decisions needed") does not touch it.

**Files**
- Create: `ios/PurgeQuest/Models/DecisionHistory.swift` (pure) and `ios/PurgeQuestTests/DecisionHistoryTests.swift`; add both to `tools/swift_harness/run.sh`.
- Modify: `ios/PurgeQuest/ViewModels/CombatViewModel.swift` (`decideDelete`, `decideSpare`, `commitGroupDecisions`, a new `undoLastDecision`), `ios/PurgeQuest/Views/Combat/CombatView.swift` and `SwipeMediaCard.swift` (the two buttons, the Undo pill, the coach mark), `ios/PurgeQuest/Models/DiveRules.swift` (the 5-second window as a named constant).
- Test (CI only, it needs SwiftData): `ios/PurgeQuestTests/UndoDecisionTests.swift`: keep, then undo, leaves no `SparedMediaRecord`; delete, then undo, restores the combo and `hero.highestCombo`.

**Interfaces**
- Produces (proposed): `struct DecisionHistory { mutating func record(_ entry: Entry); mutating func undoLast(now: Date) -> Entry?; func canUndo(now: Date) -> Bool }`, with `Entry` holding the item id, whether it was a delete, the previous `combo`, `peakCombo`, `perfectRoom`, `hero.highestCombo`, the previous `ComboMultiplier` (see "Decisions"), and `recordedAt`. Pure, so the five-second window and the "one step only" rule are harness-tested with an injected `now`.

**Spec (assessment 10.2, verbatim):** "Undo: Glass pill above the buttons for 5 s after any decision; rewinds one step." "Coach mark: First card only: two arrows with labels, dismissed by the first swipe or tap." "Decisions: Keep (`surface`, `patina` shield) and Delete (`ember-fill`, `on-ember`), equal width, 56 pt." Keep and Delete are also VoiceOver actions.

**Also in 1.2 (found reviewing the Phase 0 tour):** the assessment's combat-card spec (10.2) says "no reward preview appears anywhere on the card", but the card's strip still shows "+33 XP · +0 on confirm" under the photo, beside the Keep and Delete buttons, which the principle "A reward never shares a surface with a safeguard" forbids. Remove the XP and gem preview from `SwipeMediaCard`'s `bottomMetaBar` and its `rewardXP` and `rewardGems` inputs. The duplicate card's per-copy preview (`DuplicateGroupCard`'s `previewReward`) needs the owner's call: it is the one place a reward preview helps pick a copy.

**Hazard from 1.1 (the Room note and the coach mark):** 1.1 puts a one-line "Room: 20 items." note (`GlossaryTip`) above the card stack on the very first card, and it leaves as soon as that card is decided. The coach mark lands on the same card. Showing both at once crowds the 44 pt "Got it" target, the two arrows and the Delete and Keep row on a small phone, and when the note leaves, the card jumps up by about 56 pt. Decide in 1.2 which one wins the first card (the coach mark is the stronger teacher; the Room note can wait for the second card, or fold into the coach mark's text), and measure the card and both buttons on the tour in Light and Dark with the larger text sizes.

**Acceptance:** keep or delete, tap Undo within five seconds, and the card returns with combo, perfect-room state and persistence exactly as before; after five seconds, or one step back, there is nothing to undo; the coach mark appears on the very first card only and never again.

### 1.5 Onboarding rebuild: 3 screens, deferred look, coached first room

**Goal:** Nine taps and seven screens become three screens and a coached first room; race, class and look arrive as a reward.

**Today** (`ios/PurgeQuest/Views/Onboarding/OnboardingView.swift`, 590 lines): six swipeable pages (intro, permission, race, class and name, look, swipe tutorial) with state for race, class, name and `draftLook`, and a looping `DemoSwipeCard`. The choices are written to `UserDefaults` and applied to the hero by `GameDataService.applyOnboardingChoices` (`GameDataService.swift:65`); `AppState.hasOnboarded` is `pq.hasOnboarded`.

**Files**
- Modify: `OnboardingView.swift` (reduce to Promise and Permission), `AppState.swift` (the phase after Permission is the coached first room), `CombatView.swift` (the coach mark from 1.2 runs on the real first card), `GameDataService.swift` (`provision` already calls `loadOrCreateHero` and then applies any saved choices; the expanded plan confirms which defaults a hero gets when nothing was chosen, Valkyrie and Holy Paladin being the onboarding state's defaults, that it runs before the first dive, and how the later "Level up your look" writes to the hero), `RoomSummaryView.swift` (after the first Room Summary, offer "Level up your look").
- Create: `ios/PurgeQuest/Views/Onboarding/LevelUpLookView.swift` reusing the existing race, class, name and look controls (`LookControls.swift`, `HeroForgeView.swift` swatches).
- Modify tests: `OnboardingResetUITests.swift` (it walks "Choose Your Race" and `onboarding.race.necromancer` today), `AppearanceTourUITests.swift` (the onboarding shots).

**Spec (assessment 8.2, verbatim):** "Three screens (Promise, Permission, First room), then straight into a coached first room. Race, class and look arrive as 'Level up your look' after the first Room Summary. The permission screen can never trap the user. 9 taps become 3." Validation pass (section 12): "Install, open, get to the first card. Pass: under 60 seconds, no help, nobody stuck at permission."

**Decided (owner, 14 November 2026): the first room when photo access is denied.** Three bundled sample cards teach the gesture without touching the library, then the permission screen returns. This needs three original sample images in the app bundle; they are made for the app, not stock photos, with their provenance recorded in `docs/CREDITS.md`. A user who grants access goes straight to their own first card.

**Risk:** this is the highest-risk sub-plan: it changes first-run state, the reset flow and the tour's navigation in one move. The expanded plan splits it into two PRs if needed: 1.5a cuts the screens and defers the look; 1.5b adds the coached first room and "Level up your look".

**Acceptance:** from install to the first card in three taps; a user who denies access is never stuck; the hero exists with defaults from the first dive; the look picker appears after the first Room Summary and writes straight to the hero; the reset flow test passes against the new screens.

### 1.3 Codex and the five-tab structure

**Goal:** Dungeon, Hero, Codex, Armory, Settings. No "More" list. No empty wall without an invitation.

**Today:** `MainTab` is `dashboard, hero, bestiary, achievements, shop, settings` (`ios/PurgeQuest/ViewModels/AppState.swift:16`); `ContentView.swift:65-102` builds six `NavigationStack`s inside a `TabView`, each root wrapped in `.barScrims()`; iOS folds two under "More". `HeroTabView.swift:109` and `:160` jump to `.shop`.

**Files**
- Modify: `AppState.swift` (`MainTab`: replace `bestiary` and `achievements` with `codex`), `ContentView.swift`, `HeroTabView.swift` (route stays `.shop`), `SettingsView.swift` (see below), `ShopView.swift` (Restore leaves the header).
- Create: `ios/PurgeQuest/Views/Codex/CodexView.swift` with a segmented control over the existing `BestiaryView` and `AchievementsView` content, plus a first-run banner.
- Modify tests: `AppearanceTourUITests.swift` (the tour opens "Trophies" by tab name at line 348; its `open(tab:)` already opens a tab directly or through More, so Settings keeps working).

**Interfaces**
- Produces (proposed): `MainTab.codex`; `enum CodexSegment { case monsters, trophies }`.

**Spec (assessment 8.1 and 8.2, verbatim):** "Codex: segmented Monsters / Trophies." "A first-run banner ('Clear your first room and the Bestiary starts to fill')." Lifetime stats: "Hero only." Restore: "Settings ▸ Purchases, and the Armory footer." "Settings. Cleanup, Recently Deleted with Open Photos, Appearance (Mode only), Purchases, Privacy and About (policy link, support, credits, version), then Reset. No stats." **Exception:** Appearance keeps Palette until Phase 2 (D2).

**Not in Phase 1:** the Armory's themed segmented filter, state labels (Owned, Equipped, Next goal) and full-opacity names on locked items (S-13's remainder). They are component work for Phase 2.

**Risk (assessment risk table):** an IA merge can hide the shop. Armory stays a tab and the gem chip opens it; compare App Store Connect sales across the release.

**Acceptance:** five tabs and no More; Monsters and Trophies reachable in one tap from Codex; empty Codex segments say what to do; Restore Purchases still reachable (App Review requires it); the tour and `OnboardingResetUITests` pass.

### 1.6 Hero stage at full size and one equip flow

**Goal:** The hero is the screen. Equipping is one flow.

**Files**
- Create: `ios/PurgeQuest/Views/Hero/HeroStageView.swift` (the shared component: figure 160 pt or taller on a pedestal), `GearSlotGrid.swift`, `GearSheet.swift`.
- Modify: `HeroTabView.swift` (183 lines), `ShopView.swift` (equip state), the tour's Hero shot.

**Spec (assessment 8.1, 8.2, verbatim):** "The stage is the screen: figure 160 pt or taller. Slots are a 2×3 grid; an empty slot says what to equip." "Hero and Armory, with slot rows opening a gear sheet: One flow to equip." At accessibility Dynamic Type sizes the stage shrinks to 120 pt (10.1).

**Acceptance:** the figure is 160 pt or taller; an empty slot reads as an instruction, not "Nothing equipped"; equipping happens in one flow; `HeroStageView` is reusable by 1.4.

### 1.4 Dungeon home and "Choose what to clean"

**Goal:** Nine blocks become five; the power tools move into one sheet.

**Today:** `ios/PurgeQuest/Views/Dashboard/DashboardView.swift` (617 lines) stacks `libraryOverview` (`:111`), `heroStrip` (`:264`), `themeStrip` (`:301`), `questsPanel` (`:330`), `enterDungeonButton` (`:355`), `focusedDiveMenu` (`:372`), `datesRow` (`:432`) and `pickedHuntPicker` (`:509`); `DatesSheet.swift` is 234 lines.

**Files**
- Create: `ios/PurgeQuest/Models/CleanChoice.swift` (pure: which kind of dive a choice starts) with `CleanChoiceTests.swift`, added to the harness; `ios/PurgeQuest/Views/Dashboard/ChooseWhatToCleanSheet.swift`, `StorageInfoSheet.swift`.
- Modify: `DashboardView.swift`, `DatesSheet.swift` (becomes a row inside the sheet), `ContentView.swift`.

**Spec (assessment 10.1; quotes are verbatim, with `(…)` where a token note is omitted):** zones Header, Stage, Next dive, Storage strip, Quests. "Choose what to clean: Tap: Opens a sheet (…): Blur, Screenshots, Large video, Old, Duplicates, a date range, Pick items. Choosing one starts a dive for that choice only." "No items to review: the plate reads 'Nothing to review', disabled, with 'Choose what to clean' still available." "Storage strip: Info tap: Sheet explaining the three numbers." "Gem chip: Tap: Opens the Armory." A seasonal event is a dismissible Notice above the next dive. The plate's label is "Enter the Dungeon, mixed dive".

**Acceptance:** nine blocks become five; Dates, Focus, Hunt Chosen and Duplicates are reachable only through the sheet; the headline monster (Duplicates) is finally on the focus list (S-14); the primary action is above the fold on the smallest supported phone.

### 1.7 Tour and baseline consolidation

**Goal:** The screenshot tour covers every Phase 1 surface, and a baseline exists to compare against.

**Files:** `ios/PurgeQuestUITests/AppearanceTourUITests.swift`, `.github/workflows/ui-snapshots.yml` only if a new shot needs a fixture (`tools/ci/make_library_fixtures.py`).

**Scope:** add the Room Summary (the Phase 0 tour has none), the duplicate card, the Undo pill, the coach mark, the three onboarding screens, the Codex segments and the Dungeon sheet. The roadmap's "the More list (if kept)" is dropped: D3 removes it.

**Acceptance:** every new surface has a Light and a Dark shot; each can be measured with the same scripts used for Phase 0 (title contrast of 4.5:1 or better, no hard edges).

---

## How each sub-plan runs

1. Branch from the current `main`.
2. Write the pure Foundation file and its tests first (TDD): failing test, run it in the harness, minimal code, run it. Add both files to `run.sh`.
3. Wire the SwiftUI. Push early and read `build-and-analyze` (about 3 minutes) before building further; it is the only compile check.
4. Wait for `unit-tests` (about 35 minutes, includes UI tests) and `tour`. Download the `ui-snapshots-tour` artifact into a new empty directory, verify its digest, and measure the screenshots.
5. Update the PR body with what was measured, and stop. The owner decides about merging.

## Risks

| Risk | Mitigation |
|---|---|
| UI-test churn: onboarding, the tab names and the tour are coupled to navigation | The sub-plan that changes an identifier updates its tests in the same task; budget two CI cycles per sub-plan |
| SwiftUI cannot be compiled locally | Push early, read `build-and-analyze` first; keep SwiftUI thin and the rules pure |
| The IA merge hides the shop | Armory stays a tab; the gem chip opens it; compare App Store Connect sales across the release |
| First run with denied access has no first room | Decided: three bundled sample cards (three original images, provenance in `docs/CREDITS.md`); the permission screen can never trap the user |
| The combo rule is changing (approved, own PR) | Undo restores snapshots, including the multiplier, so it does not depend on the formula |
| The roadmap's 2 weeks is optimistic | The bottom-up sum is about 3.5 weeks; slice A ships the first-session experience first |
| No in-app analytics | The assessment's validation plan (section 12) is the measurement; its baseline run belongs on the Phase 0 build **before** Phase 1 ships |

## Coverage check against the assessment

| Roadmap line (section 11, Phase 1) | Sub-plan |
|---|---|
| Onboarding rebuild (3 screens, deferred character creation, coached first room) | 1.5 |
| Undo | 1.2 |
| Dungeon home restructure and the Choose-what-to-clean sheet | 1.4 |
| Codex merge, first-run banners and empty states | 1.3 (Codex, banners), 1.6 (Hero slots) |
| Glossary microcopy (Appendix B) | 1.1 (the "Focused Dive / Hunt Chosen" renames are in 1.4) |
| Hero stage at full size | 1.6 |
| Add Room Summary, the duplicate card and the More list (if kept) to the screenshot tour | 1.7 (the More list is dropped under D3) |

| Finding | Sub-plan |
|---|---|
| S-03 time to value | 1.5 |
| S-05 nine blocks | 1.4 |
| S-08 no undo, Delete outweighs Keep | 1.2 |
| S-06 the card's content (the reward preview left over from Phase 0) | 1.2 |
| S-09 jargon without a gloss | 1.1, 1.4 |
| S-10 six tabs and duplicated data | 1.3, 1.6 |
| S-11 empty states | 1.3, 1.6 |
| S-12 Settings ordered by the builder | 1.3 |
| S-14 power tools exposed | 1.4 |
| S-15 onboarding small defects | 1.5 |
| S-16 scan wait (confidence R) | 1.1 |
| S-13 Armory state signals (remainder) | Phase 2, see 1.3 |

## Decisions

1. **Sequencing and launch: decided, slice A (14 November 2026).** 1.0 ships with Phase 0 plus slice A (1.1, 1.2, 1.5); slice B (1.3, 1.6, 1.4, 1.7) follows as the first update. Slice A is about 1.5 weeks at the spec's sizes. Sub-plan 1.1 is expanded in full in `docs/superpowers/plans/2026-11-14-phase-1-1-glossary-and-plain-words.md`; 1.2 and 1.5 are expanded just before they run.
2. **First room with photo access denied: decided.** Three bundled sample cards, then the permission screen returns (see 1.5).
3. **Combo rule: decided, built in its own PR (not Phase 1).**
   - The multiplier is a value in tenths from x1.0 to x2.0: a deletion adds 0.1 (the tenth deletion reaches x2.0); a keep takes 12%, rounded to the nearest tenth, never below x1.0 (x2.0 becomes x1.8, x1.5 becomes x1.3, x3.3 would have become x2.9). The first deletion earns the multiplier after its own step, as the old rule did.
   - A tenths integer, not a `Double`, so the cap is exactly x2.0 and no drift builds up over a long dive. It is a small pure type in `DiveRules.swift`, covered by the Linux harness.
   - **Defaults I chose, say if you disagree:** the *streak* (consecutive deletions) is a separate count that still resets on a keep, so "20 in a row", Combo King ("Reach a 20-deletion streak") and the peak-combo stats mean what they say; the HUD badge shows the multiplier ("×1.8"); rewards round to the nearest whole XP or gem, which at x1.0 and x2.0 is exactly the old result.
