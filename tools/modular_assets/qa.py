"""Visual + numeric QA for separated packs."""
from __future__ import annotations

from typing import Dict, List, Tuple

import numpy as np
from PIL import Image, ImageDraw

import imgops as ops
import scml
from separate import PackSeparation, provider_for

BG = (58, 58, 68, 255)
REGION_COLORS = {"skin": (230, 170, 120), "hair": (220, 60, 220), "eyes": (60, 200, 255),
                 "primary": (235, 60, 60), "secondary": (70, 200, 90), "trim": (70, 110, 240),
                 "leather": (240, 220, 60), "emissive": (255, 255, 255)}


def render_set(sep: PackSeparation, animation: str, frame: int, scale: float = 0.5) -> Dict[str, Image.Image]:
    doc = scml.load_doc(sep.race_dir, sep.variant)
    r = lambda **kw: scml.render_frame(doc, sep.race_dir, sep.variant, animation, frame, scale=scale, background=BG, **kw)
    return {
        "original": r(),
        "anatomy only": r(provider=provider_for(sep, hide_kinds=("armor", "headgear")), hide=("sword", "bow", "arrow", "shield")),
        "armor only": r(provider=provider_for(sep, hide_kinds=("anatomy",)), hide=("sword", "bow", "arrow", "shield")),
        "recomposite": r(provider=provider_for(sep)),
    }


def reassembly_error(sep: PackSeparation, animations=("Idle",), frames=(0, 2)) -> Tuple[float, float, float]:
    """(max abs diff, mean abs diff, fraction of pixels differing by >0.1) original vs recomposite."""
    doc = scml.load_doc(sep.race_dir, sep.variant)
    worst, total, n, bad = 0.0, 0.0, 0, 0.0
    for a in animations:
        if a not in doc.animations:
            continue
        for f in frames:
            f = f % len(doc.animations[a])
            o = np.asarray(scml.render_frame(doc, sep.race_dir, sep.variant, a, f, scale=0.5, background=(0, 0, 0, 255)), np.float32) / 255
            m = np.asarray(scml.render_frame(doc, sep.race_dir, sep.variant, a, f, scale=0.5, background=(0, 0, 0, 255),
                                             provider=provider_for(sep)), np.float32) / 255
            d = np.abs(o - m)
            worst, total, n = max(worst, float(d.max())), total + float(d.mean()), n + 1
            bad += float((d.max(axis=-1) > 0.1).mean())
    return worst, total / max(n, 1), bad / max(n, 1)


def mask_overlay(layer, scale: float = 1.0) -> Image.Image:
    rgb, a = ops.arrays(layer.image)
    g = ops.lum(rgb)[..., None]
    out = np.repeat(g * 0.55 + 0.1, 3, axis=-1)
    for name, m in layer.masks.items():
        mv = (np.asarray(m, np.float32) / 255.0)[..., None]
        col = np.array(REGION_COLORS[name], np.float32) / 255.0
        out = out * (1 - mv * 0.75) + (col * (g * 0.9 + 0.35)) * mv * 0.75
    img = ops.from_arrays(out, a)
    bg = Image.new("RGBA", img.size, BG)
    bg.alpha_composite(img)
    return bg


def recolor(img: Image.Image, masks: Dict[str, Image.Image], tones: Dict[str, List[float]],
            colors: Dict[str, Tuple[float, float, float]]) -> Image.Image:
    """Reference implementation of the on-device recolor (RecolorMath.recolor): OKLab, shading-preserving."""
    rgb, a = ops.arrays(img)
    out = ops.recolor_materials(rgb, masks, tones, colors)
    return ops.from_arrays(out.astype(np.float32), a)


def sheet(rows: List[List[Tuple[str, Image.Image]]], cell_w: int = 0, label_h: int = 16) -> Image.Image:
    col_w = max(i.width for r in rows for _, i in r)
    row_h = [max(i.height for _, i in r) + label_h for r in rows]
    W = col_w * max(len(r) for r in rows)
    out = Image.new("RGBA", (W, sum(row_h)), BG)
    d = ImageDraw.Draw(out)
    y = 0
    for r, rh in zip(rows, row_h):
        for c, (label, im) in enumerate(r):
            d.text((c * col_w + 4, y + 2), label, fill=(240, 240, 240, 255))
            out.alpha_composite(im, (c * col_w, y + label_h))
        y += rh
    return out


def crop_to_content(images: List[Image.Image], pad: int = 6) -> List[Image.Image]:
    """Crop all images to the union bbox of the first image's non-background pixels."""
    a = np.asarray(images[0].convert("RGB"), np.int16)
    diff = np.abs(a - np.array(BG[:3])).sum(-1) > 12
    ys, xs = np.nonzero(diff)
    box = (max(xs.min() - pad, 0), max(ys.min() - pad, 0), min(xs.max() + pad, a.shape[1]), min(ys.max() + pad, a.shape[0]))
    return [i.crop(box) for i in images]


TEST_COLORS = {"skin": (0.62, 0.34, 0.80), "hair": (0.95, 0.2, 0.75), "eyes": (0.2, 0.9, 0.9),
               "primary": (0.86, 0.14, 0.14), "secondary": (0.14, 0.70, 0.26), "trim": (0.2, 0.36, 0.95),
               "leather": (0.95, 0.82, 0.18), "emissive": (1.0, 1.0, 1.0)}


def recolored_provider(sep: PackSeparation, colors=None):
    colors = colors or TEST_COLORS
    cache = {}
    base = provider_for(sep)
    by_part = {}
    for layer in sep.layers + sep.faces:
        by_part.setdefault(layer.part, []).append(layer)
    order = {"anatomy": 0, "armor": 1, "headgear": 1, "face": 1}

    def provide(p):
        stem = p.file.stem
        if stem not in by_part:
            return None
        out = []
        for l in sorted(by_part[stem], key=lambda l: order[l.kind]):
            key = (stem, l.kind)
            if key not in cache:
                cache[key] = recolor(l.image, l.masks, l.region_tone, colors)
            out.append(cache[key])
        return out
    return provide


def recolor_set(sep: PackSeparation, animation: str = "Idle", frame: int = 0, scale: float = 0.4):
    doc = scml.load_doc(sep.race_dir, sep.variant)
    return scml.render_frame(doc, sep.race_dir, sep.variant, animation, frame, scale=scale, background=BG,
                             provider=recolored_provider(sep))
