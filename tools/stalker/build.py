"""Close-up meshes and textures for the Stalker (Builders/HollowBuilder stalker).

The lost porter: too tall, too thin, in the rags of a railway greatcoat. Seen at arm's length in a grab, on a
phone, under gaslight, so the read has to come from shape and value, not from small parts:
  head     a long skull under skin drawn tight: brow ridge, two deep sockets with wide, clouded
           eyes, cheekbones over fallen cheeks, sunken temples, a collapsed nose, thin uneven
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
EYE_MURK = (0.25, 0.26, 0.22)  # one clouded grey-green for the whole eye
BONE_TEAR = (0.549, 0.529, 0.431)  # RGB 140, 135, 110: dry bone where the skin has split
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
    """Uneven teeth: (root, direction, length, radius). Yellowed, dark at the root, worn blunt and flat at the
    edge (a person's teeth, not fangs)."""
    for root, d, length, r in specs:
        root, d = Vector(root), Vector(d).normalized()
        pts = [root + d * (length * f) for f in (0.0, 0.35, 0.8, 1.0)]
        rad = [r * 0.85, r, r * 0.95, r * 0.75]
        rings = tube_rings(bm, col, pts, rad, 6, flat=0.62,
                           colour=lambda i, s, co: mix(TOOTH_ROOT, TOOTH, i / 2.0) if i < 3 else mul(TOOTH, 0.8))
        loft(bm, rings, cap0=True, cap1=True)


# ------------------------------------------------------------------ head
# A man first: the face is built as flesh, not carved bone. Overlapping solid shapes (skull, face, brow,
# cheekbones, orbits, nose, lips, ears, neck) are merged into one skin by a voxel remesh and smoothed so the joins
# read as soft tissue; the lids and the parted lips are cut; then the fine forms (sunken temples, hollow cheeks,
# lid creases, the folds beside the mouth, neck cords) are pushed in and out. Asymmetric on purpose: the right
# eye sits lower, the nose is bent, the left ear is torn, the lip is drawn up further on the left.
EYES = ((-0.2, 0.168, -0.314), (0.2, 0.146, -0.316))  # eyeball centres in the Head frame
EYE_R = (0.082, 0.07, 0.072)  # wider than tall
MOUTH_Y = -0.445  # the lips part here: above it the head piece, below it the jaw piece
VOXEL = 0.0065


def blob(bm, c, r, rot=(0.0, 0.0, 0.0), seg=28):
    """A solid ellipsoid: centre c, radii r, turned by rot (degrees, like CFrame.Angles)."""
    m = Matrix.Translation(Vector(c)) @ A(*rot)
    geom = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2 + 2, radius=1.0)
    for v in geom["verts"]:
        v.co = m @ Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2]))


def rod(bm, a, b, r, rb=None, seg=20):
    """A solid ellipsoid stretched from a to b (radius r across, rb at most)."""
    a, b = Vector(a), Vector(b)
    q = (b - a).to_track_quat("Y", "Z").to_matrix().to_4x4()
    m = Matrix.Translation((a + b) / 2) @ q
    half = (b - a).length / 2 + r
    geom = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2 + 2, radius=1.0)
    for v in geom["verts"]:
        v.co = m @ Vector((v.co.x * r, v.co.y * half, v.co.z * (rb or r)))


def box(bm, lo, hi):
    geom = bmesh.ops.create_cube(bm, size=1.0)
    lo, hi = Vector(lo), Vector(hi)
    for v in geom["verts"]:
        v.co = Vector(((lo.x, hi.x)[v.co.x > 0], (lo.y, hi.y)[v.co.y > 0], (lo.z, hi.z)[v.co.z > 0]))


def raw_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def flesh(name, build, cuts, smooth=5):
    """build(bm) lays the solid shapes; cuts is a list of build functions for what to take away. Returns a
    bmesh (Roblox axes) with a colour layer, one closed skin."""
    bm = bmesh.new()
    build(bm)
    obj = raw_object(name, bm)
    apply_mod(obj, "REMESH", mode="VOXEL", voxel_size=VOXEL)
    apply_mod(obj, "SMOOTH", factor=0.5, iterations=smooth)
    for cut in cuts:
        cbm = bmesh.new()
        cut(cbm)
        cobj = raw_object("cut", cbm)
        apply_mod(obj, "BOOLEAN", object=cobj, operation="DIFFERENCE")
        me = cobj.data
        bpy.data.objects.remove(cobj)
        bpy.data.meshes.remove(me)
    apply_mod(obj, "REMESH", mode="VOXEL", voxel_size=VOXEL)
    apply_mod(obj, "SMOOTH", factor=0.6, iterations=3)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    me = obj.data
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)
    col = bm.verts.layers.float_color.new("col")
    bm.normal_update()
    return bm, col


def eye_space(x, y, i):
    """Distance from eye i in the face plane, in lid units (1 = the lid's edge), and the height above it."""
    ex, ey, _ = EYES[i]
    dx, dy = x - ex, y - ey
    out = -1 if ex < 0 else 1
    a = math.radians(-9) * out  # the outer corners droop
    u = dx * math.cos(a) + dy * math.sin(a)
    w = -dx * math.sin(a) + dy * math.cos(a)
    return math.sqrt((u / 0.102) ** 2 + (w / 0.06) ** 2), w


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length, t


def head_shapes(bm):
    blob(bm, (0, 0.22, 0.06), (0.305, 0.41, 0.38))  # cranium
    blob(bm, (0, 0.18, 0.15), (0.28, 0.32, 0.27))  # the back of the skull
    blob(bm, (0, -0.02, -0.16), (0.262, 0.40, 0.30))  # face
    blob(bm, (0, -0.27, -0.2), (0.215, 0.23, 0.22))  # lower face, narrowing
    blob(bm, (0, 0.40, -0.21), (0.25, 0.17, 0.22))  # forehead
    blob(bm, (0, 0.285, -0.345), (0.25, 0.062, 0.115))  # brow
    for sx, dy in ((-1, 0.0), (1, -0.016)):
        blob(bm, (sx * 0.165, 0.262 + dy, -0.37), (0.1, 0.045, 0.068), (0, 0, sx * -10))  # brow over each eye
    for (ex, ey, ez) in EYES:
        blob(bm, (ex, ey + 0.004, -0.335), (0.114, 0.068, 0.06))  # the orbit and lids round the eyeball
        blob(bm, (ex, ey + 0.03, -0.352), (0.088, 0.034, 0.04))  # the upper lid, heavy over the eye
    for sx in (-1, 1):
        blob(bm, (sx * 0.212, 0.035, -0.245), (0.074, 0.05, 0.13), (0, sx * 28, sx * 8))  # cheekbone
        blob(bm, (sx * 0.262, 0.045, -0.08), (0.04, 0.036, 0.14))  # the arch running back to the ear
    blob(bm, (0, -0.335, -0.335), (0.15, 0.12, 0.11))  # the gum under the lip
    blob(bm, (0.0, -0.392, -0.432), (0.128, 0.022, 0.038), (0, 0, -4))  # upper lip, thin, drawn up on the left
    # the nose: a long thin bridge with a hump, the tip hooked down and bent to the right
    rod(bm, (0, 0.15, -0.41), (0.011, -0.07, -0.54), 0.035, 0.046)
    blob(bm, (0.004, 0.06, -0.48), (0.031, 0.045, 0.035))
    blob(bm, (0.016, -0.1, -0.542), (0.034, 0.034, 0.032))
    blob(bm, (0.056, -0.135, -0.5), (0.03, 0.026, 0.03))
    blob(bm, (-0.034, -0.137, -0.502), (0.031, 0.027, 0.03))
    blob(bm, (0.012, -0.14, -0.522), (0.022, 0.018, 0.03))
    # ears, a little low, set back behind the jaw's hinge
    for sx in (-1, 1):
        blob(bm, (sx * 0.312, 0.035, 0.07), (0.026, 0.125, 0.075), (-12, sx * 10, 0))
        blob(bm, (sx * 0.318, -0.078, 0.048), (0.022, 0.032, 0.032))  # lobe
        blob(bm, (sx * 0.30, 0.03, 0.06), (0.03, 0.08, 0.05))  # root
    hair_shapes(bm)
    rod(bm, (0, -0.22, 0.12), (0, -0.64, 0.15), 0.118, 0.13)  # neck
    for sx in (-1, 1):  # the cords of the neck, from behind the ear to the throat
        rod(bm, (sx * 0.17, -0.2, 0.09), (sx * 0.05, -0.74, -0.0), 0.022)


