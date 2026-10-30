"""Held-gear fitting: grip points, per-pack hold points, recolor masks, Titan 2x clipping analysis.

Model (mirrored by HeldGearFit.swift): every weapon/shield image is drawn with its top-left
at the SCML anchor pivot. An item declares its `grip` (image px, y-down). Each pack declares
the `hold` point (px relative to the anchor pivot, y-down) where its own baked weapon is
gripped. For any scale s the local offset that keeps the grip on the hold is

    offset(s) = hold - s * (grip - pivotPx)

so Titan scaling (s = 2) grows the item about the grip and the hand never lets go.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import imgops as ops
import qa
import scml
import separate
from separate import Layer, RegionModel

REPO = Path(__file__).resolve().parents[2]
OUT = scml.ART_ROOT / "Modular"
MASK_DIR = OUT / "Gear"
SHEETS = REPO / "docs" / "modular" / "verification"
TITAN_SCALE = 2.0
GEAR_ROOT = scml.ART_ROOT / "Gear"

SIGNATURE = [  # (HeroRace raw, display name, kind)
    ("valkyrie", "Valkyrie Blade", "sword"), ("forest_ranger", "Elven Recurve", "bow"),
    ("seer", "Seer's Edge", "sword"), ("blood_alchemist", "Vampyri Cleaver", "sword"),
    ("dark_oracle", "Scarred Fang", "sword"), ("necromancer", "Shadowbrand", "sword"),
    ("skeleton_crusader", "Undead Claymore", "sword"), ("golem", "Vaultcracker", "sword"),
]
STAFF_SETS = ["Ashen Bough", "Verdant Coil", "Tidecaller", "Ember Scepter", "Storm Spire", "Gilded Crook", "Bone Reliquary", "Voidspike"]
SHIELD_SETS = ["Oaken Ward", "Templar Aegis", "Scaled Bulwark", "Runic Disc", "Valkyrie Wing", "Iron Moon", "Bone Paragon", "Verdigris Sigil"]
TIERS = ["I", "II", "III", "IV", "V"]


# ------------------------------------------------------------ geometry

def opaque_bbox(img: Image.Image, thresh: int = 20) -> Tuple[int, int, int, int]:
    a = np.asarray(img.convert("RGBA"))[..., 3] > thresh
    ys, xs = np.nonzero(a)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def detect_grip(img: Image.Image, kind: str) -> Tuple[float, float]:
    """Grip point in image px (y-down). Consistent across items so alignment is comparable."""
    x0, y0, x1, y1 = opaque_bbox(img)
    a = np.asarray(img.convert("RGBA"))[..., 3] > 20
    if kind == "shield":
        return (x0 + x1) / 2, (y0 + y1) / 2
    if kind == "bow":
        row = a[int((y0 + y1) / 2)]
        xs = np.nonzero(row)[0]
        return (float(xs.mean()) if len(xs) else x0 + 0.15 * (x1 - x0)), (y0 + y1) / 2
    length = x1 - x0
    cols = slice(x0, x0 + max(2, int(0.2 * length)))
    ys = np.nonzero(a[:, cols].any(axis=1))[0]
    return x0 + 0.10 * length, float(ys.mean())


def anchor_info(race: str, variant: int, kind: str) -> dict:
    """Pivot (px, y-down from image top-left) and anchor stem for weapons/shields in a pack."""
    doc = scml.load_doc(race, variant)
    pivots = set()
    stem = None
    for anim in ("Idle", "Slashing", "Shooting"):
        for frame in doc.animations.get(anim, []):
            for p in frame:
                match = (kind == "shield" and p.file.stem.startswith("shield")) or \
                        (kind != "shield" and scml.is_weapon(p.file.stem) and p.file.stem != "arrow")
                if match:
                    stem = p.file.stem
                    pivots.add((round(p.pivot_x, 4), round(p.pivot_y, 4), p.file.width, p.file.height))
    if not pivots and kind == "shield":
        for frame in doc.animations["Idle"]:
            for p in frame:
                if p.file.stem == "left_hand":
                    stem = "left_hand"
                    pivots.add((round(p.pivot_x, 4), round(p.pivot_y, 4), p.file.width, p.file.height))
    px, py, w, h = sorted(pivots)[0]
    return {"stem": stem, "pivotPx": (px * w, (1 - py) * h), "width": w, "height": h, "constant": len(pivots) == 1}


def pack_holds(race: str, variant: int) -> dict:
    pid = scml.pack_id(race, variant)
    base = scml.pack_dir(race, variant)
    out = {}
    w = anchor_info(race, variant, "weapon")
    wstem = w["stem"]
    wimg = Image.open(base / f"{pid}_{wstem}.png").convert("RGBA")
    kind = "bow" if wstem == "bow" else "sword"
    g = detect_grip(wimg, kind)
    out["weapon"] = {"anchor": wstem, "pivotPx": w["pivotPx"], "hold": (g[0] - w["pivotPx"][0], g[1] - w["pivotPx"][1]),
                     "gripPx": g, "imageSize": wimg.size, "constantPivot": w["constant"]}
    s = anchor_info(race, variant, "shield")
    simg = Image.open(base / f"{pid}_{s['stem']}.png").convert("RGBA")
    if s["stem"] == "shield":
        sg = detect_grip(simg, "shield")
    else:  # no baked shield: hold on the left hand's visible centre
        x0, y0, x1, y1 = opaque_bbox(simg)
        sg = ((x0 + x1) / 2, (y0 + y1) / 2)
    out["shield"] = {"anchor": s["stem"], "pivotPx": s["pivotPx"], "hold": (sg[0] - s["pivotPx"][0], sg[1] - s["pivotPx"][1]),
                     "gripPx": sg, "imageSize": simg.size, "constantPivot": s["constant"]}
    return out


def local_offset(hold: Tuple[float, float], grip: Tuple[float, float], pivot_px: Tuple[float, float], s: float) -> Tuple[float, float]:
    return (hold[0] - s * (grip[0] - pivot_px[0]), hold[1] - s * (grip[1] - pivot_px[1]))


def item_corners_world(p: scml.Placement, bbox, img_size, off, s: float):
    """World (y-up) corners of an item's opaque bbox. Items draw in native pixels relative to the anchor pivot:
    local(u, v) = s * ((u, v) - pivotPx) + off (y-down), matching SpriteRenderer.itemRect."""
    pivot_px = (p.pivot_x * p.file.width, (1 - p.pivot_y) * p.file.height)
    x0, y0, x1, y1 = bbox
    r = math.radians(p.angle)
    c, sn = math.cos(r), math.sin(r)
    pts = []
    for u, v in ((x0, y0), (x1 + 1, y0), (x1 + 1, y1 + 1), (x0, y1 + 1)):
        lx = s * (u - pivot_px[0]) + off[0]
        ly = -(s * (v - pivot_px[1]) + off[1])
        pts.append((p.x + lx * c - ly * sn, p.y + lx * sn + ly * c))
    return pts


def item_rect_corners(p: scml.Placement, img_size, off, s: float):
    """World (y-up) corners of an item's full image rect drawn at placement p."""
    return item_corners_world(p, (0, 0, img_size[0] - 1, img_size[1] - 1), img_size, off, s)


