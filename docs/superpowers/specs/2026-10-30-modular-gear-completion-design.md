# Modular Characters, Held Gear, and Forge Completion — Design

Builds on `2026-09-18-modular-character-system-design.md` (Phase 0 foundation). This document covers the work that takes Phases 1–4 from "contracts exist" to "every asset has resources, fitting data, masks, and Forge behavior", and states exactly what remains a human or device gate.

## Goal

Complete separated anatomy/armor for all eight races, finish every listed gear asset, and make fitting, recoloring, equipping, and saving work reliably on iOS — without ever switching production rendering to a path that has not been approved.

## Verified starting state (repository, 2026-10-30)

- Phase 0 exists: `ModularCharacterFoundation.swift` (profiles, slots, manifests, fitter, planner, legacy projection) and its tests.
- No modular art exists. Every race pack (`Art/Races/<race>/v1..v3`, 27 packs; Skeletal Undead ships six variants from two packs) is 14 baked layers: `body, head, face_01..03, left/right arm, left/right hand, left/right leg, shield, slashfx, sword|bow+arrow`. Armor is painted into body/arms/legs; headgear/hair is painted into `head`; the skin "face window" is an outlined flat region.
- `SpriteRenderer` draws held gear at the SCML weapon/shield anchor with no per-item fit. Titan Blade applies `1.4×` (`SpriteEngine.swift:543`); the store copy and `MiniAvatar` say `2×`.
- The 14 store items (3 headpieces, 9 weapons, 2 shields) exist only as hand-drawn SwiftUI shapes in `MiniAvatar`; `GearCatalog.design(id:)` returns nil for them, so the sprite renderer ignores them.
- `HeroForgeView.save()` runs `try? modelContext.save()` then dismisses: a failed save looks like success. The Forge has no gear or material controls; equipment is changed only in the Armory and persists immediately.

## Status model (mapped ≠ verified)

Every asset carries one status. Only a human approval moves it to `verified`.

| Status | Meaning | Who sets it |
|---|---|---|
| `unstarted` | no resources yet | tool |
| `mapped` | resources exist, anchors recorded, structural validators pass | tool |
| `candidate` | `mapped` + automated visual checks produced (overlays, contact sheets, bounds) and passed; awaiting review | tool |
| `verified` | a reviewer approved the visual output; approval is in `docs/modular/approvals.json` | **human** |
| `unsupported` | cannot be fit within safe bounds / failed a check | tool |

The generator merges the approvals ledger into the bundled manifest. A `verified` status without a ledger entry is a validator failure. This session produces `candidate` assets only; production modular rendering therefore stays off, and the legacy renderer remains the fallback for every recipe.

## Asset pipeline (offline Python, `tools/modular_assets/`)

Pillow + NumPy only; assets are committed, the tools are not bundled in the app.

1. `scml.py` parses SCML and rasterizes frames with the same transform math as `SpriteRenderer` (bone chain → world placement, pivot, y-up). It is the visual-check engine for everything below.
2. `separate.py` splits each baked part by connected components of non-outline pixels (the art closes every region with a dark outline):
   - **Head:** the face window (flat skin/bone/stone region) becomes the *anatomy* layer — a full bare-head silhouette with the same outline weight, filled from the window's palette. The original head with the window cut out becomes the *headgear* layer (slot `helmet`, `hair` mask where hair is painted).
   - **Torso/limbs:** the anatomy layer is a bare silhouette in the race's skin/bone/stone palette; the baked part is the *armor* layer (`chestArmor`, `leftGauntlet`/`rightGauntlet`, `leftLegArmor`/`rightLegArmor`).
   - **Hands:** skin-colored mitts are anatomy-only; metal gauntlet hands add an armor layer over a skin hand.
   - **Bone/stone races:** the part is anatomy; only genuinely armored parts (crusader/warrior plate, helms) become armor layers.
   - A per-pack override file corrects any segmentation the heuristics get wrong.
3. Material masks are 8-bit grayscale PNGs, one per region present on a layer (`skin, hair, eyes, primary, secondary, trim, leather, emissive`), soft-edged, multiplied by the layer alpha. The dark outline is never inside a mask, so recoloring preserves linework, shading (luminance), highlights, and texture.
4. Resource names are flattened into the bundle root by the synchronized Xcode group, so every file uses a globally unique base name: `<pack>_<part>_<layer>[_mask_<region>]` (e.g. `valkyrie_v1_body_anatomy`, `valkyrie_v1_body_armor_mask_primary`). Manifests go to `Art/Modular/modular_character_manifest.json`.
5. `validate.py` checks: every referenced PNG exists with expected mode and size; masks are grayscale, within the layer's alpha, non-empty for declared regions, disjoint except at soft edges; anatomy+armor recomposite matches the original baked part within tolerance (the *reassembly gate*); all anchors exist in the SCML; fit scales are inside declared safe ranges; no duplicate base names.
6. Per pack the tool renders Idle and Slashing/Shooting frames at representative indices: original vs modular recomposite vs recolor test, written under `docs/modular/verification/`.

### Body-profile fit

