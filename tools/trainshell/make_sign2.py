"""
Paints a car's sign atlas (round 2): the name boards and its cast brass plates, laid out by
signs.py from the car's json, with a normal map so the plates' letters stand up.

  python tools/trainshell/make_sign2.py <car.json> "<NAME>" <number> <out_prefix> <fonts_dir>

Writes <out_prefix>_sign.png (colour) and <out_prefix>_signnormal.png. Each board is painted at its
own length: gilt sign-writing (Merriweather, shaded in dark red) between two gilt crests (a crescent
moon over a lamp, the company's mark), a keyline and corner flourishes, so no end of the board is
empty. The builder's plate and the number plate are cast brass with raised letters on a black field.
"""

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import signs  # noqa: E402

meta = json.load(open(sys.argv[1]))
NAME, NUMBER, OUT, FONTS = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
spec = meta["spec"]
rects = signs.layout(spec["labels"])
rng = np.random.default_rng(11)

color = np.zeros((signs.H, signs.W, 3), np.float32) + np.array([24, 20, 17], np.float32)
height = np.zeros((signs.H, signs.W), np.float32)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def gold(h, w):
    yy = np.linspace(0, 1, h)[:, None]
    g = np.stack([206 - 70 * yy, 164 - 64 * yy, 88 - 44 * yy], -1) * np.ones((1, w, 1))
    fleck = (rng.random((h, w)) < 0.02).astype(np.float32)
    fleck = np.asarray(Image.fromarray((fleck * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)), np.float32) / 255
    return g * (1 - 0.5 * fleck[..., None])


