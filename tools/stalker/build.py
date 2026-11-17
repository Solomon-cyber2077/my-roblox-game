"""Close-up meshes and textures for the Stalker (Builders/HollowBuilder stalker).

The lost porter: too tall, too thin, in the rags of a railway greatcoat. Seen at arm's length in a grab, on a
phone, under gaslight, so the read has to come from shape and value, not from small parts:
  head     a long skull under skin drawn tight: brow ridge, two separate deep sockets (the red pinprick sits on
           each socket floor), cheekbones over fallen cheeks, sunken temples, a collapsed nose, thin uneven
           upper teeth set in a receded gum, and the crushed porter's cap with its peak and badge
  jaw      a narrow mandible and chin with its own thin lower teeth; it rides the Jaw joint, so the gape opens
  torso    the coat's upper body (hunched back, torn lapels, double row of tarnished buttons, stand collar)
           open over a starved chest: ribs and sternum under grey skin, a dark rag of shirt and waistcoat
  coat     the skirt, from the waist to tails torn at seven places, the back vent, a muddy ragged hem
  sleeve   folds bunched at the elbow, a frayed open cuff with hanging shreds
  forearm  two bones under the skin, tendons at the wrist, the elbow knob
  hand     long fingers with knuckles in the profile, curled claws, stained dark with old blood
Each piece is one mesh with one colour texture (detail lives in the texture: grime, seams, stains, veins,
baked occlusion). Performance keeps the block build (Builders/HollowBuilder tags those DetailFallback).

  blender -b --python tools/stalker/build.py [-- --no-render]

Writes tools/stalker/out/<name>.fbx and <name>.png (the TextureID image), report.json (size and centre in
studs, triangles) and the renders sheet.png, front.png, face.png, gaslight.png, phone.png. Axes: +Y up,
front -Z. Arm bones run along X, proximal end at +X (the joint). One Blender unit = one stud.
"""

import json
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from mathutils import noise as mn

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools" / "stalker" / "out"
OUT.mkdir(parents=True, exist_ok=True)

TAU = math.tau


def S(a, b, x):
    """Smoothstep from a to b (a may be above b)."""
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def G(d, w):
    return math.exp(-((d / w) ** 2))


def nz(p, s, octaves=1):
    p = Vector(p) * s
    total, amp, norm = 0.0, 1.0, 0.0
    for _ in range(octaves):
        total += mn.noise(p) * amp
        norm += amp
        amp *= 0.5
        p *= 2.03
    return total / norm


def lin(c):
    """Design colours are picked as sRGB; vertex colours and shaders want linear."""
    return tuple(max(0.0, v) ** 2.2 for v in c)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def mul(a, k):
    return tuple(x * k for x in a)


# palette (sRGB)
SKIN = (0.50, 0.49, 0.42)  # waxy pallor
SKIN_HOLLOW = (0.25, 0.26, 0.22)  # grey-green in the hollows
BRUISE = (0.24, 0.16, 0.16)
VEIN = (0.30, 0.32, 0.40)
VOID = (0.012, 0.009, 0.009)
ICHOR = (0.06, 0.035, 0.03)
GUM = (0.30, 0.15, 0.14)
MOUTH = (0.08, 0.015, 0.015)
LIP = (0.34, 0.22, 0.20)
TOOTH = (0.60, 0.53, 0.37)
TOOTH_ROOT = (0.22, 0.13, 0.08)
BLOOD = (0.30, 0.07, 0.06)
BLOOD_WET = (0.40, 0.07, 0.07)
NAIL = (0.20, 0.17, 0.12)
WOOL = (0.085, 0.095, 0.075)  # bottle-green serge gone near black
WOOL_WORN = (0.17, 0.18, 0.15)
SEAM = (0.03, 0.03, 0.028)
STITCH = (0.22, 0.21, 0.17)
MUD = (0.17, 0.14, 0.10)
MILDEW = (0.20, 0.22, 0.17)
BRASS = (0.34, 0.26, 0.11)
VERDIGRIS = (0.20, 0.27, 0.20)
LEATHER = (0.035, 0.032, 0.03)
SHIRT = (0.13, 0.12, 0.10)
WAISTCOAT = (0.07, 0.06, 0.05)
HAIR = (0.13, 0.13, 0.12)


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def new_bm():
    bm = bmesh.new()
    col = bm.verts.layers.float_color.new("col")
    return bm, col


def loft(bm, rings, closed=True, cap0=False, cap1=False):
    """Faces between consecutive rings of verts (lists of BMVert). Winding: ring i -> i+1, s -> s+1."""
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        n = len(a)
        for s in range(n if closed else n - 1):
            bm.faces.new((a[s], a[(s + 1) % n], b[(s + 1) % n], b[s]))
    if cap0:
        bm.faces.new(rings[0][::-1])
    if cap1:
        bm.faces.new(rings[-1])


def orient(bm, outward):
    """Flip each face whose normal points against outward(centre) (open sheets have no inside to recalc from)."""
    bm.normal_update()
    flip = [f for f in bm.faces if f.normal.dot(outward(f.calc_center_median())) < 0]
    bmesh.ops.reverse_faces(bm, faces=flip)


def paint(vert, col, c):
    vert[col] = (*lin(c), 1)


def tube_rings(bm, col, pts, radii, sides, flat=1.0, colour=None, roll=0.0):
    """Rings of verts along pts (Roblox axes); colour(i, s, co) -> sRGB."""
    rings = []
    n = len(pts)
    for i, (p, r) in enumerate(zip(pts, radii)):
        p = Vector(p)
        a = (Vector(pts[min(i + 1, n - 1)]) - Vector(pts[max(i - 1, 0)])).normalized()
        up = Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((1, 0, 0))
        u = a.cross(up).normalized()
        v = a.cross(u).normalized()
        ring = []
        for s in range(sides):
            t = s / sides * TAU + roll
            co = p + u * (math.cos(t) * r) + v * (math.sin(t) * r * flat)
            vert = bm.verts.new(co)
            paint(vert, col, colour(i, s, co) if colour else SKIN)
            ring.append(vert)
        rings.append(ring)
    return rings


