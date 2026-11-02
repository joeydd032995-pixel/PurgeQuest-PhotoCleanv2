#!/usr/bin/env python3
"""Trace the six Bestiary family icons from the dark Bestiary mockup into vector assets.

  tools/design/trace_icons.py [--preview DIR]

Input : docs/design/mockups/bestiary-dark.jpg  (491x958 screenshot)
Output: ios/PurgeQuest/Assets.xcassets/Family-<name>.imageset/Family-<name>.svg   (template images)

Each icon is converted to a single-colour coverage map (distance from the tile's
own background colour), smoothed at 4x, thresholded, and traced with potrace.
The SVGs are plain paths, so the app tints them with the family accent colour
and they stay sharp at any size. Replace the SVGs with final art when it exists;
asset names are what the code uses.

Requires: Pillow, numpy, scipy, potracer (pure-Python potrace).
"""
import argparse
import json
from pathlib import Path

import numpy as np
import potrace
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "docs/design/mockups/bestiary-dark.jpg"
CATALOG = ROOT / "ios/PurgeQuest/Assets.xcassets"

# name -> crop box in the screenshot
ICONS = {
    "clutterUndead":    (22, 174, 128, 268),
    "archiveRelics":    (268, 174, 374, 268),
    "storageBehemoths": (22, 438, 158, 528),
    "duplicateDragons": (268, 438, 384, 528),
    "videoPhantoms":    (22, 702, 138, 792),
    "glitchborn":       (268, 702, 384, 792),
}
UP = 4


def coverage(crop: np.ndarray) -> np.ndarray:
    """0..1 'ink' amount: colour distance from the tile background, normalised to the strokes."""
    h, w, _ = crop.shape
    ring = np.concatenate([crop[:3].reshape(-1, 3), crop[-3:].reshape(-1, 3), crop[:, :3].reshape(-1, 3), crop[:, -3:].reshape(-1, 3)])
    bg = np.median(ring, axis=0)
    dist = np.linalg.norm(crop - bg, axis=2)
    return np.clip(dist / np.percentile(dist, 99.2), 0.0, 1.0)


def upsample(a: np.ndarray, sigma: float) -> np.ndarray:
    img = Image.fromarray(a.astype(np.float32), "F").resize((a.shape[1] * UP, a.shape[0] * UP), Image.BICUBIC)
    return ndi.gaussian_filter(np.asarray(img), sigma)


def clean(mask: np.ndarray, min_area: int) -> np.ndarray:
    labels, n = ndi.label(mask)
    if n == 0:
        return mask
    sizes = ndi.sum(mask, labels, range(1, n + 1))
    return np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= min_area])


def trace(mask: np.ndarray) -> tuple[str, tuple[int, int, int, int]]:
    ys, xs = np.where(mask)
    pad = 2 * UP
    x0, y0 = max(xs.min() - pad, 0), max(ys.min() - pad, 0)
    x1, y1 = min(xs.max() + pad + 1, mask.shape[1]), min(ys.max() + pad + 1, mask.shape[0])
    # potracer treats True as background, so trace the inverted mask.
    plist = potrace.Bitmap(~mask[y0:y1, x0:x1]).trace(turdsize=6, alphamax=1.2, opticurve=True, opttolerance=0.6)
    parts = []
    for curve in plist:
        s = curve.start_point
        parts.append(f"M{s.x:.1f} {s.y:.1f}")
        for seg in curve.segments:
            if seg.is_corner:
                parts.append(f"L{seg.c.x:.1f} {seg.c.y:.1f}L{seg.end_point.x:.1f} {seg.end_point.y:.1f}")
            else:
                parts.append(f"C{seg.c1.x:.1f} {seg.c1.y:.1f} {seg.c2.x:.1f} {seg.c2.y:.1f} {seg.end_point.x:.1f} {seg.end_point.y:.1f}")
        parts.append("Z")
    return "".join(parts), (x0, y0, x1, y1)


def write_imageset(name: str, svg: str) -> None:
    folder = CATALOG / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{name}.svg").write_text(svg)
    contents = {
        "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def svg_doc(path: str, box) -> str:
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
        f'<path fill="#000000" fill-rule="evenodd" d="{path}"/></svg>\n'
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", type=Path)
    args = ap.parse_args()
    im = Image.open(SRC).convert("RGB")
    if args.preview:
        args.preview.mkdir(parents=True, exist_ok=True)

    for name, box in ICONS.items():
        crop = np.asarray(im.crop(box)).astype(np.float32)
        cov = coverage(crop)
        strokes = clean(upsample(cov, 2.0) > 0.5, 40 * UP)
        path, tbox = trace(strokes)
        write_imageset(f"Family-{name}", svg_doc(path, tbox))
        print(f"{name}: strokes ok, bbox {tbox[2]-tbox[0]}x{tbox[3]-tbox[1]} @4x")

        if args.preview:
            crop_big = im.crop(box).resize(((box[2]-box[0]) * UP, (box[3]-box[1]) * UP), Image.LANCZOS)
            crop_big.save(args.preview / f"{name}-orig.png")


if __name__ == "__main__":
    main()