def crest(d, cx, cy, r, fill=255):
    """The company's mark: a ring, a crescent moon over a small lamp, two leaves below."""
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=fill, width=max(2, r // 9))
    d.ellipse((cx - r * 0.78, cy - r * 0.78, cx + r * 0.78, cy + r * 0.78), outline=fill, width=max(1, r // 18))
    m = r * 0.42
    d.ellipse((cx - m, cy - r * 0.62, cx + m, cy - r * 0.62 + 2 * m), fill=fill)
    d.ellipse((cx - m + r * 0.18, cy - r * 0.7, cx + m + r * 0.18, cy - r * 0.7 + 2 * m), fill=0)
    lw = r * 0.16
    d.rectangle((cx - lw, cy + r * 0.05, cx + lw, cy + r * 0.42), fill=fill)
    d.polygon([(cx - lw * 1.6, cy + r * 0.05), (cx + lw * 1.6, cy + r * 0.05), (cx, cy - r * 0.1)], fill=fill)
    for s in (-1, 1):
        d.chord((cx + s * r * 0.15 - r * 0.32, cy + r * 0.38, cx + s * r * 0.15 + r * 0.32, cy + r * 0.66), 0, 360, fill=fill)


def board(rect, text):
    x0, y0, x1, y1 = rect
    w, h = x1 - x0, y1 - y0
    # ground: a dark lacquer with a faint grain and grime at the bottom
    grain = rng.normal(0, 1, (h // 3 + 1, w // 2 + 1)).astype(np.float32)
    grain = np.asarray(Image.fromarray(((grain * 18) + 128).clip(0, 255).astype(np.uint8)).resize((w, h), Image.BILINEAR), np.float32) - 128
    ground = np.zeros((h, w, 3), np.float32) + np.array([28, 24, 20], np.float32) + grain[..., None] * 0.2
    ground *= (0.75 + 0.25 * np.linspace(1, 0, h))[:, None, None] ** 0.5
    mask = Image.new("L", (w, h), 0)
    shade = Image.new("L", (w, h), 0)
    d, ds = ImageDraw.Draw(mask), ImageDraw.Draw(shade)
    # keyline and corner flourishes
    k = max(6, h // 14)
    d.rectangle((k, k, w - k - 1, h - k - 1), outline=255, width=2)
    d.rectangle((k + 6, k + 6, w - k - 7, h - k - 7), outline=150, width=1)
    for cx, cy, a in ((k, k, 0), (w - k, k, 90), (w - k, h - k, 180), (k, h - k, 270)):
        rr = h // 5
        d.arc((cx - rr, cy - rr, cx + rr, cy + rr), a, a + 90, fill=255, width=2)
    # crests at both ends, flanked by a short rule, so the board is filled end to end
    r = int(h * 0.3)
    for cx in (int(h * 0.62), int(w - h * 0.62)):
        crest(d, cx, h // 2, r)
        crest(ds, cx + 3, h // 2 + 3, r)
    # the name, as big as the board allows between the crests
    avail = w - 2.6 * h
    size = int(h * 0.56)
    spaced = "  ".join(text.split(" "))
    while size > 10:
        f = font("Merriweather-Regular.ttf", size)
        bb = d.textbbox((0, 0), spaced, font=f, stroke_width=1)
        if bb[2] - bb[0] <= avail:
            break
        size -= 2
    tx = (w - (bb[2] - bb[0])) // 2 - bb[0]
    ty = (h - (bb[3] - bb[1])) // 2 - bb[1]
    d.text((tx, ty), spaced, font=f, fill=255, stroke_width=1, stroke_fill=255)
    ds.text((tx + 4, ty + 4), spaced, font=f, fill=255, stroke_width=1, stroke_fill=255)
    # rules from the crests to the lettering
    lx0, lx1 = int(h * 0.62 + r * 1.25), int(tx - h * 0.12)
    for a, b in ((lx0, lx1), (w - lx1, w - lx0)):
        if b - a > 10:
            d.line((a, h // 2, b, h // 2), fill=255, width=2)
            d.ellipse(((a + b) // 2 - 4, h // 2 - 4, (a + b) // 2 + 4, h // 2 + 4), fill=255)
    m = np.asarray(mask, np.float32) / 255
    sh = np.asarray(shade.filter(ImageFilter.GaussianBlur(1)), np.float32) / 255
    out = ground * (1 - 0.85 * sh[..., None]) + np.array([72, 20, 14], np.float32) * 0.85 * sh[..., None]
    out = out * (1 - m[..., None]) + gold(h, w) * m[..., None]
    # wear: gilt rubbed off in flecks, soot along the top edge
    wear = (rng.random((h, w)) < 0.01).astype(np.float32)
    wear = np.asarray(Image.fromarray((wear * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)), np.float32) / 255
    out = out * (1 - 0.6 * wear[..., None] * m[..., None]) + np.array([40, 30, 24], np.float32) * 0.6 * wear[..., None] * m[..., None]
    soot = np.clip(1 - np.arange(h) / (h * 0.35), 0, 1)[:, None, None] * 0.45
    out = out * (1 - soot)
    color[y0:y1, x0:x1] = out
    height[y0:y1, x0:x1] = m * 0.3


def plate(rect, lines, oval):
    x0, y0, x1, y1 = rect
    w, h = x1 - x0, y1 - y0
    shape = Image.new("L", (w, h), 0)
    ds = ImageDraw.Draw(shape)
    if oval:
        ds.ellipse((0, 0, w - 1, h - 1), fill=255)
    else:
        ds.rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 6, fill=255)
    rim = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(rim)
    b = max(6, h // 12)
    if oval:
        dr.ellipse((0, 0, w - 1, h - 1), fill=255)
        dr.ellipse((b, b, w - 1 - b, h - 1 - b), fill=0)
        dr.ellipse((b + 5, b + 5, w - 6 - b, h - 6 - b), outline=255, width=2)
    else:
        dr.rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 6, fill=255)
        dr.rounded_rectangle((b, b, w - 1 - b, h - 1 - b), radius=h // 8, fill=0)
    let = Image.new("L", (w, h), 0)
    dl = ImageDraw.Draw(let)
    n = len(lines)
    for i, (txt, rel) in enumerate(lines):
        size = int(h * rel)
        f = font("Merriweather-Regular.ttf", size)
        bb = dl.textbbox((0, 0), txt, font=f)
        while bb[2] - bb[0] > w * 0.8 and size > 8:  # long numbers shrink to fit inside the rim
            size -= 2
            f = font("Merriweather-Regular.ttf", size)
            bb = dl.textbbox((0, 0), txt, font=f)
        tw, th = bb[2] - bb[0], bb[3] - bb[1]
        cy = h * (i + 1) / (n + 1)
        dl.text(((w - tw) / 2 - bb[0], cy - th / 2 - bb[1]), txt, font=f, fill=255)
    if oval:
        for sx in (-1, 1):
            cx = w / 2 + sx * w * 0.36
            dl.ellipse((cx - 8, h / 2 - 8, cx + 8, h / 2 + 8), fill=255)
    s = np.asarray(shape, np.float32) / 255
    rm = np.asarray(rim, np.float32) / 255
    lt = np.asarray(let, np.float32) / 255
    raised = np.clip(rm + lt, 0, 1)
    brass = np.array([186, 148, 82], np.float32) * (0.9 + 0.2 * np.linspace(1, 0, h)[:, None, None])
    field = np.array([22, 18, 16], np.float32)
    tarn = np.asarray(Image.fromarray((rng.random((h // 8 + 1, w // 8 + 1)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32)[..., None] / 255
    metal = brass * (0.75 + 0.35 * tarn)
    # the crests of the letters rubbed bright, the field black with green in the corners
    edge = np.asarray(Image.fromarray((raised * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2)), np.float32) / 255
    out = field * (1 - raised[..., None]) + metal * raised[..., None]
    out = out + np.array([40, 34, 20], np.float32) * (raised * (1 - edge) * 2).clip(0, 1)[..., None]
    out = out * (1 - (1 - edge) * 0.25 * (1 - raised))[..., None]
    region = color[y0:y1, x0:x1]
    color[y0:y1, x0:x1] = region * (1 - s[..., None]) + out * s[..., None]
    height[y0:y1, x0:x1] = np.maximum(height[y0:y1, x0:x1], raised * s * 0.8)


for lab in spec["labels"]:
    if lab["label"].startswith("board"):
        board(rects[lab["label"]], NAME)
plate(rects["builders"], [("LAST TRAIN Co.", 0.14), ("WORKS No 214", 0.12), ("1887", 0.12)], True)
plate(rects["number"], [(f"No {NUMBER}", 0.56)], False)
if "nameplate" in rects:
    plate(rects["nameplate"], [(NAME, 0.36), (f"No. {NUMBER}", 0.17)], False)

Image.fromarray(color.clip(0, 255).astype(np.uint8)).save(OUT + "_sign.png")
hb = np.asarray(Image.fromarray((height * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
gy, gx = np.gradient(hb)
k = 6.0
nx, ny, nz = -gx * k, gy * k, np.ones_like(hb)  # OpenGL: +Y up, rows run down
ln = np.sqrt(nx * nx + ny * ny + nz * nz)
nmap = np.dstack([nx / ln, ny / ln, nz / ln]) * 0.5 + 0.5
Image.fromarray((nmap * 255).astype(np.uint8)).save(OUT + "_signnormal.png")
print("sign", OUT, rects)
