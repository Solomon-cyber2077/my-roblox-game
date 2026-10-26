"""Candidate Stoker v2 classic clothing textures; leaves uploaded Stoker assets untouched."""
from pathlib import Path
import random
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2] / "assets" / "crew-clothing" / "stoker-v2"
TORSO = {"front": (231, 74, 128, 128), "back": (427, 74, 128, 128),
         "right": (165, 74, 64, 128), "left": (361, 74, 64, 128),
         "up": (231, 8, 128, 64), "down": (231, 204, 128, 64)}
LIMBS = [(217, 355), (85, 355), (19, 355), (151, 355), (308, 355),
         (440, 355), (374, 355), (506, 355)]
OLIVE, TAN, LEATHER, BRASS, CHARCOAL = (72, 82, 59), (183, 156, 112), (125, 78, 45), (190, 145, 62), (38, 39, 38)

def shade(c, n): return tuple(max(0, min(255, x + n)) for x in c)

def panel(size, color, seed):
    rng = random.Random(seed); im = Image.new("RGBA", size, (*color, 255)); p = im.load()
    for y in range(size[1]):
        for x in range(size[0]):
            n = rng.randint(-3, 3); p[x, y] = (*shade(color, n), 255)
    return im

def draw_face(kind, size, pants=False):
    im = panel(size, CHARCOAL if pants else OLIVE, kind + str(pants)); d = ImageDraw.Draw(im); w, h = size
    if pants:
        d.rectangle((0, int(h*.76), w, h), fill=(54, 38, 29)); d.line((0, int(h*.76), w, int(h*.76)), fill=LEATHER, width=2)
        d.line((w//2, 12, w//2-3, int(h*.67)), fill=shade(CHARCOAL, -14), width=2)
        d.line((8, int(h*.48), w-8, int(h*.48)), fill=shade(CHARCOAL, 18), width=1)
        d.line((10, int(h*.51), w-10, int(h*.51)), fill=shade(CHARCOAL, -12), width=1)
        d.rounded_rectangle((8, int(h*.24), w-8, int(h*.42)), radius=4, outline=shade(CHARCOAL, 16), width=2)
        d.line((8, int(h*.42), w-8, int(h*.42)), fill=shade(CHARCOAL, -16), width=1)
        d.line((7, int(h*.89), w-7, int(h*.89)), fill=(104, 71, 46), width=2)
        for x in range(12, w-8, 12): d.line((x, int(h*.80), x+5, int(h*.86)), fill=(76, 54, 38), width=1)
        return im
    if kind == "front":
        # Broad tan collar over a strong olive chore jacket; one readable leather apron.
        d.polygon([(35, 0), (93, 0), (64, 44)], fill=TAN)
        d.line((35, 1, 64, 44, 93, 1), fill=shade(TAN, -22), width=2)
        d.rectangle((27, 38, 101, 127), fill=LEATHER)
        d.line((27, 38, 101, 38), fill=BRASS, width=3)
        d.rounded_rectangle((38, 67, 90, 111), radius=7, fill=shade(LEATHER, -18), outline=(145, 117, 78), width=2)
        d.line((64, 70, 64, 108), fill=shade(TAN, 18), width=2)
        d.line((42, 102, 86, 102), fill=shade(LEATHER, 22), width=2)
        for x in (34, 94):
            d.rectangle((x-5, 40, x+5, 127), fill=OLIVE); d.line((x, 42, x, 123), fill=shade(OLIVE, -18), width=2)
            d.ellipse((x-4, 42, x+4, 50), fill=BRASS)
        d.rectangle((7, 78, 28, 104), fill=shade(OLIVE, -16), outline=TAN, width=2)
    elif kind == "back":
        d.line((64, 5, 64, 118), fill=shade(OLIVE, -18), width=3)
        # Cross-back leather harness and a waist belt keep the apron functional.
        d.line((39, 0, 86, 116), fill=LEATHER, width=10)
        d.line((89, 0, 42, 116), fill=shade(LEATHER, -12), width=10)
        d.rectangle((28, 104, 100, 119), fill=LEATHER)
        d.line((28, 104, 100, 104), fill=BRASS, width=2)
    elif kind in ("right", "left"):
        d.rectangle((7, 72, w-7, 105), fill=LEATHER, outline=TAN, width=2)
        d.line((7, 72, w-7, 72), fill=BRASS, width=2)
    elif kind == "sleeve":
        d.rectangle((0, 99, w, h), fill=shade(OLIVE, -18)); d.line((0, 99, w, 99), fill=BRASS, width=3)
        d.line((5, 96, w-5, 96), fill=shade(OLIVE, -28), width=2)
        d.line((5, 102, w-5, 102), fill=shade(OLIVE, -20), width=2)
        d.rounded_rectangle((10, 48, w-10, 82), radius=5, outline=shade(OLIVE, -16), width=2)
        for y in (55, 64, 73): d.line((16, y, 27, y-5), fill=shade(OLIVE, 10), width=1)
    else:
        d.rectangle((0, 0, w, h), fill=shade(OLIVE, -8))
    return im

def worn(im):
    mask = Image.new("L", im.size, 0); d = ImageDraw.Draw(mask); rng = random.Random(19)
    for _ in range(100):
        x, y = rng.randrange(im.width), rng.randrange(im.height); r = rng.randrange(1, 7); d.ellipse((x-r, y-r, x+r, y+r), fill=rng.randrange(15, 65))
    result = Image.composite(Image.new("RGBA", im.size, (32, 29, 25, 255)), im, mask.filter(ImageFilter.GaussianBlur(2)))
    result.putalpha(im.getchannel("A"))
    return result

def build():
    ROOT.mkdir(parents=True, exist_ok=True)
    for pants in (False, True):
        sheet = Image.new("RGBA", (585, 559), (0, 0, 0, 0))
        for side, box in TORSO.items():
            p = draw_face(side, (box[2], box[3]), pants)
            if not pants:
                sheet.paste(p, box[:2]); p.save(ROOT / f"torso-{side}.png")
        for i, (x, y) in enumerate(LIMBS):
            p = draw_face("sleeve", (64, 128), pants); sheet.paste(p, (x, y))
            if i == 0: p.save(ROOT / ("pants-limb.png" if pants else "shirt-limb.png"))
        # Roblox's upper/lower limb caps are part of the classic template.
        for x, y in ((217, 289), (308, 289), (217, 485), (308, 485)):
            cap = panel((64, 64), (54, 38, 29) if pants else OLIVE, "cap" + str(pants) + str(x))
            sheet.paste(cap, (x, y))
        sheet.save(ROOT / ("pants-clean.png" if pants else "shirt-clean.png"))
        worn(sheet).save(ROOT / ("pants-worn.png" if pants else "shirt-worn.png"))
    atlas = Image.new("RGB", (256, 64)); d = ImageDraw.Draw(atlas)
    for i, c in enumerate((OLIVE, LEATHER, BRASS, (45, 42, 40))): d.rectangle((i*64, 0, i*64+63, 63), fill=c)
    atlas.save(ROOT / "hat-atlas.png")

if __name__ == "__main__": build()
