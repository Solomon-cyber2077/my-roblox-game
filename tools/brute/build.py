"""Close-up meshes and textures for the Brute (Builders/HollowBuilder brute), second pass (B8).

Who it was: the line's fireman, the man who fed the firebox. A heavy labourer, not a fantasy brute: a real
face under coal dust, a broken nose, eyes narrowed to slits under hooded lids, one side of the head, neck,
shoulder and left arm carrying an old healed burn (keloid ropes, a pulled-down lower lid, the left ear burnt
to a nub, the right one a boxer's cauliflower ear). Stripped to the waist under a smith's bib apron: one hide,
neck strap with a roller buckle on one side and a riveted tab on the other, waist thongs knotted at the back,
a patch pocket sewn with a saddle stitch and riveted at the corners, spark holes. A sweat rag knotted at the
neck. Moleskin trousers bloused over "yorks" below the knee (a strap on the right, a cord on the left),
hobnailed ankle boots. The fireman's shovel in its right hand, the hand grown over the shaft. The embers live
in a few deep fissures in the burn plaques of its flanks and back: the only warm thing about it.

References (refs/, SOURCES.json): Meunier's Puddler and Resting Puddler (build, apron), Menzel's Iron
Rolling Mill (furnace men, aprons), Levering's Stoker and Staniland's Stokehold (stokers stripped to the
waist), a locomotive fireman at the firebox, hobnail boots and soles, a keloid scar study, railway shovels.

Look-gate rules this pass is built against: no mirrored sides (every stroke is placed on its own, the left and
right limbs are separate meshes), no noise standing in for detail (forms are carved: planes, creases, ridges;
colour follows form through cavity and occlusion), straps and fastenings that work (every strap ends in a
buckle, a knot, a rivet or a seam), matte leather, skin and cloth, the muted palette of the Stalker and train.

  blender -b --python build.py -- [--only head,torso] [--preview] [--no-render]
  blender -b --python build.py -- --render-only            (renders from out/*.fbx and *.png)
  blender -b --python build.py -- --before-only --old <dir> (the block build and a stored remake)

Writes out/<piece>.fbx, out/<piece>.png, out/report.json; renders into renders/.
Axes: +Y up, front -Z, one Blender unit = one stud; bone pieces run along X with the joint end at +X.
"""

import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import b8lib as L  # noqa: E402

BASE = HERE if HERE.name == "brute" else HERE.parent  # tools/brute in the game, or the private work folder
L.OUT = BASE / "out"
L.OUT.mkdir(exist_ok=True)
RENDERS = BASE / "renders"
RENDERS.mkdir(exist_ok=True)
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = None
for a in ARGS:
    if a.startswith("--only"):
        ONLY = set(ARGS[ARGS.index(a) + 1].split(","))
PREVIEW = "--preview" in ARGS
GIANT = "--giant" in ARGS  # the 12-stud Brute (owner 2026-11-17); without it, the skeleton HollowBuilder has today
if GIANT:
    L.OUT = BASE / "out-giant"
    L.OUT.mkdir(exist_ok=True)

S, mixc, fbm, vnoise, Mesh = L.S, L.mixc, L.fbm, L.vnoise, L.Mesh
A, T = L.A, L.T

# palette (sRGB)
SKIN = np.array((0.46, 0.35, 0.29))  # a labourer's weathered skin under the dust
SKIN_SHADE = np.array((0.30, 0.21, 0.18))
SOOT = np.array((0.095, 0.085, 0.08))
ASH = np.array((0.36, 0.35, 0.33))
SCAR = np.array((0.44, 0.35, 0.32))  # healed burn: dull, pinkish brown; it reads by its gloss
SCAR_RIM = np.array((0.30, 0.20, 0.19))
SCAR_RIDGE = np.array((0.52, 0.42, 0.38))
LIP = np.array((0.28, 0.18, 0.16))
WET = np.array((0.05, 0.035, 0.03))
STUBBLE = np.array((0.13, 0.12, 0.12))
TOOTH = np.array((0.55, 0.47, 0.32))
EMBER_RIM = np.array((0.62, 0.25, 0.08))
LEATHER = np.array((0.33, 0.21, 0.12))
LEATHER_DARK = np.array((0.11, 0.07, 0.045))
LEATHER_WORN = np.array((0.42, 0.30, 0.19))
STITCH = np.array((0.50, 0.43, 0.30))
IRON = np.array((0.20, 0.19, 0.18))
IRON_BRIGHT = np.array((0.50, 0.49, 0.46))
RUST = np.array((0.36, 0.18, 0.09))
COPPER = np.array((0.42, 0.26, 0.15))
MOLESKIN = np.array((0.23, 0.22, 0.2))  # trousers: brown-grey heavy cotton
MOLESKIN_DARK = np.array((0.11, 0.105, 0.1))
RAG = np.array((0.22, 0.24, 0.26))  # faded blue-grey cotton
WOOD = np.array((0.30, 0.22, 0.15))
CHAR = np.array((0.04, 0.035, 0.03))
CORD = np.array((0.38, 0.33, 0.24))


def soot_skin(m, cav, seed=0, base=SKIN, coverage=0.62, streaks=True):
    """Coal dust over skin, settling into every fold (cavity), wiped thin on what sticks out, with clean runs
    where sweat ran down (vertical streaks), a little ash on what faces up."""
    P, n = m.V, m.N()
    C = np.tile(base, (len(P), 1))
    C = mixc(C, SKIN_SHADE, 0.25 + 0.2 * L.fbm(P, 8.0, 3, seed))
    cover = coverage + 0.08 * L.fbm(P, 11.0, 3, seed + 3) + 0.45 * np.clip(cav, 0, 1) - 0.25 * np.clip(-cav, 0, 1)
    if streaks:
        run = S(0.25, 0.7, L.vnoise(P, 7.0, seed + 5, stretch=(1, 0.07, 1))) * S(0.2, 0.7, -n[:, 1] * 0 + 1 - np.abs(n[:, 1]))
        cover = cover - 0.38 * run
    C = mixc(C, SOOT, np.clip(cover, 0, 0.93))
    C = mixc(C, ASH, S(0.55, 0.95, n[:, 1]) * 0.22)
    # where it shines: skin the sweat has washed (low cover) is wet; soot and ash stay dry and matte
    m.R = np.clip(0.42 + 0.52 * np.clip(cover, 0, 1) + 0.08 * np.clip(cav, 0, 1), 0.28, 0.97)
    return C


# ------------------------------------------------------------------ head and jaw
EYE_R = np.array((0.205, 0.045, -0.535))  # figure's right (+X): heavy-lidded slit
EYE_L = np.array((-0.205, 0.022, -0.53))  # burn side: a little lower, lower lid pulled down
JAW_ORIGIN = np.array((0.0, -0.67, -0.15))
NECK_PIVOT = np.array((0.0, -0.35, 0.0))  # the Neck joint in the Head frame
HEAD_SCALE = 1.14  # the Jaw part's centre in the Head frame (HollowBuilder Jaw joint)


