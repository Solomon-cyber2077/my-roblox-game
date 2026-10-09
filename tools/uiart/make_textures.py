"""Procedural UI textures for the Blood Moon Mail look (see src/client/UI/Theme.luau).

Every texture is an overlay meant to sit over a coloured Frame, so the hue stays in Theme
and the image only carries grain, stains and light. White-on-alpha images are tinted with
ImageColor3; black-on-alpha images darken whatever is underneath.

    python tools/uiart/make_textures.py assets/ui
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/ui")
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(1887)


def tile_noise(size: int, scale: float) -> np.ndarray:
    """Tileable fractal noise in 0..1, built in frequency space so it wraps."""
    fx = np.fft.fftfreq(size)[:, None]
    fy = np.fft.fftfreq(size)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    spectrum = (rng.normal(size=(size, size)) + 1j * rng.normal(size=(size, size))) / f**scale
    spectrum[0, 0] = 0
    n = np.real(np.fft.ifft2(spectrum))
    return (n - n.min()) / (n.max() - n.min())


def save(name: str, rgba: np.ndarray):
    Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA").save(OUT / name)
    print("wrote", OUT / name)


def mono(alpha: np.ndarray, value: int) -> np.ndarray:
    h, w = alpha.shape
    out = np.zeros((h, w, 4))
    out[..., :3] = value
    out[..., 3] = alpha * 255
    return out


# Paper: fibres, foxing and coal dust, dark on alpha (tile 256).
S = 256
soft = tile_noise(S, 1.6)
fine = tile_noise(S, 0.6)
blotch = tile_noise(S, 2.4)
fox = np.clip((blotch - 0.62) * 4, 0, 1) ** 1.5  # rust-brown foxing spots
grain = np.abs(fine - 0.5) * 2
paper_a = 0.10 + 0.22 * soft + 0.25 * grain**2 + 0.45 * fox
speck = rng.random((S, S)) > 0.9975  # coal dust
paper_a[speck] = 0.85
paper = mono(np.clip(paper_a, 0, 1) * 0.55, 0)
paper[..., 0] += fox * 70  # foxing reads brown, not grey
paper[..., 1] += fox * 30
save("paper_grain.png", paper)

# Iron / leather: hammered mottling, light and dark, on alpha (tile 256).
mott = tile_noise(S, 2.0)
pits = tile_noise(S, 0.9)
iron = np.zeros((S, S, 4))
light = np.clip((mott - 0.55) * 2.2, 0, 1)
dark = np.clip((0.45 - mott) * 2.2, 0, 1) + np.clip((0.3 - pits) * 3, 0, 1) * 0.6
iron[..., :3] = (light / np.maximum(light + dark, 1e-3))[..., None] * 255
iron[..., 3] = np.clip(light * 0.10 + dark * 0.35, 0, 1) * 255
save("iron_grain.png", iron)

# Edge burn: 9-slice (centre 40..88 of 128), transparent middle, ragged darkening edges.
E = 128
yy, xx = np.mgrid[0:E, 0:E] / (E - 1)
edge = np.minimum.reduce([xx, 1 - xx, yy, 1 - yy])  # 0 at border, 0.5 centre
rag = tile_noise(E, 1.4)
burn = np.clip(1 - (edge + (rag - 0.5) * 0.06) / 0.30, 0, 1) ** 2.2
save("edge_burn.png", mono(burn, 255))

# Soft glow: 9-slice white halo for selection and lamp light (centre 48..80).
d = np.maximum(np.abs(xx - 0.5), np.abs(yy - 0.5)) * 2  # 0 centre, 1 edge
glow = np.clip(1 - (d - 0.25) / 0.75, 0, 1) ** 2.4
save("glow.png", mono(glow, 255))

# Stamp grunge: paper-coloured knock-outs laid over rubber-stamp ink (tile 256).
g1 = tile_noise(S, 1.1)
g2 = rng.random((S, S))
grunge = np.clip((g1 - 0.58) * 5, 0, 1) * 0.9 + (g2 > 0.93) * 0.8
img = Image.fromarray((np.clip(grunge, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
save("stamp_grunge.png", mono(np.asarray(img) / 255, 255))

# Panel vignette: radial, dark corners, transparent centre (stretched, 256).
V = 256
vy, vx = np.mgrid[0:V, 0:V] / (V - 1) - 0.5
r = np.sqrt(vx * vx + vy * vy) / 0.7071
vig = np.clip((r - 0.35) / 0.65, 0, 1) ** 1.6
save("vignette.png", mono(vig, 255))

# Perforation bite: one punched hole, white disc on alpha with a soft rim (32).
P = 32 * 4
im = Image.new("L", (P, P), 0)
ImageDraw.Draw(im).ellipse((10, 10, P - 10, P - 10), fill=255)
im = im.filter(ImageFilter.GaussianBlur(3)).resize((32, 32), Image.LANCZOS)
save("punch.png", mono(np.asarray(im) / 255, 255))

# Post: the enamel plate is tinted per style in game, so strip the lamp's warmth from the render.
plate = OUT / "enamel_plate.png"
if plate.exists():
    p = np.asarray(Image.open(plate).convert("RGBA")).astype(float)
    lum = p[..., :3] @ [0.299, 0.587, 0.114]
    p[..., :3] = (lum / max(lum[p[..., 3] > 0].max(), 1) * 255)[..., None]
    save("enamel_plate.png", p)


# Composite 9-slice materials (256px, slice centre 64..192). The panel's fill colour comes from
# BackgroundColor3 underneath, so these carry only shading, wear and the brass rim.
def composite_9slice(name: str, layers):
    out = np.zeros((256, 256, 4))
    for rgba in layers:
        a = rgba[..., 3:4] / 255
        out[..., :3] = rgba[..., :3] * a + out[..., :3] * (1 - a)
        out[..., 3:4] = (a + out[..., 3:4] / 255 * (1 - a)) * 255
    save(name, out)


N = 256
ny, nx = np.mgrid[0:N, 0:N] / (N - 1)
border = np.minimum.reduce([nx, 1 - nx, ny, 1 - ny]) * N  # px from the edge
low = tile_noise(N, 2.6)
grit = tile_noise(N, 0.8)
in_border = np.clip(1 - (border - 56) / 8, 0, 1)  # fine grain only where 9-slice keeps it 1:1

# Iron/lacquer panel: mottled shading, darkened rim (inner shadow), hairline highlight, brass frame.
shade = 0.12 + 0.16 * low + in_border * 0.12 * np.abs(grit - 0.5) * 2
shade += np.clip(1 - (border - 34) / 26, 0, 1) ** 1.8 * 0.55  # inner shadow inside the brass
hair = ((border >= 37) & (border < 38.5)).astype(float) * 0.22  # lamp catching the inner bevel
dark_layer = mono(np.clip(shade, 0, 1), 0)
light_layer = mono(hair * (ny < 0.5), 255)  # only the upper half catches the lamp
frame = np.asarray(Image.open(OUT / "brass_frame.png").convert("RGBA").resize((N, N), Image.LANCZOS)).astype(float)
frame[..., :3] *= 0.82  # blackened brass: the rim should not outshine the text
composite_9slice("panel_iron.png", [dark_layer, light_layer, frame])

# Aged card: smoke stains, foxing and grain at the edges, scorched and coal-dusted rim.
stain = np.clip(low - 0.35, 0, 1) * 0.35
burnt = np.clip(1 - (border + (grit - 0.5) * 8) / 20, 0, 1) ** 2.2
card = np.zeros((N, N, 4))
card[..., 0], card[..., 1], card[..., 2] = 34, 20, 10  # burnt umber, not grey
card[..., 3] = np.clip(stain + burnt * 0.85 + in_border * 0.10 * grit, 0, 1) * 255
composite_9slice("card_aged.png", [card])