def canvas_with_item(doc: scml.Doc, pack: dict, kind: str, img_size, grip, scale: float, pad: float = 20.0):
    """Base canvas united with the item's rect at its fitted placement over every frame, hidden anchors included
    (a swapped item is drawn at its anchor even when the baked one is hidden). Mirrors SpriterDocument.canvas(for:)."""
    base_o, base_s = doc.canvas(1.0)
    min_x, min_y = base_o[0] + pad, base_o[1] + pad
    max_x, max_y = base_o[0] + base_s[0] - pad, base_o[1] + base_s[1] - pad
    key = "shield" if kind == "shield" else "weapon"
    hold, pivot = pack[key]["hold"], pack[key]["pivotPx"]
    off = local_offset(hold, grip, pivot, scale)
    for frames in doc.animations.values():
        for fr in frames:
            if kind == "shield":
                anchors = [p for p in fr if p.file.stem.startswith("shield")] or [p for p in fr if p.file.stem == "left_hand"]
            else:
                anchors = [p for p in fr if p.file.stem.startswith(("sword", "bow"))]
            for p in anchors[:1]:
                for x, y in item_rect_corners(p, img_size, off, scale):
                    min_x, max_x, min_y, max_y = min(min_x, x), max(max_x, x), min(min_y, y), max(max_y, y)
    origin = (min_x - pad, min_y - pad)
    return origin, (max_x + pad - origin[0], max_y + pad - origin[1])


