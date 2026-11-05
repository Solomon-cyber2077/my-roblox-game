"""Period signage textures (posters, bills, notices, plaques, chalk, framed texts).

python3 tools/signage/textures.py <out dir> <fonts dir>

Plain PIL, no numpy. Every sheet is drawn on its old SurfaceGui canvas layout (scaled), then
given paper, ink, metal, stone or chalk surface and wear. Writes <name>_color.png, a
<name>_normal.png from a height map, and for the metal atlas _rough/_metal maps, plus
atlas.json with each sign's UV rect (0-1, origin top-left) and size in studs.
"""
import json, math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops, ImageOps

OUT = Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
FD = Path(sys.argv[2])
NOTO = Path('/usr/share/fonts/truetype/noto')
FONTS = {
    'oswald': FD / 'Oswald-Bold.ttf',
    'serif': FD / 'Merriweather-Regular.ttf',
    'serif_i': FD / 'Merriweather-Italic.ttf',
    'gothic': FD / 'GrenzeGotisch-Bold.ttf',
    'bodoni': NOTO / 'NotoSerifDisplay-Bold.ttf',
    'garamond': FD / 'AccanthisADFStd-Regular.otf',
    'guru': FD / 'Guru-Regular.otf',
    'hand': FD / 'Fondamento-Regular.ttf',
}
BOLD = {'serif'}  # faces the game uses in bold that ship here only as regular: thickened with a stroke
RNG = random.Random(1888)
MANIFEST = {}


def font(key, size):
    return ImageFont.truetype(str(FONTS[key]), max(4, int(size)))


def noise(w, h, sigma=60, blur=0.0):
    n = Image.effect_noise((w, h), sigma).convert('L')
    if blur:
        n = n.filter(ImageFilter.GaussianBlur(blur))
        n = ImageOps.autocontrast(n)
    return n