SKULL = (((0, 0.22, 0.06), (0.305, 0.41, 0.38)), ((0, 0.18, 0.15), (0.28, 0.32, 0.27)))


def hair_shapes(bm):
    """What is left of the hair, grown into the same skin: a thin mat over the back of the skull under the cap and
    lank clumps hanging from it to the collar, thicker on the left, a gap on the right."""
    blob(bm, (0, 0.22, 0.15), (0.316, 0.425, 0.322))
    rnd = random.Random(11)
    for k in range(24):
        th = math.radians(-74 + 148 * k / 23 + rnd.uniform(-4, 4))
        if 0.3 < math.sin(th) < 0.7:
            continue  # a thin patch on the right
        root = (math.sin(th) * 0.29, 0.44, 0.16 + math.cos(th) * 0.29)
        drop = rnd.uniform(0.45, 0.8) * (1.1 if th < 0 else 0.9)
        tip = (math.sin(th) * (0.24 + 0.04 * rnd.random()), 0.44 - drop, 0.13 + math.cos(th) * (0.2 + 0.06 * rnd.random()))
        if abs(math.sin(th)) > 0.75:  # over the ears: hang behind them
            tip = (math.copysign(0.27, th), tip[1], max(tip[2], 0.2))
        rod(bm, root, tip, rnd.uniform(0.022, 0.03), rnd.uniform(0.012, 0.018), seg=12)


def is_hair(p):
    x, y, z = p.x, p.y, p.z
    if z < 0.02:
        return 0.0
    if y < -0.1 and seg_dist(Vector((x, y, z)), Vector((0, -0.22, 0.12)), Vector((0, -0.64, 0.15)))[0] < 0.145:
        return 0.0  # the neck
    k = min(((x - c[0]) / r[0]) ** 2 + ((y - c[1]) / r[1]) ** 2 + ((z - c[2]) / r[2]) ** 2 for c, r in SKULL)
    near_ear = math.hypot(abs(x) - 0.31, y - 0.0, z - 0.07) < 0.15 and abs(x) > 0.27
    return 0.0 if near_ear else S(1.02, 1.08, k)


def head_cuts():
    cuts = []

    def mouth(bm):
        box(bm, (-0.142, -0.9, -0.8), (0.142, MOUTH_Y, -0.18))
        box(bm, (-0.6, -1.2, -0.8), (0.6, -0.52, -0.02))  # the chin and the lower face are the jaw piece's
    cuts.append(mouth)
    for i, (ex, ey, ez) in enumerate(EYES):
        out = -1 if ex < 0 else 1
        open_h = 0.028 if out > 0 else 0.0235  # narrowed (38% of the eyeball, both eyes together); the left lid hangs heavier

        def fissure(bm, ex=ex, ey=ey, out=out, open_h=open_h):
            blob(bm, (ex, ey - 0.008, -0.38), (0.087, open_h, 0.064), (0, 0, out * -9), seg=32)
        cuts.append(fissure)

    def torn_ear(bm):
        blob(bm, (-0.345, 0.155, 0.075), (0.05, 0.035, 0.04), (0, 0, 30))
    cuts.append(torn_ear)
    return cuts


