"""
Paints a car's name board: gilt sign-writing on a dark ground, hand-lettered serif with a
shaded edge and a fine keyline, as a sign-writer would do it in gold leaf.

  python tools/trainshell/make_sign.py "CREW SALOON" out.png <fonts_dir>

The image stands for a 13-stud board (2048 x 128): the board's UVs take the middle of it in
proportion to their length, so shorter boards show the same letters at the same size.
"""

import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

text, out, fonts = sys.argv[1], sys.argv[2], sys.argv[3]
W, H = 2048, 128
rng = np.random.default_rng(7)

# ground: near-black brown with grain and grime
ground = np.zeros((H, W, 3), np.float32) + np.array([30, 24, 20], np.float32)
grain = rng.normal(0, 1, (H // 4, W // 2)).astype(np.float32)
grain = np.array(Image.fromarray(((grain * 20) + 128).clip(0, 255).astype(np.uint8)).resize((W, H), Image.BILINEAR), np.float32) - 128
ground += grain[..., None] * 0.18
img = Image.fromarray(ground.clip(0, 255).astype(np.uint8))

font = ImageFont.truetype(f"{fonts}/Merriweather-Regular.ttf", 92)
d = ImageDraw.Draw(img)
spaced = "  ".join(text.split(" "))
bbox = d.textbbox((0, 0), spaced, font=font, stroke_width=2)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
x, y = (W - tw) // 2 - bbox[0], (H - th) // 2 - bbox[1] - 2

mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).text((x, y), spaced, font=font, fill=255, stroke_width=2, stroke_fill=255)
m = np.array(mask, np.float32) / 255
# drop shade down-right in dark red (the sign-writer's shading)
shade = np.roll(np.roll(m, 4, 0), 4, 1)
base = np.array(img, np.float32)
base = base * (1 - shade[..., None] * 0.9) + np.array([70, 18, 14], np.float32) * shade[..., None] * 0.9
# gold leaf: a vertical gradient, a highlight line and worn flecks
yy = np.linspace(0, 1, H)[:, None]
gold = np.stack([196 - 60 * yy, 156 - 56 * yy, 84 - 40 * yy], -1) * np.ones((1, W, 1))
fleck = (rng.random((H, W)) < 0.025).astype(np.float32)
fleck = np.array(Image.fromarray((fleck * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)), np.float32) / 255
gold = gold * (1 - 0.55 * fleck[..., None])
base = base * (1 - m[..., None]) + gold * m[..., None]
# keyline: a thin gilt rule inset round the board
k = np.zeros((H, W), np.float32)
k[10:12, 24:-24] = k[-12:-10, 24:-24] = 1
k[10:-10, 24:26] = k[10:-10, -26:-24] = 1
base = base * (1 - k[..., None] * 0.8) + np.array([160, 124, 64], np.float32) * k[..., None] * 0.8
Image.fromarray(base.clip(0, 255).astype(np.uint8)).save(out)
print("sign", out, tw, th)