def resample(pts, radii, n):
    """n evenly spaced samples along a polyline, radii interpolated."""
    pts = [Vector(p) for p in pts]
    seg = [(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
    total = sum(seg)
    out_p, out_r = [], []
    for k in range(n):
        d = total * k / (n - 1)
        i = 0
        while i < len(seg) - 1 and d > seg[i]:
            d -= seg[i]
            i += 1
        t = min(1.0, d / seg[i]) if seg[i] else 0.0
        out_p.append(pts[i].lerp(pts[i + 1], t))
        out_r.append(radii[i] + (radii[i + 1] - radii[i]) * t)
    return out_p, out_r


def teeth(bm, col, specs):
    """Thin uneven teeth: (root, direction, length, radius). Yellowed bone, dark at the root."""
    for root, d, length, r in specs:
        root, d = Vector(root), Vector(d).normalized()
        pts = [root + d * (length * f) for f in (0.0, 0.35, 0.75, 1.0)]
        rad = [r * 0.9, r, r * 0.7, r * 0.18]
        rings = tube_rings(bm, col, pts, rad, 6, flat=0.62,
                           colour=lambda i, s, co: mix(TOOTH_ROOT, TOOTH, i / 2.0) if i < 3 else mul(TOOTH, 0.8))
        loft(bm, rings, cap0=True, cap1=True)


# ------------------------------------------------------------------ head
SOCKETS = (-0.185, 0.185)
SOCKET_Y = 0.165


def head_high():
    """In the Head part's frame (block 0.82 x 1.4 x 0.98, face -Z). Pinpricks sit at (+-0.2, 0.16, -0.14)."""
    bm, col = new_bm()
    bmesh.ops.create_uvsphere(bm, u_segments=128, v_segments=96, radius=0.5)
    for v in bm.verts:
        n = v.co / 0.5
        x, y, z = n.x * 0.37, n.y * 0.70, n.z * 0.49
        if z > 0:  # the cranium swells behind
            z *= 1.0 + 0.12 * S(-0.2, 0.5, y)
        k = S(-0.05, -0.70, y)  # the lower face narrows to a long thin maxilla
        x *= 1 - 0.38 * k
        if z < 0:
            z *= 1 - 0.12 * k
        F = S(-0.02, -0.30, z)
        sgn = 1.0 if x >= 0 else -1.0
        ax = abs(x)
        z += 0.07 * S(0.36, 0.72, y) * F  # forehead slopes back
        z -= 0.06 * G(y - 0.315, 0.05) * G(x, 0.30) * F  # brow ridge
        z += 0.012 * G(x, 0.04) * G(y - 0.31, 0.06) * F  # glabella dip
        sock, rim, under = 0.0, 0.0, 0.0
        for sx in SOCKETS:
            dx, dy = x - sx, y - SOCKET_Y
            a = 0.18 if sx > 0 else -0.18  # the outer corners droop
            u = dx * math.cos(a) + dy * math.sin(a)
            w = -dx * math.sin(a) + dy * math.cos(a)
            e = math.sqrt((u / 0.12) ** 2 + (w / 0.104) ** 2)
            if e < 1:
                b = 1 - e ** 6
                z += 0.36 * b * F
                sock = max(sock, b)
            z -= 0.022 * G(e - 1.12, 0.14) * F  # the bony rim
            rim = max(rim, G(e - 1.0, 0.45) * (1 if e > 0.85 else 0))
            under = max(under, G(dx, 0.1) * G(dy + 0.13, 0.05))  # the shadow under the lower rim
        # nose: a stub of bone, then the cavity where it fell in
        z -= 0.025 * G(x, 0.035) * G(y - 0.05, 0.05) * F
        ny = y + 0.075
        wn = 0.028 + 0.25 * max(0.0, min(0.08, 0.04 - ny))
        en = math.sqrt((x / wn) ** 2 + (ny / 0.065) ** 2)
        nose = 0.0
        if en < 1:
            nose = 1 - en ** 3
            z += 0.14 * nose * F
        # cheekbones, the arch running back, and the cheek fallen in below
        cb = G(ax - 0.235, 0.06) * G(y - 0.03, 0.045)
        z -= 0.035 * cb * F
        x += sgn * 0.05 * G(y - 0.03, 0.04) * S(0.15, -0.15, z) * S(0.2, 0.3, ax)
        ch = G(ax - 0.2, 0.085) * G(y + 0.27, 0.12)
        z += 0.12 * ch * F
        chs = G(y + 0.25, 0.14) * S(0.2, 0.3, ax) * S(0.2, -0.2, z)
        x -= sgn * 0.07 * chs
        # temples sunk behind the outer rim
        tp = G(y - 0.22, 0.11) * G(z + 0.1, 0.16) * S(0.18, 0.3, ax)
        x -= sgn * 0.085 * tp
        # the mouth: lips gone back from a receded gum, a dark pit behind the teeth
        mm = S(0.19, 0.14, ax) * S(-0.385, -0.42, y)
        zb = -0.27 + 1.3 * x * x
        if z < zb:
            z += (zb - z) * mm
        z -= 0.02 * G(y + 0.405, 0.015) * S(0.17, 0.12, ax) * F  # the gum ledge
        tuck = S(-0.56, -0.62, y) * S(0.27, 0.2, ax)  # the chin belongs to the jaw: tuck in behind it
        if z < -0.18:
            z += (-0.18 - z) * tuck
        p = Vector((x, y, z))
        p += n * (0.004 * nz(p, 14))
        v.co = p

        c = mul(SKIN, 0.9 + 0.16 * nz(p, 7, 3))
        c = mix(c, SKIN_HOLLOW, 0.95 * ch + 0.9 * tp + 0.6 * chs + 0.6 * under + 0.5 * G(ax - 0.3, 0.06) * G(y + 0.1, 0.08))
        c = mul(c, 0.86 + 0.14 * S(0.0, 0.5, cb))  # light only on the bone
        if tp > 0.15 and abs(nz(p * Vector((1, 0.35, 1)), 11)) < 0.06:
            c = mix(c, VEIN, 0.55)
        if 0.36 < y < 0.62 and F > 0.5 and math.sin(y * 95 + 3 * nz(p, 4)) > 0.8:
            c = mul(c, 0.7)  # forehead creases
        if nz(p * Vector((1, 3, 1)), 18) > 0.3:
            c = mul(c, 0.8)  # skin drawn into fine lines
        c = mix(c, (0.30, 0.27, 0.22), 0.45 * S(0.1, 0.6, nz(p, 3, 2)))  # old grime
        c = mix(c, BRUISE, 0.8 * rim * F)
        c = mix(c, VOID, S(0.05, 0.4, sock))
        for sx, length in ((-0.185, 0.36), (0.185, 0.52)):  # an ichor run from each socket
            streak = G(x - sx - 0.018 * math.sin(y * 21 + sx * 9), 0.013) * S(0.1, 0.06, y) * S(0.1 - length, 0.05 - length * 0.6, y)
            c = mix(c, ICHOR, 0.85 * streak * F)
        c = mix(c, VOID, S(0.0, 0.5, nose))
        if mm > 0.3:
            c = mix(c, LIP, S(-0.37, -0.40, y))
            c = mix(c, GUM, S(-0.395, -0.415, y))
            c = mix(c, MOUTH, S(-0.43, -0.46, y))
        if z > 0 and 0.28 < y < 0.58 and nz(p * Vector((5, 0.6, 5)), 6) > 0.1:
            c = mix(c, HAIR, 0.85)  # what is left of the hair, under the cap
        c = mul(c, 0.82 + 0.18 * S(-0.7, -0.35, y))  # grime toward the chin
        paint(v, col, c)

    cap(bm, col)
    return bm


def cap(bm, col):
    """The porter's cap, crushed and pushed back: crown, band, peak, tarnished badge."""
    tilt = Matrix.Translation((0, 0.6, 0)) @ Matrix.Rotation(math.radians(-7), 4, "Z") @ Matrix.Rotation(math.radians(-6), 4, "X") @ Matrix.Translation((0, -0.6, 0))

    def colour(i, co):
        c = mul(WOOL, 0.85 + 0.3 * nz(co, 9, 2))
        if co.y < 0.585:
            c = mul(c, 0.55)  # the band
        if i >= 4:
            c = mix(c, WOOL_WORN, 0.6 * S(0.3, 0.9, nz(co, 5)))  # the crown worn through to the felt
        if co.z < -0.3 and abs(co.x) < 0.05 and 0.585 < co.y < 0.655:
            c = mix(BRASS, VERDIGRIS, S(0.0, 0.5, nz(co, 40)))
        if co.x > 0.25 and 0.59 < co.y < 0.69 and nz(co, 12) > 0.25:
            c = VOID  # a tear in the crown
        return c

    pts = [(0, 0.50, 0.03), (0, 0.55, 0.03), (0, 0.60, 0.04), (0, 0.66, 0.05), (0, 0.71, 0.07), (0, 0.735, 0.07),
           (0, 0.70, 0.07), (0, 0.68, 0.07)]
    rad = [0.316, 0.32, 0.335, 0.355, 0.37, 0.33, 0.17, 0.02]
    rings = []
    for i, (p, r) in enumerate(zip(pts, rad)):
        ring = []
        for s in range(48):
            t = s / 48 * TAU
            dent = 1 - 0.06 * G(math.atan2(math.sin(t - 2.2), math.cos(t - 2.2)), 0.7) * (1 if i >= 4 else 0)
            co = Vector((p[0] + math.cos(t) * r * dent, p[1] - 0.03 * (i >= 5) * nz((t, i, 0), 2), p[2] - math.sin(t) * r * 1.27 * dent))
            co = tilt @ co
            vert = bm.verts.new(co)
            paint(vert, col, colour(i, co))
            ring.append(vert)
        rings.append(ring)
    loft(bm, rings, cap0=True, cap1=True)
    # the peak: a stiff leather half-moon dipping over the brow, a closed slab
    cols, rows = 20, 3
    layers = []
    for off in (0.0, 0.018):
        grid = []
        for r in range(rows):
            row = []
            for c in range(cols):
                t = math.radians(-72 + 144 * c / (cols - 1))
                reach = 0.15 * r / (rows - 1)
                x = math.sin(t) * (0.318 + reach * 0.6)
                z = -math.cos(t) * (0.40 + reach)
                y = 0.535 - reach * 0.45 - off - 0.01 * nz((x * 9, z * 9, 0), 1)
                co = tilt @ Vector((x, y, z))
                vert = bm.verts.new(co)
                paint(vert, col, mul(LEATHER, 2.6) if nz(co, 30) > 0.45 else LEATHER)
                row.append(vert)
            grid.append(row)
        layers.append(grid)
    g0, g1 = layers
    for r in range(rows - 1):
        for c in range(cols - 1):
            bm.faces.new((g0[r][c], g0[r][c + 1], g0[r + 1][c + 1], g0[r + 1][c]))
            bm.faces.new((g1[r + 1][c], g1[r + 1][c + 1], g1[r][c + 1], g1[r][c]))
    for c in range(cols - 1):
        for r in (0, rows - 1):
            bm.faces.new((g0[r][c], g1[r][c], g1[r][c + 1], g0[r][c + 1]))
    for r in range(rows - 1):
        for c in (0, cols - 1):
            bm.faces.new((g0[r][c], g0[r + 1][c], g1[r + 1][c], g1[r][c]))


UPPER_TEETH = [  # x, length, tilt, radius: uneven, one missing, one broken
    (-0.118, 0.085, -0.10, 0.014), (-0.080, 0.105, -0.04, 0.016), (-0.034, 0.12, 0.02, 0.018),
    (0.012, 0.115, 0.05, 0.017), (0.058, 0.05, 0.0, 0.016), (0.112, 0.095, 0.12, 0.014),
]


def upper_teeth(bm, col):
    specs = []
    for x, length, tilt, r in UPPER_TEETH:
        z = -0.305 + 1.3 * x * x
        specs.append(((x, -0.41, z), (tilt, -1, -0.12), length, r))
    teeth(bm, col, specs)


# ------------------------------------------------------------------ jaw
JAW_FRAME = Vector((0, -0.80, -0.12))  # the Jaw part's centre in the Head frame at rest (HollowBuilder Jaw joint)


def jaw_high():
    """Built in the Head frame (moved to the Jaw frame by to_jaw_frame). A narrow chin, the mandible's angle
    under the cheek, the lower lip gone back from thin lower teeth."""
    bm, col = new_bm()
    bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=40, radius=0.5)
    for v in bm.verts:
        n = v.co / 0.5
        x, y, z = n.x * 0.27, n.y * 0.17, n.z * 0.25
        y += -0.71
        z += -0.17
        F = S(-0.12, -0.36, z)
        x *= 1 - 0.5 * S(-0.15, -0.42, z)  # a narrow pointed chin
        sgn = 1.0 if x >= 0 else -1.0
        ax = abs(x)
        z -= 0.045 * G(x, 0.07) * G(y + 0.83, 0.05)  # the chin knob
        x += sgn * 0.022 * G(y + 0.78, 0.04) * S(-0.05, 0.08, z)  # the jaw's angle
        x -= sgn * 0.03 * G(y + 0.69, 0.05) * S(-0.1, 0.0, z) * S(0.12, 0.2, ax)  # hollow under the cheek
        lipm = S(-0.64, -0.59, y) * F
        z += 0.07 * lipm  # the lower lip drawn back
        if y > -0.57:
            y = -0.57 + (y + 0.57) * 0.35  # flat top where it meets the head
        p = Vector((x, y, z))
        p += n * (0.003 * nz(p, 16))
        v.co = p
        c = mul(SKIN, 0.86 + 0.16 * nz(p, 8, 3))
        c = mix(c, SKIN_HOLLOW, 0.6 * G(y + 0.69, 0.05) * S(0.12, 0.2, ax))
        c = mix(c, LIP, lipm * S(-0.61, -0.59, y))
        c = mix(c, GUM, lipm * S(-0.595, -0.58, y))
        c = mix(c, MOUTH, S(-0.585, -0.575, y))
        if nz(p, 60) > 0.35 and y < -0.62:
            c = mul(c, 0.7)  # grey stubble
        drip = G(x + 0.03 + 0.01 * math.sin(y * 30), 0.018) * S(-0.6, -0.66, y) * F  # ichor run off the lip
        c = mix(c, ICHOR, 0.8 * drip)
        paint(v, col, mul(mix(c, SKIN_HOLLOW, 0.3), 0.75))  # in the shadow of the face
    return bm


LOWER_TEETH = [(-0.085, 0.07, 0.10, 0.013), (-0.04, 0.085, 0.0, 0.015), (0.0, 0.04, -0.05, 0.015),
               (0.042, 0.09, -0.06, 0.014), (0.088, 0.065, -0.14, 0.012)]


def lower_teeth(bm, col):
    specs = []
    for x, length, tilt, r in LOWER_TEETH:
        z = -0.29 + 1.3 * x * x
        specs.append(((x, -0.61, z), (tilt, 1, -0.08), length, r))
    teeth(bm, col, specs)


def to_jaw_frame(bm):
    for v in bm.verts:
        v.co -= JAW_FRAME


# ------------------------------------------------------------------ torso
def keys(table, y):
    for (y0, a), (y1, b) in zip(table, table[1:]):
        if y <= y1:
            return a + (b - a) * S(y0, y1, y) if y >= y0 else a
    return table[-1][1]


TORSO_W = [(-1.4, 0.66), (-0.6, 0.63), (0.3, 0.70), (0.85, 0.86), (1.1, 0.95), (1.3, 0.72), (1.42, 0.36)]
TORSO_D = [(-1.4, 0.47), (0.3, 0.48), (1.1, 0.47), (1.42, 0.27)]
OPEN = [(-1.4, 0.42), (0.0, 0.62), (0.8, 0.75), (1.3, 0.55), (1.6, 0.6)]


def body_point(theta, w, d, n=2.6):
    s, c = math.sin(theta), math.cos(theta)
    x = w * math.copysign(abs(s) ** (2 / n), s)
    z = -d * math.copysign(abs(c) ** (2 / n), c)
    return x, z


def wool(co, k=1.0):
    c = mul(WOOL, (0.8 + 0.35 * nz(co, 6, 3)) * k)
    return mix(c, MILDEW, 0.5 * S(0.35, 0.7, nz(co * Vector((3, 0.25, 3)), 3)))


def torso_high():
    """In the Chest part's frame (block 1.45 x 2.8 x 0.95; the waist leans it forward 27 degrees)."""
    bm, col = new_bm()
    rnd = random.Random(5)
    buttons = []
    for side in (-1, 1):
        for by in (-0.95, -0.45, 0.05, 0.55):
            if rnd.random() > 0.3:
                buttons.append((side, by, rnd.random() > 0.5))
    rows, cols = 46, 72
    rings = []
    for r in range(rows):
        y = -1.4 + 3.0 * r / (rows - 1)  # up to 1.6: the stand collar
        collar = y > 1.38
        w = 0.33 + 0.02 * S(1.38, 1.6, y) if collar else keys(TORSO_W, y)
        d = 0.27 + 0.02 * S(1.38, 1.6, y) if collar else keys(TORSO_D, y)
        o = keys(OPEN, y) + 0.05 * nz((y * 6, 1, 2), 1)
        ring = []
        for c in range(cols):
            theta = o + (TAU - 2 * o) * c / (cols - 1)
            x, z = body_point(theta, w, d)
            edge = min(theta - o, TAU - o - theta)
            lapel = S(0.25, 0.0, edge) * S(1.3, 0.9, y) * S(-1.2, -0.6, y)
            k = 1 + 0.06 * lapel
            # folds: the drape down the back, diagonals off the armpit, the waist creased by the lean
            k += 0.012 * math.sin(theta * 9 + y * 2) * S(0.3, -1.2, y) * S(0.8, 0.2, math.cos(theta) + 1)
            k += 0.012 * math.sin((y + 0.6 * abs(x)) * 14) * S(0.3, 0.6, abs(math.sin(theta)))
            k += 0.02 * math.sin(y * 25) * G(y + 1.2, 0.2)
            x, z = x * k, z * k
            if z > 0:
                z += 0.09 * G(y - 0.75, 0.45)  # the hunch
            co = Vector((x, y, z - 0.03 * lapel))
            cc = wool(co)
            cc = mix(cc, WOOL_WORN, 0.6 * S(0.08, 0.0, edge) + 0.35 * G(y - 1.15, 0.1) * S(0.5, 0.8, abs(x)))
            if abs(abs(theta - math.pi) - math.pi / 2) < 0.02 or abs(theta - math.pi) < 0.015 or abs(y - 1.2) < 0.012:
                cc = STITCH if int(y * 40 + theta * 40) % 3 == 0 else SEAM
            for side, by, missing in buttons:
                bt = o + 0.13 if side > 0 else TAU - o - 0.13
                if math.hypot((theta - bt) * 0.7, y - by) < 0.035:
                    cc = SEAM if missing else mix(BRASS, VERDIGRIS, S(0.0, 0.6, nz(co, 50)))
            if nz(co, 3.5) > 0.42 and edge > 0.3:
                cc = VOID  # a rent in the cloth
            if y < -1.05:
                cc = mix(cc, MUD, 0.4 * S(-1.05, -1.4, y))
            vert = bm.verts.new(co)
            paint(vert, col, cc)
            ring.append(vert)
        rings.append(ring)
    loft(bm, rings, closed=False)

    # the starved chest inside the open coat
    rings = []
    for r in range(40):
        y = -1.35 + 2.7 * r / 39
        o = keys(OPEN, y) + 0.32
        w = keys(TORSO_W, y) * 0.84
        d = keys(TORSO_D, y) * 0.9
        ring = []
        for c in range(30):
            theta = -o + 2 * o * c / 29
            x, z = body_point(theta, w, d)
            ph = y + 0.18 * abs(x)  # the ribs sweep down to the sides
            rib = max(0.0, math.sin(ph * math.pi / 0.27)) ** 2 * S(-0.75, -0.45, y) * S(0.95, 0.7, y)
            z -= 0.022 * rib
            z -= 0.022 * G(x, 0.05) * S(-0.5, -0.2, y) * S(0.95, 0.7, y)  # sternum
            z += 0.07 * S(-0.55, -1.1, y) * G(x, 0.4)  # the belly fallen in under the ribs
            z -= 0.02 * G(y - 1.12, 0.04) * S(0.04, 0.12, abs(x))  # collarbones
            co = Vector((x, y, z))
            cc = mix(mul(SKIN, 0.7 + 0.12 * nz(co, 8, 2)), SKIN_HOLLOW, 0.8 * (1 - rib) * S(-0.6, 0.8, y))
            rent = G(x + 0.05 * math.sin(y * 3), 0.14) * S(-0.6, -0.3, y) * S(1.05, 0.75, y)
            shirt = 0.35 - rent * 0.9 + 0.3 * nz(co * Vector((1, 0.5, 1)), 6, 2)
            if shirt > 0.0:
                cc = mix(SHIRT, mul(SHIRT, 0.6), S(0.0, 0.5, nz(co, 15)))
            if y < -0.55 and shirt > -0.15:
                cc = BRASS if abs(x) < 0.03 and math.sin(y * 34) > 0.92 else WAISTCOAT
            drip = G(x - 0.04 + 0.02 * math.sin(y * 9), 0.02) * S(1.3, 0.9, y) * S(0.1, 0.5, y)
            cc = mix(cc, ICHOR, 0.75 * drip)
            vert = bm.verts.new(co)
            paint(vert, col, cc)
            ring.append(vert)
        rings.append(ring)
    loft(bm, rings, closed=False)
    orient(bm, lambda p: Vector((p.x, 0, p.z)).normalized() if p.x * p.x + p.z * p.z > 1e-6 else Vector((0, 0, -1)))
    return bm


# ------------------------------------------------------------------ coat skirt
TEARS = [1.25, 1.9, 2.5, math.pi, 3.78, 4.38, 5.03]


def coat_high():
    """In the Pelvis frame: from the waist, over the pelvis block, to tails torn at seven places and the back
    vent, the hem ragged and muddy. Two buttons at the top of the vent."""
    bm, col = new_bm()
    rnd = random.Random(11)
    cols, rows = 84, 44
    o = 0.42
    tear_start = [rnd.uniform(0.38, 0.58) for _ in TEARS]
    hem = [1 - 0.22 * (0.5 + 0.5 * nz((c * 0.45, 3, 0), 1)) - 0.06 * rnd.random() for c in range(cols)]
    holes = [(rnd.uniform(1.0, 5.3), rnd.uniform(0.3, 0.7), rnd.uniform(0.03, 0.06)) for _ in range(5)]
    grid = []
    for r in range(rows):
        t = r / (rows - 1)
        row = []
        for c in range(cols):
            theta = o + (TAU - 2 * o) * c / (cols - 1)
            back = (1 - math.cos(theta)) / 2
            length = 3.1 + 0.85 * back + 0.75  # 0.75 of it over the pelvis block
            y = 0.35 - t * length
            R = 1 + 0.38 * S(0.18, 1.0, t)
            R *= 1 + 0.06 * S(0.15, 1.0, t) * math.sin(theta * 9 + 1.7 * math.sin(theta * 3))
            x = 0.79 * R * math.sin(theta)
            z = -0.52 * R * math.cos(theta) + 0.25 * t * t * back
            co = Vector((x, y, z))
            fr = min(abs(theta - tt) for tt in TEARS)
            cc = wool(co)
            cc = mix(cc, WOOL_WORN, 0.7 * S(0.1, 0.0, fr) * S(0.3, 0.5, t))  # fibres pulled at the tears
            if abs(abs(theta - math.pi) - math.pi / 2) < 0.012 or abs(t - 0.17) < 0.006:
                cc = STITCH if r % 2 else SEAM
            if abs(abs(theta - math.pi) - 0.09) < 0.02 and abs(y + 0.45) < 0.035:
                cc = mix(BRASS, VERDIGRIS, 0.4)  # the two tail buttons
            cc = mix(cc, MUD, 0.85 * S(hem[c] - 0.3, hem[c] - 0.02, t) * (0.6 + 0.4 * nz(co, 7)))
            vert = bm.verts.new(co)
            paint(vert, col, cc)
            row.append(vert)
        grid.append(row)
    for r in range(rows - 1):
        t = (r + 0.5) / (rows - 1)
        for c in range(cols - 1):
            theta = o + (TAU - 2 * o) * (c + 0.5) / (cols - 1)
            if t > hem[c]:
                continue
            torn = any(t > ts and abs(theta - tt) < 0.025 + 0.13 * (t - ts) + 0.02 * nz((t * 9, tt, 0), 1)
                       for tt, ts in zip(TEARS, tear_start))
            torn = torn or any(math.hypot((theta - ht) * 0.8, t - hy) < hr for ht, hy, hr in holes)
            if not torn:
                bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    orient(bm, lambda p: Vector((p.x, 0, p.z)).normalized())
    return bm


# ------------------------------------------------------------------ arms
def angd(a, b):
    return math.atan2(math.sin(a - b), math.cos(a - b))


def ring_x(bm, col, x, sides, radius, colour):
    ring = []
    for s in range(sides):
        phi = s / sides * TAU
        r = radius(phi)
        co = Vector((x, math.cos(phi) * r, math.sin(phi) * r))
        vert = bm.verts.new(co)
        paint(vert, col, colour(phi, co))
        ring.append(vert)
    return ring


def forearm_high(length=2.75, d=0.32 * 0.82):
    """Along X, wrist at -X, elbow at +X."""
    bm, col = new_bm()

    def radius(t, phi):
        r = d / 2 * (0.62 + 0.55 * t)
        r *= 1 + 0.1 * math.cos(2 * phi)
        r *= 1 + 0.035 * max(0.0, math.cos(6 * phi)) * S(0.35, 0.05, t)  # tendons
        r *= 1 - 0.06 * G(angd(phi, math.pi / 2), 0.5) * G(t - 0.5, 0.25)  # wasted between the bones
        r *= 1 + 0.25 * G(t - 0.96, 0.04) * G(angd(phi, math.pi / 2), 0.7)  # elbow
        r *= 1 + 0.18 * G(t - 0.04, 0.04) * G(angd(phi, -math.pi / 2), 0.7)  # wrist knob
        return r

    def colour(t, co):
        c = mul(SKIN, 0.85 + 0.15 * nz(co, 7, 3))
        if abs(nz(co * Vector((0.3, 1, 1)), 9)) < 0.05:
            c = mix(c, VEIN, 0.5)
        c = mix(c, BLOOD, S(0.3, 0.0, t) * S(-0.2, 0.3, nz(co, 4)))
        return mul(c, 0.9)

    rings = []
    for i in range(40):
        t = i / 39
        rings.append(ring_x(bm, col, -length / 2 + t * length, 16, lambda phi: radius(t, phi), lambda phi, co: colour(t, co)))
    loft(bm, rings, cap0=True, cap1=True)
    return bm


def sleeve_high(length=2.9, d=0.32):
    """Along X, shoulder at +X, the open cuff at -X: down the outside, round the frayed lip, a little way up
    the inside. Shreds hang off the cuff."""
    bm, col = new_bm()
    rnd = random.Random(7)
    sides = 20
    jag = [rnd.uniform(0.05, 0.38) * (1 if k % 2 else 0.4) for k in range(sides)]

    def outer(t, phi):
        r = d / 2 * (0.9 + 0.45 * t)
        r *= 1 + 0.06 * math.sin(t * 70 + 1.3 * math.sin(phi)) * S(0.4, 0.05, t)
        r *= 1 + 0.04 * math.sin(2 * phi + t * 12)
        return r

    def colour(t, phi, co):
        c = wool(co)
        c = mix(c, WOOL_WORN, 0.6 * G(t - 0.08, 0.08) * G(angd(phi, math.pi / 2), 0.8))  # the worn elbow
        if abs(angd(phi, math.pi)) < 0.06:
            c = STITCH if int(t * 120) % 2 else SEAM
        if math.hypot(t - 0.22, angd(phi, 0.6) * 0.15) < 0.035:
            c = VOID  # worn through
        return mix(c, WOOL_WORN, 0.6 * S(0.06, 0.0, t))

    rings = []
    for i in range(36):
        t = 1 - i / 35
        rings.append(ring_x(bm, col, -length / 2 + t * length, sides, lambda phi: outer(t, phi), lambda phi, co: colour(t, phi, co)))

    def frayed(r_k, back, shade):
        ring = []
        for s in range(sides):
            phi = s / sides * TAU
            r = d / 2 * 0.9 * r_k
            co = Vector((-length / 2 - jag[s] + back, math.cos(phi) * r, math.sin(phi) * r))
            vert = bm.verts.new(co)
            paint(vert, col, mul(mix(WOOL, WOOL_WORN, 0.5), shade))
            ring.append(vert)
        return ring

    rings.append(frayed(1.0, 0.0, 1.0))
    rings.append(frayed(0.86, 0.0, 0.6))
    rings.append(frayed(0.86, 0.35 + max(jag), 0.25))
    loft(bm, rings, cap0=True, cap1=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for k in (1, 6, 11, 15):  # two-sided shreds
        phi = k / sides * TAU
        r = d / 2 * 0.95
        base = Vector((-length / 2 - jag[k] * 0.8, math.cos(phi) * r, math.sin(phi) * r))
        side = Vector((0, -math.sin(phi), math.cos(phi))) * 0.05
        tip = base + Vector((-rnd.uniform(0.3, 0.6), math.cos(phi) * 0.04, math.sin(phi) * 0.04))
        for flip in (False, True):
            vs = [bm.verts.new(p) for p in (base - side, base + side, tip + side * 0.3, tip - side * 0.3)]
            for vv in vs:
                paint(vv, col, mix(WOOL, WOOL_WORN, 0.5))
            bm.faces.new(vs[::-1] if flip else vs)
    return bm


# ------------------------------------------------------------------ hand
FINGERS = [(-0.135, 0.85), (-0.045, 1.0), (0.045, 0.96), (0.135, 0.78)]


def hand_colour(co, nail=-1.0):
    c = mul(SKIN, 0.82 + 0.15 * nz(co, 9, 2))
    stain = S(-0.15, -0.85, co.y) * (0.55 + 0.45 * nz(co, 5, 2)) + 0.4 * S(0.0, -0.05, co.z) * S(0.1, -0.2, co.y)
    c = mix(c, BLOOD, stain)
    if nz(co, 22) > 0.4:
        c = mix(c, BLOOD_WET, 0.6 * stain)
    if nail >= 0:
        c = mix(NAIL, VOID, nail)  # the claw, black at the point
    return c


def hand_high():
    """Wrist at +0.25 Y, long knuckled fingers hanging to about -1.45, palm to the front (-Z), thumb at +X."""
    bm, col = new_bm()
    pal_p, pal_r = resample([(0, 0.25, 0), (0, 0.1, 0), (0, -0.1, 0), (0, -0.25, 0), (0, -0.31, 0)],
                            [0.11, 0.15, 0.19, 0.2, 0.17], 18)
    flats = [0.6, 0.5, 0.42, 0.4, 0.45]
    rings = []
    for i, (p, r) in enumerate(zip(pal_p, pal_r)):
        f = flats[min(4, int(i / 18 * 5))]
        ring = []
        for s in range(24):
            t = s / 24 * TAU
            x = p.x + math.cos(t) * r
            z = -math.sin(t) * r * f
            knuckle = 0.0
            if z > 0:  # the back of the hand: tendons and knuckles
                z += 0.012 * (0.5 + 0.5 * math.cos(TAU * x / 0.09)) * S(0.15, -0.1, p.y)
                knuckle = max(G(x - fx, 0.03) * G(p.y + 0.27, 0.04) for fx, _ in FINGERS)
                z += 0.03 * knuckle
            co = Vector((x, p.y, z))
            vert = bm.verts.new(co)
            paint(vert, col, mix(hand_colour(co), BRUISE, 0.5 * knuckle))
            ring.append(vert)
        rings.append(ring)
    loft(bm, rings, cap0=True, cap1=True)

    def digit(start, dirs, lengths, radii):
        pts, rad = [Vector(start)], [radii[0]]
        p = Vector(start)
        for k, (dvec, length) in enumerate(zip(dirs, lengths)):
            pts += [p + dvec * (length * 0.5), p + dvec * length]
            p = p + dvec * length
            rad += [radii[2 * k + 1], radii[2 * k + 2]]
        fp, fr = resample(pts, rad, 26)
        rings = tube_rings(bm, col, fp, fr, 10, flat=0.85,
                           colour=lambda i, s, co: mul(hand_colour(co), 0.6) if i % 8 == 0 and i else hand_colour(co))
        loft(bm, rings, cap0=True, cap1=True)
        # the claw: thick at the bed, curling past the tip to a point
        d = dirs[-1]
        curl = Vector((0, d.z, -d.y)) * 0.5
        cp = [p - d * 0.03, p + d * 0.05, p + d * 0.11 + curl * 0.03, p + d * 0.16 + curl * 0.08]
        rings = tube_rings(bm, col, cp, [0.02, 0.017, 0.01, 0.002], 6, flat=0.5,
                           colour=lambda i, s, co: hand_colour(co, nail=i / 3))
        loft(bm, rings, cap0=True, cap1=True)

    for fx, k in FINGERS:
        dirs, a = [], 0.0
        for bend in (10, 22, 18):
            a += math.radians(bend)
            dirs.append(Vector((0.03 * fx, -math.cos(a), -math.sin(a))).normalized())
        digit((fx, -0.27, 0.0), dirs, [0.42 * k, 0.32 * k, 0.24 * k], [0.042, 0.032, 0.041, 0.028, 0.034, 0.024, 0.019])
    tdirs = [Vector((0.55, -0.8, -0.3)).normalized(), Vector((0.2, -0.95, -0.25)).normalized()]
    digit((0.13, 0.02, -0.02), tdirs, [0.24, 0.2], [0.05, 0.045, 0.046, 0.036, 0.03])
    return bm


# ------------------------------------------------------------------ the pipeline
def swap_to_blender(obj):
    """Built in Roblox axes (+Y up, front -Z); relabel to Blender's (+Z up, front -Y) so the exporter maps it back.
    The relabel mirrors, so the faces are turned back over to keep them facing out."""
    for v in obj.data.vertices:
        v.co = Vector((v.co.x, v.co.z, v.co.y))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def make_object(name, bm, closed=False):
    if closed:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    swap_to_blender(obj)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def apply_mod(obj, kind, **props):
    m = obj.modifiers.new(kind, kind)
    for k, v in props.items():
        setattr(m, k, v)
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_apply(modifier=m.name)


def join_into(obj, extra):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.from_mesh(extra.data)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True


def select_only(*objs, active=None):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def piece(name, high_bm, target, size, ao_dist, extra=None, solid=0.0, closed=False):
    """Decimate a copy of the high mesh to `target` triangles, unwrap it, bake the high mesh's vertex colours and
    the occlusion of the low shape into one colour texture. Returns the low object."""
    high = make_object(name + "_hi", high_bm, closed=closed)
    low = high.copy()
    low.data = high.data.copy()
    low.name = name
    bpy.context.scene.collection.objects.link(low)
    base = (target - (tris(extra) if extra else 0)) / (2.0 if solid else 1.0)
    apply_mod(low, "DECIMATE", ratio=min(1.0, base / tris(high)))
    if extra:
        join_into(high, extra)
        join_into(low, extra)
        bpy.data.objects.remove(extra)
    if solid:
        for o in (high, low):
            apply_mod(o, "SOLIDIFY", thickness=solid, offset=0.0, use_rim=True)
    apply_mod(low, "TRIANGULATE")
    select_only(low)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.012)
    bpy.ops.object.mode_set(mode="OBJECT")

    hm = bpy.data.materials.new(name + "_hi")
    hm.use_nodes = True
    nt = hm.node_tree
    nt.nodes.clear()
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "col"
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(attr.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs[0], out.inputs[0])
    high.data.materials.append(hm)

    img_c = bpy.data.images.new(name + "_c", size, size)
    img_a = bpy.data.images.new(name + "_ao", size, size)
    img_a.colorspace_settings.name = "Non-Color"
    lm = bpy.data.materials.new(name)
    lm.use_nodes = True
    nt = lm.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    node_c = nt.nodes.new("ShaderNodeTexImage")
    node_c.image = img_c
    node_a = nt.nodes.new("ShaderNodeTexImage")
    node_a.image = img_a
    low.data.materials.clear()
    low.data.materials.append(lm)

    # the colours: a dense copy of the low mesh (same UVs) takes the high mesh's vertex colours, and bakes them
    dense = low.copy()
    dense.data = low.data.copy()
    bpy.context.scene.collection.objects.link(dense)
    apply_mod(dense, "SUBSURF", subdivision_type="SIMPLE", levels=3, render_levels=3)
    dt = dense.modifiers.new("dt", "DATA_TRANSFER")
    dt.object = high
    dt.use_vert_data = True
    dt.data_types_verts = {"COLOR_VERTEX"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    with bpy.context.temp_override(object=dense, active_object=dense):
        bpy.ops.object.datalayout_transfer(modifier=dt.name)
        bpy.ops.object.modifier_apply(modifier=dt.name)
    dm = hm.copy()
    dense.data.materials.clear()
    dense.data.materials.append(dm)
    node_d = dm.node_tree.nodes.new("ShaderNodeTexImage")
    node_d.image = img_c
    dm.node_tree.nodes.active = node_d

    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.world.light_settings.distance = ao_dist
    others = [o for o in sc.objects if o not in (low, dense) and not o.hide_render]
    for o in others:  # the pieces already built sit at the origin too: keep them out of this one's occlusion
        o.hide_render = True
    sc.cycles.samples = 1
    select_only(dense)
    bpy.ops.object.bake(type="EMIT", margin=6, use_clear=True)
    dense.hide_render = True
    nt.nodes.active = node_a
    sc.cycles.samples = 48
    select_only(low)
    bpy.ops.object.bake(type="AO", margin=6, use_clear=True)
    for o in others:
        o.hide_render = False
    me = dense.data
    bpy.data.objects.remove(dense)
    bpy.data.meshes.remove(me)

    c = np.empty(size * size * 4, dtype=np.float32)
    a = np.empty(size * size * 4, dtype=np.float32)
    img_c.pixels.foreach_get(c)
    img_a.pixels.foreach_get(a)
    c = c.reshape(-1, 4)
    a = a.reshape(-1, 4)[:, :1]
    c[:, :3] *= 0.3 + 0.7 * a
    c[:, 3] = 1
    tex = bpy.data.images.new(name + "_tex", size, size)
    tex.pixels.foreach_set(c.ravel())
    # the PNG gets display (sRGB) values: these numbers are linear and the byte image saves them as they are,
    # while Roblox reads a TextureID as sRGB (unencoded, every piece showed about four times too dark)
    png = bpy.data.images.new(name + "_png", size, size)
    e = c.copy()
    e[:, :3] = np.where(e[:, :3] <= 0.0031308, 12.92 * e[:, :3], 1.055 * np.power(e[:, :3], 1 / 2.4) - 0.055)
    png.pixels.foreach_set(e.ravel())
    png.filepath_raw = str(OUT / f"{name}.png")
    png.file_format = "PNG"
    png.save()
    bpy.data.images.remove(png)
    nt.nodes.remove(node_a)
    node_c.image = tex
    nt.links.new(node_c.outputs["Color"], bsdf.inputs["Base Color"])
    bpy.data.images.remove(img_c)
    bpy.data.images.remove(img_a)

    me = high.data
    bpy.data.objects.remove(high)
    bpy.data.meshes.remove(me)
    return low


def mirror_x(obj, name):
    o = obj.copy()
    o.data = obj.data.copy()
    o.name = o.data.name = name
    bpy.context.scene.collection.objects.link(o)
    for v in o.data.vertices:
        v.co.x = -v.co.x
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()
    return o


def export(obj, report, texture):
    """FBX centred on its box; the report keeps the box (size, centre) in the part's frame, Roblox axes."""
    select_only(obj)
    bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    mid = (lo + hi) / 2
    report[obj.name] = {
        "size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
        "center": [round(mid.x, 3), round(mid.z, 3), round(mid.y, 3)],
        "tris": tris(obj),
        "texture": texture,
    }
    for v in obj.data.vertices:
        v.co -= mid
    bpy.ops.export_scene.fbx(filepath=str(OUT / f"{obj.name}.fbx"), use_selection=True, axis_forward="-Z",
                             axis_up="Y", apply_unit_scale=True, global_scale=1.0, path_mode="STRIP",
                             colors_type="NONE")  # Roblox multiplies vertex colours into the texture: leave the bake's out
    for v in obj.data.vertices:
        v.co += mid


# ------------------------------------------------------------------ the figure, for the renders
def rgb(r, g, b):
    return (r / 255, g / 255, b / 255)


GAME = {  # HollowBuilder's colours
    "FACE": rgb(140, 135, 120), "SKIN": rgb(182, 178, 160), "SKIN_DARK": rgb(126, 122, 108),
    "COAT": rgb(43, 40, 38), "LAPEL": rgb(27, 25, 24), "BLOOD": rgb(104, 22, 24), "TROUSER": rgb(40, 40, 44),
    "TOOTH": rgb(196, 184, 148), "GAPE": rgb(120, 22, 26), "BRASS": rgb(150, 118, 58), "ICHOR": rgb(20, 14, 14),
}


def flat_material(c, emit=0.0):
    key = "flat%.3f_%.3f_%.3f_%.1f" % (*c, emit)
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(c), 1)
    b.inputs["Roughness"].default_value = 0.8
    if emit:
        b.inputs["Emission Color"].default_value = (*lin(c), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


def A(x=0.0, y=0.0, z=0.0):
    """Roblox CFrame.Angles in degrees."""
    return Matrix.Rotation(math.radians(x), 4, "X") @ Matrix.Rotation(math.radians(y), 4, "Y") @ Matrix.Rotation(math.radians(z), 4, "Z")


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def place(obj, M):
    """A copy of obj (Blender axes, part frame) moved by the Roblox world matrix M."""
    o = obj.copy()
    o.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(o)
    o.hide_render = False
    for v in o.data.vertices:
        r = M @ Vector((v.co.x, v.co.z, v.co.y))
        v.co = Vector((r.x, r.z, r.y))
    o["figure"] = True
    return o


def prim(kind, size, M, colour, emit=0.0):
    """The Roblox blocks both versions draw: box, rod (axis X, size length x diameter) or ball."""
    bm = bmesh.new()
    if kind == "box":
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    elif kind == "rod":
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=size[1] / 2, radius2=size[1] / 2, depth=size[0])
        for v in bm.verts:
            v.co = Vector((v.co.z, v.co.x, v.co.y))
    else:
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=size[0] / 2)
    o = make_object("p", bm, closed=True)
    o.data.materials.append(flat_material(colour, emit))
    out = place(o, M)
    me = o.data
    bpy.data.objects.remove(o)
    bpy.data.meshes.remove(me)
    return out