def bow_string_alignment(race: str, variant: int, bow_img: Image.Image) -> dict:
    """Distance (px) from the arrow nock to the bow's string chord in every Shooting frame."""
    doc = scml.load_doc(race, variant)
    base = scml.pack_dir(race, variant)
    arrow_img = Image.open(base / f"{scml.pack_id(race, variant)}_arrow.png").convert("RGBA")
    bx0, by0, bx1, by1 = opaque_bbox(bow_img)
    a = np.asarray(bow_img)[..., 3] > 20
    top_x = float(np.nonzero(a[by0])[0].mean()); bot_x = float(np.nonzero(a[by1])[0].mean())
    ax0, ay0, ax1, ay1 = opaque_bbox(arrow_img)
    dists = []
    for fr in doc.animations["Shooting"]:
        bow = next(p for p in fr if p.file.stem == "bow")
        arrow = next(p for p in fr if p.file.stem == "arrow")
        if bow.alpha < 0.01 or arrow.alpha < 0.01:
            continue
        def world(p, u, v, img):
            sx, sy = p.file.width / img.size[0], p.file.height / img.size[1]
            lx, ly = u * sx - p.pivot_x * p.file.width, (1 - p.pivot_y) * p.file.height - v * sy
            r = math.radians(p.angle)
            return p.x + lx * math.cos(r) - ly * math.sin(r), p.y + lx * math.sin(r) + ly * math.cos(r)
        t = world(bow, top_x, by0, bow_img); b = world(bow, bot_x, by1, bow_img)
        nock = world(arrow, ax0, (ay0 + ay1) / 2, arrow_img)
        # distance from nock to chord line t-b
        (x1, y1), (x2, y2), (px, py) = t, b, nock
        d = abs((x2 - x1) * (y1 - py) - (x1 - px) * (y2 - y1)) / max(math.hypot(x2 - x1, y2 - y1), 1e-6)
        dists.append(d)
    return {"frames": len(dists), "maxNockToChordPx": round(max(dists), 2) if dists else None,
            "meanNockToChordPx": round(sum(dists) / len(dists), 2) if dists else None}


# ------------------------------------------------------------ items

def build_items() -> List[dict]:
    items: List[dict] = []
    for raw, name, kind in SIGNATURE:
        resource = f"{raw}_v1_{'bow' if kind == 'bow' else 'sword'}"
        items.append({"id": f"weapon.{raw}", "name": name, "kind": kind, "slot": "mainHand", "resource": resource,
                      "path": scml.pack_dir(raw, 1) / f"{resource}.png", "group": "signature"})
    for si, set_name in enumerate(STAFF_SETS, 1):
        for t in range(1, 6):
            res = f"staff_{si}_{t}"
            items.append({"id": f"weapon.staff.{si}.{t}", "name": f"{set_name} {TIERS[t-1]}", "kind": "staff", "slot": "mainHand",
                          "resource": res, "path": GEAR_ROOT / "staves" / f"{res}.png", "group": f"staff{si}"})
    for si, set_name in enumerate(SHIELD_SETS, 1):
        for t in range(1, 6):
            res = f"shield_{si}_{t}"
            items.append({"id": f"shield.set.{si}.{t}", "name": f"{set_name} {TIERS[t-1]}", "kind": "shield", "slot": "offHand",
                          "resource": res, "path": GEAR_ROOT / "shields" / f"{res}.png", "group": f"shield{si}"})
    spec = REPO / "tools" / "modular_assets" / "store_gear_spec.json"
    if spec.exists():
        for g in json.loads(spec.read_text())["items"]:
            hp = g["kind"] == "headpiece"
            items.append({"id": g["id"], "name": g["name"], "kind": g["kind"],
                          "slot": "head" if hp else ("offHand" if g["kind"] == "shield" else "mainHand"),
                          "resource": g["resource"], "path": GEAR_ROOT / "store" / f"{g['resource']}.png",
                          "group": "headpiece" if hp else "store"})
    return items


