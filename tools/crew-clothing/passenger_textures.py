"""The Depot hall's six passengers (Config/Passengers) on the R6 body: classic shirt and pants sheets
in place of the kit's box coats, sleeves and trousers, a recoloured skirt atlas for the two women
(Mabel's uploaded skirt mesh), and the bag atlas for passenger_r6.py's bag meshes.
Run with Python + Pillow, then Blender --background --python passenger_r6.py.
Output: $PASSENGER_OUT (default assets/crew-clothing/passengers-r6). Painted at 4x and reduced.
References (period types, looked at, nothing traced or embedded): lounge (sack) suits and frock coats
c. 1890-1900, railway porters' double-breasted reefer jackets, mourning bodices in crape with jet
buttons, day bodices with lace collars, canvas newspaper bags, leather post satchels, drawstring
reticules.
Colours come from each passenger's look in Config/Passengers; keep LOOKS in step with that file.
"""
import math, os, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, str(Path(__file__).resolve().parent))
import mabel_textures as mt
from textures import TORSO, LIMBS, adjust
from mabel_textures import weave, grime, shade, reduce

OUT = Path(os.environ.get('PASSENGER_OUT', Path(__file__).resolve().parents[2] / 'assets/crew-clothing/passengers-r6'))
S = 4
LINEN = (226, 220, 206)
BOOT = (30, 24, 20)
PEWTER = (120, 116, 108)

LOOKS = {
    'Clerk': dict(cut='Sack', coat=(64, 60, 56), trim=PEWTER, waistcoat=(96, 84, 66), neck=(40, 44, 70), lower=(54, 52, 50), prop='Ledger'),
    'Mother': dict(cut='Bodice', coat=(70, 40, 50), trim=(196, 170, 120), lower=(62, 36, 44), skirt='Bustle', prop='Reticule'),
    'Gentleman': dict(cut='Frock', coat=(30, 32, 36), trim=(196, 160, 90), waistcoat=(110, 26, 30), neck=LINEN, lower=(44, 42, 46), prop='Cane'),
    'Porter': dict(cut='Reefer', coat=(30, 40, 62), trim=(180, 148, 88), lower=(34, 38, 52), prop='Post'),
    'Widow': dict(cut='Bodice', coat=(22, 20, 24), trim=(90, 86, 84), lower=(20, 18, 22), skirt='Plain', prop='Hanky', crape=True),
    'Newsboy': dict(cut='Sack', coat=(92, 70, 48), trim=(150, 130, 100), neck=(120, 30, 26), lower=(70, 62, 54), prop='Papers', patched=True),
}
WAIST = 93  # torso px where a bodice ends; the skirt mesh covers below it

def P(*xy):
    return tuple(v * S for v in xy)