def frames(reach):
    """Part frames for a standing pose (Roblox world, ground at y = 0). reach: upper and fore arm swing forward."""
    root = T(0, 5.0, 0)
    pelvis = root @ T(0, -0.65, 0)
    chest = pelvis @ T(0, 0.42, 0) @ A(-27) @ T(0, 1.4, 0)
    head = chest @ T(0, 1.62, -0.42) @ A(16) @ T(0, 0.68, -0.12)
    jaw = head @ T(0, -0.66, 0.3) @ A(-9) @ T(0, -0.14, -0.42)
    f = {"pelvis": pelvis, "chest": chest, "head": head, "jaw": jaw}
    for side, s in (("L", -1), ("R", 1)):
        shoulder = (chest @ T(s * 0.98, 1.12, 0)).translation
        up1 = (A(reach[0]) @ Vector((0, 1, 0, 0))).to_3d()
        f["upper" + side] = T(*shoulder) @ A(reach[0]) @ A(0, 0, 90) @ T(-1.45, 0, 0)
        elbow = shoulder - up1 * 2.9
        up2 = (A(reach[1]) @ Vector((0, 1, 0, 0))).to_3d()
        f["fore" + side] = T(*elbow) @ A(reach[1]) @ A(0, 0, 90) @ T(-1.375, 0, 0)
        wrist = elbow - up2 * 2.75
        f["hand" + side] = T(*wrist) @ A(reach[1] + 8) @ T(0, -0.25, 0)
        hip = (pelvis @ T(s * 0.5, -0.4, 0)).translation
        f["thigh" + side] = T(hip.x, hip.y - 1.05, hip.z + 0.1) @ A(-4)
        f["shin" + side] = T(hip.x, hip.y - 3.0, hip.z + 0.2)
        f["foot" + side] = T(hip.x, 0.1, hip.z - 0.25)
    return f


