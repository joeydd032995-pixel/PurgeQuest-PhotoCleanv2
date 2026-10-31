"""Separate baked race parts into anatomy / armor / headgear layers plus material masks.

Strategy (see docs/superpowers/specs/2026-10-30-modular-gear-completion-design.md):
the art closes every region with a dark outline, so the head's skin "face window"
is found by flood-filling from the face overlay's centre. Anatomy layers are the
window pixels (head) or a bare silhouette in the pack's skin/bone/stone palette
(torso, limbs). The baked part (with the window cut out for the head) is the
armor layer. Reassembly (anatomy under armor) reproduces the original part.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

import numpy as np
from PIL import Image

import imgops as ops
import scml

REGIONS = ("skin", "hair", "eyes", "primary", "secondary", "trim", "leather", "emissive")

# Original SCML part stem -> (anatomy slot, armor slot, armor label)
PART_SLOTS = {
    "head": ("head", "helmet"),
    "body": ("torso", "chestArmor"),
    "left_arm": ("leftArm", "leftShoulder"),
    "right_arm": ("rightArm", "rightShoulder"),
    "left_hand": ("leftHand", "leftGauntlet"),
    "right_hand": ("rightHand", "rightGauntlet"),
    "left_leg": ("leftLeg", "leftLegArmor"),
    "right_leg": ("rightLeg", "rightLegArmor"),
}


@dataclass
class Layer:
    part: str                 # original part stem
    kind: str                 # anatomy | armor | headgear
    slot: str                 # CharacterSlot raw value
    image: Image.Image        # RGBA, same pixel size as the original part
    masks: Dict[str, Image.Image] = field(default_factory=dict)   # region -> L
    region_tone: Dict[str, List[float]] = field(default_factory=dict)   # region -> [mean OKLab L, mean OKLab chroma]
    mask_outline: Optional[np.ndarray] = None   # authored ink policy, when dark fabric resembles linework

    @property
    def suffix(self) -> str:
        return "headgear" if self.kind == "headgear" else self.kind


@dataclass
class PackSeparation:
    race_dir: str
    variant: int
    layers: List[Layer]
    notes: List[str]
    skin_color: Tuple[float, float, float]
    window_found: bool
    faces: List[Layer] = field(default_factory=list)

    @property
    def pid(self) -> str:
        return scml.pack_id(self.race_dir, self.variant)


# ---------------------------------------------------------------- geometry

def face_seed_in_head(doc: scml.Doc, head_size: Tuple[int, int]) -> Optional[Tuple[int, int]]:
    """Project the face overlay's centre into head image pixel coordinates (frame 0 of Idle)."""
    frame = doc.animations["Idle"][0]
    head = next((p for p in frame if p.file.stem == "head"), None)
    face = next((p for p in frame if p.file.stem.startswith("face")), None)
    if not head or not face:
        return None
    # face image centre relative to its pivot (y-up): dx=(0.5-pivotX)*w, dy=(0.5-pivotY)*h
    cx = (0.5 - face.pivot_x) * face.file.width
    cy = (0.5 - face.pivot_y) * face.file.height
    r = math.radians(face.angle)
    wx = face.x + cx * math.cos(r) - cy * math.sin(r)
    wy = face.y + cx * math.sin(r) + cy * math.cos(r)
    # into head local (y-up), un-rotate
    dx, dy = wx - head.x, wy - head.y
    r = math.radians(-head.angle)
    lx = dx * math.cos(r) - dy * math.sin(r)
    ly = dx * math.sin(r) + dy * math.cos(r)
    u = lx + head.pivot_x * head.file.width
    v = (1 - head.pivot_y) * head.file.height - ly
    sx, sy = head_size[0] / head.file.width, head_size[1] / head.file.height
    return int(round(u * sx)), int(round(v * sy))


def nearest_open(mask: np.ndarray, x: int, y: int, limit: int = 60) -> Optional[Tuple[int, int]]:
    h, w = mask.shape
    x, y = min(max(x, 0), w - 1), min(max(y, 0), h - 1)
    for r in range(limit):
        ys, xs = slice(max(0, y - r), min(h, y + r + 1)), slice(max(0, x - r), min(w, x + r + 1))
        sub = np.argwhere(mask[ys, xs])
        if len(sub):
            d = ((sub[:, 0] + ys.start - y) ** 2 + (sub[:, 1] + xs.start - x) ** 2)
            j = int(np.argmin(d))
            return int(sub[j, 1] + xs.start), int(sub[j, 0] + ys.start)
    return None


