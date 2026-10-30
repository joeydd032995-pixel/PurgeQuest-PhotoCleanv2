"""Generate modular race assets, masks, fit tables, QA sheets, and the races manifest.

Usage: python3 build_assets.py [--packs valkyrie_v1,seer_v2 ...] [--no-sheets]
Outputs:
  ios/PurgeQuest/Art/Modular/<race>/v<n>/*.png          layers + masks (bundled)
  ios/PurgeQuest/Art/Modular/modular_races_manifest.json (bundled)
  docs/modular/verification/<pack>_*.png                QA sheets (not bundled)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import fit as fitmod
import qa
import scml
import separate
from separate import Layer, PackSeparation

REPO = Path(__file__).resolve().parents[2]
OUT_ROOT = scml.ART_ROOT / "Modular"
SHEET_ROOT = REPO / "docs" / "modular" / "verification"
RACE_RAW = {  # art dir -> HeroRace raw value used by the Swift enum (rawValue of the case)
    "valkyrie": "valkyrie", "forest_ranger": "forest_ranger", "seer": "seer", "blood_alchemist": "blood_alchemist",
    "dark_oracle": "dark_oracle", "necromancer": "necromancer", "skeleton_crusader": "skeleton_crusader",
    "skeleton_warrior": "skeleton_crusader", "golem": "golem",
}
ATTACK_PREFERENCE = ("Shooting", "Slashing")
THRESH = {"mean": 5e-4, "bad": 2e-3, "coverage": 0.80}


def attack_name(race: str, variant: int = 1) -> str:
    """The pack's attack animation: Shooting when it ships one, else Slashing (Elven v3 has no Shooting)."""
    doc = scml.load_doc(race, variant)
    return next(n for n in ATTACK_PREFERENCE if n in doc.animations)


def layer_base(pid: str, layer: Layer) -> str:
    if layer.kind == "face":
        return f"{pid}_{layer.part}"
    return f"{pid}_{layer.part}_{layer.suffix}"


def emit(sep: PackSeparation) -> Dict[str, str]:
    """Write layer + mask PNGs. Returns {layerKey: resourceBaseName}."""
    out_dir = OUT_ROOT / sep.race_dir / f"v{sep.variant}"
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("*.png"):
        old.unlink()
    pid = sep.pid
    resources: Dict[str, str] = {}
    for layer in sep.layers + sep.faces:
        base = layer_base(pid, layer)
        original = scml.pack_dir(sep.race_dir, sep.variant) / f"{pid}_{layer.part}.png"
        reuse = layer.kind == "anatomy" and layer.image is not None and _same_as_original(layer, original)
        if layer.kind == "face":
            resources[f"{layer.part}:face"] = f"{pid}_{layer.part}"      # original resource
        elif reuse:
            resources[f"{layer.part}:{layer.kind}"] = f"{pid}_{layer.part}"
        else:
            layer.image.save(out_dir / f"{base}.png", optimize=True)
            resources[f"{layer.part}:{layer.kind}"] = base
        for region, mask in layer.masks.items():
            mask.save(out_dir / f"{base}_mask_{region}.png", optimize=True)
    return resources


def _same_as_original(layer: Layer, original: Path) -> bool:
    if not original.exists():
        return False
    import imgops as ops
    from PIL import Image
    a = np.asarray(layer.image.convert("RGBA"), np.int16)
    b = np.asarray(Image.open(original).convert("RGBA"), np.int16)
    return a.shape == b.shape and int(np.abs(a - b).max()) == 0


def mask_metrics(layer: Layer) -> Dict[str, float]:
    import imgops as ops
    rgb, alpha = ops.arrays(layer.image)
    outline = ops.outline_mask(rgb, alpha)
    body = (alpha > 0.5) & ~outline
    if not layer.masks or body.sum() == 0:
        return {"coverage": 0.0, "outlineLeak": 0.0, "overlap": 0.0}
    total = np.zeros(alpha.shape, np.float32)
    for m in layer.masks.values():
        total += np.asarray(m, np.float32) / 255.0
    return {
        "coverage": float(np.clip(total, 0, 1)[body].mean()),
        "outlineLeak": float(np.clip(total, 0, 1)[outline].mean()) if outline.sum() else 0.0,
        "overlap": float(np.clip(total - 1, 0, None)[body].mean()),
    }


