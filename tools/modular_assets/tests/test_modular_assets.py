"""Run: python3 -I -m unittest discover -s tools/modular_assets/tests -t tools/modular_assets"""
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import approvals  # noqa: E402
import fit  # noqa: E402
import held_gear as hg  # noqa: E402
import qa  # noqa: E402
import scml  # noqa: E402
import validate  # noqa: E402


class FitParity(unittest.TestCase):
    def test_python_profiles_match_swift(self):
        swift = validate.swift_profiles()
        for name, vals in fit.PROFILES.items():
            self.assertEqual(swift.get(name), vals, name)

    def test_unsafe_scale_is_unsupported_not_clamped(self):
        # athletic arm thickness 1.08 -> slender 0.90 is 0.833, outside 0.90...1.10
        self.assertIsNone(fit.fit("leftArm", "athletic", "slender"))
        level, f = fit.compatibility("leftArm", "athletic", "standard")
        self.assertEqual(level, "adapted")
        self.assertAlmostEqual(f[0], 1.0 / 1.08, places=6)
        self.assertEqual(fit.compatibility("torso", "athletic", "athletic")[0], "native")


class RecolorReference(unittest.TestCase):
    """The same vectors are asserted by ModularGearTests.swiftRecolorMatchesThePythonReference."""

    def test_reference_vectors(self):
        import numpy as np
        import imgops
        tone, target = (0.55, 0.04), (0.15, 0.45, 0.85)
        cases = [((0.5, 0.5, 0.5), (0.386066, 0.523885, 0.72084), (0.443033, 0.511943, 0.61042)),
                 ((0.8, 0.2, 0.2), (0.007788, 0.448259, 0.933371), (0.403894, 0.32413, 0.566686)),
                 ((0.2, 0.35, 0.6), (0.006171, 0.351848, 0.743256), (0.103085, 0.350924, 0.671628)),
                 ((0.9, 0.9, 0.85), (0.862335, 0.918664, 0.999384), (0.881168, 0.909332, 0.924692))]
        for src, full, half in cases:
            a = imgops.recolor_pixels(np.array([src]), target, tone, np.array([1.0]))[0]
            b = imgops.recolor_pixels(np.array([src]), target, tone, np.array([0.5]))[0]
            self.assertTrue(np.allclose(a, full, atol=1e-5), (src, a, full))
            self.assertTrue(np.allclose(b, half, atol=1e-5), (src, b, half))

    def test_unmasked_untouched_and_shading_monotonic(self):
        import numpy as np
        import imgops
        grey = np.array([[v, v, v] for v in np.linspace(0.2, 0.9, 8)])
        out = imgops.recolor_pixels(grey, (0.15, 0.45, 0.85), (0.55, 0.04), np.ones(8))
        light = imgops.rgb_to_oklab(out)[:, 0]
        self.assertTrue(np.all(np.diff(light) > 0), "recolor must keep brighter pixels brighter")
        untouched = imgops.recolor_pixels(grey, (0.15, 0.45, 0.85), (0.55, 0.04), np.zeros(8))
        self.assertTrue(np.allclose(untouched, grey))

    def test_masks_stay_off_the_linework(self):
        races = json.loads(validate.RACES.read_text())
        for p in races["parts"]:
            leak = p["verification"]["automated"]["masks"].get("outlineLeak")
            if leak is not None:
                self.assertLessEqual(leak, 0.005, p["id"])


class CellMerging(unittest.TestCase):
    """One outline-bounded cell is one material: shading splits merge, a different hue stays its own region."""

    @staticmethod
    def _cell(colors, widths):
        import numpy as np
        h, w = 40, sum(widths)
        rgb = np.zeros((h, w, 3), np.float32)
        labels = np.zeros((h, w), np.int16)
        x = 0
        for i, (c, wd) in enumerate(zip(colors, widths)):
            rgb[:, x:x + wd] = c
            labels[:, x:x + wd] = i
            x += wd
        return rgb, np.ones((h, w), np.float32), np.zeros((h, w), bool), labels

    def test_highlight_of_the_same_hue_joins_the_cloth(self):
        import numpy as np
        import separate
        rgb, alpha, outline, labels = self._cell([(0.35, 0.22, 0.12), (0.62, 0.45, 0.25), (0.2, 0.35, 0.85)], [60, 25, 15])
        out = separate.merge_shading_splits(labels, rgb, alpha, outline, 3)
        self.assertTrue(np.all(out[:, 60:85] == 0), "tan highlight on brown cloth is shading")
        self.assertTrue(np.all(out[:, 85:] == 2), "a blue patch is a different material and stays separate")

    def test_light_and_dark_neutrals_in_one_cell_merge(self):
        import numpy as np
        import separate
        rgb, alpha, outline, labels = self._cell([(0.30, 0.30, 0.31), (0.62, 0.62, 0.63)], [70, 30])
        out = separate.merge_shading_splits(labels, rgb, alpha, outline, 2)
        self.assertTrue(np.all(out == 0))

    def test_cells_separated_by_outline_keep_their_own_labels(self):
        import numpy as np
        import separate
        rgb, alpha, outline, labels = self._cell([(0.35, 0.22, 0.12), (0.62, 0.45, 0.25)], [50, 50])
        outline[:, 49:51] = True          # linework splits it into two cells
        out = separate.merge_shading_splits(labels, rgb, alpha, outline, 2)
        self.assertTrue(np.all(out[:, :49] == 0) and np.all(out[:, 51:] == 1))


