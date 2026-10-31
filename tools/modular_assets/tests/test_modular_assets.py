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
    """chroma-cells-v5: one outline-bounded cell is one material: shading splits merge, a different hue stays its own region."""

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
        import gear_masks_chroma as separate
        rgb, alpha, outline, labels = self._cell([(0.35, 0.22, 0.12), (0.62, 0.45, 0.25), (0.2, 0.35, 0.85)], [60, 25, 15])
        out = separate.merge_shading_splits(labels, rgb, alpha, outline, 3)
        self.assertTrue(np.all(out[:, 60:85] == 0), "tan highlight on brown cloth is shading")
        self.assertTrue(np.all(out[:, 85:] == 2), "a blue patch is a different material and stays separate")

    def test_light_and_dark_neutrals_in_one_cell_merge(self):
        import numpy as np
        import gear_masks_chroma as separate
        rgb, alpha, outline, labels = self._cell([(0.30, 0.30, 0.31), (0.62, 0.62, 0.63)], [70, 30])
        out = separate.merge_shading_splits(labels, rgb, alpha, outline, 2)
        self.assertTrue(np.all(out == 0))

    def test_cells_separated_by_outline_keep_their_own_labels(self):
        import numpy as np
        import gear_masks_chroma as separate
        rgb, alpha, outline, labels = self._cell([(0.35, 0.22, 0.12), (0.62, 0.45, 0.25)], [50, 50])
        outline[:, 49:51] = True          # linework splits it into two cells
        out = separate.merge_shading_splits(labels, rgb, alpha, outline, 2)
        self.assertTrue(np.all(out[:, :49] == 0) and np.all(out[:, 51:] == 1))


