"""Registry of gear material-mask algorithms.

Every gear item's manifest entry records which algorithm produced its masks (``verification.automated.materialMasks.algorithm``)
and ``validate.py`` checks the item against *that* algorithm's own gate, so each algorithm keeps the guarantees it was built for:

  authored-surfaces-v1   authored polygons per shield/staff set aligned to the source outline; protects very dark source ink
                         and border shadows (never recoloured). Asset pass "v4.1" (PR #11). ``gear_materials.py``.
  chroma-cells-v5        derived from the sprite itself (chromaticity clusters inside outline-bounded cells); dark wood and
                         other dark fill recolour, line work never does. Asset pass "v5" (PR #12). ``gear_masks_chroma.py``.

``DEFAULT_ALGORITHM`` is what ``held_gear.py`` regenerates with. Change it, or pass ``--algorithm NAME``, then run
``held_gear.py --masks-only`` to switch the shipped gear masks without touching any grip, fit, or catalog data.
"""
import gear_masks_chroma
import gear_materials

ALGORITHMS = {
    "authored-surfaces-v1": gear_materials,
    "chroma-cells-v5": gear_masks_chroma,
}
DEFAULT_ALGORITHM = "chroma-cells-v5"


def get(name: str):
    try:
        return ALGORITHMS[name]
    except KeyError:
        raise KeyError(f"unknown gear mask algorithm {name!r}; known: {', '.join(ALGORITHMS)}") from None
