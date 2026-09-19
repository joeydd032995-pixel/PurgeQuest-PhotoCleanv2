# PurgeQuest Modular Character System Design

## Objective

Replace race-locked finished sprites with a compatibility-based character composition system while preserving the existing offline iOS architecture, current saves, current art, and current production renderer until migrated assets are proven safe.

The target invariant is:

> Animations belong to the rig. Anatomy belongs to slots. Armor belongs to equipment anchors. Color belongs to materials. Race establishes defaults and compatibility metadata.

## Current-state constraints

- PurgeQuest is a native SwiftUI/SwiftData iOS app with no backend dependency.
- Existing race art is shipped as layered PNG parts plus Spriter SCML animation projects.
- `SpriteRenderer` currently parses SCML, resolves bone transforms, recolors parts, substitutes weapon/shield art, composites frames, and caches output.
- Existing armor catalog entries are largely conceptual: race body art is baked with armor and dyed instead of swapping independent armor sprites.
- Existing armor recolor uses a semi-transparent `sourceAtop` tint; the target design replaces this with material-mask recoloring.
- Existing `HeroAppearance` data must remain valid. No implementation phase may reset class, XP, gems, purchases, equipment ownership, streaks, achievements, or statistics.

## Architecture

### Canonical rig

All humanoid characters target `humanoid_v1`. The canonical rig provides stable anchors for head, torso, left/right limbs, hands, equipment, weapons, shields, back items, and FX. Body profiles alter proportions without changing animation topology.

Initial profiles:

- `slender`
- `standard`
- `athletic`
- `skeletal`
- `brute`

The Golem and Skeletal Undead remain on the same canonical rig using `brute` and `skeletal` profiles respectively.

### Character recipe

A rendered hero is derived from:

1. ancestry/race preset,
2. canonical rig ID,
3. body profile,
4. ordered anatomy/equipment part selections,
5. material assignments,
6. animation pose,
7. compatibility and fitting metadata.

The save model stores IDs and material parameters, never rendered frames.

### Part manifests

Every modular part declares:

- stable ID,
- source resource,
- character slot,
- rig ID,
- reference profile,
- native profiles,
- adapted profiles,
- safe X/Y scaling ranges,
- optional profile-specific fitting overrides,
- anatomy coverage tags,
- recolorable material regions,
- representation type (`modular` or `legacyCombined`).

Compatibility is three-state:

- **native**: authored for the selected profile,
- **adapted**: verified to fit using canonical fitting rules/overrides,
- **unsupported**: hidden/disabled in user-facing customization.

### Fitting

Automatic fitting changes bone-relative placement and constrained part scaling. It must never blindly stretch artwork outside the manifest's safe range. Optional per-profile overrides can supply exact scale and offset values. A part that cannot fit within approved bounds is unsupported.

### Materials

The target asset pipeline uses material masks instead of global hue overlays. Material regions include skin, hair, eyes, primary armor, secondary armor, trim, leather, and emissive/FX regions. Recoloring preserves source luminance, painted texture, shadow, and highlight information while replacing chroma only inside the applicable mask.

Phase 0 introduces the material data model only. Core Image mask compositing is introduced after the first real masked asset exists.

### Renderer boundaries

The future renderer is split into four responsibilities:

1. animation produces canonical bone poses,
2. fitting resolves body-profile transforms,
3. material rendering produces cached materialized textures,
4. composition draws resolved layers in deterministic semantic order.

The existing `SpriteRenderer` remains the production fallback until the modular path passes migration gates.

## Forge UX target

The Hero Forge ultimately exposes:

- **Origin**: ancestry and starting preset,
- **Body**: profile and compatible anatomy parts,
- **Face**: existing facial identity options,
- **Gear**: equipped owned gear preview/equip controls,
- **Colors**: mask-aware body and equipment material controls.

Left/right anatomy and gear remain mirrored by default with an advanced toggle for asymmetric combinations.

Changing ancestry must not silently destroy a custom hero. The UI will offer explicit whole-look, anatomy-only, or cancel behavior.

