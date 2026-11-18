"""Paints the depot hall's tile surfaces as seamless PBR maps (colour, normal, roughness).

  python tools/lobby-tiles/paint.py [out_dir]

Two MaterialVariants and one overlay, all painted from scratch with noise, no photographs:
  quarry   oxblood quarry tiles for the walk: 8 x 8 square tiles over 6 studs (9 inch tiles), each a
           little uneven in size and colour, chipped corners, grime packed into the joints
  dado     green glazed tiles for the back and end walls: 4 x 12 tiles over 4 studs (9 x 3 inch station
           tiles) laid in running bond,
           glaze pooled darker at the rims, crazed, a few chips showing the buff body
  path     a Texture laid on the walk's top face, 8 studs across: the worn path down the middle
           (dulled, lightly polished) and dirt banked along both sides

Every map tiles seamlessly (all noise is periodic). No pixel is pure white or pure black. Normal maps
are tangent space, +Y up (OpenGL), as Roblox reads them. Same seed, same maps.
"""

import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

SIZE = 1024
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out")


def noise(rng, shape, sigma):
    """Periodic smooth noise, about -1..1."""
    n = ndimage.gaussian_filter(rng.standard_normal(shape), sigma, mode="wrap")
    return n / (np.abs(n).max() + 1e-9)


def fbm(rng, shape, sigmas, weights):
    out = np.zeros(shape)
    for s, w in zip(sigmas, weights):
        out += noise(rng, shape, s) * w
    return out


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def tile_fields(rng, cols, rows, bond, jitter, joint):
    """Per-pixel tile id, distance in from the tile's edge (px) and a 0..1 inside mask.

    Each tile is an axis-aligned box whose four edges are jittered a few pixels, so tiles are not all
    the same size and the joints wander. Wrap-around is handled by tiling the layout 3 x 3.
    """
    cw, ch = SIZE / cols, SIZE / rows
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)
    ident = np.full((SIZE, SIZE), -1, dtype=np.int32)
    inset = np.zeros((SIZE, SIZE))
    boxes = []
    for r in range(rows):
        off = (cw / 2) if (bond and r % 2 == 1) else 0
        for c in range(cols):
            x0 = c * cw + off + joint / 2 + rng.uniform(-jitter, jitter)
            x1 = (c + 1) * cw + off - joint / 2 + rng.uniform(-jitter, jitter)
            y0 = r * ch + joint / 2 + rng.uniform(-jitter, jitter)
            y1 = (r + 1) * ch - joint / 2 + rng.uniform(-jitter, jitter)
            boxes.append((x0, x1, y0, y1))
    for i, (x0, x1, y0, y1) in enumerate(boxes):
        for dx in (-SIZE, 0, SIZE):
            for dy in (-SIZE, 0, SIZE):
                if x1 + dx < 0 or x0 + dx > SIZE or y1 + dy < 0 or y0 + dy > SIZE:
                    continue
                ax0, ax1 = max(0, int(x0 + dx)), min(SIZE, int(np.ceil(x1 + dx)))
                ay0, ay1 = max(0, int(y0 + dy)), min(SIZE, int(np.ceil(y1 + dy)))
                if ax1 <= ax0 or ay1 <= ay0:
                    continue
                sx, sy = xx[ay0:ay1, ax0:ax1], yy[ay0:ay1, ax0:ax1]
                d = np.minimum.reduce([sx - (x0 + dx), (x1 + dx) - sx, sy - (y0 + dy), (y1 + dy) - sy])
                sub = d > 0
                ident[ay0:ay1, ax0:ax1][sub] = i
                inset[ay0:ay1, ax0:ax1][sub] = d[sub]
    # hand-pressed edges: wobble the boundary a pixel or two so no arris is ruler straight
    inset = inset + noise(rng, (SIZE, SIZE), 2.5) * 1.8 * (inset > 0)
    return ident, inset, len(boxes)


