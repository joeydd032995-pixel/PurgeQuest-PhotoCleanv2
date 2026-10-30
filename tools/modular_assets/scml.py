"""SCML parser and rasterizer mirroring ios/PurgeQuest/Services/SpriteEngine.swift.

The Swift renderer uses only mainline keys (no tweening), resolves bone
chains into world placements (Spriter y-up space), and draws each part
rotated about its pivot. This module reproduces that math so every
modular asset can be checked visually and numerically off-device.
"""
from __future__ import annotations

import math
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Tuple

from PIL import Image

ART_ROOT = Path(__file__).resolve().parents[2] / "ios" / "PurgeQuest" / "Art"
RACES_ROOT = ART_ROOT / "Races"

# (race raw value used by HeroRace.artBase, variants as (dir, variant) pairs)
PACKS: List[Tuple[str, int]] = (
    [("valkyrie", v) for v in (1, 2, 3)]
    + [("forest_ranger", v) for v in (1, 2, 3)]
    + [("seer", v) for v in (1, 2, 3)]
    + [("blood_alchemist", v) for v in (1, 2, 3)]
    + [("dark_oracle", v) for v in (1, 2, 3)]
    + [("necromancer", v) for v in (1, 2, 3)]
    + [("skeleton_crusader", v) for v in (1, 2, 3)]
    + [("skeleton_warrior", v) for v in (1, 2, 3)]
    + [("golem", v) for v in (1, 2, 3)]
)


def pack_id(race_dir: str, variant: int) -> str:
    return f"{race_dir}_v{variant}"


def pack_dir(race_dir: str, variant: int) -> Path:
    return RACES_ROOT / race_dir / f"v{variant}"


def stem_of(file_name: str) -> str:
    return Path(file_name).stem.lower().replace(" ", "_")


@dataclass(frozen=True)
class FileDef:
    name: str
    width: float
    height: float
    pivot_x: float
    pivot_y: float

    @property
    def stem(self) -> str:
        return stem_of(self.name)


@dataclass(frozen=True)
class Placement:
    file: FileDef
    x: float
    y: float
    angle: float
    pivot_x: float
    pivot_y: float
    z: int
    alpha: float


class Doc:
    def __init__(self, animations: Dict[str, List[List[Placement]]]):
        self.animations = animations
        self._bounds_cache: Dict[Tuple, Tuple[Tuple[float, float], Tuple[float, float]]] = {}

    def _bounds(self, weapon_scale: float = 1.0):
        """Union bounds over visible placements. Weapon files scale about their pivot."""
        key = (weapon_scale,)
        if key in self._bounds_cache:
            return self._bounds_cache[key]
        min_x = min_y = math.inf
        max_x = max_y = -math.inf
        for frames in self.animations.values():
            for frame in frames:
                for p in frame:
                    if p.alpha <= 0.01 or p.file.stem.startswith("slashfx"):
                        continue
                    s = weapon_scale if is_weapon(p.file.stem) else 1.0
                    w, h = p.file.width * s, p.file.height * s
                    r = math.radians(p.angle)
                    c, sn = math.cos(r), math.sin(r)
                    for cx, cy in (
                        (-p.pivot_x * w, -p.pivot_y * h),
                        ((1 - p.pivot_x) * w, -p.pivot_y * h),
                        ((1 - p.pivot_x) * w, (1 - p.pivot_y) * h),
                        (-p.pivot_x * w, (1 - p.pivot_y) * h),
                    ):
                        x = p.x + cx * c - cy * sn
                        y = p.y + cx * sn + cy * c
                        min_x, max_x = min(min_x, x), max(max_x, x)
                        min_y, max_y = min(min_y, y), max(max_y, y)
        self._bounds_cache[key] = ((min_x, min_y), (max_x, max_y))
        return self._bounds_cache[key]

    def canvas(self, weapon_scale: float = 1.0, pad: float = 20.0):
        (mnx, mny), (mxx, mxy) = self._bounds(weapon_scale)
        origin = (mnx - pad, mny - pad)
        return origin, (mxx + pad - origin[0], mxy + pad - origin[1])


def is_weapon(stem: str) -> bool:
    return stem.startswith(("sword", "bow", "arrow"))


def _f(attrs, key, default):
    try:
        v = float(attrs[key])
        return v if math.isfinite(v) else default
    except (KeyError, ValueError):
        return default


def _child_world(lx, ly, ppos, pang, own):
    r = math.radians(pang)
    c, s = math.cos(r), math.sin(r)
    return (ppos[0] + lx * c - ly * s, ppos[1] + lx * s + ly * c), pang + own


