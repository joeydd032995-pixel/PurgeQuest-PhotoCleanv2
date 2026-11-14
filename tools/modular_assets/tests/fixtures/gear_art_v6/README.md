# Gear art as bundled in asset pass v6

The 99 held and store gear sprites (40 staves, 40 shields, 11 store items, 8 signature weapons) exactly as they were
shipped before the v7 art swap. `authored-surfaces-v1` (`gear_materials.py`, PR #11) draws its material polygons against
this art, so `GearMaterialRegression` runs that algorithm on these files and not on the shipped sprites. The shipped
sprites are checked against the algorithm that made their masks (`ChromaCellsV5Assets` and `validate.py`).

Files are named by resource name (`staff_2_2.png`, `valkyrie_v1_sword.png`). Do not edit them.