def reassembly(sep: PackSeparation) -> Dict[str, Dict[str, float]]:
    doc = scml.load_doc(sep.race_dir, sep.variant)
    res = {}
    for anim in ("Idle", attack_name(sep.race_dir, sep.variant)):
        if anim not in doc.animations:
            continue
        n = len(doc.animations[anim])
        mx, mean, bad = qa.reassembly_error(sep, animations=(anim,), frames=tuple(range(n)))
        res[anim] = {"frames": n, "max": round(mx, 4), "mean": round(mean, 6), "bad": round(bad, 6)}
    return res


def profile_table(sep: PackSeparation) -> Dict[str, Dict[str, dict]]:
    ref = fitmod.RACE_DEFAULT_PROFILE[sep.race_dir]
    table: Dict[str, Dict[str, dict]] = {}
    for layer in sep.layers:
        row = {}
        for prof in fitmod.PROFILES:
            level, f = fitmod.compatibility(layer.slot, ref, prof)
            row[prof] = {"level": level, "scaleX": round(f[0], 4) if f else None, "scaleY": round(f[1], 4) if f else None}
        table[f"{layer.part}:{layer.kind}"] = row
    return table


def fit_provider(sep: PackSeparation, profile: str):
    ref = fitmod.RACE_DEFAULT_PROFILE[sep.race_dir]
    by_part: Dict[str, List[Layer]] = {}
    for l in sep.layers:
        by_part.setdefault(l.part, []).append(l)
    order = {"anatomy": 0, "armor": 1, "headgear": 1}

    def provide(p):
        if p.file.stem not in by_part:
            return None
        out = []
        for l in sorted(by_part[p.file.stem], key=lambda x: order[x.kind]):
            f = fitmod.fit(l.slot, ref, profile)
            out.append((l.image, f[0], f[1]) if f else (l.image, 1.0, 1.0))
        return out
    return provide