def almond(c, w, h, tilt, n=24):
    """The lid line of a narrowed eye: an upper and a lower arc from the inner to the outer corner."""
    inner = c + np.array((-np.sign(c[0]) * w * 0.55, -0.004, 0.012))
    outer = c + np.array((np.sign(c[0]) * w * 0.5, tilt, 0.03))
    t = np.linspace(0, 1, n)
    base = inner[None] + (outer - inner)[None] * t[:, None]
    bulge = np.sin(t * math.pi)[:, None]
    upper = base + bulge * np.array((0, h, -0.012))
    lower = base + bulge * np.array((0, -h * 0.55, -0.008))
    return upper, lower, inner, outer


def head_sculpt():
    # a smooth base: cranium, face mass, jaw, neck; every feature after this is pushed or pulled out of it
    m = L.Meta(0.03)
    m.ell((0, 0.1, 0.05), (0.48, 0.41, 0.53))
    m.ell((0, -0.22, -0.26), (0.43, 0.34, 0.36))
    m.cap((0.0, 0.08, -0.54), (0.03, -0.1, -0.615), 0.05)  # nose bridge, knocked to its right
    m.ell((0.035, -0.14, -0.6), (0.07, 0.085, 0.07))  # nose body
    m.ball((0.05, -0.19, -0.645), 0.068)  # tip, bulbous
    m.ball((0.118, -0.212, -0.585), 0.05)  # wings
    m.ball((-0.03, -0.222, -0.588), 0.046)
    tache = L.smooth_path([(-0.15, -0.4, -0.53), (-0.1, -0.345, -0.57), (0.0, -0.325, -0.6), (0.1, -0.34, -0.575),
                           (0.17, -0.41, -0.535), (0.19, -0.46, -0.505)], 12)
    m.chain(tache, [0.018, 0.026, 0.032, 0.034, 0.032, 0.03, 0.028, 0.026, 0.024, 0.022, 0.02, 0.016])  # moustache
    m.ell((0, -0.6, -0.25), (0.39, 0.2, 0.3))
    m.ball((0.02, -0.7, -0.45), 0.155)
    m.cap((0, -0.4, 0.12), (0, -0.98, 0.2), 0.47)  # bull neck
    m.ell((0, -0.3, 0.33), (0.39, 0.22, 0.18))  # nape fat
    m.ell((0.48, -0.02, 0.07), (0.035, 0.125, 0.085))  # right ear (lumps added below)
    m.ell((-0.475, -0.035, 0.07), (0.04, 0.07, 0.06))  # left ear burnt to a nub
    h = m.mesh(0.0072)  # fine enough for pores in the normal map
    h.smooth(it=6)
    g = lambda c, r, v: h.move(h.ball(c, r), v)
    # brow shelf forward and down, glabella
    g((0, 0.16, -0.45), 0.4, (0, -0.02, -0.085))
    g((0, 0.12, -0.52), 0.14, (0, 0, -0.025))
    # orbits sunk, the balls under the lids
    for e in (EYE_R, EYE_L):
        pass
    g((0, 0.22, -0.45), 0.24, (0, -0.02, -0.08))
    for e in (EYE_R, EYE_L):
        h.move(h.ell(e + (0, -0.005, -0.02), (0.13, 0.085, 0.12)), (0, 0.0, 0.08))
    # cheekbones, the hollow under them, the jowls
    g((0.3, -0.04, -0.42), 0.19, (0.03, 0.0, -0.04))
    g((-0.3, -0.06, -0.41), 0.2, (-0.025, -0.008, -0.045))
    h.inflate(h.ball((0.26, -0.27, -0.46), 0.1), -0.01)
    h.inflate(h.ball((-0.25, -0.29, -0.46), 0.1), -0.007)
    g((0.3, -0.5, -0.3), 0.14, (0.02, -0.02, 0))
    g((-0.3, -0.52, -0.3), 0.14, (-0.02, -0.025, 0))
    # muzzle and the moustache over it; chin forward and square
    g((0, -0.4, -0.5), 0.26, (0, 0, -0.04))
    g((0.02, -0.72, -0.5), 0.18, (0, -0.015, -0.05))
    h.smooth(it=2)
    surf = L.Surface(h)

    def on(pts, d=(0, 0, 1)):
        out = []
        for p in pts:
            q, _ = surf.cast(p, d)
            out.append(q if q is not None else p)
        return np.array(out)

    # big planes: the brow shelf, the flat under the cheekbones, the square chin
    h.flatten(h.ell((0, 0.27, -0.42), (0.3, 0.12, 0.12)), 0.5)
    h.flatten(h.ell((0.3, -0.2, -0.42), (0.1, 0.12, 0.1)), 0.4)
    h.flatten(h.ell((-0.31, -0.22, -0.41), (0.1, 0.12, 0.1)), 0.4)
    h.flatten(h.ell((0.02, -0.76, -0.55), (0.14, 0.08, 0.1)), 0.6)
    h.flatten(h.ell((0.0, 0.14, -0.53), (0.3, 0.04, 0.06)), 0.5, normal=(0, 0.25, -1))
    for s_ in (1, -1):  # the jaw's side and underside planes meet in a hard jawline
        h.flatten(h.ell((s_ * 0.3, -0.58, -0.25), (0.08, 0.14, 0.2)), 0.6, normal=(s_, -0.15, -0.1))
        h.flatten(h.ell((s_ * 0.2, -0.78, -0.3), (0.16, 0.06, 0.2)), 0.5, normal=(s_ * 0.3, -1, -0.2))
    surf = L.Surface(h)
    # the lower edge of the brow shelf, crisp, a little different each side
    for s, y in ((1, 0.098), (-1, 0.088)):
        xs = np.linspace(0.07, 0.34, 14)
        h.crease(on(np.stack([s * xs, y - 0.04 * ((xs - 0.2) / 0.14) ** 2, np.full_like(xs, -0.4)], 1)), 0.03, 0.016, 0.3)
    surf = L.Surface(h)
    eyes_at = []
    for c, side in ((EYE_R, 1), (EYE_L, -1)):
        q, _ = surf.cast(c + (0, 0, -0.5), (0, 0, 1))
        cc = q if q is not None else c
        up, lo, inner, outer = almond(cc, 0.15, 0.02 if side > 0 else 0.024, 0.006 if side > 0 else -0.004)
        h.ridge(up + np.array((0, 0.014, -0.004)), 0.02, 0.012)  # upper lid, thick and heavy
        h.ridge(lo + np.array((0, -0.01, -0.002)), 0.014, 0.006)
        h.crease(up, 0.016, 0.034, 0.9, key="eye")
        h.crease(lo, 0.013, 0.024, 0.9, key="eye")
        h.crease(up + np.array((0, 0.042, 0.004)), 0.022, 0.012, 0.5)  # the hooded fold
        h.crease(lo + np.array((0, -0.055, 0.004)), 0.03, 0.009, 0.4)  # bags
        for k, ang in enumerate((18, -8, -30)):  # crow's feet, uneven
            a = math.radians(ang)
            d = np.array((side * math.cos(a), math.sin(a), 0.03))
            ln = (0.06, 0.08, 0.05)[k] * (1.0 if side > 0 else 0.6)
            h.crease([outer + d * 0.02, outer + d * (0.02 + ln)], 0.012, 0.006, 0.4)
        eyes_at.append(cc)
    h.eyes_at = eyes_at
    h.move(h.ell(EYE_L + (0, -0.045, -0.02), (0.09, 0.03, 0.05)), (0.0, -0.016, 0.004))  # pulled lid
    surf = L.Surface(h)
    # forehead: two broken lines; glabella: two unequal ones
    for y, x0, x1, dp in ((0.29, -0.22, 0.04, 0.006), (0.3, 0.09, 0.25, 0.005), (0.35, -0.15, 0.16, 0.006)):
        xs = np.linspace(x0, x1, 12)
        h.crease(on(np.stack([xs, y + 0.012 * np.sin(xs * 9 + y * 20), np.full_like(xs, -0.5)], 1)), 0.02, dp, 0.4, key="lines")
    h.crease(on([(-0.035, 0.13, -0.6), (-0.045, 0.21, -0.6)]), 0.015, 0.012, 0.6, key="lines")
    h.crease(on([(0.05, 0.12, -0.6), (0.06, 0.18, -0.6)]), 0.013, 0.008, 0.6, key="lines")
    # nose: hump where it broke, alar grooves, nostrils opening down
    h.inflate(h.ball((0.018, -0.02, -0.62), 0.045), 0.012)
    surf = L.Surface(h)
    for c, side in (((0.123, -0.212, -0.6), 1), ((-0.033, -0.222, -0.602), -1)):
        arc = [np.array(c) + np.array((side * 0.055 * math.cos(t), 0.048 * math.sin(t) - 0.005, -0.01)) for t in np.linspace(-0.2, 2.4, 10)]
        h.crease(on(arc), 0.013, 0.012, 0.6, key="lines")
    for c in ((0.085, -0.255, -0.63), (-0.012, -0.262, -0.63)):
        w = h.ell(c, (0.026, 0.02, 0.02))
        h.move(w, (0, 0.03, 0.008))
        h.masks["nostril"] = np.maximum(h.masks.get("nostril", 0), w)
    # moustache: locks carved from the parting outward and down; the left side thinner and singed
    surf = L.Surface(h)
    h.masks["tache"] = S(0.06, 0.03, L.path_dist(h.V, tache)[0])
    rng = np.random.default_rng(21)
    for k in range(22):
        s = 1 if k % 2 == 0 else -1
        x0 = s * rng.uniform(0.0, 0.05)
        y0 = rng.uniform(-0.31, -0.29)
        ln = rng.uniform(0.09, 0.2) * (1.0 if s > 0 else 0.75)
        pts = [(x0, y0, -0.65), (x0 + s * ln * 0.55, y0 - ln * 0.25, -0.65), (x0 + s * ln * 0.8, y0 - ln * 0.65, -0.6)]
        h.crease(on(L.smooth_path(pts, 10)), 0.009, 0.006, 0.5, key="hairline")
    # mouth under the moustache: the line, the lower lip, the fold beneath
    surf = L.Surface(h)
    xs = np.linspace(-0.17, 0.165, 20)
    mouth = on(np.stack([xs, -0.432 - 0.03 * (xs / 0.18) ** 2 + 0.006 * (xs < 0) * (xs / 0.18) ** 2, np.full_like(xs, -0.5)], 1))
    h.crease(mouth, 0.02, 0.03, 0.95, key="mouth")
    h.inflate(h.ell((0.005, -0.465, -0.53), (0.12, 0.028, 0.05)), 0.009)
    h.crease(on(L.smooth_path([(-0.17, -0.41, -0.6), (-0.06, -0.385, -0.66), (0.06, -0.385, -0.66), (0.2, -0.46, -0.6)], 20)), 0.016, 0.014, 0.6, key="lines")
    h.masks["lip"] = h.ell((0.0, -0.455, -0.53), (0.15, 0.035, 0.06))
    xs = np.linspace(-0.11, 0.12, 10)
    h.crease(on(np.stack([xs, -0.525 + 0.02 * (xs / 0.12) ** 2, np.full_like(xs, -0.5)], 1)), 0.022, 0.014, 0.5, key="lines")
    # nasolabial folds into marionette lines; the burnt side drawn tighter
    surf = L.Surface(h)
    for pts, dp in (([(0.15, -0.215, -0.55), (0.21, -0.33, -0.53), (0.235, -0.44, -0.49), (0.26, -0.56, -0.41)], 0.02),
                    ([(-0.115, -0.228, -0.55), (-0.18, -0.33, -0.53), (-0.21, -0.45, -0.49), (-0.24, -0.54, -0.42)], 0.014)):
        path = on(L.smooth_path(pts, 24, 0.002, 3))
        h.crease(path, 0.034, dp, 0.5, key="lines")
        h.inflate(h.line(path + np.array((np.sign(pts[0][0]) * 0.045, 0.01, 0)), 0.05)[0], 0.01)
    # cauliflower ear: lumps on the right ear
    surf = L.Surface(h)
    for c, r, a in (((0.52, 0.05, 0.05), 0.04, 0.02), ((0.525, -0.05, 0.1), 0.045, 0.024), ((0.515, 0.08, 0.12), 0.03, 0.014),
                    ((0.51, -0.11, 0.05), 0.03, 0.012)):
        h.inflate(h.ball(c, r), a)
    h.crease(on([(0.53, 0.03, 0.08), (0.535, -0.03, 0.085), (0.53, -0.07, 0.07)], (-1, 0, 0)), 0.02, 0.018, 0.5, key="lines")
    h.smooth(h.ball((0.5, -0.02, 0.07), 0.16), it=2, lam=0.4)
    # double chin, two uneven rolls at the nape, the cords of the neck
    surf = L.Surface(h)
    xs = np.linspace(-0.28, 0.27, 16)
    h.crease(on(np.stack([xs, -0.76 - 0.07 * (1 - (xs / 0.28) ** 2), np.full_like(xs, -0.2)], 1), (0, 0.5, 1)), 0.03, 0.016, 0.5, key="lines")
    for y, x0, x1, dp in ((-0.36, -0.33, 0.26, 0.026), (-0.52, -0.18, 0.3, 0.018)):
        xs = np.linspace(x0, x1, 14)
        roll = on(np.stack([xs, y + 0.025 * np.sin(xs * 5 + y * 9), np.full_like(xs, 0.3)], 1), (0, 0, -1))
        h.crease(roll, 0.03, dp, 0.5, key="lines")
        h.inflate(h.line(roll + np.array((0, 0.05, 0)), 0.05)[0], 0.012)
    for s in (1, -1):
        h.ridge(on([(s * 0.42, -0.2, 0.1), (s * 0.3, -0.55, 0.0), (s * 0.16, -0.95, -0.1)], (-s, 0, 0)), 0.07, 0.016)
    # scalp: an old cut and a dent
    surf = L.Surface(h)
    h.ridge(on([(0.1, 0.62, -0.1), (0.2, 0.6, 0.06), (0.27, 0.52, 0.2)], (0, -1, 0)), 0.012, 0.007, key="cut")
    h.inflate(h.ball((-0.12, 0.52, 0.16), 0.11), -0.012)

    # the burn: left temple, cheek, ear and neck. Skin pulled tight, keloid plaques laid across it
    burn = np.maximum.reduce([h.ell((-0.43, 0.0, -0.05), (0.17, 0.33, 0.38)), h.ell((-0.37, -0.56, 0.0), (0.17, 0.36, 0.3)),
                              h.ell((-0.3, 0.2, -0.3), (0.13, 0.15, 0.18)), h.ell((-0.25, -0.15, -0.42), (0.1, 0.12, 0.1))])
    burn = S(0.15, 0.55, burn * (1.0 + 0.7 * L.fbm(h.V, 6.0, 2, 11)))
    h.smooth(burn, it=8, lam=0.6)
    surf = L.Surface(h)
    plaques = [((-0.46, 0.08, -0.18), (0.03, 0.14, 0.04), 0.004), ((-0.47, -0.15, 0.02), (0.03, 0.05, 0.14), 0.005),
               ((-0.4, -0.3, -0.25), (0.05, 0.12, 0.04), 0.004), ((-0.42, -0.58, -0.1), (0.04, 0.16, 0.05), 0.005),
               ((-0.38, -0.8, 0.05), (0.04, 0.05, 0.12), 0.004), ((-0.33, 0.27, -0.3), (0.07, 0.03, 0.04), 0.003)]
    for c, semi, a in plaques:
        w = h.ell(c, semi)
        h.inflate(w, a)
        h.masks["keloid"] = np.maximum(h.masks.get("keloid", 0), w)
    rng = np.random.default_rng(5)
    for k in range(9):  # contracture lines between the plaques
        c = np.array((-0.44, rng.uniform(-0.8, 0.2), rng.uniform(-0.3, 0.15)))
        d = rng.normal(0, 1, 3)
        d[0] = 0
        d = d / np.linalg.norm(d) * rng.uniform(0.05, 0.11)
        pts = [surf.nearest(c - d)[0], surf.nearest(c)[0], surf.nearest(c + d)[0]]
        h.crease(pts, 0.012, 0.005, 0.5, key="lines")
    h.masks["burn"] = burn
    h.move(h.ball((-0.17, -0.45, -0.52), 0.07), (-0.008, 0.01, 0.01))  # mouth corner drawn toward the scar
    h.smooth(it=1, lam=0.3)
    # cut every line deeper and harder (no clay: a weathered face has sharp folds), then pores on the skin
    n = h.N()
    lines = np.clip(h.masks.get("lines", 0) * 1.0, 0, 1)
    h.V -= n * (0.009 * lines ** 0.7)[:, None]
    skin = (1 - S(0.2, 0.6, h.masks.get("tache", 0))) * (1 - S(0.2, 0.6, h.masks.get("eye", 0)))
    skin = skin * (1 - 0.7 * S(0.2, 0.6, h.masks.get("burn", 0)))  # scar tissue has no pores
    pores = np.clip(L.vnoise(h.V, 150.0, 31) - 0.35, 0, 1) * 0.0045 + L.vnoise(h.V, 60.0, 32) * 0.0012
    h.V -= n * (pores * skin)[:, None]
    return h


