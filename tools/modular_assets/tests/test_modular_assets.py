"""Run: python3 -I -m unittest discover -s tools/modular_assets/tests -t tools/modular_assets"""
import json
import math
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
REPO = HERE.parents[2]

import approvals  # noqa: E402
import fit  # noqa: E402
import held_gear as hg  # noqa: E402
import pinning  # noqa: E402
import qa  # noqa: E402
import review_kit  # noqa: E402
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
            self.assertTrue(algo.quality_passes(algo.quality(rgba, masks, protected), resource), resource)

    def test_low_coverage_floors_are_exactly_the_items_that_need_them(self):
        """Every item holds to COVERAGE_MIN except the documented exceptions, and an exception must actually be needed
        (so the list cannot silently outlive the art that required it). Uses the coverage recorded in the manifest."""
        import gear_masks_chroma as chroma
        by_resource = {i["resourceName"]: i["verification"]["automated"]["materialMasks"]["coverage"] for i in self.items}
        self.assertLessEqual(set(chroma.LOW_COVERAGE_FLOORS), set(by_resource), "a floor names an unknown gear resource")
        for resource, coverage in by_resource.items():
            if resource in chroma.LOW_COVERAGE_FLOORS:
                self.assertLess(coverage, chroma.COVERAGE_MIN, f"{resource} reaches COVERAGE_MIN now: drop its floor")
                self.assertGreaterEqual(coverage, chroma.LOW_COVERAGE_FLOORS[resource], resource)
            else:
                self.assertGreaterEqual(coverage, chroma.COVERAGE_MIN, resource)


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

    def test_a_ledger_from_before_pinning_loads_and_verifies_nothing(self):
        # Schema 1 records carry no content hash, so there is nothing to tie them to the files as they are now.
        with Sandbox(["valkyrie_v1.head.anatomy"]) as box:
            box.ledger.write_text(json.dumps({"approvals": [
                {"assetId": "valkyrie_v1.head.anatomy", "profile": None, "reviewer": "T", "date": "x", "note": ""}]}))
            counts = approvals.apply()
            self.assertEqual(counts["verified"], 0)
            self.assertEqual(len(counts["stale"]), 1)
            self.assertIn("no content hash", counts["stale"][0])
            self.assertEqual(box.status_of("valkyrie_v1.head.anatomy"), "candidate")


