"""Procedural sprites for the 11 store weapons and shields that previously existed only as SwiftUI shapes.
(The three headpieces were drawn and then removed on request.)

Weapons are 400x128 (hilt left, blade right, centre line y=64, same convention as the race
swords so the standard anchor/grip model applies). Shields are 160x160.

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
]

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    spec = []
    for item_id, name, kind, resource, fn in ITEMS:
        img = fn()
        img.save(OUT / f"{resource}.png", optimize=True)
        spec.append({"id": item_id, "name": name, "kind": kind, "resource": resource, "imageSize": list(img.size)})
    SPEC.write_text(json.dumps({"schemaVersion": 1, "items": spec}, indent=1) + "\n")
    print(f"wrote {len(spec)} store sprites to {OUT}")


if __name__ == "__main__":
    main()