def supported_packs(item: dict) -> List[str]:
    packs = [scml.pack_id(r, v) for r, v in scml.PACKS]
    if item["kind"] == "bow":   # a bow needs a pack with a bow anchor and the Shooting animation
        return [p for p in packs if p in ("forest_ranger_v1", "forest_ranger_v2")]
    return packs


def arrow_nock(pid: str) -> list:
    """Arrow tail (nock) in arrow-image px: the left end of the arrow's opaque bbox, mid-height."""
    race, variant = pid.rsplit("_v", 1)[0], int(pid.rsplit("_v", 1)[1])
    img = Image.open(scml.pack_dir(race, variant) / f"{pid}_arrow.png").convert("RGBA")
    x0, y0, x1, y1 = opaque_bbox(img)
    return [float(x0), (y0 + y1) / 2]


def head_fit(race: str, variant: int) -> dict:
    """Where a headpiece sits on this pack's head, in head-PNG pixels: centre, brim line, and width."""
    pid = scml.pack_id(race, variant)
    anat = OUT / race / f"v{variant}" / f"{pid}_head_anatomy.png"
    path = anat if anat.exists() else scml.pack_dir(race, variant) / f"{pid}_head.png"
    img = Image.open(path).convert("RGBA")
    x0, y0, x1, y1 = opaque_bbox(img)
    orig = Image.open(scml.pack_dir(race, variant) / f"{pid}_head.png")
    return {"cx": round((x0 + x1) / 2, 1), "baseY": round(y0 + 0.42 * (y1 - y0), 1), "widthPx": round(1.12 * (x1 - x0), 1),
            "headPngSize": list(orig.size), "headBox": [x0, y0, x1, y1]}


def headpiece_canvas(doc: scml.Doc, fit: dict, nom: dict, img_size, pad: float = 20.0):
    """Canvas size when a headpiece overlay is added to every frame's head placement."""
    base_o, base_s = doc.canvas(1.0)
    min_x, min_y = base_o[0] + pad, base_o[1] + pad
    max_x, max_y = base_o[0] + base_s[0] - pad, base_o[1] + base_s[1] - pad
    k = fit["widthPx"] / nom["width"]
    for frames in doc.animations.values():
        for fr in frames:
            head = next((p for p in fr if p.file.stem == "head"), None)
            if head is None:
                continue
            f = head.file.width / fit["headPngSize"][0]
            left = (fit["cx"] - k * nom["anchorU"]) * f - head.pivot_x * head.file.width
            top = (fit["baseY"] - k * nom["anchorV"]) * f - (1 - head.pivot_y) * head.file.height
            w, h = img_size[0] * k * f, img_size[1] * k * f
            r = math.radians(head.angle); c, s = math.cos(r), math.sin(r)
            for lx, ly in ((left, -top), (left + w, -top), (left + w, -(top + h)), (left, -(top + h))):
                x, y = head.x + lx * c - ly * s, head.y + lx * s + ly * c
                min_x, max_x, min_y, max_y = min(min_x, x), max(max_x, x), min(min_y, y), max(max_y, y)
    return (max_x - min_x + 2 * pad, max_y - min_y + 2 * pad)