class Sandbox:
    """Copies of the manifests, an empty ledger and the files of a few assets, with approvals/validate pointed at them.
    The real ledger, manifests and art are never written."""

    def __init__(self, asset_ids=(), packs=()):
        self.asset_ids, self.packs = set(asset_ids), set(packs)

    def __enter__(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.races, self.gear, self.ledger = self.tmp / "r.json", self.tmp / "g.json", self.tmp / "l.json"
        self.art = self.tmp / "Art"
        self.art.mkdir()
        shutil.copy(validate.RACES, self.races)
        shutil.copy(validate.GEAR, self.gear)
        self.ledger.write_text(json.dumps({"schemaVersion": 2, "approvals": []}))
        index = pinning.png_index()
        for entry in json.loads(self.races.read_text())["parts"] + json.loads(self.gear.read_text())["items"]:
            if entry["id"] in self.asset_ids or entry.get("pack") in self.packs:
                for path in pinning.asset_files(entry, index):
                    shutil.copy(path, self.art / path.name)
        self.saved = (approvals.RACES, approvals.GEAR, approvals.LEDGER, approvals.ART,
                      validate.RACES, validate.GEAR, validate.LEDGER, validate.ART)
        approvals.RACES, approvals.GEAR, approvals.LEDGER, approvals.ART = self.races, self.gear, self.ledger, self.art
        validate.RACES, validate.GEAR, validate.LEDGER, validate.ART = self.races, self.gear, self.ledger, self.art
        return self

    def __exit__(self, *exc):
        (approvals.RACES, approvals.GEAR, approvals.LEDGER, approvals.ART,
         validate.RACES, validate.GEAR, validate.LEDGER, validate.ART) = self.saved
        shutil.rmtree(self.tmp)

    def entry(self, asset_id):
        for path, key in ((self.races, "parts"), (self.gear, "items")):
            for e in json.loads(path.read_text())[key]:
                if e["id"] == asset_id:
                    return e
        raise KeyError(asset_id)

    def status_of(self, asset_id):
        return self.entry(asset_id)["verification"]["status"]

    def records(self):
        return json.loads(self.ledger.read_text())["approvals"]

    def edit(self, path, key, asset_id, change):
        manifest = json.loads(path.read_text())
        change(next(e for e in manifest[key] if e["id"] == asset_id))
        path.write_text(json.dumps(manifest))

    def flip_a_byte(self, asset_id):
        """Change one byte of the asset's image, as regenerating it would."""
        path = self.art / (self.entry(asset_id)["resourceBaseName"] + ".png")
        data = bytearray(path.read_bytes())
        data[-1] ^= 0xFF
        path.write_bytes(bytes(data))


class PinnedApprovals(unittest.TestCase):
    HEAD = "valkyrie_v1.head.anatomy"       # athletic native; adapts to slender, standard, skeletal, brute

    def test_a_fresh_approval_verifies_the_asset_and_pins_its_content(self):
        with Sandbox([self.HEAD]) as box:
            result = approvals.approve(f"id:{self.HEAD}", "Reviewer")
            self.assertEqual(result["added"], [self.HEAD])
            counts = approvals.apply()
            self.assertEqual((counts["verified"], counts["stale"]), (1, []))
            self.assertEqual(box.status_of(self.HEAD), "verified")
            self.assertEqual(box.entry(self.HEAD)["verification"]["approvedBy"], ["Reviewer"])
            record, = box.records()
            self.assertTrue(pinning.wellformed_hash(record["contentHash"]))
            self.assertEqual(record["contentHash"], pinning.content_hash(box.entry(self.HEAD), pinning.png_index(box.art)))
            self.assertEqual(validate.main(), 0)

    def test_changing_the_asset_strands_its_approval(self):
        with Sandbox([self.HEAD]) as box:
            approvals.approve(f"id:{self.HEAD}", "Reviewer")
            approvals.apply()
            box.flip_a_byte(self.HEAD)
            counts = approvals.apply()
            self.assertEqual(counts["verified"], 0)
            self.assertEqual(len(counts["stale"]), 1)
            self.assertIn("changed after approval", counts["stale"][0])
            self.assertEqual(box.status_of(self.HEAD), "candidate")
            self.assertEqual(len(box.records()), 1, "a stale record is history: it stays until revoked or replaced")
            self.assertEqual(validate.main(), 0, "a stale record is a warning once the manifest no longer says verified")

    def test_a_manifest_still_verified_on_a_stale_approval_fails_validation(self):
        with Sandbox([self.HEAD]) as box:
            approvals.approve(f"id:{self.HEAD}", "Reviewer")
            approvals.apply()
            self.assertEqual(validate.main(), 0)
            box.flip_a_byte(self.HEAD)          # regenerated, and nobody ran apply
            self.assertEqual(box.status_of(self.HEAD), "verified")
            self.assertEqual(validate.main(), 1)

    def test_approving_again_replaces_the_stale_record(self):
        with Sandbox([self.HEAD]) as box:
            approvals.approve(f"id:{self.HEAD}", "First")
            first = box.records()[0]["contentHash"]
            box.flip_a_byte(self.HEAD)
            result = approvals.approve(f"id:{self.HEAD}", "Second")
            self.assertEqual(result["replaced"], [self.HEAD])
            record, = box.records()
            self.assertEqual(record["reviewer"], "Second")
            self.assertNotEqual(record["contentHash"], first)
            self.assertEqual(approvals.apply()["verified"], 1)
            self.assertEqual(approvals.approve(f"id:{self.HEAD}", "Third")["alreadyApproved"], [self.HEAD])
            self.assertEqual(len(box.records()), 1)

    def test_a_fit_approval_goes_stale_when_the_fit_changes(self):
        with Sandbox([self.HEAD]) as box:
            approvals.approve(f"id:{self.HEAD}", "Reviewer")
            approvals.approve(f"id:{self.HEAD}", "Reviewer", profile="standard")
            approvals.apply()
            self.assertEqual(box.entry(self.HEAD)["verification"]["approvedProfiles"], ["standard"])

            def rescale(entry):
                entry["profileOverrides"]["standard"]["scaleX"] = 1.07
            box.edit(box.races, "parts", self.HEAD, rescale)
            counts = approvals.apply()
            self.assertEqual(len(counts["stale"]), 1)
            self.assertIn("standard fit", counts["stale"][0])
            after = box.entry(self.HEAD)["verification"]
            self.assertEqual(after["status"], "verified", "the pixels did not change, so the layer itself stays approved")
            self.assertEqual(after["approvedProfiles"], [])

    def test_a_fit_approval_counts_only_with_the_layer_and_only_where_the_layer_adapts(self):
        with Sandbox([self.HEAD]) as box:
            native = approvals.approve(f"id:{self.HEAD}", "Reviewer", profile="athletic")
            self.assertEqual((native["added"], native["notAdapted"]), ([], [self.HEAD]))
            approvals.approve(f"id:{self.HEAD}", "Reviewer", profile="standard")
            approvals.apply()
            alone = box.entry(self.HEAD)["verification"]
            self.assertEqual((alone["status"], alone["approvedProfiles"]), ("candidate", []))
            with self.assertRaises(SystemExit):
                approvals.approve(f"id:{self.HEAD}", "Reviewer", profile="giant")

    def test_an_asset_the_automated_checks_rejected_cannot_be_approved(self):
        with Sandbox([self.HEAD]) as box:
            def reject(entry):
                entry["verification"]["status"] = "mapped"
                entry["verification"]["automatedPass"] = False
            box.edit(box.races, "parts", self.HEAD, reject)
            result = approvals.approve(f"id:{self.HEAD}", "Reviewer")
            self.assertEqual(result["added"], [])
            self.assertEqual(len(result["refused"]), 1)
            self.assertEqual(box.records(), [])
            self.assertEqual(approvals.apply()["verified"], 0)

    def test_an_approval_needs_a_named_reviewer(self):
        with Sandbox([self.HEAD]) as box:
            for nobody in ("", "   "):
                with self.assertRaises(SystemExit):
                    approvals.approve(f"id:{self.HEAD}", nobody)
            self.assertEqual(box.records(), [])

    def test_revoking_removes_the_approval_its_fits_and_keeps_a_record(self):
        with Sandbox([self.HEAD]) as box:
            approvals.approve(f"id:{self.HEAD}", "Reviewer")
            approvals.approve(f"id:{self.HEAD}", "Reviewer", profile="standard")
            approvals.approve(f"id:{self.HEAD}", "Reviewer", profile="brute")
            only_fit = approvals.revoke(f"id:{self.HEAD}", "Reviewer", profile="brute")
            self.assertEqual([r["profile"] for r in only_fit], ["brute"])
            self.assertEqual(sorted(str(r["profile"]) for r in box.records()), ["None", "standard"])
            removed = approvals.revoke(f"id:{self.HEAD}", "Second", note="cheek mask")
            self.assertEqual(len(removed), 2)
            self.assertEqual(box.records(), [])
            self.assertEqual(approvals.apply()["verified"], 0)
            self.assertEqual(box.status_of(self.HEAD), "candidate")
            log = json.loads(box.ledger.read_text())["revocations"]
            self.assertEqual(len(log), 3)
            self.assertEqual((log[-1]["revokedBy"], log[-1]["approvedBy"], log[-1]["note"]), ("Second", "Reviewer", "cheek mask"))

    def test_a_whole_pack_renders_modular_only_when_every_layer_is_approved(self):
        with Sandbox(packs=["golem_v1"]) as box:
            before = approvals.status()["packs"]["golem_v1"]
            self.assertFalse(before["rendersModular"])
            approvals.approve("pack:golem_v1", "Reviewer")
            approvals.apply()
            after = approvals.status()
            self.assertTrue(after["packs"]["golem_v1"]["rendersModular"])
            self.assertEqual(after["packs"]["golem_v1"]["approved"], after["packs"]["golem_v1"]["layers"])
            self.assertEqual(after["totals"]["packsRenderingModular"], 1)
            # One layer short keeps the whole pack on the legacy renderer.
            approvals.revoke("id:golem_v1.body.anatomy", "Reviewer")
            self.assertFalse(approvals.status()["packs"]["golem_v1"]["rendersModular"])

    def test_a_target_that_is_an_id_and_a_prefix_is_refused(self):
        with Sandbox(["weapon.staff"]) as box:
            with self.assertRaises(SystemExit):
                approvals.approve("weapon.staff", "Reviewer")       # the Archmage Staff, and the start of 40 staves
            self.assertEqual(approvals.approve("id:weapon.staff", "Reviewer")["added"], ["weapon.staff"])
            self.assertEqual(len(box.records()), 1)
            with self.assertRaises(SystemExit):
                approvals.approve("pack:no_such_pack", "Reviewer")


class ReviewGuide(unittest.TestCase):
    def setUp(self):
        self.waves = json.loads((REPO / "docs" / "modular" / "review_waves.json").read_text())["waves"]
        self.races = json.loads(validate.RACES.read_text())
        self.gear = json.loads(validate.GEAR.read_text())

    def test_every_pack_is_in_exactly_one_pack_wave_and_every_gear_group_in_the_gear_wave(self):
        packs = [p for w in self.waves if w["kind"] == "packs" for p in w["packs"]]
        self.assertEqual(sorted(packs), sorted(self.races["packs"]))
        self.assertEqual(len(packs), len(set(packs)))
        groups = [g for w in self.waves if w["kind"] == "gear" for g in w["groups"]]
        self.assertEqual(sorted(groups), sorted({i["group"] for i in self.gear["items"]}))
        self.assertEqual(len(groups), len(set(groups)))

    def test_wave_one_covers_every_body_profile_with_a_pack_native_to_it(self):
        first = next(w for w in self.waves if w["id"] == 1)["packs"]
        native = {p["pack"]: set(p["nativeProfiles"]) for p in self.races["parts"] if p["part"] == "body" and p["kind"] == "anatomy"}
        covered = set().union(*(native[p] for p in first))
        self.assertEqual(covered, set(fit.PROFILES))
        self.assertTrue(all(p.endswith("_v1") for p in first))

    def test_status_counts_match_the_manifests(self):
        s = approvals.status()
        self.assertEqual(s["totals"]["assets"], len(self.races["parts"]) + len(self.gear["items"]))
        self.assertEqual(s["totals"]["packs"], len(self.races["packs"]))
        self.assertEqual(sum(p["layers"] for p in s["packs"].values()), len(self.races["parts"]))
        self.assertEqual(sum(g["items"] for g in s["gear"].values()), len(self.gear["items"]))
        stamped = sum(e["verification"]["status"] == "verified" for e in self.races["parts"] + self.gear["items"])
        self.assertEqual(s["totals"]["approved"], stamped, "the manifests' stamps and the ledger disagree: run approvals.py apply")

    def test_the_committed_guide_is_current_and_regenerates_byte_for_byte(self):
        guide = REPO / "docs" / "modular" / "REVIEW.md"
        committed = guide.read_bytes()
        review_kit.main()
        once = guide.read_bytes()
        review_kit.main()
        self.assertEqual(once, guide.read_bytes())
        self.assertEqual(committed, once, "docs/modular/REVIEW.md is out of date: run review_kit.py")

    def test_every_sheet_the_guide_links_to_exists(self):
        import re
        text = (REPO / "docs" / "modular" / "REVIEW.md").read_text()
        linked = set(re.findall(r"\]\(verification/([^)]+)\)", text))
        self.assertGreater(len(linked), 60)
        for name in linked:
            self.assertTrue((REPO / "docs" / "modular" / "verification" / name).exists(), name)
        for pack in self.races["packs"]:
            self.assertIn(f"approve pack:{pack} ", text)


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
    validate.py, each against its own gate). They also run on the art the algorithm was authored against, kept in
    tests/fixtures/gear_art_v6, not on the shipped sprites: its polygons and the exact pigments asserted below belong to
    the v6 sprites, which the v7 art swap replaced.
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
        fixtures = HERE / "fixtures" / "gear_art_v6"
        sources = {i["resource"]: fixtures / f"{i['resource']}.png" for i in held_gear.build_items()}
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