def parse(path: Path) -> Doc:
    root = ET.parse(path).getroot()
    folders: Dict[int, Dict[int, FileDef]] = {}
    for folder in root.iter("folder"):
        fid = int(folder.get("id", 0))
        for f in folder.iter("file"):
            folders.setdefault(fid, {})[int(f.get("id", 0))] = FileDef(
                f.get("name", ""), _f(f.attrib, "width", 1), _f(f.attrib, "height", 1),
                _f(f.attrib, "pivot_x", 0), _f(f.attrib, "pivot_y", 1))
    animations: Dict[str, List[List[Placement]]] = {}
    for anim in root.iter("animation"):
        name = anim.get("name")
        bone_tl: Dict[int, Dict[int, Tuple[float, float, float]]] = {}
        obj_tl: Dict[int, Dict[int, dict]] = {}
        for tl in anim.iter("timeline"):
            tid = int(tl.get("id", -1))
            for key in tl.findall("key"):
                kid = int(key.get("id", -1))
                for b in key.findall("bone"):
                    bone_tl.setdefault(tid, {})[kid] = (_f(b.attrib, "x", 0), _f(b.attrib, "y", 0), _f(b.attrib, "angle", 0))
                for o in key.findall("object"):
                    obj_tl.setdefault(tid, {})[kid] = dict(
                        folder=int(o.get("folder", 0)), file=int(o.get("file", 0)),
                        x=_f(o.attrib, "x", 0), y=_f(o.attrib, "y", 0), angle=_f(o.attrib, "angle", 0),
                        px=_f(o.attrib, "pivot_x", math.nan), py=_f(o.attrib, "pivot_y", math.nan),
                        a=_f(o.attrib, "a", 1))
        frames: List[List[Placement]] = []
        mainline = anim.find("mainline")
        for key in (mainline.findall("key") if mainline is not None else []):
            worlds: Dict[int, Tuple[Tuple[float, float], float]] = {}
            for ref in key.findall("bone_ref"):
                bx, by, ba = bone_tl.get(int(ref.get("timeline", -1)), {}).get(int(ref.get("key", -1)), (0, 0, 0))
                parent = ref.get("parent")
                if parent is not None and int(parent) in worlds:
                    pw = worlds[int(parent)]
                    worlds[int(ref.get("id", -1))] = _child_world(bx, by, pw[0], pw[1], ba)
                else:
                    worlds[int(ref.get("id", -1))] = ((bx, by), ba)
            placements: List[Placement] = []
            for ref in key.findall("object_ref"):
                obj = obj_tl.get(int(ref.get("timeline", -1)), {}).get(int(ref.get("key", -1)))
                if not obj:
                    continue
                fd = folders.get(obj["folder"], {}).get(obj["file"])
                if not fd:
                    continue
                px = obj["px"] if math.isfinite(obj["px"]) else fd.pivot_x
                py = obj["py"] if math.isfinite(obj["py"]) else fd.pivot_y
                parent = ref.get("parent")
                if parent is not None and int(parent) in worlds:
                    pw = worlds[int(parent)]
                    pos, ang = _child_world(obj["x"], obj["y"], pw[0], pw[1], obj["angle"])
                else:
                    pos, ang = (obj["x"], obj["y"]), obj["angle"]
                placements.append(Placement(fd, pos[0], pos[1], ang, px, py, int(ref.get("z_index", 0)), obj["a"]))
            if placements:
                frames.append(placements)
        if frames and name:
            animations[name] = frames
    return Doc(animations)


_doc_cache: Dict[str, Doc] = {}


def load_doc(race_dir: str, variant: int) -> Doc:
    pid = pack_id(race_dir, variant)
    if pid not in _doc_cache:
        _doc_cache[pid] = parse(pack_dir(race_dir, variant) / f"{pid}.scml")
    return _doc_cache[pid]


# --------------------------------------------------------------------------
# Rasterization

PartProvider = Callable[[Placement], Iterable[Image.Image]]


def _draw(canvas: Image.Image, img: Image.Image, p: Placement, origin, canvas_h: float,
          scale: float, extra: float = 1.0, offset=(0.0, 0.0), extra_rot: float = 0.0,
          sx: float = 1.0, sy: float = 1.0, local_offset=(0.0, 0.0), rect=None) -> None:
    """Draw `img` like SpriteRenderer.draw: rect sized to the SCML file (times `extra`),
    anchored at the placement pivot, rotated about that pivot (y-up CCW degrees)."""
    ws, hs = p.file.width * extra * sx * scale, p.file.height * extra * sy * scale
    ang = math.radians(p.angle + extra_rot)
    ca, sa = math.cos(ang), math.sin(ang)
    # local (image-axis, y-down) offset -> screen offset: R(-angle) in y-down space
    lox, loy = local_offset
    dx = offset[0] + lox * ca + loy * sa
    dy = offset[1] - lox * sa + loy * ca
    px = (p.x - origin[0] + dx) * scale
    py = (canvas_h - (p.y - origin[1]) + dy) * scale
    c, s = ca, sa
    kx, ky = img.size[0] / ws, img.size[1] / hs
    if rect is not None:   # explicit local rect (left, top, w, h) in SCML units relative to the pivot, y-down
        ws, hs = rect[2] * scale, rect[3] * scale
        kx, ky = img.size[0] / ws, img.size[1] / hs
        left_s, top_s = rect[0] * scale, rect[1] * scale
    else:
        left_s, top_s = -p.pivot_x * ws, -(1 - p.pivot_y) * hs
    coeffs = (
        c * kx, -s * kx, (-px * c + py * s - left_s) * kx,
        s * ky, c * ky, (-px * s - py * c - top_s) * ky,
    )
    out = img.convert("RGBa").transform(canvas.size, Image.AFFINE, coeffs, resample=Image.BILINEAR)
    canvas.alpha_composite(out.convert("RGBA"))