def analyze() -> dict:
    holds = {scml.pack_id(r, v): pack_holds(r, v) for r, v in scml.PACKS}
    items = build_items()
    out_items = []
    nominal = json.loads((REPO / 'tools' / 'modular_assets' / 'store_gear_spec.json').read_text())['headpieceNominal']
    pack_out_pre = {pid: {"headFit": head_fit(pid.rsplit('_v', 1)[0], int(pid.rsplit('_v', 1)[1]))} for pid in holds}
    MASK_DIR.mkdir(parents=True, exist_ok=True)
    for old in MASK_DIR.glob("*.png"):
        old.unlink()
    for it in items:
        img = Image.open(it["path"]).convert("RGBA")
        bbox = opaque_bbox(img)
        kind = it["kind"]
        grip = detect_grip(img, kind if kind in ("bow", "shield") else "sword")
        # recolor masks
        layer = Layer(it["resource"], "armor", it["slot"], img)
        model = RegionModel([layer])
        masks, lumas = model.masks(img)
        for region, m in masks.items():
            m.save(MASK_DIR / f"{it['resource']}_mask_{region}.png", optimize=True)
        checks = {"gripOnItem": bool(_alpha_near(img, grip, 10) > 0.5), "bbox": list(bbox)}
        if kind == "headpiece":
            nom = nominal
            grip = (nom["anchorU"], nom["anchorV"])
            checks["gripOnItem"] = True
            growth = {"1x": [1.0, 1.0]}
            worst = [1.0, 1.0]
            for pid, pk in pack_out_pre.items():
                race, v = pid.rsplit("_v", 1)[0], int(pid.rsplit("_v", 1)[1])
                doc = scml.load_doc(race, v)
                _, base_size = doc.canvas(1.0)
                gs = headpiece_canvas(doc, pk["headFit"], nom, img.size)
                worst = [max(worst[0], round(gs[0] / base_size[0], 3)), max(worst[1], round(gs[1] / base_size[1], 3))]
            growth["1x"] = worst
            checks["canvasGrowth"] = growth
            checks["headFitPacks"] = len(pack_out_pre)
            out_items.append({
                "id": it["id"], "name": it["name"], "kind": kind, "slot": "head", "resourceName": it["resource"], "group": it["group"],
                "imageWidth": img.size[0], "imageHeight": img.size[1], "gripPx": [grip[0], grip[1]], "scale": 1.0, "rotationDegrees": 0.0,
                "layer": "aboveFace", "profileOverrides": {}, "supportedPacks": [p for p in pack_out_pre],
                "maskResources": {r: f"{it['resource']}_mask_{r}" for r in sorted(masks)},
                "regionLuma": {r: round(v, 4) for r, v in lumas.items()},
                "verification": {"status": "candidate" if max(worst) <= 1.35 and masks else "mapped", "automated": checks, "approvedBy": None}})
            continue
        packs = supported_packs(it)
        growth = {"1x": [1.0, 1.0], "titan": [1.0, 1.0]}
        for pid in packs:
            race, v = pid.rsplit("_v", 1)[0], int(pid.rsplit("_v", 1)[1])
            doc = scml.load_doc(race, v)
            _, base_size = doc.canvas(1.0)
            for label, s in ([("1x", 1.0)] if kind == "shield" else [("1x", 1.0), ("titan", TITAN_SCALE)]):
                _, size = canvas_with_item(doc, holds[pid], kind, img.size, grip, s)
                g = [size[0] / base_size[0], size[1] / base_size[1]]
                growth[label] = [max(growth[label][0], round(g[0], 3)), max(growth[label][1], round(g[1], 3))]
        checks["canvasGrowth"] = growth
        extra = {}
        if kind == "bow":
            a_ = np.asarray(img)[..., 3] > 20
            extra["stringAnchors"] = {"top": [round(float(np.nonzero(a_[bbox[1]])[0].mean()), 1), bbox[1]],
                                      "bottom": [round(float(np.nonzero(a_[bbox[3]])[0].mean()), 1), bbox[3]]}
            checks["stringAlignment"] = {pid: bow_string_alignment(pid.rsplit("_v", 1)[0], int(pid.rsplit("_v", 1)[1]), img) for pid in packs}
        ok = checks["gripOnItem"] and max(growth["titan"]) <= 1.9 and bool(masks)
        out_items.append({
            "id": it["id"], "name": it["name"], "kind": kind, "slot": it["slot"], "resourceName": it["resource"],
            "group": it["group"], "imageWidth": img.size[0], "imageHeight": img.size[1],
            "gripPx": [round(grip[0], 2), round(grip[1], 2)], "scale": 1.0, "rotationDegrees": 0.0, "layer": "front",
            "profileOverrides": {}, "supportedPacks": packs, **extra,
            "maskResources": {r: f"{it['resource']}_mask_{r}" for r in sorted(masks)},
            "regionLuma": {r: round(v, 4) for r, v in lumas.items()},
            "verification": {"status": "candidate" if ok else "mapped", "automated": checks, "approvedBy": None},
        })
    nominal = json.loads((REPO / 'tools' / 'modular_assets' / 'store_gear_spec.json').read_text())['headpieceNominal'] if (REPO / 'tools' / 'modular_assets' / 'store_gear_spec.json').exists() else None
    pack_out = {pid: {"weaponAnchor": h["weapon"]["anchor"], "weaponPivotPx": [round(x, 2) for x in h["weapon"]["pivotPx"]],
                      "weaponHold": [round(x, 2) for x in h["weapon"]["hold"]],
                      "shieldAnchor": h["shield"]["anchor"], "shieldPivotPx": [round(x, 2) for x in h["shield"]["pivotPx"]],
                      "shieldHold": [round(x, 2) for x in h["shield"]["hold"]],
                      "headFit": head_fit(pid.rsplit("_v", 1)[0], int(pid.rsplit("_v", 1)[1])),
                      **({"arrowNock": arrow_nock(pid)} if h["weapon"]["anchor"] == "bow" else {})} for pid, h in holds.items()}
    return {"schemaVersion": 1, "titanScale": TITAN_SCALE, "headpieceNominal": nominal, "packs": pack_out, "items": out_items}


