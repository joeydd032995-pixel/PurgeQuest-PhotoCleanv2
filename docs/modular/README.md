# Modular character & gear pipeline

Everything here is produced by `tools/modular_assets/` (Python 3, Pillow + NumPy only) and shipped as plain PNG/JSON under `ios/PurgeQuest/Art/`. Design: `docs/superpowers/specs/2026-10-30-modular-gear-completion-design.md`. Current state: [`CHECKLIST.md`](CHECKLIST.md).

## What exists

| Output | Where | Produced by |
|---|---|---|
| Anatomy / armor / headgear layers + soft recolor masks for all 27 packs | `Art/Modular/<race>/v<n>/` | `build_assets.py` |
| Races manifest (parts, fits, mask resources, automated results) | `Art/Modular/modular_races_manifest.json` | `build_assets.py` |
| Held-gear grips, per-pack holds, head fits, Titan canvas analysis | `Art/Modular/modular_gear_manifest.json` | `held_gear.py` |
| Gear recolor masks | `Art/Modular/Gear/` | `held_gear.py` |
| 11 store weapon/shield sprites | `Art/Gear/store/` | `store_gear.py` |
| QA sheets (layers, fit per body profile, gear, Titan) | `docs/modular/verification/` | the scripts above |
| Checklist + status | `docs/modular/CHECKLIST.md`, `asset_status.json` | `checklist.py` |
| **Versioned inventory of every asset** (set version, per-asset revision, content hash, attention flags) | `docs/modular/ASSET_INVENTORY.md`, `asset_inventory.json` | `inventory.py` |

## Which set am I looking at?

`inventory.py` stamps every asset from git, so the numbers cannot drift from the files: **set `vN`** is the Nth commit that changed the shipped art (`+wip` = uncommitted art changes), **`rK`** counts how many sets changed that asset, and **`#xxxxxxxx`** is a hash of its pixels, so two renders showing the same hash are the same asset. `python3 -I tools/modular_assets/inventory.py --sheets DIR` also writes contact sheets (one PNG per pack and gear group, each with the set banner and the same stamps) and a single PDF. The "Needs attention" section of `ASSET_INVENTORY.md` lists assets worth a second look: computed signals (tiny or stray regions, low mask coverage) plus issues recorded by hand from reviewing renders (`KNOWN_ISSUES` in the script). A flag means *look*, not *wrong*; notes (regions merged since the previous set, unsupported body profiles) are information.

## Regenerate

```sh
python3 -I tools/modular_assets/store_gear.py        # store sprites + spec
python3 -I tools/modular_assets/build_assets.py      # race layers, masks, races manifest, sheets (~6 min)
python3 -I tools/modular_assets/held_gear.py         # held-gear manifest, masks, sheets
python3 -I tools/modular_assets/approvals.py apply   # re-stamp statuses from the ledger
python3 -I tools/modular_assets/validate.py          # must exit 0
python3 -I tools/modular_assets/checklist.py
python3 -I tools/modular_assets/tests/test_modular_assets.py
```

## Approving assets (the only way anything becomes `verified`)

Open the sheets, then record who looked:

```sh
python3 -I tools/modular_assets/approvals.py approve valkyrie_v1 --reviewer "Your Name"                 # part-level (native profile)
python3 -I tools/modular_assets/approvals.py approve valkyrie_v1 --reviewer "Your Name" --profile standard   # an adapted fit
python3 -I tools/modular_assets/approvals.py approve weapon.staff.1 --reviewer "Your Name"              # prefix match works for gear ids
```

`approvals.py` appends to `docs/modular/approvals.json` and re-stamps both manifests. The validator rejects `verified` without a ledger entry. At runtime `CharacterRenderPlanner` sends a recipe to the modular renderer only when **every** selected part is `verified` and each adapted profile is approved; anything else falls back to the legacy renderer without a blank frame.

## How the separation works (and its limits)

The art closes every region with a dark outline. The head's skin "face window" is found by flood-filling from the face overlay's centre; the bare head is that window plus a hull-smoothed cranium, and the original head with the window cut out is the headgear layer. Torso, limbs, and non-skin hands get a flat bare-silhouette anatomy layer under the baked part as armor. Parts that are already skin/bone/stone (skulls, stone bodies, mitts) are anatomy-only. `overrides.json` corrects packs where a near-black hood hides the window.

## Recoloring

Masks are *adhesive*: each pixel is first assigned to a material region, but pixels beside an outline or the silhouette edge (anti-aliased blends whose colour is misleading) inherit the region of their nearest confident interior pixel, and a 5x5 vote removes speckle. Region names (`primary`, `secondary`, ...) are clustered per art pack (per sprite for held gear), so they mean the same material on every part.

**A material is one region, however it is shaded.** Colour is clustered on a lightness-independent chromaticity (OKLab a, b over lightness), so a lit plank and a shaded one, or a rim and its highlight stripes, land together. Clusters closer than `MERGE_DISTANCE`, or two clearly coloured clusters within `HUE_MERGE_DEGREES` of the same hue (a pale tint of its base), merge. Inside one outline-bounded cell, a split between same-hue colours is shading and merges too (`merge_shading_splits`). Different hues, and neutral versus coloured, stay separate.

**Linework never recolors.** `imgops.outline_mask` treats as outline: thin strokes and the small dark blobs where strokes meet; dark pixels within a stroke's width of the silhouette edge (the dark glow band some sprites have outside their stroke); and pixels of exactly the outline's own colour that belong to a ring around other fill (a doubled stroke along the top of a shield). A dark pixel counts as line work only if it is near the sprite's own measured outline colour, so dark brown planks or a navy robe stay paintable. Weights on outline pixels are exactly zero.

The recolor itself runs in OKLab (`imgops.recolor_pixels`, mirrored in `RecolorMath.swift`): a pixel keeps its lightness offset from its region's mean, so shadows, highlights and painted texture survive, re-centred on the chosen colour's lightness; the hue becomes the chosen colour's; chroma follows it, is modulated by how the source's chroma varied, and is fitted into the sRGB gamut so saturated colours desaturate instead of clipping. The region means (`regionTone`) are measured over the whole pack, so parts of one material keep their relative brightness. `tests/` and `ModularGearTests.swiftRecolorMatchesThePythonReference` pin the two implementations to each other.

Limits to review: bare anatomy is procedural (flat fill, matching outline), not hand-painted; hair is not separately masked where it is baked into headgear; Golem/skeleton parts that *are* the material have no separate armor art.

## Held gear model

Each item stores its grip (image px). Each pack stores the *hold* where its own baked weapon sits. `offset(s) = hold - s * (grip - pivotPx)` keeps the grip in the hand at any scale, so the Titan Blade (`HeldGearFit.titanScale = 2`) grows about the grip. The renderer unions the pack canvas with the item rect over every frame (hidden anchors included) so nothing clips; the view keeps the character's size and lets the blade overflow.

## Local Swift checks

`SWIFT_BIN=/path/to/swift tools/swift_harness/run.sh` compiles and runs the pure-Foundation suites on Linux (Swift 6.2). UIKit/SwiftUI code (`SpriteEngine`, Forge views) is compiled and tested only by Xcode/CI.
