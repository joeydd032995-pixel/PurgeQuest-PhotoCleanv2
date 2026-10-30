"""Small NumPy/Pillow image helpers (no SciPy/OpenCV dependency)."""
from __future__ import annotations

from collections import deque
from typing import Tuple

import numpy as np
from PIL import Image, ImageFilter

LUMA = np.array([0.299, 0.587, 0.114], dtype=np.float32)


def arrays(img: Image.Image) -> Tuple[np.ndarray, np.ndarray]:
    a = np.asarray(img.convert("RGBA"), dtype=np.float32) / 255.0
    return a[..., :3], a[..., 3]


def from_arrays(rgb: np.ndarray, alpha: np.ndarray) -> Image.Image:
    out = np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[..., None]], axis=-1)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def lum(rgb: np.ndarray) -> np.ndarray:
    return rgb @ LUMA


def _morph(mask: np.ndarray, r: int, op) -> np.ndarray:
    if r <= 0:
        return mask
    im = Image.fromarray((mask.astype(np.uint8)) * 255)
    return np.asarray(im.filter(op(2 * r + 1))) > 127


def erode(mask: np.ndarray, r: int) -> np.ndarray:
    return _morph(mask, r, ImageFilter.MinFilter)


def dilate(mask: np.ndarray, r: int) -> np.ndarray:
    return _morph(mask, r, ImageFilter.MaxFilter)


def blur(arr: np.ndarray, radius: float) -> np.ndarray:
    im = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255.0


def label(mask: np.ndarray) -> Tuple[np.ndarray, int]:
    """4-connected component labelling. Returns (labels, count); 0 is background."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    flat = mask.ravel()
    lab = labels.ravel()
    count = 0
    for start in np.flatnonzero(flat):
        if lab[start]:
            continue
        count += 1
        lab[start] = count
        queue = deque([start])
        while queue:
            i = queue.popleft()
            x = i % w
            for j in (i - w, i + w, i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1):
                if 0 <= j < flat.size and flat[j] and not lab[j]:
                    lab[j] = count
                    queue.append(j)
    return labels, count


def rgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124564, 0.3575761, 0.1804375],
                  [0.2126729, 0.7151522, 0.0721750],
                  [0.0193339, 0.1191920, 0.9503041]], dtype=np.float32)
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883], dtype=np.float32)
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)


def measure_outline(rgb: np.ndarray, alpha: np.ndarray, max_r: int = 16) -> Tuple[int, np.ndarray]:
    """Estimate outline thickness (px) and colour from the silhouette boundary rings."""
    solid = alpha > 0.5
    prev = solid
    width = 2
    ring_colors = []
    for k in range(1, max_r):
        cur = erode(prev, 1)
        ring = prev & ~cur
        if ring.sum() == 0:
            break
        mean_l = float(lum(rgb)[ring].mean())
        if mean_l > 0.34 and k > 1:
            width = k - 1
            break
        ring_colors.append(rgb[ring].mean(axis=0))
        width = k
        prev = cur
    color = np.median(np.array(ring_colors), axis=0) if ring_colors else np.array([0.1, 0.1, 0.12], np.float32)
    return max(2, width), color.astype(np.float32)


def outline_mask(rgb: np.ndarray, alpha: np.ndarray, dark_thresh: float = 0.22, thick: int = 7) -> np.ndarray:
    """Dark *thin* strokes. Thick dark areas (black robes) are fills, not outline."""
    dark = (lum(rgb) < dark_thresh) & (alpha > 0.5)
    fill_dark = erode(dark, thick)
    fill_dark = dilate(fill_dark, thick + 1) & dark
    return dark & ~fill_dark


def smoothstep(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    t = np.clip((x - lo) / max(hi - lo, 1e-6), 0, 1)
    return t * t * (3 - 2 * t)


def convex_hull_mask(mask: np.ndarray) -> np.ndarray:
    """Rasterized convex hull of a boolean mask (Andrew monotone chain)."""
    from PIL import ImageDraw
    ys, xs = np.nonzero(mask)
    if len(xs) < 3:
        return mask
    pts = sorted(set(zip(xs.tolist(), ys.tolist())))

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    hull = lower[:-1] + upper[:-1]
    im = Image.new("L", (mask.shape[1], mask.shape[0]), 0)
    ImageDraw.Draw(im).polygon(hull, fill=255)
    return np.asarray(im) > 127
