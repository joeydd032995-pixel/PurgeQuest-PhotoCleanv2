"""Asset inventory: every modular asset with a set version, a per-asset revision, a content hash and attention flags.

    python3 -I tools/modular_assets/inventory.py                 # docs/modular/ASSET_INVENTORY.md + asset_inventory.json
    python3 -I tools/modular_assets/inventory.py --sheets DIR    # also contact sheets (PNG per pack/gear group) + one PDF

Versions come from git, so they are real and cannot drift from the files:
  * set version  vN  = the Nth commit that changed the shipped modular art (in history order). The newest is the set the
                       app bundles; "+wip" means the working tree has art changes that are not committed yet.
  * revision     rK  = how many of those commits changed *this* asset's files; "last changed in vN" says which.
  * hash         #xxxxxxxx = first 8 hex of the SHA-256 of the asset's image + mask bytes; it differs between two sets
                       exactly when the pixels differ, so two renders carrying the same hash are the same asset.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

import imgops as ops  # noqa: E402

REPO = HERE.parent.parent
ART = REPO / "ios" / "PurgeQuest" / "Art"
RACES = ART / "Modular" / "modular_races_manifest.json"
GEAR = ART / "Modular" / "modular_gear_manifest.json"
ART_PATHS = ["ios/PurgeQuest/Art/Modular", "ios/PurgeQuest/Art/Gear/store"]
DOCS = REPO / "docs" / "modular"

# Things a reviewer should know about specific assets (found by looking at the renders; not computed).
KNOWN_ISSUES = [
    (r"^golem_v\d\.(head|body)\.anatomy$", "anatomy-only stone: recolours through the single skin region, with no primary/secondary/trim"),
    (r"^skeleton_crusader_v\d\.head\.headgear", "the helm band shares the helm's hue, so it recolours with the helm (not separate)"),
    (r"^valkyrie_v\d\.head\.headgear", "right cheek guard stays near-black; right-cheek blush recolours cream while the left stays pink"),
    (r"^Bone Paragon V$", "a small separate region inside the dark centre emblem"),
    (r"^Verdigris Sigil (III|IV)$", "inner emblem stays dark (close to the outline colour)"),
]
LOUD = {"primary": (0.86, 0.14, 0.14), "secondary": (0.14, 0.70, 0.26), "trim": (0.20, 0.36, 0.95),
        "leather": (0.95, 0.82, 0.18), "emissive": (1.0, 1.0, 1.0), "skin": (0.62, 0.34, 0.80),
        "hair": (1.0, 0.5, 0.0), "eyes": (0.1, 0.9, 0.9)}


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, text=True, check=False).stdout


# ---------------------------------------------------------------- versions

def set_history() -> List[dict]:
    """Commits that changed the shipped art, oldest first, each with the files it touched."""
    out = git("log", "--reverse", "--format=@@%H|%h|%ad|%s", "--date=short", "--name-only", "--", *ART_PATHS)
    sets: List[dict] = []
    for line in out.splitlines():
        if line.startswith("@@"):
            full, short, date, subject = line[2:].split("|", 3)
            sets.append({"commit": full, "short": short, "date": date, "subject": subject, "files": set()})
        elif line.strip() and sets:
            sets[-1]["files"].add(line.strip())
    sets = [s for s in sets if s["files"]]
    if not sets:    # no git history available (e.g. an export): every asset reads as unversioned source art
        sets = [{"commit": "", "short": "no git history", "date": "", "subject": "git history unavailable", "files": set()}]
    for i, s in enumerate(sets):
        s["version"] = i + 1
    wip = [l for l in git("status", "--porcelain", "--", *ART_PATHS).splitlines() if l.strip()]
    if wip:
        sets.append({"commit": "", "short": "working tree", "date": "", "subject": "uncommitted art changes",
                     "files": {l[3:].strip() for l in wip}, "version": len(sets) + 1})
    return sets


def png_index() -> Dict[str, Path]:
    return {p.stem: p for p in ART.rglob("*.png")}      # bundle names are globally unique (flattened by Xcode)


def rel(p: Path) -> str:
    return str(p.relative_to(REPO))


def digest(paths: List[Path]) -> str:
    h = hashlib.sha256()
    for p in sorted(paths, key=lambda q: q.name):
        h.update(p.name.encode()); h.update(p.read_bytes())
    return h.hexdigest()[:8]


def version_info(paths: List[Path], sets: List[dict]) -> dict:
    files = {rel(p) for p in paths}
    touched = [s["version"] for s in sets if files & s["files"]]
    return {"revision": len(touched), "createdIn": min(touched) if touched else None,
            "lastChangedIn": max(touched) if touched else None, "hash": digest(paths)}


def prev_regions(sets: List[dict], manifest_rel: str) -> dict:
    """{asset id: set of region names} from the manifest as of the previous set (to spot lost/gained regions)."""
    if len(sets) < 2 or not sets[-2]["commit"]:
        return {}
    try:
        old = json.loads(git("show", f"{sets[-2]['commit']}:{manifest_rel}"))
    except Exception:
        return {}
    items = old.get("parts") or old.get("items") or []
    return {i["id"]: set(i.get("materialRegions") or i.get("maskResources", {}).keys()) for i in items}


# ---------------------------------------------------------------- flags

def mask_arrays(index: Dict[str, Path], resources: Dict[str, str]) -> Dict[str, np.ndarray]:
    return {r: np.asarray(Image.open(index[n]).convert("L"), np.float32) / 255.0 for r, n in resources.items() if n in index}


def region_flags(masks: Dict[str, np.ndarray]) -> List[str]:
    flags: List[str] = []
    if not masks:
        return flags
    area = {r: float((m > 0.5).sum()) for r, m in masks.items()}
    total = max(sum(area.values()), 1.0)
    for r, a in area.items():
        if r not in ("skin", "eyes", "hair") and a / total < 0.04 and len(masks) > 1:
            flags.append(f"tiny region '{r}' ({100 * a / total:.1f}% of the painted area): check for a stray patch")
    if len([r for r in masks if r not in ("skin", "eyes", "hair")]) >= 3:
        flags.append("3+ colour regions: check that one material was not split")
    return flags


def known(asset_id: str, name: str = "") -> List[str]:
    return [msg for pat, msg in KNOWN_ISSUES if re.search(pat, asset_id) or (name and re.search(pat, name))]


# ---------------------------------------------------------------- collect

def collect() -> dict:
    sets = set_history()
    index = png_index()
    races = json.loads(RACES.read_text())
    gear = json.loads(GEAR.read_text())
    old_parts = prev_regions(sets, "ios/PurgeQuest/Art/Modular/modular_races_manifest.json")
    old_gear = prev_regions(sets, "ios/PurgeQuest/Art/Modular/modular_gear_manifest.json")
    parts, items = [], []
    for p in races["parts"]:
        files = [index[n] for n in [p["resourceBaseName"], *p.get("maskResources", {}).values()] if n in index]
        auto = p["verification"].get("automated", {})
        flags, notes = list(known(p["id"])), []
        masks = auto.get("masks", {})
        if masks.get("outlineLeak", 0) > 0.002:
            flags.append(f"outline leak {masks['outlineLeak']:.4f}")
        if p["kind"] in ("armor", "headgear") and not p.get("materialRegions"):
            flags.append("no recolour region")
        if p["kind"] in ("armor", "headgear") and masks.get("coverage") is not None and masks["coverage"] < 0.9:
            flags.append(f"mask coverage {masks['coverage']:.2f}: parts of the art are not recolourable")
        worst = max([a.get("mean", 0) for a in auto.get("reassembly", {}).values()] or [0])
        if worst > 2e-4:
            flags.append(f"reassembly error {worst:.1e}")
        all_profiles = {"athletic", "slender", "standard", "skeletal", "brute"}
        fit = set(p.get("nativeProfiles", [])) | set(p.get("adaptedProfiles", []))
        unsupported = sorted(all_profiles - fit)
        if len(unsupported) >= 2:
            notes.append("body fit unsupported for: " + ", ".join(unsupported))
        gone = old_parts.get(p["id"], set()) - set(p.get("materialRegions", []))
        if p["id"] in old_parts and gone:
            notes.append("regions merged vs the previous set (no longer separate): " + ", ".join(sorted(gone)))
        parts.append({"id": p["id"], "pack": p["pack"], "part": p["part"], "kind": p["kind"], "slot": p["slot"],
                      "status": p["verification"]["status"], "regions": p.get("materialRegions", []),
                      "unsupportedProfiles": unsupported, "flags": flags, "notes": notes,
                      **version_info(files, sets)})
    for g in gear["items"]:
        names = [g["resourceName"], *g.get("maskResources", {}).values()]
        files = [index[n] for n in names if n in index and (n != g["resourceName"] or "store" in index[n].parts)]
        flags, notes = list(known(g["id"], g["name"])), []
        flags += region_flags(mask_arrays(index, g.get("maskResources", {})))
        if g["verification"]["status"] != "candidate":
            flags.append(f"status {g['verification']['status']} (automated checks did not all pass)")
        gone = old_gear.get(g["id"], set()) - set(g.get("maskResources", {}))
        if g["id"] in old_gear and gone:
            notes.append("regions merged vs the previous set (no longer separate): " + ", ".join(sorted(gone)))
        items.append({"id": g["id"], "name": g["name"], "kind": g["kind"], "group": g["group"],
                      "status": g["verification"]["status"], "regions": sorted(g.get("maskResources", {})),
                      "supportedPacks": len(g["supportedPacks"]), "flags": flags, "notes": notes, **version_info(files, sets)})
    current = sets[-1]
    return {"setVersion": current["version"], "wip": not current["commit"], "sets": [
        {k: v for k, v in s.items() if k != "files"} | {"filesChanged": len(s["files"])} for s in sets],
        "counts": {"parts": len(parts), "gear": len(items), "candidate": sum(a["status"] == "candidate" for a in parts + items),
                   "verified": sum(a["status"] == "verified" for a in parts + items)},
        "parts": parts, "gear": items}


# ---------------------------------------------------------------- markdown

def label(inv: dict) -> str:
    cur = inv["sets"][-1]
    return f"v{inv['setVersion']}{'+wip' if inv['wip'] else ''}"


def row(a: dict, name: str, cur: int) -> str:
    chg = "source art" if a["lastChangedIn"] is None else "**changed**" if a["lastChangedIn"] == cur else f"v{a['lastChangedIn']}"
    rev = "-" if a["lastChangedIn"] is None else f"r{a['revision']}"
    text = "; ".join(a["flags"] + [f"note: {n}" for n in a.get("notes", [])])
    return f"| {name} | {a['status']} | {rev} | {chg} | `#{a['hash']}` | {', '.join(a['regions']) or '-'} | {text} |"


def markdown(inv: dict) -> str:
    cur = inv["setVersion"]
    L = [f"# Modular asset inventory — set {label(inv)}", "",
         "Generated by `tools/modular_assets/inventory.py`; do not edit. Versions come from git (see the script's docstring).", "",
         "- **vN** — set version: the Nth commit that changed the shipped art. **rK** — how many sets changed this asset. "
         "**#hash** — SHA-256 prefix of its pixels: the same hash means the same asset.",
         "- **last changed** — `changed` means this asset's pixels are new in the current set; otherwise the set it last changed in.",
         f"- {inv['counts']['parts']} race parts + {inv['counts']['gear']} held-gear items; {inv['counts']['candidate']} candidate, "
         f"{inv['counts']['verified']} verified (approval is a human gate).", "",
         "## Set history", "", "| set | commit | date | what | files |", "|---|---|---|---|---|"]
    for s in inv["sets"]:
        L.append(f"| v{s['version']} | `{s['short']}` | {s['date']} | {s['subject'][:90]} | {s['filesChanged']} |")
    flagged = [a for a in inv["parts"] + inv["gear"] if a["flags"]]
    L += ["", f"## Needs attention ({len(flagged)} assets with flags)", "",
          "Flags are either computed (tiny regions, lost regions, mask coverage, fit) or recorded by hand from reviewing renders "
          "(`KNOWN_ISSUES` in the script). A flag means *look at this one*, not that it is wrong.", "",
          "| asset | version | flags |", "|---|---|---|"]
    for a in flagged:
        L.append(f"| {a.get('name') or a['id']} (`{a['id']}`) | r{a['revision']} · `#{a['hash']}` | {'; '.join(a['flags'])} |")
    by_pack: Dict[str, List[dict]] = defaultdict(list)
    for a in inv["parts"]:
        by_pack[a["pack"]].append(a)
    L += ["", "## Race parts", ""]
    for pack, rows in by_pack.items():
        L += [f"### {pack}", "", "| part | status | rev | last changed | hash | regions | flags |", "|---|---|---|---|---|---|---|"]
        L += [row(a, f"{a['part']} · {a['kind']}", cur) for a in rows]
        L.append("")
    by_group: Dict[str, List[dict]] = defaultdict(list)
    for a in inv["gear"]:
        by_group[a["group"]].append(a)
    L += ["## Held gear", ""]
    for group, rows in by_group.items():
        L += [f"### {group}", "", "| item | status | rev | last changed | hash | regions | flags |", "|---|---|---|---|---|---|---|"]
        L += [row(a, f"{a['name']} (`{a['id']}`)", cur) for a in rows]
        L.append("")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- sheets

def font(size: int):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def preview(index: Dict[str, Path], base: str, masks: Dict[str, str], tones: dict, box: int = 150) -> Image.Image:
    import qa
    img = Image.open(index[base]).convert("RGBA")
    ms = {r: Image.open(index[n]).convert("L") for r, n in masks.items() if n in index}
    rec = qa.recolor(img, ms, tones, LOUD) if ms else img
    s = box / max(img.size)
    size = (max(1, int(img.width * s)), max(1, int(img.height * s)))
    out = Image.new("RGB", (box * 2 + 18, box + 10), (44, 46, 58))
    for k, im in enumerate((img, rec)):
        t = Image.new("RGBA", img.size, (44, 46, 58, 255)); t.alpha_composite(im.convert("RGBA"))
        t = t.convert("RGB").resize(size, Image.LANCZOS)
        out.paste(t, (4 + k * (box + 10) + (box - size[0]) // 2, 5 + (box - size[1]) // 2))
    return out


def sheet(title: str, tiles: List[tuple], banner: str, cols: int = 4) -> Image.Image:
    f, fs = font(13), font(11)
    tw, th = 2 * 150 + 18 + 12, 150 + 10 + 62
    rows = (len(tiles) + cols - 1) // cols
    W, H = cols * (tw + 8) + 8, rows * (th + 8) + 8 + 64
    im = Image.new("RGB", (W, H), (20, 20, 26)); d = ImageDraw.Draw(im)
    d.text((10, 8), banner, fill=(255, 214, 120), font=f)
    d.text((10, 30), title, fill=(255, 255, 255), font=f)
    d.text((10, 48), "left: original art    right: one loud colour per recolour region (red primary, green secondary, blue trim, "
           "yellow leather, white emissive, purple skin)", fill=(170, 170, 180), font=fs)
    for i, (pic, line1, line2, flags) in enumerate(tiles):
        x, y = 8 + (i % cols) * (tw + 8), 64 + 8 + (i // cols) * (th + 8)
        d.rectangle([x, y, x + tw, y + th], fill=(30, 30, 38))
        im.paste(pic, (x + 6, y + 4))
        d.text((x + 8, y + 150 + 16), line1, fill=(240, 240, 240), font=fs)
        d.text((x + 8, y + 150 + 30), line2, fill=(150, 200, 255), font=fs)
        if flags:
            d.text((x + 8, y + 150 + 44), "FLAG: " + flags[:44], fill=(255, 140, 120), font=fs)
    return im


def make_sheets(inv: dict, out: Path) -> List[Path]:
    out.mkdir(parents=True, exist_ok=True)
    index = png_index()
    races = {p["id"]: p for p in json.loads(RACES.read_text())["parts"]}
    gear = {g["id"]: g for g in json.loads(GEAR.read_text())["items"]}
    cur = inv["sets"][-1]
    banner = (f"PurgeQuest modular asset set {label(inv)}  ·  commit {cur['short']}  ·  {cur['date'] or 'uncommitted'}  ·  "
              f"{inv['counts']['candidate']} candidate / {inv['counts']['verified']} verified  ·  r = revisions, # = content hash")
    paths: List[Path] = []

    def tile(a: dict, src: dict, base: str, masks: dict, name: str):
        pic = preview(index, base, masks, src.get("regionTone", {}))
        if a["lastChangedIn"] is None:
            chg, rev = "source art (unchanged)", "-"
        else:
            chg = "CHANGED in this set" if a["lastChangedIn"] == inv["setVersion"] else f"last changed v{a['lastChangedIn']}"
            rev = f"r{a['revision']}"
        return (pic, name[:46], f"{rev}  #{a['hash']}  {chg}  [{a['status']}]", "; ".join(a["flags"]) or "")

    by_pack: Dict[str, List[dict]] = defaultdict(list)
    for a in inv["parts"]:
        by_pack[a["pack"]].append(a)
    for pack, rows in by_pack.items():
        tiles = [tile(a, races[a["id"]], races[a["id"]]["resourceBaseName"], races[a["id"]].get("maskResources", {}),
                      f"{a['part']} · {a['kind']}") for a in rows]
        p = out / f"{len(paths) + 1:02d}_{pack}.png"
        sheet(f"Race pack {pack}  ({len(rows)} layers)", tiles, banner).save(p, optimize=True); paths.append(p)
    groups: Dict[str, List[dict]] = defaultdict(list)
    for a in inv["gear"]:
        groups[a["group"] if a["group"] != "store" else "store"].append(a)
    for group, rows in groups.items():
        for k in range(0, len(rows), 24):
            chunk = rows[k:k + 24]
            tiles = [tile(a, gear[a["id"]], gear[a["id"]]["resourceName"], gear[a["id"]].get("maskResources", {}), a["name"])
                     for a in chunk]
            part = f" ({k // 24 + 1}/{(len(rows) + 23) // 24})" if len(rows) > 24 else ""
            p = out / f"{len(paths) + 1:02d}_gear_{group}{('_' + str(k // 24 + 1)) if part else ''}.png"
            sheet(f"Held gear: {group}{part}", tiles, banner).save(p, optimize=True); paths.append(p)
    pdf = out / f"asset_set_{label(inv).replace('+', '_')}_all.pdf"
    ims = [Image.open(p).convert("RGB") for p in paths]
    ims[0].save(pdf, save_all=True, append_images=ims[1:], resolution=110.0)
    paths.append(pdf)
    return paths


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheets", type=Path, help="also write contact sheets (PNG per pack/gear group) and one PDF here")
    ap.add_argument("--no-docs", action="store_true", help="do not write docs/modular/ASSET_INVENTORY.md / asset_inventory.json")
    args = ap.parse_args()
    inv = collect()
    if not args.no_docs:
        (DOCS / "asset_inventory.json").write_text(json.dumps(inv, indent=1) + "\n")
        (DOCS / "ASSET_INVENTORY.md").write_text(markdown(inv))
    flagged = sum(1 for a in inv["parts"] + inv["gear"] if a["flags"])
    print(f"set {label(inv)}: {inv['counts']['parts']} parts + {inv['counts']['gear']} gear, "
          f"{inv['counts']['candidate']} candidate, {inv['counts']['verified']} verified, {flagged} flagged")
    if args.sheets:
        for p in make_sheets(inv, args.sheets):
            print(" ", p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
