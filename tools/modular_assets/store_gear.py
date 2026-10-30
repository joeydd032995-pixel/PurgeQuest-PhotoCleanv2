"""Procedural sprites for the 14 store items that previously existed only as SwiftUI shapes.

Weapons are 400x128 (hilt left, blade right, centre line y=64, same convention as the race
swords so the standard anchor/grip model applies). Shields are 160x160. Headpieces are
520x640 overlays with their brim/base line at y=400 and dome width 380 at that line; the
per-pack head fit (held_gear.py) positions and scales them on each race's head.

Catalog IDs, prices and unlock rules live in GameDataService and are untouched; this file
only supplies art + the resource mapping (store_gear_spec.json).
"""
from __future__ import annotations

import json
import math
from pathlib import Path
from typing import List, Tuple

import numpy as np
from PIL import Image, ImageDraw

import sys
sys.path.insert(0, str(Path(__file__).parent))
import imgops as ops

OUT = Path(__file__).resolve().parents[2] / "ios" / "PurgeQuest" / "Art" / "Gear" / "store"
SPEC = Path(__file__).with_name("store_gear_spec.json")
SS = 4
INK = (27, 26, 33, 255)


def rgb(h: str) -> Tuple[int, int, int, int]:
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def _p(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def poly(self, pts, fill):
        self.d.polygon(self._p(pts), fill=rgb(fill) if isinstance(fill, str) else fill)

    def rect(self, x0, y0, x1, y1, fill):
        self.d.rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=rgb(fill) if isinstance(fill, str) else fill)

    def ellipse(self, cx, cy, rx, ry, fill):
        self.d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=rgb(fill) if isinstance(fill, str) else fill)

    def line(self, pts, fill, width):
        self.d.line(self._p(pts), fill=rgb(fill) if isinstance(fill, str) else fill, width=int(width * SS), joint="curve")

    def star(self, cx, cy, r, fill, points=5, inner=0.45, rot=-90):
        pts = []
        for i in range(points * 2):
            rr = r if i % 2 == 0 else r * inner
            a = math.radians(rot + i * 180 / points)
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        self.poly(pts, fill)

    def hole(self, shape: str, *args):
        """Cut transparent holes (used for face openings / sprocket holes)."""
        mask = Image.new("L", self.img.size, 0)
        md = ImageDraw.Draw(mask)
        if shape == "ellipse":
            cx, cy, rx, ry = args
            md.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=255)
        a = np.asarray(self.img).copy()
        a[np.asarray(mask) > 0] = 0
        self.img = Image.fromarray(a, "RGBA")
        self.d = ImageDraw.Draw(self.img)

    def finish(self, outline: float = 5.0, inner_outline: bool = False) -> Image.Image:
        a = np.asarray(self.img)[..., 3] > 8
        r = int(outline * SS)
        halo = ops.dilate(a, r)
        under = np.zeros(a.shape + (4,), np.uint8)
        under[halo] = INK
        base = Image.fromarray(under, "RGBA")
        base.alpha_composite(self.img)
        return base.resize((self.w, self.h), Image.LANCZOS)


# ------------------------------------------------------------------ weapons

def blade_polygon(x0, x1, half_base, half_tip, tip=24):
    return [(x0, 64 - half_base), (x1 - tip, 64 - half_tip), (x1, 64), (x1 - tip, 64 + half_tip), (x0, 64 + half_base)]


def hilt(c: Canvas, guard_x=76, guard_h=70, grip="#6b4a2f", metal="#c9a64a", pommel="#c9a64a"):
    c.rect(24, 57, guard_x, 71, grip)
    c.rect(24, 57, guard_x, 61, "#8a6340")
    c.ellipse(18, 64, 11, 11, pommel)
    c.rect(guard_x, 64 - guard_h / 2, guard_x + 12, 64 + guard_h / 2, metal)
    c.rect(guard_x, 64 - guard_h / 2, guard_x + 12, 64 - guard_h / 2 + 5, "#e8d089")


