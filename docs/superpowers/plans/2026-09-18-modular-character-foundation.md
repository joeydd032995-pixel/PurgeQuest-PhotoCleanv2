# Modular Character Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a non-destructive modular-character foundation that can describe interchangeable anatomy, compatibility-based fitting, material regions, and a legacy-safe render decision before any production art is migrated.

**Architecture:** Add pure Foundation domain types and deterministic services beside the existing sprite renderer. Project current `HeroAppearance` race/variant data into legacy manifests and recipes, mark those assets as `legacyCombined`, and require the render planner to remain on the existing renderer until all selected parts are verified modular assets.

**Tech Stack:** Swift 6 language mode as configured by the Xcode project, Foundation, Swift Testing, existing `HeroRace`/`HeroAppearance` models. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-18-modular-character-system-design.md`

## Global Constraints

- iOS remains native and offline-first.
- No third-party dependencies are added.
- Existing `SpriteRenderer`, `HeroSpriteView`, Forge behavior, and save encoding remain production behavior in Phase 0.
- Existing progression, inventory, purchases, achievements, and statistics are untouched.
- Unsafe automatic fitting returns unsupported rather than distorting outside declared scale bounds.
- Legacy combined parts must force the legacy render path.

---

### Task 1: Define canonical character contracts

**Files:**
- Create: `ios/PurgeQuest/Models/ModularCharacterFoundation.swift`
- Test: `ios/PurgeQuestTests/ModularCharacterFoundationTests.swift`

**Interfaces:**
- Produces: `BodyProfile`, `BodyProfileMetrics`, `CharacterSlot`, `CharacterPartRepresentation`, `CompatibilityLevel`, `PartManifest`, `MaterialRegion`, `MaterialRGBA`, `MaterialSelection`, `CharacterMaterialSet`, `ModularCharacterRecipe`.

- [x] **Step 1: Write tests for body-profile mapping, material clamping, and deterministic fingerprints.**
- [x] **Step 2: Parse/syntax-check the new tests.**
- [x] **Step 3: Implement the pure model types and stable fingerprint.**
- [x] **Step 4: Compile the pure model/service file against minimal repository-compatible stubs with Swift 6.2.1.**

### Task 2: Implement compatibility and fitting

**Files:**
- Modify: `ios/PurgeQuest/Models/ModularCharacterFoundation.swift`
- Test: `ios/PurgeQuestTests/ModularCharacterFoundationTests.swift`

**Interfaces:**
- Consumes: `PartManifest`, `BodyProfile`, `ModularCharacterRecipe`.
- Produces: `PartFitter.fit(_:to:) -> PartFitTransform?`, `CharacterCompatibilityResolver.level(for:recipe:) -> CompatibilityLevel`.

- [x] **Step 1: Add tests distinguishing native, adapted, and unsupported parts.**
- [x] **Step 2: Add a test proving explicit profile overrides are honored.**
- [x] **Step 3: Add a test proving scaling outside a manifest's approved bounds is rejected.**
- [x] **Step 4: Implement slot-aware profile ratios and compatibility resolution.**
- [x] **Step 5: Compile the pure implementation against minimal stubs.**

### Task 3: Add legacy projection and render safety gate

**Files:**
- Modify: `ios/PurgeQuest/Models/ModularCharacterFoundation.swift`
- Test: `ios/PurgeQuestTests/ModularCharacterFoundationTests.swift`

**Interfaces:**
- Produces: `LegacyCharacterRecipeFactory.make(from:fallbackRace:) -> LegacyCharacterMigration`.
- Produces: `CharacterRenderPlanner.plan(for:manifests:) -> CharacterRenderPlan`.

- [x] **Step 1: Add a test projecting Vampyri variant 2 into deterministic current resource IDs.**
- [x] **Step 2: Add a test proving legacy-combined manifests force `.legacy`.**
- [x] **Step 3: Add a test proving a complete compatible modular recipe can choose `.modular`.**
- [x] **Step 4: Implement deterministic legacy manifests and recipe projection.**
- [x] **Step 5: Implement the all-or-nothing render planner.**

### Task 4: Document phase boundaries and acceptance gates

**Files:**
- Create: `docs/superpowers/specs/2026-09-18-modular-character-system-design.md`
- Create: `docs/superpowers/plans/2026-09-18-modular-character-foundation.md`

**Interfaces:**
- Produces: canonical design and implementation handoff for Valkyrie proof migration.

- [x] **Step 1: Record canonical rig, profiles, manifests, materials, migration behavior, and renderer responsibilities.**
- [x] **Step 2: Record Phases 0–5 with explicit acceptance gates.**
- [x] **Step 3: Define Phase 0 as non-production-rendering and non-schema-mutating.**
- [x] **Step 4: Self-review both documents for placeholder text, inconsistent type names, and scope creep.**

### Task 5: Commit and remote verification

**Files:**
- All files above.

**Interfaces:**
- Produces: one feature-branch commit on `feature/modular-character-foundation`.

- [ ] **Step 1: Create one Git tree containing the source, tests, spec, and plan on top of current `main`.**
- [ ] **Step 2: Create a commit with message `feat: add modular character foundation`.**
- [ ] **Step 3: Advance `feature/modular-character-foundation` to the new commit without force.**
- [ ] **Step 4: Compare the branch to `main` and verify only the intended four files changed.**
- [ ] **Step 5: Inspect available commit status/workflows and report the macOS/Xcode verification limitation if no CI executes.**