def head_colour(h):
    cav = h.cavity(3)
    P, n = h.V, h.N()
    C = soot_skin(h, cav, seed=1)
    m = h.masks
    # close-cropped hair and stubble: a tone, not dots. Receding at the temples, none on the burn
    hairline = 0.3 + 0.05 * np.abs(P[:, 0]) / 0.3 + 0.015 * L.fbm(P, 12, 1, 4)  # receding at the temples
    scalp = S(hairline, hairline + 0.06, P[:, 1] + 0.35 * (P[:, 2] + 0.3))
    beard = S(-0.32, -0.42, P[:, 1]) * S(-0.2, -0.45, P[:, 2]) * (1 - m["lip"])
    beard = np.maximum(beard, S(-0.25, -0.35, P[:, 1]) * S(0.1, 0.25, np.abs(P[:, 0])) * S(0.05, -0.3, P[:, 2]))
    hair = np.clip(np.maximum(scalp, beard * 0.7), 0, 1) * (1 - S(0.1, 0.5, m["burn"]))
    C = mixc(C, STUBBLE * 0.7, hair * (0.75 + 0.1 * L.fbm(P, 20, 1, 9)))
    # lips, the slits of the eyes, nostrils
    C = mixc(C, LIP, m["lip"] * 0.55)
    C = mixc(C, WET, S(0.3, 0.8, m.get("mouth", 0)))
    C = mixc(C, WET, S(0.25, 0.7, m["eye"]))
    C = mixc(C, (0.3, 0.17, 0.15), S(0.05, 0.25, m["eye"]) * (1 - S(0.25, 0.7, m["eye"])) * 0.6)
    C = mixc(C, WET, m["nostril"] * 0.9)
    tache = S(0.1, 0.6, m["tache"]) * (1 - S(0.3, 0.7, m["burn"]) * 0.5)
    C = mixc(C, mixc(np.tile(STUBBLE * 0.55, (len(P), 1)), (0.26, 0.24, 0.22), S(-0.1, -0.8, cav) * 0.6), tache * 0.95)
    # the burn: pale shiny scar, darker margins, lighter ropes, less dust stays on it
    burn = m["burn"]
    scar = mixc(np.tile(SCAR, (len(P), 1)), SCAR_RIM, S(0.6, 0.15, burn) * 0.8)
    scar = mixc(scar, SCAR_RIDGE, S(-0.15, -0.7, cav) * 0.4)
    scar = mixc(scar, SOOT, np.clip(0.25 + 0.5 * np.clip(cav, 0, 1), 0, 1))
    C = mixc(C, scar, S(0.1, 0.45, burn) * 0.7)
    C = mixc(C, SCAR * 0.8, m.get("cut", 0) * 0.7)
    h.C = C
    R = h.R
    R = R + (0.4 - R) * S(0.1, 0.45, m["burn"]) * 0.8  # keloid is glossy
    R = R + (0.15 - R) * S(0.25, 0.7, m["eye"])  # wet eyes
    R = R + (0.45 - R) * m["lip"] * 0.6
    R = R + (0.8 - R) * S(0.1, 0.6, m["tache"])
    h.R = R
    return h