def head_fields(p, n):
    """Push along the normal (studs) and the colour (sRGB) for a point of the head skin."""
    x, y, z = p.x, p.y, p.z
    ax = abs(x)
    sgn = 1 if x >= 0 else -1
    F = S(-0.05, -0.28, z) * S(-0.2, 0.3, -n.z + 0.3)  # front of the face
    d = 0.0
    lid, under, rim, crease, eye_core, socket = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    for i in range(2):
        e, w = eye_space(x, y, i)
        rim = max(rim, G(e - 1.0, 0.18) * F)
        if w > 0:  # above: the lid, then its crease sunk under the brow
            d -= 0.0184 * G(e - 1.45, 0.3) * F
            crease = max(crease, G(e - 1.45, 0.25) * F)
            d += 0.004 * G(e - 1.05, 0.15) * F
        else:  # below: a bag, then the hollow under it
            d += 0.006 * G(e - 1.15, 0.15) * F
            d -= 0.0161 * G(e - 1.6, 0.3) * F
            under = max(under, G(e - 1.6, 0.35) * F)
        eye_core = max(eye_core, S(1.0, 0.85, e) * F)
        socket = max(socket, S(1.9, 1.1, e) * F * (1.0 if w > -0.02 else 0.7))
        d -= 0.005 * G(e - 1.3, 0.35) * F  # the socket sunk deeper round the lids, a cage over the eye
        if e > 1.4 and e < 2.6 and abs(math.atan2(w, x - EYES[i][0]) - (0 if EYES[i][0] > 0 else math.pi)) < 0.6:
            d -= 0.0016 * max(0.0, math.sin(e * 40)) * F  # crow's feet at the outer corner
    tp = G(y - 0.24, 0.12) * G(z + 0.1, 0.14) * S(0.2, 0.3, ax)
    d -= 0.035 * tp  # temples
    # a dry, jagged split in the skin over the left temple, old and bloodless, the yellowed bone showing
    tear, tear_rim = 0.0, 0.0
    if x < -0.18 and n.x < -0.25:
        tdist, tt = seg_dist(Vector((0, y, z)), Vector((0, 0.33, -0.14)), Vector((0, 0.16, -0.02)))
        half = (0.024 + 0.01 * nz(p, 45) + 0.007 * nz(p, 110)) * math.sqrt(max(0.0, math.sin(math.pi * tt)))
        if half > 0:
            tear = S(half, half * 0.55, tdist)
            tear_rim = G(tdist - half, 0.011) * (1 - tear)
    d -= 0.011 * tear
    d += 0.005 * tear_rim  # the skin's edge curled up and dried
    ch = G(ax - 0.19, 0.07) * G(y + 0.22, 0.1) * F
    d -= 0.045 * ch  # the cheek fallen in under the bone
    # the folds from the nose's wings to the corners of the mouth, cheek skin sagging over them
    fold = 0.0
    q = Vector((ax, y, 0))
    dist, t = seg_dist(q, Vector((0.07 + 0.012 * sgn, -0.155, 0)), Vector((0.168, -0.44, 0)))
    side = (ax - (0.07 + 0.098 * t))
    fold = G(dist, 0.012) * F
    d -= 0.007 * fold
    d += 0.007 * G(dist - 0.03, 0.02) * S(-0.01, 0.02, side) * F
    # forehead creases, uneven
    fh = S(0.33, 0.4, y) * S(0.56, 0.5, y) * F
    d -= 0.0022 * fh * max(0.0, math.sin(y * 105 + 4 * nz(p, 3) + 0.6 * x))
    # nostrils and the corners of the mouth
    nostril = 0.0
    for nx in (-0.03, 0.05):
        nostril = max(nostril, G(math.hypot((x - nx) / 0.017, (y + 0.155) / 0.01), 1.0) * S(-0.45, -0.55, z))
    d -= 0.012 * nostril
    corner = G(ax - 0.163, 0.015) * G(y - MOUTH_Y - 0.01, 0.02) * F
    d -= 0.01 * corner
    # neck cords and the hollow at the base of the skull
    d -= 0.02 * G(x, 0.04) * G(y + 0.2, 0.08) * S(0.1, 0.25, z)
    d += 0.0015 * nz(p, 30)  # skin, uneven

    # colour
    c = mul(SKIN, 0.9 + 0.14 * nz(p, 6, 3))
    c = mix(c, (0.56, 0.52, 0.42), 0.35 * S(0.0, 0.6, nz(p, 2.5, 2)))  # yellowed patches
    c = mix(c, SKIN_HOLLOW, min(1.0, 0.9 * tp + 0.8 * ch + 0.7 * under + 0.7 * crease + 0.9 * fold))
    c = mix(c, BRUISE, 0.6 * rim * (1 - eye_core))
    c = mix(c, (0.136, 0.112, 0.104), 0.9 * socket)  # the sockets in deep shadow
    c = mix(c, BRUISE, 0.35 * G(ax - 0.21, 0.08) * G(y + 0.02, 0.06) * F)  # broken veins on the cheek
    if (tp > 0.2 or fh > 0.3) and abs(nz(p * Vector((1, 0.35, 1)), 12)) < 0.045:
        c = mix(c, VEIN, 0.6)
    nose_tip = G(math.hypot(x - 0.016, y + 0.11), 0.05) * S(-0.5, -0.58, z)
    c = mix(c, (0.48, 0.33, 0.30), 0.55 * nose_tip)  # the cold nose
    c = mix(c, VOID, 0.85 * nostril)
    ear = S(0.27, 0.31, ax) * G(y - 0.0, 0.16) * S(-0.08, 0.0, z)
    c = mix(c, (0.44, 0.36, 0.32), 0.35 * ear)
    c = mix(c, mul(SKIN_HOLLOW, 0.6), 0.6 * ear * S(0.0, 0.5, -(n.x * sgn)))  # the dark inside of the ear
    lip = G(y + 0.393, 0.02) * S(0.15, 0.11, ax) * S(-0.38, -0.43, z)
    c = mix(c, LIP, 0.85 * lip)
    if lip > 0.4 and math.sin(x * 160 + 3 * nz(p, 9)) > 0.75:
        c = mul(c, 0.55)  # cracks
    gum = S(-0.4, -0.415, y) * S(0.15, 0.12, ax) * S(-0.33, -0.39, z)
    c = mix(c, GUM, 0.9 * gum)
    if y < MOUTH_Y + 0.006 and n.y < -0.5 and z < -0.15:
        c = MOUTH  # the inside of the mouth
    c = mix(c, (0.20, 0.19, 0.16), 0.5 * S(0.25, 0.7, nz(p, 4, 2)))  # grime
    h = is_hair(p)
    if h > 0:  # lank, grey-brown, darker in the clumps' shadow
        strand = 0.75 + 0.35 * max(0.0, math.sin(x * 260 + z * 120 + 6 * nz(p, 6)))
        c = mix(c, mul(HAIR, strand * (0.85 + 0.3 * nz(p, 9))), h)
        d += 0.0015 * h * math.sin(x * 260 + z * 120)
    if tear > 0 or tear_rim > 0:
        bone = mul(BONE_TEAR, 0.9 + 0.12 * nz(p, 30))
        if abs(nz(p, 22)) < 0.03:
            bone = mul(bone, 0.6)  # hairline cracks in the bone
        c = mix(c, (0.16, 0.12, 0.10), 0.9 * tear_rim)  # the dried edge
        c = mix(c, bone, tear)
    if F > 0.3 and -0.44 < y < -0.18 and ax < 0.16 and nz(p, 70) > 0.42:
        c = mul(c, 0.72)  # grey stubble
    c = mul(c, 0.88 + 0.12 * S(-0.6, 0.0, y))
    if y < -0.3 and z > -0.05:
        c = mix(c, SKIN_HOLLOW, 0.4 * S(-0.3, -0.6, y))  # the neck going down into the collar's shadow
    return d, c


def displace(bm, col, fields):
    moves = []
    for v in bm.verts:
        d, c = fields(v.co, v.normal)
        moves.append((v, v.normal * d))
        paint(v, col, c)
    for v, m in moves:
        v.co += m


def head_high():
    """In the Head part's frame (block 0.82 x 1.4 x 0.98, face -Z)."""
    bm, col = flesh("head_flesh", head_shapes, head_cuts())
    displace(bm, col, head_fields)
    cap(bm, col)
    return bm


def eyeballs(bm, col):
    """Wide, clouded eyeballs in one murky grey-green: no pupil, only a faint darker iris in the same hue."""
    for i, (ex, ey, ez) in enumerate(EYES):
        geom = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
        look = Vector((0.03 * (1 if i == 0 else -1), 0.0, -1)).normalized()  # a slight inward stare
        for v in geom["verts"]:
            nrm = v.co.normalized()
            v.co = Vector((nrm.x * EYE_R[0], nrm.y * EYE_R[1], nrm.z * EYE_R[2])) + Vector((ex, ey, ez))
            a = math.acos(max(-1.0, min(1.0, nrm.dot(look))))
            c = mix(EYE_MURK, mul(EYE_MURK, 0.5), S(0.45, 1.2, a))  # darker towards the lids
            c = mix(c, mul(EYE_MURK, 0.62), 0.85 * S(0.5, 0.36, a))  # the iris, faint, the same murk
            c = mul(c, 0.9 + 0.16 * nz(v.co, 45))  # cloudy
            paint(v, col, c)


def hair(bm, col):
    """What is left of the hair: lank strands from under the cap at the sides and back, more on the left."""
    rnd = random.Random(11)

    def skull(y):  # the skull's half-width and half-depth at height y (widest below 0.22)
        k = math.sqrt(max(0.0, 1 - ((max(y, 0.22) - 0.22) / 0.42) ** 2))
        return 0.315 * k, 0.43 * k

    for k in range(30):
        th = math.radians(rnd.uniform(-72, 72))  # the back half (+Z)
        if math.sin(th) > 0.2 and rnd.random() < 0.45:
            continue  # thinner on the right
        length = rnd.uniform(0.28, 0.62)
        pts, rad = [], []
        for j in range(6):
            t = j / 5
            y = 0.47 - t * length
            hw, hd = skull(y)
            push = 1.06 + 0.04 * t + 0.03 * nz((k, t, 0), 2)
            px = math.sin(th) * hw * push + 0.03 * t * nz((k, 0, t), 1)
            pz = 0.05 + math.cos(th) * hd * push
            if abs(px) > 0.26 and -0.12 < y < 0.2:
                px = math.copysign(max(abs(px), 0.37), px)  # over the ear, not through it
            pts.append((px, y, pz))
            rad.append(0.02 * (1 - 0.7 * t) + 0.003)
        rings = tube_rings(bm, col, pts, rad, 3, flat=0.4,
                           colour=lambda i, s, co: mul(HAIR, 0.8 + 0.4 * nz(co, 20)))
        loft(bm, rings, cap0=True, cap1=True)



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


