---
name: modular-character-swiftui
description: Design and implement modular character composition, fitting, materials, and safe migration for SwiftUI iOS games. Use when working on HeroAppearance, MiniAvatar, SpriteEngine, modular character foundation, gear slots, body profiles, material masks, Hero Forge, ancestry, or phased asset migration while preserving existing saves.
---

# Skill: Modular Character System (SwiftUI)

## Goal
Evolve a race-locked or baked-sprite character system into a slot-based, profile-aware, material-aware composition system without breaking existing saves, purchases, or production rendering.

## Trigger
Use for HeroForge, MiniAvatar, CharacterAvatarView, HeroSpriteView, ModularCharacterFoundation, GearCatalog, body profiles, fitting, material assignment, or any request to make characters more modular or recolorable.

## Inputs
- Existing HeroAppearance model and versioned JSON seam
- Current renderer (SpriteRenderer / MiniAvatar shapes)
- Design doc under docs/superpowers (modular character system design)
- Owned gear IDs and catalog

## Process
1. Read the modular design doc first. Follow its phases and acceptance gates.
2. Phase 0 (foundation) only introduces data models, compatibility, fitting math, fingerprints, and legacy projection. Do not change production render paths.
3. Keep legacyCombined parts on the old renderer until every visible part of a recipe is verified modular.
4. Fitting never blindly stretches outside declared safe scale ranges; unsupported is preferred over distortion.
5. Materials use masks (or clear placeholders) rather than whole-part sourceAtop tints once real masked assets exist.
6. Save model stores IDs and material parameters, never rendered frames.
7. Ancestry/race change must never silently destroy custom anatomy; offer explicit whole-look, anatomy-only, or cancel.
8. Unit tests for migration projection, compatibility, clamping, fingerprint stability, and planner path selection.

## Tools
- SwiftUI Shape / Image composition
- Core Image for future mask-aware recolor
- Existing SpriteEngine as production fallback
- Swift Testing for pure fitting and migration logic

## Output
- Additive model and planner changes that leave current UI and saves intact
- Clear statement of which phase is complete and which gate is next
- No production renderer switch until Phase 5 gates are satisfied

## Quality checks
- Existing users keep class, XP, gems, equipment, streaks, achievements
- Legacy recipes always choose the legacy render path
- Fully modular recipes can choose the modular path only when complete
- Unsupported combinations cannot be selected in normal UI

## Failure handling
- Missing or incompatible asset falls back to legacy or default without blank frames
- Memory caches must respect memory warnings
- If assets are not ready, keep the production fallback and limit any modular render preview to development until the design gates are met

## Metrics
- Migration is additive and reversible
- Visual continuity for existing heroes
- Agent can state exact phase and remaining gates in one sentence