def shard() -> Image.Image:
    c = Canvas(400, 128)
    hilt(c, 72, 50, "#4a4f66", "#8f98b5", "#8f98b5")
    c.poly([(84, 50), (250, 34), (350, 64), (250, 94), (84, 78)], "#6fb4e6")
    c.poly([(84, 50), (250, 34), (350, 64), (84, 64)], "#bfe9ff")
    c.poly([(150, 44), (250, 34), (350, 64), (220, 60)], "#e8f8ff")
    c.line([(88, 64), (340, 64)], "#4f8fc2", 3)
    return c.finish()


def reel() -> Image.Image:
    c = Canvas(400, 128)
    c.rect(24, 58, 70, 70, "#4a3f55")
    c.ellipse(16, 64, 10, 10, "#2f2a38")
    c.poly(blade_polygon(100, 385, 15, 7, 38), "#e6e4d8")
    c.poly([(100, 49), (347, 57), (385, 64), (100, 64)], "#fbf9ee")
    c.line([(104, 64), (370, 64)], "#a9a698", 3)
    c.ellipse(86, 64, 36, 36, "#cfd3dc")
    c.ellipse(86, 64, 28, 28, "#2f3447")
    c.ellipse(86, 64, 9, 9, "#cfd3dc")
    for i in range(6):
        a = math.radians(i * 60)
        c.ellipse(86 + 18 * math.cos(a), 64 + 18 * math.sin(a), 5, 5, "#cfd3dc")
    return c.finish()


def gem_hammer() -> Image.Image:
    c = Canvas(400, 128)
    c.rect(20, 57, 306, 71, "#6b4a2f")
    c.rect(20, 57, 306, 62, "#8a6340")
    c.ellipse(16, 64, 10, 10, "#c9a64a")
    c.rect(292, 14, 388, 114, "#8d97a8")
    c.rect(292, 14, 388, 34, "#c3cad6")
    c.rect(292, 96, 388, 114, "#626b7c")
    c.rect(288, 52, 300, 76, "#c9a64a")
    for cx, cy, col in ((318, 64, "#46d6a8"), (360, 64, "#f2c14e")):
        c.ellipse(cx, cy, 15, 15, "#c9a64a")
        c.ellipse(cx, cy, 10, 10, col)
        c.ellipse(cx - 3, cy - 3, 3, 3, "#ffffff")
    return c.finish()


def archmage_staff() -> Image.Image:
    c = Canvas(400, 128)
    c.rect(20, 58, 330, 70, "#6b4a2f")
    c.rect(20, 58, 330, 62, "#8a6340")
    c.ellipse(14, 64, 9, 9, "#c9a64a")
    for dy in (-1, 1):
        c.poly([(316, 64 + dy * 8), (345, 64 + dy * 34), (378, 64 + dy * 26), (360, 64 + dy * 6)], "#d9b44f")
    c.ellipse(352, 64, 27, 27, "#2f8a6f")
    c.ellipse(352, 64, 21, 21, "#47c9a0")
    c.ellipse(344, 56, 7, 7, "#d9fff0")
    return c.finish()


def storm_cleaver() -> Image.Image:
    c = Canvas(400, 128)
    hilt(c, 76, 66, "#3f4659", "#9aa4b8", "#9aa4b8")
    c.poly([(88, 36), (330, 30), (380, 64), (330, 98), (88, 92)], "#aeb8cc")
    c.poly([(88, 36), (330, 30), (380, 64), (88, 64)], "#dfe6f2")
    c.poly([(200, 40), (246, 40), (224, 62), (252, 62), (190, 100), (212, 70), (186, 70)], "#f5d84a")
    return c.finish()


def oathbreaker() -> Image.Image:
    c = Canvas(400, 128)
    hilt(c, 84, 100, "#3d3a47", "#7e889c", "#7e889c")
    c.poly(blade_polygon(98, 392, 17, 9, 40), "#b9c2d3")
    c.poly([(98, 47), (352, 55), (392, 64), (98, 64)], "#e8edf5")
    for i in range(4):
        x = 150 + i * 52
        c.line([(x, 46), (x + 22, 64), (x, 82)], "#6c768a", 4)
    return c.finish()