def hull2d(pts):
    """Convex hull (monotone chain) of 2D points, counter-clockwise."""
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


def split_head(h):
    """Cut the jaw off along the mouth, in front of the ramus and above the throat; cap both cuts dark."""
    bm = bmesh.new()
    col = bm.verts.layers.float_color.new("col")
    vs = [bm.verts.new(v) for v in h.V]
    for v, c in zip(vs, h.C):
        v[col] = (*c, 1.0)
    for f in h.F:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass
    planes = [((0, -0.445, -0.5), (0, 1, -0.08)), ((0, -0.5, 0.07), (0, 0, 1)), ((0, -0.8, -0.45), (0, -0.92, 0.4))]
    for co, no in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, dist=1e-5)
    # new verts from the cuts take the colour of their nearest old vertex
    bm.verts.index_update()
    kd = KDTree(len(h.V))
    for i, v in enumerate(h.V):
        kd.insert(v, i)
    kd.balance()
    for v in bm.verts:
        if v.index >= len(h.V) or v[col][3] == 0:
            _, i, _ = kd.find(v.co)
            v[col] = (*h.C[i], 1.0)

    def jaw_side(p):
        return all((Vector(p) - Vector(co)).dot(Vector(no)) < 0 for co, no in planes)

    parts = []
    for keep_jaw in (False, True):
        b = bm.copy()
        c2 = b.verts.layers.float_color["col"]
        drop = [f for f in b.faces if jaw_side(f.calc_center_median()) != keep_jaw]
        bmesh.ops.delete(b, geom=drop, context="FACES")
        for co, no in planes:  # a flat dark cap on each cut plane, from the hull of the cut's verts
            co, no = Vector(co), Vector(no).normalized()
            on_plane = [v.co.copy() for v in b.verts if v.is_boundary and abs((v.co - co).dot(no)) < 2e-4]
            if len(on_plane) < 3:
                continue
            u = no.orthogonal().normalized()
            w = no.cross(u)
            pts = sorted({(round((p - co).dot(u), 5), round((p - co).dot(w), 5)) for p in on_plane})
            hull = hull2d(pts)
            cx = sum(p[0] for p in hull) / len(hull)
            cy = sum(p[1] for p in hull) / len(hull)
            ring = [b.verts.new(co + u * (cx + (x - cx) * 0.94) + w * (cy + (y - cy) * 0.94) - no * 0.002 * (1 if keep_jaw else -1))
                    for x, y in hull]
            mid = b.verts.new(co + u * cx + w * cy)
            for v in ring + [mid]:
                v[c2] = (0.12, 0.08, 0.07, 1.0)
            for i in range(len(ring)):
                f = (mid, ring[i], ring[(i + 1) % len(ring)])
                b.faces.new(f if keep_jaw else f[::-1])
        bmesh.ops.triangulate(b, faces=b.faces)
        b.verts.index_update()
        V = np.array([v.co[:] for v in b.verts])
        F = np.array([[v.index for v in f.verts] for f in b.faces])
        C = np.array([v[c2][:3] for v in b.verts])
        parts.append(Mesh(V, F, C))
        b.free()
    bm.free()
    return parts


