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
| Reviewer's guide (waves, sheets, commands) | `docs/modular/REVIEW.md`; order in `review_waves.json` | `review_kit.py` |
| **Versioned inventory of every asset** (pass label, per-asset revision, content hash, attention flags) | `docs/modular/ASSET_INVENTORY.md`, `asset_inventory.json`; pass names in `asset_sets.json` | `inventory.py` |

## Which set am I looking at?

Assets ship in named **passes** (`asset_sets.json`): v4 = OKLab recolor; v4.1 = PR #11 (authored gear surfaces, corrected Lost Souls 1 / Elven 1 / Seer 2); v5 = PR #12 (chroma-cell gear and shield masks, also pinned at the `archive/asset-set-v5` branch); **v6 = the landed set**: every gear item uses the v5 masks, characters and tooling are #11's. `inventory.py` stamps every asset from git, so the numbers cannot drift from the files: **`rK`** counts how many passes changed that asset, **`last changed`** names the pass that last did (a gear mask that is pixel-identical to v5 reads v5, a character mask from #11 reads v4.1), and **`#xxxxxxxx`** is a hash of its pixels, so two renders showing the same hash are the same asset. The commit hash is the identity; the label is the name. `python3 -I tools/modular_assets/inventory.py --sheets DIR` also writes contact sheets (one PNG per pack and gear group, each with the set banner and the same stamps) and a single PDF. The "Needs attention" section of `ASSET_INVENTORY.md` lists assets worth a second look: computed signals (tiny or stray regions, low mask coverage, gear masks that leave a lot of what `authored-surfaces-v1` would recolour untouched) plus issues recorded by hand from reviewing renders (`KNOWN_ISSUES` in the script). A flag means *look*, not *wrong*.

## Regenerate

```sh
python3 -I tools/modular_assets/store_gear.py        # store sprites + spec
python3 -I tools/modular_assets/build_assets.py      # race layers, masks, races manifest, sheets (~6 min)
python3 -I tools/modular_assets/held_gear.py         # held-gear manifest, material masks (default algorithm), fit sheets
# Rebuild just materials while retaining all fitting/anchor data; pick the algorithm with --algorithm:
python3 -I tools/modular_assets/held_gear.py --masks-only --no-sheets
python3 -I tools/modular_assets/held_gear.py --masks-only --algorithm authored-surfaces-v1
python3 -I tools/modular_assets/approvals.py apply   # re-stamp statuses from the ledger
python3 -I tools/modular_assets/validate.py          # must exit 0
python3 -I tools/modular_assets/checklist.py
python3 -I tools/modular_assets/review_kit.py      # reviewer's guide
python3 -I tools/modular_assets/inventory.py         # versioned inventory (add --sheets DIR for contact sheets + PDF)
python3 -I tools/modular_assets/tests/test_modular_assets.py
```

## Which hand holds what