# ---------------------------------------------------------------- masks

def _kmeans(feat: np.ndarray, k: int, iters: int = 14) -> np.ndarray:
    rng = np.random.default_rng(7)
    centers = [feat[rng.integers(len(feat))]]
    for _ in range(1, k):
        d = np.min([((feat - c) ** 2).sum(1) for c in centers], axis=0)
        centers.append(feat[int(np.argmax(d + rng.random(len(d)) * 1e-3))])
    centers = np.array(centers)
    for _ in range(iters):
        d = ((feat[:, None, :] - centers[None]) ** 2).sum(-1)
        assign = d.argmin(1)
        for c in range(k):
            sel = feat[assign == c]
            if len(sel):
                centers[c] = sel.mean(0)
    return centers


def _features(rgb: np.ndarray) -> np.ndarray:
    lab = ops.rgb_to_lab(rgb)
    return np.concatenate([lab[..., 1:3], 0.12 * lab[..., 0:1]], axis=-1)


def _layer_weight(img: Image.Image, ink_palette: bool = False, protect_ink: bool = False):
    """(rgb, alpha, body, weight, outline). `weight` keeps dark *shading* (the OKLab recolor handles it) and
    removes only the thin dark outline strokes, softly, so masks never reach the linework."""
    rgb, alpha = ops.arrays(img)
    if ink_palette:
        # These three packs use near-neutral #1a1917 ink. Their navy cloth
        # is dark but chromatic: treating all dark pixels as ink leaves
        # sleeves/boots uncoloured with only their decorations changing.
        near_ink = np.linalg.norm(rgb * 255 - np.array([26, 25, 23]), axis=-1) < 16
        outline = ((ops.lum(rgb) < 0.10) | near_ink) & (alpha > 0.08)
    else:
        outline = ops.outline_mask(rgb, alpha)
    if protect_ink:
        outline |= (np.linalg.norm(rgb * 255 - np.array([26, 25, 23]), axis=-1) < 16) & (alpha > 0.08)
    soft_out = ops.blur(outline.astype(np.float32), 0.8)
    body = (alpha > 0.5) & ~outline
    # outline pixels get exactly zero; the feather lives on the fill side, so linework is never tinted
    weight = np.clip(alpha * (1 - np.maximum(outline.astype(np.float32), soft_out)), 0, 1)
    return rgb, alpha, body, weight, outline


def _adhesive_labels(hard: np.ndarray, alpha: np.ndarray, outline: np.ndarray, k: int) -> np.ndarray:
    """Region label per pixel (-1 = none). Confident interior pixels keep their own colour-based label; pixels that
    sit next to an outline or the silhouette edge (anti-aliased blends of fill and linework, whose colour is
    misleading) inherit the label of the nearest interior pixel; a 5x5 vote removes isolated speckle."""
    from PIL import ImageFilter
    region = alpha > 0.08
    todo = region & ~outline
    near = ops.dilate(outline, 2) | ~ops.erode(alpha > 0.9, 2)
    interior = todo & ~near
    labels = np.full(hard.shape, -1, np.int16)
    if interior.sum() < 20:
        interior = todo
    labels[interior] = hard[interior]
    for _ in range(8):
        unl = todo & (labels < 0)
        if not unl.any():
            break
        for idx in range(k):
            take = unl & (labels < 0) & ops.dilate(labels == idx, 1)
            labels[take] = idx
    counts = np.stack([
        np.asarray(Image.fromarray(((labels == i) & todo).astype(np.uint8) * 255).filter(ImageFilter.BoxBlur(2)), np.float32)
        for i in range(k)], axis=-1)
    voted = counts.argmax(-1).astype(np.int16)
    return np.where(todo & (counts.sum(-1) > 0), voted, labels)


