"""Gear material masks, algorithm ``chroma-cells-v5`` (the "v5" asset set).

Same interface as ``gear_materials`` (authored-surfaces-v1) so ``held_gear.py`` and ``validate.py`` can use either; every
gear item records which algorithm made its masks, and ``validate.py`` checks it against *that* algorithm's own gate.

How it works (derived from the asset pass that produced v5, kept verbatim so the committed masks regenerate exactly):
  * line work is found from the sprite itself: strokes, junction blobs, the dark glow band along the edge, and rings of the
    outline's own colour (a doubled stroke), but a dark pixel is line work only if it is near the measured outline colour,
    so dark wood and navy cloth stay paintable;
  * paintable pixels are clustered on a lightness-independent chromaticity, close clusters and same-hue tints merge, and
    inside one outline-bounded cell a same-hue split is shading and merges too, so one material is one region however it is
    shaded; masks are soft partitions of unity that are exactly zero on line work.

Unlike authored-surfaces-v1 this does not protect very dark *fill* (dark planks recolour); its gate checks the opposite
guarantees: no weight on line work, none outside the sprite's alpha, no overlap, and near-complete coverage of the rest.
"""
from __future__ import annotations

import math
from types import SimpleNamespace
from typing import Dict, List, Optional, Tuple

import numpy as np
from PIL import Image

import imgops as ops

ALGORITHM = "chroma-cells-v5"


def _measure_outline(rgb: np.ndarray, alpha: np.ndarray, max_r: int = 16, lum_limit: float = 0.34) -> Tuple[int, np.ndarray]:
    """Estimate outline thickness (px) and colour from the silhouette boundary rings. A ring whose mean luminance
    exceeds lum_limit is already fill."""
    solid = alpha > 0.5
    prev = solid
    width = 2
    ring_colors = []
    for k in range(1, max_r):
        cur = ops.erode(prev, 1)
        ring = prev & ~cur
        if ring.sum() == 0:
            break
        mean_l = float(ops.lum(rgb)[ring].mean())
        if mean_l > lum_limit and k > 1:
            width = k - 1
            break
        ring_colors.append(rgb[ring].mean(axis=0))
        width = k
        prev = cur
    color = np.median(np.array(ring_colors), axis=0) if ring_colors else np.array([0.1, 0.1, 0.12], np.float32)
    return max(2, width), color.astype(np.float32)


def _disk_offsets(r: int):
    return [(dy, dx) for dy in range(-r, r + 1) for dx in range(-r, r + 1) if dy * dy + dx * dx <= r * r + r]


def _disk_erode(mask: np.ndarray, r: int) -> np.ndarray:
    """Erosion by a round window. Square windows cut thin dark fills into rectangular steps."""
    h, w = mask.shape
    pad = np.zeros((h + 2 * r, w + 2 * r), bool)
    pad[r:r + h, r:r + w] = mask
    out = np.ones((h, w), bool)
    for dy, dx in _disk_offsets(r):
        out &= pad[r + dy:r + dy + h, r + dx:r + dx + w]
    return out


def _disk_dilate(mask: np.ndarray, r: int) -> np.ndarray:
    h, w = mask.shape
    pad = np.zeros((h + 2 * r, w + 2 * r), bool)
    pad[r:r + h, r:r + w] = mask
    out = np.zeros((h, w), bool)
    for dy, dx in _disk_offsets(r):
        out |= pad[r + dy:r + dy + h, r + dx:r + dx + w]
    return out


def _edge_depth(solid: np.ndarray, limit: int) -> np.ndarray:
    """Pixels from the silhouette edge (1 = outermost ring), capped at limit + 1."""
    depth = np.full(solid.shape, limit + 1, np.int32)
    cur = solid
    for k in range(1, limit + 1):
        nxt = ops.erode(cur, 1)
        depth[cur & ~nxt] = k
        cur = nxt
        if not cur.any():
            break
    return depth


def _fill_holes(mask: np.ndarray) -> np.ndarray:
    """mask plus every background region that does not touch the image border."""
    labels, n = ops.label(~mask)
    if n == 0:
        return mask
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])).tolist())
    holes = np.isin(labels, [i for i in range(1, n + 1) if i not in border])
    return mask | holes