def big_noise(w, h, scale, rng=RNG):
    """Smooth value noise: random cells upsampled."""
    cw, ch = max(2, w // scale + 2), max(2, h // scale + 2)
    small = Image.new('L', (cw, ch))
    small.putdata([rng.randint(0, 255) for _ in range(cw * ch)])
    return small.resize((w, h), Image.BICUBIC)


def wrap(text, f, width):
    lines = []
    for para in text.split('\n'):
        words, cur = para.split(' '), ''
        for wd in words:
            t = (cur + ' ' + wd).strip()
            if f.getlength(t) <= width or not cur:
                cur = t
            else:
                lines.append(cur); cur = wd
        lines.append(cur)
    return lines


def text_mask(size, text, key, box, align='center', bold=False, max_px=None, spacing=1.12):
    """TextScaled: the largest size whose wrapped lines fit the box. Returns an L mask."""
    w, h = size
    x, y, bw, bh = box
    lo, hi = 4, int(max_px or bh * 1.2)
    best = None
    while lo <= hi:
        mid = (lo + hi) // 2
        f = font(key, mid)
        lines = wrap(text, f, bw) if '\n' not in text else text.split('\n')
        asc, desc = f.getmetrics()
        lh = (asc + desc) * spacing
        tw = max(f.getlength(l) for l in lines)
        if tw <= bw and lh * len(lines) <= bh * 1.02:
            best = (mid, f, lines, lh); lo = mid + 1
        else:
            hi = mid - 1
    m = Image.new('L', (w, h), 0)
    if best is None:
        return m
    sz, f, lines, lh = best
    d = ImageDraw.Draw(m)
    top = y + (bh - lh * len(lines)) / 2
    sw = max(1, sz // 28) if bold else 0
    for i, l in enumerate(lines):
        lw = f.getlength(l)
        lx = x + (bw - lw) / 2 if align == 'center' else (x if align == 'left' else x + bw - lw)
        d.text((lx, top + i * lh), l, font=f, fill=255, stroke_width=sw, stroke_fill=255)
    return m


def roughen(mask, amount=0.25, blur=0.5):
    """Letterpress: patchy ink, a little spread."""
    w, h = mask.size
    n = noise(w, h, 80, 1.2).point(lambda v: 255 if v > 70 else int(v * 255 / 70 * (1 - amount) + 255 * amount * 0))
    m = ImageChops.multiply(mask, n)
    return m.filter(ImageFilter.GaussianBlur(blur))


class Sheet:
    """A colour canvas with a height map beside it, drawn in canvas units scaled by k."""

    def __init__(self, w, h, k, base):
        self.k = k
        self.W, self.H = int(w * k), int(h * k)
        self.img = Image.new('RGB', (self.W, self.H), base)
        self.hgt = Image.new('L', (self.W, self.H), 128)
        self.ink_mask = Image.new('L', (self.W, self.H), 0)

    def s(self, v):
        return v * self.k

    def layer(self, draw_fn, color, alpha=1.0):
        m = Image.new('L', (self.W, self.H), 0)
        draw_fn(ImageDraw.Draw(m))
        if alpha < 1:
            m = m.point(lambda v: int(v * alpha))
        self.img.paste(color, (0, 0, self.W, self.H), m)
        return m

    def box(self, color, x, y, w, h, rot=0.0, alpha=1.0):
        s = self.s
        cx, cy = s(x + w / 2), s(y + h / 2)
        a = math.radians(rot)
        pts = []
        for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            px, py = dx * s(w) / 2, dy * s(h) / 2
            pts.append((cx + px * math.cos(a) - py * math.sin(a), cy + px * math.sin(a) + py * math.cos(a)))
        return self.layer(lambda d: d.polygon(pts, fill=255), color, alpha)

    def disc(self, color, cx, cy, dia, alpha=1.0):
        s = self.s
        r = s(dia) / 2
        return self.layer(lambda d: d.ellipse((s(cx) - r, s(cy) - r, s(cx) + r, s(cy) + r), fill=255), color, alpha)

    def fade_box(self, color, x, y, w, h, keys, vertical=True, soft=0):
        """UIGradient transparency keys along the box (rotation 90 = top to bottom)."""
        s = self.s
        x0, y0, x1, y1 = int(s(x)), int(s(y)), int(s(x + w)), int(s(y + h))
        m = Image.new('L', (self.W, self.H), 0)
        n = (y1 - y0) if vertical else (x1 - x0)
        d = ImageDraw.Draw(m)
        for i in range(max(1, n)):
            t = i / max(1, n - 1)
            tr = keys[-1][1]
            for (t0, a0), (t1, a1) in zip(keys, keys[1:]):
                if t0 <= t <= t1:
                    tr = a0 + (a1 - a0) * (t - t0) / max(1e-6, t1 - t0); break
            v = int(255 * (1 - tr))
            if vertical:
                d.line((x0, y0 + i, x1, y0 + i), fill=v)
            else:
                d.line((x0 + i, y0, x0 + i, y1), fill=v)
        if soft:
            m = m.filter(ImageFilter.GaussianBlur(self.s(soft)))
        self.img.paste(color, (0, 0, self.W, self.H), m)

    def words(self, text, key, color, x, y, w, h, align='center', bold=False, press=True):
        s = self.s
        m = text_mask((self.W, self.H), text, key, (s(x), s(y), s(w), s(h)), align, bold or key in BOLD and bold)
        if press:
            m = roughen(m)
        self.img.paste(color, (0, 0, self.W, self.H), m)
        self.ink_mask = ImageChops.lighter(self.ink_mask, m)
        return m

    def rule(self, color, x, y, w, thick=2):
        self.box(color, x, y, w, thick)

    def outline(self, color, x, y, w, h, thick):
        s = self.s
        self.layer(lambda d: d.rectangle((s(x), s(y), s(x + w), s(y + h)), outline=255, width=max(1, int(s(thick)))), color)

    # ---- surfaces
    def paper(self, fibre=0.06, mottle=0.08, edge=0.18):
        W, H = self.W, self.H
        f = noise(W, H, 50, 0.6)
        mot = big_noise(W, H, max(8, W // 10))
        out = self.img
        # fibre and mottling: multiply by a near-white field
        fib = f.point(lambda v: int(255 - abs(v - 128) * fibre * 2))
        mo = mot.point(lambda v: int(255 - v * mottle))
        out = ImageChops.multiply(out, Image.merge('RGB', (fib, fib, fib)))
        out = ImageChops.multiply(out, Image.merge('RGB', (mo, mo, mo)))
        # edges browned
        e = Image.new('L', (W, H), 255)
        ImageDraw.Draw(e).rectangle((W * 0.03, H * 0.03, W * 0.97, H * 0.97), fill=0)
        e = e.filter(ImageFilter.GaussianBlur(W * 0.04)).point(lambda v: int(255 - v * edge))
        out = ImageChops.multiply(out, Image.merge('RGB', (e, e.point(lambda v: int(v * 0.97)), e.point(lambda v: int(v * 0.9)))))
        self.img = out
        # height: fibre + paste wrinkles; ink bites in
        hg = Image.blend(Image.new('L', (W, H), 128), f, 0.06)
        wr = Image.new('L', (W, H), 0)
        d = ImageDraw.Draw(wr)
        for _ in range(6):
            x0, y0 = RNG.uniform(0, W), RNG.uniform(0, H)
            a = RNG.uniform(-0.6, 0.6) + math.pi / 2 * RNG.choice((0, 1))
            L = RNG.uniform(0.2, 0.6) * W
            d.line((x0, y0, x0 + L * math.cos(a), y0 + L * math.sin(a)), fill=RNG.randint(60, 140), width=max(2, W // 160))
        wr = wr.filter(ImageFilter.GaussianBlur(W / 150))
        hg = ImageChops.add(hg, wr)
        self.hgt = hg

    def foxing(self, n=24, color=(120, 86, 50)):
        for _ in range(n):
            x, y = RNG.uniform(0, self.W), RNG.uniform(0, self.H)
            r = RNG.uniform(1, 5) * self.k
            self.layer(lambda d: d.ellipse((x - r, y - r, x + r, y + r), fill=255), color, RNG.uniform(0.15, 0.4))

    def stain(self, cx, cy, dia, alpha=0.16, color=(70, 52, 34)):
        """A damp stain: soft fill and a darker tide line."""
        s = self.s
        r = s(dia) / 2
        X, Y = s(cx), s(cy)
        m = Image.new('L', (self.W, self.H), 0)
        d = ImageDraw.Draw(m)
        pts = []
        for i in range(40):
            a = i / 40 * math.tau
            rr = r * (0.85 + 0.3 * RNG.random())
            pts.append((X + rr * math.cos(a), Y + rr * math.sin(a)))
        d.polygon(pts, fill=int(255 * alpha))
        d.line(pts + [pts[0]], fill=int(255 * min(1, alpha * 2.6)), width=max(2, int(r / 18)))
        m = m.filter(ImageFilter.GaussianBlur(max(1, r / 25)))
        self.img.paste(color, (0, 0, self.W, self.H), m)

    def finish(self, name, rect=None, atlas=None):
        img = self.img
        # ink lies in the paper: the press bites the letters a touch below the sheet
        h = ImageChops.subtract(self.hgt, self.ink_mask.point(lambda v: int(v * 0.12)))
        return img, h


def normal_from(h, strength=2.0):
    """Tangent-space normal map (OpenGL, +Y up) from a height map."""
    kx = ImageFilter.Kernel((3, 3), [-1, 0, 1, -2, 0, 2, -1, 0, 1], scale=1 / strength, offset=128)
    ky = ImageFilter.Kernel((3, 3), [-1, -2, -1, 0, 0, 0, 1, 2, 1], scale=1 / strength, offset=128)
    gx = h.filter(kx)
    gy = h.filter(ky)
    r = ImageOps.invert(gx)  # height rising to the right tilts the normal left
    g = gy  # image rows grow downward: rising downward tilts the normal toward -Y (up in UV is -row)
    b = Image.new('L', h.size, 255)
    bz = ImageChops.subtract(b, ImageChops.add(ImageChops.difference(gx, Image.new('L', h.size, 128)),
                                                ImageChops.difference(gy, Image.new('L', h.size, 128))).point(lambda v: v // 2))
    return Image.merge('RGB', (r, g, bz))


def save(name, color, height, strength=2.0, extra=None):
    color.save(OUT / f'{name}_color.png')
    normal_from(height, strength).save(OUT / f'{name}_normal.png')
    for k, im in (extra or {}).items():
        im.save(OUT / f'{name}_{k}.png')


def worn(S, corner):
    """The old sheet's wear, kept: stains, soot at the foot, the torn corner showing brick."""
    for i, st in enumerate(((470, 120, 120), (90, 560, 90), (380, 470, 60))):
        S.stain(st[0], st[1], st[2], 0.18 - i * 0.03)
    S.fade_box((14, 12, 12), 0, 720 - 120, 560, 120, [(0, 1), (1, 0.45)])
    x = 560 - 46 if corner > 0 else -46
    S.box((80, 46, 38), x, -46, 92, 92, 45)
    S.foxing(30)


# ---------------------------------------------------------------- posters (560 x 720 canvas)
PREMISE = dict(Wanted='H A N D S', For='for the Relief', Body='RELIEF DEPARTS AT DUSK.\nHANDS REPORT TO THE CLERK.',
               Motto='THE DEPOT STANDS WHILE THE LINE RUNS.', Apply='Coldharbour Depot · Apply to the Clerk.')
PK = 1.4  # 560 x 720 -> 784 x 1008


def coast():
    S = Sheet(560, 720, PK, (22, 52, 64))
    bands = [(22, 52, 64), (30, 70, 80), (52, 98, 102), (96, 140, 134), (150, 178, 168)]
    for i, c in enumerate(bands):
        S.box(c, 0, i * 86, 560, 86)
    S.disc((234, 124, 76), 230, 440, 230)
    S.disc((244, 156, 98), 230, 440, 150)
    S.box((20, 46, 66), 0, 440, 560, 170)
    S.box((28, 62, 84), 0, 440, 560, 18)
    for i, w in enumerate((150, 110, 120, 70, 84, 40), 1):
        S.box((234, 124, 76), 230 - w / 2 + ((i % 2) * 2 - 1) * 10, 456 + i * 22, w, 6)
    ink = (14, 28, 34)
    S.box(ink, 380, 330, 200, 280); S.box(ink, 330, 392, 120, 220, -16)
    S.box(ink, 472, 250, 26, 84); S.box((226, 236, 238), 472, 274, 26, 10)
    S.disc((255, 214, 140), 485, 246, 18)
    S.box((255, 214, 140), 485, 236, 120, 20, -8, 0.45)
    S.box(ink, 0, 382, 330, 22)
    for i in range(6):
        S.box(ink, 14 + i * 56, 404, 18, 60)
    for b in ((196, 354, 74, 28), (120, 360, 70, 22), (44, 360, 70, 22), (252, 338, 10, 18)):
        S.box((10, 14, 18), *b)
    for i in range(1, 6):
        S.disc((196, 214, 210), 248 - i * 34, 326 - i * 6, 30 - i * 3, 0.75 - i * 0.12)
    for i in range(4):
        S.box((255, 214, 140), 132 + i * 20 + (22 if i > 1 else 0), 366, 8, 6)
    S.words('WYVERN SANDS', 'oswald', (214, 234, 230), 30, 26, 500, 82)
    S.words('BY THE NIGHT EXPRESS', 'bodoni', (244, 156, 98), 30, 112, 500, 56)
    S.box((12, 16, 20), 0, 610, 560, 110)
    S.rule((206, 168, 92), 0, 610, 560, 4)
    S.words('S. & W. C. R.', 'oswald', (206, 168, 92), 30, 622, 300, 40, 'left')
    S.words('ALL STOPS TO THE TERMINUS', 'oswald', (146, 158, 166), 330, 630, 200, 26, 'right')
    S.words('Ten stops, one sunrise. Return tickets regrettably unavailable.', 'serif_i', (196, 206, 210), 30, 672, 500, 30, 'left')
    # lithograph grain over the colour
    S.paper(fibre=0.08, mottle=0.1, edge=0.25)
    worn(S, 1)
    return S


def fog():
    S = Sheet(560, 720, PK, (166, 192, 182))
    ink = (30, 36, 40)
    S.paper(fibre=0.06, mottle=0.12, edge=0.22)
    S.outline(ink, 18, 18, 524, 684, 3); S.outline(ink, 28, 28, 504, 664, 1)
    S.words('N O T I C E', 'serif', ink, 60, 52, 440, 34, bold=True)
    S.rule(ink, 200, 96, 160, 2)
    S.words('Mind the Fog', 'gothic', (120, 24, 26), 50, 112, 460, 120)
    S.rule(ink, 120, 252, 130, 2); S.rule(ink, 310, 252, 130, 2); S.box(ink, 272, 245, 16, 16, 45)
    S.words('It is not weather.\nIt has never been weather.', 'serif_i', ink, 70, 278, 420, 92)
    S.box((150, 166, 162), 46, 500, 468, 4)
    for i in range(6):
        x, h = 70 + i * 82, 150 - i * 16
        S.box(ink, x, 500 - h, 6, h, 0, 1 - i * 0.17)
        S.box(ink, x - 18, 500 - h + 12, 42, 5, 0, 1 - i * 0.17)
    for i, y in enumerate((430, 456, 478), 1):
        S.fade_box((226, 236, 236), 46, y, 468, 40 - i * 6, [(0, 0.95), (0.5, 0.25 + i * 0.1), (1, 0.05)], vertical=False, soft=8)
    S.rule(ink, 60, 560, 440, 1)
    S.words('Passengers seeing the fog approach a stopping train will return to it at once and will not wait to be told.', 'serif', ink, 60, 572, 440, 64)
    S.words('BYE-LAW 7', 'serif', ink, 60, 652, 160, 22, 'left', bold=True)
    S.words('By Order · The Line Superintendent', 'serif_i', ink, 220, 652, 280, 22, 'right')
    S.foxing(26)
    return S


def coal():
    S = Sheet(560, 720, PK, (164, 136, 96))
    ink, red = (26, 22, 20), (132, 34, 30)
    S.paper(fibre=0.07, mottle=0.12, edge=0.25)
    S.outline(ink, 16, 16, 528, 688, 4)
    S.words('SEVERN & WESTERN COUNTIES RAILWAY', 'serif', ink, 40, 34, 480, 26, bold=True)
    S.rule(ink, 40, 68, 480, 2)
    S.words('WANTED', 'oswald', red, 40, 76, 480, 108)
    S.words(PREMISE['Wanted'], 'bodoni', ink, 40, 188, 480, 62)
    S.words(PREMISE['For'], 'serif_i', ink, 80, 252, 400, 36)
    S.box((150, 122, 84), 140, 304, 280, 170, 0, 0.6)
    # the woodcut, now cut: hatched shading inside each shape
    S.box(ink, 236, 320, 12, 150, -28); S.box(ink, 262, 306, 40, 12, -28); S.box(ink, 180, 420, 70, 52, -28)
    for i, l in enumerate(((200, 452, 40, 12), (260, 446, 54, 38), (330, 450, 44, 20), (380, 456, 34, 60)), 1):
        S.box(ink if i % 2 == 0 else (54, 46, 40), l[0] - l[2] / 2, l[1] - l[2] / 2, l[2], l[2], l[3])
    for j in range(0, 170, 7):  # engraver's hatching across the block
        S.box((120, 96, 66), 140, 304 + j, 280, 1.4, 0, 0.5)
    S.rule(ink, 40, 496, 480, 2)
    S.words(PREMISE['Body'], 'serif', ink, 60, 508, 440, 70, bold=True)
    S.words(PREMISE['Motto'], 'serif_i', red, 40, 584, 480, 30)
    S.rule(ink, 40, 626, 480, 1)
    S.words(PREMISE['Apply'], 'serif', ink, 40, 636, 480, 24)
    S.words('BY ORDER · 1889', 'serif', ink, 40, 664, 480, 22, bold=True)
    worn(S, 1)
    return S


def moon():
    S = Sheet(560, 720, PK, (18, 20, 36))
    S.fade_box((40, 34, 62), 0, 0, 560, 720, [(0, 1), (1, 0)])
    S.disc((196, 56, 46), 280, 300, 330, 0.18)
    S.disc((196, 56, 46), 280, 300, 210)
    for sea in ((240, 266, 54), (316, 330, 40), (300, 250, 24), (250, 340, 30)):
        S.disc((140, 34, 30), *sea, 0.8)
    hill = (8, 8, 12)
    S.box(hill, -60, 470, 420, 300, -9); S.box(hill, 240, 480, 420, 300, 7); S.box(hill, 0, 520, 560, 200)
    for x, h, lean in ((176, 300, 0), (214, 250, 3), (404, 280, -4)):
        S.box(hill, x, 486 - h, 9, h, lean)
        S.disc(hill, x + 4 + lean * 2, 486 - h - 8, 18)
        S.box(hill, x - 9, 486 - h + 30, 4, h * 0.55, lean + 8)
        S.box(hill, x + 14, 486 - h + 30, 4, h * 0.55, lean - 8)
    S.disc((255, 196, 120), 92, 516, 150, 0.22)
    S.box(hill, 88, 516, 8, 170); S.box((255, 206, 140), 80, 500, 24, 26); S.box(hill, 76, 494, 32, 8)
    S.words('NOTICE TO PASSENGERS', 'serif', (196, 206, 214), 30, 24, 500, 30, bold=True)
    S.rule((196, 206, 214), 160, 60, 240, 2)
    S.words('WHEN THE MOON IS RED', 'bodoni', (214, 70, 58), 30, 70, 500, 70)
    S.words('Keep to the lamplight.\nWave at nothing that waves back.', 'serif_i', (196, 206, 214), 40, 616, 480, 56)
    S.words('By Order · S. & W. C. R.', 'serif', (150, 160, 170), 40, 676, 480, 22)
    S.paper(fibre=0.1, mottle=0.12, edge=0.3)
    worn(S, -1)
    return S


for name, fn, corner in (('poster_coast', coast, 1), ('poster_fog', fog, 0), ('poster_coal', coal, 1), ('poster_moon', moon, -1)):
    S = fn()
    c, h = S.finish(name)
    save(name, c, h, 0.8)
    MANIFEST[name] = dict(tex=name, rect=[0, 0, 1, 1], size=[7, 9], kind='poster', corner=corner)


# ---------------------------------------------------------------- the notice board's bills (1.55 x 2.30) and Tom (1.3 x 1.7)
BILLS = [
    ('MISSING', 'Ellen Venn, aged 9.\nLast seen in Church Lane\non Tuesday evening.\nApply W. Venn, Butcher.'),
    ("ST. MICHAEL'S", 'Evensong at Six.\nSermon: On the Thinning.\nAll are earnestly\nentreated to attend.'),
    ('NOTICE', 'The 9.40 up train\nwill not run until\nfurther notice.\nBy Order.'),
    ('LOST', 'A grey mare, from\nthe Upper Field.\nShe would not\ncome to the bridle.'),
    ('NOTICE', 'Persons are requested\nnot to walk the line\nafter dark.\nBy Order.'),
]
atlas = Image.new('RGB', (1024, 1024), (40, 36, 30)); ah = Image.new('L', (1024, 1024), 128)
CW, CH = 336, 500
for i, (title, body) in enumerate(BILLS + [('TOM', None)]):
    cx, cy = (i % 3) * 341, (i // 3) * 512
    if title == 'TOM':
        tw, th = 336, int(336 * 1.7 / 1.3)
        S = Sheet(tw, th, 1, (196, 186, 160))
        S.paper(0.05, 0.1, 0.2)
        for y in range(40, th, 22):  # a ruled pad page, faint blue lines
            S.box((120, 140, 170), 0, y, tw, 1.2, 0, 0.5)
        S.box((170, 70, 60), 40, 0, 1.5, th, 0, 0.5)
        S.words('HAVE YOU SEEN TOM?', 'hand', (40, 52, 98), 26, 60, 290, 300, press=False)
        S.stain(250, 330, 70, 0.12)
        size = [1.3, 1.7]
    else:
        tw, th = CW, CH
        S = Sheet(tw, th, 1, (206, 190, 150))
        S.paper(0.07, 0.12, 0.28)
        ink = (30, 26, 22)
        S.outline(ink, 10, 10, tw - 20, th - 20, 2)
        S.words(title, 'oswald', (120, 30, 28) if title in ('MISSING', 'LOST') else ink, 22, 26, tw - 44, 90)
        S.rule(ink, 40, 124, tw - 80, 2)
        S.words(body, 'guru', ink, 26, 140, tw - 52, 300)
        S.stain(RNG.uniform(60, 280), RNG.uniform(300, 460), RNG.uniform(50, 110), 0.14)
        S.foxing(14)
        size = [1.55, 2.3]
    c, h = S.finish('bill')
    atlas.paste(c, (cx, cy)); ah.paste(h, (cx, cy))
    MANIFEST[f'bill_{i + 1}' if title != 'TOM' else 'bill_tom'] = dict(
        tex='bills', rect=[cx / 1024, cy / 1024, (cx + c.width) / 1024, (cy + c.height) / 1024], size=size, kind='bill',
        text=title)
save('bills', atlas, ah, 0.8)


# ---------------------------------------------------------------- metal: cast iron, bronze, brass, enamel
MA = Image.new('RGB', (1024, 1024), (20, 20, 20)); MH = Image.new('L', (1024, 1024), 128)
MR = Image.new('L', (1024, 1024), 200); MM = Image.new('L', (1024, 1024), 0)


def metal_panel(name, x, y, w, h, size, text, key, ground, letters, raised=True, metal=True, rim=True, enamel=False,
                rough_ground=170, rough_letters=90, bold=False, kind='plaque'):
    base = Image.new('RGB', (w, h), ground)
    hg = Image.new('L', (w, h), 128)
    # cast or pitted ground
    n = noise(w, h, 60, 1.0)
    mott = big_noise(w, h, max(6, w // 12))
    shade = ImageChops.multiply(n.point(lambda v: 200 + v // 5), mott.point(lambda v: 210 + v // 6))
    base = ImageChops.multiply(base, Image.merge('RGB', (shade, shade, shade)))
    hg = Image.blend(hg, n, 0.15 if not enamel else 0.03)
    if rim:
        r = Image.new('L', (w, h), 0)
        bw = max(4, int(min(w, h) * 0.06))
        ImageDraw.Draw(r).rectangle((bw // 2, bw // 2, w - bw // 2, h - bw // 2), outline=255, width=bw)
        r = r.filter(ImageFilter.GaussianBlur(bw / 4))
        base.paste(letters, (0, 0), r.point(lambda v: v if not enamel else v))
        hg = ImageChops.add(hg, r.point(lambda v: v // 3))
    pad = int(min(w, h) * 0.14)
    m = text_mask((w, h), text, key, (pad, pad * 0.8, w - 2 * pad, h - 1.6 * pad), bold=bold)
    if raised:
        lit = m.filter(ImageFilter.GaussianBlur(1))
        base.paste(letters, (0, 0), lit)
        hg = ImageChops.add(hg, m.filter(ImageFilter.GaussianBlur(1.5)).point(lambda v: v // 3))
    else:  # incised and filled
        base.paste(letters, (0, 0), m)
        hg = ImageChops.subtract(hg, m.filter(ImageFilter.GaussianBlur(1.5)).point(lambda v: v // 3))
    if enamel:
        # chips: black iron with a rust halo, mostly at the edges and the screw holes
        for _ in range(9):
            ex = RNG.choice((RNG.uniform(0, w * 0.08), RNG.uniform(w * 0.92, w), RNG.uniform(0, w)))
            ey = RNG.uniform(0, h) if ex < w * 0.08 or ex > w * 0.92 else RNG.choice((RNG.uniform(0, h * 0.15), RNG.uniform(h * 0.85, h)))
            rr = RNG.uniform(3, 9)
            ImageDraw.Draw(base).ellipse((ex - rr * 1.8, ey - rr * 1.8, ex + rr * 1.8, ey + rr * 1.8), fill=(110, 62, 34))
            ImageDraw.Draw(base).ellipse((ex - rr, ey - rr, ex + rr, ey + rr), fill=(24, 22, 22))
            ImageDraw.Draw(hg).ellipse((ex - rr, ey - rr, ex + rr, ey + rr), fill=100)
    # soot and verdigris in the low ground, the high letters rubbed bright
    dirt = ImageOps.invert(hg).point(lambda v: max(0, v - 128) * 2).filter(ImageFilter.GaussianBlur(2))
    base.paste((30, 36, 30) if metal else (20, 18, 18), (0, 0), dirt.point(lambda v: v // 3))
    MA.paste(base, (x, y)); MH.paste(hg, (x, y))
    rough = Image.new('L', (w, h), rough_ground)
    rough.paste(rough_letters, (0, 0), m)
    MR.paste(rough, (x, y))
    MM.paste(Image.new('L', (w, h), 255 if metal else 0), (x, y))
    MANIFEST[name] = dict(tex='metal', rect=[x / 1024, y / 1024, (x + w) / 1024, (y + h) / 1024], size=size, kind=kind)


metal_panel('notice_iron', 0, 0, 640, 338, [3.6, 1.9], 'NOTICE.\nPASSENGERS MUST NOT\nCROSS THE LINE.\nBY ORDER  1884', 'bodoni',
            (30, 30, 32), (214, 204, 176), metal=False, rough_ground=200, rough_letters=150, kind='iron')
metal_panel('plaque_kept_lit', 650, 0, 352, 192, [1.1, 0.6], 'KEPT LIT BY THOSE WHO WENT BEFORE', 'serif',
            (150, 118, 62), (40, 30, 18), raised=False, rough_ground=80, rough_letters=200, bold=True)
metal_panel('plaque_temperance', 650, 210, 352, 154, [1.6, 0.7], 'TEMPERANCE\nSOCIETY 1868', 'guru',
            (40, 40, 42), (190, 150, 80), metal=False, rough_ground=190, rough_letters=110, kind='iron')
metal_panel('plaque_subscription', 0, 350, 384, 227, [2.2, 1.3], 'ERECTED BY\nPUBLIC SUBSCRIPTION\nMDCCCLXXIX', 'guru',
            (66, 56, 34), (214, 184, 118), rough_ground=170, rough_letters=60)
metal_panel('enamel_no_passengers', 0, 880, 1024, 113, [5.6, 0.62], 'NO PASSENGERS BEYOND THIS POINT', 'oswald',
            (24, 40, 92), (232, 230, 220), raised=False, metal=False, enamel=True, rough_ground=40, rough_letters=40,
            kind='enamel')
save('metal', MA, MH, 1.2, {'rough': MR, 'metal': MM})


# ---------------------------------------------------------------- stone: the board school's date stone, the Jubilee die
SA = Image.new('RGB', (1024, 1024), (120, 116, 108)); SH = Image.new('L', (1024, 1024), 128)


def stone(name, x, y, w, h, size, text, key, ground, fill):
    base = Image.new('RGB', (w, h), ground)
    grain = noise(w, h, 90, 0.8)
    speck = noise(w, h, 120).point(lambda v: 255 if v > 200 else 0)
    big = big_noise(w, h, max(8, w // 8))
    sh = ImageChops.multiply(grain.point(lambda v: 190 + v // 4), big.point(lambda v: 200 + v // 5))
    base = ImageChops.multiply(base, Image.merge('RGB', (sh, sh, sh)))
    base.paste((60, 58, 56), (0, 0), speck.point(lambda v: v // 3))
    hg = Image.blend(Image.new('L', (w, h), 128), grain, 0.35)
    # a sunk panel with a chamfered margin
    m = Image.new('L', (w, h), 0)
    bw = int(min(w, h) * 0.08)
    ImageDraw.Draw(m).rectangle((bw, bw, w - bw, h - bw), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(bw / 3))
    hg = ImageChops.subtract(hg, m.point(lambda v: v // 6))
    pad = int(min(w, h) * 0.16)
    t = text_mask((w, h), text, key, (pad, pad * 0.9, w - 2 * pad, h - 1.8 * pad))
    base.paste(fill, (0, 0), t)
    hg = ImageChops.subtract(hg, t.filter(ImageFilter.GaussianBlur(1.2)).point(lambda v: v // 2))
    # lichen and rain streaks below the letters
    lich = big_noise(w, h, max(4, w // 30)).point(lambda v: 255 if v > 205 else 0).filter(ImageFilter.GaussianBlur(2))
    base.paste((112, 118, 74), (0, 0), lich.point(lambda v: v // 3))
    streak = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(streak)
    for _ in range(int(w / 12)):
        sx = RNG.uniform(0, w)
        d.line((sx, RNG.uniform(0, h * 0.5), sx + RNG.uniform(-3, 3), h), fill=RNG.randint(20, 60), width=RNG.randint(2, 6))
    base.paste((50, 48, 44), (0, 0), streak.filter(ImageFilter.GaussianBlur(3)))
    SA.paste(base, (x, y)); SH.paste(hg, (x, y))
    MANIFEST[name] = dict(tex='stone', rect=[x / 1024, y / 1024, (x + w) / 1024, (y + h) / 1024], size=size, kind='stone')


stone('datestone_ashgrove', 0, 0, 1024, 384, [6.4, 2.4], 'ASHGROVE SCHOOL BOARD\nA.D. 1876', 'garamond', (150, 120, 96), (60, 44, 36))
stone('jubilee_die', 0, 400, 512, 478, [3.0, 2.8], 'V.R.\n1837 - 1887\nJUBILEE', 'guru', (110, 108, 106), (214, 204, 184))
save('stone', SA, SH, 1.2)


# ---------------------------------------------------------------- chalk: the school boards and the tea room's menu
CHALK = [
    'DO NOT OPEN THE DOORS AFTER DARK',
    'Lessons are cancelled.\nGo home. Go HOME.',
    '9 x 7 = 63\nthe train comes at midnight',
    'Count heads at every stop.\nCount them twice.',
    'Who is sitting in the back row?',
]


def chalkboard(name, w, h, text, slate, size, menu=False):
    S = Sheet(w, h, 1, slate)
    W, H = w, h
    n = noise(W, H, 40, 0.7)
    mot = big_noise(W, H, max(10, W // 9))
    sh = ImageChops.multiply(n.point(lambda v: 225 + v // 8), mot.point(lambda v: 225 + v // 9))
    S.img = ImageChops.multiply(S.img, Image.merge('RGB', (sh, sh, sh)))
    # ghosts of earlier lessons, and the eraser's sweeps
    for _ in range(5):
        g = text_mask((W, H), RNG.choice(['ab cd ef gh', '12 + 7 = 19', 'Psalm 121', 'cat  mat  hat', 'Kings of England']),
                      'hand', (RNG.uniform(0, W * 0.5), RNG.uniform(0, H * 0.7), W * 0.5, H * 0.25))
        S.img.paste((200, 204, 196), (0, 0), g.filter(ImageFilter.GaussianBlur(5)).point(lambda v: v // 18))
    sweep = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(sweep)
    for _ in range(7):
        y0 = RNG.uniform(0, H)
        d.line((RNG.uniform(-50, W * 0.3), y0, RNG.uniform(W * 0.6, W + 50), y0 + RNG.uniform(-40, 40)), fill=40, width=int(H * 0.12))
    S.img.paste((190, 196, 188), (0, 0), sweep.filter(ImageFilter.GaussianBlur(H * 0.04)).point(lambda v: v // 3))
    # the writing: chalk breaks up on the slate's tooth
    if menu:
        m = text_mask((W, H), text.split('\n')[0], 'hand', (W * 0.08, H * 0.05, W * 0.84, H * 0.2))
        lines = text.split('\n')[1:]
        for i, l in enumerate(lines):
            m = ImageChops.lighter(m, text_mask((W, H), l, 'hand', (W * 0.08, H * (0.3 + i * 0.16), W * 0.84, H * 0.13), 'left'))
    else:
        m = text_mask((W, H), text, 'hand', (W * 0.05, H * 0.1, W * 0.9, H * 0.8))
    tooth = noise(W, H, 110).point(lambda v: 255 if v > 95 else 0)
    m = ImageChops.multiply(m, tooth).filter(ImageFilter.GaussianBlur(0.7))
    S.img.paste((226, 226, 214), (0, 0), m.point(lambda v: int(v * 0.88)))
    # dust gathered along the ledge
    S.fade_box((210, 210, 200), 0, H * 0.86, W, H * 0.14, [(0, 1), (1, 0.75)])
    S.img.save(OUT / f'{name}_color.png')
    MANIFEST[name] = dict(tex=name, rect=[0, 0, 1, 1], size=size, kind='chalk')


for i, t in enumerate(CHALK, 1):
    chalkboard(f'chalk_{i}', 1024, 410, t, (36, 50, 42), [9, 3.6])
chalkboard('chalk_tearoom', 1024, 768,
           'TEA ROOM\nTea ............ 1d\nHot soup ........ 2d\nA kind word ..... free\nCourage .. ask Mrs. Pell',
           (34, 38, 36), [8, 6], menu=True)


# ---------------------------------------------------------------- framed texts: three samplers, two printed cards (1.86 x 1.26)
DA = Image.new('RGB', (1024, 1024), (200, 190, 160)); DH = Image.new('L', (1024, 1024), 128)
DECOR = [
    ('THOU GOD\nSEEST ME', 'sampler'),
    ('BY ORDER.\nPassengers must not\ncross the line\nexcept by the bridge.', 'card'),
    ('PRAY FOR THEM\nTHAT TRAVEL\nBY NIGHT', 'sampler'),
    ('LOST PROPERTY\nis to be claimed\nwithin seven days.\nBy Order.', 'card'),
    ('THE NIGHT IS\nFAR SPENT', 'sampler'),
]
PW, PH = 480, 325
for i, (text, kind) in enumerate(DECOR):
    x, y = (i % 2) * 512, (i // 2) * 340
    if kind == 'sampler':
        # cross stitch on linen: the motto stitched cell by cell, a border of stitched vine
        img = Image.new('RGB', (PW, PH), (214, 200, 168))
        weave = Image.new('L', (PW, PH), 128)
        d = ImageDraw.Draw(img); dw = ImageDraw.Draw(weave)
        for gx in range(0, PW, 3):
            dw.line((gx, 0, gx, PH), fill=150); d.line((gx, 0, gx, PH), fill=(206, 192, 160))
        for gy in range(0, PH, 3):
            dw.line((0, gy, PW, gy), fill=110)
        cell = 4
        gw, gh = PW // cell, PH // cell
        big = text_mask((gw * 8, gh * 8), text, 'oswald', (48, 48, gw * 8 - 96, gh * 8 - 96))
        small = big.resize((gw, gh), Image.BOX)
        thread = [(110, 30, 34), (40, 60, 44), (36, 40, 80)][i % 3]
        for cy in range(gh):
            for cx in range(gw):
                border = cx in (2, gw - 3) or cy in (2, gh - 3)
                vine = (cx in (1, gw - 2) or cy in (1, gh - 2)) and (cx + cy) % 4 == 0
                on = small.getpixel((cx, cy)) > 100
                if on or border or vine:
                    col = thread if on else ((150, 120, 60) if border else (60, 90, 50))
                    px, py = cx * cell, cy * cell
                    d.line((px, py, px + cell - 1, py + cell - 1), fill=col, width=2)
                    d.line((px + cell - 1, py, px, py + cell - 1), fill=tuple(int(c * 1.15) for c in col), width=2)
                    dw.line((px + 1, py + 1, px + cell - 2, py + cell - 2), fill=220, width=2)
                    dw.line((px + cell - 2, py + 1, px + 1, py + cell - 2), fill=230, width=2)
        # age: the linen yellowed toward the edges, a few faded stitches
        S = Sheet(PW, PH, 1, (0, 0, 0)); S.img = img
        S.foxing(10)
        img = S.img
        hg = weave.filter(ImageFilter.GaussianBlur(0.6))
    else:
        S = Sheet(PW, PH, 1, (222, 210, 180))
        S.paper(0.06, 0.1, 0.25)
        S.outline((30, 26, 24), 12, 12, PW - 24, PH - 24, 2)
        S.words(text, 'garamond', (30, 26, 24), 36, 30, PW - 72, PH - 60)
        S.foxing(12)
        img, hg = S.finish('card')
    DA.paste(img, (x, y)); DH.paste(hg, (x, y))
    MANIFEST[f'framed_{i + 1}'] = dict(tex='framed', rect=[x / 1024, y / 1024, (x + PW) / 1024, (y + PH) / 1024],
                                       size=[1.86, 1.26], kind=kind, text=text.split('\n')[0])
save('framed', DA, DH, 0.8)

(OUT / 'atlas.json').write_text(json.dumps(MANIFEST, indent=1))
print('signs', len(MANIFEST))
