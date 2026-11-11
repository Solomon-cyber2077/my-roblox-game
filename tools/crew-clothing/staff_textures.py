"""The Depot hall's four counter staff (Config/Outfits Lobby) on the R6 body, painted as
passenger_textures.py paints the passengers, plus what each one's trade puts on them:
Mrs. Pell's bib apron (bodice and skirt), Mr. Pyle's tape measure round the neck and pins in his
lapel, Mr. Lethbridge's holland oversleeves and watch chain, the Superintendent's gold chain and lapel
badge. The Guard stays the kit figure (his lean over the van rail is a pose, not a standing body).
Run with Python + Pillow, then PASSENGER_OUT=assets/crew-clothing/staff-r6 Blender --background
--python passenger_r6.py for the renders.
References (period types, looked at, nothing traced or embedded): tea-room waitresses' bib aprons
c. 1890-1905, tailors' tape measures and pin cushions, booking clerks' sleeve protectors, Albert
watch chains, railway officers' frock coats.
Colours come from each look in Config/Outfits; keep STAFF in step with that file.
"""
import json, os, sys
from pathlib import Path
from PIL import Image, ImageDraw
sys.path.insert(0, str(Path(__file__).resolve().parent))
import passenger_textures as pt
from textures import adjust
from mabel_textures import weave, grime

OUT = Path(os.environ.get('PASSENGER_OUT', Path(__file__).resolve().parents[2] / 'assets/crew-clothing/staff-r6'))
S, P, button, stitch = pt.S, pt.P, pt.button, pt.stitch
BRASS, LINEN = (180, 148, 88), (226, 220, 206)
GOLD = (206, 170, 92)

STAFF = {
    'TeaRoom': dict(cut='Bodice', skin=(236, 200, 172), coat=(46, 40, 58), trim=BRASS, lower=(52, 44, 60), skirt='Plain',
                    apron=LINEN, prop='Cloth'),
    'Outfitter': dict(cut='Frock', skin=(224, 188, 160), coat=(30, 32, 38), trim=BRASS, waistcoat=(108, 36, 34),
                      neck=(34, 30, 32), lower=(72, 68, 64), prop='Tape', tape=True),
    'TicketClerk': dict(cut='Reefer', skin=(214, 176, 150), coat=(28, 36, 60), trim=BRASS, waistcoat=(28, 36, 60),
                        lower=(34, 36, 48), prop='Punch', oversleeves=True, chain=True),
    'LineMastery': dict(cut='Frock', skin=(230, 196, 170), coat=(22, 24, 30), trim=BRASS, waistcoat=(62, 66, 72),
                        neck=(118, 30, 34), lower=(40, 40, 46), prop='Pointer', chain=True, badge=True),
}

def overlay(size):
    return Image.new('RGBA', (size[0] * S, size[1] * S), (0, 0, 0, 0))

def merge(base, top):
    out = base.convert('RGBA')
    out.alpha_composite(top.resize(base.size, Image.LANCZOS))
    return out