def _alpha_near(img: Image.Image, pt, r: int) -> float:
    a = np.asarray(img.convert("RGBA"))[..., 3] / 255.0
    x, y = int(round(pt[0])), int(round(pt[1]))
    return float(a[max(0, y - r): y + r + 1, max(0, x - r): x + r + 1].max())


# ------------------------------------------------------------ sheets

def render_item(race: str, variant: int, anim: str, frame: int, it: dict, holds: dict, scale: float = 0.4, titan: bool = False,
                gear_cache: Dict[str, Image.Image] = {}) -> Image.Image:
    doc = scml.load_doc(race, variant)
    pid = scml.pack_id(race, variant)
    path = next(i["path"] for i in build_items() if i["resource"] == it["resourceName"])
    img = gear_cache.setdefault(str(path), Image.open(path).convert("RGBA"))
    kind = "shield" if it["kind"] == "shield" else "weapon"
    h = holds[pid][kind]
    s = TITAN_SCALE if (titan and kind == "weapon") else 1.0
    off = local_offset(h["hold"], tuple(it["gripPx"]), h["pivotPx"], s)
    fit = {"scale": s, "offset": off}
    origin, size = canvas_with_item(doc, holds[pid], it["kind"], img.size, tuple(it["gripPx"]), s)
    return scml.render_frame(doc, race, variant, anim, frame, canvas=(origin, size), scale=scale,
                                    weapon_image=img if kind == "weapon" else None, weapon_fit=fit if kind == "weapon" else None,
                                    shield_image=img if kind == "shield" else None, shield_fit=fit if kind == "shield" else None,
                                    background=qa.BG)


