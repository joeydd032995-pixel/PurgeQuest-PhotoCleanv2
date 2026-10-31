"""Review the three reported models using the shipped resources/masks/tones.

Run after build_assets.py. No approval records are written. These reference
renders use the same original-pixel material blend as the native recolorer.
"""
from pathlib import Path
import json
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import qa
import scml

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / 'docs/modular/verification'
CASES = {
    'necromancer_v1': ('Lost Souls', {'hair': (.82, .16, .20)},
                      {'primary': (.55, .07, .12), 'secondary': (.19, .12, .23), 'trim': (.74, .70, .58)}),
    'forest_ranger_v1': ('Elven', {'primary': (.42, .18, .70)},
                       {'secondary': (.82, .61, .19), 'leather': (.39, .24, .13)}),
    'seer_v2': ('Seer', {'primary': (.04, .55, .60)},
                {'primary': (.04, .55, .60), 'leather': (.28, .18, .10), 'trim': (.74, .50, .15)}),
}


def provider(parts, resources, colors):
    by_part = {}
    for part in parts:
        base = Image.open(resources[part['resourceBaseName']]).convert('RGBA')
        masks = {r: Image.open(resources[name]).convert('L') for r, name in part['maskResources'].items()}
        recolored = qa.recolor(base, masks, part['regionTone'], colors)
        by_part.setdefault(part['part'], []).append((part['kind'], recolored))
    order = {'anatomy': 0, 'armor': 1, 'headgear': 1, 'face': 1}

    def provide(placement):
        layers = by_part.get(placement.file.stem)
        return [image for kind, image in sorted(layers, key=lambda v: order[v[0]])] if layers else None
    return provide


def main():
    resources = {p.stem: p for p in scml.ART_ROOT.rglob('*.png')}
    parts = json.loads((scml.ART_ROOT / 'Modular/modular_races_manifest.json').read_text())['parts']
    for pid, (name, head_colors, outfit_colors) in CASES.items():
        race, variant = pid.rsplit('_v', 1)
        variant = int(variant)
        doc = scml.load_doc(race, variant)
        selected = [p for p in parts if p['pack'] == pid]
        head_parts = [p for p in selected if p['part'] == 'head']
        outfit_parts = [p for p in selected if p['part'] != 'head']
        combined = dict(outfit_colors, **head_colors)
        views = [provider(head_parts, resources, head_colors),
                 provider(outfit_parts, resources, outfit_colors),
                 provider(selected, resources, combined)]
        rows = []
        attack = 'Shooting' if 'Shooting' in doc.animations else 'Slashing'
        for animation, frame in [('Idle', 0), (attack, len(doc.animations[attack]) // 2)]:
            render = lambda **kwargs: scml.render_frame(doc, race, variant, animation, frame,
                scale=.6, background=qa.BG, **kwargs)
            images = qa.crop_to_content([render()] + [render(provider=p) for p in views])
            labels = [f'{name}: {animation} original', 'Hair / hood only', 'Clothing only', 'Combined (skin unchanged)']
            rows.append(list(zip(labels, images)))
        target = OUT / f'{pid}_recolor.png'
        qa.sheet(rows).convert('RGB').save(target, optimize=True)
        print(target.relative_to(REPO))


if __name__ == '__main__':
    main()