def chain(d, pts):
    """An Albert chain: small gold links along a sagging polyline, a fob at the end."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(2, int(((x1 - x0) ** 2 + (y1 - y0) ** 2) ** .5 / 1.6))
        for i in range(n):
            x, y = x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n
            d.ellipse(P(x - .7, y - .45, x + .7, y + .45), outline=GOLD, width=S // 2)

_front, _sleeve = pt.torso_front, pt.sleeve

def torso_front(look):
    im = _front(look)
    top = overlay((128, 128)); d = ImageDraw.Draw(top)
    if look.get('apron'):  # the bib, its straps over the shoulders and the waistband with a pocket
        a = look['apron']
        d.polygon([P(44, 26), P(84, 26), P(86, 128), P(42, 128)], fill=a + (255,))
        for s in (-1, 1):
            d.polygon([P(64 + s * 20 - 3, 0), P(64 + s * 20 + 3, 0), P(64 + s * 20 + 3 * s, 27), P(64 + s * 20 - 3 * s, 27)],
                      fill=adjust(a, -8) + (255,))
        d.rectangle(P(36, pt.WAIST - 6, 92, pt.WAIST), fill=adjust(a, -14) + (255,))
        stitch(d, [(44, 28), (84, 28)], adjust(a, -40), 3)
        d.rectangle(P(54, 40, 74, 54), outline=adjust(a, -30) + (255,), width=S)  # bib pocket, a pencil in it
        d.line(P(70, 34, 70, 46), fill=(150, 110, 60), width=S)
        for y in range(30, pt.WAIST - 8, 6):  # starch creases
            d.line(P(46, y, 82, y + 1), fill=adjust(a, -10) + (120,), width=S // 2)
    if look.get('tape'):  # the tailor's tape round the neck, both ends hanging, inch ticks; pins in the lapel
        tape = (214, 190, 120)
        for x0, x1 in ((50, 46), (78, 82)):
            d.line(P(x0, 0, x1, 96), fill=tape + (255,), width=4 * S)
            for y in range(4, 96, 4):
                x = x0 + (x1 - x0) * y / 96
                d.line(P(x - 1.6, y, x - .2, y), fill=(40, 34, 28, 255), width=max(1, S // 2))
        d.rectangle(P(44.5, 92, 51.5, 98), fill=(150, 152, 156, 255))  # the brass-tipped ends
        d.rectangle(P(78.5, 92, 85.5, 98), fill=(150, 152, 156, 255))
        for i, y in enumerate((18, 21, 24, 27)):  # pins in the left lapel
            d.line(P(34 + i, y, 40 + i, y - 2), fill=(196, 198, 202, 255), width=S // 2)
            d.ellipse(P(33 + i, y - .9, 34.8 + i, y + .9), fill=((180, 40, 40) if i % 2 else (40, 40, 44)) + (255,))
    if look.get('chain'):  # pocket to pocket across the waistcoat, through a buttonhole
        mid = 64 if look['cut'] != 'Reefer' else 64
        top_y = 70 if look['cut'] != 'Reefer' else 66
        chain(d, [(46, top_y), (52, top_y + 7), (58, top_y + 9), (mid, top_y + 4), (70, top_y + 9), (76, top_y + 7), (82, top_y)])
        d.ellipse(P(62, top_y + 5, 66, top_y + 11), fill=GOLD + (255,))  # the fob seal
    if look.get('badge'):  # the Company's lapel badge: a winged wheel in enamel
        d.ellipse(P(88, 20, 98, 30), fill=GOLD + (255,))
        d.ellipse(P(90, 22, 96, 28), fill=(118, 30, 34, 255))
        d.line(P(85, 25, 101, 25), fill=GOLD + (255,), width=S)
    return merge(im, top)

def sleeve(look, face, seed):
    im = _sleeve(look, face, seed)
    if not look.get('oversleeves'):
        return im
    # holland oversleeves from the elbow to the cuff, gathered at both ends
    top = overlay((64, 128)); d = ImageDraw.Draw(top)
    holland = (186, 174, 146)
    d.rectangle(P(0, 56, 64, 96), fill=holland + (255,))
    for y in (56, 96):
        for x in range(0, 64, 3):
            d.line(P(x, y - 2, x + 1.5, y + 1), fill=adjust(holland, -34) + (255,), width=S // 2)
    for x in range(4, 64, 9):  # the gathers
        d.line(P(x, 58, x + 1, 94), fill=adjust(holland, -14) + (150,), width=S // 2)
    t = merge(im, top)
    t = grime(t, 'ink' + seed, 30, (0, 80, 64, 96), 10, (40, 40, 60)).convert('RGBA')  # ink at the cuff
    t.putalpha(im.getchannel('A'))
    return t

def skirt_atlas(look):
    im = pt.skirt_atlas(look).convert('RGBA')
    if look.get('apron'):  # the apron's skirt over the front of the wool: u = 0 is the front (mabel_r6 skirt_point), so it wraps the seam
        a = look['apron']
        cloth = weave((360, 560), a, 'apron', amp=5, twill=False).convert('RGBA')
        d = ImageDraw.Draw(cloth)
        for x in range(30, 360, 60):
            d.line((x, 0, x + 6, 560), fill=adjust(a, -12), width=3)
        d.rectangle((0, 520, 360, 560), fill=adjust(a, -6))
        d.line((0, 520, 360, 520), fill=adjust(a, -36), width=2)
        for x in range(4, 360, 10):
            d.line((x, 524, x + 5, 524), fill=adjust(a, -40), width=2)
        d.rectangle((120, 90, 240, 190), outline=adjust(a, -30), width=4)  # a big pocket for the change
        cloth = grime(cloth.convert('RGBA'), 'tea', 40, (60, 120, 300, 400), 12, (150, 110, 70)).convert('RGBA')  # tea spots
        im.paste(cloth.crop((180, 0, 360, 560)), (0, 0))
        im.paste(cloth.crop((0, 0, 180, 560)), (1024 - 180, 0))
    return im.convert('RGB')

def main():
    pt.torso_front, pt.sleeve = torso_front, sleeve  # sheet() looks these up at call time
    OUT.mkdir(parents=True, exist_ok=True)
    for pid, look in STAFF.items():
        name = pid.lower()
        pt.sheet(look, 'shirt').save(OUT / f'{name}-shirt.png')
        pt.sheet(look, 'pants').save(OUT / f'{name}-pants.png')
        if look.get('skirt'):
            skirt_atlas(look).save(OUT / f'{name}-skirt.png')
    (OUT / 'looks.json').write_text(json.dumps(STAFF, indent=1))

if __name__ == '__main__':
    main()