def figure(pieces, extras, reach=(25, 50)):
    """pieces: name -> object in its part frame. extras(f) adds the blocks that version still draws."""
    f = frames(reach)
    for name, frame in (("head", "head"), ("jaw", "jaw"), ("torso", "chest"), ("coat", "pelvis")):
        if name in pieces:
            place(pieces[name], f[frame])
    for side in ("L", "R"):
        if "sleeve" in pieces:
            place(pieces["sleeve"], f["upper" + side])
        if "forearm" in pieces:
            place(pieces["forearm"], f["fore" + side])
        if "hand" in pieces:
            place(pieces["hand" if side == "R" else "handL"], f["hand" + side])
    prim("rod", (0.62, 0.34, 0.34), f["chest"] @ T(0, 1.5, -0.34) @ A(0, 0, 90) @ A(0, 16, 0), GAME["SKIN_DARK"])
    for side in ("L", "R"):
        prim("box", (0.46, 2.1, 0.46), f["thigh" + side], GAME["TROUSER"])
        prim("box", (0.3, 1.85, 0.3), f["shin" + side], GAME["SKIN"])
        prim("box", (0.4, 0.2, 0.9), f["foot" + side], GAME["SKIN_DARK"])
    for sx in (-0.2, 0.2):  # the pinpricks (HollowBuilder shine)
        prim("ball", (0.045,), f["head"] @ T(sx, 0.16, -0.14), (0.75, 0.09, 0.07), emit=6.0)
    extras(f)
    return f


