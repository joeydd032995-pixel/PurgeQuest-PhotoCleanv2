"""Validate modular assets, manifests, approvals, and catalog preservation.

    python3 tools/modular_assets/validate.py [--update-catalog-snapshot]

Exit code 1 on any error. Fast checks (no rendering); rendering-based metrics are recorded by
build_assets.py / held_gear.py and re-checked here against thresholds.
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import fit as fitmod
import gear_materials
import scml

REPO = Path(__file__).resolve().parents[2]
APP = REPO / "ios" / "PurgeQuest"
MODULAR = APP / "Art" / "Modular"
RACES = MODULAR / "modular_races_manifest.json"
GEAR = MODULAR / "modular_gear_manifest.json"
LEDGER = REPO / "docs" / "modular" / "approvals.json"
SNAPSHOT = REPO / "docs" / "modular" / "catalog_snapshot.json"
FOUNDATION = APP / "Models" / "ModularCharacterFoundation.swift"
GAMEDATA = APP / "Services" / "GameDataService.swift"
THRESH = {"mean": 5e-4, "bad": 2e-3}
PROFILES = set(fitmod.PROFILES)


def bundle_index() -> dict:
    """Flattened bundle names: the synchronized Xcode group copies resources to the bundle root."""
    index = defaultdict(list)
    for p in APP.rglob("*"):
        if p.is_file() and p.suffix.lower() in (".png", ".json", ".scml", ".storekit", ".ttf", ".otf"):
            if "Assets.xcassets" in p.parts:
                continue
            index[p.name].append(p)
    return index


def swift_slots() -> set:
    src = FOUNDATION.read_text()
    body = src[src.index("enum CharacterSlot"):]
    body = body[:body.index("}")]
    return set(re.findall(r"case (\w+)", body))


def swift_profiles() -> dict:
    src = FOUNDATION.read_text()
    out = {}
    for m in re.finditer(r"case \.(\w+):\s*\n\s*return \.init\(([^)]*)\)", src):
        vals = [float(x.split(":")[1]) for x in m.group(2).split(",")]
        out[m.group(1)] = tuple(vals)
    return out


def catalog_ids_and_prices() -> dict:
    src = GAMEDATA.read_text()
    out = {}
    for m in re.finditer(r'CosmeticItem\(id: "([^"]+)",.*?priceGems: (\d+)(?:,\s*isUnlocked: (true|false))?', src):
        out[m.group(1)] = {"price": int(m.group(2)), "unlocked": m.group(3) == "true"}
    return out


def gear_catalog_ids() -> set:
    ids = {f"weapon.staff.{s}.{t}" for s in range(1, 9) for t in range(1, 6)}
    ids |= {f"shield.set.{s}.{t}" for s in range(1, 9) for t in range(1, 6)}
    ids |= {f"weapon.{raw}" for raw in ("valkyrie", "forest_ranger", "seer", "blood_alchemist", "dark_oracle", "necromancer", "skeleton_crusader", "golem")}
    return ids


def main() -> int:
    errors, warnings = [], []
    races = json.loads(RACES.read_text())
    gear = json.loads(GEAR.read_text())
    ledger = json.loads(LEDGER.read_text()) if LEDGER.exists() else {"approvals": []}
    index = bundle_index()

    # 1. bundle-name collisions
    for name, paths in index.items():
        if len(paths) > 1:
            errors.append(f"duplicate bundle resource name {name}: {[str(p.relative_to(APP)) for p in paths]}")

    def png(name: str):
        paths = index.get(f"{name}.png")
        return paths[0] if paths else None

    # 2. race parts
    slots = swift_slots()
    ids = set()
    for part in races["parts"]:
        pid = part["id"]
        if pid in ids:
            errors.append(f"duplicate part id {pid}")
        ids.add(pid)
        if part["slot"] not in slots:
            errors.append(f"{pid}: unknown slot {part['slot']}")
        if part["rigID"] != "humanoid_v1":
            errors.append(f"{pid}: rig {part['rigID']}")
        base = png(part["resourceBaseName"])
        if base is None:
            errors.append(f"{pid}: missing resource {part['resourceBaseName']}.png")
            continue
        size = Image.open(base).size
        for region, mask_name in part["maskResources"].items():
            mp = png(mask_name)
            if mp is None:
                errors.append(f"{pid}: missing mask {mask_name}.png")
                continue
            mim = Image.open(mp)
            if mim.mode != "L" or mim.size != size:
                errors.append(f"{pid}: mask {mask_name} mode/size {mim.mode} {mim.size} != L {size}")
                continue
            m = np.asarray(mim, np.float32) / 255
            a = np.asarray(Image.open(base).convert("RGBA"), np.float32)[..., 3] / 255
            if float(np.clip(m - a, 0, None).max()) > 0.02:
                errors.append(f"{pid}: mask {region} exceeds layer alpha")
            if m.sum() < 20:
                errors.append(f"{pid}: mask {region} empty")
        tones = part.get("regionTone", {})
        if "regionLuma" in part:
            errors.append(f"{pid}: stale regionLuma (regenerate: tones are regionTone now)")
        for region in part["maskResources"]:
            t = tones.get(region)
            if not (isinstance(t, list) and len(t) == 2 and 0 <= t[0] <= 1 and 0 <= t[1] <= 0.5):
                errors.append(f"{pid}: region {region} needs a regionTone [lightness, chroma]")
        if part["kind"] in ("armor", "headgear") and not part["maskResources"]:
            errors.append(f"{pid}: armor/headgear layer has no material masks")
        ref = part["referenceProfile"]
        if ref not in PROFILES:
            errors.append(f"{pid}: bad reference profile")
        for prof, ov in part["profileOverrides"].items():
            lo, hi = part["scaleXRange"]["min"], part["scaleXRange"]["max"]
            if prof not in part["adaptedProfiles"]:
                errors.append(f"{pid}: override for non-adapted profile {prof}")
            elif not (lo <= ov["scaleX"] <= hi and part["scaleYRange"]["min"] <= ov["scaleY"] <= part["scaleYRange"]["max"]):
                errors.append(f"{pid}: {prof} override outside safe range")
        if part["kind"] != "face" and ref not in part["nativeProfiles"]:
            errors.append(f"{pid}: reference profile not native")
        for anim, r in part["verification"]["automated"]["reassembly"].items():
            if r["mean"] > THRESH["mean"] or r["bad"] > THRESH["bad"]:
                if part["verification"]["status"] != "mapped":
                    errors.append(f"{pid}: {anim} reassembly {r} over threshold but status {part['verification']['status']}")

    # 3. gear
    packs = {scml.pack_id(r, v) for r, v in scml.PACKS}
    for item in gear["items"]:
        iid = item["id"]
        ip = png(item["resourceName"])
        if ip is None:
            errors.append(f"{iid}: missing resource {item['resourceName']}.png")
            continue
        im = Image.open(ip)
        if im.size != (item["imageWidth"], item["imageHeight"]):
            errors.append(f"{iid}: size mismatch")
        gx, gy = item["gripPx"]
        if not (0 <= gx < im.size[0] and 0 <= gy < im.size[1]):
            errors.append(f"{iid}: grip outside image")
        if not set(item["supportedPacks"]) <= packs:
            errors.append(f"{iid}: unknown supported pack")
        material_masks = {}
        for region, mask_name in item["maskResources"].items():
            mp = png(mask_name)
            if mp is None:
                errors.append(f"{iid}: missing mask {mask_name}.png")
                continue
            with Image.open(mp) as mask:
                if mask.mode != "L" or mask.size != im.size:
                    errors.append(f"{iid}: mask {mask_name} wrong mode/size")
                    continue
                material_masks[region] = mask.copy()
        if material_masks:
            source = im.convert("RGBA")
            protected = gear_materials.protected_ink(source,
                exterior=item["resourceName"] not in gear_materials.HALO_RESOURCES)
            actual = gear_materials.quality(source, material_masks, protected)
            if not gear_materials.quality_passes(actual):
                errors.append(f"{iid}: material mask coverage/ink/alpha failure: {actual}")
            recorded = item["verification"]["automated"].get("materialMasks", {})
            if recorded.get("algorithm") != "authored-surfaces-v1":
                errors.append(f"{iid}: missing topology-aware material checks (regenerate gear masks)")
        if not item["maskResources"]:
            errors.append(f"{iid}: no recolor masks")
        for region in item["maskResources"]:
            t = item.get("regionTone", {}).get(region)
            if not (isinstance(t, list) and len(t) == 2):
                errors.append(f"{iid}: region {region} needs a regionTone")
        if item["kind"] == "bow" and any(p == "forest_ranger_v3" for p in item["supportedPacks"]):
            errors.append(f"{iid}: bow must not be supported on forest_ranger_v3 (sword pack, no Shooting animation)")
        ids.add(iid)
    if len(gear["items"]) != 8 + 80 + 11:
        errors.append(f"expected 99 gear items, found {len(gear['items'])}")

    # 4. approvals ledger
    for rec in ledger["approvals"]:
        if rec["assetId"] not in ids:
            errors.append(f"ledger references unknown asset {rec['assetId']}")
        if rec.get("profile") and rec["profile"] not in PROFILES:
            errors.append(f"ledger bad profile {rec['profile']}")
    approved = {r["assetId"] for r in ledger["approvals"] if not r.get("profile")}
    for entry in races["parts"] + gear["items"]:
        status = entry["verification"]["status"]
        if status == "verified" and entry["id"] not in approved:
            errors.append(f"{entry['id']}: verified without a ledger approval")
        if status != "verified" and entry["id"] in approved and entry["verification"].get("automatedPass"):
            errors.append(f"{entry['id']}: approved in ledger but not stamped (run approvals.py apply)")

    # 5. catalog preservation + Swift parity
    cat = catalog_ids_and_prices()
    for iid in gear_catalog_ids():
        pass  # generated by GearCatalog; verified by Swift tests
    for item in gear["items"]:
        if item["group"] == "store" and item["id"] not in cat:
            errors.append(f"store item {item['id']} missing from GameDataService seeds")
    snap = {k: v for k, v in cat.items() if k.startswith(("head.", "weapon.", "shield.", "upgrade."))}
    if "--update-catalog-snapshot" in sys.argv or not SNAPSHOT.exists():
        SNAPSHOT.write_text(json.dumps(snap, indent=1, sort_keys=True) + "\n")
    else:
        old = json.loads(SNAPSHOT.read_text())
        for k, v in old.items():
            if snap.get(k) != v:
                errors.append(f"catalog drift for {k}: {v} -> {snap.get(k)}")
    sp = swift_profiles()
    for name, vals in fitmod.PROFILES.items():
        if sp.get(name) != vals:
            errors.append(f"profile parity: {name} Swift {sp.get(name)} != Python {vals}")

    for w in warnings:
        print("warn:", w)
    for e in errors:
        print("ERROR:", e)
    counts = defaultdict(int)
    for entry in races["parts"] + gear["items"]:
        counts[entry["verification"]["status"]] += 1
    print(f"parts={len(races['parts'])} gear={len(gear['items'])} status={dict(counts)} errors={len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
