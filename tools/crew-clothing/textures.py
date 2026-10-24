"""Author original classic-clothing sheets; run with Python + Pillow before build.py.
Coordinates follow the official Roblox 585x559 classic shirt/pants template.
No reference photographs are embedded in the assets.
"""
from pathlib import Path
import random
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2] / 'assets' / 'crew-clothing'
PALETTES = {
    'stoker': ((58, 68, 70), (113, 83, 58), (154, 126, 85)),
    'brakeman': ((82, 73, 57), (55, 62, 58), (162, 127, 69)),
    'conductor': ((35, 47, 63), (29, 36, 47), (179, 148, 82)),
    'trackwalker': ((97, 94, 65), (57, 60, 48), (157, 124, 77)),
    'wayfarer': ((97, 62, 55), (60, 52, 49), (176, 142, 96)),
    'stoker_veteran': ((49, 59, 62), (87, 64, 48), (186, 148, 86)),
    'conductor_terminus': ((42, 37, 51), (31, 29, 40), (191, 158, 99)),
}
TORSO = {'front': (231, 74, 128, 128), 'back': (427, 74, 128, 128),
         'right': (165, 74, 64, 128), 'left': (361, 74, 64, 128),
         'up': (231, 8, 128, 64), 'down': (231, 204, 128, 64)}
LIMBS = [(217, 355), (85, 355), (19, 355), (151, 355), (308, 355),
         (440, 355), (374, 355), (506, 355)]

def adjust(c, d):
    return tuple(max(0, min(255, v + d)) for v in c)

def cloth(size, color, seed):
    rng = random.Random(seed)
    im = Image.new('RGBA', size)
    px = im.load()
    for y in range(size[1]):
        for x in range(size[0]):
            grain = rng.randint(-5, 5) + (2 if (x+y) % 3 == 0 else 0)
            edge = -9 if x < 2 or x >= size[0]-2 else 0
            px[x, y] = (*adjust(color, grain+edge), 255)
    return im

def face(name, side, size, pants=False):
    base, trousers, metal = PALETTES[name]
    im = cloth(size, trousers if pants else base, name+side+str(pants))
    d = ImageDraw.Draw(im)
    w, h = size
    seam = adjust(trousers if pants else base, 25)
    d.line([(3, 0), (3, h), (w-4, h), (w-4, 0)], fill=seam, width=1)
    if pants:
        if h == 128:
            d.rectangle((0, 95, w, h), fill=(31, 28, 25))
            d.line((0, 96, w, 96), fill=(94, 76, 54), width=2)
            d.line((4, 119, w-4, 119), fill=(62, 52, 40), width=2)
            d.line((w//2, 18, w//2-4, 85), fill=adjust(trousers,-12), width=2)
        return im
    if side == 'front':
        # Waistcoat/apron silhouette with a broad contrasting neck opening.
        d.polygon([(38,0),(64,32),(90,0)], fill=(181,163,128))
        d.polygon([(31,0),(44,0),(64,31),(52,46),(37,25)], fill=adjust(base,-21))
        d.polygon([(97,0),(84,0),(64,31),(76,46),(91,25)], fill=adjust(base,22))
        if name.startswith('stoker'):
            d.rectangle((28,38,100,127), fill=trousers)
            d.line((35,0,35,48), fill=trousers,width=9)
            d.line((93,0,93,48), fill=trousers,width=9)
            d.rectangle((42,53,86,79), outline=adjust(trousers,35),width=2)
            d.line((64,53,64,79), fill=adjust(trousers,20))
            for x in (35,93): d.ellipse((x-2,39,x+2,43),fill=metal)
        else:
            d.line((64,32,64,127), fill=adjust(base,-24),width=3)
            for y in (48,67,86,105):
                xs = (51,77) if name.startswith('conductor') else (67,)
                for x in xs:
                    d.ellipse((x-2,y-2,x+2,y+2),fill=metal)
                    d.point((x-1,y-1), fill=(229,204,148))
            for x in (12,88):
                d.rectangle((x,76,x+28,98),outline=adjust(base,-17),width=2)
                d.line((x,77,x+28,77), fill=seam,width=2)
        d.rectangle((0,117,127,125),fill=(39,31,24))
        d.rectangle((58,117,69,125),outline=metal,width=2)
        if name.endswith('veteran') or name.endswith('terminus'):
            for y in (42,47,52): d.line((14,y,20,y+3,26,y),fill=metal,width=2)
    elif side == 'back':
        d.line((64,7,64,115), fill=adjust(base,-15),width=2)
        d.line((9,22,118,22),fill=seam)
        if name.startswith('stoker'):
            d.line((35,0,88,117),fill=trousers,width=9)
            d.line((93,0,40,117),fill=trousers,width=9)
        d.rectangle((0,117,w,125),fill=(39,31,24))
    elif side == 'sleeve':
        d.rectangle((0,103,w,127),fill=adjust(base,-22))
        d.line((0,104,w,104),fill=seam,width=2)
        d.rectangle((10,54,w-10,80),outline=adjust(base,-13),width=2)
    return im

def soot(im, seed):
    mask = Image.new('L',im.size,0); d=ImageDraw.Draw(mask); r=random.Random(seed)
    for _ in range(180):
        x,y=r.randrange(im.width),r.randrange(im.height); s=r.randrange(2,16)
        d.ellipse((x-s,y-s,x+s,y+s),fill=r.randrange(25,105))
    mask=mask.filter(ImageFilter.GaussianBlur(3))
    result=Image.composite(Image.new('RGBA',im.size,(25,24,23,255)),im,mask)
    result.putalpha(im.getchannel('A')); return result

def main():
    ROOT.mkdir(parents=True,exist_ok=True)
    for name in PALETTES:
        out=ROOT/name; out.mkdir(exist_ok=True)
        for kind in ('shirt','pants'):
            sheet=Image.new('RGBA',(585,559))
            for side,(x,y,w,h) in TORSO.items():
                panel=face(name,side,(w,h),pants=kind=='pants')
                if kind=='pants': panel=Image.new('RGBA',(w,h)) # shirt owns torso/belt
                sheet.paste(panel,(x,y))
                if kind=='shirt': panel.save(out/f'torso-{side}.png')
            for i,(x,y) in enumerate(LIMBS):
                panel=face(name,'sleeve',(64,128),pants=kind=='pants')
                sheet.paste(panel,(x,y))
                if i==0: panel.save(out/f'{kind}-limb.png')
            for x in (217,308):
                sheet.paste(cloth((64,64), PALETTES[name][kind=='pants'],name),(x,289))
                sheet.paste(cloth((64,64), (31,28,25) if kind=='pants' else PALETTES[name][0],name),(x,485))
            sheet.save(out/f'{kind}-clean.png')
            worn=soot(sheet,name)
            worn.save(out/f'{kind}-worn.png')
            worn.crop((231,74,359,202)).save(out/f'{kind}-worn-front.png')
            worn.crop((217,355,281,483)).save(out/f'{kind}-worn-limb.png')
        # Hat atlas: horizontal material swatches, sampled explicitly by exported mesh UVs.
        atlas=Image.new('RGB',(256,64)); d=ImageDraw.Draw(atlas)
        for i,c in enumerate((PALETTES[name][0],(30,27,25),PALETTES[name][2],adjust(PALETTES[name][0],25))):
            d.rectangle((i*64,0,i*64+63,63),fill=c)
        atlas.save(out/'hat-atlas.png')

if __name__=='__main__': main()