_png_cache: Dict[Path, Image.Image] = {}


def load_png(path: Path) -> Image.Image:
    if path not in _png_cache:
        _png_cache[path] = Image.open(path).convert("RGBA")
    return _png_cache[path]


def render_frame(doc: Doc, race_dir: str, variant: int, animation: str, frame_index: int,
                 provider: Optional[PartProvider] = None, scale: float = 0.5,
                 weapon_scale: float = 1.0, hide: Iterable[str] = (),
                 weapon_image: Optional[Image.Image] = None, weapon_fit: Optional[dict] = None,
                 shield_image: Optional[Image.Image] = None, shield_fit: Optional[dict] = None,
                 head_overlay: Optional[tuple] = None, canvas: Optional[tuple] = None, background=(0, 0, 0, 0)) -> Image.Image:
    """Render one frame. `provider(placement)` may return replacement layer images
    (same pixel size as the original part) drawn at the part's placement in order."""
    frames = doc.animations[animation]
    placements = frames[frame_index % len(frames)]
    origin, size = canvas if canvas is not None else doc.canvas(1.0)
    canvas = Image.new("RGBA", (max(1, round(size[0] * scale)), max(1, round(size[1] * scale))), background)
    base = pack_dir(race_dir, variant)
    pid = pack_id(race_dir, variant)
    hide = set(hide)
    swapped_weapon = weapon_image is not None
    swapped_shield = shield_image is not None
    weapon_anchor = next((p for p in placements if p.file.stem.startswith(("sword", "bow"))), None)
    shield_anchor = next((p for p in placements if p.file.stem.startswith("shield")), None) or \
        next((p for p in placements if "left_hand" in p.file.stem), None)
    for p in sorted(placements, key=lambda q: q.z):
        stem = p.file.stem
        if p.alpha < 0.01 or stem.startswith("slashfx") or stem in hide:
            continue
        if swapped_weapon and stem.startswith(("sword", "bow")):
            continue   # the arrow stays: a swapped bow still fires
        if swapped_shield and stem.startswith("shield"):
            continue
        provided = provider(p) if provider else None
        layers = list(provided) if provided is not None else None
        if layers is None:
            path = base / f"{pid}_{stem}.png"
            if not path.exists():
                continue
            layers = [load_png(path)]
        for item in layers:
            img, sx, sy = item if isinstance(item, tuple) else (item, 1.0, 1.0)
            _draw(canvas, img, p, origin, size[1], scale, sx=sx, sy=sy)
    if head_overlay is not None:
        img, fit = head_overlay        # fit: cx, baseY, widthPx (head px), nominal: width, anchorU, anchorV, headPngSize
        head = next((p for p in placements if p.file.stem == "head"), None)
        if head is not None:
            k = fit["widthPx"] / fit["nominalWidth"]
            f = head.file.width / fit["headPngSize"][0]
            left = (fit["cx"] - k * fit["anchorU"]) * f - head.pivot_x * head.file.width
            top = (fit["baseY"] - k * fit["anchorV"]) * f - (1 - head.pivot_y) * head.file.height
            _draw(canvas, img, head, origin, size[1], scale, rect=(left, top, img.size[0] * k * f, img.size[1] * k * f))
    if swapped_weapon and weapon_anchor is not None:
        fit = weapon_fit or {}
        _draw(canvas, weapon_image, weapon_anchor, origin, size[1], scale,
              extra=fit.get("scale", 1.0) * weapon_scale, local_offset=fit.get("offset", (0, 0)),
              extra_rot=fit.get("rotation", 0.0))
    if swapped_shield and shield_anchor is not None:
        fit = shield_fit or {}
        _draw(canvas, shield_image, shield_anchor, origin, size[1], scale,
              extra=fit.get("scale", 1.0), local_offset=fit.get("offset", (0, 0)),
              extra_rot=fit.get("rotation", 0.0))
    return canvas
