#!/usr/bin/env python3
"""Turn a folder of real photos into the grayscale buffers PurgeQuest derives from its thumbnails.

Development machine only (needs Pillow and NumPy). Run with `python3 -I` so nothing is imported from
the data folder:

    python3 -I tools/detection_bench/prepare.py --originals DIR [--copies DIR] --out OUT_DIR

Ground truth comes from the INRIA CopyDays naming scheme: `GGGGVV.jpg`, where GGGG is the scene and
VV the variant (00 is the original). Any folder named like that works.

What the app does, and what this approximates
  PhotoLibraryService asks PhotoKit for a 600x600 aspect-fill thumbnail, which comes back uncropped with
  its short side at 600 px. The dHash then draws that image into a 9x8 gray context, and the quality
  metrics draw it into small contexts. Here: scale to a 600 px short side, then area-average down to the
  same grids. CoreGraphics' own interpolation differs a little, so absolute numbers are an estimate;
  A/B comparisons between two engines on the same buffers are exact.

Output: OUT_DIR/manifest.tsv and OUT_DIR/features.bin (fixed-size records, see RECORD below).
"""
import argparse, os, sys, struct
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageOps

# Grid sizes written per sample. Keep in step with tools/detection_bench/Sources/bench/main.swift.
GRIDS = [(9, 8), (16, 16), (32, 32), (80, 80), (128, 128), (256, 256)]
THUMB = 600


def to_thumbnail(img: Image.Image) -> Image.Image:
    img = ImageOps.exif_transpose(img).convert("RGB")
    w, h = img.size
    scale = THUMB / min(w, h)
    if scale < 1:
        img = img.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    return img


def gray(img: Image.Image, size) -> bytes:
    # ITU-R 601 luma, the same weights MLAnalysisService uses.
    g = img.convert("L").resize(size, Image.BOX)
    return g.tobytes()


def record(img: Image.Image) -> bytes:
    return b"".join(gray(img, s) for s in GRIDS)


def gaussian(img, sigma):
    from PIL import ImageFilter
    return img.filter(ImageFilter.GaussianBlur(sigma))


def motion(img, length):
    a = np.asarray(img, dtype=np.float32)
    acc = np.zeros_like(a)
    for k in range(length):
        acc += np.roll(a, k - length // 2, axis=1)
    return Image.fromarray(np.clip(acc / length, 0, 255).astype(np.uint8))


def darken(img, factor):
    # Underexposure: scale linear light, re-encode to sRGB-ish gamma.
    a = (np.asarray(img, dtype=np.float32) / 255.0) ** 2.2 * factor
    return Image.fromarray(np.clip(a ** (1 / 2.2) * 255, 0, 255).astype(np.uint8))


def brighten(img, factor):
    a = np.asarray(img, dtype=np.float32) * factor
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def resave(img):
    # What a messenger does: shrink the long edge to 1600 px and re-encode at JPEG quality 70.
    import io
    w, h = img.size
    s = 1600 / max(w, h)
    small = img.resize((round(w * s), round(h * s)), Image.LANCZOS) if s < 1 else img
    buf = io.BytesIO(); small.save(buf, "JPEG", quality=70); buf.seek(0)
    return Image.open(buf).convert("RGB")


def center_crop(img, frac):
    w, h = img.size
    cw, ch = round(w * frac), round(h * frac)
    x, y = (w - cw) // 2, (h - ch) // 2
    return img.crop((x, y, x + cw, y + ch))


def work(job):
    path, group, kind, extra = job
    with Image.open(path) as im:
        src_w, src_h = im.size
        thumb = to_thumbnail(im)
    if extra:
        name, arg = extra
        thumb = {
            "blur": lambda t: to_thumbnail(gaussian(t, arg)),
            "motion": lambda t: to_thumbnail(motion(t, arg)),
            "dark": lambda t: to_thumbnail(darken(t, arg)),
            "bright": lambda t: to_thumbnail(brighten(t, arg)),
            "resave": lambda t: to_thumbnail(resave(t)),
            "crop": lambda t: to_thumbnail(center_crop(t, arg)),
        }[name](thumb)
    w, h = thumb.size
    return (os.path.basename(path), group, kind, src_w, src_h, record(thumb))


def scan(folder):
    out = []
    for f in sorted(os.listdir(folder)):
        stem, ext = os.path.splitext(f)
        if ext.lower() not in (".jpg", ".jpeg", ".png") or not stem.isdigit():
            continue
        out.append((os.path.join(folder, f), int(stem) // 100, stem))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--originals", required=True)
    ap.add_argument("--copies")
    ap.add_argument("--out", required=True)
    ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()

    jobs = []
    for path, group, _ in scan(args.originals):
        jobs.append((path, group, "orig", None))
    if args.copies:
        for path, group, _ in scan(args.copies):
            jobs.append((path, group, "copy", None))
    # Derived samples from every original. Kinds are `<family>_<parameter>`.
    for path, group, _ in scan(args.originals):
        for s in (1.5, 3.0, 5.0, 8.0):  jobs.append((path, group, f"blur_{s}", ("blur", s)))
        for n in (15, 31):              jobs.append((path, group, f"motion_{n}", ("motion", n)))
        for k in (0.04, 0.08, 0.15):    jobs.append((path, group, f"dark_{k}", ("dark", k)))
        jobs.append((path, group, "syn_bright", ("bright", 1.25)))
        jobs.append((path, group, "syn_resave", ("resave", None)))
        jobs.append((path, group, "syn_crop", ("crop", 0.92)))

    os.makedirs(args.out, exist_ok=True)
    rec_size = sum(w * h for w, h in GRIDS)
    with Pool(args.workers) as pool, open(os.path.join(args.out, "features.bin"), "wb") as fb, \
         open(os.path.join(args.out, "manifest.tsv"), "w") as mf:
        mf.write("index\tname\tgroup\tkind\tsrc_w\tsrc_h\n")
        for i, (name, group, kind, sw, sh, rec) in enumerate(pool.imap(work, jobs, chunksize=4)):
            assert len(rec) == rec_size
            fb.write(rec)
            mf.write(f"{i}\t{name}\t{group}\t{kind}\t{sw}\t{sh}\n")
    print(f"wrote {len(jobs)} samples, {rec_size} bytes each -> {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