def sheets(sep: PackSeparation) -> None:
    SHEET_ROOT.mkdir(parents=True, exist_ok=True)
    doc = scml.load_doc(sep.race_dir, sep.variant)
    atk = attack_name(sep.race_dir, sep.variant)
    rows = []
    for anim, frame in (("Idle", 0), (atk, max(len(doc.animations[atk]) // 2, 0))):
        s = qa.render_set(sep, anim, frame, scale=0.3)
        s["recolor test"] = qa.recolor_set(sep, anim, frame, scale=0.3)
        ims = qa.crop_to_content(list(s.values()))
        rows.append([(f"{anim} {k}", i) for k, i in zip(s, ims)])
    qa.sheet(rows).convert("RGB").save(SHEET_ROOT / f"{sep.pid}_layers.png", optimize=True)
    # body-profile fit overlay: same frame under each profile
    ref = fitmod.RACE_DEFAULT_PROFILE[sep.race_dir]
    frames = []
    for prof in fitmod.PROFILES:
        sample = {l.slot: fitmod.compatibility(l.slot, ref, prof)[0] for l in sep.layers}
        unsupported = sorted(k for k, v in sample.items() if v == "unsupported")
        im = scml.render_frame(doc, sep.race_dir, sep.variant, "Idle", 0, provider=fit_provider(sep, prof),
                               scale=0.3, background=qa.BG)
        label = f"{prof}{' (ref)' if prof == ref else ''}" + (f" UNSUPPORTED x{len(unsupported)}" if unsupported else " ok")
        frames.append((label, im))
    ims = qa.crop_to_content([i for _, i in frames])
    qa.sheet([[(l, i) for (l, _), i in zip(frames, ims)]]).convert("RGB").save(SHEET_ROOT / f"{sep.pid}_fit.png", optimize=True)


def manifest_entries(sep: PackSeparation, resources: Dict[str, str], checks: dict) -> List[dict]:
    race_raw = RACE_RAW[sep.race_dir]
    ref = fitmod.RACE_DEFAULT_PROFILE[sep.race_dir]
    table = profile_table(sep)
    entries = []
    pass_pack = all(v["mean"] <= THRESH["mean"] and v["bad"] <= THRESH["bad"] for v in checks["reassembly"].values())
    for layer in sep.layers + sep.faces:
        key = f"{layer.part}:{layer.kind}"
        base = resources[key if layer.kind != "face" else f"{layer.part}:face"]
        mm = checks["masks"].get(key, {})
        ok = pass_pack and (layer.kind == "face" or mm.get("coverage", 1.0) >= THRESH["coverage"] or layer.kind == "anatomy")
        row = table.get(key, {})
        native = [p for p, v in row.items() if v["level"] == "native"]
        adapted = [p for p, v in row.items() if v["level"] == "adapted"]
        overrides = {p: {"scaleX": v["scaleX"], "scaleY": v["scaleY"], "offsetX": 0, "offsetY": 0}
                     for p, v in row.items() if v["level"] == "adapted"}
        entries.append({
            "id": f"{sep.pid}.{layer.part}.{layer.kind}",
            "resourceBaseName": base,
            "slot": layer.slot,
            "rigID": "humanoid_v1",
            "sourceRace": race_raw,
            "referenceProfile": ref,
            "nativeProfiles": native or ([ref] if layer.kind == "face" else []),
            "adaptedProfiles": adapted,
            "scaleXRange": {"min": 0.9, "max": 1.1},
            "scaleYRange": {"min": 0.9, "max": 1.1},
            "profileOverrides": overrides,
            "coverageTags": [layer.part, layer.kind],
            "materialRegions": sorted(layer.masks.keys()),
            "representation": "modular",
            "pack": sep.pid,
            "part": layer.part,
            "kind": layer.kind,
            "paintVariant": sep.variant,
            "maskResources": {r: f"{layer_base(sep.pid, layer)}_mask_{r}" for r in sorted(layer.masks)},
            "regionLuma": {r: round(v, 4) for r, v in layer.region_luma.items()},
            "verification": {
                "status": "candidate" if ok else "mapped",
                "automated": {"reassembly": checks["reassembly"], "masks": mm},
                "approvedBy": None,
            },
        })
    return entries


def build_pack(race: str, variant: int, with_sheets: bool = True) -> dict:
    sep = separate.separate_pack(race, variant)
    resources = emit(sep)
    checks = {"reassembly": reassembly(sep),
              "masks": {f"{l.part}:{l.kind}": {k: round(v, 4) for k, v in mask_metrics(l).items()}
                        for l in sep.layers if l.kind != "face"}}
    if with_sheets:
        sheets(sep)
    return {"pack": sep.pid, "notes": sep.notes, "windowFound": sep.window_found, "checks": checks,
            "entries": manifest_entries(sep, resources, checks)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--packs", default="")
    ap.add_argument("--no-sheets", action="store_true")
    args = ap.parse_args()
    wanted = set(filter(None, args.packs.split(",")))
    packs, entries, report = [], [], {}
    for race, v in scml.PACKS:
        pid = scml.pack_id(race, v)
        if wanted and pid not in wanted:
            continue
        res = build_pack(race, v, not args.no_sheets)
        print(pid, "window" if res["windowFound"] else "no-window",
              {k: (x["mean"], x["bad"]) for k, x in res["checks"]["reassembly"].items()}, flush=True)
        entries += res["entries"]
        report[pid] = {"notes": res["notes"], "checks": res["checks"]}
        packs.append(pid)
    if not wanted:
        manifest = {"schemaVersion": 1, "rigID": "humanoid_v1", "generatedBy": "tools/modular_assets/build_assets.py",
                    "packs": packs, "parts": entries}
        (OUT_ROOT / "modular_races_manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
        (REPO / "docs" / "modular").mkdir(parents=True, exist_ok=True)
        (REPO / "docs" / "modular" / "race_build_report.json").write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")
        print("manifest parts:", len(entries))


if __name__ == "__main__":
    main()
