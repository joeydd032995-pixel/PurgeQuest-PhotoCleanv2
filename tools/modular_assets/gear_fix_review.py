"""Compare baseline and fixed gear masks using identical player colour choices.

Run: python3 -I tools/modular_assets/gear_fix_review.py
Needs the baseline commit in local Git history. Writes review images/report,
never asset approvals. Before and after use the same current recolor math:
the only difference is the material masks and their measured source tones.
"""
from io import BytesIO
import json
from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
import qa

BASELINE = '35819112018927206952159dfc4426487ac055c6'
ART = REPO / 'ios/PurgeQuest/Art'
OUT = REPO / 'docs/modular/verification'
MASK_PATH = 'ios/PurgeQuest/Art/Modular/Gear/'
MANIFEST_PATH = 'ios/PurgeQuest/Art/Modular/modular_gear_manifest.json'
COLORS = {'primary':(.16,.46,.82),'secondary':(.72,.14,.24),'trim':(.85,.65,.20),
          'leather':(.36,.22,.12),'emissive':(.12,.83,.88)}
BG = (26,30,40,255)
CARD = (45,50,64,255)


def font(size):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',size)
    except OSError:
        return ImageFont.load_default(size=size)


def baseline_bytes(path):
    return subprocess.check_output(['git','show',f'{BASELINE}:{path}'],cwd=REPO)


def atlas(filename,title,items,views,columns=5,cell_width=320):
    cell_height,header=226,88
    rows=(len(items)+columns-1)//columns
    canvas=Image.new('RGBA',(cell_width*columns,header+rows*cell_height),BG)
    draw=ImageDraw.Draw(canvas)
    draw.text((16,12),title,font=font(23),fill='#f0f4fc')
    draw.text((16,47),'BEFORE (left)  →  FIXED (right)  |  Same blue / red / gold preferences',font=font(14),fill='#c1c8d7')
    for n,item in enumerate(items):
        x,y=(n%columns)*cell_width,header+(n//columns)*cell_height
        draw.rounded_rectangle((x+6,y+4,x+cell_width-6,y+cell_height-4),radius=10,fill=CARD)
        draw.text((x+14,y+12),item['name'],font=font(14),fill='#f0f4fc')
        before,after,bbox=views[item['id']]
        for side,image in enumerate([before,after]):
            image=image.crop(bbox)
            slot=(cell_width-36)//2
            scale=min((slot-8)/image.width,150/image.height)
            size=(max(1,round(image.width*scale)),max(1,round(image.height*scale)))
            image=image.resize(size,Image.Resampling.LANCZOS)
            left=x+14+side*(slot+8)+(slot-image.width)//2
            canvas.alpha_composite(image,(left,y+43+(150-image.height)//2))
        draw.text((x+14,y+201),'Material regions stay together',font=font(11),fill='#aab6ce')
    target=OUT/filename
    canvas.convert('RGB').save(target,optimize=True)
    print(target.relative_to(REPO))


def main():
    old=json.loads(baseline_bytes(MANIFEST_PATH))
    current=json.loads((REPO/MANIFEST_PATH).read_text())
    old_items={i['id']:i for i in old['items']}
    resources={p.stem:p for p in ART.rglob('*.png')}
    views,report={},[]
    for item in current['items']:
        previous=old_items[item['id']]
        with Image.open(resources[item['resourceName']]) as image:
            source=image.convert('RGBA')
        before_masks={}
        for region,name in previous['maskResources'].items():
            with Image.open(BytesIO(baseline_bytes(MASK_PATH+name+'.png'))) as mask:
                before_masks[region]=mask.convert('L')
        after_masks={}
        for region,name in item['maskResources'].items():
            with Image.open(resources[name]) as mask:
                after_masks[region]=mask.convert('L')
        before=qa.recolor(source,before_masks,previous['regionTone'],COLORS)
        after=qa.recolor(source,after_masks,item['regionTone'],COLORS)
        views[item['id']]=(before,after,source.getchannel('A').getbbox())
        report.append({'id':item['id'],'name':item['name'],
                       'beforeRegions':sorted(previous['maskResources']),
                       'afterRegions':sorted(item['maskResources']),
                       'checks':item['verification']['automated']['materialMasks']})
    all_items=current['items']
    for group,title in [('staff','ALL 40 STAVES — old masks → fixed'),('shield','ALL 40 SHIELDS — old masks → fixed')]:
        selected=[i for i in all_items if i['group'].startswith(group)]
        atlas(f'gear_fix_{group}s_all.png',title,selected,views)
    atlas('gear_fix_signature_all.png','ALL 8 SIGNATURE WEAPONS — old masks → fixed',
          [i for i in all_items if i['group']=='signature'],views,2,560)
    atlas('gear_fix_store_all.png','ALL 11 STORE ITEMS — old masks → fixed',
          [i for i in all_items if i['group']=='store'],views,3,420)
    atlas('gear_fix_reported_staves.png','VERDANT COIL & TIDECALLER — all five tiers fixed',
          [i for i in all_items if i['group'] in ('staff2','staff3')],views,5,320)
    reported=['shield.set.2.1','shield.set.3.3','shield.set.3.4','shield.set.4.3',
              'shield.set.4.4','shield.set.4.5','shield.set.5.3','shield.set.5.4',
              'shield.set.3.5','shield.set.1.5','shield.set.7.3','shield.set.8.5']
    by_id={i['id']:i for i in all_items}
    atlas('gear_fix_reported_shields.png','SHIELD MATERIALS — panels, rims, and bosses fixed',
          [by_id[i] for i in reported],views,3,420)
    target=REPO/'docs/modular/gear_material_fix_report.json'
    target.write_text(json.dumps({'baselineCommit':BASELINE,'assets':report},indent=1,sort_keys=True)+'\n')
    print('Compared all',len(views),'assets with the same preference palette.')


if __name__=='__main__':
    main()