def ruby_fang() -> Image.Image:
    c = Canvas(400, 128)
    c.rect(26, 57, 74, 71, "#4a2f2f")
    c.ellipse(18, 64, 12, 12, "#c9a64a")
    c.ellipse(18, 64, 7, 7, "#d63a4f")
    c.rect(74, 26, 88, 102, "#c9a64a")
    c.poly([(88, 48), (200, 34), (300, 40), (372, 78), (300, 70), (200, 66), (88, 80)], "#b83145")
    c.poly([(88, 48), (200, 34), (300, 40), (372, 78), (200, 56), (88, 62)], "#e0566b")
    c.ellipse(112, 64, 7, 7, "#ff9aa9")
    return c.finish()


def arcane_edge() -> Image.Image:
    c = Canvas(400, 128)
    hilt(c, 78, 76, "#3a4a3f", "#d9b44f", "#d9b44f")
    c.poly(blade_polygon(92, 390, 15, 8, 40), "#3fb58f")
    c.poly([(92, 49), (350, 56), (390, 64), (92, 64)], "#8ff0cd")
    c.line([(98, 64), (370, 64)], "#2a8566", 3)
    c.ellipse(86, 64, 8, 8, "#d9fff0")
    return c.finish()


def firework_blade() -> Image.Image:
    c = Canvas(400, 128)
    hilt(c, 76, 64, "#403647", "#b9b6c9", "#b9b6c9")
    c.poly(blade_polygon(90, 386, 15, 8, 38), "#e4e7ef")
    c.poly([(90, 49), (348, 56), (386, 64), (90, 64)], "#fbfcff")
    for x, y, col, r in ((150, 64, "#ff7a3d", 15), (225, 54, "#ff4fa3", 12), (292, 70, "#3dd6ff", 13), (350, 62, "#ffd84a", 10)):
        c.star(x, y, r, col, points=8, inner=0.4)
    return c.finish()


# ------------------------------------------------------------------ shields

def heater(c: Canvas, field: str, field_hi: str, cross: str, rivet: str, trim: str):
    pts = [(24, 20), (136, 20), (140, 84), (80, 146), (20, 84)]
    c.poly(pts, trim)
    inner = [(33, 29), (127, 29), (130, 82), (80, 132), (30, 82)]
    c.poly(inner, field)
    c.poly([(33, 29), (127, 29), (130, 60), (33, 60)], field_hi)
    c.rect(72, 30, 88, 128, cross)
    c.rect(36, 58, 124, 74, cross)
    for x, y in ((40, 38), (120, 38), (36, 78), (124, 78), (80, 120)):
        c.ellipse(x, y, 6, 6, rivet)
        c.ellipse(x - 2, y - 2, 2, 2, "#ffffff")


def azure_aegis() -> Image.Image:
    c = Canvas(160, 160)
    heater(c, "#3f6fae", "#5b8bcc", "#e2bd4a", "#e2bd4a", "#8fa4c4")
    return c.finish(outline=5)


def templar_bulwark() -> Image.Image:
    c = Canvas(160, 160)
    heater(c, "#e6e4da", "#f7f6ef", "#b92a3b", "#d9b44f", "#a8a69b")
    return c.finish(outline=5)


# ------------------------------------------------------------------ headpieces
# 520x640 overlays. The brim/brow line is y=400 and the dome is 380 wide there; the head fit scales that to each
# race's *bare* head (anatomy layer), so cheek guards and hood drapes reach the jaw instead of floating.

HP_W, HP_H, HP_BASE = 520, 640, 400


def catmull(pts, closed=True, n=14):
    P = np.array(pts, float)
    ext = np.vstack([P[-1], P, P[0], P[1]]) if closed else np.vstack([P[0], P, P[-1]])
    last = len(P) + 1 if closed else len(P)
    out = []
    for i in range(1, last):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    if not closed:
        out.append(P[-1])
    return [tuple(p) for p in out]


