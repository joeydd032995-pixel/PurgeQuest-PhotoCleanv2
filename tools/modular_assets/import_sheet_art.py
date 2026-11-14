"""Import updated weapon and shield art from phone screenshots of the owner's contact sheets.

The owner supplied the updated art for all 99 held and store gear items as screenshots of review sheets
(`docs/modular/source_photos/`): a grid of named tiles ("Oaken Ward I", "Crystal Shard", ...), each with two drawings
side by side (the original and a recoloured example) on a flat dark tile colour. This tool finds the tile grid in each
photo, cuts the chosen drawing of every tile out of the tile colour, and fits it into the existing sprite's canvas, so
filenames, canvas sizes, catalog ids and the visible-art box stay as they are.

    python3 -I tools/modular_assets/import_sheet_art.py                    # plan only: source photo and upscale per item
    python3 -I tools/modular_assets/import_sheet_art.py --write            # replace the 99 sprites in place
    python3 -I tools/modular_assets/import_sheet_art.py --write --half right
    python3 -I tools/modular_assets/import_sheet_art.py --out DIR          # write the sprites to DIR instead
    python3 -I tools/modular_assets/import_sheet_art.py --only "Crystal Shard,Oaken Ward I" --preview sheet.png

Then regenerate what depends on the sprites (grips, masks, Titan checks, manifest): see docs/modular/README.md.

Where a name appears in several photos the widest drawing (the most pixels) is used. Weapons keep their pommel end where
the previous sprite had it, so the grip lands where the hand expects it; shields and the bow are centred in the box.
The painterly Verdant Coil / Tidecaller photo the owner also sent is not used: it has no outlines and its tiles are
too small to cut out cleanly.

Pillow + NumPy only.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]
ART = REPO / "ios" / "PurgeQuest" / "Art"
PHOTOS = REPO / "docs" / "modular" / "source_photos"
MANIFEST = ART / "Modular" / "modular_gear_manifest.json"

SETS_STAFF = ["Ashen Bough", "Verdant Coil", "Tidecaller", "Ember Scepter",
              "Storm Spire", "Gilded Crook", "Bone Reliquary", "Voidspike"]
SETS_SHIELD = ["Oaken Ward", "Templar Aegis", "Scaled Bulwark", "Runic Disc",
               "Valkyrie Wing", "Iron Moon", "Bone Paragon", "Verdigris Sigil"]
ROMAN = ["I", "II", "III", "IV", "V"]


def grid(sets: List[str], tiers: List[int], rows: Optional[List[int]] = None) -> List[List[str]]:
    rows = rows if rows is not None else list(range(len(sets)))
    return [[f"{sets[r]} {ROMAN[t - 1]}" for t in tiers] for r in rows]


# One entry per photo: the names of its tiles, row by row (a tile has no readable title for a program, so the position
# is the name; the order is the order of the sheets the photos were taken from). Slots a photo cuts off are omitted.
LAYOUTS: List[dict] = [
    dict(key="staves_I_II", file="staves_I_II.jpg", rows=grid(SETS_STAFF, [1, 2], rows=list(range(6)))),
    dict(key="staves_BoneVoid_I_II", file="staves_BoneVoid_I_II.jpg", rows=grid(SETS_STAFF, [1, 2], rows=[6, 7])),
    dict(key="staves_III_IV", file="staves_III_IV.jpg", rows=grid(SETS_STAFF, [3, 4], rows=list(range(7)))),
    dict(key="staves_III_IV_lower", file="staves_III_IV_lower.jpg", rows=grid(SETS_STAFF, [3, 4], rows=[3, 4, 5, 6, 7])),
    dict(key="staves_IV_V", file="staves_IV_V.jpg", rows=grid(SETS_STAFF, [4, 5], rows=list(range(8)))),
    dict(key="shields_I_II", file="shields_I_II.jpg", rows=grid(SETS_SHIELD, [1, 2])),
    dict(key="shields_III_IV", file="shields_III_IV.jpg", rows=grid(SETS_SHIELD, [3, 4])),
    dict(key="shields_V", file="shields_V.jpg", rows=grid(SETS_SHIELD, [5])),
    dict(key="store", file="store.jpg",
         rows=[["Crystal Shard", "Film Reel Blade", "Gem Hammer"],
               ["Archmage Staff", "Storm Cleaver", "Oathbreaker Greatsword"],
               ["Ruby Fang", "Arcane Edge", "Firework Blade"],
               ["Azure Aegis", "Templar Bulwark"]]),
    dict(key="signature", file="signature.jpg",
         rows=[["Valkyrie Blade", "Elven Recurve"], ["Seer's Edge", "Vampyri Cleaver"],
               ["Scarred Fang", "Shadowbrand"], ["Undead Claymore", "Vaultcracker"]]),
]


# --------------------------------------------------------------------------------------
# small image helpers (no SciPy)
# --------------------------------------------------------------------------------------
def runs(flags: np.ndarray, min_len: int) -> List[Tuple[int, int]]:
    out, start = [], None
    for i, v in enumerate(flags):
        if v and start is None:
            start = i
        elif not v and start is not None:
            if i - start >= min_len:
                out.append((start, i))
            start = None
    if start is not None and len(flags) - start >= min_len:
        out.append((start, len(flags)))
    return out


def label(mask: np.ndarray, eight: bool) -> np.ndarray:
    """Connected components of a boolean mask (run-based union-find). 0 = background."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    parent = [0]

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    nxt, prev = 1, []
    pad = 1 if eight else 0
    for y in range(h):
        d = np.diff(np.concatenate(([0], mask[y].astype(np.int8), [0])))
        starts, ends = np.where(d == 1)[0], np.where(d == -1)[0]
        cur = []
        for s, e in zip(starts, ends):
            lab = 0
            for ps, pe, pl in prev:
                if ps < e + pad and s < pe + pad:
                    if lab == 0:
                        lab = pl
                    else:
                        ra, rb = find(lab), find(pl)
                        if ra != rb:
                            parent[max(ra, rb)] = min(ra, rb)
            if lab == 0:
                lab = nxt
                parent.append(lab)
                nxt += 1
            cur.append((s, e, lab))
            labels[y, s:e] = lab
        prev = cur
    roots = np.array([find(i) for i in range(len(parent))], dtype=np.int32)
    return roots[labels]


