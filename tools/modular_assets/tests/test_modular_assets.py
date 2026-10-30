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
        self.assertEqual(len(self.gear["items"]), 8 + 80 + 14)
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