class GearRegions(unittest.TestCase):
    """Regressions from shield recolors: a coloured arc above the silhouette, planks split by lightness, dark wood
    treated as linework, one crystal split in two."""
    LINE = (0.11, 0.10, 0.09)

    @staticmethod
    def _sprite():
        import numpy as np
        rgb = np.zeros((90, 90, 3), np.float32)
        alpha = np.zeros((90, 90), np.float32)
        alpha[10:80, 10:80] = 1
        rgb[10:80, 10:80] = GearRegions.LINE
        rgb[34:66, 24:66] = (0.55, 0.35, 0.22)          # fill inside a 14px outline, with a doubled (24px) top stroke
        return rgb, alpha

    def test_thick_top_stroke_and_glow_band_are_line_work(self):
        import numpy as np
        import imgops
        rgb, alpha = self._sprite()
        rgb[10:14, 10:80] = (0.23, 0.22, 0.21)            # dark-grey glow band along the very top edge
        out = imgops.outline_mask(rgb, alpha)
        self.assertTrue(out[16:32, 30:60].all(), "the thick top stroke must be outline, however thick")
        self.assertTrue(out[10:14, 20:70].all(), "the dark glow band at the edge must be outline")
        self.assertFalse(out[40:60, 30:60].any(), "the fill must not be outline")

    def test_dark_brown_fill_is_not_line_work(self):
        import numpy as np
        import imgops
        rgb, alpha = self._sprite()
        rgb[38:62, 30:50] = (0.25, 0.13, 0.10)            # very dark wood: dark, but clearly not the outline colour
        out = imgops.outline_mask(rgb, alpha)
        self.assertFalse(out[42:58, 34:46].any(), "dark brown planks are paintable fill")

    def test_hue_rule_merges_a_tint_but_not_a_neutral_or_another_hue(self):
        import numpy as np
        import separate
        ang = lambda deg: (np.cos(np.radians(deg)), np.sin(np.radians(deg)))
        spec = [((-0.03, -0.13), -104, 0.11, 400), ((-0.02, -0.065), -112, 0.04, 400),   # blue and its pale tint
                ((0.0, 0.13), 90, 0.13, 300), ((0.0, 0.0), -120, 0.01, 300)]             # gold, grey
        centers = np.array([s[0] for s in spec])
        members = np.concatenate([[i] * s[3] for i, s in enumerate(spec)])
        units = np.concatenate([[ang(s[1])] * s[3] for s in spec])
        chroma = np.concatenate([[s[2]] * s[3] for s in spec])
        merged, out = separate._merge_close(centers, members, separate.MERGE_DISTANCE, units, chroma)
        self.assertEqual(len(merged), 3)
        self.assertEqual(out[0], out[400], "pale tint of the same hue joins its base")
        self.assertEqual(len({out[0], out[800], out[1100]}), 3, "gold and grey stay separate regions")

    def test_one_wood_in_light_and_dark_planks_is_one_region(self):
        import numpy as np
        from PIL import Image
        import imgops
        import separate
        rgb, alpha = self._sprite()
        # four planks of one wood, alternating light and dark, divided by outline-coloured seams
        shades = [(0.52, 0.33, 0.21), (0.36, 0.22, 0.14), (0.52, 0.33, 0.21), (0.36, 0.22, 0.14)]
        for i, c in enumerate(shades):
            rgb[34:76, 26 + i * 10: 34 + i * 10] = c
            rgb[34:76, 34 + i * 10: 36 + i * 10] = self.LINE
        rgb[12:24, 20:70] = (0.60, 0.61, 0.62)             # a steel rim above: neutral, a different material
        img = imgops.from_arrays(rgb, alpha)
        layer = separate.Layer("t", "armor", "mainHand", img)
        masks, _ = separate.RegionModel([layer]).masks(img)
        weights = {r: np.asarray(m, np.float32) / 255 for r, m in masks.items()}
        owner = [max(weights, key=lambda r: weights[r][50, 29 + i * 10]) for i in range(4)]
        self.assertEqual(len(set(owner)), 1, f"planks split across regions: {owner}")
        rim_owner = max(weights, key=lambda r: weights[r][17, 45])
        self.assertNotEqual(rim_owner, owner[0], "steel and wood are different materials")