UPPER_TEETH = [  # x, length, tilt, radius: two long front teeth, the rest short, one gone, one broken
    (-0.105, 0.04, -0.12, 0.013), (-0.068, 0.05, -0.05, 0.014), (-0.024, 0.088, 0.0, 0.019),
    (0.02, 0.082, 0.04, 0.018), (0.063, 0.03, 0.02, 0.014), (0.112, 0.055, 0.1, 0.014),
]


def upper_teeth(bm, col):
    specs = []
    for x, length, tilt, r in UPPER_TEETH:
        z = -0.408 + 1.5 * x * x
        specs.append(((x, -0.418, z), (tilt, -1, -0.1), length, r))
    teeth(bm, col, specs)


# ------------------------------------------------------------------ jaw
JAW_FRAME = Vector((0, -0.80, -0.12))  # the Jaw part's centre in the Head frame at rest (HollowBuilder Jaw joint)


def jaw_shapes(bm):
    """A mandible, not a ball: the jaw line from the chin back to each angle, the ramus rising under the cheek
    (hidden in the head), the chin, the lower lip, and loose skin slung between the jaw lines."""
    for sx in (-1, 1):
        rod(bm, (sx * 0.05, -0.75, -0.33), (sx * 0.172, -0.615, -0.02), 0.042, 0.05)  # the jaw line
        rod(bm, (sx * 0.172, -0.615, -0.02), (sx * 0.19, -0.42, 0.02), 0.04, 0.05)  # the ramus
        blob(bm, (sx * 0.125, -0.56, -0.29), (0.04, 0.06, 0.05))  # jowl, sagging
    blob(bm, (0.01, -0.70, -0.31), (0.085, 0.075, 0.07))  # chin
    blob(bm, (0.012, -0.755, -0.325), (0.055, 0.032, 0.045))  # the chin's point
    blob(bm, (0, -0.55, -0.27), (0.15, 0.1, 0.12))  # under the lower lip
    blob(bm, (0, -0.5, -0.16), (0.17, 0.08, 0.16))  # inside, to close the mouth's floor
    blob(bm, (0.0, -0.48, -0.395), (0.105, 0.024, 0.036), (0, 0, 3))  # lower lip
    blob(bm, (0, -0.52, -0.37), (0.12, 0.05, 0.05))
    blob(bm, (0, -0.71, -0.15), (0.11, 0.04, 0.12))  # loose skin under the chin
    blob(bm, (0, -0.655, -0.12), (0.15, 0.06, 0.17))  # the floor between the jaw lines


def jaw_cuts():
    def top(bm):
        box(bm, (-0.136, -0.462, -0.8), (0.136, 0.2, 0.3))  # the mouth
        box(bm, (-0.6, -0.40, -0.8), (0.6, 0.2, 0.3))  # beyond the mouth, hidden under the cheeks
    return [top]


def jaw_fields(p, n):
    x, y, z = p.x, p.y, p.z
    ax = abs(x)
    F = S(-0.05, -0.25, z)
    d = 0.0
    d -= 0.012 * G(y + 0.6, 0.04) * G(ax - 0.07, 0.04) * F  # the dip under the lip
    d -= 0.02 * G(ax - 0.16, 0.05) * G(y + 0.52, 0.06) * S(0.0, -0.15, z)  # the hollow under the cheek
    d += 0.003 * nz(p, 30)
    c = mul(SKIN, 0.86 + 0.14 * nz(p, 7, 3))
    c = mix(c, SKIN_HOLLOW, 0.6 * G(ax - 0.16, 0.06) * G(y + 0.52, 0.07) + 0.5 * S(-0.7, -0.78, y))
    lip = G(y + 0.476, 0.016) * S(0.13, 0.09, ax) * S(-0.35, -0.41, z)
    c = mix(c, LIP, 0.85 * lip)
    if lip > 0.4 and math.sin(x * 150 + 3 * nz(p, 9)) > 0.75:
        c = mul(c, 0.55)
    if y > -0.47 and n.y > 0.5:
        c = MOUTH
    c = mix(c, (0.20, 0.19, 0.16), 0.5 * S(0.25, 0.7, nz(p, 4, 2)))
    if F > 0.2 and y < -0.5 and nz(p, 70) > 0.4:
        c = mul(c, 0.72)  # grey stubble
    return d, mul(c, 0.82)  # in the shadow of the face


def jaw_high():
    """Built in the Head frame (moved to the Jaw frame by to_jaw_frame)."""
    bm, col = flesh("jaw_flesh", jaw_shapes, jaw_cuts())
    displace(bm, col, jaw_fields)
    return bm


LOWER_TEETH = [(-0.07, 0.035, 0.10, 0.012), (-0.035, 0.045, 0.0, 0.013), (0.0, 0.028, -0.05, 0.013),
               (0.04, 0.045, -0.06, 0.012), (0.078, 0.03, -0.14, 0.011)]