Every art pack bakes its sword (or bow) into the **Left Hand**, the one on the right of the screen. Valkyrie and Skeleton Crusader also bake a shield, and they hold it in the **Right Hand**. A pack with no shield part holds a swapped-in shield in the Right Hand too (`scml.SHIELD_HAND`, written to each pack's `shieldAnchor` in `modular_gear_manifest.json`, read back by `HeldGearAnchors` in `SpriteEngine.swift`), so a shield never sits on top of the blade. `HeldGearAnchorTests` checks this on the shipped art: in every pack and every idle and attack frame the shield and weapon anchors are more than 80 units apart (148 at the closest).

### How a swapped-in weapon is held

A weapon that is just pasted on top of the character floats in front of the body, so the renderer layers it the way each pack layers its own (`scml.render_frame`, mirrored by `SpriteRenderer.frame`):

- **Attack frames** (Slashing, Shooting, Run Slashing, Slashing in The Air): the pack draws its sword at the very back, behind the hand, the arm and the body, so only the blade shows and the fist covers the grip. The swapped weapon takes that same layer. (A swapped bow's string is drawn right after the arrow, in front of the body, when one is nocked.)
- **Every other frame** (the idle pose, walking, hurt): the pack draws no sword and its fist hangs empty at the hip. The weapon is drawn in front and the weapon hand is **drawn again over the grip**, so the fist visibly closes around it. The hand is the manifest's `weaponHand` (`held_gear.weapon_hand`, the hand whose pivot is nearest the weapon anchor; the Left Hand in all 27 packs).

A swapped item is gripped at **2%** from its pommel (`held_gear.ITEM_GRIP_FRACTION`), not at the 10% the packs' own baked swords use (`BAKED_GRIP_FRACTION`, which is what defines each pack's `hold`). The hold point sits inside the fist, and the fist is drawn over it, so a grip further along the blade would bury the crossguard in the hand instead of leaving it clear.

#### Carried up and away from the hip

The packs draw the idle hand at hip height, and hold the sword sideways through most of the swing (8 of 11 Slashing frames in most packs), so a weapon left the way the art draws it sticks straight out from the pelvis, which reads as something it is not. So a blade, staff or hammer is **never left pointing flat**: whenever it points between `CARRY_FLOOR` (-45 degrees) and `CARRY_ANGLE` (45 degrees), measured counter-clockwise from the way it points in its art (0 is straight out sideways, 90 is straight up), it is turned **about its grip** up to 45 degrees, so it rises up and away from the body and clears the head in every pack.

- It is decided frame by frame from the weapon anchor's own angle (`held_gear.carry_turn`, `HeldGearFit.carryTurn`), so the idle pose (the anchor points 5 to 17 degrees up) always carries at exactly 45, and the follow-through of the swing (0 to 6 degrees) is lifted to 45 too. The wind-up (the sword raised behind and above the head, 54 to 160 degrees) and a sword pointing back are left alone, so the swing still reads as a swing.
- Turning about the pivot moves the grip, so the fit starts the grip where the hold would be after turning the other way and the turn carries it back onto the hold (`local_offset(..., rotation)`, `HeldGearFit.offset(..., rotationDegrees:)`). The hand never lets go, at any scale (Titan Blade included, and the pack's own baked weapon on a Titan hero).
- `carryAngle` is in the manifest on every blade, staff and hammer (56 items) and absent on the bow and the shields, which are not turned; `validate.py` checks that. Bows are upright already. The canvas takes the union of every frame's own rect, turned or not.

Checked on the shipped art for all 27 packs by `WeaponInHand` and `CarryAngle` in `tests/test_modular_assets.py` (the hold lies 5 to 29 units from the middle of the fist in every idle frame; the pack's own weapon is behind the hand and the body in all 992 frames where it shows; the fist's centre pixel is the fist's own, where leaving the redraw out would leave the weapon on top of it in 21 of 27 packs; none of the 3,180 frames of the 25 sword packs leaves a carried blade flat, and all 100 idle frames carry at 45) and by `HeldGearAnchorTests` and `ModularGearTests` in the app.

## Approving assets (the only way anything becomes `verified`)

Start with [`REVIEW.md`](REVIEW.md). It orders the work into waves (the default paint of each race first: eight packs that between them cover all five body profiles), and for every pack and gear group gives the sheets to open, what the inventory already flags, and the command. Then record who looked:

```sh
python3 -I tools/modular_assets/approvals.py status                                              # where review stands
python3 -I tools/modular_assets/approvals.py approve pack:valkyrie_v1 --reviewer "Your Name"     # every layer of one pack
python3 -I tools/modular_assets/approvals.py approve pack:valkyrie_v1 --reviewer "Your Name" --profile standard   # an adapted fit
python3 -I tools/modular_assets/approvals.py approve group:staff1 --reviewer "Your Name"         # a gear group
python3 -I tools/modular_assets/approvals.py approve id:weapon.staff --reviewer "Your Name"      # exactly one asset
python3 -I tools/modular_assets/approvals.py revoke pack:valkyrie_v1 --reviewer "Your Name" --note "why"
python3 -I tools/modular_assets/review_kit.py                                                    # refresh REVIEW.md
```

`approvals.py` writes `docs/modular/approvals.json` and re-stamps both manifests. What keeps the ledger honest:

- **An approval is pinned to content.** Each record stores a SHA-256 of the files that were reviewed: the image and every mask, plus the fit numbers for a `--profile` approval (`pinning.py`). Regenerate an asset and its record is *stale*: the asset drops back to `candidate` at the next `apply`, and `status`, `validate.py` and `REVIEW.md` all report it until someone looks again (approving replaces the stale record) or revokes it.
- **Only an asset whose automated checks passed can be approved.** A `mapped` asset is refused.
- **A fit approval counts only alongside the layer's own**, and is recorded only for layers that adapt to that profile. Revoking a layer removes its fit approvals too.
- **Revocations are kept** in the ledger, so it is a history.
- **A bare target that is both an id and a prefix is refused.** `weapon.staff` is the Archmage Staff and also the start of forty staves; say `id:`, `pack:` or `group:`.

The validator rejects `verified` without a current ledger record. At runtime `CharacterRenderPlanner` sends a recipe to the modular renderer only when **every** selected part is `verified` and each adapted profile is approved; anything else falls back to the legacy renderer without a blank frame. So approval is progressive, one art pack at a time: an approved pack renders modular and unlocks its Forge body colours, and every other pack looks exactly as it does today. Held-gear approval is a record that someone looked; no rendering path reads it.

## How the separation works (and its limits)

The art closes every region with a dark outline. The head's skin "face window" is found by flood-filling from the face overlay's centre; the bare head is that window plus a hull-smoothed cranium, and the original head with the window cut out is the headgear layer. Torso, limbs, and non-skin hands get a flat bare-silhouette anatomy layer under the baked part as armor. Parts that are already skin/bone/stone (skulls, stone bodies, mitts) are anatomy-only. `overrides.json` corrects packs where a near-black hood hides the window.

## Recoloring

Race-layer masks are *adhesive*: each pixel is first assigned to a material region by colour, but pixels beside an outline or the silhouette edge (anti-aliased blends whose colour is misleading) inherit the region of their nearest confident interior pixel, and a 5x5 vote removes speckle. Thin outlines and the small dark blobs where outlines meet are excluded, so linework never recolors. Region names (`primary`, `secondary`, ...) are clustered per art pack, so they mean the same material on every part.

The recolor itself runs in OKLab (`imgops.recolor_pixels`, mirrored in `RecolorMath.swift`): a pixel keeps its lightness offset from its region's mean, so shadows, highlights and painted texture survive, re-centred on the chosen colour's lightness; the hue becomes the chosen colour's; chroma follows it, is modulated by how the source's chroma varied, and is fitted into the sRGB gamut so saturated colours desaturate instead of clipping. The region means (`regionTone`) are measured over the whole pack, so parts of one material keep their relative brightness. `tests/` and `ModularGearTests.swiftRecolorMatchesThePythonReference` pin the two implementations to each other.

Limits to review: bare anatomy is procedural (flat fill, matching outline), not hand-painted; hair is not separately masked where it is baked into headgear; Golem/skeleton parts that *are* the material have no separate armor art.

For the three reported model fixes and their idle/attack comparisons, see [Recolor fixes](recolor-fixes.md).
Their authored semantic masks override clustering for the affected paints. Soft region boundaries in both Python and
Swift blend independently from the original pixel, so applying multiple colors cannot recolor shading twice or depend on region order.

## Legacy recolor of baked parts (skin, hair, armor dye)

Until a pack is human-approved, the app draws the baked part PNGs (the legacy renderer). The skin, hair and armor-dye swatches recolor those pixels through the shipped masks, with the same shading-preserving OKLab math as above. Design and the discussion behind it: [`docs/superpowers/specs/2026-11-06-hero-look-recolor-design.md`](../superpowers/specs/2026-11-06-hero-look-recolor-design.md).

**Recorded policy exception.** Masks that are still `candidate` may recolor baked pixels, exactly as held-gear masks already do. Nothing else about approval changes: composition (the anatomy substitution), `CharacterRenderPlanner`, the `verified` gate and `approvals.json` are untouched, and no approval is recorded or implied. The whole behavior sits behind one constant, `LookRecolorPolicy.candidateMasksMayRecolorBakedParts` (`ios/PurgeQuest/Models/LookRecolor.swift`); set it to `false` and the legacy renderer shows the art as painted.

| Control | What it recolors | Stored as |
|---|---|---|
| Armor dye | `primary` and `secondary` of the **armor** layers of body, arms and legs (never the head or hands). The secondary keeps its original lightness offset from the primary, so two-tone outfits stay two-tone. | Derived at render time from `armorDye`; never stored, so saved heroes keep working. |
| Skin tone | The head's face window, the headgear layer's own `skin` mask, and hands whose anatomy layer *is* the baked image. | `materials.skin`, tagged `skin.<tone>`. "As painted" removes it. |
| Hair color | The head's `hair` region (Forest Ranger 1, Necromancer 1, Seer 3). | `materials.hair`, tagged `hair.<color>`. |

A stored Forge `custom` color always wins over the derived dye. The armor layers are pixel-identical to the baked parts, so their masks apply to the baked art directly. The face window is `anatomy skin mask x (1 - headgear alpha)`, plus the headgear skin mask; alpha alone would also pick up dark linework.

`LookCapabilities` (same file) reads the manifest and disables a control, with a stated reason, where it would change nothing: dye needs a `body` armor layer with `primary` or `secondary` (not Golem 1, Skeleton Warrior 3); hair needs a head `hair` region; skin needs a flesh paint whose face window is skin-colored (chroma >= 0.02, which excludes Dark Oracle 2 and 3's void faces, and all bone and stone bodies).

The planner applies the same availability rules as the UI, so a choice stored on another paint never recolors a paint whose control is disabled (Forge `custom` colors are not gated). Choosing "As painted" also restores the saved `skinTone` or `hairColor` to the race default, so a cleared swatch leaves no phantom customization.

Masks added for this: Seer 1's body, arms and legs are now armor layers (`overrides.json`), and Seer 3's head is authored into `hair` and `skin` (`semantic_regions.json`).

Before and after on Seer 1 to 3 (offline render with the same math): [`verification/look_recolor_seer.png`](verification/look_recolor_seer.png).

Known limits (all data, all candidate masks): Seer 2's chest pendant glow keeps a pale ring under dye; Seer 1's medallion and boots follow the dye; the Ebony tone makes Seer 3's ear and brow bands very dark; Blood Alchemist 1's goggle lenses take the skin tone; Valkyrie 3's and Forest Ranger 3's ears do not follow the skin tone. The eye-color swatch and the hue sliders are not part of this.

## Held gear model

Each item stores its grip (image px). Each pack stores the *hold* where its own baked weapon sits. `offset(s) = hold - s * (grip - pivotPx)` keeps the grip in the hand at any scale, so the Titan Blade (`HeldGearFit.titanScale = 2`) grows about the grip. The renderer unions the pack canvas with the item rect over every frame (hidden anchors included) so nothing clips; the view keeps the character's size and lets the blade overflow.

## Local Swift checks

`SWIFT_BIN=/path/to/swift tools/swift_harness/run.sh` compiles and runs the pure-Foundation suites on Linux (Swift 6.2). UIKit/SwiftUI code (`SpriteEngine`, Forge views) is compiled and tested only by Xcode/CI.

See [Gear visual views](gear-visual-views.md) for original/recolored texture comparisons of all 99 weapons and shields.

Held gear masks come from one of two algorithms, listed in `gear_algorithms.py`. Each gear item records which one made its masks (`verification.automated.materialMasks.algorithm`) and `validate.py` holds it to **that algorithm's own gate**, so neither is weakened by the other:

| | `chroma-cells-v5` (shipped, `DEFAULT_ALGORITHM`) | `authored-surfaces-v1` (PR #11) |
|---|---|---|
| Source | `gear_masks_chroma.py` | `gear_materials.py` + `semantic_regions.json` |
| Idea | derived from the sprite: lightness-independent colour clusters inside outline-bounded cells; same-hue shades and tints merge, so one material is one region | authored polygons per shield/staff set, aligned to the source outline; rims, bosses and inlays are separate regions |
| Line work | found from the sprite (strokes, the dark glow band along the edge, rings in the outline's own colour); exactly zero weight | "protected ink": the known ink and border-shadow colours; never recoloured |
| Dark fill | recoloured when it is clearly not the outline colour; the very darkest browns stay dark | very dark fill is protected |
| Gate | coverage of paintable area at least 0.80; zero weight on line work; no alpha leak; overlap at most 0.02 | coverage at least 0.80 of its own paintable area; zero weight on protected ink; same alpha/overlap limits |

To ship the other one: `python3 -I tools/modular_assets/held_gear.py --masks-only --algorithm authored-surfaces-v1`, then validate, test and regenerate the inventory. The tests in `GearMaterialRegression` check the authored algorithm on its own output; `ChromaCellsV5Assets` checks that the shipped masks regenerate pixel for pixel. See [gear recolor fixes](gear-recolor-fixes.md) (the authored pass) and [gear visual views](gear-visual-views.md) (the shipped masks).
