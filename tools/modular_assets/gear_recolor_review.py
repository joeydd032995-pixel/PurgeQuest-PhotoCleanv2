"""Render all 99 gear assets as original/recolored pairs from bundled resources.

Run: python3 -I tools/modular_assets/gear_recolor_review.py
This writes review sheets only, without modifying masks or approval records.
"""
from pathlib import Path
import json
import math
import sys
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'tools/modular_assets'))
import qa

ART = REPO / 'ios/PurgeQuest/Art'
OUT = REPO / 'docs/modular/verification'
OUT.mkdir(parents=True, exist_ok=True)
resources = {p.stem: p for p in ART.rglob('*.png')}
items = json.loads((ART / 'Modular/modular_gear_manifest.json').read_text())['items']
colors = {'primary': (.16, .46, .82), 'secondary': (.72, .14, .24),
          'trim': (.85, .65, .20), 'leather': (.36, .22, .12), 'emissive': (.12, .83, .88)}
font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(size):
    try:
        return ImageFont.truetype(font_path, size)
    except OSError:
        return ImageFont.load_default(size=size)
BG = (26, 30, 40, 255)
CARD = (45, 50, 64, 255)


def fit_texture(image, box):
    cropped = image.crop(image.getchannel('A').getbbox())
    factor = min(box[0] / cropped.width, box[1] / cropped.height)
    return cropped.resize((max(1, round(cropped.width * factor)), max(1, round(cropped.height * factor))), Image.Resampling.LANCZOS)


def atlas(name, title, selected, columns, cell_width):
    cell_height = 224
    header = 90
    rows = math.ceil(len(selected) / columns)
    canvas = Image.new('RGBA', (columns * cell_width, header + rows * cell_height), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 13), title, font=font(24), fill='#F0F4FC')
    draw.text((18, 47), 'Every tile: ORIGINAL (left)  |  RECOLORED (right) — current masks, preserved alpha and shading',
              font=font(14), fill='#C1C8D7')
    for n, item in enumerate(selected):
        x, y = (n % columns) * cell_width, header + (n // columns) * cell_height
        draw.rounded_rectangle((x+7, y+5, x+cell_width-7, y+cell_height-5), radius=10, fill=CARD)
        label = item['name']
        label_font = font(14)
        while draw.textbbox((0,0), label, font=label_font)[2] > cell_width-30 and len(label)>20:
            label = label[:-2].rstrip() + '…'
        draw.text((x+16, y+14), label, font=label_font, fill='#F0F4FC')
        with Image.open(resources[item['resourceName']]) as im:
            source = im.convert('RGBA')
        masks = {}
        for region, resource in item['maskResources'].items():
            with Image.open(resources[resource]) as im:
                masks[region] = im.convert('L')
        recolored = qa.recolor(source, masks, item['regionTone'], colors)
        slot_width = (cell_width-38)//2
        for side, texture in enumerate([source, recolored]):
            fitted = fit_texture(texture, (slot_width-8, 143))
            left = x + 14 + side*(slot_width+10)
            canvas.alpha_composite(fitted, (left+(slot_width-fitted.width)//2, y+43+(143-fitted.height)//2))
        draw.text((x+16, y+195), ', '.join(item['maskResources']), font=font(11), fill='#AAB6CE')
    target = OUT / name
    canvas.convert('RGB').save(target, optimize=True)
    print(f'{target} ({len(selected)} assets; {canvas.width}x{canvas.height})')
    return target

outputs = [
    atlas('gear_assets_signature.png', '8 SIGNATURE WEAPONS — including the Elven Recurve', [i for i in items if i['group']=='signature'], 2, 560),
    atlas('gear_assets_staves.png', 'ALL 40 STAVES — eight sets, tiers I–V across each row', [i for i in items if i['group'].startswith('staff')], 5, 280),
    atlas('gear_assets_shields.png', 'ALL 40 SHIELDS — eight sets, tiers I–V across each row', [i for i in items if i['group'].startswith('shield')], 5, 280),
    atlas('gear_assets_store.png', 'STORE GEAR — 9 weapons and 2 named shields', [i for i in items if i['group']=='store'], 3, 400)
]
print('Rendered 99 original/recolored asset pairs using current masks.')