class GearRegions(unittest.TestCase):
    """chroma-cells-v5 regressions from shield recolors: a coloured arc above the silhouette, planks split by lightness, dark wood
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
        import gear_masks_chroma
        rgb, alpha = self._sprite()
        rgb[10:14, 10:80] = (0.23, 0.22, 0.21)            # dark-grey glow band along the very top edge
        out = gear_masks_chroma._outline_mask(rgb, alpha)
        self.assertTrue(out[16:32, 30:60].all(), "the thick top stroke must be outline, however thick")
        self.assertTrue(out[10:14, 20:70].all(), "the dark glow band at the edge must be outline")
        self.assertFalse(out[40:60, 30:60].any(), "the fill must not be outline")

    def test_dark_brown_fill_is_not_line_work(self):
        import numpy as np
        import gear_masks_chroma
        rgb, alpha = self._sprite()
        rgb[38:62, 30:50] = (0.25, 0.13, 0.10)            # very dark wood: dark, but clearly not the outline colour
        out = gear_masks_chroma._outline_mask(rgb, alpha)
        self.assertFalse(out[42:58, 34:46].any(), "dark brown planks are paintable fill")

    def test_hue_rule_merges_a_tint_but_not_a_neutral_or_another_hue(self):
        import numpy as np
        import gear_masks_chroma as separate
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
        from types import SimpleNamespace
        import imgops
        import gear_masks_chroma as separate
        rgb, alpha = self._sprite()
        # four planks of one wood, alternating light and dark, divided by outline-coloured seams
        shades = [(0.52, 0.33, 0.21), (0.36, 0.22, 0.14), (0.52, 0.33, 0.21), (0.36, 0.22, 0.14)]
        for i, c in enumerate(shades):
            rgb[34:76, 26 + i * 10: 34 + i * 10] = c
            rgb[34:76, 34 + i * 10: 36 + i * 10] = self.LINE
        rgb[12:24, 20:70] = (0.60, 0.61, 0.62)             # a steel rim above: neutral, a different material
        img = imgops.from_arrays(rgb, alpha)
        layer = SimpleNamespace(image=img)
        masks, _ = separate.RegionModel([layer]).masks(img)
        weights = {r: np.asarray(m, np.float32) / 255 for r, m in masks.items()}
        owner = [max(weights, key=lambda r: weights[r][50, 29 + i * 10]) for i in range(4)]
        self.assertEqual(len(set(owner)), 1, f"planks split across regions: {owner}")
        rim_owner = max(weights, key=lambda r: weights[r][17, 45])
        self.assertNotEqual(rim_owner, owner[0], "steel and wood are different materials")


class ChromaCellsV5Assets(unittest.TestCase):
    """The shipped gear masks are exactly what the algorithm recorded on each item produces, so they can be regenerated."""

    @classmethod
    def setUpClass(cls):
        import held_gear
        cls.items = json.loads(validate.GEAR.read_text())["items"]
        cls.sources = {i["resource"]: i["path"] for i in held_gear.build_items()}

    def test_every_item_records_an_algorithm_and_it_is_the_default(self):
        import gear_algorithms
        recorded = {i["verification"]["automated"]["materialMasks"]["algorithm"] for i in self.items}
        self.assertEqual(recorded, {gear_algorithms.DEFAULT_ALGORITHM},
                         "mixed or non-default shipped algorithms: regenerate with held_gear.py --masks-only")

    def test_sampled_shipped_masks_regenerate_pixel_for_pixel(self):
        import numpy as np
        from PIL import Image
        import gear_algorithms
        from separate import Layer, pool_tones
        index = {p.stem: p for p in scml.ART_ROOT.rglob("*.png")}
        for item in self.items[::4]:                 # every 4th item keeps this fast; validate.py gates all 99
            resource = item["resourceName"]
            algo = gear_algorithms.get(item["verification"]["automated"]["materialMasks"]["algorithm"])
            with Image.open(self.sources[resource]) as im:
                rgba = im.convert("RGBA")
            masks, protected = algo.masks_for(resource, rgba)
            self.assertEqual(sorted(masks), sorted(item["maskResources"]), resource)
            for region, mask in masks.items():
                with Image.open(index[item["maskResources"][region]]) as shipped:
                    self.assertTrue(np.array_equal(np.asarray(mask), np.asarray(shipped.convert("L"))), (resource, region))
            layer = Layer(resource, "armor", item["slot"], rgba, masks)
            pool_tones([layer])
            self.assertEqual(layer.region_tone, item["regionTone"], resource)
            self.assertTrue(algo.quality_passes(algo.quality(rgba, masks, protected)), resource)


class Inventory(unittest.TestCase):
    """Holds at any git depth (CI clones shallowly), so it asserts structure, not history."""

    @classmethod
    def setUpClass(cls):
        import inventory
        cls.inv = inventory.collect()
        cls.md = inventory.markdown(cls.inv)

    def test_lists_every_manifest_asset_once(self):
        races = json.loads(validate.RACES.read_text())["parts"]
        gear = json.loads(validate.GEAR.read_text())["items"]
        self.assertEqual(sorted(a["id"] for a in self.inv["parts"]), sorted(p["id"] for p in races))
        self.assertEqual(sorted(a["id"] for a in self.inv["gear"]), sorted(g["id"] for g in gear))
        for a in self.inv["gear"]:
            self.assertIn(f"`{a['id']}`", self.md)
        for pack in {a["pack"] for a in self.inv["parts"]}:
            self.assertIn(f"### {pack}", self.md)

    def test_set_versions_are_consecutive_and_hashes_are_content_hashes(self):
        import re
        versions = [s["version"] for s in self.inv["sets"]]
        self.assertEqual(versions, list(range(1, len(versions) + 1)))
        self.assertEqual(self.inv["setVersion"], versions[-1])
        for a in self.inv["parts"] + self.inv["gear"]:
            self.assertRegex(a["hash"], r"^[0-9a-f]{8}$")
            if a["lastChangedIn"] is None:
                self.assertEqual(a["revision"], 0)
            else:
                self.assertGreaterEqual(a["revision"], 1)
                self.assertLessEqual(a["lastChangedIn"], self.inv["setVersion"])

    def test_passes_are_named_and_every_stamp_names_a_known_pass(self):
        import inventory
        cfg = json.loads(inventory.ASSET_SETS.read_text())
        labels = [s["label"] for s in self.inv["sets"]]
        self.assertIn(cfg["current"], labels)
        self.assertEqual(self.inv["currentLabel"], cfg["current"])
        self.assertEqual(len(set(labels)), len(labels), "pass labels must be unique")
        for a in self.inv["parts"] + self.inv["gear"]:
            if a["lastChangedIn"] is not None:
                self.assertIn(a["lastChangedLabel"], labels, a["id"])

    def test_every_gear_item_names_the_algorithm_that_made_its_masks(self):
        import gear_algorithms
        for a in self.inv["gear"]:
            self.assertIn(a["maskAlgorithm"], gear_algorithms.ALGORITHMS, a["id"])

    def test_untouched_source_art_is_only_face_overlays(self):
        # held-gear and layer assets always have masks or layers in the modular set; only the baked face overlays are source art
        if len(self.inv["sets"]) < 2:
            self.skipTest("shallow git history: every asset reads as changed in the only set")
        for a in self.inv["parts"]:
            if a["lastChangedIn"] is None:
                self.assertEqual(a["kind"], "face", a["id"])


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



class GearMaterialRegression(unittest.TestCase):
    """authored-surfaces-v1 (PR #11) source-art regressions: one material across its painted light bands,
    dark wood remains editable, and drop shadows never become bright caps.

    These assert what *that algorithm* must produce, so they run on its own output, not on the shipped masks: the shipped
    gear may use another algorithm (see gear_algorithms.py; the shipped set is checked in ChromaCellsV5Assets and by
    validate.py, each against its own gate).
    """
    @classmethod
    def setUpClass(cls):
        import numpy as np
        from PIL import Image
        import gear_materials
        import held_gear
        from separate import Layer, pool_tones
        cls.np = np
        cls.items = json.loads(validate.GEAR.read_text())["items"]
        cls.by_resource = {i["resourceName"]: i for i in cls.items}
        sources = {i["resource"]: i["path"] for i in held_gear.build_items()}
        cls.images, cls.masks, cls.metrics, cls.tones = {}, {}, {}, {}
        for item in cls.items:
            resource = item["resourceName"]
            with Image.open(sources[resource]) as image:
                rgba = image.convert("RGBA")
            cls.images[resource] = np.array(rgba)
            produced, protected = gear_materials.masks_for(resource, rgba)
            cls.masks[resource] = {r: np.array(m, dtype=float) / 255 for r, m in produced.items()}
            cls.metrics[resource] = gear_materials.quality(rgba, produced, protected)
            layer = Layer(resource, "armor", item["slot"], rgba, produced)
            pool_tones([layer])
            cls.tones[resource] = layer.region_tone

    def assert_pigments_share_material(self, resource, region, pigments, box=None):
        image = self.images[resource]
        mask = self.masks[resource][region]
        for pigment in pigments:
            selected = (image[...,:3] == pigment).all(-1) & (image[...,3] > 250)
            if box:
                yy,xx = self.np.mgrid[:image.shape[0],:image.shape[1]]
                x0,y0,x1,y1 = box
                selected &= (xx>=x0)&(xx<x1)&(yy>=y0)&(yy<y1)
            self.assertGreater(selected.sum(),20,(resource,pigment))
            self.assertGreater(self.np.median(mask[selected]),.90,(resource,pigment,region))

    def test_dark_and_lit_wood_planks_share_primary(self):
        self.assert_pigments_share_material("shield_1_1","primary",[[73,58,39],[48,38,25],[117,93,62]])
        self.assert_pigments_share_material("shield_2_1","primary",[[71,45,38],[46,29,25],[114,72,61]])

    def test_verdant_coil_shaft_has_one_color_across_its_shading(self):
        self.assert_pigments_share_material("staff_2_2","secondary",[[115,89,70],[49,38,30],[86,67,52]],(10,0,220,128))
        self.assert_pigments_share_material("staff_2_2","primary",[[168,153,105],[233,229,184]])

    def test_tidecaller_reflected_light_is_part_of_the_crystal(self):
        self.assert_pigments_share_material("staff_3_1","primary",[[224,136,76],[247,225,133],[168,102,57]])

    def test_rim_highlights_and_shadows_share_one_material(self):
        self.assert_pigments_share_material("shield_3_3","secondary",[[127,118,99],[204,200,193]])
        self.assert_pigments_share_material("shield_4_3","secondary",[[199,199,197],[114,114,109]])
        self.assert_pigments_share_material("shield_4_4","secondary",[[90,96,90],[189,191,189]])

    def test_dark_signature_blade_is_recolorable(self):
        self.assert_pigments_share_material("necromancer_v1_sword","primary",[[42,50,53],[73,87,93]])

    def test_embossed_shield_does_not_invent_a_material_from_shine(self):
        self.assertEqual(set(self.masks["shield_8_5"]),{"primary"})

    def test_shield_boss_is_trim_instead_of_leather(self):
        for tier in [2,3,4,5]:
            masks = self.masks[f"shield_5_{tier}"]
            self.assertIn("trim",masks)
            self.assertNotIn("leather",masks)
            self.assertGreater(masks["trim"][80,80],.95)

    def test_all_gear_masks_preserve_ink_shadow_alpha_and_partition(self):
        from PIL import Image
        # Strong preferences must be safe too; the player is not limited to
        # the blue/red/gold review palette.
        colors = {"primary":(1.,1.,1.),"secondary":(.05,.8,.2),"trim":(.8,.1,.8),
                  "leather":(.8,.5,.1),"emissive":(.1,.8,1.)}
        selected_for_render = {"shield_2_1","shield_4_3","shield_4_4","staff_2_2","store_weapon_ruby"}
        for resource,masks in self.masks.items():
            image = self.images[resource]
            alpha = image[...,3].astype(float)/255
            total = sum(masks.values())
            self.assertEqual(float(total[alpha==0].max(initial=0)),0,resource)
            self.assertLessEqual(float((total-alpha).max()),.02,resource)
            self.assertLessEqual(float(total.max()),1.02,resource)
            # The two actual source ink palettes and the opaque border shadow.
            ink = self.np.zeros(alpha.shape,dtype=bool)
            for color in [(27,26,24),(20,18,14),(27,26,33),(58,55,53)]:
                ink |= (image[...,:3]==color).all(-1)&(alpha>0)
            self.assertEqual(float(total[ink].max(initial=0)),0,resource)
            metrics = self.metrics[resource]
            self.assertGreaterEqual(metrics["coverage"],.80,resource)
            self.assertEqual(metrics["protectedLeak"],0,resource)
            if resource in selected_for_render:
                rendered = self.np.asarray(qa.recolor(Image.fromarray(image),
                    {r:Image.fromarray(self.np.round(m*255).astype("uint8")) for r,m in masks.items()},
                    self.tones[resource], colors))
                self.np.testing.assert_array_equal(rendered[...,3],image[...,3])
                self.np.testing.assert_array_equal(rendered[ink],image[ink])


if __name__ == "__main__":
    unittest.main()
