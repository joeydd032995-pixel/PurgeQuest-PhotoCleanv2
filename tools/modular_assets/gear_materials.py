"""Material topology for held gear, independent of painted highlights/shadows.

Coordinates refer to original source pixels (shields 160x160, staves/swords
400x128, bow 200x320). Source ink/shadow pigments are protected exactly;
outline-bounded fill cells vote on the authored geometry so diagonal shine
never splits one material. No pixels or approval records are authored here.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import re

import numpy as np
from PIL import Image, ImageDraw

import imgops as ops

# Actual ink palettes in the bundled art, including the opaque shield drop
# shadow. Brightening this shadow caused the detached blue/red border caps.
HALO_RESOURCES = frozenset(('seer_v1_sword', 'dark_oracle_v1_sword'))
INK = ((27, 26, 24), (20, 18, 14), (20, 19, 18), (28, 31, 38), (27, 26, 33), (58, 55, 53))


@dataclass
class Surface:
    region: str
    shape: str
    points: tuple


@dataclass
class MaterialLayout:
    base: str = 'primary'
    snap_cells: bool = True
    surfaces: list[Surface] = field(default_factory=list)

    def rect(self, region, x0, y0, x1, y1):
        self.surfaces.append(Surface(region, 'rectangle', (x0, y0, x1, y1)))
        return self

    def ellipse(self, region, cx, cy, rx, ry=None):
        ry = rx if ry is None else ry
        self.surfaces.append(Surface(region, 'ellipse', (cx-rx, cy-ry, cx+rx, cy+ry)))
        return self

    def polygon(self, region, points):
        self.surfaces.append(Surface(region, 'polygon', tuple(tuple(p) for p in points)))
        return self


def protected_ink(image, exterior=True):
    rgb, alpha = ops.arrays(image)
    pixels = rgb * 255
    ink = np.zeros(alpha.shape, bool)
    for color in INK:
        ink |= np.linalg.norm(pixels - color, axis=-1) <= 2.5
    if not exterior:
        return ink & (alpha > 0)
    # The closed outer ink stroke separates the material from its drop shadow.
    # Protect the whole exterior, including antialiased shadow colours: matching
    # only an exact dark pigment leaves a bright hairline around recoloured gear.
    barrier = ops.dilate(ink & (alpha > .5),1)
    cells, _ = ops.label(~barrier)
    exterior_ids = np.unique(np.concatenate([cells[0],cells[-1],cells[:,0],cells[:,-1]]))
    exterior_ids = exterior_ids[exterior_ids != 0]
    exterior = np.isin(cells,exterior_ids)
    protected = ink | ops.dilate(exterior,1)
    return protected & (alpha > 0)


def bounds(image):
    alpha = np.asarray(image.convert('RGBA'))[...,3]
    ys,xs = np.nonzero(alpha > 230)
    x0,x1,y0,y1 = float(xs.min()),float(xs.max()),float(ys.min()),float(ys.max())
    return x0,y0,x1,y1


# Inner contours run along the source's black divider, not along a highlight.
# A material's light/dark paint bands therefore cannot create a second region.
TEARDROP_FACE = [(80,34),(103,41),(116,55),(114,76),(103,99),(80,124),(57,99),(46,76),(44,55),(57,41)]
RUNIC_FACE = [(48,36),(112,36),(112,98),(104,116),(80,130),(56,116),(48,98)]
TRIANGLE_FACE = [(41,39),(80,24),(119,39),(80,133)]
HEART_FACE = [(38,49),(58,51),(80,43),(102,51),(122,49),(116,87),(100,109),(80,125),(60,109),(44,87)]


def shield_layout(group: int, tier: int):
    s = MaterialLayout()
    # Simple wooden planks are one material, including their dark recesses.
    if tier <= 2 and group != 5:
        if group == 6:
            s.polygon('secondary', [(39,23),(54,21),(124,133),(110,139)])
        return s
    if group == 1:
        if tier >= 4:
            s = MaterialLayout('secondary').ellipse('primary',80,80,48)
        if tier >= 3:
            s.rect('trim',55,65,105,96)
        if tier == 5:
            s.ellipse('primary',80,80,51).ellipse('trim',80,80,22)
    elif group == 2:
        if tier in (3,4):
            s = MaterialLayout('secondary').polygon('primary',HEART_FACE).ellipse('trim',80,82,16)
        elif tier == 5:
            s.ellipse('trim',80,95,15)
    elif group == 3:
        if tier in (3,4):
            s = MaterialLayout('secondary').polygon('primary',TEARDROP_FACE)
        elif tier == 5:
            s.ellipse('trim',80,91,9,22)
    elif group == 4:
        if tier >= 3:
            inner = RUNIC_FACE if tier in (3,4) else [(58,40),(102,40),(102,99),(96,109),(80,114),(64,109),(58,99)]
            s = MaterialLayout('secondary').polygon('primary',inner)
    elif group == 5:
        if tier in (1,2,3):
            # Wood face, metal ring/cross, and an independently adjustable boss.
            s.ellipse('secondary',80,80,57).ellipse('primary',80,80,48)
            s.rect('secondary',74,20,86,140).rect('secondary',20,74,140,86)
            if tier >= 2:
                s.ellipse('trim',80,80,17)
        else:
            s = MaterialLayout('secondary').ellipse('primary',80,80,49).ellipse('trim',80,80,13)
    elif group == 6:
        if tier >= 3:
            inner = [(47,40),(113,40),(113,113),(103,125),(80,130),(57,125),(47,113)]
            s = MaterialLayout('secondary').polygon('primary',inner)
            if tier == 4:
                s.polygon('trim',[(49,43),(59,42),(110,117),(99,122)])
    elif group == 7:
        inner = [(53,41),(68,41),(80,29),(92,41),(107,41),(107,112),(96,127),(80,135),(64,127),(53,112)]
        s = MaterialLayout('secondary').polygon('primary',inner)
        if tier == 3:
            s.polygon('trim',[(52,51),(60,46),(111,111),(103,121)])
            s.polygon('trim',[(50,110),(58,119),(111,54),(102,47)])
    elif group == 8:
        # Tier V is one embossed metal plate, with no separate rim. Its
        # diagonal shine must not create a second surface at the corners.
        if tier == 5:
            return MaterialLayout()
        s = MaterialLayout('secondary').polygon('primary',TRIANGLE_FACE)
    return s


def staff_layout(group: int, tier: int, image):
    s = MaterialLayout()
    x0,y0,x1,y1 = bounds(image)
    w,h = x1-x0,y1-y0
    x = lambda fraction: x0+w*fraction
    cy,cx,r = (y0+y1)/2,x1-h*.5,h*.48
    if group == 1:  # crook and shaft are continuous wood; gem inside the crook
        if tier >= 2:
            s.ellipse('secondary',cx,cy,r*.44,r*.32)
        if tier >= 4:
            s.rect('trim',x0,0,x(.1),128)
    elif group == 2:  # orb is Primary; all shaded shaft pixels are Secondary
        s.base = 'secondary'
        s.ellipse('primary',cx,cy,r)
        if tier >= 4:
            s.rect('trim',x0,0,x(.1),128)
        if tier == 5:
            s.rect('trim',x(.96),0,x1,128)
    elif group == 3:  # crystal, including its reflected light bands
        s.base = 'secondary'
        s.rect('primary',x(.61),0,x1,128)
        if tier >= 3:
            s.rect('trim',x0,0,x(.09),128)
    elif group == 4:
        s.ellipse('secondary',cx,cy,r*.44,r*.34)
        if tier >= 3:
            s.rect('trim',x0,0,x(.09),128)
    elif group == 5:
        s.ellipse('secondary',cx,cy,r*.44,r*.32)
    elif group == 6:
        # The cross-hatching is carved/shaded into the same continuous wood.
        if tier >= 3:
            s.rect('trim',x0,0,x(.12),128)
        if tier == 5:
            s.ellipse('secondary',x(.9),cy,r*.35)
    elif group == 7:
        s.base = 'secondary'
        s.ellipse('primary',cx,cy,r)
        if tier >= 3:
            s.rect('trim',x0,0,x(.12),128)
    elif group == 8:
        s.base = 'secondary'
        s.ellipse('primary',cx,cy,r)
        if tier >= 4:
            s.rect('trim',x0,0,x(.10),128)
    return s


def signature_layout(resource, image):
    s = MaterialLayout()
    x0,y0,x1,y1 = bounds(image)
    cy,cx,r = (y0+y1)/2,x1-(y1-y0)*.5,(y1-y0)*.48
    if resource == 'valkyrie_v1_sword':
        return s.rect('leather',0,0,105,128).rect('secondary',90,0,127,128).rect('trim',0,0,46,128)
    if resource == 'forest_ranger_v1_bow':
        return s.rect('leather',0,126,200,198)
    if resource == 'seer_v1_sword':
        s.snap_cells = False
        return s.ellipse('secondary',cx,cy,r)
    if resource == 'blood_alchemist_v1_sword':
        return s.rect('leather',0,0,141,128)  # blood stains are assigned by an explicit pigment rule below
    if resource == 'dark_oracle_v1_sword':
        s.snap_cells = False
        return s.rect('secondary',228,0,400,128)
    if resource == 'necromancer_v1_sword':
        return s.rect('leather',0,0,115,128)
    if resource == 'skeleton_crusader_v1_sword':
        return s.rect('leather',0,0,106,128).rect('secondary',94,0,143,128)
    if resource == 'golem_v1_sword':
        return s.rect('leather',0,0,114,128)
    raise ValueError(f'No signature material layout: {resource}')


def store_layout(resource):
    # Exact contours from store_gear.py, which paints unoutlined adjacent
    # materials. Cell voting would collapse the whole item to one colour.
    s = MaterialLayout(snap_cells=False)
    if resource in ('store_shield_crux','store_shield_templar'):
        s.base = 'secondary'
        s.polygon('primary',[(33,29),(127,29),(130,82),(80,132),(30,82)])
        s.rect('trim',72,30,88,128).rect('trim',36,58,124,74)
        for x,y in ((40,38),(120,38),(36,78),(124,78),(80,120)):
            s.ellipse('secondary',x,y,6)
        return s
    if resource == 'store_weapon_gem':
        s.rect('secondary',20,57,292,71).ellipse('trim',16,64,10)
        s.rect('trim',288,52,300,76)
        for x in (318,360):
            s.ellipse('trim',x,64,15).ellipse('emissive',x,64,10)
        return s
    if resource == 'store_weapon_staff':
        s.rect('secondary',316,20,380,108).ellipse('trim',14,64,9)
        return s.ellipse('emissive',352,64,27)
    if resource == 'store_weapon_reel':
        s.rect('leather',24,58,70,70).ellipse('trim',16,64,10)
        s.ellipse('trim',86,64,36).ellipse('secondary',86,64,28).ellipse('trim',86,64,9)
        for i in range(6):
            angle = np.deg2rad(i*60)
            s.ellipse('trim',86+18*np.cos(angle),64+18*np.sin(angle),5)
        return s
    guards = {'store_weapon_shard':72,'store_weapon_stormblade':76,'store_weapon_chevron':84,
              'store_weapon_ruby':74,'store_weapon_arcane':78,'store_weapon_fireworkBlade':76}
    gx = guards[resource]
    s.rect('leather',24,57,gx,71).rect('secondary',gx,0,gx+12 if resource!='store_weapon_ruby' else 88,128)
    s.ellipse('trim',18,64,12)
    if resource == 'store_weapon_stormblade':
        s.polygon('emissive',[(200,40),(246,40),(224,62),(252,62),(190,100),(212,70),(186,70)])
    elif resource == 'store_weapon_arcane':
        s.ellipse('emissive',86,64,8)
    elif resource == 'store_weapon_fireworkBlade':
        for x,y,r in ((150,64,15),(225,54,12),(292,70,13),(350,62,10)):
            points=[]
            for i in range(16):
                angle=np.deg2rad(-90+i*22.5)
                radius=r if i%2==0 else r*.4
                points.append((x+radius*np.cos(angle),y+radius*np.sin(angle)))
            s.polygon('emissive',points)
    return s


def layout_for(resource, image):
    m = re.fullmatch(r'shield_(\d+)_(\d+)',resource)
    if m:
        return shield_layout(*map(int,m.groups()))
    m = re.fullmatch(r'staff_(\d+)_(\d+)',resource)
    if m:
        return staff_layout(*map(int,m.groups()), image)
    if resource.startswith('store_'):
        return store_layout(resource)
    return signature_layout(resource, image)


def masks_for(resource, image):
    spec = layout_for(resource, image)
    names = list(dict.fromkeys([spec.base] + [s.region for s in spec.surfaces]))
    authored = Image.new('I',image.size,0)
    draw = ImageDraw.Draw(authored)
    for surface in spec.surfaces:
        getattr(draw,surface.shape)(surface.points, fill=names.index(surface.region))
    hard = np.asarray(authored,dtype=np.int16)
    rgb, alpha = ops.arrays(image)
    has_halo = resource in HALO_RESOURCES
    ink = protected_ink(image, exterior=not has_halo)
    # A one-pixel barrier closes antialiased gaps in the painted outlines.
    core = (alpha > .9) & ~ops.dilate(ink,1)
    cells, count = ops.label(core)
    labels = hard.copy()
    for cid in range(1,count+1) if spec.snap_cells else ():
        selected = cells == cid
        if selected.sum() < 4:
            continue
        counts = np.bincount(hard[selected],minlength=len(names))
        labels[selected] = int(counts.argmax())
    todo = (alpha > 0) & ~ink
    known = core.copy()
    for _ in range(8):
        pending = todo & ~known
        if not pending.any():
            break
        new = np.full(labels.shape,-1,np.int16)
        for i in range(len(names)):
            take = pending & (new < 0) & ops.dilate(known & (labels == i),1)
            new[take] = i
        accepted = new >= 0
        labels[accepted] = new[accepted]
        known |= accepted
    # Pixels without a path to a real interior are antialiased ink/shadow
    # islands, not a new paint surface. The old geometry fallback tinted them.
    if has_halo:
        x0,y0,x1,y1 = bounds(image)
        yy,xx = np.mgrid[:alpha.shape[0],:alpha.shape[1]]
        halo = (xx > x0 + (x1-x0)*.65) & (alpha > .02) & ~ink
        # These two textures paint emission over the tip outline, so their
        # exterior is intentionally luminous rather than an opaque drop shadow.
        if 'emissive' not in names:
            names.append('emissive')
        emission = halo & (alpha < .95)
        if resource == 'dark_oracle_v1_sword':
            emission |= halo & (rgb[...,0] > rgb[...,1]*1.2) & (rgb[...,0] > rgb[...,2]*1.4)
        labels[emission] = names.index('emissive')
        known |= halo
    todo &= known
    ink |= (alpha > 0) & ~known
    # Explicitly distinct pigments in these textures are paint/FX, not lighting.
    if resource in ('shield_1_2','shield_1_3'):
        # Small iron clamps have no enclosing stroke. Explicit neutral metal
        # pigments distinguish them from the brown planks without splitting
        # a plank's lighter and darker paint bands.
        neutral = (rgb.max(-1)-rgb.min(-1) < .075) & (ops.lum(rgb) > .18)
        if 'secondary' not in names:
            names.append('secondary')
        labels[neutral & todo] = names.index('secondary')
    if resource.startswith('staff_8_'):
        wood = (rgb[...,0] > rgb[...,1]*1.12) & (rgb[...,0] > rgb[...,2]*1.4)
        labels[wood & todo] = names.index('secondary')
    if resource == 'blood_alchemist_v1_sword':
        red = (rgb[...,0] > rgb[...,1]*1.4) & (rgb[...,0] > rgb[...,2]*1.5) & (rgb[...,0] > .35)
        if 'secondary' not in names:
            names.append('secondary')
        labels[red & todo] = names.index('secondary')
    labels[~todo] = -1
    weight = alpha * (1 - np.maximum(ink.astype(np.float32),ops.blur(ink.astype(np.float32),.45)))
    soft = [ops.blur((labels==i).astype(np.float32),.45) for i in range(len(names))]
    total = np.maximum(sum(soft),1e-8)
    masks = {name: Image.fromarray(np.round(np.clip(s/total*weight,0,1)*255).astype(np.uint8),'L')
             for name,s in zip(names,soft) if (s/total*weight).sum() >= 20}
    return masks, ink


def quality(image, masks, protected):
    """Measure the emitted masks against source alpha and protected ink/shadow."""
    _,alpha = ops.arrays(image)
    total = sum((np.asarray(m,np.float64)/255 for m in masks.values()),np.zeros(alpha.shape))
    paint = (alpha > .95) & ~protected
    return {
        'algorithm': 'authored-surfaces-v1',
        'coverage': round(float(np.clip(total,0,1)[paint].mean()),6) if paint.any() else 0.0,
        'protectedLeak': round(float(total[protected].max()),6) if protected.any() else 0.0,
        'alphaLeak': round(float(np.maximum(total-alpha,0).max()),6),
        'overlap': round(float(np.maximum(total-1,0).max()),6),
    }


def quality_passes(metrics):
    return (metrics['coverage'] >= .80 and metrics['protectedLeak'] == 0
            and metrics['alphaLeak'] <= .02 and metrics['overlap'] <= .02)