def sheets(manifest: dict) -> None:
    SHEETS.mkdir(parents=True, exist_ok=True)
    holds = {pid: {"weapon": {"hold": tuple(p["weaponHold"]), "pivotPx": tuple(p["weaponPivotPx"])},
                   "shield": {"hold": tuple(p["shieldHold"]), "pivotPx": tuple(p["shieldPivotPx"])}} for pid, p in manifest["packs"].items()}
    globals()["_HOLDS"] = holds
    by_group: Dict[str, List[dict]] = {}
    for it in manifest["items"]:
        by_group.setdefault(it["group"], []).append(it)
    nominal = manifest["headpieceNominal"]
    for group, items in by_group.items():
        if group == "signature":
            continue
        if group == "headpiece":
            rows = []
            for race, v in [(r, 1) for r in ("valkyrie", "forest_ranger", "seer", "blood_alchemist", "dark_oracle", "necromancer", "skeleton_crusader", "golem")]:
                pid = scml.pack_id(race, v)
                doc = scml.load_doc(race, v)
                row = []
                for it in items:
                    img = Image.open(GEAR_ROOT / "store" / f"{it['resourceName']}.png").convert("RGBA")
                    fit = dict(manifest["packs"][pid]["headFit"], nominalWidth=nominal["width"], anchorU=nominal["anchorU"], anchorV=nominal["anchorV"])
                    origin, size = doc.canvas(1.0)
                    row.append((f"{race} {it['name']}", scml.render_frame(doc, race, v, "Idle", 0, scale=0.3, head_overlay=(img, fit),
                                                                          canvas=(origin, size), background=qa.BG)))
                ims = qa.crop_to_content([im for _, im in row])
                rows.append([(l, i) for (l, _), i in zip(row, ims)])
            qa.sheet(rows).convert("RGB").save(SHEETS / "gear_headpieces.png", optimize=True)
            continue
        for ci in range(0, len(items), 5):
            chunk = items[ci:ci + 5]
            rows = []
            for race, v in (("valkyrie", 1), ("golem", 1), ("seer", 1), ("forest_ranger", 1)):
                doc = scml.load_doc(race, v)
                anim = "Shooting" if race == "forest_ranger" else "Slashing"
                frame = len(doc.animations[anim]) // 2
                ims = qa.crop_to_content([render_item(race, v, anim, frame, it, holds) for it in chunk])
                rows.append([(f"{race} {it['name']}", im) for it, im in zip(chunk, ims)])
            qa.sheet(rows).convert("RGB").save(SHEETS / f"gear_{group}{'' if len(items) <= 5 else '_' + str(ci // 5 + 1)}.png", optimize=True)
    # signature weapons on their own race + Titan comparison
    rows = []
    for it in by_group["signature"]:
        raw = it["id"].split(".", 1)[1]
        doc = scml.load_doc(raw, 1)
        anim = "Shooting" if it["kind"] == "bow" else "Slashing"
        mid = len(doc.animations[anim]) // 2
        row = []
        for label, a, f, t in (("idle", "Idle", 1, False), ("attack", anim, mid, False), ("titan 2x", anim, mid, True)):
            row.append((f"{it['name']} {label}", render_item(raw, 1, a, f, it, holds, titan=t)))
        ims = [qa.crop_to_content([im])[0] for _, im in row]   # each column has its own canvas (Titan is larger)
        rows.append([(l, i) for (l, _), i in zip(row, ims)])
    qa.sheet(rows).convert("RGB").save(SHEETS / "gear_signature.png", optimize=True)


def main() -> None:
    manifest = analyze()
    (OUT / "modular_gear_manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
    summary = {"items": len(manifest["items"]),
               "candidate": sum(i["verification"]["status"] == "candidate" for i in manifest["items"]),
               "mapped": [i["id"] for i in manifest["items"] if i["verification"]["status"] != "candidate"],
               "titanGrowthMax": max(max(i["verification"]["automated"]["canvasGrowth"]["titan"]) for i in manifest["items"] if i["kind"] not in ("shield", "headpiece"))}
    print(json.dumps(summary, indent=1)[:1500])
    if "--no-sheets" not in sys.argv:
        sheets(manifest)


if __name__ == "__main__":
    main()
