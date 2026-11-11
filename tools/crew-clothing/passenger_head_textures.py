"""One 1024 atlas for the hall passengers' sculpted hair, whiskers, hats and coat pieces
(passenger_heads.py). A 6 x 6 grid of cells; cell k sits at column k % 6, row k // 6 from the top.
Hair cells run their strands along v (root at the top of the cell, tip at the bottom), which is how
the lock tubes are unwrapped. Run with Python + Pillow, then Blender --background --python
passenger_heads.py. Output: $PASSENGER_OUT/heads.png.
References (period types, looked at, nothing traced or embedded): 1890s men's side-parted and
swept-back cuts, full beards and chin curtains, women's centre-parted bands and low buns, bowlers,
silk top hats, railway porters' peaked caps, eight-panel flat caps, poke bonnets with ribbon ties,
mourning crape veils, knitted shawls, cotton neckerchiefs.
"""
import os, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, str(Path(__file__).resolve().parent))
from textures import adjust
from mabel_textures import weave

OUT = Path(os.environ.get('PASSENGER_OUT', Path(__file__).resolve().parents[2] / 'assets/crew-clothing/passengers-r6'))
N, C = 6, 1024 // 6  # cells per side, cell size in px

HAIR = {0: (70, 52, 40), 1: (98, 66, 46), 2: (150, 146, 140), 3: (40, 32, 28), 4: (168, 164, 160), 5: (150, 96, 54)}
CELLS = {
    6: ('felt', (30, 28, 28)), 7: ('plush', (22, 22, 24)), 8: ('silk', (52, 30, 36)), 9: ('cloth', (26, 32, 48)),
    10: ('tweed', (84, 76, 64)), 11: ('crape', (20, 18, 22)), 12: ('patent', (14, 14, 16)), 13: ('brass', (176, 138, 66)),
    14: ('grosgrain', (18, 16, 18)), 15: ('cloth', (30, 32, 36)), 16: ('cloth', (64, 60, 56)), 17: ('cloth', (30, 40, 62)),
    18: ('cloth', (70, 40, 50)), 19: ('knit', (30, 28, 32)), 20: ('spots', (120, 30, 26)), 21: ('silk', (196, 170, 120)),
    22: ('cloth', (16, 14, 14)), 23: ('felt', (40, 36, 34)),
}

def hair(color, seed):
    im = Image.new('RGB', (C, C), adjust(color, -10)); d = ImageDraw.Draw(im); rng = random.Random(seed)
    for _ in range(1500):
        x = rng.uniform(0, C); y = rng.uniform(-20, C); l = rng.uniform(25, 90)
        col = adjust(color, rng.choice((-30, -18, -8, 4, 14, 26)))
        if color[0] > 120 and rng.random() < .06:
            col = (226, 222, 216)  # silver threads in the grey
        d.line((x, y, x + rng.uniform(-4, 4), y + l), fill=col, width=1)
    for x in range(0, C, 14):  # clump grooves: darker valleys between locks
        d.line((x + rng.uniform(-2, 2), 0, x + rng.uniform(-3, 3), C), fill=adjust(color, -38 - (20 if color[0] > 140 else 0)), width=2)
    im = im.filter(ImageFilter.GaussianBlur(.6))
    # root shadow at the top of the cell, sheen band a third of the way down
    px = im.load()
    for y in range(C):
        k = -26 * max(0, 1 - y / (C * .25)) + 16 * max(0, 1 - abs(y - C * .38) / (C * .1))
        for x in range(C):
            r, g, b = px[x, y]; px[x, y] = (max(0, min(255, int(r + k))), max(0, min(255, int(g + k))), max(0, min(255, int(b + k))))
    return im

def fabric(kind, color, seed):
    rng = random.Random(seed)
    if kind in ('cloth', 'felt'):
        im = weave((C, C), color, seed, amp=5 if kind == 'cloth' else 3, twill=kind == 'cloth').convert('RGB')
        if kind == 'felt':
            im = im.filter(ImageFilter.GaussianBlur(1.2))
        return im
    im = Image.new('RGB', (C, C), color); d = ImageDraw.Draw(im)
    if kind == 'plush':  # silk plush: fine nap with a soft vertical sheen
        for x in range(C):
            k = int(22 * max(0, 1 - abs(x - C * .35) / (C * .18)))
            d.line((x, 0, x, C), fill=adjust(color, k + rng.choice((-3, 0, 3))))
    elif kind == 'silk':
        for y in range(C):
            k = int(28 * max(0, 1 - abs(y - C * .4) / (C * .25)))
            d.line((0, y, C, y), fill=adjust(color, k - 6))
        for _ in range(60):
            y = rng.uniform(0, C); d.line((0, y, C, y + rng.uniform(-6, 6)), fill=adjust(color, rng.choice((-14, 10))))
    elif kind == 'tweed':  # herringbone in flecked wool
        for y in range(0, C, 4):
            for x in range(0, C, 8):
                up = (x // 8) % 2
                d.line((x, y + (4 if up else 0), x + 8, y + (0 if up else 4)), fill=adjust(color, rng.choice((-18, -8, 8, 16))), width=2)
        for _ in range(500):
            x, y = rng.uniform(0, C), rng.uniform(0, C)
            d.point((x, y), fill=rng.choice(((120, 60, 40), (60, 70, 50), (150, 140, 120))))
    elif kind == 'crape':  # crinkled matte mourning crape
        for _ in range(900):
            x, y = rng.uniform(0, C), rng.uniform(0, C)
            d.line((x, y, x + rng.uniform(-10, 10), y + rng.uniform(4, 16)), fill=adjust(color, rng.choice((-6, 6, 12))), width=1)
    elif kind == 'patent':
        for y in range(C):
            k = int(70 * max(0, 1 - abs(y - C * .3) / (C * .07)) + 25 * max(0, 1 - abs(y - C * .62) / (C * .2)))
            d.line((0, y, C, y), fill=adjust(color, k))
    elif kind == 'brass':
        for _ in range(1200):
            x, y = rng.uniform(0, C), rng.uniform(0, C)
            d.point((x, y), fill=adjust(color, rng.choice((-40, -20, 0, 20, 45))))
        d.ellipse((C * .3, C * .25, C * .7, C * .55), outline=adjust(color, 60), width=3)
    elif kind == 'grosgrain':
        for y in range(0, C, 3):
            d.line((0, y, C, y), fill=adjust(color, 14), width=1)
    elif kind == 'knit':  # stocking-stitch Vs, fringe strands at the bottom fifth
        for y in range(0, int(C * .8), 6):
            for x in range(0, C, 6):
                d.line((x, y, x + 3, y + 5), fill=adjust(color, 16)); d.line((x + 6, y, x + 3, y + 5), fill=adjust(color, 10))
        for x in range(0, C, 3):
            d.line((x, C * .8, x + rng.uniform(-2, 2), C), fill=adjust(color, rng.choice((-8, 8, 18))), width=2)
    elif kind == 'spots':
        for y in range(6, C, 18):
            for x in range(6 + (y // 18 % 2) * 9, C, 18):
                d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(222, 210, 190))
        im = im.filter(ImageFilter.GaussianBlur(.5))
    return im

def main():
    atlas = Image.new('RGB', (1024, 1024), (20, 18, 18))
    for k, color in HAIR.items():
        atlas.paste(hair(color, f'hair{k}'), ((k % N) * C, (k // N) * C))
    for k, (kind, color) in CELLS.items():
        atlas.paste(fabric(kind, color, f'cell{k}'), ((k % N) * C, (k // N) * C))
    OUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT / 'heads.png')
    print('wrote', OUT / 'heads.png')

main()