class WeaponInHand(unittest.TestCase):
    """A swapped-in weapon is held by the hero's own fist, in every pack.

    It used to be drawn on top of the whole character at the pack's hold point, so it floated in front of the body
    with no hand on it. The renderer now layers it the way each pack layers its own weapon (see scml.render_frame):
    in an attack the pack draws its sword at the very back, behind the hand, the arm and the body, and the swapped
    weapon takes that layer; in the idle pose the pack draws no sword and the fist hangs empty, so the weapon is drawn
    in front and the weapon hand is drawn again over its grip.
    """
    @classmethod
    def setUpClass(cls):
        import numpy as np
        from PIL import Image
        cls.np, cls.Image = np, Image
        cls.gear = json.loads(validate.GEAR.read_text())
        cls.packs = cls.gear["packs"]
        cls.items = {i["id"]: i for i in cls.gear["items"]}
        cls.sources = {i["id"]: i["path"] for i in hg.build_items()}
        cls.docs = {pid: scml.load_doc(*cls.split(pid)) for pid in cls.packs}

    @staticmethod
    def split(pid):
        race, variant = pid.rsplit("_v", 1)
        return race, int(variant)

    @staticmethod
    def weapon_of(frame):
        return next((p for p in frame if p.file.stem.startswith(("sword", "bow"))), None)

    def attack_animation(self, pid):
        doc = self.docs[pid]
        return "Shooting" if "Shooting" in doc.animations and self.packs[pid]["weaponAnchor"] == "bow" else "Slashing"

    def test_every_pack_names_the_hand_that_holds_its_weapon(self):
        for pid, pack in self.packs.items():
            race, variant = self.split(pid)
            self.assertEqual(pack["weaponHand"], hg.weapon_hand(race, variant), pid)
            self.assertEqual(pack["weaponHand"], "left_hand", pid)
            # ...and it is not the hand a shield goes in.
            self.assertNotEqual(pack["weaponHand"], pack["shieldAnchor"], pid)

    def test_idle_is_empty_handed_and_every_attack_frame_is_armed(self):
        for pid in self.packs:
            doc = self.docs[pid]
            self.assertTrue(all(self.weapon_of(f).alpha < 0.01 for f in doc.animations["Idle"]), f"{pid} Idle draws a sword")
            attack = self.attack_animation(pid)
            self.assertTrue(all(self.weapon_of(f).alpha >= 0.01 for f in doc.animations[attack]), f"{pid} {attack}")

    def test_the_packs_own_weapon_is_behind_the_hand_and_body_whenever_it_shows(self):
        armed = empty = 0
        for pid, pack in self.packs.items():
            for anim, frames in self.docs[pid].animations.items():
                for i, frame in enumerate(frames):
                    weapon = self.weapon_of(frame)
                    hand = next((p for p in frame if p.file.stem == pack["weaponHand"]), None)
                    body = next((p for p in frame if p.file.stem == "body"), None)
                    self.assertIsNotNone(weapon, (pid, anim, i))
                    if weapon.alpha >= 0.01:
                        armed += 1
                        self.assertLess(weapon.z, hand.z, (pid, anim, i))
                        self.assertLess(weapon.z, body.z, (pid, anim, i))
                    else:
                        empty += 1
                        self.assertIsNotNone(hand, (pid, anim, i))
                        self.assertGreaterEqual(hand.alpha, 0.01, (pid, anim, i))
        self.assertGreater(armed, 500)
        self.assertGreater(empty, 1000)

    def fist_center(self, pid, frame):
        """World position (y-up) of the middle of the weapon hand's opaque pixels."""
        np, Image = self.np, self.Image
        race, variant = self.split(pid)
        stem = self.packs[pid]["weaponHand"]
        with Image.open(scml.pack_dir(race, variant) / f"{pid}_{stem}.png") as img:
            solid = np.asarray(img.convert("RGBA"))[..., 3] > 250
            size = img.size
        ys, xs = np.nonzero(solid)
        u, v = float(xs.mean()), float(ys.mean())
        p = next(q for q in frame if q.file.stem == stem)
        lx = u * p.file.width / size[0] - p.pivot_x * p.file.width
        ly = (1 - p.pivot_y) * p.file.height - v * p.file.height / size[1]
        r = math.radians(p.angle)
        return (p.x + lx * math.cos(r) - ly * math.sin(r), p.y + lx * math.sin(r) + ly * math.cos(r))

    def hold_point(self, pid, frame):
        """World position (y-up) of the point the pack's weapon is gripped at (the hold), from the shipped manifest."""
        p = self.weapon_of(frame)
        hx, hy = self.packs[pid]["weaponHold"]
        r = math.radians(p.angle)
        lx, ly = hx, -hy
        return (p.x + lx * math.cos(r) - ly * math.sin(r), p.y + lx * math.sin(r) + ly * math.cos(r))

    def test_the_hold_point_is_inside_the_fist_in_every_idle_frame(self):
        for pid in self.packs:
            for i, frame in enumerate(self.docs[pid].animations["Idle"]):
                (fx, fy), (hx, hy) = self.fist_center(pid, frame), self.hold_point(pid, frame)
                self.assertLess(math.hypot(fx - hx, fy - hy), 40, f"{pid} Idle {i}: the grip is not in the fist")

    def render_idle(self, pid, item_id, weapon_hand=None):
        """Idle frame 0 with `item_id` swapped in, at the shipped hold and grip, on the canvas that fits it.
        Returns (image, canvas, frame). `weapon_hand` overrides the hand drawn over the grip."""
        race, variant = self.split(pid)
        doc, pack, item = self.docs[pid], self.packs[pid], self.items[item_id]
        img = self.Image.open(self.sources[item_id]).convert("RGBA")
        hold = {"weapon": {"hold": tuple(pack["weaponHold"]), "pivotPx": tuple(pack["weaponPivotPx"])}}
        carry = item.get("carryAngle")
        canvas = hg.canvas_with_item(doc, hold, item["kind"], img.size, tuple(item["gripPx"]), 1.0, carry_angle=carry)
        fit = hg.fit_for_anchor(hold["weapon"]["hold"], tuple(item["gripPx"]), hold["weapon"]["pivotPx"], 1.0, carry)
        out = scml.render_frame(doc, race, variant, "Idle", 0, canvas=canvas, scale=0.5, weapon_image=img, weapon_fit=fit,
                                weapon_hand=weapon_hand or pack["weaponHand"])
        return out, canvas, doc.animations["Idle"][0]

    def test_the_fist_is_drawn_over_the_weapons_grip_in_every_pack(self):
        np = self.np
        covered_without_the_fix = 0
        for pid, pack in self.packs.items():
            race, variant = self.split(pid)
            item_id = "weapon.shard"
            held, (origin, size), frame = self.render_idle(pid, item_id)
            # The same canvas with only the weapon hand drawn: what the fist looks like when nothing is on top of it.
            others = {p.file.stem for p in frame} - {pack["weaponHand"]}
            hand_only = scml.render_frame(self.docs[pid], race, variant, "Idle", 0, canvas=(origin, size), scale=0.5, hide=others)
            fx, fy = self.fist_center(pid, frame)
            px, py = round((fx - origin[0]) * 0.5), round((size[1] - (fy - origin[1])) * 0.5)
            got, want = np.asarray(held)[py, px].astype(int), np.asarray(hand_only)[py, px].astype(int)
            self.assertLessEqual(int(abs(got - want).max()), 3, f"{pid}: the fist is not on top of the weapon at its centre")
            # Control: leave the hand out of the redraw (the old behaviour) and the weapon covers the same pixel.
            old, _, _ = self.render_idle(pid, item_id, weapon_hand="no_such_hand")
            if int(abs(np.asarray(old)[py, px].astype(int) - want).max()) > 3:
                covered_without_the_fix += 1
        self.assertGreaterEqual(covered_without_the_fix, 10, "the check never catches a weapon pasted over the fist")