def chips(rng, ident, inset, count, per_tile, radius):
    """Bites out of tile edges and corners: returns depth 0..1 (1 = deepest)."""
    chip = np.zeros((SIZE, SIZE))
    edge = (inset > 0) & (inset < radius[1] * 0.6)
    ys, xs = np.nonzero(edge)
    if len(ys) == 0:
        return chip
    n = int(count * per_tile)
    picks = rng.choice(len(ys), size=n, replace=False)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    for p in picks:
        cy, cx = ys[p], xs[p]
        rad = rng.uniform(*radius)
        # an irregular flake: a squashed disc with a noisy rim
        a = rng.uniform(0, np.pi)
        dx = (xx - cx + SIZE / 2) % SIZE - SIZE / 2
        dy = (yy - cy + SIZE / 2) % SIZE - SIZE / 2
        u = dx * np.cos(a) + dy * np.sin(a)
        v = (-dx * np.sin(a) + dy * np.cos(a)) * rng.uniform(1.2, 2.2)
        dist = np.sqrt(u * u + v * v) / rad
        flake = np.clip(1 - dist, 0, 1) ** 0.6
        flake *= ident == ident[cy, cx]
        chip = np.maximum(chip, flake)
    rough = noise(rng, (SIZE, SIZE), 1.5) * 0.35
    return np.clip(chip + rough * (chip > 0), 0, 1) * (chip > 0.05)