def button(d, x, y, r, color, shine=True):
    d.ellipse(P(x - r - .5, y - r, x + r + .5, y + r + .8), fill=(16, 16, 18))
    d.ellipse(P(x - r, y - r, x + r, y + r), fill=color)
    if shine:
        d.ellipse(P(x - r * .5, y - r * .7, x + r * .2, y - r * .1), fill=adjust(color, 50))
    d.arc(P(x - r, y - r, x + r, y + r), 20, 160, fill=adjust(color, -50), width=max(1, S // 2))

def stitch(d, pts, color, gap=3):
    """A running stitch along a polyline, in template px."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / gap))
        for i in range(0, n, 2):
            a, b = i / n, min(1, (i + 1) / n)
            d.line(P(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a, x0 + (x1 - x0) * b, y0 + (y1 - y0) * b), fill=color, width=S // 2)

def cloth(size, color, seed, look, twill=True):
    im = weave(size, color, seed, amp=7 if look.get('crape') else 6, twill=twill)
    if look.get('crape'):  # mourning crape: a crimped, matt surface
        rng = random.Random('crape' + seed); d = ImageDraw.Draw(im)
        for _ in range(size[0] * size[1] // 900):
            x, y = rng.randrange(size[0]), rng.randrange(size[1])
            d.line((x, y, x + rng.randint(4, 14), y + rng.randint(-3, 3)), fill=adjust(color, rng.choice((-8, 9))), width=2)
    return im

def lapels(d, coat, wide, open_to):
    """Notched lapels rolling from the collar to the top button at `open_to` px."""
    dark, light = adjust(coat, -20), adjust(coat, 14)
    for s in (-1, 1):
        roll = [(64 + s * 10, 4), (64 + s * (30 if wide else 22), 18), (64 + s * (24 if wide else 17), 30), (64 + s * 3, open_to)]
        d.polygon([P(*p) for p in roll] + [P(64 + s * 3, 6)], fill=adjust(coat, 6))
        d.line([P(*p) for p in roll], fill=dark, width=S)
        d.line([P(roll[0][0] - s, roll[0][1] + 1), P(roll[1][0] - s * 2, roll[1][1])], fill=light, width=S // 2)
        notch = roll[1]
        d.polygon([P(*notch), P(notch[0] - s * 5, notch[1] - 3), P(notch[0] - s * 3, notch[1] + 2)], fill=dark)
        stitch(d, [(64 + s * 11, 6), (notch[0] - s * 2, notch[1] - 1)], adjust(coat, 22))

def shirt_front(d, look, top_open):
    """Linen shirt, wing collar and the neckwear in the coat's opening."""
    d.polygon([P(52, 0), P(76, 0), P(64 + 2, top_open), P(64 - 2, top_open)], fill=LINEN)
    for s in (-1, 1):
        d.polygon([P(64 + s * 2, 1), P(64 + s * 12, 0), P(64 + s * 9, 8)], fill=adjust(LINEN, -14))
        d.line([P(64 + s * 12, 0), P(64 + s * 9, 8)], fill=adjust(LINEN, -50), width=S // 2)
    if look.get('neck'):
        tie = look['neck']
        if look['cut'] == 'Frock':  # a full cravat with a pearl pin
            d.ellipse(P(57, 6, 71, 22), fill=tie); d.ellipse(P(59, 8, 69, 14), fill=adjust(tie, 18))
            button(d, 64, 15, 1.3, (230, 226, 214))
        else:  # a knotted neckerchief or narrow tie
            d.polygon([P(60, 6), P(68, 6), P(66, 11), P(62, 11)], fill=tie)
            d.polygon([P(62, 11), P(66, 11), P(67.5, 28), P(64, 31), P(60.5, 28)], fill=adjust(tie, -6))
            d.line(P(63, 12, 63.5, 28), fill=adjust(tie, 20), width=S // 2)

def waistcoat(d, look, top, bottom):
    wc = look['waistcoat']
    d.polygon([P(46, top), P(82, top), P(84, bottom), P(64, bottom + 6), P(44, bottom)], fill=wc)
    for s in (-1, 1):  # the V opening
        d.line([P(64 + s * 9, top), P(64 + s * 1, top + 14)], fill=adjust(wc, -30), width=S)
    for y in range(top + 16, bottom, 7):
        button(d, 64, y, 1.4, look['trim'])
    for s in (-1, 1):  # welt pockets
        d.line(P(64 + s * 8, bottom - 12, 64 + s * 16, bottom - 13), fill=adjust(wc, -36), width=S)
    # watch chain from the buttonhole to the pocket
    pts = [(64 + 9 * math.sin(t / 10 * math.pi) * 1.0 - 1, bottom - 22 + 9 * t / 10 + 3 * math.sin(t / 10 * math.pi)) for t in range(11)]
    d.line([P(64 - x + 64 + 1, y) for x, y in pts], fill=look['trim'], width=S // 2 + 1)

def torso_front(look):
    cut, coat, trim = look['cut'], look['coat'], look['trim']
    w, h = 128 * S, 128 * S
    im = cloth((w, h), coat, 'front', look)
    d = ImageDraw.Draw(im)
    if cut == 'Bodice':
        for s in (-1, 1):  # fitted darts
            pts = [P(64 + s * (30 - 9 * (t / 10) ** 1.6), 18 + t * 7.5) for t in range(11)]
            d.line(pts, fill=adjust(coat, -14), width=S)
        d.line(P(64, 12, 64, WAIST), fill=adjust(coat, -18), width=S)
        for y in range(18, WAIST - 4, 8):  # jet or covered buttons down the front
            button(d, 64, y, 1.6, (12, 12, 14) if look.get('crape') else trim, shine=True)
        if look.get('crape'):  # a narrow white collar band, the one pale note
            d.rectangle(P(44, 0, 84, 6), fill=adjust(LINEN, -6)); d.line(P(44, 6, 84, 6), fill=(8, 8, 10), width=S)
            d.polygon([P(54, 22), P(74, 22), P(70, 46), P(58, 46)], fill=adjust(coat, -6))  # crape yoke panel
        else:  # a lace collar falling over the shoulders
            lace = (232, 226, 210)
            d.chord(P(36, -16, 92, 22), 0, 180, fill=lace)
            for i in range(14):
                x = 38 + i * 3.8
                d.ellipse(P(x - 2.2, 14, x + 2.2, 21), fill=lace)
                d.ellipse(P(x - .8, 11, x + .8, 13), fill=adjust(lace, -40))
            button(d, 64, 9, 2.4, trim)  # a cameo brooch
            d.ellipse(P(62.2, 7.2, 65.8, 10.8), fill=(236, 220, 200))
        d.rectangle(P(0, WAIST - 4, 128, 128), fill=look['lower'])
        d.rectangle(P(0, WAIST - 5, 128, WAIST), fill=adjust(look['lower'], -20))
        if look.get('skirt') == 'Bustle':  # the swagged overskirt starts at the waist
            d.chord(P(-10, WAIST - 6, 138, WAIST + 30), 0, 180, fill=adjust(look['lower'], 16))
            d.arc(P(-10, WAIST - 6, 138, WAIST + 30), 0, 180, fill=trim, width=S)
    elif cut == 'Reefer':  # double-breasted, closed to the neck, brass in two rows
        d.polygon([P(46, 0), P(82, 0), P(86, 128), P(42, 128)], fill=adjust(coat, 4))
        d.line([P(78, 4), P(84, 128)], fill=adjust(coat, -24), width=S)
        d.rectangle(P(42, 0, 86, 9), fill=adjust(coat, -10))  # stand collar
        d.line(P(42, 9, 86, 9), fill=adjust(coat, -30), width=S)
        for x in (50, 78):  # company collar badges
            d.rectangle(P(x - 3, 2, x + 3, 7), fill=trim); d.line(P(x - 2, 4.5, x + 2, 4.5), fill=adjust(trim, -60), width=S // 2)
        for y in range(18, 112, 16):
            button(d, 52, y, 2.2, trim); button(d, 76, y, 2.2, trim)
        for s in (-1, 1):  # flapped hip pockets and a breast pocket
            d.rectangle(P(64 + s * 20 - 10, 98, 64 + s * 20 + 10, 104), fill=adjust(coat, -10))
            stitch(d, [(64 + s * 20 - 9, 103), (64 + s * 20 + 9, 103)], adjust(coat, 30))
        d.line(P(24, 36, 38, 36), fill=adjust(coat, -30), width=S)
        stitch(d, [(46, 0), (42, 128)], trim, 4)  # company piping down the front edge
    else:  # Sack or Frock: single-breasted, lapels open over the shirt
        frock = cut == 'Frock'
        open_to = 40 if frock else 30
        shirt_front(d, look, open_to + 4)
        if look.get('waistcoat'):
            waistcoat(d, look, 10, 92 if frock else 86)
        d.polygon([P(0, 0), P(54, 0), P(61, open_to), P(60, 128), P(0, 128)], fill=coat)
        d.polygon([P(128, 0), P(74, 0), P(67, open_to), P(68, 128), P(128, 128)], fill=coat)
        if frock:  # the frock hangs open below the waist button, showing the waistcoat
            d.polygon([P(60, 96), P(68, 96), P(76, 128), P(52, 128)], fill=adjust(look['lower'], -4))
            button(d, 64, 92, 2.0, (24, 24, 28))
            d.line(P(0, 96, 128, 96), fill=adjust(coat, -16), width=S)  # waist seam
        else:
            d.line([P(61, open_to), P(60, 128)], fill=adjust(coat, -26), width=S)
            for y in (open_to + 6, open_to + 22, open_to + 38):
                button(d, 60.5, y, 1.8, adjust(coat, -36), shine=False)
        lapels(d, coat, frock, open_to)
        for s in (-1, 1):  # hip pocket flaps, breast pocket welt
            d.rectangle(P(64 + s * 30 - 11, 100, 64 + s * 30 + 11, 107), fill=adjust(coat, -8))
            d.line(P(64 + s * 30 - 11, 107, 64 + s * 30 + 11, 107), fill=adjust(coat, -32), width=S)
        d.line(P(84, 38, 98, 37), fill=adjust(coat, -28), width=S)
        if frock:  # a linen square in the breast pocket
            d.polygon([P(86, 37), P(90, 31), P(94, 33), P(96, 37)], fill=LINEN)
        if look.get('patched'):  # the newsboy's coat: a patch on the left front, a torn pocket
            d.rectangle(P(18, 56, 36, 72), fill=adjust(coat, -18))
            stitch(d, [(18, 56), (36, 56), (36, 72), (18, 72), (18, 56)], (160, 150, 130), 2)
            d.line(P(87, 101, 95, 106), fill=adjust(coat, -50), width=S)
    if look['prop'] in ('Post', 'Papers'):  # the bag strap: left shoulder to right hip
        strap = (78, 50, 32) if look['prop'] == 'Post' else (150, 136, 104)
        d.line(P(104, 0, 20, 128), fill=strap, width=7 * S)
        stitch(d, [(101.5, 0), (17.5, 128)], adjust(strap, 50), 3); stitch(d, [(106.5, 0), (22.5, 128)], adjust(strap, 50), 3)
        if look['prop'] == 'Post':
            d.rectangle(P(56, 58, 66, 66), outline=trim, width=S)  # strap buckle
    im = shade(im, bottom=30, sides=70)
    im = grime(im, 'front', 60 if look.get('patched') else 40, (0, 50 * S, w, h), 40, (70, 62, 52))
    return reduce(im, (128, 128))

def torso_back(look):
    cut, coat = look['cut'], look['coat']
    w, h = 128 * S, 128 * S
    im = cloth((w, h), coat, 'back', look)
    d = ImageDraw.Draw(im)
    d.rectangle(P(40, 0, 88, 8), fill=adjust(coat, -10))
    d.line(P(40, 8, 88, 8), fill=adjust(coat, -28), width=S)
    for s in (-1, 1):
        d.line([P(64 + s * (24 - 10 * t / 10), 12 + t * 8) for t in range(11)], fill=adjust(coat, -14), width=S)
    if cut == 'Bodice':
        d.line(P(64, 8, 64, WAIST), fill=adjust(coat, -16), width=S)
        d.rectangle(P(0, WAIST - 4, 128, 128), fill=look['lower'])
        if look.get('skirt') == 'Bustle':  # the bustle's bow
            d.ellipse(P(44, WAIST - 2, 62, WAIST + 12), fill=look['trim']); d.ellipse(P(66, WAIST - 2, 84, WAIST + 12), fill=look['trim'])
            d.rectangle(P(60, WAIST, 68, WAIST + 10), fill=adjust(look['trim'], -30))
    else:
        d.line(P(64, 8, 64, 128), fill=adjust(coat, -18), width=S)
        if cut == 'Frock':  # waist seam and the two hip buttons over the vent
            d.line(P(0, 96, 128, 96), fill=adjust(coat, -16), width=S)
            button(d, 56, 96, 2, (24, 24, 28)); button(d, 72, 96, 2, (24, 24, 28))
        if cut == 'Reefer':
            d.rectangle(P(30, 92, 98, 100), fill=adjust(coat, -6))  # half belt
            button(d, 36, 96, 2, look['trim']); button(d, 92, 96, 2, look['trim'])
    if look['prop'] in ('Post', 'Papers'):
        strap = (78, 50, 32) if look['prop'] == 'Post' else (150, 136, 104)
        d.line(P(24, 0, 108, 128), fill=strap, width=7 * S)
    im = shade(im, bottom=30, sides=70)
    im = grime(im, 'back', 35, None, 25, (70, 62, 52))
    return reduce(im, (128, 128))

def torso_side(look, side):
    coat = look['coat']
    w, h = 64 * S, 128 * S
    im = cloth((w, h), coat, 'side' + side, look)
    d = ImageDraw.Draw(im)
    d.line(P(32, 6, 30, 128), fill=adjust(coat, -15), width=S)
    d.rectangle(P(12, 0, 52, 6), fill=adjust(coat, -10))
    if look['cut'] == 'Bodice':
        d.rectangle(P(0, WAIST - 4, 64, 128), fill=look['lower'])
    if look['prop'] in ('Post', 'Papers') and side == 'r':
        d.line(P(0, 118, 64, 128), fill=(78, 50, 32) if look['prop'] == 'Post' else (150, 136, 104), width=7 * S)
    im = shade(im, bottom=30, sides=40)
    return reduce(im, (64, 128))

def torso_up(look):
    im = cloth((128 * S, 64 * S), look['coat'], 'up', look)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(P(36, 12, 92, 56), radius=8 * S, outline=adjust(look['coat'], -22), width=3 * S)
    return reduce(im, (128, 64))

def sleeve(look, face, seed):
    """Coat sleeve to the wrist: bodice puff or set-in sleeve, a turned cuff (braided on the porter),
    a linen cuff, then the hand left clear for the skin-coloured arm."""
    cut, coat, trim = look['cut'], look['coat'], look['trim']
    w, h = 64 * S, 128 * S
    im = cloth((w, h), coat, 'sl' + seed, look)
    d = ImageDraw.Draw(im)
    if cut == 'Bodice':
        for x in range(4, 64, 6):  # gathered sleeve head
            d.line(P(x, 0, x + 2, 22), fill=adjust(coat, -14), width=S)
            d.line(P(x + 2, 0, x + 3, 18), fill=adjust(coat, 14), width=S // 2)
        for y in (86, 92):  # tucks at the fitted forearm
            d.line(P(0, y, 64, y), fill=adjust(coat, -18), width=S // 2 + 1)
    else:
        d.line(P(0, 2, 64, 2), fill=adjust(coat, -24), width=S)  # shoulder seam
        if face in ('front', 'back'):  # elbow creases
            for i in range(3):
                d.arc(P(14, 52 + i * 5, 50, 62 + i * 5), 200, 340, fill=adjust(coat, -16), width=S // 2 + 1)
        d.rectangle(P(0, 86, 64, 96), fill=adjust(coat, -10))  # turned cuff
        d.line(P(0, 86, 64, 86), fill=adjust(coat, -32), width=S)
        if cut == 'Reefer':
            for y in (89, 93):
                d.line(P(0, y, 64, y), fill=trim, width=S)
        if face == 'outer':
            for y in (89, 93) if cut != 'Reefer' else (90,):
                button(d, 50, y, 1.3, trim if cut == 'Reefer' else adjust(coat, -36), shine=cut == 'Reefer')
    if look.get('crape'):  # black-edged cuff
        d.rectangle(P(0, 96, 64, 102), fill=(14, 14, 16))
    else:
        d.rectangle(P(0, 96, 64, 102), fill=LINEN)
        d.line(P(0, 96, 64, 96), fill=(20, 20, 22), width=S)
        if face == 'outer':
            button(d, 32, 99, 1.2, trim)
    if look.get('patched') and face == 'back':  # worn through at the elbow, darned
        d.ellipse(P(20, 56, 44, 70), fill=adjust(coat, -22))
        for y in range(58, 69, 2):
            d.line(P(22, y, 42, y), fill=(140, 130, 112), width=S // 2)
    im = shade(im, sides=60)
    im = grime(im, 'sl' + seed, 35, (0, 60 * S, w, 96 * S), 18, (90, 84, 76))
    d = ImageDraw.Draw(im)
    d.rectangle(P(0, 103, 64, 128), fill=(0, 0, 0, 0))  # the hand
    return reduce(im, (64, 128))

def leg(look, face, seed):
    lower, coat = look['lower'], look['coat']
    w, h = 64 * S, 128 * S
    im = cloth((w, h), lower, 'lg' + seed, look, twill=False)
    d = ImageDraw.Draw(im)
    top = 98 if not look.get('skirt') else 84
    if look.get('skirt'):  # stockings under the skirt (the mesh hides them), buttoned boots
        pass
    else:
        if face == 'front':  # pressed crease and knee bagging
            d.line(P(32, 0, 32, top), fill=adjust(lower, -18), width=S)
            d.line(P(33, 0, 33, top), fill=adjust(lower, 12), width=S // 2)
            d.arc(P(16, 40, 48, 54), 200, 340, fill=adjust(lower, -12), width=S // 2 + 1)
        if face == 'outer':
            d.line(P(32, 0, 32, top), fill=adjust(lower, -16), width=S)
            if look['cut'] == 'Reefer':
                d.line(P(30, 0, 30, top), fill=look['trim'], width=S)  # company piping
        if look['cut'] == 'Frock' and face in ('back', 'outer', 'inner'):  # the frock's skirts to the knee
            d.rectangle(P(0, 0, 64, 50), fill=coat)
            d.line(P(0, 50, 64, 50), fill=adjust(coat, -30), width=S)
            if face == 'back':
                d.line(P(32 if seed in ('85', '440') else 0, 0, 32 if seed in ('85', '440') else 0, 50), fill=adjust(coat, -30), width=S)
        if look['cut'] in ('Sack', 'Reefer') and face in ('back', 'outer', 'inner', 'front'):  # the jacket's hem over the hips
            d.rectangle(P(0, 0, 64, 12), fill=coat)
            d.line(P(0, 12, 64, 12), fill=adjust(coat, -30), width=S)
        if look.get('patched') and face == 'front':  # a knee patch
            d.rectangle(P(18, 44, 44, 62), fill=adjust(lower, 14))
            stitch(d, [(18, 44), (44, 44), (44, 62), (18, 62), (18, 44)], (60, 50, 40), 2)
        d.rectangle(P(0, top - 4, 64, top), fill=adjust(lower, -14))  # trouser hem breaking on the boot
    d.rectangle(P(0, top, 64, 128), fill=BOOT)
    d.line(P(0, top, 64, top), fill=(70, 60, 54), width=S)
    if face == 'front':
        d.ellipse(P(10, 106, 54, 128), fill=(38, 32, 28)); d.ellipse(P(24, 110, 36, 114), fill=(84, 76, 70))
        if not look.get('skirt'):  # laces
            for y in range(top + 3, 112, 4):
                d.line(P(26, y, 38, y + 2), fill=(60, 52, 44), width=S // 2)
    d.rectangle(P(0, 122, 64, 128), fill=(16, 14, 13))
    im = shade(im, sides=60)
    im = grime(im, 'lg' + seed, 80, (0, 96 * S, w, h), 30, (82, 72, 60))
    return reduce(im, (64, 128))

def sheet(look, kind):
    out = Image.new('RGBA', (585, 559), (0, 0, 0, 0))
    if kind == 'shirt':
        down = reduce(cloth((128 * S, 64 * S), look['lower'] if look['cut'] == 'Bodice' else look['coat'], 'dn', look), (128, 64))
        faces = {'front': torso_front(look), 'back': torso_back(look), 'right': torso_side(look, 'r'),
                 'left': torso_side(look, 'l'), 'up': torso_up(look), 'down': down}
        for side, (x, y, w, h) in TORSO.items():
            out.paste(faces[side], (x, y))
    names = {19: 'inner', 85: 'back', 151: 'outer', 217: 'front', 308: 'front', 374: 'outer', 440: 'back', 506: 'inner'}
    for x, y in LIMBS:
        panel = sleeve(look, names[x], str(x)) if kind == 'shirt' else leg(look, names[x], str(x))
        out.paste(panel, (x, y), panel)
    for x in (217, 308):
        if kind == 'shirt':
            out.paste(reduce(cloth((64 * S, 64 * S), look['coat'], 'au' + str(x), look), (64, 64)), (x, 289))
        else:
            out.paste(reduce(cloth((64 * S, 64 * S), look['lower'], 'lu' + str(x), look, False), (64, 64)), (x, 289))
            out.paste(Image.new('RGBA', (64, 64), (16, 14, 13, 255)), (x, 485))
    return out

def skirt_atlas(look):
    """Mabel's skirt atlas in this passenger's cloth; the ticket pouch becomes a plain purse at the
    waist (no stubs, no pencil)."""
    mt.SKIRT = look['lower']
    mt.LEATHER = adjust(look['lower'], -8) if look.get('crape') else (60, 40, 30)
    mt.BRASS = look['trim']
    im = mt.skirt_atlas().convert('RGBA')
    purse = weave((256, 256), mt.LEATHER, 'purse', amp=8, twill=False)
    im.paste(purse, (768, 768))
    if look.get('skirt') == 'Bustle':  # a deep flounce at the hem
        d = ImageDraw.Draw(im)
        d.rectangle((0, 520, 1024, 600), fill=adjust(look['lower'], 12))
        for x in range(0, 1024, 16):
            d.arc((x, 590, x + 16, 606), 0, 180, fill=adjust(look['lower'], -20), width=3)
        d.line((0, 520, 1024, 520), fill=look['trim'], width=6)
    if look.get('crape'):  # a crape band round the skirt
        d = ImageDraw.Draw(im)
        band = cloth((1024, 90), (14, 13, 15), 'band', look, twill=False)
        im.paste(band, (0, 480))
    return im.convert('RGB')

def bag_atlas():
    """1024: post-bag leather (0..512 x 0..512), canvas paper bag (512..1024 x 0..512), newsprint
    (0..512 x 512..1024), reticule velvet (512..768 x 512..768), brass and cord (768..1024 x 512..768),
    strap leather (512..1024 x 768..1024)."""
    im = Image.new('RGB', (1024, 1024))
    leather = weave((512, 512), (78, 50, 32), 'post', amp=10, twill=False)
    d = ImageDraw.Draw(leather); rng = random.Random('hide')
    for _ in range(1600):
        x, y = rng.uniform(0, 512), rng.uniform(0, 512)
        d.point((x, y), fill=adjust((78, 50, 32), rng.choice((-24, -14, 12))))
    d.rectangle((12, 12, 500, 500), outline=adjust((78, 50, 32), 26), width=3)
    for x in range(18, 496, 12):
        d.line((x, 16, x + 6, 16), fill=(196, 170, 120), width=2); d.line((x, 496, x + 6, 496), fill=(196, 170, 120), width=2)
    d.text((170, 230), 'COMPANY POST', fill=(150, 112, 60))
    leather = grime(leather.convert('RGBA'), 'postwear', 90, None, 80, (40, 26, 18))
    im.paste(leather.convert('RGB'), (0, 0))
    canvas = weave((512, 512), (150, 136, 104), 'canvas', amp=9, twill=False)
    d = ImageDraw.Draw(canvas)
    for y in range(0, 512, 3):
        d.line((0, y, 512, y), fill=adjust((150, 136, 104), -6 if y % 6 else 4))
    d.rectangle((10, 10, 502, 502), outline=(110, 98, 74), width=4)
    canvas = grime(canvas.convert('RGBA'), 'ink', 110, None, 90, (60, 56, 50))
    im.paste(canvas.convert('RGB'), (512, 0))
    paper = Image.new('RGB', (512, 512), (214, 206, 186)); d = ImageDraw.Draw(paper)
    for y in range(24, 512, 10):  # columns of small print
        for col in range(4):
            x0 = 16 + col * 124
            d.line((x0, y, x0 + rng.randint(80, 112), y), fill=(120, 114, 104), width=3)
    d.rectangle((16, 4, 496, 20), fill=(40, 38, 36))  # masthead rule
    im.paste(paper.filter(ImageFilter.GaussianBlur(.7)), (0, 512))
    velvet = weave((256, 256), (136, 118, 84), 'velvet', amp=12, twill=False)
    im.paste(velvet.convert('RGB'), (512, 512))
    misc = Image.new('RGB', (256, 256), (196, 160, 90)); d = ImageDraw.Draw(misc)
    for y in range(0, 128, 4):
        d.line((0, y, 256, y), fill=adjust((196, 160, 90), int(30 * math.sin(y / 14))))
    d.rectangle((0, 128, 256, 256), fill=(60, 44, 34))
    for x in range(0, 256, 8):
        d.line((x, 128, x + 8, 256), fill=(84, 64, 48), width=3)
    im.paste(misc, (768, 512))
    strap = weave((512, 256), (66, 42, 28), 'strap', amp=8, twill=False); d = ImageDraw.Draw(strap)
    for x in range(6, 512, 10):
        d.line((x, 12, x + 5, 12), fill=(180, 150, 100), width=2); d.line((x, 244, x + 5, 244), fill=(180, 150, 100), width=2)
    im.paste(strap.convert('RGB'), (512, 768))
    return im

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for pid, look in LOOKS.items():
        name = pid.lower()
        sheet(look, 'shirt').save(OUT / f'{name}-shirt.png')
        sheet(look, 'pants').save(OUT / f'{name}-pants.png')
        if look.get('skirt'):
            skirt_atlas(look).save(OUT / f'{name}-skirt.png')
    bag_atlas().save(OUT / 'bags.png')
    (OUT / 'looks.json').write_text(__import__('json').dumps(LOOKS, indent=1))  # for passenger_r6.py (no Pillow in Blender)

if __name__ == '__main__':
    main()