def teeth_row(xs, y0, z0, down, specs):
    """Human teeth along an arch: specs (x, width, length, missing/broken factor). Yellow, dark at the gum."""
    out = []
    for x, wd, ln, keep in specs:
        if keep == 0:
            continue
        z = z0 + 1.6 * x * x
        ln = ln * keep
        m = L.sphere((0, 0, 0), 1.0, (wd / 2, ln / 2, 0.022), seg=8, rings=5)
        m.V += np.array((x, y0 + (-ln / 2 if down else ln / 2), z))
        t = (m.V[:, 1] - y0) * (-1 if down else 1) / max(ln, 1e-3)
        m.C = mixc(np.tile(TOOTH, (len(m.V), 1)), (0.16, 0.09, 0.05), S(0.35, 0.0, t))
        out.append(m)
    return L.join(*out)


def eyes_neon(at):
    """Two embers for pupils, set just behind the slits (Neon, no texture): only the slit shows them."""
    out = []
    for c, r in zip(at, (0.03, 0.027)):
        m = L.sphere(np.asarray(c) + np.array((0.0, -0.004, -0.024)), r, (1.0, 0.5, 0.4), seg=10, rings=6)
        out.append(m)
    return L.join(*out)


def head_pieces(pivot_to=None, scale=None, jaw_origin=None):
    pivot_to = NECK_PIVOT if pivot_to is None else pivot_to
    scale = HEAD_SCALE if scale is None else scale
    jaw_origin = JAW_ORIGIN if jaw_origin is None else jaw_origin
    h = head_colour(head_sculpt())
    global EYES_AT
    EYES_AT = h.eyes_at
    head, jaw = split_head(h)
    upper = teeth_row(None, -0.442, -0.44, True, [(-0.15, 0.05, 0.05, 1), (-0.1, 0.05, 0.06, 0.6), (-0.055, 0.05, 0.07, 1),
                                                   (-0.015, 0.045, 0.075, 1), (0.03, 0.048, 0.072, 0), (0.075, 0.05, 0.065, 1),
                                                   (0.12, 0.05, 0.06, 1), (0.16, 0.05, 0.05, 0.5)])
    lower = teeth_row(None, -0.448, -0.43, False, [(-0.13, 0.045, 0.05, 1), (-0.085, 0.04, 0.055, 1), (-0.04, 0.04, 0.06, 0),
                                                   (0.0, 0.04, 0.06, 1), (0.04, 0.04, 0.058, 1), (0.085, 0.045, 0.05, 0.4),
                                                   (0.13, 0.045, 0.05, 1)])
    head = L.join(head, upper)
    jaw = L.join(jaw, lower)
    for m_ in (head, jaw):  # a man's head on these shoulders, not a pinhead: scaled up round the neck joint
        m_.V = pivot_to + (m_.V - NECK_PIVOT) * scale
    EYES_AT = [pivot_to + (np.asarray(e) - NECK_PIVOT) * scale for e in EYES_AT]
    jaw.V -= jaw_origin
    return head, jaw


# ------------------------------------------------------------------ the figure on HollowBuilder's skeleton
GAME = {"SOOT": (46, 40, 38), "BURN": (98, 46, 36), "APRON": (66, 44, 30), "STRAP": (40, 28, 20), "IRON": (78, 72, 66),
        "RUST": (104, 62, 40), "EMBER": (255, 122, 42), "TOOTH": (196, 184, 148)}
GAME = {k: tuple(c / 255 for c in v) for k, v in GAME.items()}


def bone_frames(parent, at, upper, lower, end_y, bend=(0, 0)):
    """HollowBuilder limb(): Part1 = Part0 * C0 * Transform * C1^-1; boneC1(L) = Rz(-90) * T(0, L/2, 0)."""
    a = parent @ at @ A(bend[0]) @ T(0, -upper / 2, 0) @ A(0, 0, 90)
    b = a @ T(-upper / 2, 0, 0) @ A(0, 0, -90) @ A(bend[1]) @ T(0, -lower / 2, 0) @ A(0, 0, 90)
    c = b @ T(-lower / 2, 0, 0) @ A(0, 0, -90) @ T(0, -end_y / 2, 0)
    return a, b, c


def frames(reach=(0, 0)):
    root = T(0, 4.1 + 1.6, 0)
    pelvis = root @ T(0, -0.85, 0)
    chest = pelvis @ T(0, 0.62, 0) @ A(-24) @ T(0, 1.6, 0)
    head = chest @ T(0, 1.42, -0.75) @ A(20) @ T(0, 0.35, 0)
    jaw = head @ T(*JAW_ORIGIN)
    f = {"pelvis": pelvis, "chest": chest, "head": head, "jaw": jaw}
    for side, s_ in (("L", -1), ("R", 1)):
        end_y = 0.95 if side == "L" else 0.5
        f["upper" + side], f["fore" + side], f["hand" + side] = bone_frames(chest, T(s_ * 2.05, 1.0, 0.1), 2.5, 2.4, end_y, reach)
        f["thigh" + side], f["shin" + side], f["foot" + side] = bone_frames(pelvis, T(s_ * 0.75, -0.55, 0), 2.0, 1.85, 0.55)
    return f


