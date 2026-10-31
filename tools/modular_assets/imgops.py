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


def outline_mask(rgb: np.ndarray, alpha: np.ndarray, dark_thresh: float = 0.22, thick: int = 0) -> np.ndarray:
    """Dark *line work*. Thin strokes are outline; so are the small dark blobs where strokes meet (junctions are wider
    than a stroke but nowhere near the area of a real dark fill). Only dark regions clearly thicker than the stroke and
    big enough to be a fill (black robes, dark shading) are treated as fill, so they stay recolorable. The window is
    round and sized from the measured stroke width: a square one cuts thin dark strips into rectangular steps."""
    dark_all = (lum(rgb) < dark_thresh) & (alpha > 0.08)    # includes the faint anti-aliased halo around the silhouette
    dark = dark_all & (alpha > 0.5)
    width, _ = measure_outline(rgb, alpha)
    thick = thick or max(7, (width + 1) // 2 + 3)
    fill_dark = _disk_dilate(_disk_erode(dark, thick), thick + 1) & dark
    if fill_dark.any():
        min_area = max(300, int(14 * width * width))
        labels, n = label(fill_dark)
        if n:
            sizes = np.bincount(labels.ravel(), minlength=n + 1)
            keep = np.zeros(n + 1, bool)
            keep[1:] = sizes[1:] >= min_area
            fill_dark = keep[labels]
    return dark_all & ~fill_dark


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


# ---------------------------------------------------------------- OKLab (shared with RecolorMath.swift)

def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def rgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
    lin = srgb_to_linear(rgb.astype(np.float64))
    r, g, b = lin[..., 0], lin[..., 1], lin[..., 2]
    l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], axis=-1)


def oklab_to_linear(lab: np.ndarray) -> np.ndarray:
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return np.stack([4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                     -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                     -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s], axis=-1)


def oklab_to_rgb(lab: np.ndarray) -> np.ndarray:
    return linear_to_srgb(oklab_to_linear(lab))


GAMUT_EPS = 1e-4
GAMUT_STEPS = 7


def fit_chroma(L: np.ndarray, c: np.ndarray, h: float) -> np.ndarray:
    """Largest chroma <= c (by 7-step bisection) whose colour is inside the sRGB gamut, so saturated targets
    desaturate instead of clipping and shifting hue. Mirrored step for step in RecolorMath.fitChroma."""
    ch, sh = np.cos(h), np.sin(h)

    def inside(cc):
        lin = oklab_to_linear(np.stack([L, cc * ch, cc * sh], axis=-1))
        return np.all((lin >= -GAMUT_EPS) & (lin <= 1 + GAMUT_EPS), axis=-1)
    ok = inside(c)
    lo, hi = np.zeros_like(c), c.copy()
    for _ in range(GAMUT_STEPS):
        mid = (lo + hi) / 2
        good = inside(mid)
        lo = np.where(good, mid, lo)
        hi = np.where(good, hi, mid)
    return np.where(ok, c, lo)


def soft_limit(x: np.ndarray, lo: float = 0.1, hi: float = 0.9) -> np.ndarray:
    """Identity inside [lo, hi]; compresses smoothly toward 0 and 1 outside so highlights/shadows never clip flat."""
    x = np.asarray(x, dtype=np.float64)
    up = hi + (1 - hi) * np.tanh((x - hi) / (1 - hi))
    dn = lo - lo * np.tanh((lo - x) / lo)
    return np.where(x > hi, up, np.where(x < lo, dn, x))


def recolor_pixels(rgb: np.ndarray, target_rgb, tone, mask: np.ndarray) -> np.ndarray:
    """Reference recolor (mirrored by RecolorMath.recolor in Swift).

    Inside the mask, lightness keeps its offset from the region's mean (so shading, highlights and texture survive)
    but is re-centred on the target's lightness; hue becomes the target's; chroma follows the target, modulated by how
    the source's chroma varied around its region mean and reduced near white/black. Outside the mask: unchanged.
    """
    lab = rgb_to_oklab(rgb)
    L, C = lab[..., 0], np.hypot(lab[..., 1], lab[..., 2])
    lm, cm = tone
    tl = rgb_to_oklab(np.array(target_rgb, dtype=np.float64))
    lt, ct, ht = tl[0], float(np.hypot(tl[1], tl[2])), float(np.arctan2(tl[2], tl[1]))
    lp = soft_limit(lt + (L - lm))
    ratio = np.clip(C / cm, 0.5, 1.6) if cm > 0.02 else np.ones_like(C)
    gam = np.clip(1 - 1.3 * np.maximum(0, lp - 0.85) - 1.3 * np.maximum(0, 0.2 - lp), 0.2, 1)
    cp = fit_chroma(lp, ct * ratio * gam, ht)
    new = oklab_to_rgb(np.stack([lp, cp * np.cos(ht), cp * np.sin(ht)], axis=-1))
    m = np.clip(mask, 0, 1)[..., None]
    return rgb * (1 - m) + new * m


def region_tone(rgb: np.ndarray, weight: np.ndarray):
    """Weighted mean OKLab lightness and chroma of a region."""
    w = weight.astype(np.float64)
    tot = w.sum()
    if tot <= 0:
        return None
    lab = rgb_to_oklab(rgb)
    return float((lab[..., 0] * w).sum() / tot), float((np.hypot(lab[..., 1], lab[..., 2]) * w).sum() / tot)