For each part the tool evaluates `PartFitter` for all five profiles. Profiles inside the safe scale range are `adapted` (the race's default profile is `native`); the rest are `unsupported` and hidden from normal UI. Default safe range is 0.90–1.10; per-part overrides are only recorded when the computed scale is in range. Each (part, profile) pair gets an overlay image so a reviewer can approve or reject it.

## Held gear

A `HeldGearFit` record per item and race group captures grip position and pivot (fractions of the sprite, y-up), scale, rotation, layering (front/behind hand), optional per-profile overrides, and status. Items: 8 signature weapons (including the Elven Recurve bow with string alignment and its Shooting animation), the Valkyrie sword, 40 staves, 40 shields, and the 14 store items.

- Sprite-path rendering applies the fit record when present and otherwise uses the existing generic anchor behavior, so nothing regresses.
- Recolor masks are generated per item (`primary`, `trim`, `leather`, `emissive` where present) with the same rules as armor masks.
- **Titan Blade:** `2×` about the existing grip pivot. Because the SCML canvas is sized to the 1× parts, the renderer computes an expanded canvas for Titan frames; the tool verifies no clipping across every race, variant, and animation frame at 2×.
- The 14 store items get new procedural sprites in the existing outlined style, ported from the `MiniAvatar` geometry. Catalog IDs, prices, ownership, and unlock requirements are untouched; the existing `CosmeticItem` seeds are reused.

## Renderer and planner (Swift, additive)

- `PartManifest` gains `verification` and `maskResources`; defaults keep every existing manifest and test valid.
- `CharacterRenderPlanner` requires `verification == .verified` for every selected part; otherwise it returns `.legacy` with an `unverified:<id>` reason. Missing/duplicate/incompatible assets keep falling back to legacy.
- `ModularAssetCatalog` loads the bundled manifest and resolves recipes. Failure to load yields an empty catalog (all recipes legacy), never a blank hero.
- `HeldGearFitResolver` maps (gear ID, race, body profile) to a placement and clamps through the manifest's safe range.
- `MaterialRecolorer` (Core Image) applies masked chroma replacement preserving luminance, caches per (layer, mask, color), and evicts on memory warning.
- Titan Blade becomes a named constant `HeldGearFit.titanScale = 2`.

## Forge and persistence

- `HeroAppearance` gains optional `materials: CharacterMaterialSet?`, decoded leniently; `currentSchemaVersion` becomes 4. Existing v1–v3 saves decode in place; unknown/corrupt `materials` decodes to nil.
- Forge adds **Gear** (owned, race-compatible items per slot) and **Colors** (masked material regions) categories. Equipment and colors are held in the draft (`ForgeDraft`), applied to `CosmeticItem.isEquipped` and `hero.appearance` only on Save; Cancel and swipe-down discard.
- Save runs through an injectable `AppearanceSaving` seam. On failure it restores the previous appearance and equipment, keeps the Forge open, and shows an error alert; success haptics fire only after a successful save.
- Changing ancestry when the draft has customizations shows **Whole look / Anatomy only / Cancel**. Whole look adopts the new race's designed default. Anatomy only changes race/variant and keeps face traits, hue shifts, and materials. Cancel leaves the draft unchanged.
- Unsupported (race, profile, part) combinations are not offered.

## Validation

- Python: unit tests for validators and the SCML rasterizer against known frames.
- Swift Testing (run on CI and, for pure-Foundation sources, locally on a Linux toolchain): manifest decoding, planner gate, fit bounds and overrides, Titan constant and pivot math, migration v3→v4, save round-trip, save failure rollback, ancestry resolver, renderer fallback selection, catalog ID/price/unlock preservation.
- XCUITest: Forge flows behind a `-UITestSeedForge` launch argument using an in-memory store.
- Not possible in this environment: iOS simulator and physical iPhone runs, visual approval, small-preview and combat rendering checks on device, relaunch persistence, and memory profiling. These are listed in the checklist as open gates.

## Completion gate

An asset becomes selectable in modular rendering only when it is `verified`. Until reviewers approve candidates (via `tools/modular_assets/approve.py`, which records the ledger entry), the app behaves exactly as before for character rendering, while held gear gains per-item fit, Titan 2×, and the Forge/save fixes.

## Implementation status (this change)

Done and checked in CI/locally: separation pipeline and masks for all 27 packs; held-gear fits for 8 signature weapons (including the Elven Recurve bow), 40 staves, 40 shields and the 14 store items; Titan Blade at `2.0x` about the grip with an expanded canvas; manifests, validator, approvals ledger and generated checklist; verified-only planner gate; Forge Gear/Colors, draft-until-Save, atomic save with rollback and a visible error, explicit ancestry choices; HeroAppearance v4 (additive); Elven v3 attack-animation fix; Swift Testing suites (pure logic run on Linux, bundle tests and Forge UI tests on the CI simulator).

Deliberately *not* claimed: every asset is `candidate`, not `verified` — approval is a human act recorded in `docs/modular/approvals.json`. Body colours are therefore inert until a look's layers are approved (the Forge says so); gear colours are live. Physical-iPhone checks (small previews, combat rendering, relaunch persistence, memory) remain open in `docs/modular/CHECKLIST.md`.

Findings worth knowing: Elven variant 3 is a sword pack with no `Shooting` animation (the Recurve is therefore unsupported there, and v3 previously never attacked); the baked weapon anchor is hidden in Idle but a swapped item is still drawn there, so the canvas now includes hidden anchors; shields on packs without a baked shield were squashed into the 128px left-hand rect and now draw at native size.
