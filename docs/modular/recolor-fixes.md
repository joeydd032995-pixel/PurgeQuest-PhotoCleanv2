# Recolor fixes for the three reported models

The fixes target the exact paints in the screenshots: **Lost Souls 1** (`necromancer_v1`), **Elven 1** (`forest_ranger_v1`), and **Seer 2** (`seer_v2`). Their original art, animation, ownership, and saved appearance schema are retained.

| Model | Corrected material boundaries | Review sheet |
|---|---|---|
| Lost Souls 1 | Hair has its own control; blue face, blush, neck, and bare hands stay skin. Dark sleeves remain recolorable cloth; chains and sleeve symbols use Trim. | [Idle and attack](verification/necromancer_v1_recolor.png) |
| Elven 1 | Hood, its highlights, shadows, and lining share Primary. The brown fringe uses Hair; the vest uses Secondary, cuffs/boots Leather, and fasteners Trim. Skin highlights stay skin. | [Idle and shooting](verification/forest_ranger_v1_recolor.png) |
| Seer 2 | Hood and tunic use Primary; the scarf uses Secondary, boots Leather, and hood runes Trim. Clothing colors leave the face and hands unchanged. | [Idle and attack](verification/seer_v2_recolor.png) |

The authored rules are in [`semantic_regions.json`](../../tools/modular_assets/semantic_regions.json). They replace ambiguous color clustering only for these three packs. Polygons constrain material areas; explicit source pigments protect face remnants, distinguish the hair fringe, and retain unoutlined runes. Dark outfit masks distinguish the packs' neutral ink from colored dark cloth, so a dark sleeve's fill can recolor without changing its outline. The generic pipeline remains available for other packs.

Soft material boundaries now blend each region from the **original** pixel in both Python and Swift. Previously, a region could recolor the previous region's output, changing shading twice and making dictionary order affect the result. Overlapping weights are normalized. Source alpha and unselected regions remain intact.

Regenerate the targeted assets and review sheets:

```sh
python3 -I tools/modular_assets/build_assets.py --packs necromancer_v1,forest_ranger_v1,seer_v2 --update-manifest
python3 -I tools/modular_assets/approvals.py apply
python3 -I tools/modular_assets/checklist.py
python3 -I tools/modular_assets/recolor_review.py
python3 -I tools/modular_assets/validate.py
python3 -W ignore::ResourceWarning -I tools/modular_assets/tests/test_modular_assets.py
```

`--update-manifest` merges selected packs into the existing manifest/report, preserving other packs. The new review sheets load the shipped images, masks, and tones, then show original, head-only, outfit-only, and combined colors at idle and a representative attack frame. No approval records are generated; existing production activation gates remain in force.

Regression coverage checks visible face pigments, bare hands, hood consistency, rune separation, dark sleeve coverage, ink exclusion, material blending order, and overlap normalization. The full asset validator also checks resources, mask sizes/alpha, fitting bounds, catalog invariants, and approval records. Native simulator/device rendering still requires the existing Xcode validation workflow and device review.
