"""Mabel Orrin (ticket clerk) on the R6 body: classic sheets, face decal, piece textures.
Run with Python + Pillow, then Blender --background --python mabel_r6.py.
Output goes to $MABEL_OUT (default assets/crew-clothing/mabel-r6).
Faces are painted at 4x and reduced, so the 128 px template faces stay clean at arm's length.
References: navy wool bodices c. 1893-1900 (Gunn Historical Museum D 208d.2, MOTAT 69723), the
clerk's starched stand collar, ribbon tie and black sateen sleeve protectors, a leather ticket pouch
on the belt, side-button boots 1890s (ASU FIDM, LACMA 8049), Bonney-Vehslage conductor's punch
(NMAH 843150).
"""
import math, os, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops
sys.path.insert(0, str(Path(__file__).resolve().parent))
from textures import TORSO, LIMBS, adjust

OUT = Path(os.environ.get('MABEL_OUT', Path(__file__).resolve().parents[2] / 'assets/crew-clothing/mabel-r6'))
S = 4
NAVY = (40, 50, 78)
SKIRT = (33, 40, 62)
BRASS = (201, 160, 82)
COLLAR = (236, 234, 226)
SATEEN = (20, 20, 24)
LEATHER = (78, 50, 32)
STOCK = (30, 33, 48)
BOOT = (26, 23, 22)
HAIR = (150, 147, 148)
SKIN = (234, 196, 168)

def rgba(c, a=255):
    return (*c, a)