def dilate(mask: np.ndarray, r: int) -> np.ndarray:
    return np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(2 * r + 1))) > 127


def erode(mask: np.ndarray, r: int) -> np.ndarray:
    return np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(2 * r + 1))) > 127


def luminance(a: np.ndarray) -> np.ndarray:
    return 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]


def smoothstep(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def blur(a: np.ndarray, radius: float) -> np.ndarray:
    img = Image.fromarray(np.clip(a * 255.0, 0, 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(img).astype(np.float32) / 255.0


def gauss(a: np.ndarray, sigma: float) -> np.ndarray:
    r = max(1, int(3 * sigma + 0.5))
    x = np.arange(-r, r + 1)
    k = np.exp(-(x ** 2) / (2 * sigma ** 2))
    k /= k.sum()
    p = np.pad(a, ((r, r), (r, r)), mode="edge")
    t = np.apply_along_axis(lambda m: np.convolve(m, k, mode="valid"), 1, p)
    return np.apply_along_axis(lambda m: np.convolve(m, k, mode="valid"), 0, t)


def border_labels(lab: np.ndarray) -> np.ndarray:
    b = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    return b[b != 0]


def fill_holes(mask: np.ndarray) -> np.ndarray:
    lab = label(~mask, eight=False)
    return ~np.isin(lab, border_labels(lab))


def trim_black(im: np.ndarray) -> np.ndarray:
    """Drop letterbox bars (near-black rows/columns) from the edges of a screenshot."""
    rows = im.mean(axis=(1, 2)) < 10
    cols = im.mean(axis=(0, 2)) < 10
    y0, y1 = 0, im.shape[0]
    while y0 < y1 and rows[y0]:
        y0 += 1
    while y1 > y0 and rows[y1 - 1]:
        y1 -= 1
    x0, x1 = 0, im.shape[1]
    while x0 < x1 and cols[x0]:
        x0 += 1
    while x1 > x0 and cols[x1 - 1]:
        x1 -= 1
    return im[y0:y1, x0:x1]


# --------------------------------------------------------------------------------------
# 1. the tile grid of a photo
# --------------------------------------------------------------------------------------
def tile_background(im: np.ndarray) -> np.ndarray:
    q = (im // 8).reshape(-1, 3)[::5]
    key = Counter(map(tuple, q)).most_common(1)[0][0]
    return im[np.all((im // 8) == np.array(key), axis=2)].mean(axis=0)


def detect_tiles(im: np.ndarray, bg: np.ndarray) -> Tuple[List[Tuple[int, int]], List[Tuple[int, int]]]:
    """(column spans, row spans). Gaps between tiles hold almost no tile-coloured pixels; a row that crosses a long
    weapon still keeps a few percent, so the threshold is low. Slivers of a tile cut off at an edge are dropped."""
    is_tile = np.abs(im - bg).max(axis=2) <= 14
    cols = runs(is_tile.mean(axis=0) > 0.03, 40)
    rows = runs(is_tile.mean(axis=1) > 0.03, 40)

    def drop_slivers(spans):
        if len(spans) < 2:
            return spans
        med = float(np.median([b - a for a, b in spans]))
        return [s for s in spans if (s[1] - s[0]) >= 0.6 * med]

    return drop_slivers(cols), drop_slivers(rows)


# --------------------------------------------------------------------------------------
# 2. the two drawings in a tile
# --------------------------------------------------------------------------------------
def tile_objects(tile: np.ndarray, bg: np.ndarray) -> Dict[str, Optional[Tuple[int, int, int, int]]]:
    """Bounding boxes (x0, y0, x1, y1) of the left and the right drawing; the tile's title and caption are text."""
    h, w, _ = tile.shape
    art = np.abs(tile - bg).max(axis=2) > 38
    lab = label(dilate(art, 3), eight=True)
    comps = []
    for i in range(1, lab.max() + 1):
        ys, xs = np.where(lab == i)
        if len(ys) == 0:
            continue
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        area = int(art[lab == i].sum())
        is_text = (y1 - y0) < 0.14 * h and (y1 < 0.30 * h or y0 > 0.72 * h)
        if not is_text and area >= 30:
            comps.append((x0, y0, x1, y1, area))
    out: Dict[str, Optional[Tuple[int, int, int, int]]] = {"left": None, "right": None}
    for side in ("left", "right"):
        mine = [c for c in comps if ((c[0] + c[2]) / 2 < w / 2) == (side == "left")]
        if not mine:
            continue
        big = max(c[4] for c in mine)
        keep = [c for c in mine if c[4] >= 0.04 * big]
        out[side] = (min(c[0] for c in keep), min(c[1] for c in keep), max(c[2] for c in keep), max(c[3] for c in keep))
    return out


# --------------------------------------------------------------------------------------
# 3. cut a drawing out of the tile colour
# --------------------------------------------------------------------------------------
# Solid art is either darker than the tile (outlines, shadows) or strongly different from it. A pixel only moderately
# different and not darker is smoke / glow / haze, which keeps a partial alpha instead of turning opaque.
WEAK_D = 80.0
WEAK_DARKER = -8.0
HULL_CLOSE = 8       # radius (px) of the closing that bridges gaps in an outline before its interior is filled


def cut_out(crop: np.ndarray, bg: np.ndarray, pad: int = 4) -> np.ndarray:
    """RGBA uint8 (padded by `pad`): solid art opaque with a smooth antialiased edge, smoke / glow partly transparent,
    the flat tile colour transparent."""
    h0, w0 = crop.shape[:2]
    big = np.empty((h0 + 2 * pad, w0 + 2 * pad, 3), dtype=np.float32)
    big[:] = bg
    big[pad:pad + h0, pad:pad + w0] = crop
    d = np.abs(big - bg).max(axis=2)
    dl = luminance(big) - float(luminance(bg))
    # JPEG noise makes a thin dark outline flicker between "solid" and "glow" pixel by pixel; classify on a lightly
    # smoothed signal so the contour is continuous.
    d_s, dl_s = gauss(d, 0.8), gauss(dl, 0.8)
    lab = label(d <= 12, eight=False)
    border = border_labels(lab)
    exterior = np.isin(lab, border)
    for i in np.unique(lab):                      # enclosed tile-coloured pockets (the hole of a ring)
        if i == 0 or i in border:
            continue
        pocket = lab == i
        if pocket.sum() >= 40 and d[pocket].max() <= 10:
            exterior |= pocket
    obj = ~exterior
    weak_candidate = (d_s < WEAK_D) & (dl_s > WEAK_DARKER)
    strong = erode(dilate(obj & ~weak_candidate, 1), 1)          # close 1px gaps in thin outlines
    comp = label(strong, eight=True)
    if comp.max() > 0:
        sizes = np.bincount(comp.ravel())
        sizes[0] = 0
        strong &= np.isin(comp, np.where(sizes >= max(10, 0.02 * sizes.max()))[0])
    # Low-contrast art (an olive staff on the dark tile) has gaps in its outline; closing them lets the silhouette fill
    # its interior instead of leaving it half transparent.
    closed = erode(dilate(strong, HULL_CLOSE), HULL_CLOSE)
    hull = fill_holes(dilate(closed, 1)) & obj    # the solid drawing, holes filled
    hull = np.asarray(Image.fromarray((hull * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(3))) > 127
    weak = obj & ~hull & weak_candidate           # thick weak regions are smoke / glow; thin rings are JPEG ringing
    weak_thick = dilate(erode(weak, 2), 2) & weak
    a_weak = np.clip((d - 10.0) / 70.0, 0.0, 0.9) * weak_thick
    a_weak[a_weak < 0.15] = 0.0
    a_hull = smoothstep(blur(hull.astype(np.float32), 1.0), 0.3, 0.7) * dilate(hull, 1)
    alpha = np.maximum(a_hull, a_weak)
    rgb = big.copy()
    # Only the outermost half-transparent edge pixels are blended with the tile colour: borrow the colour of the nearest
    # solid pixel. Solid pixels (a thin dark outline included) are left exactly as they are.
    solid = a_hull >= 0.9
    edge = (a_hull > 0) & ~solid & ~(a_weak > 0)
    for y, x in zip(*np.where(edge)):
        y0, y1, x0, x1 = max(0, y - 2), min(rgb.shape[0], y + 3), max(0, x - 2), min(rgb.shape[1], x + 3)
        nb = solid[y0:y1, x0:x1]
        if nb.any():
            rgb[y, x] = rgb[y0:y1, x0:x1][nb].mean(axis=0)
    aw = np.maximum(a_weak, 1e-3)[..., None]       # smoke / glow colour: undo the blend with the tile colour
    unmixed = np.clip((big - (1.0 - aw) * bg) / aw, 0, 255)
    rgb = np.where((a_weak > 0)[..., None] & ~hull[..., None], unmixed, rgb)
    out = np.zeros(big.shape[:2] + (4,), dtype=np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8)
    out[..., :3][out[..., 3] == 0] = 0
    return out


def tight(rgba: np.ndarray, thresh: int = 8) -> np.ndarray:
    ys, xs = np.where(rgba[..., 3] > thresh)
    return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


# --------------------------------------------------------------------------------------
# 4. fit into the existing sprite's canvas
# --------------------------------------------------------------------------------------
def opaque_bbox(img: Image.Image, thresh: int = 128) -> Tuple[int, int, int, int]:
    ys, xs = np.where(np.asarray(img.getchannel("A")) > thresh)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def resize_rgba(rgba: np.ndarray, size: Tuple[int, int]) -> np.ndarray:
    """Lanczos resize of premultiplied colour, so transparent pixels cannot bleed into the edge."""
    a = rgba[..., 3:4].astype(np.float32) / 255.0
    pm = np.concatenate([rgba[..., :3].astype(np.float32) * a, a * 255.0], axis=2)
    chans = [np.asarray(Image.fromarray(pm[..., c], mode="F").resize(size, Image.Resampling.LANCZOS)) for c in range(4)]
    pm2 = np.stack(chans, axis=2)
    alpha = np.clip(pm2[..., 3:4], 0, 255) / 255.0
    rgb = np.where(alpha > 1e-4, pm2[..., :3] / np.maximum(alpha, 1e-4), 0)
    return (np.concatenate([np.clip(rgb, 0, 255), np.clip(alpha * 255, 0, 255)], axis=2) + 0.5).astype(np.uint8)


def fit_into(cut: np.ndarray, target_size: Tuple[int, int], target_box: Tuple[int, int, int, int],
             align: str = "center", sharpen: float = 60.0) -> Tuple[Image.Image, float]:
    """Scale a cut-out to fit inside `target_box` (aspect kept) on a transparent canvas of `target_size`.

    align="center": centred on the box (shields, the bow).
    align="left":   the cut-out's left edge on the box's left edge, vertically centred (weapons: the pommel end stays
                    where it was, so the grip stays where the hand expects it)."""
    cut = tight(cut, 30)
    bx0, by0, bx1, by1 = target_box
    s = min((bx1 - bx0) / cut.shape[1], (by1 - by0) / cut.shape[0])
    nw, nh = max(1, round(cut.shape[1] * s)), max(1, round(cut.shape[0] * s))
    img = Image.fromarray(resize_rgba(cut, (nw, nh)), "RGBA")
    if sharpen:   # upscaling softens the outline; a light unsharp mask on colour only (alpha is untouched)
        rgb = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.2, percent=int(sharpen), threshold=2))
        img = Image.merge("RGBA", (*rgb.split(), img.getchannel("A")))
    canvas = Image.new("RGBA", target_size, (0, 0, 0, 0))
    x = bx0 if align == "left" else round((bx0 + bx1) / 2 - nw / 2)
    canvas.alpha_composite(img, (int(x), round((by0 + by1) / 2 - nh / 2)))
    return canvas, s


def align_for(item: dict) -> str:
    r = item["resourceName"]
    if item["group"].startswith("shield") or r.startswith("store_shield") or item["kind"] == "bow":
        return "center"
    return "left"


# --------------------------------------------------------------------------------------
# driver
# --------------------------------------------------------------------------------------
def load_items() -> Dict[str, dict]:
    """Gear manifest items by display name, each with the path of its sprite."""
    res = {p.stem: p for p in ART.rglob("*.png")}
    return {i["name"]: dict(i, path=res[i["resourceName"]]) for i in json.loads(MANIFEST.read_text())["items"]}


def extract(photos: Path, verbose: bool = True) -> Dict[str, List[dict]]:
    """name -> candidate drawings, one per photo that shows it: {'photo', 'left', 'right', 'width': {side: px}}."""
    found: Dict[str, List[dict]] = {}
    for lay in LAYOUTS:
        im = trim_black(np.asarray(Image.open(photos / lay["file"]).convert("RGB")).astype(np.float32))
        bg = tile_background(im)
        cols, rows = detect_tiles(im, bg)
        want = (len(lay["rows"]), max(len(r) for r in lay["rows"]))
        if verbose:
            print(f"{lay['key']:<22} tiles {len(rows)}x{len(cols)} (expected {want[0]}x{want[1]})")
        if len(rows) < want[0] or len(cols) < want[1]:
            raise SystemExit(f"{lay['file']}: found {len(rows)}x{len(cols)} tiles, expected {want[0]}x{want[1]}")
        for ri, names in enumerate(lay["rows"]):
            for ci, name in enumerate(names):
                (y0, y1), (x0, x1) = rows[ri], cols[ci]
                tile = im[y0:y1, x0:x1]
                objs = tile_objects(tile, bg)
                if objs["left"] is None or objs["right"] is None:
                    raise SystemExit(f"{lay['file']}: could not find both drawings of {name!r}")
                rec = {"photo": lay["key"]}
                mid = tile.shape[1] // 2
                for side in ("left", "right"):
                    bx0, by0, bx1, by1 = objs[side]
                    cx0, cy0 = max(0, bx0 - 6), max(0, by0 - 6)
                    cx1, cy1 = min(tile.shape[1], bx1 + 6), min(tile.shape[0], by1 + 6)
                    cx0, cx1 = (cx0, min(cx1, mid)) if side == "left" else (max(cx0, mid), cx1)   # not the other half
                    rec[side] = cut_out(tile[cy0:cy1, cx0:cx1], bg)
                rec["width"] = {s: int(tight(rec[s]).shape[1]) for s in ("left", "right")}
                found.setdefault(name, []).append(rec)
    return found


def build(item: dict, candidates: List[dict], half: str) -> Tuple[Image.Image, float, str]:
    """(new sprite, upscale factor, photo key) for one item: the widest drawing of the chosen half."""
    pick = max(candidates, key=lambda c: c["width"][half])
    with Image.open(item["path"]) as cur:
        cur = cur.convert("RGBA")
    sprite, scale = fit_into(pick[half], cur.size, opaque_bbox(cur), align=align_for(item))
    return sprite, scale, pick["photo"]


def preview_sheet(rows: List[Tuple[str, Image.Image, Image.Image]], path: Path) -> None:
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    except OSError:
        font = ImageFont.load_default(size=13)
    pw = max(max(a.width, b.width) for _, a, b in rows)
    ph = max(max(a.height, b.height) for _, a, b in rows)
    cols = max(1, min(4, len(rows)))
    n = -(-len(rows) // cols)
    sheet = Image.new("RGBA", (cols * (2 * pw + 16), n * (ph + 28)), (24, 28, 38, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (name, cur, new) in enumerate(rows):
        x, y = (i % cols) * (2 * pw + 16), (i // cols) * (ph + 28)
        draw.text((x + 4, y + 4), f"{name}: before | after", font=font, fill=(240, 244, 252, 255))
        for j, img in enumerate((cur, new)):
            tile = Image.new("RGBA", (pw, ph), (96, 102, 114, 255))
            tile.alpha_composite(img, ((pw - img.width) // 2, (ph - img.height) // 2))
            sheet.alpha_composite(tile, (x + 4 + j * (pw + 4), y + 24))
    sheet.convert("RGB").save(path)


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--photos", type=Path, default=PHOTOS, help="folder with the photos named in LAYOUTS")
    ap.add_argument("--half", choices=("left", "right"), default="left",
                    help="which drawing of each tile is the art: left = the original, right = the recoloured example")
    ap.add_argument("--only", help="comma-separated item names to process (default: all 99)")
    ap.add_argument("--write", action="store_true", help="replace the sprites under ios/PurgeQuest/Art in place")
    ap.add_argument("--out", type=Path, help="write the sprites (named <resource>.png) to this folder instead")
    ap.add_argument("--preview", type=Path, help="write a before/after sheet of the processed items to this PNG")
    args = ap.parse_args(argv)
    if args.write and args.out:
        ap.error("--write and --out are exclusive")

    items = load_items()
    names = [n.strip() for n in args.only.split(",")] if args.only else list(items)
    unknown = [n for n in names if n not in items]
    if unknown:
        ap.error(f"unknown item(s): {unknown}")
    found = extract(args.photos)
    missing = [n for n in names if n not in found]
    if missing:
        raise SystemExit(f"no photo shows: {missing}")

    rows, scales = [], []
    for name in names:
        item = items[name]
        sprite, scale, photo = build(item, found[name], args.half)
        scales.append(scale)
        with Image.open(item["path"]) as cur:
            rows.append((name, cur.convert("RGBA"), sprite))
        print(f"  {name:<24} {item['resourceName']:<30} {photo:<22} x{scale:.2f}")
        if args.write:
            sprite.save(item["path"], optimize=True)
        elif args.out:
            args.out.mkdir(parents=True, exist_ok=True)
            sprite.save(args.out / f"{item['resourceName']}.png", optimize=True)
    print(f"{len(names)} items; upscale median x{np.median(scales):.2f}, max x{max(scales):.2f}"
          f"{'  (written to the repo)' if args.write else ''}")
    if args.preview:
        preview_sheet(rows, args.preview)
        print("preview:", args.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
