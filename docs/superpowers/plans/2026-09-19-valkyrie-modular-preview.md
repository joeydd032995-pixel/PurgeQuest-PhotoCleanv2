# Valkyrie Modular Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate Valkyrie v1 anatomy metadata onto `humanoid_v1` and expose a development-only modular renderer preview that always falls back to the existing Valkyrie renderer when modular rendering is unavailable.

**Architecture:** Add a Valkyrie v1 modular asset set that reuses the existing split PNG/SCML art but marks only the anatomy pieces needed by the preview as modular. Add a preview renderer that consumes the existing SCML pose data, resolves modular anatomy resources by slot, and composites those resources using the same placements. Expose this only under `#if DEBUG`; production `HeroSpriteView` remains unchanged.

**Tech Stack:** Swift 5/6, SwiftUI, UIKit/CoreGraphics, existing SCML/SpriteEngine, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-09-18-modular-character-system-design.md`

## Global Constraints

- iOS 18+ / iPhone.
- No third-party dependencies.
- Existing race renderer remains the production fallback.
- Preview is compiled only in DEBUG builds.
- Do not mutate existing player save data.
- Reuse current Valkyrie v1 PNG/SCML assets; do not invent missing anatomy.

---

### Task 1: Valkyrie v1 modular anatomy catalog

**Files:**
- Create: `ios/PurgeQuest/Models/ValkyrieV1ModularAssetSet.swift`
- Test: `ios/PurgeQuestTests/ValkyrieModularPreviewTests.swift`

**Produces:** `ValkyrieV1ModularAssetSet.recipe`, `.manifests`, resource resolution, and preview gating.

- [x] Add failing tests that require eight Valkyrie anatomy slots, `humanoid_v1`, athletic-native compatibility, and `.modular` representation.
- [x] Implement the Valkyrie v1 catalog using the existing `valkyrie_v1_*` resources.
- [x] Verify the pure Swift catalog harness passes.

### Task 2: Development modular renderer

**Files:**
- Create: `ios/PurgeQuest/Services/ModularCharacterPreviewRenderer.swift`
- Test: `ios/PurgeQuestTests/ValkyrieModularPreviewTests.swift`

**Produces:** `ModularCharacterPreviewRenderer.frame(...) -> UIImage?` in DEBUG builds.

- [x] Add planner/resource-resolution tests for Valkyrie v1.
- [x] Implement deterministic slot/stem resolution and use the existing Valkyrie SCML placement data for Idle/Slashing poses.
- [x] Keep all preview renderer code under `#if DEBUG`.

### Task 3: Debug-only comparison view

**Files:**
- Create: `ios/PurgeQuest/Views/Hero/ModularCharacterDebugPreview.swift`

**Produces:** Xcode DEBUG previews comparing Legacy / Modular rendering and demonstrating fallback.

- [x] Render the existing `HeroSpriteView` fallback next to the modular preview.
- [x] Show plan/fallback state for unsupported races or non-v1 Valkyrie variants.
- [x] Compile the entire view only in DEBUG builds.

### Task 4: Verification gates

- [x] Production `HeroSpriteView` remains unchanged.
- [x] No save-schema changes introduced.
- [x] Non-Valkyrie and Valkyrie v2/v3 requests report legacy fallback.
- [x] Pure Swift catalog harness passes and DEBUG files/tests pass syntax parsing in Swift 6.2.1.
- [ ] Run full Xcode build/tests on macOS CI or local Xcode when available.