def normal_from_height(h, strength):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    # image rows run down; +Y (green) points up the image, so the y gradient flips sign
    n = np.dstack([-gx, gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def save(name, rgb=None, gray=None, normal=None):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    if rgb is not None:
        img = np.clip(rgb, 8, 247).astype(np.uint8)  # never pure black or white
        Image.fromarray(img, "RGB").save(path)
        return img
    if gray is not None:
        Image.fromarray(np.clip(gray * 255, 0, 255).astype(np.uint8), "L").save(path)
        return None
    img = ((normal * 0.5 + 0.5) * 255).astype(np.uint8)
    Image.fromarray(img, "RGB").save(path)
    return None


def crazing(rng, mask, cell):
    """A network of fine dark lines (Voronoi borders of jittered points), only where mask is set."""
    n = int((SIZE / cell) ** 2)
    pts = rng.uniform(0, SIZE, size=(n, 2))
    tiled = np.concatenate([pts + [dx, dy] for dx in (-SIZE, 0, SIZE) for dy in (-SIZE, 0, SIZE)])
    tree = cKDTree(tiled)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    q = np.column_stack([xx.ravel(), yy.ravel()]).astype(np.float64)
    # warp the lookup so the lines wander instead of running dead straight
    warp = noise(rng, (SIZE, SIZE), 6).ravel() * cell * 0.25
    q[:, 0] += warp
    q[:, 1] += np.roll(warp, SIZE * 7)
    d, _ = tree.query(q, k=2)
    gap = (d[:, 1] - d[:, 0]).reshape(SIZE, SIZE)
    line = 1 - smoothstep(0.0, 1.1, gap)
    # not every crack is complete: fade some runs out
    line *= smoothstep(-0.3, 0.3, noise(rng, (SIZE, SIZE), 18))
    return line * mask


# -- quarry tiles -----------------------------------------------------------------------------------
def quarry(rng):
    ident, inset, count = tile_fields(rng, 8, 8, bond=False, jitter=2.5, joint=7)
    inside = smoothstep(0.0, 2.5, inset)
    shape = (SIZE, SIZE)
    # per-tile firing colour: oxblood, some browner, some nearer purple, a few darker
    base = np.array([138, 68, 56], dtype=np.float64)
    tint = np.ones((count, 3))
    for i in range(count):
        v = rng.normal(1.0, 0.075)
        brown = rng.normal(0, 0.08)
        tint[i] = [v * (1 + brown * 0.4), v * (1 + brown), v * (1 + brown * 1.2)]
        if rng.random() < 0.12:
            tint[i] *= 0.8  # an over-fired tile
    tinted = np.where(ident[..., None] >= 0, tint[np.maximum(ident, 0)], 1.0)
    mottle = fbm(rng, shape, [3, 10, 40], [0.05, 0.08, 0.1])
    col = base * tinted * (1 + mottle[..., None])
    # iron speckle in the clay
    speck = noise(rng, shape, 0.7)
    col *= 1 - 0.35 * (speck > 0.55)[..., None]
    # grime: banked in from each joint, patchy over the face, packed into chips
    edge_grime = 1 - smoothstep(0, 20, inset)
    patch = smoothstep(0.0, 0.7, fbm(rng, shape, [14, 50, 120], [0.4, 0.4, 0.3]))
    grime = np.clip(edge_grime * 0.4 + patch * 0.4, 0, 1)
    chip = chips(rng, ident, inset, count, 0.7, (6, 18))
    joint_col = np.array([88, 72, 62], dtype=np.float64) * (1 + noise(rng, shape, 2)[..., None] * 0.15)
    dirt = np.array([62, 48, 40], dtype=np.float64)
    col = col * (1 - grime[..., None] * 0.5) + dirt * grime[..., None] * 0.25
    # dry dust lying in drifts, greying the clay
    dust = smoothstep(0.1, 0.9, fbm(rng, shape, [8, 35, 90], [0.3, 0.4, 0.3])) * 0.3
    col = col * (1 - dust[..., None]) + np.array([112, 98, 88]) * dust[..., None]
    col = col * (1 - chip[..., None]) + (joint_col * 1.15) * chip[..., None]
    # scuffs: short pale strokes along the walk
    scuff = np.clip(noise(rng, shape, (0.8, 9)) - 0.4, 0, 1) * smoothstep(0.2, 0.6, noise(rng, shape, 30))
    col += scuff[..., None] * np.array([30, 22, 18]) * inside[..., None]
    col = col * inside[..., None] + joint_col * (1 - inside[..., None])
    # height: flat faces with softened arrises, recessed joints and chips, pitted clay
    h = smoothstep(0, 9, inset) * 1.0 - chip * 0.7 + fbm(rng, shape, [1, 4], [0.03, 0.05]) * inside
    nrm = normal_from_height(h * 6, 1.0)
    rough = 0.78 + noise(rng, shape, 12) * 0.06 - (1 - grime) * 0.05
    rough = rough * inside + 0.95 * (1 - inside)
    rough = np.maximum(rough, chip * 0.92)
    return col, nrm, np.clip(rough, 0.05, 0.98)


# -- glazed dado ------------------------------------------------------------------------------------
def dado(rng):
    ident, inset, count = tile_fields(rng, 4, 12, bond=True, jitter=1.0, joint=4)
    inside = smoothstep(0.0, 2.0, inset)
    shape = (SIZE, SIZE)
    base = np.array([46, 112, 84], dtype=np.float64)
    tint = np.ones((count, 3))
    for i in range(count):
        v = rng.normal(1.0, 0.06)
        hue = rng.normal(0, 0.045)  # bottle green to teal to olive, tile by tile
        tint[i] = [v * (1 + hue * 1.6), v, v * (1 - hue * 1.2)]
    tinted = np.where(ident[..., None] >= 0, tint[np.maximum(ident, 0)], 1.0)
    # the glaze ran: thicker and darker at the rim, thinner and paler on the face, wavy
    rim = (1 - smoothstep(0, 7, inset)) * (0.6 + 0.4 * noise(rng, shape, 5))
    wave = fbm(rng, shape, [6, 22], [0.5, 0.5])
    col = base * tinted * (1 + wave[..., None] * 0.1)
    col *= (1 - rim * 0.3)[..., None]
    col *= 1 + np.array([-0.1, 0.0, 0.05]) * rim[..., None]  # deeper, bluer where it pooled
    craze = crazing(rng, inside > 0.5, 26)
    chip = chips(rng, ident, inset, count, 0.6, (5, 14))
    body = np.array([150, 128, 98], dtype=np.float64) * (1 + noise(rng, shape, 2)[..., None] * 0.1)
    joint_col = np.array([50, 50, 43], dtype=np.float64) * (1 + noise(rng, shape, 2)[..., None] * 0.15)
    # soot and dust on the glaze, worse lower down each tile where it settles on the joint
    soot = smoothstep(0.05, 0.85, fbm(rng, shape, [25, 80], [0.5, 0.5])) * 0.35
    col = col * (1 - soot[..., None] * 0.5) + np.array([48, 46, 40]) * soot[..., None] * 0.25
    col *= (1 - craze * 0.22)[..., None]
    col = col * (1 - chip[..., None]) + (body * 0.75 + joint_col * 0.25) * chip[..., None]
    grime_edge = 1 - smoothstep(0, 5, inset)
    col = col * (1 - grime_edge[..., None] * 0.35)
    col = col * inside[..., None] + joint_col * (1 - inside[..., None])
    # height: pillowed tile faces, a faint orange-peel ripple in the glaze, chips cut through it
    pillow = smoothstep(0, 5, inset)
    h = pillow * 1.0 + wave * 0.03 * inside - craze * 0.02 - chip * 0.6
    nrm = normal_from_height(h * 7, 1.0)
    rough = 0.24 + soot * 0.3 + noise(rng, shape, 8) * 0.04 + craze * 0.25
    rough = rough * inside + 0.93 * (1 - inside)
    rough = np.maximum(rough, chip * 0.88)
    return col, nrm, np.clip(rough, 0.05, 0.98)


# -- worn path overlay ------------------------------------------------------------------------------
def path(rng):
    """RGBA, 8 studs across (rows) by 16 studs along (columns): a dull worn band down the middle and
    dirt banked along both edges. Columns run along the walk, so the texture repeats along it."""
    w, h = 1024, 512
    yy = np.linspace(-1, 1, h)[:, None] * np.ones((1, w))
    streak = ndimage.gaussian_filter(rng.standard_normal((h, w)), (3, 60), mode="wrap")
    streak /= np.abs(streak).max()
    wander = ndimage.gaussian_filter1d(rng.standard_normal(w), 80, mode="wrap")
    wander = wander / (np.abs(wander).max() + 1e-9) * 0.12
    centre = np.abs(yy - wander[None, :])
    worn = 1 - smoothstep(0.15, 0.6, centre + streak * 0.08)
    banked = smoothstep(0.7, 0.98, np.abs(yy)) * (0.8 + streak * 0.2)
    rgb = np.zeros((h, w, 3))
    worn_col = np.array([168, 120, 104])  # dull pink-buff where boots have polished the dirt off
    dirt_col = np.array([46, 38, 33])
    a_worn = worn * (0.3 + streak * 0.08)
    a_dirt = banked * 0.55
    alpha = np.clip(a_worn + a_dirt, 0, 1)
    mix = a_dirt / (alpha + 1e-6)
    rgb = worn_col * (1 - mix[..., None]) + dirt_col * mix[..., None]
    img = np.dstack([np.clip(rgb, 8, 247), np.clip(alpha * 255, 0, 255)]).astype(np.uint8)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, "path_color.png"))


def main():
    rng = np.random.default_rng(1871)
    means = {}
    for key, fn in (("quarry", quarry), ("dado", dado)):
        col, nrm, rough = fn(rng)
        img = save(key + "_color", rgb=col)
        save(key + "_normal", normal=nrm)
        save(key + "_roughness", gray=rough)
        means[key] = [round(float(v)) for v in img.reshape(-1, 3).mean(0)]
    path(rng)
    with open(os.path.join(OUT, "means.json"), "w") as f:
        json.dump(means, f, indent=1)
    print(json.dumps(means))


if __name__ == "__main__":
    main()