def no_extras(f):
    pass


def clear_figure():
    for o in list(bpy.context.scene.objects):
        if o.get("figure") or o.type in ("LIGHT", "CAMERA"):
            data = o.data
            bpy.data.objects.remove(o)
            if isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)


def to_b(p):
    return Vector((p.x, p.z, p.y))


def camera(eye_r, at_r, fov=70, ortho=None):
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.scene.collection.objects.link(cam)
    eye, at = to_b(eye_r), to_b(at_r)
    cam.location = eye
    cam.rotation_euler = (at - eye).to_track_quat("-Z", "Y").to_euler()
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(fov)
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    cam.data.clip_start = 0.05
    bpy.context.scene.camera = cam


def light(kind, pos_r, energy, colour, size=0.2, at_r=None):
    ld = bpy.data.lights.new("l", kind)
    ld.energy = energy
    ld.color = colour
    if kind == "POINT":
        ld.shadow_soft_size = size
    lo = bpy.data.objects.new("l", ld)
    lo.location = to_b(pos_r)
    if at_r is not None:
        lo.rotation_euler = (to_b(at_r) - to_b(pos_r)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(lo)


def world(c, strength=1.0):
    w = bpy.context.scene.world
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*c, 1)
    bg.inputs[1].default_value = strength


def render(path, w, h, samples=40):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 50
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def gaslight(head):
    world((0.004, 0.005, 0.008), 1.0)
    light("POINT", head + Vector((-2.0, 0.6, -1.5)), 150, (1.0, 0.62, 0.30), size=0.15)
    light("POINT", head + Vector((1.5, 0.4, 1.8)), 12, (0.45, 0.55, 0.8), size=0.5)