## Save and migration strategy

The existing `HeroAppearance` versioned JSON seam remains the eventual save mechanism. Migration is additive and lenient. Existing v1-v3 appearances are first projected into a modular recipe using deterministic legacy part IDs.

Legacy source parts are marked `legacyCombined`, meaning they remain renderable by the existing renderer but cannot accidentally activate the modular renderer. This is the transitional safety boundary.

No schema bump is activated until the Forge can actually edit at least one fully modular character configuration end-to-end.

## Implementation phases

### Phase 0 — Foundation vertical slice

Implemented by the first commit:

- canonical body profiles,
- canonical character slots,
- part manifests,
- compatibility levels,
- constrained fitting calculations,
- material-assignment data model,
- deterministic render fingerprint,
- legacy `HeroAppearance` → modular recipe/manifests projection,
- render planner that keeps legacy-combined recipes on `SpriteRenderer`,
- unit tests for migration, compatibility, fitting, planning, fingerprint stability, and clamping.

No production rendering or Forge behavior changes in this phase.

### Phase 1 — One-race anatomy proof

Migrate Valkyrie first because it exercises flesh/face/hair behavior and common armor silhouettes. Produce clean modular head, torso, arms, hands, and legs against `humanoid_v1`; retain old Valkyrie assets as fallback.

### Phase 2 — One real armor/material proof

Create one complete armor set with separate PNG layers and material masks. Implement Core Image mask-aware recoloring, L1/L2 material caches, deterministic semantic layering, and snapshot/reference output.

### Phase 3 — Forge modular controls

Add Body and material-aware Colors controls. Existing race selection becomes an ancestry preset operation. Add compatibility badges, mirrored limb selection, and explicit ancestry-reset behavior.

### Phase 4 — Asset migration

Migrate remaining races and armor sets incrementally. Each migrated asset must carry a manifest and pass automated validation before becoming selectable.

### Phase 5 — Production renderer activation

Route a character through the modular renderer only when every selected visible part resolves to a verified modular manifest. Otherwise fall back to the legacy renderer without producing a blank or partial hero.

## Acceptance gates

### Phase 0 gate

- Existing UI/render paths are untouched.
- Existing save decoding is untouched.
- Legacy projection resolves deterministic current resource names.
- Legacy projections always choose the legacy render path.
- Fully modular compatible recipes can choose the modular path.
- Unsafe scaling produces `unsupported`, not clamped/distorted output.

### Phase 1 gate

- Valkyrie idle and attack poses visually align with the current art at representative frames.
- All anatomy anchors exist and remain inside declared scale bounds for native profile.
- No blank frames or missing-part crashes.

### Phase 2 gate

- Recolor affects only declared material regions.
- Source shading, highlight, alpha, and texture details remain visible.
- No semi-transparent whole-part tint is used for the migrated armor.
- Material output is cached independently from animation-frame composition.

### Phase 3 gate

- Cancel discards draft modular changes.
- Save persists and round-trips the same visual recipe.
- Changing ancestry never silently overwrites custom anatomy.
- Unsupported combinations cannot be selected in normal UI.

### Phase 4 gate

- Every selectable part has a manifest and all referenced resources exist.
- Every adapted profile has been visually approved or carries an explicit fitting override.
- Existing owned/equipped gear IDs continue to resolve.

### Phase 5 gate

- Modular renderer activation is all-or-nothing for a requested recipe.
- Missing/incompatible assets automatically fall back to legacy/default assets.
- Existing users retain progression, purchases, gear ownership, and visual continuity.
- Memory use is bounded by cost-aware caches and memory-warning eviction.

## First vertical slice rationale

The first slice intentionally does not redraw assets, change `HeroAppearance` storage, or alter `HeroSpriteView`. It establishes contracts and a migration planner first. That prevents the most damaging failure mode: switching production rendering before enough anatomy/armor assets exist to reproduce a valid character.

The next implementation after this slice should migrate one Valkyrie anatomy set and wire a development-only modular render preview, not mass-convert the asset library.
