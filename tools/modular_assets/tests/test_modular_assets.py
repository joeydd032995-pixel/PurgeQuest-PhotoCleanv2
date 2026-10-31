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


class RecolorMaterials(unittest.TestCase):
    def test_soft_boundaries_sample_original_shading_and_ignore_region_order(self):
        import numpy as np
        import imgops as ops
        rgb = np.array([[[0.4, 0.3, 0.2], [0.7, 0.6, 0.5]]])
        masks = {"primary": np.array([[153, 0]], dtype=np.uint8),
                 "trim": np.array([[102, 0]], dtype=np.uint8)}
        colors = {"primary": (0.8, 0.1, 0.1), "trim": (0.1, 0.3, 0.8)}
        tones = {"primary": [0.5, 0.1], "trim": [0.4, 0.1]}
        forward = ops.recolor_materials(rgb, masks, tones, colors)
        backward = ops.recolor_materials(rgb, masks, tones, dict(reversed(list(colors.items()))))
        np.testing.assert_allclose(forward, backward, atol=1e-12)
        red = ops.recolor_pixels(rgb, colors["primary"], tones["primary"], np.ones((1, 2)))
        blue = ops.recolor_pixels(rgb, colors["trim"], tones["trim"], np.ones((1, 2)))
        np.testing.assert_allclose(forward[0, 0], red[0, 0] * .6 + blue[0, 0] * .4)
        np.testing.assert_array_equal(forward[0, 1], rgb[0, 1])

    def test_overlapping_masks_normalize_instead_of_oversaturating(self):
        import numpy as np
        import imgops as ops
        rgb = np.array([[[0.4, 0.3, 0.2]]])
        masks = {r: np.array([[255]], dtype=np.uint8) for r in ["primary", "trim"]}
        colors = {"primary": (0.8, 0.1, 0.1), "trim": (0.1, 0.3, 0.8)}
        out = ops.recolor_materials(rgb, masks, {}, colors)
        expected = sum(ops.recolor_pixels(rgb, c, [0.6, 0.1], np.ones((1, 1))) for c in colors.values()) / 2
        np.testing.assert_allclose(out, expected)


class ReportedModelMasks(unittest.TestCase):
    def setUp(self):
        import numpy as np
        self.np = np
        self.parts = json.loads(validate.RACES.read_text())["parts"]
        self.by_id = {p["id"]: p for p in self.parts}
        self.resources = {p.stem: p for p in scml.ART_ROOT.rglob("*.png")}

    def masks(self, part_id):
        from PIL import Image
        return {r: self.np.asarray(Image.open(self.resources[name]), dtype=float) / 255
                for r, name in self.by_id[part_id]["maskResources"].items()}

    def test_lost_souls_hands_are_skin_and_hair_has_its_own_region(self):
        head = self.masks("necromancer_v1.head.headgear")
        self.assertIn("hair", head)
        self.assertGreater(head["hair"][100, 180], .9)
        for hand in ["left_hand", "right_hand"]:
            part = self.by_id[f"necromancer_v1.{hand}.anatomy"]
            self.assertEqual(part["materialRegions"], ["skin"])
            self.assertNotIn(f"necromancer_v1.{hand}.armor", self.by_id)

    def test_clothing_colors_leave_visible_face_pigments_unchanged(self):
        from PIL import Image
        colors = {"hair": (.8, .1, .1), "primary": (.1, .5, .9), "secondary": (.9, .7, .1), "trim": (.8, .6, .1)}
        import qa
        cases = {"necromancer_v1": [[85,132,159], [76,116,139], [232,163,163]],
                 "forest_ranger_v1": [[239,183,125], [179,137,94], [245,212,175]],
                 "seer_v2": [[184,121,58], [138,91,43], [212,169,81]]}
        for pid, pigments in cases.items():
            checked = 0
            for kind in ["anatomy", "headgear"]:
                part = self.by_id[f"{pid}.head.{kind}"]
                image = Image.open(self.resources[part["resourceBaseName"]]).convert("RGBA")
                source = self.np.asarray(image)
                visible = source[..., 3] > 200
                skin = self.np.zeros(visible.shape, dtype=bool)
                for pigment in pigments:
                    skin |= (source[..., :3] == pigment).all(-1)
                selected = visible & skin
                checked += int(selected.sum())
                if not selected.any():
                    continue
                recolored = self.np.asarray(qa.recolor(image,
                    {r: Image.open(self.resources[name]) for r, name in part["maskResources"].items()},
                    part["regionTone"], colors))
                self.assertLessEqual(self.np.abs(recolored.astype(int) - source.astype(int))[selected].max(), 1, (pid, kind))
            self.assertGreater(checked, 100, pid)

    def test_elven_hood_highlight_shadow_and_lining_share_primary(self):
        head = self.masks("forest_ranger_v1.head.headgear")
        for x, y in [(300, 200), (158, 350), (485, 425)]:
            self.assertGreater(head["primary"][y, x], .8, (x, y))
        self.assertIn("hair", head)

    def test_dark_sleeves_are_recolorable_and_ink_stays_untouched(self):
        from PIL import Image
        for pid in ["necromancer_v1", "forest_ranger_v1", "seer_v2"]:
            masks = self.masks(f"{pid}.left_arm.armor")
            cloth = "secondary" if pid == "necromancer_v1" else "primary"
            self.assertGreater(masks[cloth][55, 60], .8, pid)
            for part in [p for p in self.parts if p["pack"] == pid and p["kind"] in ["armor", "headgear"]]:
                source = self.np.asarray(Image.open(self.resources[part["resourceBaseName"]]).convert("RGBA"))
                ink = (source[..., :3] == [27, 26, 24]).all(-1) & (source[..., 3] > 200)
                if ink.any():
                    total = sum(self.masks(part["id"]).values())
                    self.assertEqual(total[ink].max(), 0, part["id"])

    def test_seer_runes_use_trim_and_cloth_uses_primary(self):
        head = self.masks("seer_v2.head.headgear")
        self.assertGreater(head["primary"][100, 200], .9)
        self.assertGreater(head["trim"][166, 245], .8)



if __name__ == "__main__":
    unittest.main()