class CarryAngle(unittest.TestCase):
    """A weapon is never left pointing flat out from the hero's side (held_gear.CARRY_ANGLE).

    The packs draw the idle hand at hip height and hold the sword sideways through most of the swing, so a weapon left the
    way the art draws it sticks straight out from the pelvis, which reads as something it is not. A blade, staff or hammer
    that points between CARRY_FLOOR and CARRY_ANGLE is turned about its grip up to CARRY_ANGLE: up and away from the body.
    """
    @classmethod
    def setUpClass(cls):
        cls.gear = json.loads(validate.GEAR.read_text())
        cls.packs = cls.gear["packs"]
        cls.items = {i["id"]: i for i in cls.gear["items"]}
        cls.docs = {pid: scml.load_doc(pid.rsplit("_v", 1)[0], int(pid.rsplit("_v", 1)[1])) for pid in cls.packs}

    def sword_packs(self):
        return [pid for pid, p in self.packs.items() if p["weaponAnchor"] != "bow"]

    def test_constants_match_swift(self):
        swift = (Path(__file__).resolve().parents[3] / "ios/PurgeQuest/Models/HeldGearFit.swift").read_text()
        self.assertIn(f"static let carryAngle: Double = {hg.CARRY_ANGLE:g}", swift)
        self.assertIn(f"static let carryFloor: Double = {hg.CARRY_FLOOR:g}", swift)

    def test_carry_turn_table_matches_the_swift_tests(self):
        # The same table as ModularGearTests.aFlatBladeIsTurnedUpToTheCarryAngleAndNothingElseIs.
        for angle, turn in [(11.8, 33.2), (731.8, 33.2), (3, 42), (0, 45), (-44, 89)]:
            self.assertAlmostEqual(hg.carry_turn(angle, 45.0), turn, places=9, msg=angle)
        for angle in [45, 54, 63, 92, 116, 160, 180, -177, -46, -90]:
            self.assertEqual(hg.carry_turn(angle, 45.0), 0.0, angle)
        self.assertEqual(hg.carry_turn(10, None), 0.0)
        self.assertAlmostEqual(hg.norm_angle(731.8), 11.8, places=9)
        self.assertAlmostEqual(hg.norm_angle(648.1), -71.9, places=9)
        self.assertEqual(hg.norm_angle(-180), 180)
        self.assertEqual(hg.norm_angle(190), -170)

    def test_blades_staves_and_hammers_carry_and_bows_and_shields_do_not(self):
        for item in self.gear["items"]:
            if item["kind"] in hg.CARRIED_KINDS:
                self.assertEqual(item["carryAngle"], hg.CARRY_ANGLE, item["id"])
            else:
                self.assertNotIn("carryAngle", item, item["id"])
        self.assertEqual(sum("carryAngle" in i for i in self.gear["items"]), 14 + 41 + 1)

    def test_turning_about_the_grip_keeps_the_grip_on_the_hold(self):
        # Where the grip ends up in the world, with and without the turn, in every pack's idle and swing.
        def grip_world(anchor, hold, grip, pivot, s, turn):
            off = hg.local_offset(hold, grip, pivot, s, turn)
            gx, gy = s * (grip[0] - pivot[0]) + off[0], s * (grip[1] - pivot[1]) + off[1]   # local, y-down
            r = math.radians(anchor.angle + turn)
            sx, sy = gx * math.cos(r) + gy * math.sin(r), -gx * math.sin(r) + gy * math.cos(r)   # screen offset, y-down
            return anchor.x + sx, anchor.y - sy
        item = self.items["weapon.staff.1.1"]
        grip = tuple(item["gripPx"])
        for pid in self.sword_packs():
            pack = self.packs[pid]
            hold, pivot = tuple(pack["weaponHold"]), tuple(pack["weaponPivotPx"])
            for anim in ("Idle", "Slashing"):
                for frame in self.docs[pid].animations[anim]:
                    anchor = next(p for p in frame if p.file.stem.startswith("sword"))
                    for s in (1.0, 2.0):
                        turn = hg.carry_turn(anchor.angle, hg.CARRY_ANGLE)
                        x1, y1 = grip_world(anchor, hold, grip, pivot, s, 0.0)
                        x2, y2 = grip_world(anchor, hold, grip, pivot, s, turn)
                        self.assertAlmostEqual(x1, x2, places=6, msg=(pid, anim))
                        self.assertAlmostEqual(y1, y2, places=6, msg=(pid, anim))

    def test_no_frame_leaves_a_carried_weapon_pointing_flat_out_from_the_hero(self):
        turned = idle = 0
        for pid in self.sword_packs():
            for anim, frames in self.docs[pid].animations.items():
                for i, frame in enumerate(frames):
                    anchor = next(p for p in frame if p.file.stem.startswith("sword"))
                    pointing = hg.norm_angle(anchor.angle + hg.carry_turn(anchor.angle, hg.CARRY_ANGLE))
                    self.assertTrue(pointing < hg.CARRY_FLOOR or pointing >= hg.CARRY_ANGLE - 1e-9, (pid, anim, i, pointing))
                    turned += hg.carry_turn(anchor.angle, hg.CARRY_ANGLE) != 0
                    if anim == "Idle":
                        idle += 1
                        self.assertAlmostEqual(pointing, hg.CARRY_ANGLE, places=6, msg=(pid, i))
        self.assertGreater(idle, 90)
        self.assertGreater(turned, 1000)

    def test_the_wind_up_of_the_swing_is_left_alone(self):
        # The first three frames raise the sword behind and above the head; only the part that points flat is turned.
        for pid in self.sword_packs():
            for frame in self.docs[pid].animations["Slashing"][:3]:
                anchor = next(p for p in frame if p.file.stem.startswith("sword"))
                self.assertEqual(hg.carry_turn(anchor.angle, hg.CARRY_ANGLE), 0.0, pid)

    def test_the_canvas_holds_the_carried_weapon_in_every_frame(self):
        # canvas_with_item must contain every frame's rect, turned or not, or the carried blade would be clipped.
        item = self.items["weapon.staff"]
        grip, img_size = tuple(item["gripPx"]), (item["imageWidth"], item["imageHeight"])
        for pid in ("golem_v3", "valkyrie_v1", "seer_v2"):
            pack = self.packs[pid]
            hold = {"weapon": {"hold": tuple(pack["weaponHold"]), "pivotPx": tuple(pack["weaponPivotPx"])}}
            for s in (1.0, 2.0):
                (ox, oy), (w, h) = hg.canvas_with_item(self.docs[pid], hold, item["kind"], img_size, grip, s, carry_angle=hg.CARRY_ANGLE)
                fit = hg.fit_for_anchor(hold["weapon"]["hold"], grip, hold["weapon"]["pivotPx"], s, hg.CARRY_ANGLE)
                for frames in self.docs[pid].animations.values():
                    for frame in frames:
                        anchor = next(p for p in frame if p.file.stem.startswith("sword"))
                        f = fit(anchor)
                        for x, y in hg.item_rect_corners(anchor, img_size, f["offset"], s, f["rotation"]):
                            self.assertTrue(ox <= x <= ox + w and oy <= y <= oy + h, (pid, s, x, y))