def lower_teeth(bm, col):
    specs = []
    for x, length, tilt, r in LOWER_TEETH:
        z = -0.375 + 1.5 * x * x
        specs.append(((x, -0.475, z), (tilt, 1, -0.06), length, r))
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
    """Along X, wrist at -X, elbow at +X. The coat's lower sleeve hangs loose to a frayed cuff a little above the
    wrist, so only the bony wrist shows (a bare forearm read as a pale rod): the cloth tube, the cuff turning
    inward, then the wrist with its tendons and knob."""
    bm, col = new_bm()
    rnd = random.Random(5)
    sides = 18
    CUFF = 0.24  # where the cuff ends (t from the wrist)
    jag = [rnd.uniform(-0.035, 0.035) + (0.05 if k % 5 == 2 else 0.0) for k in range(sides)]

    def cloth_r(t, phi):
        r = d / 2 * (1.15 + 0.12 * S(1.0, CUFF, t))  # hanging loose, the cuff a little open
        r *= 1 + 0.07 * math.sin(t * 46 + 1.4 * math.sin(phi)) * S(0.45, 0.25, t)  # folds slumped at the cuff
        r *= 1 + 0.05 * math.sin(3 * phi + t * 9)
        return r

    def skin_r(t, phi):
        r = d / 2 * (0.6 + 0.4 * t / CUFF)
        r *= 1 + 0.1 * math.cos(2 * phi)
        r *= 1 + 0.05 * max(0.0, math.cos(6 * phi))  # tendons
        r *= 1 + 0.2 * G(t - 0.04, 0.04) * G(angd(phi, -math.pi / 2), 0.7)  # the wrist knob
        return r

    def cloth_c(t, phi, co):
        c = wool(co)
        c = mix(c, WOOL_WORN, 0.55 * G(t - 0.95, 0.08) * G(angd(phi, math.pi / 2), 0.8))  # the worn elbow
        if abs(angd(phi, math.pi)) < 0.06:
            c = STITCH if int(t * 120) % 2 else SEAM
        c = mix(c, MUD, 0.5 * S(0.4, CUFF, t) * S(0.0, 0.6, nz(co, 5)))
        return mix(c, WOOL_WORN, 0.5 * S(CUFF + 0.06, CUFF, t))

    def skin_c(co):
        c = mul(SKIN, 0.8 + 0.15 * nz(co, 7, 3))
        if abs(nz(co * Vector((0.3, 1, 1)), 9)) < 0.05:
            c = mix(c, VEIN, 0.5)
        return mix(c, (0.20, 0.16, 0.12), 0.4 * S(0.0, 0.6, nz(co, 4)))  # grime

    x_of = lambda t: -length / 2 + t * length
    rings = []
    for i in range(30):  # cloth, elbow to cuff
        t = 1 - (1 - CUFF) * i / 29
        rings.append(ring_x(bm, col, x_of(t), sides, lambda phi: cloth_r(t, phi), lambda phi, co: cloth_c(t, phi, co)))
    # the frayed lip, turning in to the arm
    lip = []
    for k in range(sides):
        phi = k / sides * TAU
        r = cloth_r(CUFF, phi) * 0.96
        co = Vector((x_of(CUFF) - jag[k] * length, math.cos(phi) * r, math.sin(phi) * r))
        v = bm.verts.new(co)
        paint(v, col, mul(mix(WOOL, WOOL_WORN, 0.6), 0.8))
        lip.append(v)
    rings.append(lip)
    inner = []
    for k in range(sides):
        phi = k / sides * TAU
        r = skin_r(CUFF, phi) * 1.12
        co = Vector((x_of(CUFF) + 0.05, math.cos(phi) * r, math.sin(phi) * r))
        v = bm.verts.new(co)
        paint(v, col, VOID)  # the dark inside of the sleeve
        inner.append(v)
    rings.append(inner)
    for i in range(12):  # the wrist, from inside the cuff to the hand
        t = CUFF * (1 - i / 11)
        rings.append(ring_x(bm, col, x_of(t) + (0.05 if i == 0 else 0.0), sides, lambda phi: skin_r(t, phi), lambda phi, co: skin_c(co)))
    loft(bm, rings, cap0=True, cap1=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def sleeve_high(length=2.9, d=0.32):
    """Along X, shoulder at +X, the elbow at -X, where the forearm's lower sleeve carries on."""
    bm, col = new_bm()
    sides = 20

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
        return c

    rings = []
    for i in range(36):
        t = 1 - i / 35
        rings.append(ring_x(bm, col, -length / 2 + t * length, sides, lambda phi: outer(t, phi), lambda phi, co: colour(t, phi, co)))

    loft(bm, rings, cap0=True, cap1=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ------------------------------------------------------------------ hand
FINGERS = [(-0.135, 0.85), (-0.045, 1.0), (0.045, 0.96), (0.135, 0.78)]


def hand_colour(co, nail=-1.0):
    c = mul(SKIN, 0.82 + 0.15 * nz(co, 9, 2))
    stain = S(-0.3, -1.0, co.y) * (0.45 + 0.45 * nz(co, 5, 2)) + 0.25 * S(0.0, -0.05, co.z) * S(0.1, -0.2, co.y)
    c = mix(c, (0.16, 0.12, 0.10), min(1.0, stain))  # grime worked into the fingers and the creases
    if abs(nz(co * Vector((1, 0.4, 1)), 12)) < 0.05:
        c = mix(c, VEIN, 0.4)
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



# ------------------------------------------------------------------ legs
# The railwayman's serge trousers, cut for the man he was, hanging loose on legs gone to bone, over cracked lace-up
# boots. The thigh and shin pieces sit on HollowBuilder's leg bones (frames along X, hip or knee end at +X, front
# -Z); the boot on the Foot block (0.4 x 0.2 x 0.9, Y up, toe to -Z). The two shins and two boots differ.
THIGH_LEN, SHIN_LEN = 2.1, 1.85


def trouser_colour(co, phi, worn=0.0):
    c = wool(co)
    c = mix(c, WOOL_WORN, (0.25 + worn) * G(angd(phi, -math.pi / 2), 0.3))  # the front crease, rubbed shiny
    for seam in (0.0, math.pi):  # outside and inside seams: one piece serves either leg
        if abs(angd(phi, seam)) < 0.045:
            c = mix(c, STITCH if int((co.x + 3) * 55) % 2 else SEAM, 0.45)
    return c


def thigh_high():
    """Hip at +X (under the coat), knee at -X. Loose wool with the bony knee pressing through at the front, sag
    folds behind the knee and a darned patch above it."""
    bm, col = new_bm()
    sides = 22
    top, bot = THIGH_LEN / 2 + 0.1, -THIGH_LEN / 2 - 0.12

    def radius(x, phi):
        t = (top - x) / (top - bot)  # 0 at the hip, 1 at the knee
        r = 0.31 - 0.062 * t + 0.12 * S(0.55, top, x)  # full at the seat, so the two legs meet at the fork
        calm = S(bot, bot + 0.35, x)  # the folds die away where it meets the shin
        r *= 1 + 0.05 * calm * math.sin(5 * phi + 2.5 * nz(Vector((x, phi, 0)), 1.3))  # the drape, hanging slack
        r *= 1 + 0.035 * math.sin(3 * phi + x * 4.0) * S(1.1, 0.2, x)  # creases pulled down from the fork
        r *= 1 + 0.13 * G(x + 0.9, 0.12) * G(angd(phi, -math.pi / 2), 0.55)  # the knee, through the cloth
        r *= 1 + 0.05 * math.sin(x * 38) * G(angd(phi, math.pi / 2), 0.8) * G(x + 0.78, 0.22)  # behind the knee
        r *= 1 - 0.07 * G(angd(phi, 0.0), 0.5) * G(x - 0.1, 0.5)  # the bone shows where the cloth falls in
        return r

    def colour(x, phi, co):
        c = trouser_colour(co, phi, worn=0.35 * G(x + 0.9, 0.15))
        u, v = angd(phi, -math.pi / 2 + 0.45) * 0.3, x + 0.55  # the darn, front and a little inside
        if abs(u) < 0.075 and abs(v) < 0.1:
            edge = abs(u) > 0.06 or abs(v) > 0.085
            c = (STITCH if int(v * 90) % 2 else SEAM) if edge else mul(WOOL_WORN, 0.75 + 0.2 * nz(co * 4, 9))
        c = mix(c, MUD, 0.35 * S(-0.5, -1.1, x) * S(0.2, 0.7, nz(co, 5)))
        return c

    rings = []
    n = 44
    for i in range(n):
        x = top - (top - bot) * i / (n - 1)
        rings.append(ring_x(bm, col, x, sides, lambda phi: radius(x, phi), lambda phi, co: colour(x, phi, co)))
    for dx, k in ((0.012, 0.93), (0.03, 0.8)):  # the end turned in under itself
        rings.append(ring_x(bm, col, bot + dx, sides, lambda phi: radius(bot, phi) * k,
                            lambda phi, co: mul(colour(bot, phi, co), 0.6)))
    loft(bm, rings, cap0=True, cap1=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def shin_high(variant=0):
    """Knee at +X, the trousers too long for him: concertina folds above a frayed hem that hangs over the boot
    top. Variant 0: a rip up from the hem at the front. Variant 1: the hem torn
    ragged, longer at the back, and caked in mud."""
    bm, col = new_bm()
    rnd = random.Random(11 + variant)
    sides = 22
    top = SHIN_LEN / 2 + 0.12
    hem = -SHIN_LEN / 2 + 0.22

    def hem_x(phi):
        drop = 0.06 * G(angd(phi, math.pi / 2), 0.9) if variant == 1 else 0.0  # longer at the back
        return hem - drop

    jag = [rnd.uniform(-0.03, 0.03) + ((0.07 if k % 4 == 1 else -0.02) if variant == 1 else 0.0)
           for k in range(sides)]
    if variant == 0:
        jag[sides * 3 // 4] -= 0.09  # a rip up from the hem at the front

    def radius(x, phi):
        r = 0.243 - 0.012 * S(top - 0.26, top, x) - 0.01 * S(0.6, -0.3, x) + 0.035 * S(-0.3, hem, x)
        r *= 1 + 0.05 * S(top, top - 0.4, x) * math.sin(4 * phi + 1.7 * nz(Vector((x, phi, 1)), 1.1))
        r *= 1 + 0.08 * math.sin(x * 52 + 1.6 * math.sin(phi)) * S(-0.2, hem + 0.1, x)  # bunched folds
        r *= 1 - 0.06 * G(angd(phi, -math.pi / 2), 0.4) * G(x - 0.1, 0.35)  # cloth falls onto the shin bone
        return r

    def colour(x, phi, co):
        c = trouser_colour(co, phi)
        c = mix(c, mul(MUD, 0.7), (0.3 + 0.2 * variant) * S(-0.15, hem, x) * S(0.0, 0.8, nz(co, 4)))
        return c

    rings = []
    for dx, k in ((0.03, 0.8), (0.012, 0.93)):  # the top turned in, inside the thigh's end
        rings.append(ring_x(bm, col, top - dx, sides, lambda phi: radius(top, phi) * k,
                            lambda phi, co: mul(trouser_colour(co, phi), 0.6)))
    n = 40
    for i in range(n):
        x = top - (top - (hem + 0.02)) * i / (n - 1)
        rings.append(ring_x(bm, col, x, sides, lambda phi: radius(x, phi), lambda phi, co: colour(x, phi, co)))
    lip = []
    for k in range(sides):
        phi = k / sides * TAU
        r = radius(hem, phi) * 0.97
        co = Vector((hem_x(phi) - jag[k], math.cos(phi) * r, math.sin(phi) * r))
        v = bm.verts.new(co)
        paint(v, col, mix(mul(mix(WOOL, WOOL_WORN, 0.4), 0.75), mul(MUD, 0.7), 0.25 + 0.15 * variant))
        lip.append(v)
    rings.append(lip)
    inner = []
    for k in range(sides):
        phi = k / sides * TAU
        r = radius(hem, phi) * 0.78
        co = Vector((hem + 0.06, math.cos(phi) * r, math.sin(phi) * r))
        v = bm.verts.new(co)
        paint(v, col, VOID)  # the dark inside of the trouser leg
        inner.append(v)
    rings.append(inner)
    loft(bm, rings, cap0=True, cap1=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


BOOT_TOP = 0.46  # the shaft's open top, in the Foot frame (the ankle sits at +0.1)


def keyed(table, z):
    """Linear interpolation through (z, value) pairs."""
    if z <= table[0][0]:
        return table[0][1]
    for (z0, a), (z1, b) in zip(table, table[1:]):
        if z <= z1:
            return a + (b - a) * (z - z0) / (z1 - z0)
    return table[-1][1]


def section_loft(bm, zs, width, bottom, top, n=2.6, sides=28):
    """A closed solid lofted along Z through rounded-box sections: half-width width(z), from bottom(z) to top(z)."""
    rings = []
    for z in zs:
        w, b, t = width(z), bottom(z), top(z)
        mid, hh = (b + t) / 2, max(0.004, (t - b) / 2)
        ring = []
        for k in range(sides):
            a = k / sides * TAU
            ca, sa = math.cos(a), math.sin(a)
            x = w * math.copysign(abs(ca) ** (2 / n), ca)
            y = mid + hh * math.copysign(abs(sa) ** (2 / n), sa)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    loft(bm, rings, cap0=True, cap1=True)


BOOT_W = [(-0.53, 0.025), (-0.5, 0.07), (-0.44, 0.1), (-0.32, 0.125), (-0.2, 0.13), (-0.05, 0.118), (0.1, 0.104),
          (0.22, 0.112), (0.31, 0.105), (0.36, 0.07), (0.375, 0.03)]
BOOT_TOPLINE = [(-0.53, -0.045), (-0.46, -0.01), (-0.32, 0.035), (-0.16, 0.09), (0.0, 0.17), (0.14, 0.2),
                (0.26, 0.17), (0.34, 0.11), (0.375, 0.05)]


def boot_shapes(variant):
    def build(bm):
        zs = [-0.53 + 0.905 * i / 40 for i in range(41)]
        # the upper, on its last: low pointed toe, high instep, the heel counter
        section_loft(bm, zs, lambda z: keyed(BOOT_W, z), lambda z: -0.065, lambda z: keyed(BOOT_TOPLINE, z))
        # the sole, a little proud of the upper all round
        section_loft(bm, [-0.535 + 0.915 * i / 40 for i in range(41)], lambda z: keyed(BOOT_W, z) + 0.012,
                     lambda z: -0.1, lambda z: -0.058, n=5)
        # the heel, stacked under the back
        section_loft(bm, [0.17 + 0.2 * i / 10 for i in range(11)], lambda z: keyed(BOOT_W, z) * 0.95,
                     lambda z: -0.122, lambda z: -0.09, n=5)
        rod(bm, (0, 0.08, 0.13), (0, BOOT_TOP, 0.1), 0.128)  # the shaft, round the ankle
    return build


def boot_cuts(variant):
    def shaft(bm):
        rod(bm, (0, BOOT_TOP - 0.09, 0.1), (0, BOOT_TOP + 0.3, 0.1), 0.1)
    cuts = [shaft]
    if variant == 1:
        def split(bm):  # the sole come away from the upper at the toe
            box(bm, (-0.2, -0.068, -0.62), (0.2, -0.05, -0.32))
        cuts.append(split)
    return cuts


def boot_fields(variant):
    broken = 0.24 if variant == 0 else 9.0  # variant 0's laces end here, the tongue lolling out above

    def fields(p, n):
        d = 0.0
        c = mul(LEATHER, 0.85 + 0.45 * nz(p * 3, 7, 3))
        front = S(-0.2, -0.75, n.z)
        # creases across the instep where it flexed, and the cracks along them
        flex = G(p.z + 0.17, 0.12) * S(-0.07, 0.05, p.y)
        crease = max(0.0, math.sin(p.z * 60 + 3 * nz(p * 2, 3)))
        d -= 0.006 * crease * flex
        if abs(nz(p * Vector((1.4, 1, 0.35)), 21)) < 0.035 * flex + 0.008:
            c = mix(c, (0.13, 0.11, 0.09), 0.7)
        # scuffed toe and heel, gone grey-brown
        c = mix(c, (0.16, 0.13, 0.10), 0.6 * G(p.z + 0.48, 0.1) * S(0.0, 0.6, nz(p * 2, 4)))
        c = mix(c, (0.14, 0.12, 0.09), 0.4 * G(p.z - 0.33, 0.06))
        # the toe cap seam
        if abs(p.z + 0.3 + 0.03 * math.cos(p.x * 9)) < 0.007 and p.y > -0.055:
            c = STITCH if int((p.x + 1) * 70) % 2 else SEAM
        # the sole and welt, mud on the edges
        if p.y < -0.055:
            c = mix((0.07, 0.06, 0.05), MUD, 0.6 * S(0.0, 0.6, nz(p * 4, 8)))
            if abs(p.y + 0.06) < 0.005:
                c = STITCH if int((p.z + 1) * 80) % 2 else SEAM
        # laces and eyelets up the front of the shaft
        if front > 0.3 and 0.0 < p.y < BOOT_TOP - 0.03 and p.z < 0.06:
            row = (p.y - 0.0) / 0.055
            near = abs(row - round(row))
            for sx in (-0.055, 0.055):
                if abs(p.x - sx) < 0.012 and near < 0.12:
                    c = (0.30, 0.27, 0.21) if p.y < broken else (0.10, 0.09, 0.08)  # tarnished eyelets
                    d += 0.003
            u = (p.y - 0.0) / 0.055 % 1.0
            cross = abs(p.x - (-0.055 + 0.11 * u)) < 0.008 or abs(p.x - (0.055 - 0.11 * u)) < 0.008
            if cross and abs(p.x) < 0.05 and p.y < broken:
                c, d = (0.06, 0.055, 0.05), d + 0.004
            if p.y >= broken and abs(p.x) < 0.04:
                c = mix(c, (0.11, 0.09, 0.07), 0.6)  # the tongue, paler where it shows
                d += 0.01 * S(broken, BOOT_TOP, p.y)
        # the open top: dark inside
        if p.y > BOOT_TOP - 0.05 and n.y < 0.3:
            c = mix(c, VOID, S(BOOT_TOP - 0.05, BOOT_TOP - 0.1, p.y))
        if variant == 1 and -0.07 < p.y < -0.03 and p.z < -0.28:
            c = VOID  # the split's dark mouth
        return d, c
    return fields


def boot_high(variant=0):
    bm, col = flesh("boot_flesh%d" % variant, boot_shapes(variant), boot_cuts(variant), smooth=4)
    displace(bm, col, boot_fields(variant))
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
        f["shin" + side] = f["thigh" + side] @ T(0, -1.975, 0)  # straight on from the thigh, as the knee joint has it
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
        bone = A(0, 0, 90)  # a leg bone's frame runs along X, hip end up
        if "thigh" in pieces:
            place(pieces["thigh"], f["thigh" + side] @ bone)
        else:
            prim("box", (0.46, 2.1, 0.46), f["thigh" + side], GAME["TROUSER"])
        if "shin" in pieces:
            place(pieces["shin" if side == "R" else "shinL"], f["shin" + side] @ bone)
        else:
            prim("box", (0.3, 1.85, 0.3), f["shin" + side], GAME["SKIN"])
        if "boot" in pieces:
            place(pieces["boot" if side == "R" else "bootL"], f["foot" + side] @ T(0, 0, 0.25))
        else:
            prim("box", (0.4, 0.2, 0.9), f["foot" + side], GAME["SKIN_DARK"])
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


def lights_off():
    for o in list(bpy.context.scene.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o)


def renders(pieces, extras, prefix, outdir, full=True):
    """front, side, back: the whole figure in plain light. face: arm's length (a grab), plain light; gaslight:
    the same in a dim warm lamp. phone: the grab framing at a phone's 640 x 360, arms reaching. far: 28 studs
    off down a dark platform under one lamp. silhouette: the shape alone, flat black on fog at 30 studs."""
    f = figure(pieces, extras)
    shots = [("front", Vector((2.6, 5.2, -11.5))), ("side", Vector((11.5, 5.0, -0.5))), ("back", Vector((-2.6, 5.4, 11.5)))]
    for name, eye in shots if full else shots[:1]:
        daylight(Vector((0, 4, 0)))
        camera(eye, Vector((0, 4.2, 0)), fov=48)
        render(outdir / f"{prefix}{name}.png", 1000, 1400)
        lights_off()
    head = f["head"].translation
    look = head + Vector((0, -0.12, 0))
    daylight(head)
    camera(head + Vector((0.9, -0.2, -3.2)), look, fov=30)
    render(outdir / f"{prefix}face.png", 1000, 1000)
    lights_off()
    gaslight(head)
    camera(head + Vector((0.9, -0.2, -3.2)), look, fov=30)
    render(outdir / f"{prefix}gaslight.png", 1000, 1000)
    lights_off()
    if full:
        world((0.004, 0.005, 0.008), 1.0)
        light("POINT", Vector((-3.0, 9.0, -4.0)), 900, (1.0, 0.62, 0.30), size=0.3)
        camera(Vector((1.5, 5.2, -28.0)), Vector((0, 4.5, 0)), fov=70)
        render(outdir / f"{prefix}far.png", 1280, 720, samples=48)
        lights_off()
        sc = bpy.context.scene
        black = flat_material((0.0, 0.0, 0.0))
        sc.view_layers[0].material_override = black
        world((0.55, 0.57, 0.6), 1.0)
        camera(Vector((0, 5.0, -30.0)), Vector((0, 4.5, 0)), fov=70)
        render(outdir / f"{prefix}silhouette.png", 1280, 720, samples=8)
        sc.view_layers[0].material_override = None
        lights_off()
        daylight(Vector((0, 1.6, 0)))
        camera(Vector((2.4, 3.8, -4.4)), Vector((0, 1.6, 0)), fov=44)
        render(outdir / f"{prefix}legs.png", 1000, 1000)
        lights_off()
        clear_figure()
        f = figure(pieces, extras, reach=(62, 80))
        head = f["head"].translation
        gaslight(head)
        camera(head + Vector((0.1, -0.35, -2.4)), head + Vector((0, -0.3, 0)), fov=70)
        render(outdir / f"{prefix}phone.png", 1280, 720, samples=32)
        lights_off()
    clear_figure()


def sheet(objs):
    """The pieces side by side under plain light, textures on."""
    spots = {"stalker_head": (-4.6, 1.2), "stalker_jaw": (-4.6, -0.4), "stalker_torso": (-2.6, 0.3),
             "stalker_coat": (0.0, 1.5), "stalker_sleeve": (2.2, 0.0), "stalker_forearm": (3.0, 0.0),
             "stalker_hand": (3.9, 0.6), "stalker_handL": (4.7, 0.6)}
    for o in objs:
        if o.name not in spots:
            continue  # the legs have their own renders
        x, y = spots[o.name]
        long = o.name in ("stalker_forearm", "stalker_sleeve")
        place(o, T(x, y, 0) @ (A(0, 0, -90) if long else Matrix()))
    daylight(Vector((0, 0, 0)))
    camera(Vector((0, -0.2, -14)), Vector((0, -0.2, 0)), ortho=5.6)
    render(OUT / "sheet.png", 2000, 1000, samples=24)
    clear_figure()


def colour_material():
    m = bpy.data.materials.get("vcol")
    if m:
        return m
    m = bpy.data.materials.new("vcol")
    m.use_nodes = True
    nt = m.node_tree
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "col"
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.75
    nt.links.new(attr.outputs["Color"], b.inputs["Base Color"])
    return m


def preview(outdir):
    """The head and jaw straight from the high meshes (vertex colours, no bake): front, three-quarter, profile
    and gaslight, for working on the face."""
    parts = []
    hb = head_high()
    parts.append((make_object("pv_head", hb, closed=True), Matrix()))
    for build in (upper_teeth, eyeballs):
        bm, col = new_bm()
        build(bm, col)
        parts.append((make_object("pv_x", bm, closed=True), Matrix()))
    jb = jaw_high()
    lt, ltc = new_bm()
    lower_teeth(lt, ltc)
    parts.append((make_object("pv_jaw", jb, closed=True), Matrix()))
    parts.append((make_object("pv_lt", lt, closed=True), Matrix()))
    root = T(0, 5, 0)
    for o, M in parts:
        o.data.materials.append(colour_material())
        place(o, root @ M)
        o.hide_render = True
    head = Vector((0, 5, 0))
    shots = [("pv_front", Vector((0, 0.05, -3.4)), 26), ("pv_34", Vector((1.9, 0.1, -2.8)), 26),
             ("pv_side", Vector((3.4, 0.05, 0)), 26), ("pv_back", Vector((-1.5, 0.3, 3.0)), 26), ("pv_left34", Vector((-2.2, 0.25, -2.4)), 24)]
    for name, eye, fov in shots:
        daylight(head)
        camera(head + eye, head + Vector((0, -0.05, 0)), fov=fov)
        render(outdir / f"{name}.png", 900, 900, samples=24)
        for o in list(bpy.context.scene.objects):
            if o.type in ("LIGHT", "CAMERA"):
                bpy.data.objects.remove(o)
    gaslight(head)
    camera(head + Vector((0.9, -0.2, -3.2)), head + Vector((0, -0.1, 0)), fov=30)
    render(outdir / "pv_gas.png", 900, 900, samples=32)


def legs_preview(outdir):
    """The legs straight from the high meshes (vertex colours, no bake) on the figure's frames: front
    three-quarter, side and back of the knees down, and the boots close, for working on the trousers and boots."""
    f = frames((25, 50))
    for side in ("L", "R"):
        for build, frame in ((thigh_high(), f["thigh" + side] @ A(0, 0, 90)),
                             (shin_high(0 if side == "R" else 1), f["shin" + side] @ A(0, 0, 90)),
                             (boot_high(0 if side == "R" else 1), f["foot" + side] @ T(0, 0, 0.25))):
            o = make_object("pv_leg", build, closed=True)
            o.data.materials.append(colour_material())
            place(o, frame)
            o.hide_render = True
    at = Vector((0, 1.6, 0))
    shots = [("legs_front34", Vector((2.4, 2.2, -4.4)), 44, at), ("legs_side", Vector((4.6, 1.8, -0.3)), 44, at),
             ("legs_back", Vector((-2.0, 2.0, 4.4)), 44, at),
             ("legs_boots", Vector((1.3, 0.75, -1.9)), 40, Vector((0, 0.2, -0.1)))]
    for name, eye, fov, look in shots:
        daylight(look)
        camera(look + eye, look, fov=fov)
        render(outdir / f"{name}.png", 900, 900, samples=24)
        lights_off()
    gaslight(Vector((0, 1.2, 0)))
    camera(Vector((1.6, 1.4, -3.2)), Vector((0, 0.9, 0)), fov=44)
    render(outdir / "legs_gas.png", 900, 900, samples=32)


PIECES = [  # name, high mesh, triangles (close-up, Performance), texture (close-up, Performance), occlusion distance
    ("stalker_head", "head", (4200, 1800), (1024, 512), 0.25),
    ("stalker_jaw", "jaw", (900, 320), (512, 256), 0.15),
    ("stalker_torso", "torso", (820, 420), (512, 256), 0.5),
    ("stalker_coat", "coat", (720, 380), (512, 256), 0.5),
    ("stalker_sleeve", "sleeve", (300, 140), (256, 128), 0.25),
    ("stalker_forearm", "forearm", (360, 160), (256, 128), 0.2),
    ("stalker_thigh", "thigh", (320, 140), (256, 128), 0.25),
    ("stalker_shin", "shin", (380, 170), (512, 256), 0.2),
    ("stalker_shinL", "shinL", (380, 170), (512, 256), 0.2),
    ("stalker_boot", "boot", (700, 300), (512, 256), 0.12),
    ("stalker_bootL", "bootL", (700, 300), (512, 256), 0.12),
    ("stalker_hand", "hand", (340, 170), (256, 128), 0.15),
]


def build_set(tier, report):
    """Every piece at one tier (0: close-up, 1: Performance). The high meshes are rebuilt for each tier."""
    suffix = "" if tier == 0 else "_perf"
    objs = []
    for name, kind, targets, sizes, ao in PIECES:
        extra, solid, closed = None, 0.0, True
        if kind == "head":
            bm, col = new_bm()
            upper_teeth(bm, col)
            eyeballs(bm, col)
            extra = make_object("head_x", bm, closed=True)
            high = head_high()
        elif kind == "jaw":
            bm, col = new_bm()
            lower_teeth(bm, col)
            to_jaw_frame(bm)
            extra = make_object("jaw_x", bm, closed=True)
            high = jaw_high()
            to_jaw_frame(high)
        elif kind in ("torso", "coat"):
            high, solid, closed = (torso_high() if kind == "torso" else coat_high()), 0.035, False
        elif kind == "sleeve":
            high, closed = sleeve_high(), False
        elif kind == "thigh":
            high = thigh_high()
        elif kind in ("shin", "shinL"):
            high = shin_high(1 if kind == "shinL" else 0)
        elif kind in ("boot", "bootL"):
            high = boot_high(1 if kind == "bootL" else 0)
        else:
            high = forearm_high() if kind == "forearm" else hand_high()
        objs.append(piece(name + suffix, high, targets[tier], sizes[tier], ao, extra=extra, solid=solid, closed=closed))
    objs.append(mirror_x(objs[-1], "stalker_handL" + suffix))
    for o in objs:
        export(o, report, o.name.replace("stalker_handL", "stalker_hand") + ".png")
        o.hide_render = True  # the renders use placed copies
    return objs


def main():
    clear()
    if bpy.context.scene.world is None:
        bpy.context.scene.world = bpy.data.worlds.new("w")
    if "--preview" in sys.argv:
        preview(OUT)
        return
    if "--legs" in sys.argv:
        legs_preview(OUT)
        return
    report = {}
    close = build_set(0, report)
    perf = build_set(1, report) if "--no-perf" not in sys.argv else []
    twice = {"stalker_sleeve", "stalker_forearm", "stalker_thigh"}  # one mesh on each arm or leg
    for perf_tier in (False, True):
        report["figure_tris" + ("_perf" if perf_tier else "")] = sum(
            v["tris"] * (2 if k.removesuffix("_perf") in twice else 1)
            for k, v in report.items() if isinstance(v, dict) and k.endswith("_perf") == perf_tier)
    (OUT / "report.json").write_text(json.dumps(report, indent=1))
    print(json.dumps(report))
    if "--no-render" not in sys.argv:
        sheet(close)
        renders({o.name.replace("stalker_", ""): o for o in close}, no_extras, "", OUT)
        if perf:
            renders({o.name.replace("stalker_", "").replace("_perf", ""): o for o in perf}, no_extras, "perf_", OUT, full=False)


if __name__ == "__main__":
    main()
