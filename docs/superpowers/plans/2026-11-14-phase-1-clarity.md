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

- D1: "Keeping is free: no HP loss. Combo rewards are lesser." In code: `DiveRules.keepingCostsHP = false`; the combo multiplier is x1 for the first four deletions and x2 from the fifth, never more (`DiveRules.deletionsPerComboStep` 5, `DiveRules.maxComboMultiplier` 2). The old damage, defeat and Rally code stays parked behind the flag, not deleted.
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

### 1.1 Glossary and microcopy

**Goal:** Every game term carries a plain gloss at first sight, and the words in Appendix B are used everywhere.

**Files**
- Create: `ios/PurgeQuest/Models/Glossary.swift` (pure: the four terms and their glosses) and `ios/PurgeQuestTests/GlossaryTests.swift`; add both to `tools/swift_harness/run.sh`.
- Modify: `ios/PurgeQuest/Models/Wording.swift` (new phrases follow its house style: right at 0, 1 and many), `ios/PurgeQuestTests/WordingTests.swift`.
- Modify (strings found by search when expanded): `SettingsView.swift` ("Forget spared monsters"), the Bestiary stats ("Spared"), `GameDataService.swift` (quest and trophy text such as "Defeat 3 Leviathans over 2 minutes"), `CombatView.swift` (the scan wait).

**Interfaces**
- Produces (proposed): `Glossary.Term` (`dive`, `room`, `elite`, `shade`) with `Glossary.gloss(_:) -> String`, exactly the four glosses in Appendix B ("Dive: one session of up to five rooms. Room: 20 items. Elite: a boss-tier monster that pays more. Shade: a photo you deleted before; deleting it again pays nothing."). The first-seen flag lives in the app layer (`UserDefaults`, key `pq.glossary.seen.<term>`), not in the pure file.

**Scope notes**
- Appendix B renames "Focused Dive / Hunt Chosen" to "Choose what to clean / Pick items": that belongs to 1.4 (they become one sheet). "Palette" stays until Phase 2 (D2).
- S-16 ("Scan wait has no progress") has confidence R, meaning reasoned, not verified. The first task of the expanded plan reproduces it on the tour before changing anything; "Scanning your library… (with a count)" is built only if the wait is real.

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
- Produces (proposed): `struct DecisionHistory { mutating func record(_ entry: Entry); mutating func undoLast(now: Date) -> Entry?; func canUndo(now: Date) -> Bool }`, with `Entry` holding the item id, whether it was a delete, the previous `combo`, `peakCombo`, `perfectRoom`, `hero.highestCombo`, and `recordedAt`. Pure, so the five-second window and the "one step only" rule are harness-tested with an injected `now`.

**Spec (assessment 10.2, verbatim):** "Undo: Glass pill above the buttons for 5 s after any decision; rewinds one step." "Coach mark: First card only: two arrows with labels, dismissed by the first swipe or tap." "Decisions: Keep (`surface`, `patina` shield) and Delete (`ember-fill`, `on-ember`), equal width, 56 pt." Keep and Delete are also VoiceOver actions.

**Acceptance:** keep or delete, tap Undo within five seconds, and the card returns with combo, perfect-room state and persistence exactly as before; after five seconds, or one step back, there is nothing to undo; the coach mark appears on the very first card only and never again.

### 1.5 Onboarding rebuild: 3 screens, deferred look, coached first room

**Goal:** Nine taps and seven screens become three screens and a coached first room; race, class and look arrive as a reward.

**Today** (`ios/PurgeQuest/Views/Onboarding/OnboardingView.swift`, 590 lines): six swipeable pages (intro, permission, race, class and name, look, swipe tutorial) with state for race, class, name and `draftLook`, and a looping `DemoSwipeCard`. The choices are written to `UserDefaults` and applied to the hero by `GameDataService.applyOnboardingChoices` (`GameDataService.swift:65`); `AppState.hasOnboarded` is `pq.hasOnboarded`.

**Files**
- Modify: `OnboardingView.swift` (reduce to Promise and Permission), `AppState.swift` (the phase after Permission is the coached first room), `CombatView.swift` (the coach mark from 1.2 runs on the real first card), `GameDataService.swift` (`provision` already calls `loadOrCreateHero` and then applies any saved choices; the expanded plan confirms which defaults a hero gets when nothing was chosen, Valkyrie and Holy Paladin being the onboarding state's defaults, that it runs before the first dive, and how the later "Level up your look" writes to the hero), `RoomSummaryView.swift` (after the first Room Summary, offer "Level up your look").
- Create: `ios/PurgeQuest/Views/Onboarding/LevelUpLookView.swift` reusing the existing race, class, name and look controls (`LookControls.swift`, `HeroForgeView.swift` swatches).
- Modify tests: `OnboardingResetUITests.swift` (it walks "Choose Your Race" and `onboarding.race.necromancer` today), `AppearanceTourUITests.swift` (the onboarding shots).

**Spec (assessment 8.2, verbatim):** "Three screens (Promise, Permission, First room), then straight into a coached first room. Race, class and look arrive as 'Level up your look' after the first Room Summary. The permission screen can never trap the user. 9 taps become 3." Validation pass (section 12): "Install, open, get to the first card. Pass: under 60 seconds, no help, nobody stuck at permission."

**Open design question (owner):** what is the first room when photo access is denied? See "Decisions needed", item 2.

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
| First run with denied access has no first room | Owner decision 2; the permission screen can never trap the user |
| The combo formula may change | Undo restores snapshots, so it does not depend on the formula |
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
| S-09 jargon without a gloss | 1.1, 1.4 |
| S-10 six tabs and duplicated data | 1.3, 1.6 |
| S-11 empty states | 1.3, 1.6 |
| S-12 Settings ordered by the builder | 1.3 |
| S-14 power tools exposed | 1.4 |
| S-15 onboarding small defects | 1.5 |
| S-16 scan wait (confidence R) | 1.1 |
| S-13 Armory state signals (remainder) | Phase 2, see 1.3 |

## Decisions needed from the owner

1. **Sequencing and launch.** The assessment says: "If the launch date is fixed, ship Phase 0, test on TestFlight, then Phase 1. If it can move two weeks, add Phase 1 before submission." Phase 0 is on `main`. This plan assumes slice A is built next either way; the decision is whether 1.0 ships with Phase 0 only, with slice A, or with all of Phase 1 (the bottom-up estimate is about 3.5 weeks, not 2).
2. **First room with photo access denied (1.5).** Options: (a) three bundled sample cards teach the gesture without touching the library, then the permission screen returns; (b) skip the first room and land on the Dungeon with the access Notice. Recommendation: (a), so the first minute works for the people most worried about permission.
3. **Combo rule.** Your request: keeping should cost a small percentage of the combo instead of resetting it, with an example of 3.3x to 2.9x. That conflicts with the D1 cap of x2. Proposal: a continuous multiplier rising 0.1 per deletion, capped at x2.0, with keeping taking 12% (never below x1.0). It is a separate small change to `DiveRules`, not part of Phase 1, and nothing in this plan depends on it.
