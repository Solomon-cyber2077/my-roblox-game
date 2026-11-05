"""Maps for the inner faces of the train's door leaves (tools/train-doors/build.py).

python3 tools/train-doors/textures.py <out dir>

One 1024 atlas; the mesh maps every piece by its place on the leaf, so grain, wear and grime
line up across stiles, panels and rails. Regions (pixels):
  A   0-384   x 0-1024  varnished teak, grain running up      (stiles, panels, mouldings)
  B 384-768   x 0-128   the same teak, grain running across   (rails, ledges)
  C 384-768   x 256-1024 oiled deal planks, grain running up  (the heavy doors)
  D 768-1024  x 0-256   brass                                 (pull, kick plate)
  E 768-1024  x 256-512 black iron                            (straps, bolts, the heavy doors' pull)
Writes door_inside_color/_normal/_rough/_metal.png.
"""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageOps

OUT = Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(1872)
N = 1024
COL = Image.new('RGB', (N, N), (60, 34, 22))
HGT = Image.new('L', (N, N), 128)
ROUGH = Image.new('L', (N, N), 150)
METAL = Image.new('L', (N, N), 0)


def stretched(w, h, sx, sy, blur=0):
    small = Image.effect_noise((max(2, w // sx), max(2, h // sy)), 70).convert('L')
    im = small.resize((w, h), Image.BICUBIC)
    return im.filter(ImageFilter.GaussianBlur(blur)) if blur else im


def grain(w, h, base, dark, across=False, rings=True):
    """Wood: long streaks along the grain, a few rings, open pores; returns colour and height."""
    if across:
        w, h = h, w
    streak = ImageOps.autocontrast(stretched(w, h, 3, 90))
    wide = ImageOps.autocontrast(stretched(w, h, 28, 260, 2))
    t = ImageChops.add(streak.point(lambda v: v // 2), wide.point(lambda v: v // 2))
    if rings:
        rr = Image.new('L', (w, h), 0)
        d = ImageDraw.Draw(rr)
        for _ in range(5):
            cx, cy = RNG.uniform(0, w), RNG.uniform(-h, 2 * h)
            for k in range(8):
                rx = 18 + k * 9
                d.ellipse((cx - rx, cy - rx * 9, cx + rx, cy + rx * 9), outline=90, width=2)
        t = ImageChops.add(t, rr.filter(ImageFilter.GaussianBlur(1.5)).point(lambda v: v // 2))
    pores = Image.effect_noise((w, h), 90).convert('L').point(lambda v: 255 if v > 215 else 0)
    col = Image.composite(Image.new('RGB', (w, h), dark), Image.new('RGB', (w, h), base), t)
    col.paste(tuple(int(c * 0.7) for c in dark), (0, 0), pores.point(lambda v: v // 3))
    # varnish fills the grain: only a faint pore and figure relief comes through
    hgt = ImageChops.subtract(Image.new('L', (w, h), 140), pores.filter(ImageFilter.GaussianBlur(0.8)).point(lambda v: v // 40))
    hgt = ImageChops.subtract(hgt, t.filter(ImageFilter.GaussianBlur(1)).point(lambda v: v // 40))
    if across:
        col, hgt = col.transpose(Image.ROTATE_90), hgt.transpose(Image.ROTATE_90)
    return col, hgt


def grime(img, region_h, foot=0.12, finger_y=None, strength=0.5):
    """Darkening at the foot (boots) and a band where hands go (the pull's height)."""
    w, h = img.size
    m = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(m)
    for y in range(h):
        v = 1 - y / h  # row 0 is the top of the leaf
        a = 0
        if v < foot:
            a = (1 - v / foot) * 150
        d.line((0, y, w, y), fill=int(a * strength))
    if finger_y is not None:
        y = int(h * (1 - finger_y))
        for edge in (0, w):
            d.ellipse((edge - w * 0.18, y - h * 0.05, edge + w * 0.18, y + h * 0.05), fill=int(70 * strength))
    m = m.filter(ImageFilter.GaussianBlur(14))
    noise = Image.effect_noise((w, h), 80).convert('L').filter(ImageFilter.GaussianBlur(3))
    m = ImageChops.multiply(m, ImageOps.autocontrast(noise).point(lambda v: 120 + v // 2))
    img.paste((20, 14, 10), (0, 0), m)
    return img


# A: teak, grain up. Leaf height 7.6 studs over 1024 px; the pull's middle sits 2.15 up.
c, h = grain(384, 1024, (104, 56, 32), (58, 28, 16))
c = grime(c, 1024, 0.1, finger_y=2.15 / 7.6)
COL.paste(c, (0, 0)); HGT.paste(h, (0, 0)); ROUGH.paste(Image.new('L', (384, 1024), 95), (0, 0))
# B: teak across
c, h = grain(384, 128, (100, 54, 30), (56, 28, 16), across=True)
COL.paste(c, (384, 0)); HGT.paste(h, (384, 0)); ROUGH.paste(Image.new('L', (384, 128), 100), (384, 0))
# C: deal planks, oiled and worked hard
c, h = grain(384, 768, (128, 92, 58), (82, 54, 32), rings=True)
c = grime(c, 768, 0.16, finger_y=2.15 / 7.6, strength=0.8)
spl = Image.effect_noise((384, 768), 90).convert('L').point(lambda v: 255 if v > 236 else 0).filter(ImageFilter.GaussianBlur(1))
c.paste((40, 30, 22), (0, 0), spl)  # oil spots and nail marks
COL.paste(c, (384, 256)); HGT.paste(h, (384, 256)); ROUGH.paste(Image.new('L', (384, 768), 170), (384, 256))
# D: brass, brushed across, tarnished in the low places, bright where touched
br = Image.new('RGB', (256, 256), (178, 138, 70))
lines = stretched(256, 256, 120, 1)
br = ImageChops.multiply(br, Image.merge('RGB', [lines.point(lambda v: 205 + v // 5)] * 3))
tarn = ImageOps.autocontrast(stretched(256, 256, 10, 10, 2)).point(lambda v: 255 if v > 205 else 0).filter(ImageFilter.GaussianBlur(3))
br.paste((96, 78, 44), (0, 0), tarn.point(lambda v: v // 3))
COL.paste(br, (768, 0)); HGT.paste(lines.point(lambda v: 124 + v // 40), (768, 0))
ROUGH.paste(ImageChops.add(Image.new('L', (256, 256), 60), tarn.point(lambda v: v // 3)), (768, 0))
METAL.paste(255, (768, 0, 1024, 256))
# E: black iron with rust where the paint has gone
ir = Image.new('RGB', (256, 256), (36, 34, 32))
rust = ImageOps.autocontrast(stretched(256, 256, 6, 6, 1)).point(lambda v: 255 if v > 215 else 0).filter(ImageFilter.GaussianBlur(1.5))
ir.paste((104, 56, 30), (0, 0), rust.point(lambda v: int(v * 0.6)))
pit = Image.effect_noise((256, 256), 80).convert('L')
COL.paste(ir, (768, 256)); HGT.paste(ImageChops.add(pit.filter(ImageFilter.GaussianBlur(0.8)).point(lambda v: 118 + v // 24), rust.point(lambda v: v // 16)), (768, 256))
ROUGH.paste(ImageChops.add(Image.new('L', (256, 256), 170), rust.point(lambda v: v // 4)), (768, 256))
METAL.paste(Image.new('L', (256, 256), 200), (768, 256))
METAL.paste(Image.new('L', (256, 256), 30), (768, 256), rust)

kx = ImageFilter.Kernel((3, 3), [-1, 0, 1, -2, 0, 2, -1, 0, 1], scale=2, offset=128)
ky = ImageFilter.Kernel((3, 3), [-1, -2, -1, 0, 0, 0, 1, 2, 1], scale=2, offset=128)
normal = Image.merge('RGB', (ImageOps.invert(HGT.filter(kx)), HGT.filter(ky), Image.new('L', (N, N), 255)))
COL.save(OUT / 'door_inside_color.png'); normal.save(OUT / 'door_inside_normal.png')
ROUGH.save(OUT / 'door_inside_rough.png'); METAL.save(OUT / 'door_inside_metal.png')
print('ok')
