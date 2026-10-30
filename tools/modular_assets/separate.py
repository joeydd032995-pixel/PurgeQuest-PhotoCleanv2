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
    region_luma: Dict[str, float] = field(default_factory=dict)   # region -> mean luminance

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


def _layer_weight(img: Image.Image):
    rgb, alpha = ops.arrays(img)
    outline = ops.outline_mask(rgb, alpha)
    soft_out = ops.blur(outline.astype(np.float32), 0.8)
    body = (alpha > 0.5) & ~outline
    weight = np.clip(alpha * (1 - soft_out), 0, 1)
    if body.sum() > 30:
        # pixels far darker than the layer's typical fill are outline-adjacent shadow: keep them out of recolor masks
        l = ops.lum(rgb)
        rel = l / max(float(np.median(l[body])), 0.05)
        weight = weight * ops.smoothstep(rel, 0.22, 0.5)
    return rgb, alpha, body, weight


class RegionModel:
    """Pack-wide clustering so 'primary' etc. mean the same material on every armor layer."""

    def __init__(self, layers: List["Layer"], max_regions: int = 4, hair_region: Optional[str] = None):
        pts = []
        for l in layers:
            rgb, alpha, body, _ = _layer_weight(l.image)
            if body.sum() < 30:
                continue
            f = _features(rgb)[body]
            take = np.random.default_rng(5).choice(len(f), min(len(f), 6000), replace=False)
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
        rgb, alpha, body, weight = _layer_weight(img)
        out, lumas = {}, {}
        if not self.valid or body.sum() < 30:
            return out, lumas
        feat = _features(rgb)
        d2 = ((feat[..., None, :] - self.centers[None, None]) ** 2).sum(-1)[..., self.keep]
        wgt = np.exp(-(d2 - d2.min(-1, keepdims=True)) / (2 * 7.0 ** 2))
        wgt /= wgt.sum(-1, keepdims=True)
        luma = ops.lum(rgb)
        for idx, nm in enumerate(self.names):
            if kind == "headgear" and self.hair_region == nm:
                nm = "hair"
            m = wgt[..., idx] * weight
            if m.sum() < 40:
                continue
            out[nm] = Image.fromarray((np.clip(m, 0, 1) * 255 + 0.5).astype(np.uint8), "L")
            lumas[nm] = float((luma * m).sum() / m.sum())
        return out, lumas


def skin_masks(img: Image.Image, name: str = "skin"):
    rgb, alpha, body, weight = _layer_weight(img)
    if body.sum() < 30:
        return {}, {}
    return ({name: Image.fromarray((weight * 255 + 0.5).astype(np.uint8), "L")}, {name: float(ops.lum(rgb)[body].mean())})


def eye_mask(img: Image.Image):
    """Iris/glow pixels of a face overlay: saturated, not blush-pink, not outline."""
    rgb, alpha, body, weight = _layer_weight(img)
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
    luma = ops.lum(rgb)
    return {"eyes": Image.fromarray((m * 255 + 0.5).astype(np.uint8), "L")}, {"eyes": float((luma * m).sum() / m.sum())}


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
    masks, lumas = skin_masks(img)
    return Layer(part, "anatomy", slot, img, masks, lumas)


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
        layer.masks, layer.region_luma = model.masks(layer.image, layer.kind)
    # bare head layers carry skin + (where the head is skin) nothing else
    faces: List[Layer] = []
    pid = scml.pack_id(race_dir, variant)
    for path in sorted(scml.pack_dir(race_dir, variant).glob(f"{pid}_face_0*.png")):
        stem = path.stem[len(pid) + 1:]
        img = Image.open(path).convert("RGBA")
        em, el = eye_mask(img)
        faces.append(Layer(stem, "face", "head", img, em, el))
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