def blocks(f):
    """The block Brute as HollowBuilder builds it today (the Performance version, and what the Test Launch has)."""
    P = L.prim
    P("box", (2.5, 1.3, 1.6), f["pelvis"], GAME["APRON"])
    P("box", (3.6, 3.2, 2.1), f["chest"], GAME["SOOT"])
    P("box", (1.15, 1.15, 1.2), f["head"], GAME["SOOT"])
    P("box", (1.0, 0.38, 1.0), f["jaw"], GAME["BURN"])
    for s_ in (-1, 1):
        P("ball", (1.9,), f["chest"] @ T(s_ * 1.45, 1.15, 0.2), GAME["SOOT"])
        P("box", (0.3, 3.5, 0.12), f["chest"] @ T(s_ * 0.75, 0.1, -1.23) @ A(0, 0, s_ * -8), GAME["STRAP"])
    P("box", (2.2, 2.3, 0.14), f["chest"] @ T(0, -0.45, -1.12), GAME["APRON"])
    P("box", (2.3, 2.2, 0.14), f["pelvis"] @ T(0, -1.25, -0.86), GAME["APRON"])
    for size, at in (((0.12, 1.4, 0.06), T(-1.2, 0.3, -1.08) @ A(0, 0, 25)), ((0.1, 0.9, 0.06), T(-1.45, -0.5, -1.08) @ A(0, 0, -15)),
                     ((0.12, 1.2, 0.06), T(1.25, 0.1, -1.08) @ A(0, 0, -30)), ((0.1, 1.6, 0.06), T(0.4, 0.6, 1.08) @ A(0, 0, 40)),
                     ((0.1, 1.1, 0.06), T(-0.6, -0.4, 1.08) @ A(0, 0, -20))):
        P("box", size, f["chest"] @ at, GAME["EMBER"], emit=8.0)
    for sx in (-0.24, 0.24):
        P("box", (0.24, 0.07, 0.06), f["head"] @ T(sx, 0.12, -0.6), GAME["EMBER"], emit=8.0)
    for i in (-1, 0, 1):
        P("box", (0.12, 0.2, 0.08), f["jaw"] @ T(i * 0.28, 0.27, -0.42), GAME["TOOTH"])
    for side in ("L", "R"):
        P("rod", (2.5, 1.05), f["upper" + side], GAME["SOOT"])
        P("rod", (2.4, 0.86), f["fore" + side], GAME["SOOT"])
        P("rod", (2.0, 0.95), f["thigh" + side], GAME["APRON"])
        P("rod", (1.85, 0.78), f["shin" + side], GAME["SOOT"])
        P("box", (1.0, 0.55, 1.5), f["foot" + side], GAME["STRAP"])
        P("rod", (0.5, 0.95), f["shin" + side] @ T(-0.7, 0, 0), GAME["STRAP"])
    P("box", (1.15, 0.95, 1.0), f["handL"], GAME["SOOT"])
    for k in (-1, 0, 1):
        P("ball", (0.42,), f["handL"] @ T(k * 0.36, -0.42, -0.4), GAME["BURN"])
    P("box", (0.5, 0.5, 0.5), f["handR"], GAME["IRON"])
    P("rod", (0.5, 1.2), f["foreR"] @ T(-1.15, 0, 0), GAME["RUST"])
    P("box", (1.7, 2.3, 0.16), f["handR"] @ T(0, -1.35, 0), GAME["IRON"])
    P("box", (1.5, 0.4, 0.2), f["handR"] @ T(0, -2.35, 0), GAME["RUST"])


# ------------------------------------------------------------------ the 12-stud Brute (owner 2026-11-17)
# A heavy man with ordinary proportions, 12 studs if it stood straight (it stoops to about 11.5). Its root box is
# taller than a building door (Config/Buildings DoorHeight 9), so it can't walk in; it reaches in instead.
# These numbers are mirrored in Config/BruteBody (Giant), which HollowBuilder reads when Tuning.BruteRemake is on.
G = {
    "hip": 5.2, "root": (2.8, 4.0, 2.2),
    "rootC0": (0, -1.1, 0), "pelvis": (2.6, 1.6, 2.0),
    "waistC0": (0, 0.85, 0), "lean": -12, "chestC1": (0, -1.6, 0), "chest": (3.0, 3.2, 2.3),
    "neckC0": (0, 1.75, -0.8), "neckTilt": 16, "headC1": (0, -0.55, 0), "head": (1.4, 1.6, 1.5),
    "jawC0": (0, -0.79, 0.36), "jawC1": (0, 0.144, 0.54), "jaw": (1.2, 0.45, 1.2),
    "shoulder": (1.5, 1.05, 0.05), "upper": 2.35, "fore": 2.15, "handL": 1.05, "handR": 0.6,
    "hipAt": (0.8, -0.4, 0), "thigh": 2.6, "shin": 2.55, "foot": 0.55,
}
G_PIVOT = np.array(G["headC1"], dtype=float)
G_HEAD_SCALE = 1.2
G_JAW_ORIGIN = np.array(G["jawC0"]) - np.array(G["jawC1"])


def frames_giant(reach=(0, 0)):
    root = T(0, G["hip"] + G["root"][1] / 2, 0)
    pelvis = root @ T(*G["rootC0"])
    chest = pelvis @ T(*G["waistC0"]) @ A(G["lean"]) @ T(*(-np.array(G["chestC1"])))
    head = chest @ T(*G["neckC0"]) @ A(G["neckTilt"]) @ T(*(-np.array(G["headC1"])))
    jaw = head @ T(*G_JAW_ORIGIN)
    f = {"pelvis": pelvis, "chest": chest, "head": head, "jaw": jaw}
    sx, sy, sz = G["shoulder"]
    hx, hy, hz = G["hipAt"]
    for side, s_ in (("L", -1), ("R", 1)):
        end_y = G["handL"] if side == "L" else G["handR"]
        f["upper" + side], f["fore" + side], f["hand" + side] = bone_frames(chest, T(s_ * sx, sy, sz), G["upper"], G["fore"], end_y, reach)
        f["thigh" + side], f["shin" + side], f["foot" + side] = bone_frames(pelvis, T(s_ * hx, hy, hz), G["thigh"], G["shin"], G["foot"])
    return f