def daylight(at):
    world((0.18, 0.19, 0.21), 1.0)
    light("SUN", Vector((3, 9, -6)), 3.0, (1, 0.97, 0.92), at_r=at)


def renders(pieces, extras, prefix, outdir):
    """front: the whole figure. face: arm's length, plain light. gaslight: the same in a dim warm lamp.
    phone: the grab framing in gaslight at a phone's 640 x 360, arms reaching."""
    f = figure(pieces, extras)
    daylight(Vector((0, 4, 0)))
    camera(Vector((2.6, 5.2, -11.5)), Vector((0, 4.2, 0)), fov=48)
    render(outdir / f"{prefix}front.png", 1000, 1400)
    head = f["head"].translation
    look = head + Vector((0, -0.12, 0))
    for o in list(bpy.context.scene.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o)
    daylight(head)
    camera(head + Vector((0.9, -0.2, -3.2)), look, fov=30)
    render(outdir / f"{prefix}face.png", 1000, 1000)
    for o in list(bpy.context.scene.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o)
    gaslight(head)
    camera(head + Vector((0.9, -0.2, -3.2)), look, fov=30)
    render(outdir / f"{prefix}gaslight.png", 1000, 1000)
    clear_figure()
    f = figure(pieces, extras, reach=(62, 80))
    head = f["head"].translation
    gaslight(head)
    camera(head + Vector((0.1, -0.35, -2.4)), head + Vector((0, -0.3, 0)), fov=70)
    render(outdir / f"{prefix}phone.png", 1280, 720, samples=32)
    clear_figure()