def merge_shading_splits(labels: np.ndarray, rgb: np.ndarray, alpha: np.ndarray, outline: np.ndarray, k: int,
                         hue_tol: float = 40.0, neutral_chroma: float = 0.035) -> np.ndarray:
    """One outline-bounded cell is one piece of material. When colour clustering splits a cell into labels whose hue is
    the same (a highlight or shadow on the same cloth, a stitched glyph in the same tone), the minority label is
    shading, not a second material, so it joins the cell's dominant label. A different hue (a gem, a lining) stays."""
    todo = (alpha > 0.08) & ~outline
    cells, n = ops.label(todo)
    if n == 0:
        return labels
    lab = ops.rgb_to_oklab(rgb)
    a, b = lab[..., 1].ravel(), lab[..., 2].ravel()
    flat_cells, flat_labels = cells.ravel(), labels.ravel()
    out = flat_labels.copy()
    order = np.argsort(flat_cells, kind="stable")
    bounds = np.searchsorted(flat_cells[order], np.arange(n + 2))
    for cid in range(1, n + 1):
        idx = order[bounds[cid]:bounds[cid + 1]]
        lbl = flat_labels[idx]
        ok = lbl >= 0
        if ok.sum() < 40:
            continue
        counts = np.bincount(lbl[ok], minlength=k)
        dom = int(counts.argmax())
        if counts[dom] < 0.4 * counts.sum() or (counts > 0).sum() < 2:
            continue
        dom_sel = ok & (lbl == dom)
        ad, bd = float(a[idx][dom_sel].mean()), float(b[idx][dom_sel].mean())
        cd, hd = math.hypot(ad, bd), math.degrees(math.atan2(bd, ad))
        for m in range(k):
            if m == dom or counts[m] == 0:
                continue
            sel = ok & (lbl == m)
            am, bm = float(a[idx][sel].mean()), float(b[idx][sel].mean())
            cm, hm = math.hypot(am, bm), math.degrees(math.atan2(bm, am))
            if cm < neutral_chroma and cd < neutral_chroma:
                same = True
            elif cm >= neutral_chroma and cd >= neutral_chroma:
                same = abs((hm - hd + 180.0) % 360.0 - 180.0) < hue_tol
            else:
                same = counts[m] < 0.05 * counts.sum()
            if same:
                out[idx[sel]] = dom
    return out.reshape(labels.shape)


def _soft_partition(labels: np.ndarray, k: int, weight: np.ndarray):
    """Soft, partition-of-unity masks from hard labels (gaussian-feathered), times the outline-excluding weight."""
    soft = [ops.blur((labels == i).astype(np.float32), 0.9) for i in range(k)]
    total = np.maximum(sum(soft), 1e-6)
    return [np.clip(s_ / total * weight, 0, 1) for s_ in soft]