def mix(c0, c1, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c0, c1))


class Art(Canvas):
    """Canvas with smooth shapes, gradients, clipped strokes and soft highlights."""

    def mask(self, pts) -> Image.Image:
        m = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(m).polygon(self._p(pts), fill=255)
        return m

    def gradient(self, mask: Image.Image, top: str, bottom: str, side: float = 0.0):
        """Vertical gradient (optionally shaded darker toward the right by `side`) clipped to `mask`."""
        x0, y0, x1, y1 = mask.getbbox()
        h, w = y1 - y0, x1 - x0
        c0, c1 = np.array(rgb(top)[:3], float), np.array(rgb(bottom)[:3], float)
        t = np.linspace(0, 1, max(h, 1))[:, None, None]
        arr = c0 * (1 - t) + c1 * t
        arr = np.broadcast_to(arr, (h, w, 3)).copy()
        if side:
            arr = np.clip(arr * (1 - side * np.linspace(0, 1, w))[None, :, None], 0, 255)
        tile = np.concatenate([arr, np.full((h, w, 1), 255.0)], axis=-1).astype(np.uint8)
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        layer.paste(Image.fromarray(tile, "RGBA"), (x0, y0))
        a = np.asarray(layer)[..., 3] * (np.asarray(mask) / 255.0)
        out = np.asarray(layer).copy()
        out[..., 3] = a.astype(np.uint8)
        self.img.alpha_composite(Image.fromarray(out, "RGBA"))

    def fill(self, pts, top, bottom=None, side=0.0):
        m = self.mask(pts)
        self.gradient(m, top, bottom or top, side)
        return m

    def stroke(self, pts, color, width, clip=None):
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).line(self._p(pts), fill=rgb(color) if isinstance(color, str) else color, width=int(width * SS), joint="curve")
        self._clip_composite(layer, clip)

    def arcs(self, boxes, color, width, clip=None):
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for (cx, cy, r) in boxes:
            d.arc([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], 20, 160, fill=rgb(color), width=int(width * SS))
        self._clip_composite(layer, clip)

    def glow(self, cx, cy, rx, ry, color=(255, 255, 255), alpha=0.35, clip=None, blur=14):
        from PIL import ImageFilter
        layer = Image.new("RGBA", self.img.size, color + (0,))
        m = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(m).ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=int(255 * alpha))
        m = m.filter(ImageFilter.GaussianBlur(blur * SS))
        layer.putalpha(m)
        self._clip_composite(layer, clip)

    def _clip_composite(self, layer, clip):
        if clip is not None:
            a = np.asarray(layer).copy()
            a[..., 3] = (a[..., 3] * (np.asarray(clip) / 255.0)).astype(np.uint8)
            layer = Image.fromarray(a, "RGBA")
        self.img.alpha_composite(layer)

    def cut(self, pts):
        m = self.mask(pts)
        a = np.asarray(self.img).copy()
        a[np.asarray(m) > 0] = 0
        self.img = Image.fromarray(a, "RGBA")
        self.d = ImageDraw.Draw(self.img)


