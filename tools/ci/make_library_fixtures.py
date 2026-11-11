#!/usr/bin/env python3
"""Make a small, synthetic photo library for the simulator, so UI screenshots show real combat cards.

  python3 tools/ci/make_library_fixtures.py OUT_DIR
  xcrun simctl addmedia <udid> OUT_DIR/*.jpg

Every picture is drawn here from a fixed seed: no photographs, no people, nothing licensed. The set is
chosen to summon a spread of monsters: ordinary scenes, a blurred one, a nearly black one, a pair of
copies, a wide panorama, a tall narrow "saved from elsewhere" frame and a thumbnail-sized image.
Needs Pillow.
"""
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SKIES = [((28, 54, 94), (238, 178, 120)), ((18, 30, 52), (120, 86, 140)), ((120, 170, 210), (236, 232, 214)),
         ((70, 40, 60), (240, 140, 90)), ((20, 60, 70), (170, 214, 190)), ((54, 44, 80), (226, 190, 150))]


def scene(seed: int, size=(1600, 1200)) -> Image.Image:
    """A layered landscape: a sky gradient, a sun, three ridges and some sharp detail in the foreground."""
    rng = random.Random(seed)
    width, height = size
    top, bottom = SKIES[seed % len(SKIES)]
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    for y in range(height):
        t = y / max(1, height - 1)
        draw.line([(0, y), (width, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    sun = (rng.randint(width // 5, 4 * width // 5), rng.randint(height // 6, height // 2))
    radius = rng.randint(height // 14, height // 8)
    draw.ellipse([sun[0] - radius, sun[1] - radius, sun[0] + radius, sun[1] + radius], fill=(250, 232, 190))
    for layer in range(3):
        base = height * (0.52 + 0.14 * layer)
        shade = tuple(max(0, int(c * (0.55 - 0.16 * layer))) for c in bottom)
        points = [(0, height)]
        x = 0
        while x <= width:
            points.append((x, base + rng.uniform(-1, 1) * height * 0.09))
            x += rng.randint(width // 14, width // 7)
        points += [(width, base), (width, height)]
        draw.polygon(points, fill=shade)
    for _ in range(140):   # fine, high-contrast detail so a sharp picture measures as sharp
        x, y = rng.randint(0, width), rng.randint(int(height * 0.72), height)
        h = rng.randint(height // 60, height // 22)
        draw.line([(x, y), (x + rng.randint(-6, 6), y - h)], fill=(rng.randint(150, 235), rng.randint(150, 220), rng.randint(90, 150)), width=2)
    return img


def main() -> int:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "library-fixtures")
    out.mkdir(parents=True, exist_ok=True)
    pictures = {f"scene-{i:02d}": scene(i) for i in range(1, 7)}
    pictures["copy-a"] = scene(2)
    pictures["copy-b"] = scene(2)                                     # a duplicate pair with scene-02
    pictures["blurred"] = scene(7).filter(ImageFilter.GaussianBlur(14))
    pictures["dark"] = Image.eval(scene(8), lambda v: v // 14)        # a dead-dark frame
    pictures["panorama"] = scene(9, size=(3600, 1200))
    pictures["tall-download"] = scene(10, size=(1080, 1920))
    pictures["thumbnail"] = scene(11, size=(480, 360))
    for name, picture in pictures.items():
        picture.save(out / f"{name}.jpg", quality=86)
    print(f"wrote {len(pictures)} pictures to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