def weave(size, color, seed, amp=6, twill=True):
    """Wool twill: per-pixel grain plus diagonal ribs, drawn at full (4x) size."""
    rng = random.Random(seed)
    w, h = size
    im = Image.new('RGBA', size, rgba(color))
    px = im.load()
    for y in range(h):
        for x in range(w):
            rib = 4 if twill and ((x + y) // S) % 3 == 0 else 0
            d = rng.randint(-amp, amp) + rib
            px[x, y] = rgba(adjust(color, d))
    return im.filter(ImageFilter.GaussianBlur(S * .35))

def grime(im, seed, strength, region=None, blobs=60, tint=(46, 40, 34)):
    """Soft dust and handling marks; region limits them (x0, y0, x1, y1) in 4x pixels."""
    rng = random.Random(seed)
    mask = Image.new('L', im.size, 0)
    d = ImageDraw.Draw(mask)
    x0, y0, x1, y1 = region or (0, 0, im.width, im.height)
    for _ in range(blobs):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        r = rng.randrange(2 * S, 9 * S)
        d.ellipse((x - r, y - r, x + r, y + r), fill=rng.randrange(10, strength))
    mask = mask.filter(ImageFilter.GaussianBlur(4 * S))
    keep = im.getchannel('A')
    out = Image.composite(Image.new('RGBA', im.size, rgba(tint)), im, mask)
    out.putalpha(keep)
    return out

def shade(im, top=0, bottom=0, sides=0):
    """Broad baked light: darker toward edges and the lower hem, no hard lines."""
    w, h = im.size
    g = Image.new('L', (w, h))
    px = g.load()
    for y in range(h):
        for x in range(w):
            e = abs(x / (w - 1) * 2 - 1)
            v = sides * e ** 3 + top * (1 - y / h) ** 4 + bottom * (y / h) ** 3
            px[x, y] = int(max(0, min(255, v)))
    keep = im.getchannel('A')
    out = Image.composite(Image.new('RGBA', im.size, (12, 14, 22, 255)), im, g)
    out.putalpha(keep)
    return out

def button(d, x, y, r=2.2):
    x, y, r = x * S, y * S, r * S
    d.ellipse((x - r - S * .6, y - r - S * .2, x + r + S * .6, y + r + S), fill=(20, 22, 32))
    d.ellipse((x - r, y - r, x + r, y + r), fill=BRASS)
    d.ellipse((x - r * .55, y - r * .7, x + r * .25, y - r * .05), fill=(240, 214, 150))
    d.arc((x - r, y - r, x + r, y + r), 20, 160, fill=(122, 92, 44), width=max(1, S // 2))

def reduce(im, size):
    return im.resize(size, Image.LANCZOS)

# ---------------------------------------------------------------- shirt faces
WAIST = 93  # torso px where the bodice ends; the skirt mesh covers below this
SHOULDER_TOP = 0

def torso_front():
    w, h = 128 * S, 128 * S
    im = weave((w, h), NAVY, 'front')
    d = ImageDraw.Draw(im)
    # princess seams: two curved darts from shoulder to waist
    for s in (-1, 1):
        pts = [((64 + s * (30 - 9 * (t / 10) ** 1.6)) * S, (18 + t * 7.5) * S) for t in range(11)]
        d.line(pts, fill=adjust(NAVY, -16), width=S)
        d.line([(x + s * S, y) for x, y in pts], fill=adjust(NAVY, 12), width=S // 2)
    # placket with brass piping
    d.rectangle((60 * S, 24 * S, 68 * S, WAIST * S), fill=adjust(NAVY, -7))
    for x in (59.5, 68.5):
        d.line((x * S, 24 * S, x * S, WAIST * S), fill=BRASS, width=S // 2 + 1)
    for y in range(31, WAIST - 3, 9):
        button(d, 64, y, 1.9)
    # starched stand collar: a stiff white band round the neck, its points turned down at the front
    d.rectangle((42 * S, 0, 86 * S, 11 * S), fill=COLLAR)
    d.line((42 * S, 11 * S, 86 * S, 11 * S), fill=adjust(NAVY, -22), width=S)  # shadow under the band
    d.line((42 * S, 1.5 * S, 86 * S, 1.5 * S), fill=adjust(COLLAR, -16), width=S // 2)  # turned top edge
    for k in (-1, 1):  # wing points
        d.polygon([((64 + k * 1) * S, 4 * S), ((64 + k * 9) * S, 6 * S), ((64 + k * 5) * S, 12 * S)], fill=adjust(COLLAR, -8))
        d.line([((64 + k * 9) * S, 6 * S), ((64 + k * 5) * S, 12 * S)], fill=adjust(COLLAR, -40), width=S // 2)
    for x in (44, 84):  # starch creases
        d.line((x * S, 2 * S, x * S, 10 * S), fill=adjust(COLLAR, -20), width=S // 2)
    # narrow black ribbon tie: a small bow at the throat, two short tails
    d.polygon([(64 * S, 9 * S), (56 * S, 6 * S), (56 * S, 13 * S)], fill=SATEEN)
    d.polygon([(64 * S, 9 * S), (72 * S, 6 * S), (72 * S, 13 * S)], fill=SATEEN)
    d.line((57 * S, 7 * S, 62 * S, 9 * S), fill=(70, 70, 80), width=S // 2)  # sheen
    d.line((66 * S, 9 * S, 71 * S, 7 * S), fill=(70, 70, 80), width=S // 2)
    d.polygon([(62.5 * S, 10 * S), (60 * S, 21 * S), (62.5 * S, 20 * S), (64 * S, 11 * S)], fill=SATEEN)
    d.polygon([(65.5 * S, 10 * S), (68 * S, 20 * S), (65.6 * S, 21 * S), (64 * S, 11 * S)], fill=SATEEN)
    d.rectangle((62.4 * S, 7.6 * S, 65.6 * S, 10.6 * S), fill=(32, 32, 38))  # knot
    # clerk's badge on her left breast (viewer's right): brass oval, raised rim, stamped number
    bx, by = 88, 38
    d.ellipse(((bx - 9) * S, (by - 6.5) * S, (bx + 9) * S, (by + 7.5) * S), fill=(24, 26, 36))
    d.ellipse(((bx - 9) * S, (by - 7) * S, (bx + 9) * S, (by + 6.5) * S), fill=(150, 112, 52))
    d.ellipse(((bx - 7.5) * S, (by - 5.5) * S, (bx + 7.5) * S, (by + 5) * S), fill=BRASS)
    d.ellipse(((bx - 5) * S, (by - 3.6) * S, (bx + 5) * S, (by + 3.2) * S), outline=(122, 92, 44), width=S // 2 + 1)
    for i, x in enumerate((bx - 3, bx - 1, bx + 1, bx + 3)):
        d.line((x * S, (by - 1.5) * S, x * S, (by + 1.5) * S), fill=(110, 80, 36), width=S // 2 + 1)
    d.arc(((bx - 7.5) * S, (by - 5.5) * S, (bx + 7.5) * S, (by + 5) * S), 200, 300, fill=(246, 222, 160), width=S)
    # pencil tucked behind the badge's pin
    d.line(((bx - 13) * S, (by - 12) * S, (bx - 9) * S, (by + 6) * S), fill=(156, 120, 62), width=int(S * 1.6))
    d.line(((bx - 13.3) * S, (by - 12.6) * S, (bx - 12.8) * S, (by - 10.5) * S), fill=(48, 40, 34), width=S)
    # waist: brass-buckled belt, then skirt cloth below
    d.rectangle((0, (WAIST - 4) * S, w, h), fill=SKIRT)
    d.rectangle((0, (WAIST - 5) * S, w, (WAIST + 1) * S), fill=(24, 22, 26))
    d.line((0, (WAIST - 5) * S, w, (WAIST - 5) * S), fill=adjust(BRASS, -40), width=S // 2)
    d.rectangle((58 * S, (WAIST - 7) * S, 70 * S, (WAIST + 3) * S), outline=BRASS, width=S + 1)
    d.line((63 * S, (WAIST - 6) * S, 63 * S, (WAIST + 2) * S), fill=(230, 200, 130), width=S // 2 + 1)
    im = shade(im, top=0, bottom=40, sides=70)
    im = grime(im, 'front', 70, (0, 40 * S, w, h), 50)
    return reduce(im, (128, 128))

def torso_back():
    w, h = 128 * S, 128 * S
    im = weave((w, h), NAVY, 'back')
    d = ImageDraw.Draw(im)
    for s in (-1, 1):
        pts = [((64 + s * (22 - 12 * (t / 10))) * S, (14 + t * 7.8) * S) for t in range(11)]
        d.line(pts, fill=adjust(NAVY, -15), width=S)
    d.line((64 * S, 10 * S, 64 * S, WAIST * S), fill=adjust(NAVY, -12), width=S)
    d.rectangle((40 * S, 0, 88 * S, 9 * S), fill=adjust(COLLAR, -6))  # collar band from behind
    d.line((40 * S, 9 * S, 88 * S, 9 * S), fill=adjust(NAVY, -22), width=S)
    d.line((40 * S, 1.5 * S, 88 * S, 1.5 * S), fill=adjust(COLLAR, -20), width=S // 2)
    d.rectangle((0, (WAIST - 4) * S, w, h), fill=SKIRT)
    d.rectangle((0, (WAIST - 5) * S, w, (WAIST + 1) * S), fill=(24, 22, 26))
    im = shade(im, bottom=30, sides=70)
    im = grime(im, 'back', 40, None, 25)
    return reduce(im, (128, 128))

def torso_side(side):
    w, h = 64 * S, 128 * S
    im = weave((w, h), NAVY, 'side' + side)
    d = ImageDraw.Draw(im)
    d.line((32 * S, 6 * S, 30 * S, WAIST * S), fill=adjust(NAVY, -15), width=S)
    d.rectangle((14 * S, 0, 50 * S, 6 * S), fill=adjust(COLLAR, -10))  # collar band at the side of the neck
    d.line((14 * S, 6 * S, 50 * S, 6 * S), fill=adjust(NAVY, -20), width=S)
    d.rectangle((0, (WAIST - 4) * S, w, h), fill=SKIRT)
    d.rectangle((0, (WAIST - 5) * S, w, (WAIST + 1) * S), fill=(24, 22, 26))
    im = shade(im, bottom=30, sides=40)
    return reduce(im, (64, 128))

def torso_up():
    w, h = 128 * S, 64 * S
    im = weave((w, h), NAVY, 'up')
    d = ImageDraw.Draw(im)
    # the collar band seen from above: a narrow white ring round the base of the head
    d.rounded_rectangle((36 * S, 12 * S, 92 * S, 56 * S), radius=8 * S, outline=adjust(COLLAR, -8), width=4 * S)
    d.rounded_rectangle((35 * S, 11 * S, 93 * S, 57 * S), radius=8 * S, outline=adjust(NAVY, -20), width=S // 2)
    return reduce(im, (128, 64))

def sleeve(face, seed):
    """One arm face: gathered shoulder, garter band, a clerk's black sateen sleeve protector over the
    forearm (elastic gathers at both ends), then a plain starched cuff with a brass link."""
    w, h = 64 * S, 128 * S
    im = weave((w, h), NAVY, 'sl' + seed)
    d = ImageDraw.Draw(im)
    # shoulder gathers (leg-of-mutton puff)
    for x in range(4, 64, 6):
        d.line((x * S, 0, (x + 2) * S, 22 * S), fill=adjust(NAVY, -14), width=S)
        d.line(((x + 2) * S, 0, (x + 3) * S, 18 * S), fill=adjust(NAVY, 14), width=S // 2)
    d.line((0, 1 * S, w, 1 * S), fill=adjust(NAVY, -20), width=S)
    # sleeve garter: dark band, slight pucker above, brass clasp on the outer face
    d.rectangle((0, 42 * S, w, 48 * S), fill=(22, 22, 28))
    d.line((0, 43 * S, w, 43 * S), fill=(60, 58, 66), width=S // 2)
    for x in range(2, 64, 5):
        d.line((x * S, 36 * S, (x + 1) * S, 41 * S), fill=adjust(NAVY, -18), width=S // 2 + 1)
    if face == 'outer':
        d.rectangle((26 * S, 41 * S, 38 * S, 49 * S), fill=BRASS)
        d.rectangle((28 * S, 43 * S, 36 * S, 47 * S), fill=(120, 90, 42))
        d.line((27 * S, 41.5 * S, 37 * S, 41.5 * S), fill=(242, 216, 150), width=S // 2)
    # sleeve protector: black sateen from just below the garter to the wrist, soft lengthwise folds
    # and a dull sheen, gathered on elastic at the top and the wrist
    rng = random.Random('prot' + seed)
    d.rectangle((0, 52 * S, w, 96 * S), fill=SATEEN)
    for x in range(3, 64, 7):
        x2 = x + rng.uniform(-2, 2)
        d.line((x * S, 56 * S, x2 * S, 92 * S), fill=(32, 32, 39), width=S // 2 + 1)
        d.line(((x + 2) * S, 58 * S, (x2 + 2) * S, 90 * S), fill=(12, 12, 15), width=S // 2)
    if face in ('front', 'outer'):
        d.line((20 * S, 60 * S, 18 * S, 88 * S), fill=(66, 66, 76), width=S)  # sheen down the forearm
    for y0 in (52, 92):
        d.rectangle((0, y0 * S, w, (y0 + 4) * S), fill=(28, 28, 34))
        for x in range(1, 64, 3):
            d.line((x * S, y0 * S, (x + 1) * S, (y0 + 4) * S), fill=(10, 10, 12), width=S // 2)
    if face == 'back':  # worn shiny at the elbow from the counter
        d.ellipse((18 * S, 60 * S, 46 * S, 72 * S), fill=(29, 29, 35))
    # starched cuff below the protector, a brass link on the outer face
    d.rectangle((0, 96 * S, w, 103 * S), fill=COLLAR)
    d.line((0, 96 * S, w, 96 * S), fill=(12, 12, 14), width=S)
    d.line((0, 102.5 * S, w, 102.5 * S), fill=adjust(COLLAR, -30), width=S // 2)
    if face == 'outer':
        button(d, 32, 99.5, 1.4)
    im = shade(im, top=0, bottom=0, sides=60)
    im = grime(im, 'sl' + seed, 35 if face in ('front', 'outer') else 20, (0, 60 * S, w, 96 * S), 18, (90, 84, 76))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 104 * S, w, h), fill=(0, 0, 0, 0))
    return reduce(im, (64, 128))

# ---------------------------------------------------------------- pants faces
def leg(face, seed):
    w, h = 64 * S, 128 * S
    im = weave((w, h), STOCK, 'lg' + seed, amp=5, twill=False)
    d = ImageDraw.Draw(im)
    for x in range(2, 64, 3):  # knit ribbing
        d.line((x * S, 0, x * S, 70 * S), fill=adjust(STOCK, -8), width=S // 2 + 1)
    # buttoned boot: shaft from 66 px down, scalloped button fly on the outer face
    top = 66
    d.rectangle((0, top * S, w, h), fill=BOOT)
    d.line((0, top * S, w, top * S), fill=(70, 60, 54), width=S)
    d.line((0, (top + 1.5) * S, w, (top + 1.5) * S), fill=(12, 10, 10), width=S // 2)
    for x in range(3, 64, 4):  # vamp stitching line
        d.point((x * S, (top + 3) * S), fill=(90, 80, 70))
    if face == 'outer':
        d.polygon([(30 * S, top * S), (50 * S, top * S), (50 * S, 112 * S), (24 * S, 112 * S)], fill=(34, 30, 29))
        for i, y in enumerate(range(top + 5, 110, 6)):
            x = 44 - (y - top) * .1
            d.arc(((x - 5) * S, (y - 3) * S, (x + 5) * S, (y + 3) * S), 90, 270, fill=(52, 46, 42), width=S // 2 + 1)
            d.ellipse(((x - 1.6) * S, (y - 1.6) * S, (x + 1.6) * S, (y + 1.6) * S), fill=(18, 16, 18))
            d.point(((x - .5) * S, (y - .6) * S), fill=(120, 116, 120))
    if face == 'front':
        d.ellipse((10 * S, 106 * S, 54 * S, 128 * S), fill=(36, 32, 30))  # toe cap
        d.arc((10 * S, 106 * S, 54 * S, 128 * S), 200, 340, fill=(96, 86, 80), width=S)
        d.ellipse((24 * S, 110 * S, 36 * S, 114 * S), fill=(80, 74, 70))  # toe shine
    d.rectangle((0, 122 * S, w, h), fill=(16, 14, 13))  # sole edge
    d.line((0, 122 * S, w, 122 * S), fill=(60, 50, 40), width=S // 2 + 1)
    im = shade(im, sides=60)
    im = grime(im, 'lg' + seed, 80, (0, 100 * S, w, h), 30, (82, 72, 60))
    return reduce(im, (64, 128))

def sheet(kind):
    out = Image.new('RGBA', (585, 559), (0, 0, 0, 0))
    if kind == 'shirt':
        faces = {'front': torso_front(), 'back': torso_back(), 'right': torso_side('r'), 'left': torso_side('l'),
                 'up': torso_up(), 'down': reduce(weave((128 * S, 64 * S), SKIRT, 'dn'), (128, 64))}
        for side, (x, y, w, h) in TORSO.items():
            out.paste(faces[side], (x, y))
    # limb faces per template: right limb L B R F at 19/85/151/217, left limb F L B R at 308/374/440/506
    names = {19: 'inner', 85: 'back', 151: 'outer', 217: 'front', 308: 'front', 374: 'outer', 440: 'back', 506: 'inner'}
    for x, y in LIMBS:
        face = names[x]
        panel = sleeve(face, str(x)) if kind == 'shirt' else leg(face, str(x))
        out.paste(panel, (x, y), panel)
    for x in (217, 308):
        if kind == 'shirt':
            top = reduce(weave((64 * S, 64 * S), NAVY, 'au' + str(x)), (64, 64))
            out.paste(top, (x, 289))
        else:
            top = reduce(weave((64 * S, 64 * S), STOCK, 'lu' + str(x), twill=False), (64, 64))
            out.paste(top, (x, 289))
            out.paste(Image.new('RGBA', (64, 64), (16, 14, 13, 255)), (x, 485))
    return out

# ---------------------------------------------------------------- face decal
class Filled:
    """ImageDraw wrapper: closed shapes are filled with ink 0 unless told otherwise."""
    def __init__(self, d):
        self.d = d
    def __getattr__(self, name):
        fn = getattr(self.d, name)
        if name in ('ellipse', 'polygon', 'rectangle'):
            return lambda *a, **k: fn(*a, **({'fill': 0} | k))
        return fn

def face_decal():
    """Calm, a little tired; soft painted shapes, no black outlines. 512 px, transparent.
    Features are full and bold (wide almond eyes, strong brows, full lips) so they read from across
    the saloon, not only at arm's length."""
    N = 512 * 2
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    def layer(draw_fn, blur, color, alpha):
        # shapes are drawn with Pillow's default ink (0) on white, then inverted into a mask
        m = Image.new('L', (N, N), 255)
        draw_fn(Filled(ImageDraw.Draw(m)))
        m = ImageChops.invert(m).filter(ImageFilter.GaussianBlur(blur)).point(lambda v: v * alpha // 255)
        col = Image.new('RGBA', (N, N), rgba(color))
        col.putalpha(m)
        return col
    def comp(l):
        nonlocal im
        im = Image.alpha_composite(im, l)
    c = N // 2
    ey = int(N * .46)   # eye line
    ex = int(N * .17)   # half eye spacing
    # under-eye shadow and lid shadow (tired, softer than before)
    comp(layer(lambda d: [d.ellipse((c + s * ex - 86, ey + 26, c + s * ex + 86, ey + 86)) for s in (-1, 1)], 26, (150, 104, 98), 95))
    comp(layer(lambda d: [d.ellipse((c + s * ex - 96, ey - 80, c + s * ex + 96, ey + 6)) for s in (-1, 1)], 22, (164, 118, 108), 120))
    # cheeks
    comp(layer(lambda d: [d.ellipse((c + s * 270 - 110, ey + 120, c + s * 270 + 110, ey + 260)) for s in (-1, 1)], 50, (214, 128, 116), 85))
    # nose: broad soft side shadow, rounded tip, nostril wings
    comp(layer(lambda d: d.polygon([(c - 34, ey - 10), (c - 8, ey - 10), (c - 6, ey + 160), (c - 58, ey + 172)]), 18, (172, 118, 100), 110))
    comp(layer(lambda d: d.ellipse((c - 62, ey + 150, c + 62, ey + 206)), 16, (182, 124, 106), 95))
    comp(layer(lambda d: [d.ellipse((c + s * 36 - 20, ey + 174, c + s * 36 + 20, ey + 198)) for s in (-1, 1)], 6, (106, 62, 56), 170))
    comp(layer(lambda d: d.ellipse((c - 20, ey + 148, c + 16, ey + 168)), 7, (255, 236, 222), 100))
    # nasolabial folds, soft
    comp(layer(lambda d: [d.arc((c + s * 84 - 56, ey + 160, c + s * 84 + 56, ey + 320), 180 if s < 0 else 270, 270 if s < 0 else 360, width=10) for s in (-1, 1)], 9, (166, 110, 98), 85))
    # eyes: wide almond whites, large grey-blue iris, pupil, two catchlights, a full brown upper lid
    for s in (-1, 1):
        x = c + s * ex
        eye = [(x - 84, ey + 2), (x - 44, ey - 38), (x + 12, ey - 44), (x + 66, ey - 24), (x + 84, ey + 4),
               (x + 44, ey + 34), (x - 26, ey + 36)]
        if s < 0:
            eye = [(2 * x - px, py) for px, py in eye]
        comp(layer(lambda d: d.polygon(eye), 3, (238, 230, 222), 255))
        comp(layer(lambda d: d.ellipse((x - 33, ey - 36, x + 33, ey + 30)), 2, (96, 118, 132), 255))
        comp(layer(lambda d: d.ellipse((x - 22, ey - 25, x + 22, ey + 19)), 3, (62, 80, 94), 255))
        comp(layer(lambda d: d.ellipse((x - 13, ey - 16, x + 13, ey + 10)), 2, (22, 20, 22), 255))
        comp(layer(lambda d: d.ellipse((x + s * 10 - 7, ey - 20, x + s * 10 + 7, ey - 6)), 1, (252, 252, 250), 240))
        comp(layer(lambda d: d.ellipse((x - s * 12 - 3, ey + 6, x - s * 12 + 3, ey + 12)), 1, (230, 236, 240), 160))
        # the upper lid sits a little over the iris (calm, tired) with a full dark lash line
        lid = [(eye[0][0], eye[0][1] - 2), eye[1], eye[2], eye[3], (eye[4][0], eye[4][1] - 2),
               (eye[3][0], eye[3][1] - 34), (eye[2][0], eye[2][1] - 38), (eye[1][0], eye[1][1] - 34)]
        lidcut = [(px, py + 10) for px, py in lid[:5]] + lid[5:]
        comp(layer(lambda d: d.polygon(lidcut), 3, (212, 164, 142), 255))
        comp(layer(lambda d: d.line([(px, py + 10) for px, py in lid[:5]], width=22, joint='curve'), 3, (64, 42, 38), 245))
        comp(layer(lambda d: d.line([(px, py - 30) for px, py in eye[1:4]], width=8, joint='curve'), 5, (166, 116, 100), 150))
        comp(layer(lambda d: d.line(eye[4:] + [eye[0]], width=7), 3, (150, 102, 90), 160))
        # crow's feet, faint
        for k in (-1, 0, 1):
            ox = x + s * 92
            comp(layer(lambda d: d.line((ox, ey + k * 12, ox + s * 36, ey + k * 22 - 4), width=4), 3, (170, 118, 104), 85))
        # brows: full, grey-brown, gently lifted at the inside, thicker at the inner end
        brow_top = [(x - s * 84, ey - 92), (x - s * 30, ey - 124), (x + s * 34, ey - 120), (x + s * 92, ey - 92)]
        brow_bot = [(x + s * 90, ey - 84), (x + s * 34, ey - 100), (x - s * 30, ey - 98), (x - s * 86, ey - 66)]
        comp(layer(lambda d: d.polygon(brow_top + brow_bot), 4, (98, 80, 74), 235))
        comp(layer(lambda d: d.line([(px, py + 6) for px, py in brow_top], width=6, joint='curve'), 3, (140, 124, 118), 120))
    # forehead line
    comp(layer(lambda d: d.arc((c - 160, ey - 230, c + 160, ey - 140), 200, 340, width=5), 5, (180, 130, 116), 60))
    # mouth: full, closed, the faintest settle at the corners
    my = int(N * .765)
    comp(layer(lambda d: d.polygon([(c - 96, my), (c - 44, my - 26), (c, my - 16), (c + 44, my - 26), (c + 96, my), (c + 40, my + 4), (c - 40, my + 4)]), 3, (166, 88, 88), 255))
    comp(layer(lambda d: d.polygon([(c - 90, my + 2), (c - 40, my + 4), (c + 40, my + 4), (c + 90, my + 2), (c + 50, my + 52), (c - 50, my + 52)]), 5, (194, 114, 110), 255))
    comp(layer(lambda d: d.line([(c - 98, my + 2), (c - 40, my + 1), (c, my + 4), (c + 40, my + 1), (c + 98, my + 2)], width=9, joint='curve'), 2, (100, 50, 52), 235))
    comp(layer(lambda d: d.ellipse((c - 38, my + 18, c + 38, my + 36)), 6, (238, 172, 162), 120))
    comp(layer(lambda d: [d.ellipse((c + s * 104 - 10, my - 4, c + s * 104 + 10, my + 12)) for s in (-1, 1)], 5, (150, 98, 90), 120))
    comp(layer(lambda d: d.ellipse((c - 50, my + 70, c + 50, my + 100)), 16, (190, 132, 116), 70))
    # crop round the features so they fill the R6 head's face at a readable size
    kw, kh = N / 1.25, N / 1.0
    cy = N * .53
    im = im.crop((int(c - kw / 2), int(cy - kh / 2), int(c + kw / 2), int(cy + kh / 2)))
    return im.resize((512, 512), Image.LANCZOS)

# ---------------------------------------------------------------- piece textures
def skirt_atlas():
    """1024: skirt wool (0..1024 x 0..640, u around, v hem at the bottom row), ticket pouch leather
    (0..512 x 640..1024: body 640..896, flap 896..1024), waistband / strap / stubs / brass
    (512..1024 x 640..1024)."""
    im = Image.new('RGBA', (1024, 1024), rgba(SKIRT))
    wool = weave((1024, 640), SKIRT, 'skirt', amp=7)
    d = ImageDraw.Draw(wool)
    for i in range(14):  # pleat valleys line up with the 14 mesh folds
        x = (i + .5) / 14 * 1024
        d.line((x, 0, x, 640), fill=adjust(SKIRT, -14), width=10)
        d.line((x + 18, 0, x + 18, 640), fill=adjust(SKIRT, 9), width=4)
    d.rectangle((0, 600, 1024, 640), fill=adjust(SKIRT, -8))  # turned hem
    d.line((0, 600, 1024, 600), fill=adjust(SKIRT, 16), width=3)
    for x in range(0, 1024, 9):
        d.point((x, 604), fill=adjust(SKIRT, 22))
    wool = wool.filter(ImageFilter.GaussianBlur(.6))
    wool = grime(wool, 'hem', 120, (0, 470, 1024, 640), 260, (72, 62, 50))  # platform dust at the hem
    wool = grime(wool, 'lap', 40, (300, 0, 720, 240), 30)
    im.paste(wool, (0, 0))
    # ticket pouch: oiled brown leather, stitched edges, darker worn corners
    leather = weave((512, 384), LEATHER, 'pouch', amp=10, twill=False)
    d = ImageDraw.Draw(leather)
    rng = random.Random('hide')
    for _ in range(900):  # grain
        x, y = rng.uniform(0, 512), rng.uniform(0, 384)
        d.point((x, y), fill=adjust(LEATHER, rng.choice((-22, -14, 12))))
    for y0, y1 in ((0, 256), (256, 384)):
        d.rectangle((10, y0 + 10, 502, y1 - 10), outline=adjust(LEATHER, 30), width=2)
        for x in range(14, 500, 12):  # saddle stitching
            d.line((x, y0 + 12, x + 6, y0 + 12), fill=(196, 170, 120), width=2)
            d.line((x, y1 - 12, x + 6, y1 - 12), fill=(196, 170, 120), width=2)
    d.line((0, 256, 512, 256), fill=adjust(LEATHER, -40), width=4)  # flap fold
    leather = leather.filter(ImageFilter.GaussianBlur(.5))
    leather = grime(leather, 'pouchwear', 80, (0, 0, 512, 384), 70, (40, 26, 18))
    for cx, cy in ((0, 0), (452, 0), (0, 196), (452, 196)):  # rubbed corners
        leather = grime(leather, f'c{cx}{cy}', 120, (cx, cy, cx + 60, cy + 60), 20, (30, 20, 14))
    im.paste(leather, (0, 640))
    misc = Image.new('RGBA', (512, 384), rgba((24, 22, 26)))
    d = ImageDraw.Draw(misc)
    d.rectangle((0, 0, 256, 128), fill=(24, 22, 26))  # waistband leather
    for x in range(6, 256, 8):
        d.point((x, 10), fill=(80, 70, 60)); d.point((x, 118), fill=(80, 70, 60))
    d.rectangle((256, 0, 512, 128), fill=BRASS)  # brass buckle
    for y in range(0, 128, 4):
        d.line((256, y, 512, y), fill=adjust(BRASS, int(30 * math.sin(y / 18))))
    d.rectangle((0, 128, 256, 384), fill=adjust(LEATHER, -30))  # strap leather
    for y in range(140, 384, 6):
        d.line((0, y, 256, y), fill=adjust(LEATHER, -42))
    d.rectangle((256, 128, 512, 256), fill=(226, 214, 180))  # ticket stubs
    for x in range(256, 512, 32):
        d.line((x, 128, x, 256), fill=(120, 96, 70), width=2)
        d.ellipse((x + 12, 150, x + 20, 158), fill=(60, 50, 40))
    d.rectangle((256, 256, 512, 384), fill=(156, 120, 62))  # pencil
    d.rectangle((256, 256, 300, 384), fill=(48, 40, 34))
    im.paste(misc, (512, 640))
    return im.convert('RGB')

def hair_atlas():
    """512: strands along v (0..512 x 0..384), bun coils (0..512 x 384..512)."""
    im = Image.new('RGB', (512, 512), HAIR)
    rng = random.Random('hair')
    d = ImageDraw.Draw(im)
    for _ in range(2600):
        x = rng.uniform(0, 512)
        y = rng.uniform(0, 384)
        l = rng.uniform(20, 90)
        col = adjust(HAIR, rng.choice((-22, -12, -5, 6, 14, 22)))
        if rng.random() < .05:
            col = (200, 198, 198)  # white strands
        d.line((x, y, x + rng.uniform(-3, 3), min(384, y + l)), fill=col, width=1)
    for _ in range(1800):
        x = rng.uniform(0, 512)
        y = rng.uniform(384, 512)
        col = adjust(HAIR, rng.choice((-22, -10, 6, 18)))
        if rng.random() < .05:
            col = (200, 198, 198)
        d.line((x, y, x + rng.uniform(30, 80), y + rng.uniform(-6, 6)), fill=col, width=1)
    for y in range(384, 512, 32):  # coil grooves
        d.line((0, y, 512, y + 6), fill=adjust(HAIR, -42), width=3)
    d.rectangle((470, 384, 512, 512), fill=(70, 66, 64))  # hairpin swatch
    return im.filter(ImageFilter.GaussianBlur(.5))

def visor_atlas():
    """512: navy felt band (0..512 x 0..256), navy brim (0..512 x 256..448), brass binding (448..512)."""
    im = Image.new('RGB', (512, 512), NAVY)
    felt = weave((512, 256), NAVY, 'felt', amp=8, twill=False).convert('RGB')
    d = ImageDraw.Draw(felt)
    d.line((0, 20, 512, 20), fill=adjust(NAVY, 20), width=2)
    d.line((0, 236, 512, 236), fill=adjust(NAVY, 20), width=2)
    for x in range(0, 512, 7):
        d.point((x, 26), fill=adjust(NAVY, 34)); d.point((x, 230), fill=adjust(NAVY, 34))
    im.paste(felt, (0, 0))
    brim = weave((512, 192), adjust(NAVY, -6), 'brim', amp=5, twill=False).convert('RGB')
    brim = grime(brim.convert('RGBA'), 'brimwear', 60, (0, 140, 512, 192), 40).convert('RGB')
    d = ImageDraw.Draw(brim)
    for y in range(12, 192, 22):
        d.line((0, y, 512, y), fill=adjust(NAVY, -14), width=2)
    im.paste(brim, (0, 256))
    d = ImageDraw.Draw(im)
    for y in range(448, 512):
        t = (y - 448) / 64
        d.line((0, y, 512, y), fill=adjust(BRASS, int(40 * math.sin(t * math.pi) - 15)))
    return im

def punch_atlas():
    """512, four equal columns for gear.assign_uv slots: 0 polished brass, 1 aged brass,
    2 nickel jaw, 3 chain brass."""
    im = Image.new('RGB', (512, 512), BRASS)
    d = ImageDraw.Draw(im)
    rng = random.Random('punch')
    cols = (BRASS, adjust(BRASS, -45), (168, 170, 172), (176, 138, 70))
    for slot, base in enumerate(cols):
        for x in range(slot * 128, slot * 128 + 128):
            d.line((x, 0, x, 512), fill=adjust(base, int(30 * math.sin((x % 128) / 128 * math.pi)) - 12))
        for _ in range(160):
            x, y = rng.uniform(slot * 128, slot * 128 + 128), rng.uniform(0, 512)
            d.line((x, y, x + rng.uniform(-8, 8), y + rng.uniform(-2, 2)), fill=adjust(base, rng.choice((-45, 35))))
    return im.filter(ImageFilter.GaussianBlur(.6))

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet('shirt').save(OUT / 'mabel-shirt.png')
    sheet('pants').save(OUT / 'mabel-pants.png')
    face_decal().save(OUT / 'mabel-face.png')
    skirt_atlas().save(OUT / 'skirt-pouch.png')
    hair_atlas().save(OUT / 'hair-bun.png')
    visor_atlas().save(OUT / 'eyeshade.png')
    punch_atlas().save(OUT / 'ticket-punch.png')

if __name__ == '__main__':
    main()