def starlit_cap() -> Image.Image:
    c = Art(HP_W, HP_H)
    # brim: dark underside then lit top, snug (1.24x the dome) so the hat reads as a cap, not a parasol
    c.ellipse(260, 410, 236, 44, "#1d2160")
    c.ellipse(260, 402, 236, 40, "#3b429a")
    c.glow(190, 392, 120, 12, alpha=0.30, blur=8)
    cone = catmull([(84, 398), (96, 330), (130, 250), (178, 170), (235, 104), (298, 58), (360, 40), (385, 52), (372, 86),
                    (338, 126), (330, 190), (368, 270), (418, 340), (438, 398), (350, 412), (170, 412)])
    m = c.fill(cone, "#5560c8", "#262c78", side=0.25)
    c.glow(190, 230, 70, 120, alpha=0.30, clip=m, blur=22)
    # soft crumple folds
    c.stroke(catmull([(150, 360), (180, 300), (232, 220), (290, 130)], closed=False), "#20266e", 4, clip=m)
    c.stroke(catmull([(330, 380), (320, 300), (338, 220), (362, 130)], closed=False), "#20266e", 4, clip=m)
    # gold band + buckle
    band = catmull([(90, 352), (170, 338), (260, 334), (350, 338), (430, 352), (436, 398), (350, 384), (260, 381), (170, 384), (88, 398)], n=10)
    bm = c.fill(band, "#f1cf6b", "#b88a2a")
    c.glow(200, 350, 90, 6, alpha=0.5, clip=bm, blur=4)
    c.rect(244, 346, 276, 384, "#8a6420")
    c.rect(250, 352, 270, 378, "#f4dc86")
    c.rect(256, 360, 264, 370, "#8a6420")
    # stars
    c.star(240, 240, 46, "#ffe58a")
    c.star(240, 240, 26, "#fff7d2")
    for x, y, r in ((330, 168, 17), (160, 296, 15), (318, 290, 13), (205, 150, 10)):
        c.star(x, y, r, "#ffe58a")
    return c.finish(outline=5.5)


def shadow_hood() -> Image.Image:
    c = Art(HP_W, HP_H)
    outer = catmull([(292, 46), (338, 104), (412, 150), (474, 250), (500, 400), (514, 530), (496, 600), (440, 630), (390, 616),
                     (330, 636), (260, 620), (190, 636), (130, 616), (80, 630), (24, 600), (6, 530), (20, 400), (48, 250),
                     (108, 150), (200, 104), (256, 82)], n=12)
    m = c.fill(outer, "#454d7c", "#1b1f38", side=0.30)
    c.glow(150, 200, 110, 150, alpha=0.32, clip=m, blur=30)
    # hanging cloth folds
    for pts in ([(70, 300), (52, 420), (60, 520), (46, 610)], [(448, 300), (468, 420), (456, 520), (472, 610)],
                [(120, 200), (88, 300), (84, 380)], [(404, 200), (436, 300), (440, 380)]):
        c.stroke(catmull(pts, closed=False), "#12142a", 4.5, clip=m)
    opening = catmull([(260, 298), (336, 314), (392, 366), (412, 450), (396, 540), (332, 590), (260, 604), (188, 590), (124, 540),
                       (108, 450), (128, 366), (184, 314)], n=12)
    # darker inner lining around the opening, then the opening itself is cut so the face shows through
    lining = catmull([(260, 268), (350, 288), (418, 350), (442, 450), (424, 556), (346, 622), (260, 636), (174, 622), (96, 556),
                      (78, 450), (102, 350), (170, 288)], n=12)
    lm = c.mask(lining)
    inner = Image.fromarray(np.asarray(lm) * (np.asarray(m) > 0), "L")
    c.gradient(inner, "#2a2f55", "#0c0d19")
    c.stroke(lining + [lining[0]], "#0b0c18", 3.5, clip=m)
    c.cut(opening)
    return c.finish(outline=5.5)