def blocks_giant(f):
    """The giant's block build: the Performance version once the switch is on."""
    P = L.prim
    P("box", G["pelvis"], f["pelvis"], GAME["APRON"])
    P("box", G["chest"], f["chest"], GAME["SOOT"])
    P("box", G["head"], f["head"], GAME["SOOT"])
    P("box", G["jaw"], f["jaw"], GAME["BURN"])
    for s_ in (-1, 1):
        P("ball", (1.5,), f["chest"] @ T(s_ * 1.2, 1.15, 0.2), GAME["SOOT"])
        P("box", (0.3, 3.4, 0.12), f["chest"] @ T(s_ * 0.6, 0.1, -1.33) @ A(0, 0, s_ * -6), GAME["STRAP"])
    P("box", (1.9, 2.4, 0.14), f["chest"] @ T(0, -0.45, -1.32), GAME["APRON"])
    P("box", (2.2, 2.9, 0.14), f["pelvis"] @ T(0, -1.55, -1.08), GAME["APRON"])
    for size, at in (((0.12, 1.3, 0.06), T(-1.3, 0.2, -0.9) @ A(0, 0, 25)), ((0.12, 1.1, 0.06), T(1.35, 0.0, -0.9) @ A(0, 0, -30)),
                     ((0.1, 1.5, 0.06), T(0.4, 0.6, 1.18) @ A(0, 0, 40)), ((0.1, 1.0, 0.06), T(-0.6, -0.4, 1.18) @ A(0, 0, -20))):
        P("box", size, f["chest"] @ at, GAME["EMBER"], emit=8.0)
    for sx in (-0.26, 0.26):
        P("box", (0.22, 0.06, 0.06), f["head"] @ T(sx, 0.12, -0.72), GAME["EMBER"], emit=8.0)
    for side in ("L", "R"):
        P("rod", (G["upper"], 1.1), f["upper" + side], GAME["SOOT"])
        P("rod", (G["fore"], 0.95), f["fore" + side], GAME["SOOT"])
        P("rod", (G["thigh"], 1.3), f["thigh" + side], GAME["APRON"])
        P("rod", (G["shin"], 1.0), f["shin" + side], GAME["APRON"])
        P("box", (1.25, 0.55, 1.9), f["foot" + side], GAME["STRAP"])
    P("box", (1.2, 1.05, 1.1), f["handL"], GAME["SOOT"])
    P("box", (0.55, 0.6, 0.55), f["handR"], GAME["IRON"])
    P("rod", (2.6, 0.2), f["handR"] @ T(0, -1.3, 0) @ A(0, 0, 90), GAME["RUST"])
    P("box", (1.85, 1.5, 0.16), f["handR"] @ T(0, -3.4, 0), GAME["IRON"])


def fit_giant(name, m):
    """Each piece of this pass refitted to the giant's skeleton: lengths to its bones, girth to its size."""
    # lopsided from the work: the shovel arm huge and corded, the burnt left one shrunken
    if name in ("upperarmL", "upperarmR"):
        g = 1.46 if name == "upperarmR" else 1.12
        m.V *= np.array((G["upper"] / 2.5, g, g))
    elif name in ("forearmL", "forearmR"):
        g = 1.45 if name == "forearmR" else 1.08
        m.V *= np.array((G["fore"] / 2.4, g, g))
    elif name == "torso":
        m.V[:, 0] *= np.where(m.V[:, 0] > 0, 1.05, 0.95)  # the shovel side heavier
    elif name in ("thighL", "thighR"):
        m.V *= np.array((G["thigh"] / 2.0, 1.4, 1.4))
    elif name in ("shinL", "shinR"):
        m.V *= np.array((G["shin"] / 1.85, 1.3, 1.3))
    elif name in ("bootL", "bootR"):
        m.V *= 1.25
        m.V[:, 1] += 0.07
    elif name == "fist":
        m.V *= 1.1
    elif name == "shovel":
        m.V *= 1.15
        low = m.V[:, 1] < -0.9
        m.V[low, 1] -= 1.6  # a longer shaft: the blade still scrapes the ground
    elif name == "apron":
        m.V *= np.array((1.0, 1.25, 1.2))
    return m


PLACES = [("head", "head"), ("eyes", "head"), ("jaw", "jaw"), ("torso", "chest"), ("embers", "chest"), ("apron", "pelvis"),
          ("upperarmL", "upperL"), ("upperarmR", "upperR"), ("forearmL", "foreL"), ("forearmR", "foreR"),
          ("fist", "handL"), ("shovel", "handR"), ("thighL", "thighL"), ("thighR", "thighR"),
          ("shinL", "shinL"), ("shinR", "shinR"), ("bootL", "footL"), ("bootR", "footR")]


def figure(pieces, kind):
    """kind: 'block' (today's build), 'old' (the stored 11-13 remake) or 'new' (this pass)."""
    f = frames_giant() if GIANT and kind in ("new", "giant-block") else frames()
    if kind == "block":
        blocks(f)
    elif kind == "giant-block":
        blocks_giant(f)
    else:
        for name, frame in PLACES:
            key = name
            if kind == "old" and name[-1] in "LR" and name not in ("fist",):
                key = name[:-1]
            o = pieces.get(key)
            if o is not None:
                c = o.get("centre", (0, 0, 0))
                L.place(o, f[frame] @ T(c[0], c[1], c[2]))
    L.light("POINT", (f["chest"] @ T(0, 0.2, -1.6)).translation, 25, (1.0, 0.45, 0.15), size=0.4)  # the EmberGlow light
    return f


def ember_light(f):
    L.light("POINT", (f["chest"] @ T(0, 0.2, -1.6)).translation, 25, (1.0, 0.45, 0.15), size=0.4)


def renders(pieces, kind, tag, quick=False):
    smp = 16 if quick else 40
    f = figure(pieces, kind)
    head = f["head"].translation
    big = 1.4 if f["head"].translation.y > 9 else 1.0
    L.daylight(Vector((0, 4, 0)))
    L.camera(Vector((4.2, 6.5, -13.5)) * big, Vector((0, 5.0, 0)) * big, fov=48)
    L.render(RENDERS / f"{tag}-front.png", 1000, 1400, samples=smp)
    shots = [("face", lambda: L.daylight(head), head + Vector((1.4, -0.3, -4.2)), head + Vector((0, -0.5, 0)), 34),
             ("gaslight", lambda: L.gaslight(head), head + Vector((1.4, -0.3, -4.2)), head + Vector((0, -0.5, 0)), 34),
             ("back", lambda: L.daylight(Vector((0, 4.5, 0))), Vector((-6.5, 7.0, 7.5)) * big, Vector((0, 5.0, 0)) * big, 50),
             ("low", lambda: L.gaslight(Vector((0.5, 3.0, -1.0))), Vector((-3.2, 2.2, -6.0)), Vector((0.2, 2.2, 0)), 40)]
    if GIANT:  # the grab camera: lifted in his left hand, a stud from his face
        rootp = Vector((0, G["hip"] + G["root"][1] / 2, 0))
        eye = rootp + Vector((-0.7, 1.5 + 1.4, -3.6))
        shots.append(("grab", lambda: L.gaslight(head), eye, head + Vector((0, -0.3, 0)), 50))
    for name, lights, eye, at, fov in shots:
        L.clear_lights()
        ember_light(f)
        lights()
        L.camera(eye, at, fov=fov)
        L.render(RENDERS / f"{tag}-{name}.png", 1000, 1000, samples=smp)
    # close-ups for the sheet beside the references, in a plain soft light
    hl, hr = f["handL"].translation, f["handR"].translation
    ch = f["chest"].translation
    ft = (f["footL"].translation + f["footR"].translation) / 2
    closes = [("c-fist", hl + Vector((-1.6, 0.3, -1.9)), hl + Vector((0, -0.1, 0)), 30),
              ("c-shovel", hr + Vector((1.4, -0.6, -3.4)), hr + Vector((0, -1.1, 0)), 40),
              ("c-boots", ft + Vector((1.2, 0.9, -3.0)), ft + Vector((0, 0.3, 0)), 34),
              ("c-chest", ch + Vector((1.2, 0.6, -5.2)), ch + Vector((0, 0.2, 0)), 40),
              ("c-burn", ch + Vector((-4.6, 0.8, -1.4)), ch + Vector((-1.4, 0.0, 0)), 40)]
    for name, eye, at, fov in closes:
        L.clear_lights()
        ember_light(f)
        L.world((0.2, 0.21, 0.23), 1.0)
        L.light("SUN", Vector((3, 9, -6)), 2.2, (1, 0.96, 0.9), at_r=at)
        L.light("POINT", eye + Vector((-1.0, 1.0, 0)), 40, (1.0, 0.85, 0.7), size=0.5)
        L.camera(eye, at, fov=fov)
        L.render(RENDERS / f"{tag}-{name}.png", 800, 800, samples=smp)
    L.clear_figure()


