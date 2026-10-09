"""2D pieces of the ticket-office look, and a clean-up pass over the Blender renders.

    python tools/uiart/make_booth.py assets/ui <roblox fonts dir>

The fonts dir is Roblox's content/fonts (Special Elite and Oswald, SIL Open Font License).
Run after render_booth.py: it flattens the engraved plate's middle so it stretches cleanly.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/ui")
FONTS = Path(sys.argv[2]) if len(sys.argv) > 2 else None
rng = np.random.default_rng(1891)


def tile_noise(h: int, w: int, scale: float, stretch=(1.0, 1.0)) -> np.ndarray:
    """Tileable fractal noise in 0..1; stretch > 1 elongates features along that axis."""
    fy = np.fft.fftfreq(h)[:, None] * stretch[0]
    fx = np.fft.fftfreq(w)[None, :] * stretch[1]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    spectrum = (rng.normal(size=(h, w)) + 1j * rng.normal(size=(h, w))) / f**scale
    spectrum[0, 0] = 0
    n = np.real(np.fft.ifft2(spectrum))
    return (n - n.min()) / (n.max() - n.min())


def save(name: str, rgba: np.ndarray):
    Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA").save(OUT / name)
    print("wrote", OUT / name)


# 1. Engraved plate: the middle (x 96..416) stretches, so keep only its vertical shading
#    there (no lamp glints to smear), and tarnish the whole plate a touch.
plate_path = OUT / "plate_engraved.png"
if plate_path.exists():
    p = np.asarray(Image.open(plate_path).convert("RGBA")).astype(float)
    mid = np.median(p[:, 96:416], axis=1, keepdims=True)
    blend = np.clip((np.abs(np.arange(512) - 256) - 120) / 60, 0, 1)[None, :, None]  # 0 in the middle
    p = p * blend + mid * (1 - blend)
    p[..., :3] *= np.array([0.86, 0.8, 0.72])
    save("plate_engraved.png", p)

# 2. Mahogany grain, dark on alpha, tile 256: long figure along x with fine pores.
S = 256
figure = tile_noise(S, S, 1.8, (6.0, 0.4))
pores = tile_noise(S, S, 0.5, (3.0, 0.5))
grain = np.zeros((S, S, 4))
grain[..., 3] = np.clip(0.15 + 0.45 * np.abs(figure - 0.5) * 2 + 0.2 * (pores > 0.62), 0, 1) * 0.6 * 255
save("grain_wood.png", grain)

# 3. The company's rubber stamp, white on alpha (tint in game), 256: a double ring,
#    the company's name round the rim, COUNTED across the middle, ink that bled and skipped.
if FONTS:
    R = 1024
    im = Image.new("L", (R, R), 0)
    d = ImageDraw.Draw(im)
    c = R / 2
    d.ellipse((24, 24, R - 24, R - 24), outline=255, width=26)
    d.ellipse((150, 150, R - 150, R - 150), outline=255, width=12)
    rim = ImageFont.truetype(str(FONTS / "SpecialElite-Regular.ttf"), 92)
    words = "LAST TRAIN OUT RLY. CO.  *  BOOKING OFFICE  *  "
    for k, ch in enumerate(words):
        a = -90 + k * 360 / len(words)
        glyph = Image.new("L", (130, 130), 0)
        ImageDraw.Draw(glyph).text((65, 65), ch, font=rim, fill=255, anchor="mm")
        glyph = glyph.rotate(-a - 90, resample=Image.BICUBIC)
        r = c - 87  # midway between the two rings
        x = c + np.cos(np.radians(a)) * r - 65
        y = c + np.sin(np.radians(a)) * r - 65
        im.paste(255, (int(x), int(y)), glyph)
    bold = ImageFont.truetype(str(FONTS / "Oswald-Bold.ttf"), 150)
    d.rectangle((190, c - 112, R - 190, c - 98), fill=255)
    d.rectangle((190, c + 98, R - 190, c + 112), fill=255)
    d.text((c, c), "COUNTED", font=bold, fill=255, anchor="mm")
    small = ImageFont.truetype(str(FONTS / "SpecialElite-Regular.ttf"), 64)
    d.text((c, c + 180), "No. 41", font=small, fill=255, anchor="mm")
    d.text((c, c - 180), "PASSENGER", font=small, fill=255, anchor="mm")
    # ink: soften, bleed, then knock out where the rubber did not meet the paper
    ink = np.asarray(im.filter(ImageFilter.GaussianBlur(3))).astype(float) / 255
    skip = tile_noise(R, R, 1.3)
    press = np.linspace(1.0, 0.55, R)[None, :] * np.linspace(1.0, 0.8, R)[:, None]  # heavier on the left
    ink = np.clip((ink - 0.25) * 3, 0, 1) * np.clip((skip - 0.3) * 3.5, 0, 1) * press
    out = np.zeros((R, R, 4))
    out[..., :3] = 255
    out[..., 3] = ink * 255
    Image.fromarray(out.astype(np.uint8), "RGBA").resize((256, 256), Image.LANCZOS).save(OUT / "stamp_company.png")
    print("wrote", OUT / "stamp_company.png")

# 4. Ticket tab, 256x80 (slice the middle 56..200): a smoked, foxed stub with a perforated
#    left edge, a punched hole at the right end and burnt corners. Colour baked in.
W, H = 256, 80
yy, xx = np.mgrid[0:H, 0:W]
base = np.array([164, 130, 88], float)  # tea-stained card, smoked
stain = tile_noise(H, W, 2.2)
fibre = tile_noise(H, W, 0.7, (1.0, 0.25))
rgb = base[None, None, :] * (0.78 + 0.22 * stain[..., None]) * (0.92 + 0.08 * fibre[..., None])
fox = np.clip((stain - 0.72) * 5, 0, 1)
rgb -= fox[..., None] * np.array([20, 34, 40])
edge = np.minimum.reduce([xx, W - 1 - xx, yy, H - 1 - yy]).astype(float)
burn = np.clip(1 - (edge + (fibre - 0.5) * 6) / 9, 0, 1) ** 1.6
rgb = rgb * (1 - burn[..., None] * 0.75) + np.array([40, 22, 12]) * burn[..., None] * 0.75
alpha = np.ones((H, W))
for y0 in range(4, H, 10):  # perforations along the torn left edge
    alpha[(xx - 0) ** 2 + (yy - y0 - 3) ** 2 < 16] = 0
hole = (xx - 226) ** 2 + (yy - H / 2) ** 2
alpha[hole < 64] = 0  # the clerk's punch
rgb[(hole >= 64) & (hole < 110)] *= 0.55  # crushed fibre round the hole
alpha[edge < 1] = 0.6
save("ticket_tab.png", np.dstack([rgb, alpha * 255]))