class RegionModel:
    """Pack-wide clustering so 'primary' etc. mean the same material on every armor layer."""

    def __init__(self, layers: List["Layer"], max_regions: int = 4, hair_region: Optional[str] = None):
        pts = []
        for l in layers:
            rgb, alpha, body, _, _ = _layer_weight(l.image)
            if body.sum() < 30:
                continue
            f = _features(rgb)[body]
            # sample in proportion to area, so the primary/secondary ranking follows real pixel area
            take = np.random.default_rng(5).choice(len(f), min(len(f), max(2000, len(f) // 3)), replace=False)
            pts.append(f[take])
        self.valid = bool(pts)
        if not self.valid:
            return
        feat = np.concatenate(pts)
        k = min(max_regions, 4)
        self.centers = _kmeans(feat, k)
        d2 = ((feat[:, None, :] - self.centers[None]) ** 2).sum(-1)
        hard = d2.argmin(1)
        areas = np.array([(hard == c).mean() for c in range(k)])
        self.keep = [int(c) for c in np.argsort(-areas) if areas[c] >= 0.04] or [int(np.argmax(areas))]
        chroma = np.hypot(self.centers[:, 0], self.centers[:, 1])
        order, names = ["primary", "secondary", "trim", "leather"], []
        for c in self.keep:
            light = self.centers[c][2] / 0.12
            if chroma[c] > 52 and light > 58 and "emissive" not in names:
                names.append("emissive")
            else:
                names.append(order.pop(0) if order else "trim")
        self.names = names
        self.hair_region = hair_region

    def masks(self, img: Image.Image, kind: str = "armor"):
        rgb, alpha, body, weight, outline = _layer_weight(img)
        out: Dict[str, Image.Image] = {}
        if not self.valid or body.sum() < 30:
            return out, {}
        feat = _features(rgb)
        d2 = ((feat[..., None, :] - self.centers[None, None]) ** 2).sum(-1)[..., self.keep]
        hard = d2.argmin(-1).astype(np.int16)
        labels = _adhesive_labels(hard, alpha, outline, len(self.names))
        labels = merge_shading_splits(labels, rgb, alpha, outline, len(self.names))
        for idx, m in enumerate(_soft_partition(labels, len(self.names), weight)):
            nm = self.names[idx]
            if kind == "headgear" and self.hair_region == nm:
                nm = "hair"
            if m.sum() < 40:
                continue
            out[nm] = Image.fromarray((m * 255 + 0.5).astype(np.uint8), "L")
        return out, {}


def semantic_masks(img: Image.Image, spec: dict):
    """Authored material boundaries for art whose similarly coloured materials confuse clustering.

    Vote over connected fill cells, not individual pigment colours: a hood highlight and
    shadow are still the same cloth. Keep linework excluded and feather only on the fill
    side. Unoutlined details (Seer's gold runes) have an explicit source-palette rule.
    """
    from PIL import ImageDraw
    rgb, alpha, body, weight, outline = _layer_weight(img, spec.get("outline") == "ink_palette", protect_ink=True)
    names = list(dict.fromkeys([spec["default"]] + [p["region"] for p in spec.get("polygons", [])]))
    authored = Image.new("I", img.size, 0)
    draw = ImageDraw.Draw(authored)
    for polygon in spec.get("polygons", []):
        draw.polygon([tuple(p) for p in polygon["points"]], fill=names.index(polygon["region"]))
    hard = np.asarray(authored, dtype=np.int16)
    cells, count = ops.label(body)
    labels = hard.copy()
    for cell in range(1, count + 1) if spec.get("snap_cells", True) else ():
        pixels = cells == cell
        votes = np.bincount(hard[pixels], minlength=len(names))
        labels[pixels] = int(votes.argmax())
    labels[~body] = -1
    masks = dict(zip(names, _soft_partition(labels, len(names), weight)))
    for detail in spec.get("details", []):
        distance = np.min([np.linalg.norm(rgb * 255 - np.array(c), axis=-1) for c in detail["colors"]], axis=0)
        match = 1 - ops.smoothstep(distance, detail["tolerance"] / 2, detail["tolerance"])
        if "box" in detail:
            x0, y0, x1, y1 = detail["box"]
            yy, xx = np.mgrid[:alpha.shape[0], :alpha.shape[1]]
            match *= (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
        source = detail["within"]
        transfer = masks[source] * match
        masks[source] = masks[source] - transfer
        masks[detail["region"]] = masks.get(detail["region"], 0) + transfer
    return {name: Image.fromarray((np.clip(mask, 0, 1) * 255 + 0.5).astype(np.uint8), "L")
            for name, mask in masks.items() if mask.sum() >= 40}, {}


def apply_semantic_masks(pid: str, layers: List["Layer"]) -> None:
    import json
    from pathlib import Path
    specs = json.loads(Path(__file__).with_name("semantic_regions.json").read_text()).get(pid, {})
    for layer in layers:
        # Bare procedural anatomy keeps its skin mask. These rules apply to
        # the visible painted clothing/hair; original hands are anatomy-only.
        if layer.kind not in ("armor", "headgear") or layer.part not in specs:
            continue
        spec = specs[layer.part]
        layer.masks, layer.region_tone = semantic_masks(layer.image, spec)
        layer.mask_outline = _layer_weight(layer.image, spec.get("outline") == "ink_palette", protect_ink=True)[4]


def skin_masks(img: Image.Image, name: str = "skin"):
    rgb, alpha, body, weight, outline = _layer_weight(img)
    if body.sum() < 30:
        return {}, {}
    return {name: Image.fromarray((weight * 255 + 0.5).astype(np.uint8), "L")}, {}


def eye_mask(img: Image.Image):
    """Iris/glow pixels of a face overlay: saturated, not blush-pink, not outline."""
    rgb, alpha, body, weight, outline = _layer_weight(img)
    lab = ops.rgb_to_lab(rgb)
    chroma = np.hypot(lab[..., 1], lab[..., 2])
    hue = np.degrees(np.arctan2(lab[..., 2], lab[..., 1]))
    cool = (hue > 70) | (hue < -30)          # greens, cyans, blues, violets
    warm_strong = chroma > 42               # red/orange/amber irises and glows
    iris = (cool & (chroma > 14)) | warm_strong
    sc = ops.blur(iris.astype(np.float32), 0.8)
    m = np.clip(sc * weight, 0, 1)
    if m.sum() < 40:
        return {}, {}
    return {"eyes": Image.fromarray((m * 255 + 0.5).astype(np.uint8), "L")}, {}


def pool_tones(layers: List["Layer"]) -> None:
    """Pack-wide region tones (mean OKLab lightness and chroma). Every layer that has a region uses the *pooled* value,
    so parts of one material keep their relative brightness after a recolor instead of each being re-centred alone."""
    acc: Dict[str, List[float]] = {}
    for layer in layers:
        rgb, alpha = ops.arrays(layer.image)
        lab = ops.rgb_to_oklab(rgb)
        chroma = np.hypot(lab[..., 1], lab[..., 2])
        for region, mask in layer.masks.items():
            w = (np.asarray(mask, np.float32) / 255.0) * alpha
            a = acc.setdefault(region, [0.0, 0.0, 0.0])
            a[0] += float(w.sum()); a[1] += float((lab[..., 0] * w).sum()); a[2] += float((chroma * w).sum())
    pooled = {r: [round(a[1] / a[0], 5), round(a[2] / a[0], 5)] for r, a in acc.items() if a[0] > 0}
    for layer in layers:
        layer.region_tone = {r: pooled[r] for r in layer.masks if r in pooled}


# ---------------------------------------------------------------- layers

def _skin_chroma_match(rgb: np.ndarray, body: np.ndarray, ref_lab: np.ndarray, tol: float) -> float:
    lab = ops.rgb_to_lab(rgb)
    d = np.hypot(lab[..., 1] - ref_lab[1], lab[..., 2] - ref_lab[2])
    # allow only moderately lighter/darker shades of the reference
    ok = (d < tol) & (np.abs(lab[..., 0] - ref_lab[0]) < 38)
    return float(ok[body].mean()) if body.sum() else 0.0


def _bare_silhouette(img: Image.Image, skin: np.ndarray, erode_px: int, outline_w: int,
                     outline_color: np.ndarray, stroke_inset: bool = True) -> Image.Image:
    """Flat skin-filled silhouette inset from the baked part's silhouette, with outline."""
    rgb, alpha = ops.arrays(img)
    sil = alpha > 0.5
    core = ops.erode(sil, erode_px)
    if core.sum() < 20:
        core = ops.erode(sil, max(1, erode_px // 3))
    ring = ops.dilate(core, outline_w) & ~core
    out_rgb = np.where(core[..., None], skin, outline_color)
    out_a = ops.blur((core | ring).astype(np.float32), 0.8)
    return ops.from_arrays(out_rgb, out_a)


def load_overrides() -> dict:
    import json
    from pathlib import Path
    return json.loads((Path(__file__).with_name("overrides.json")).read_text())


def separate_pack(race_dir: str, variant: int, overrides: Optional[dict] = None) -> PackSeparation:
    overrides = overrides if overrides is not None else load_overrides().get(scml.pack_id(race_dir, variant), {})
    doc = scml.load_doc(race_dir, variant)
    base = scml.pack_dir(race_dir, variant)
    pid = scml.pack_id(race_dir, variant)
    notes: List[str] = []
    imgs = {s: Image.open(base / f"{pid}_{s}.png").convert("RGBA") for s in PART_SLOTS}
    layers: List[Layer] = []

    # ---- head: find the face window ---------------------------------
    head = imgs["head"]
    hrgb, halpha = ops.arrays(head)
    ow, ocolor = ops.measure_outline(hrgb, halpha)
    outline = ops.outline_mask(hrgb, halpha)
    open_px = (halpha > 0.5) & ~outline
    seed = face_seed_in_head(doc, head.size)
    window = None
    skin = None
    if seed is not None and "no_window" not in overrides.get("flags", []):
        s = nearest_open(open_px, *seed)
        if s is not None:
            # edge-preserving region: component of non-outline pixels near the seed colour
            seed_lab = ops.rgb_to_lab(hrgb)[s[1], s[0]]
            lab = ops.rgb_to_lab(hrgb)
            near = open_px & (np.hypot(lab[..., 1] - seed_lab[1], lab[..., 2] - seed_lab[2]) < overrides.get("window_tol", 16)) \
                & (np.abs(lab[..., 0] - seed_lab[0]) < overrides.get("window_ltol", 30))
            labels, n = ops.label(near)
            comp = labels == labels[s[1], s[0]]
            frac = comp.sum() / max(1, (halpha > 0.5).sum())
            if frac >= overrides.get("min_window_frac", 0.07) and frac <= overrides.get("max_window_frac", 0.62):
                window = ops.dilate(ops.erode(comp, 1), 1)
                # include blush spots / shading enclosed by the region
                filled = _fill_holes(window)
                window = filled & (halpha > 0.5)
                skin = np.median(hrgb[comp], axis=0).astype(np.float32)
                notes.append(f"window frac={frac:.2f}")
            else:
                notes.append(f"window rejected frac={frac:.2f}")
    if window is None and overrides.get("face_ellipse") and seed is not None:
        face = next(p for p in doc.animations["Idle"][0] if p.file.stem.startswith("face"))
        sx, sy = head.size[0] / next(p for p in doc.animations["Idle"][0] if p.file.stem == "head").file.width, 1.0
        rx, ry = 0.40 * face.file.width * sx, 0.44 * face.file.height * sx
        yy, xx = np.mgrid[0:hrgb.shape[0], 0:hrgb.shape[1]]
        window = ((((xx - seed[0]) / rx) ** 2 + ((yy - seed[1]) / ry) ** 2) <= 1) & (halpha > 0.5)
        skin = np.median(hrgb[window], axis=0).astype(np.float32)
        notes.append("window=face-ellipse fallback")
    if window is None:
        # skull / stone head: whole head is anatomy
        body_px = open_px
        skin = np.median(hrgb[body_px], axis=0).astype(np.float32) if body_px.sum() else np.array([.7, .6, .5], np.float32)
        layers.append(_anatomy_original("head", head, "head", hair_hint=False))
        return _finish(race_dir, variant, imgs, layers, notes, skin, False, overrides, ow, ocolor, doc)

    # head anatomy (bare head) + headgear (window cut out)
    anat, gear = _split_head(head, window, skin, ow, ocolor)
    am, al = skin_masks(anat)
    layers.append(Layer("head", "anatomy", "head", anat, am, al))
    layers.append(Layer("head", "headgear", "helmet", gear))
    return _finish(race_dir, variant, imgs, layers, notes, skin, True, overrides, ow, ocolor, doc)


def _fill_holes(mask: np.ndarray) -> np.ndarray:
    inv = ~mask
    labels, n = ops.label(inv)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])).tolist())
    holes = np.isin(labels, [i for i in range(1, n + 1) if i not in border])
    return mask | holes


def _split_head(head: Image.Image, window: np.ndarray, skin: np.ndarray, ow: int, ocolor: np.ndarray):
    rgb, alpha = ops.arrays(head)
    sil = alpha > 0.5
    ys, xs = np.nonzero(window)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    w, h = x1 - x0, y1 - y0
    yy, xx = np.mgrid[0:rgb.shape[0], 0:rgb.shape[1]]
    # cranium: at least as tall as a round head is wide, so beard/visor-bounded windows don't yield a flat block
    top = min(y0 - 0.74 * h, y1 - 0.95 * w)
    cx, cy = (x0 + x1) / 2, (top + y1) / 2
    ell = (((xx - cx) / (0.66 * w + 1)) ** 2 + ((yy - cy) / (max(y1 - top, 1) / 2 + 1)) ** 2) <= 1
    core = ((ell & (yy <= y1)) | window) & ops.erode(_fill_holes(sil), 2)
    core = _fill_holes(core)
    # round off flat cuts left by cheek-guards: hull, but never beyond the baked silhouette
    core = ops.convex_hull_mask(core) & ops.erode(_fill_holes(sil), 2)
    ring = ops.dilate(core, ow) & ~core
    anat_rgb = np.where(core[..., None], skin, ocolor)
    anat_rgb = np.where(window[..., None], rgb, anat_rgb)
    anat_a = ops.blur((core | ring).astype(np.float32), 0.8)
    anat_a = np.minimum(anat_a, ops.blur(ops.dilate(_fill_holes(sil), 1).astype(np.float32), 0.8))
    anat = ops.from_arrays(anat_rgb, anat_a)
    gear_a = np.where(window, 0.0, alpha)
    # keep a 1px antialiased rim where the cut meets the outline
    rim = ops.dilate(window, 1) & ~window
    gear_a = np.where(rim, np.minimum(alpha, 0.9 * alpha), gear_a)
    gear = ops.from_arrays(rgb, gear_a)
    return anat, gear


def _anatomy_original(part: str, img: Image.Image, slot: str, hair_hint: bool) -> Layer:
    masks, tones = skin_masks(img)
    return Layer(part, "anatomy", slot, img, masks, tones)


def _finish(race_dir, variant, imgs, layers, notes, skin, window_found, overrides, ow, ocolor, doc) -> PackSeparation:
    skin_lab = ops.rgb_to_lab(skin[None, None, :])[0, 0]
    # other parts
    for part in ("body", "left_arm", "right_arm", "left_hand", "right_hand", "left_leg", "right_leg"):
        img = imgs[part]
        rgb, alpha = ops.arrays(img)
        outline = ops.outline_mask(rgb, alpha)
        body = (alpha > 0.5) & ~outline
        anat_slot, armor_slot = PART_SLOTS[part]
        tol = overrides.get("anatomy_tol", max(8.0, 0.5 * float(np.hypot(skin_lab[1], skin_lab[2]))))
        match = _skin_chroma_match(rgb, body, skin_lab, tol)
        force = part in overrides.get("armor_parts", []) and "armor" or part in overrides.get("anatomy_parts", []) and "anatomy"
        is_anatomy = (match >= overrides.get("anatomy_match", 0.72)) if not force else (force == "anatomy")
        notes.append(f"{part}: skin-match={match:.2f} -> {'anatomy' if is_anatomy else 'armor'}")
        if is_anatomy:
            layers.append(_anatomy_original(part, img, anat_slot, False))
        else:
            ow_p, oc_p = ops.measure_outline(rgb, alpha)
            erode_px = overrides.get("erode", {}).get(part, max(ow_p + 3, int(0.06 * max(img.size))))
            anat = _bare_silhouette(img, skin, erode_px, ow_p, oc_p)
            m, l = skin_masks(anat)
            layers.append(Layer(part, "anatomy", anat_slot, anat, m, l))
            layers.append(Layer(part, "armor", armor_slot, img))
    # masks for armor/headgear layers: one model per pack so region names are consistent
    armor_layers = [l for l in layers if l.kind in ("armor", "headgear")]
    model = RegionModel(armor_layers, hair_region=overrides.get("hair_region"))
    for layer in armor_layers:
        layer.masks, layer.region_tone = model.masks(layer.image, layer.kind)
    apply_semantic_masks(scml.pack_id(race_dir, variant), layers)
    # bare head layers carry skin + (where the head is skin) nothing else
    faces: List[Layer] = []
    pid = scml.pack_id(race_dir, variant)
    for path in sorted(scml.pack_dir(race_dir, variant).glob(f"{pid}_face_0*.png")):
        stem = path.stem[len(pid) + 1:]
        img = Image.open(path).convert("RGBA")
        em, el = eye_mask(img)
        faces.append(Layer(stem, "face", "head", img, em, el))
    pool_tones(layers + faces)
    return PackSeparation(race_dir, variant, layers, notes, tuple(float(c) for c in skin), window_found, faces)


# ---------------------------------------------------------------- recomposite (QA)

def provider_for(sep: PackSeparation, hide_kinds=()):
    by_part: Dict[str, List[Layer]] = {}
    for layer in sep.layers:
        by_part.setdefault(layer.part, []).append(layer)
    order = {"anatomy": 0, "armor": 1, "headgear": 1}

    def provide(p: scml.Placement):
        stem = p.file.stem
        if stem in by_part:
            return [l.image for l in sorted(by_part[stem], key=lambda l: order[l.kind]) if l.kind not in hide_kinds]
        return None
    return provide