def build_meshes():
    import body as B
    want = lambda k: ONLY is None or k in ONLY
    out = {}
    if GIANT:
        B.TS = np.array((0.82, 1.05, 1.0))
    if want("head"):
        head, jaw = head_pieces(G_PIVOT, G_HEAD_SCALE, G_JAW_ORIGIN) if GIANT else head_pieces()
        out["head"], out["jaw"] = head, jaw
        out["eyes"] = eyes_neon(EYES_AT)
    if want("torso"):
        out["torso"], out["embers"] = B.torso()
    if want("apron"):
        out["apron"] = B.apron_skirt()
    if want("arms"):
        for sd in ("L", "R"):
            out["upperarm" + sd] = B.upperarm(sd)
            out["forearm" + sd] = B.forearm(sd)
    if want("hands"):
        out["fist"] = B.fist()
        out["shovel"] = B.shovel()
    if want("legs"):
        for sd in ("L", "R"):
            out["thigh" + sd] = B.thigh(sd)
            out["shin" + sd] = B.shin(sd)
            out["boot" + sd] = B.boot(sd)
    if GIANT:
        out = {k: fit_giant(k, v) for k, v in out.items()}
    return out


SPECS = {  # triangles, texture size, occlusion distance
    "head": (2400, 1024, 0.12), "jaw": (900, 512, 0.1), "torso": (3600, 1024, 0.3), "apron": (2600, 1024, 0.3),
    "upperarmL": (700, 512, 0.15), "upperarmR": (700, 512, 0.15), "forearmL": (700, 512, 0.15), "forearmR": (900, 512, 0.15),
    "fist": (1000, 512, 0.08), "shovel": (1400, 512, 0.12), "thighL": (650, 512, 0.15), "thighR": (600, 512, 0.15),
    "shinL": (650, 512, 0.12), "shinR": (650, 512, 0.12), "bootL": (1000, 512, 0.08), "bootR": (950, 512, 0.08),
}
NEON = {"eyes": 80, "embers": 500}


OLD_NAMES = ("head", "jaw", "torso", "apron", "upperarm", "forearm", "fist", "shovel", "thigh", "shin", "boot", "eyes", "embers")


def import_old(shelf=None, names=OLD_NAMES):
    """Exported pieces read back from their FBX and PNG files (the stored 11-13 remake given with
    --old <dir>, or this pass's out/ folder), placed by their report.json centres: exactly what would be uploaded."""
    shelf = shelf or Path(ARGS[ARGS.index("--old") + 1])  # the stored remake's folder: --old <dir>
    rep = json.loads((shelf / "report.json").read_text())
    out = {}
    for name in names:
        bpy.ops.import_scene.fbx(filepath=str(shelf / f"brute_{name}.fbx"))
        o = bpy.context.selected_objects[0]
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        o.name = "old_" + name
        o.hide_render = True
        mat = bpy.data.materials.new("old_" + name)
        mat.use_nodes = True
        b = mat.node_tree.nodes["Principled BSDF"]
        b.inputs["Roughness"].default_value = 0.85
        if (shelf / f"brute_{name}.png").exists():
            img = bpy.data.images.load(str(shelf / f"brute_{name}.png"))
            t = mat.node_tree.nodes.new("ShaderNodeTexImage")
            t.image = img
            mat.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"])
            for suffix in ("normal", "rough"):  # the SurfaceAppearance maps, when this pass baked them
                fp = shelf / f"brute_{name}_{suffix}.png"
                if not fp.exists():
                    continue
                im = bpy.data.images.load(str(fp))
                im.colorspace_settings.name = "Non-Color"
                tn = mat.node_tree.nodes.new("ShaderNodeTexImage")
                tn.image = im
                if suffix == "normal":
                    nm = mat.node_tree.nodes.new("ShaderNodeNormalMap")
                    mat.node_tree.links.new(tn.outputs["Color"], nm.inputs["Color"])
                    mat.node_tree.links.new(nm.outputs["Normal"], b.inputs["Normal"])
                else:
                    mat.node_tree.links.new(tn.outputs["Color"], b.inputs["Roughness"])
        else:
            b.inputs["Base Color"].default_value = (1.0, 0.2, 0.03, 1)
            b.inputs["Emission Color"].default_value = (1.0, 0.2, 0.03, 1)
            b.inputs["Emission Strength"].default_value = 8.0
        o.data.materials.clear()
        o.data.materials.append(mat)
        o["centre"] = rep["brute_" + name]["center"]
        out[name] = o
    return out


def main():
    L.clear()
    L.world((0.18, 0.19, 0.21))
    if "--render-only" in ARGS:
        renders(import_old(L.OUT, [k for k in list(SPECS) + list(NEON)]), "new", "giant" if GIANT else "after")
        return
    if "--giant-blocks" in ARGS:
        renders({}, "giant-block", "giant-block")
        return
    if "--before-only" in ARGS:
        renders({}, "block", "before-block")
        renders(import_old(), "old", "before-remake")
        return
    meshes = build_meshes()
    objs, report = {}, {}
    for name, m in meshes.items():
        full = "brute_" + name
        if name in NEON:
            o = L.neon_piece(full, m, NEON[name])
        elif PREVIEW:
            o = L.preview(full, m)
        else:
            tri, size, ao = SPECS[name]
            o = L.piece(full, m, tri, size, ao)
            print("baked", full, L.tris(o))
        objs[name] = o
    if not PREVIEW:
        old = L.OUT / "report.json"
        if ONLY is not None and old.exists():  # a partial rebuild keeps the other pieces' rows
            report.update({k: v for k, v in json.loads(old.read_text()).items() if isinstance(v, dict)})
        for name, o in objs.items():
            L.export(o, report, None if name in NEON else o.name + ".png")
        report["figure_tris"] = sum(v["tris"] for k, v in report.items() if isinstance(v, dict))
        (L.OUT / "report.json").write_text(json.dumps(report, indent=1))
        print(json.dumps({k: v.get("tris") if isinstance(v, dict) else v for k, v in report.items()}))
    for name, o in objs.items():
        o.hide_render = True
    if "--no-render" in ARGS:
        return
    renders(objs, "new", ("wip" if PREVIEW else ("giant" if GIANT else "after")), quick=PREVIEW)


if __name__ == "__main__":
    main()