class Rasterizer(unittest.TestCase):
    def test_valkyrie_frame_and_swapped_weapon(self):
        doc = scml.load_doc("valkyrie", 1)
        self.assertEqual({"Idle", "Slashing"} <= set(doc.animations), True)
        img = scml.render_frame(doc, "valkyrie", 1, "Idle", 0)
        self.assertGreater(img.getchannel("A").getbbox()[2], 50)
        # weapon override must differ from baked weapon
        sword = scml.load_png(scml.pack_dir("valkyrie", 1) / "valkyrie_v1_sword.png")
        a = scml.render_frame(doc, "valkyrie", 1, "Slashing", 5)
        b = scml.render_frame(doc, "valkyrie", 1, "Slashing", 5, weapon_image=sword, weapon_fit={"scale": 2.0, "offset": (0.0, 0.0)})
        self.assertNotEqual(a.tobytes(), b.tobytes())


class HeldGearMath(unittest.TestCase):
    def test_grip_stays_on_hold_at_any_scale(self):
        hold, grip, pivot = (52.1, 63.5), (44.6, 64.0), (0.0, 0.0)
        for s in (1.0, 1.5, 2.0):
            off = hg.local_offset(hold, grip, pivot, s)
            self.assertAlmostEqual(s * (grip[0] - pivot[0]) + off[0], hold[0])
            self.assertAlmostEqual(s * (grip[1] - pivot[1]) + off[1], hold[1])

    def test_titan_scale_constant(self):
        self.assertEqual(hg.TITAN_SCALE, 2.0)
        swift = (Path(__file__).resolve().parents[3] / "ios/PurgeQuest/Models/HeldGearFit.swift").read_text()
        self.assertIn("static let titanScale: Double = 2", swift)


class Manifests(unittest.TestCase):
    def setUp(self):
        self.races = json.loads(validate.RACES.read_text())
        self.gear = json.loads(validate.GEAR.read_text())

    def test_counts(self):
        self.assertEqual(len(self.gear["items"]), 8 + 80 + 11)
        self.assertEqual(len(self.races["packs"]), 27)
        self.assertGreater(len(self.races["parts"]), 400)

    def test_every_pack_has_all_eight_anatomy_slots(self):
        need = {"head", "torso", "leftArm", "rightArm", "leftHand", "rightHand", "leftLeg", "rightLeg"}
        for pack in self.races["packs"]:
            slots = {p["slot"] for p in self.races["parts"] if p["pack"] == pack and p["kind"] == "anatomy"}
            self.assertEqual(need, slots, pack)

    def test_reassembly_is_tight_everywhere(self):
        for p in self.races["parts"]:
            for anim, r in p["verification"]["automated"]["reassembly"].items():
                self.assertLessEqual(r["mean"], 5e-4, (p["id"], anim))

    def test_bow_is_not_supported_on_the_sword_pack(self):
        bow = next(i for i in self.gear["items"] if i["kind"] == "bow")
        self.assertEqual(set(bow["supportedPacks"]), {"forest_ranger_v1", "forest_ranger_v2"})

    def test_validator_passes_on_shipped_data(self):
        self.assertEqual(validate.main(), 0)


class ApprovalGate(unittest.TestCase):
    def test_verified_without_ledger_fails_validation(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            races, gear = tmp / "r.json", tmp / "g.json"
            r = json.loads(validate.RACES.read_text())
            r["parts"][0]["verification"]["status"] = "verified"
            races.write_text(json.dumps(r))
            shutil.copy(validate.GEAR, gear)
            ledger = tmp / "l.json"
            ledger.write_text(json.dumps({"approvals": []}))
            old = (validate.RACES, validate.GEAR, validate.LEDGER)
            validate.RACES, validate.GEAR, validate.LEDGER = races, gear, ledger
            try:
                self.assertEqual(validate.main(), 1)
            finally:
                validate.RACES, validate.GEAR, validate.LEDGER = old
        finally:
            shutil.rmtree(tmp)

    def test_apply_only_verifies_automated_passes_with_ledger(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            races, gear, ledger = tmp / "r.json", tmp / "g.json", tmp / "l.json"
            shutil.copy(validate.RACES, races)
            shutil.copy(validate.GEAR, gear)
            r = json.loads(races.read_text())
            target = r["parts"][0]["id"]
            ledger.write_text(json.dumps({"approvals": [{"assetId": target, "profile": None, "reviewer": "T", "date": "x", "note": ""}]}))
            old = (approvals.RACES, approvals.GEAR, approvals.LEDGER)
            approvals.RACES, approvals.GEAR, approvals.LEDGER = races, gear, ledger
            try:
                counts = approvals.apply()
                self.assertEqual(counts["verified"], 1)
                again = json.loads(races.read_text())
                self.assertEqual(again["parts"][0]["verification"]["status"], "verified")
                self.assertEqual(sum(p["verification"]["status"] == "verified" for p in again["parts"]), 1)
            finally:
                approvals.RACES, approvals.GEAR, approvals.LEDGER = old
        finally:
            shutil.rmtree(tmp)


if __name__ == "__main__":
    unittest.main()