def _outline_mask(rgb: np.ndarray, alpha: np.ndarray, dark_thresh: float = 0.22, thick: int = 0) -> np.ndarray:
    """Dark *line work*. Thin strokes are outline; so are the small dark blobs where strokes meet (junctions are wider
    than a stroke but nowhere near the area of a real dark fill). Only dark regions clearly thicker than the stroke and
    big enough to be a fill (black robes, dark shading) are treated as fill, so they stay recolorable. The window is
    round and sized from the measured stroke width: a square one cuts thin dark strips into rectangular steps."""
    # A stricter ring limit than the default: dark wood (lum ~0.3) must not be mistaken for outline, which would
    # inflate the stroke width and contaminate the outline colour.
    width, line_color = _measure_outline(rgb, alpha, lum_limit=0.26)
    # Dark is not the same as line work: dark brown planks or a navy robe are fill. Only pixels near the sprite's own
    # outline colour (or faint, mostly transparent edge pixels) are candidates.
    off_line = (np.abs(rgb - line_color).max(axis=-1) > 0.09) & (alpha > 0.5)
    dark_all = (ops.lum(rgb) < dark_thresh) & (alpha > 0.08) & ~off_line   # includes the faint anti-aliased halo
    dark = dark_all & (alpha > 0.5)
    thick = thick or max(7, (width + 1) // 2 + 3)
    fill_dark = _disk_dilate(_disk_erode(dark, thick), thick + 1) & dark
    if fill_dark.any():
        min_area = max(300, int(14 * width * width))
        labels, n = ops.label(fill_dark)
        if n:
            sizes = np.bincount(labels.ravel(), minlength=n + 1)
            keep = np.zeros(n + 1, bool)
            keep[1:] = sizes[1:] >= min_area
            fill_dark = keep[labels]
    # The outline can be thicker in places (a doubled stroke along the top of a shield) and often has a dark-grey
    # glow band outside it. Both are line work, whatever their thickness:
    #  - dark pixels within a stroke's width of the silhouette edge, and
    #  - pixels of exactly the outline's own colour that are connected to that edge.
    depth = _edge_depth(alpha > 0.5, width + 3)
    rim = (depth <= min(width + 2, 10)) & (ops.lum(rgb) < 0.32) & (alpha > 0.08)
    same_color = (np.abs(rgb - line_color).max(axis=-1) < 0.04) & (alpha > 0.5)
    if same_color.any():
        labels, n = ops.label(same_color)
        touching = np.unique(labels[(depth <= 2) & same_color])
        keep = np.zeros_like(same_color)
        for cid in touching[touching > 0]:
            comp = labels == cid
            # A stroke is a ring around some other fill. A solid near-black mass that encloses nothing (a black robe
            # or limb drawn in the outline's own colour) is fill, and is left to the thickness test above.
            if (_fill_holes(comp) & ~comp).sum() >= 0.25 * comp.sum():
                keep |= comp
        same_color = keep
    return (dark_all & ~fill_dark) | rim | same_color


MERGE_DISTANCE = 0.05


HUE_MERGE_DEGREES = 15.0


HUE_MERGE_MIN_CHROMA = 0.03


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
    """Lightness-independent chromaticity (OKLab a, b over lightness + 0.25). A light and a dark shade of one material
    (a lit plank and a shaded one, a rim and its highlight stripes) land at the same point, so shading never splits
    a material across regions; different hues and neutral-versus-coloured stay apart."""
    lab = ops.rgb_to_oklab(rgb)
    return lab[..., 1:3] / (lab[..., 0:1] + 0.25)


def _cluster_hue(members: np.ndarray, units: np.ndarray, chroma: np.ndarray, c: int):
    """(mean hue direction as a unit vector, mean chroma) of cluster c."""
    sel = members == c
    v = units[sel].mean(axis=0) if sel.any() else np.zeros(2)
    return v / max(float(np.linalg.norm(v)), 1e-9), (float(chroma[sel].mean()) if sel.any() else 0.0)


def _merge_close(centers: np.ndarray, members: np.ndarray, tau: float, units: np.ndarray = None,
                 chroma: np.ndarray = None):
    """Merge clusters that are one material, so a single material is never cut into several regions just because
    k-means was asked for k: centres closer than tau, or two clearly coloured clusters of the same hue (a highlight
    tint is a paler, less saturated version of its base). Returns (centers, members) with members relabelled."""
    centers = [c.copy() for c in centers]
    members = members.copy()
    cos_tol = math.cos(math.radians(HUE_MERGE_DEGREES))
    while len(centers) > 1:
        best = None
        for i in range(len(centers)):
            for j in range(i + 1, len(centers)):
                d = float(np.linalg.norm(centers[i] - centers[j]))
                same = d < tau
                if not same and units is not None:
                    (ui, ci), (uj, cj) = _cluster_hue(members, units, chroma, i), _cluster_hue(members, units, chroma, j)
                    same = ci >= HUE_MERGE_MIN_CHROMA and cj >= HUE_MERGE_MIN_CHROMA and float(ui @ uj) >= cos_tol
                if same and (best is None or d < best[0]):
                    best = (d, i, j)
        if best is None:
            break
        _, i, j = best
        ni, nj = int((members == i).sum()), int((members == j).sum())
        centers[i] = (centers[i] * ni + centers[j] * nj) / max(ni + nj, 1)
        members[members == j] = i
        members[members > j] -= 1
        centers.pop(j)
    return np.array(centers), members


def _layer_weight(img: Image.Image):
    """(rgb, alpha, body, weight, outline). `weight` keeps dark *shading* (the OKLab recolor handles it) and
    removes only the thin dark outline strokes, softly, so masks never reach the linework."""
    rgb, alpha = ops.arrays(img)
    outline = _outline_mask(rgb, alpha)
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
        pts, lights, chromas, dirs = [], [], [], []
        for l in layers:
            rgb, alpha, body, _, _ = _layer_weight(l.image)
            if body.sum() < 30:
                continue
            lab = ops.rgb_to_oklab(rgb)
            f = (lab[..., 1:3] / (lab[..., 0:1] + 0.25))[body]
            light, chroma_px = lab[..., 0][body], np.hypot(lab[..., 1], lab[..., 2])[body]
            unit = lab[..., 1:3][body] / np.maximum(chroma_px, 1e-9)[:, None]
            # sample in proportion to area, so the primary/secondary ranking follows real pixel area
            take = np.random.default_rng(5).choice(len(f), min(len(f), max(2000, len(f) // 3)), replace=False)
            pts.append(f[take]); lights.append(light[take]); chromas.append(chroma_px[take]); dirs.append(unit[take])
        self.valid = bool(pts)
        if not self.valid:
            return
        feat, light, chroma_px, units = (np.concatenate(pts), np.concatenate(lights), np.concatenate(chromas),
                                         np.concatenate(dirs))
        k = min(max_regions, 4)
        centers = _kmeans(feat, k)
        hard = ((feat[:, None, :] - centers[None]) ** 2).sum(-1).argmin(1)
        self.centers, hard = _merge_close(centers, hard, MERGE_DISTANCE, units, chroma_px)
        k = len(self.centers)
        areas = np.array([(hard == c).mean() for c in range(k)])
        self.keep = [int(c) for c in np.argsort(-areas) if areas[c] >= 0.04] or [int(np.argmax(areas))]
        order, names = ["primary", "secondary", "trim", "leather"], []
        for c in self.keep:
            sel = hard == c
            if chroma_px[sel].mean() >= 0.15 and light[sel].mean() >= 0.72 and "emissive" not in names:
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


# ---------------------------------------------------------------- public interface (same shape as gear_materials)

def protected_ink(image, exterior=True):
    """Line work: weight is exactly zero here. (``exterior`` exists for interface parity; the glow band is always line work.)"""
    rgb, alpha = ops.arrays(image)
    return _outline_mask(rgb, alpha)


def masks_for(resource, image):
    masks, _ = RegionModel([SimpleNamespace(image=image)]).masks(image)
    return masks, protected_ink(image)


def quality(image, masks, protected):
    """Measure the emitted masks against source alpha and line work."""
    _, alpha = ops.arrays(image)
    total = sum((np.asarray(m, np.float64) / 255 for m in masks.values()), np.zeros(alpha.shape))
    paint = (alpha > .95) & ~protected
    return {
        "algorithm": ALGORITHM,
        "coverage": round(float(np.clip(total, 0, 1)[paint].mean()), 6) if paint.any() else 0.0,
        "protectedLeak": round(float(total[protected].max()), 6) if protected.any() else 0.0,
        "alphaLeak": round(float(np.maximum(total - alpha, 0).max()), 6),
        "overlap": round(float(np.maximum(total - 1, 0).max()), 6),
    }


def quality_passes(metrics):
    return (metrics["coverage"] >= COVERAGE_MIN and metrics["protectedLeak"] == 0
            and metrics["alphaLeak"] <= .02 and metrics["overlap"] <= .02)


# The same floor as authored-surfaces-v1. Measured on all 99 items: min 0.851, median 0.950, no weight on line work.
COVERAGE_MIN = 0.80