def sheet(objs):
    """The pieces side by side under plain light, textures on."""
    spots = {"stalker_head": (-4.6, 1.2), "stalker_jaw": (-4.6, -0.4), "stalker_torso": (-2.6, 0.3),
             "stalker_coat": (0.0, 1.5), "stalker_sleeve": (2.2, 0.0), "stalker_forearm": (3.0, 0.0),
             "stalker_hand": (3.9, 0.6), "stalker_handL": (4.7, 0.6)}
    for o in objs:
        x, y = spots[o.name]
        long = o.name in ("stalker_forearm", "stalker_sleeve")
        place(o, T(x, y, 0) @ (A(0, 0, -90) if long else Matrix()))
    daylight(Vector((0, 0, 0)))
    camera(Vector((0, -0.2, -14)), Vector((0, -0.2, 0)), ortho=5.6)
    render(OUT / "sheet.png", 2000, 1000, samples=24)
    clear_figure()


def main():
    clear()
    if bpy.context.scene.world is None:
        bpy.context.scene.world = bpy.data.worlds.new("w")
    report = {}
    bm, col = new_bm()
    upper_teeth(bm, col)
    up_teeth = make_object("teeth_up", bm, closed=True)
    bm, col = new_bm()
    lower_teeth(bm, col)
    to_jaw_frame(bm)
    lo_teeth = make_object("teeth_lo", bm, closed=True)
    jaw_bm = jaw_high()
    to_jaw_frame(jaw_bm)

    objs = [
        piece("stalker_head", head_high(), 1650, 1024, 0.25, extra=up_teeth, closed=True),
        piece("stalker_jaw", jaw_bm, 520, 256, 0.15, extra=lo_teeth, closed=True),
        piece("stalker_torso", torso_high(), 820, 512, 0.5, solid=0.035),
        piece("stalker_coat", coat_high(), 720, 512, 0.5, solid=0.035),
        piece("stalker_sleeve", sleeve_high(), 280, 256, 0.25),
        piece("stalker_forearm", forearm_high(), 170, 256, 0.2, closed=True),
        piece("stalker_hand", hand_high(), 340, 256, 0.15, closed=True),
    ]
    objs.append(mirror_x(objs[-1], "stalker_handL"))
    for o in objs:
        export(o, report, ("stalker_hand" if o.name == "stalker_handL" else o.name) + ".png")
    twice = {"stalker_sleeve", "stalker_forearm"}  # one mesh on each arm
    report["figure_tris"] = sum(v["tris"] * (2 if k in twice else 1) for k, v in report.items())
    (OUT / "report.json").write_text(json.dumps(report, indent=1))
    print(json.dumps(report))
    for o in objs:
        o.hide_render = True  # the renders use placed copies
    if "--no-render" not in sys.argv:
        sheet(objs)
        renders({o.name.replace("stalker_", ""): o for o in objs}, no_extras, "", OUT)


if __name__ == "__main__":
    main()