def dragoncrest_helm() -> Image.Image:
    c = Art(HP_W, HP_H)
    # crest first (behind the dome): swept crimson fin
    fin = catmull([(232, 150), (218, 96), (232, 48), (262, 22), (276, 62), (304, 40), (330, 70), (318, 150)], n=12)
    fm = c.fill(fin, "#ec5a70", "#8a1c33", side=0.2)
    c.stroke(catmull([(262, 40), (258, 90), (262, 140)], closed=False), "#6a1126", 4, clip=fm)
    c.stroke(catmull([(300, 62), (296, 100), (298, 142)], closed=False), "#6a1126", 3, clip=fm)
    dome = catmull([(78, 400), (68, 330), (92, 236), (146, 168), (214, 134), (260, 128), (306, 134), (374, 168), (428, 236), (452, 330),
                    (442, 400), (350, 408), (170, 408)], n=12)
    dm = c.fill(dome, "#f6dc83", "#a87a26", side=0.28)
    # dragon-scale rows
    boxes = []
    for r in range(5):
        y = 170 + r * 36
        for x in range(60 + (18 if r % 2 else 0), 470, 36):
            boxes.append((x, y, 18))
    c.arcs(boxes, "#9b6e22", 3, clip=dm)
    c.glow(190, 210, 100, 56, alpha=0.40, clip=dm, blur=16)
    # brow band with rivets and a nasal guard
    band = catmull([(70, 330), (146, 296), (260, 284), (374, 296), (450, 330), (448, 380), (374, 344), (260, 334), (146, 344), (72, 380)], n=10)
    bm = c.fill(band, "#d4a53a", "#8a6420")
    c.glow(220, 318, 120, 8, alpha=0.45, clip=bm, blur=5)
    for x, y in ((120, 330), (190, 316), (260, 312), (330, 316), (400, 330)):
        c.ellipse(x, y, 6, 6, "#f6dc83")
    c.poly([(244, 336), (276, 336), (270, 456), (260, 474), (250, 456)], "#c79a35")
    c.poly([(250, 340), (262, 340), (260, 452), (254, 450)], "#f2d779")
    # cheek guards frame an open face
    for sx in (1, -1):
        def X(x):
            return 260 + sx * (x - 260) if sx == 1 else 260 - (x - 260)
        guard = catmull([(X(74), 372), (X(150), 346), (X(160), 420), (X(178), 500), (X(160), 552), (X(112), 540), (X(80), 470)], n=10)
        gm = c.fill(guard, "#e7c261", "#946b24", side=0.2 * sx)
        c.stroke(catmull([(X(100), 400), (X(128), 450), (X(138), 520)], closed=False), "#8a6420", 3, clip=gm)
        c.ellipse(X(112), 392, 6, 6, "#f6dc83")
    return c.finish(outline=5.5)


ITEMS = [
    # id, name, kind, resource, draw
    ("weapon.shard", "Crystal Shard", "sword", "store_weapon_shard", shard),
    ("weapon.reel", "Film Reel Blade", "sword", "store_weapon_reel", reel),
    ("weapon.gem", "Gem Hammer", "hammer", "store_weapon_gem", gem_hammer),
    ("weapon.staff", "Archmage Staff", "staff", "store_weapon_staff", archmage_staff),
    ("weapon.stormblade", "Storm Cleaver", "sword", "store_weapon_stormblade", storm_cleaver),
    ("weapon.chevron", "Oathbreaker Greatsword", "sword", "store_weapon_chevron", oathbreaker),
    ("weapon.ruby", "Ruby Fang", "sword", "store_weapon_ruby", ruby_fang),
    ("weapon.arcane", "Arcane Edge", "sword", "store_weapon_arcane", arcane_edge),
    ("weapon.fireworkBlade", "Firework Blade", "sword", "store_weapon_fireworkBlade", firework_blade),
    ("shield.crux", "Azure Aegis", "shield", "store_shield_crux", azure_aegis),
    ("shield.templar", "Templar Bulwark", "shield", "store_shield_templar", templar_bulwark),
    ("head.starhat", "Starlit Cap", "headpiece", "store_head_starhat", starlit_cap),
    ("head.hood", "Shadow Hood", "headpiece", "store_head_hood", shadow_hood),
    ("head.dragoncrest", "Dragoncrest Helm", "headpiece", "store_head_dragoncrest", dragoncrest_helm),
]

HEADPIECE_NOMINAL = {"width": 380.0, "anchorU": 260.0, "anchorV": 400.0}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    spec = []
    for item_id, name, kind, resource, fn in ITEMS:
        img = fn()
        img.save(OUT / f"{resource}.png", optimize=True)
        spec.append({"id": item_id, "name": name, "kind": kind, "resource": resource, "imageSize": list(img.size)})
    SPEC.write_text(json.dumps({"schemaVersion": 1, "headpieceNominal": HEADPIECE_NOMINAL, "items": spec}, indent=1) + "\n")
    print(f"wrote {len(spec)} store sprites to {OUT}")


if __name__ == "__main__":
    main()
