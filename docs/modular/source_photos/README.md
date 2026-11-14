# Source photos for the v7 weapon and shield art

The owner supplied the updated art for all 99 held and store gear items on 14 November 2026 as phone screenshots of review
sheets, and said that the art is their own. These are the photos the sprites were cut from; `tools/modular_assets/import_sheet_art.py`
reads them (see its docstring for how, and `docs/CREDITS.md` for the terms). A photo is a grid of named tiles; each tile
shows the original drawing on the left and a recoloured example on the right, and the tool uses the left one by default
(`--half right` uses the other).

| Photo | Shows |
|---|---|
| `staves_I_II.jpg` | Ashen Bough, Verdant Coil, Tidecaller, Ember Scepter, Storm Spire, Gilded Crook, tiers I and II |
| `staves_BoneVoid_I_II.jpg` | Bone Reliquary and Voidspike, tiers I and II |
| `staves_III_IV.jpg` | Ashen Bough to Bone Reliquary, tiers III and IV |
| `staves_III_IV_lower.jpg` | Ember Scepter to Voidspike, tiers III and IV (the widest drawing of an item in several photos wins) |
| `staves_IV_V.jpg` | all eight staff sets, tiers IV and V |
| `shields_I_II.jpg`, `shields_III_IV.jpg`, `shields_V.jpg` | all eight shield sets, tiers I and II, III and IV, V |
| `store.jpg` | the nine store weapons and the two named store shields |
| `signature.jpg` | the eight signature weapons |

Names come from the position of a tile in its photo (the order of the sheets they were taken from), which
`LAYOUTS` in the tool spells out and `SheetArtImport` in `tests/test_modular_assets.py` checks against the gear manifest.
A painterly Verdant Coil and Tidecaller photo the owner also sent is not here: it has no outlines and its tiles are too
small to cut out cleanly, so the two sets use the drawings in the photos above.

The photos are JPEG screenshots, so the sprites are upscaled (median about x1.4, up to x2.6 for the narrowest staff
crops) and a little softer than the artwork they replace. Better source images would give crisper sprites: put them in
this folder under the same names and run the tool again.