class SheetArtImport(unittest.TestCase):
    """tools/modular_assets/import_sheet_art.py: the 99 v7 sprites are cut out of named tiles in the owner's photos."""

    @classmethod
    def setUpClass(cls):
        import import_sheet_art
        cls.isa = import_sheet_art
        cls.items = json.loads(validate.GEAR.read_text())["items"]

    def test_layouts_name_every_gear_item_and_nothing_else(self):
        named = [n for lay in self.isa.LAYOUTS for row in lay["rows"] for n in row]
        self.assertEqual(sorted(set(named)), sorted(i["name"] for i in self.items))
        for lay in self.isa.LAYOUTS:
            names = [n for row in lay["rows"] for n in row]
            self.assertEqual(len(names), len(set(names)), lay["key"])

    def test_every_photo_is_committed_and_its_tile_grid_matches_its_layout(self):
        import numpy as np
        from PIL import Image
        for lay in self.isa.LAYOUTS:
            path = self.isa.PHOTOS / lay["file"]
            self.assertTrue(path.exists(), path)
            im = self.isa.trim_black(np.asarray(Image.open(path).convert("RGB")).astype(np.float32))
            cols, rows = self.isa.detect_tiles(im, self.isa.tile_background(im))
            self.assertEqual((len(rows), len(cols)), (len(lay["rows"]), max(len(r) for r in lay["rows"])), lay["key"])

    def test_cut_out_keeps_the_drawing_and_drops_the_tile_colour(self):
        import numpy as np
        bg = np.array([45.0, 48.0, 60.0])
        tile = np.empty((60, 90, 3), np.float32)
        tile[:] = bg
        yy, xx = np.mgrid[:60, :90]
        r2 = (xx - 45) ** 2 + (yy - 30) ** 2
        tile[r2 <= 20 ** 2] = (200, 120, 60)             # the fill
        tile[(r2 <= 20 ** 2) & (r2 > 17 ** 2)] = (20, 18, 16)   # a thin dark outline
        cut = self.isa.cut_out(tile, bg)
        pad = 4
        alpha = cut[..., 3]
        self.assertEqual(int(alpha[30 + pad, 45 + pad]), 255)                       # the middle is solid
        self.assertEqual(int(alpha[0, 0]), 0)                                      # the tile colour is transparent
        self.assertEqual(int(alpha[pad + 2, pad + 2]), 0)
        self.assertEqual(cut[30 + pad, 45 + pad, :3].tolist(), [200, 120, 60])     # and keeps its exact colour
        self.assertTrue((cut[..., :3][alpha == 0] == 0).all())                     # no stray colour under transparency
        self.assertGreater(int(alpha[30 + pad, 45 + 18 + pad]), 200)               # the outline is part of the drawing

    def test_fit_into_aligns_weapons_by_the_pommel_and_centres_shields(self):
        import numpy as np
        cut = np.zeros((20, 100, 4), np.uint8)
        cut[..., :3] = (180, 40, 40)
        cut[..., 3] = 255                                # a long thin weapon, 5:1
        box = (30, 20, 330, 110)                         # the old art's box inside a 400 x 128 canvas
        left, scale = self.isa.fit_into(cut, (400, 128), box, align="left")
        self.assertEqual(left.size, (400, 128))
        self.assertAlmostEqual(scale, 3.0)
        bbox = left.getchannel("A").getbbox()
        self.assertEqual(bbox[0], 30)                    # the pommel end stays where the old sprite's was
        self.assertLessEqual(bbox[2], 330)               # and never leaves the old art's box
        centred, _ = self.isa.fit_into(cut, (400, 128), box, align="center")
        cb = centred.getchannel("A").getbbox()
        self.assertAlmostEqual((cb[1] + cb[3]) / 2, 65, delta=1.5)
        self.assertAlmostEqual((cb[0] + cb[2]) / 2, 180, delta=1.5)

    def test_weapons_align_left_and_shields_and_bows_centre(self):
        for item in self.items:
            expected = "center" if item["kind"] in ("shield", "bow") else "left"
            self.assertEqual(self.isa.align_for(item), expected, item["id"])


if __name__ == "__main__":
    unittest.main()
