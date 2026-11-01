#!/usr/bin/env python3
"""Cut the PurgeQuest gold emblem out of the light splash mockup as a transparent PNG.

  tools/design/extract_emblem.py [--preview DIR]

Input : docs/design/mockups/splash-light.jpg  (359x721 screenshot, emblem on cream)
Output: ios/PurgeQuest/Assets.xcassets/PurgeQuestEmblem.imageset/emblem@{1,2,3}x.png

The mockup is the only source art, so this is a best-effort matte: the cream
background is removed by flood fill from the border (so pale highlights that are
enclosed by the bronze outline stay opaque), edge colours are replaced by the
nearest interior colour (no cream halo on dark backgrounds), then the result is
upscaled with Lanczos. Drop a higher-resolution original into the imageset when
one exists; the asset name and the code that uses it do not change.

Requires: Pillow, numpy, scipy.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "docs/design/mockups/splash-light.jpg"
OUT = ROOT / "ios/PurgeQuest/Assets.xcassets/PurgeQuestEmblem.imageset"

# Search window around the emblem in the 359x721 screenshot (excludes title/spinner/tagline).
WINDOW = (36, 212, 326, 436)
DISPLAY_WIDTH_PT = 200  # @3x asset is 600 px wide


def matte(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Returns (alpha float32 0..1, decontaminated rgb float32)."""
    h, w, _ = rgb.shape
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]).astype(np.float32)
    bg = np.median(border, axis=0)
    dist = np.linalg.norm(rgb.astype(np.float32) - bg, axis=2)

    near_bg = dist < 26.0
    labels, _ = ndi.label(near_bg)
    edge_labels = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    background = np.isin(labels, list(edge_labels))
    fg = ~background

    # Drop specks (JPEG noise) that are not part of the emblem.
    fl, n = ndi.label(fg)
    if n:
        sizes = ndi.sum(fg, fl, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= 60]
        fg = np.isin(fl, keep)
    fg = ndi.binary_fill_holes(fg)

    # Soft edge: ~1 px feather straddling the mask boundary.
    alpha = ndi.gaussian_filter(fg.astype(np.float32), sigma=0.7)
    alpha = np.clip((alpha - 0.15) / 0.7, 0.0, 1.0)
    alpha[~ndi.binary_dilation(fg, iterations=2)] = 0.0

    # Replace colours within 2 px of the boundary by the nearest solid interior colour.
    core = ndi.binary_erosion(fg, iterations=2)
    _, (iy, ix) = ndi.distance_transform_edt(~core, return_indices=True)
    solid = rgb.astype(np.float32)[iy, ix]
    out = np.where(core[..., None], rgb.astype(np.float32), solid)
    return alpha, out


def upscale(rgb: np.ndarray, alpha: np.ndarray, width: int) -> Image.Image:
    h, w = alpha.shape
    height = round(h * width / w)
    # Resample premultiplied so transparent pixels never bleed colour.
    pre = rgb * alpha[..., None]
    chans = [Image.fromarray(np.clip(pre[..., i], 0, 255).astype(np.uint8)).resize((width, height), Image.LANCZOS) for i in range(3)]
    a = Image.fromarray((alpha * 255).astype(np.uint8)).resize((width, height), Image.LANCZOS)
    a_np = np.asarray(a).astype(np.float32) / 255.0
    pre_up = np.stack([np.asarray(c).astype(np.float32) for c in chans], axis=2)
    with np.errstate(divide="ignore", invalid="ignore"):
        straight = np.where(a_np[..., None] > 0.01, pre_up / np.maximum(a_np[..., None], 0.01), 0)
    img = Image.fromarray(np.dstack([np.clip(straight, 0, 255), a_np * 255]).astype(np.uint8), "RGBA")
    # Gentle sharpening on colour only; alpha stays untouched.
    rgb_img = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.4, percent=70, threshold=2))
    rgb_img.putalpha(img.getchannel("A"))
    return rgb_img


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", type=Path, help="write cream/dark composites here for review")
    args = ap.parse_args()

    src = Image.open(SRC).convert("RGB").crop(WINDOW)
    rgb = np.asarray(src)
    alpha, solid = matte(rgb)

    ys, xs = np.where(alpha > 0.02)
    pad = 3
    box = (max(xs.min() - pad, 0), max(ys.min() - pad, 0), min(xs.max() + pad + 1, rgb.shape[1]), min(ys.max() + pad + 1, rgb.shape[0]))
    solid = solid[box[1]:box[3], box[0]:box[2]]
    alpha = alpha[box[1]:box[3], box[0]:box[2]]

    OUT.mkdir(parents=True, exist_ok=True)
    sizes = {1: DISPLAY_WIDTH_PT, 2: DISPLAY_WIDTH_PT * 2, 3: DISPLAY_WIDTH_PT * 3}
    images = []
    for scale, width in sizes.items():
        img = upscale(solid, alpha, width)
        name = f"emblem@{scale}x.png"
        img.save(OUT / name, optimize=True)
        images.append({"idiom": "universal", "filename": name, "scale": f"{scale}x"})
        print(f"wrote {name} {img.size}")
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (OUT / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

    if args.preview:
        args.preview.mkdir(parents=True, exist_ok=True)
        big = Image.open(OUT / "emblem@3x.png")
        for label, color in (("cream", (244, 244, 236)), ("dark", (12, 21, 18))):
            bg = Image.new("RGBA", (big.width + 80, big.height + 80), color + (255,))
            bg.alpha_composite(big, (40, 40))
            bg.convert("RGB").save(args.preview / f"emblem-on-{label}.png")


if __name__ == "__main__":
    main()
