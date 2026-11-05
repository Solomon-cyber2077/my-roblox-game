"""Blender 5.2: the five train residents (Config/Npcs) as single phone-cheap meshes.

blender -b --python tools/npc-figures/build.py -- <out dir> [--no-render]

Each figure is one mesh with one 1024 texture (a cell atlas: woven, leather, metal and skin
grain, grime rising from the hem, a painted face), feet on z = 0, facing -Y here and -Z in the
exported OBJ (Roblox MeshPart front). Heights are in studs. Writes <id>.obj/.mtl/.png, a
.blend of the lot and 50% review renders (lineup front and back, heads close up).
"""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector, Matrix
import numpy as np

OUT = Path(sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'assets/npc-figures')
OUT.mkdir(parents=True, exist_ok=True)
TEX, CELL = 1024, 128  # 8x8 cells; the face takes the top-right 2x2
FACE_CELL = (6, 6)


class Mesh:
    """Accumulates one figure: verts, faces, per-face material key and smooth flag."""

    def __init__(self):
        self.v, self.f, self.mat, self.smooth = [], [], [], []
        self.face_proj = None  # (centre, radii) of the head for the face projection

    def add(self, pts, faces, keys, smooth=True):
        o = len(self.v)
        self.v += [tuple(p) for p in pts]
        for n, f in enumerate(faces):
            self.f.append(tuple(i + o for i in f))
            self.mat.append(keys[n] if isinstance(keys, list) else keys)
            self.smooth.append(smooth)

    def lathe(self, mat, rings, seg=24, arc=None, caps=(True, True), matfn=None):
        """rings: (z, rx, ry, cy[, cx]); angle 0 is the front (-Y)."""
        closed = arc is None
        n = seg if closed else seg + 1
        a0, a1 = (0, math.tau) if closed else arc
        pts = []
        for r in rings:
            z, rx, ry, cy = r[:4]
            cx = r[4] if len(r) > 4 else 0
            for i in range(n):
                a = a0 + (a1 - a0) * i / seg
                pts.append((cx + rx * math.sin(a), cy - ry * math.cos(a), z))
        faces, keys = [], []
        for j in range(len(rings) - 1):
            for i in range(seg):
                i2 = (i + 1) % n if closed else i + 1
                faces.append((j * n + i, j * n + i2, (j + 1) * n + i2, (j + 1) * n + i))
                a = a0 + (a1 - a0) * (i + .5) / seg
                keys.append(matfn(a, (rings[j][0] + rings[j + 1][0]) / 2) if matfn else mat)
        if closed and caps[0]:
            faces.append(tuple(reversed(range(n)))); keys.append(mat)
        if closed and caps[1]:
            last = (len(rings) - 1) * n
            faces.append(tuple(last + i for i in range(n))); keys.append(mat)
        self.add(pts, faces, keys)

    def tube(self, mat, pts, seg=10, caps=True):
        """pts: (x, y, z, r) along a path."""
        P = [Vector(p[:3]) for p in pts]
        ring_pts = []
        for k, p in enumerate(P):
            t = (P[min(k + 1, len(P) - 1)] - P[max(k - 1, 0)]).normalized()
            ref = Vector((0, 0, 1)) if abs(t.z) < .9 else Vector((1, 0, 0))
            u = t.cross(ref).normalized(); w = t.cross(u)
            for i in range(seg):
                a = math.tau * i / seg
                ring_pts.append(p + pts[k][3] * (math.cos(a) * u + math.sin(a) * w))
        faces = []
        for k in range(len(P) - 1):
            for i in range(seg):
                i2 = (i + 1) % seg
                faces.append((k * seg + i2, k * seg + i, (k + 1) * seg + i, (k + 1) * seg + i2))
        if caps:
            faces.append(tuple(range(seg)))
            faces.append(tuple((len(P) - 1) * seg + i for i in reversed(range(seg))))
        self.add(ring_pts, faces, mat)

    def blob(self, mat, c, r, seg=16, rings=10, skip=None, deform=None, smooth=True):
        """Ellipsoid at c with radii r; skip(centre) drops a face, deform(p) moves a vertex."""
        pts = [(c[0], c[1], c[2] + r[2])]
        for j in range(1, rings):
            ph = math.pi * j / rings
            for i in range(seg):
                th = math.tau * i / seg
                pts.append((c[0] + r[0] * math.sin(ph) * math.sin(th),
                            c[1] - r[1] * math.sin(ph) * math.cos(th),
                            c[2] + r[2] * math.cos(ph)))
        pts.append((c[0], c[1], c[2] - r[2]))
        bot = len(pts) - 1
        faces = [(0, 1 + (i + 1) % seg, 1 + i) for i in range(seg)]
        for j in range(rings - 2):
            for i in range(seg):
                a = 1 + j * seg + i; b = 1 + j * seg + (i + 1) % seg
                faces.append((a, b, b + seg, a + seg))
        base = 1 + (rings - 2) * seg
        faces += [(base + i, base + (i + 1) % seg, bot) for i in range(seg)]
        if deform:
            pts = [deform(Vector(p)) for p in pts]
        if skip:
            faces = [f for f in faces if not skip(sum((Vector(pts[i]) for i in f), Vector()) / len(f))]
        self.add(pts, faces, mat, smooth)

    def box(self, mat, c, s, rot=None):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        m = rot or Matrix.Identity(3)
        pts = [Vector(c) + m @ Vector((x * hx, y * hy, z * hz)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        self.add(pts, faces, mat, smooth=False)


# ---------------------------------------------------------------- texture

def noise(n, scale, rng):
    g = rng.random((n // scale + 2, n // scale + 2))
    x = np.linspace(0, n / scale, n, endpoint=False)
    i = x.astype(int); f = x - i
    f = f * f * (3 - 2 * f)
    a = g[i][:, i] * (1 - f)[None, :] + g[i][:, i + 1] * f[None, :]
    b = g[i + 1][:, i] * (1 - f)[None, :] + g[i + 1][:, i + 1] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]


def cell_image(rgb, kind, grime, rng, n=CELL):
    base = np.array(rgb, float) / 255
    fine = noise(n, 4, rng) - .5; mid = noise(n, 16, rng) - .5; big = noise(n, 48, rng) - .5
    yy, xx = np.mgrid[0:n, 0:n]
    if kind == 'cloth':
        weave = np.sin(xx * 1.9) * np.sin(yy * 1.9) * .5
        lum = 1 + .07 * fine + .06 * mid + .025 * weave + .05 * big
    elif kind == 'leather':
        lum = 1 + .10 * mid + .08 * big + .05 * fine + .12 * (np.abs(noise(n, 24, rng) - .5) < .02)
    elif kind == 'metal':
        lum = 1 + .05 * mid + .1 * (rng.random((n, n)) > .995) - .04 * (noise(n, 8, rng) > .8)
    elif kind == 'skin':
        lum = 1 + .025 * fine + .03 * mid
    elif kind == 'hair':
        lum = 1 + .10 * np.sin(xx * .9 + 6 * mid) * .5 + .06 * fine
    else:
        lum = np.ones((n, n))
    img = base[None, None, :] * lum[..., None]
    if kind == 'skin':
        img[..., 0] *= 1 + .03 * mid
    # grime: rows are height (row 0 = the ground), so hems, cuffs and boots darken from below
    v = yy / n
    dirt = grime * .6 * np.clip(1 - v / .4, 0, 1) ** 1.8 * (.8 + .4 * (big + .5))
    soot = grime * .18 * (noise(n, 3, rng) > .8)
    img *= (1 - np.clip(dirt + soot, 0, .65))[..., None]
    return np.clip(img, 0, 1)


def face_image(skin, hair, eye, lip, E, rng):
    n = CELL * 2
    img = cell_image(skin, 'skin', 0, rng, n)
    yy, xx = np.mgrid[0:n, 0:n] / n  # u across, v up (row 0 = the chin end)
    sk = np.array(skin, float) / 255
    hc = np.array(hair, float) / 255

    def ell(cu, cv, ru, rv):
        return ((xx - cu) / ru) ** 2 + ((yy - cv) / rv) ** 2

    def paint(mask, col, a=1.0):
        m = np.clip(mask.astype(float), 0, 1)[..., None] * a
        img[:] = img * (1 - m) + np.array(col, float)[None, None, :] * m

    ev = E.get('eye_v', .50)
    for s in (-1, 1):
        cu = .5 + s * .155
        paint(np.clip(1.2 - ell(cu, ev + .005, .11, .06), 0, 1), sk * .78, .45)  # socket shade
        paint(ell(cu, ev, .052, .026) < 1, (.93, .9, .86))
        paint(ell(cu, ev - .002, .024, .024) < 1, np.array(eye) / 255)
        paint(ell(cu, ev - .002, .011, .011) < 1, (.05, .04, .04))
        paint(ell(cu - .008, ev + .008, .006, .006) < 1, (1, 1, 1), .8)
        paint((np.abs(ell(cu, ev - .004, .056, .032) - 1) < .25) & (yy > ev + .004), (.14, .09, .07), .9)
        if E.get('tired'):
            paint((np.abs(ell(cu, ev - .03, .05, .02) - 1) < .3) & (yy < ev - .02), sk * .7, .6)
        arch = ev + .075 + E.get('brow', 0) * s + .018 * (1 - ((xx - cu) / .07) ** 2)
        paint((np.abs(yy - arch) < .012 + .004 * (s * (xx - cu) < 0)) & (np.abs(xx - cu) < .075), hc * .8)
    paint(np.clip(1 - ell(.5, ev - .14, .05, .03), 0, 1), sk * .72, .5)
    for s in (-1, 1):
        paint(ell(.5 + s * .022, ev - .155, .012, .007) < 1, sk * .45, .8)
    mv = ev - .3
    curve = mv + E.get('smile', 0) * ((xx - .5) / .075) ** 2 * .012
    paint((np.abs(yy - curve) < .006) & (np.abs(xx - .5) < .075), np.array(lip) / 255 * .55)
    paint((np.abs(yy - (mv - .018)) < .01) & (np.abs(xx - .5) < .05), np.array(lip) / 255, .55)
    paint(np.clip(1 - ell(.5, mv - .07, .06, .025), 0, 1), sk * .8, .25)
    for s in (-1, 1):
        paint(np.clip(1 - ell(.5 + s * .2, ev - .17, .07, .05), 0, 1), (sk * np.array((1.08, .9, .88))).clip(0, 1), .35)
    if E.get('lines'):
        for k in range(3):
            fv = ev + .17 + k * .03
            paint((np.abs(yy - fv - .006 * np.sin(xx * 20)) < .003) & (np.abs(xx - .5) < .12), sk * .7, .7)
        for s in (-1, 1):
            paint((np.abs(xx - (.5 + s * .1) - (yy - mv) * s * .4) < .004) & (yy > mv) & (yy < ev - .12), sk * .72, .6)
    if E.get('freckles'):
        paint((rng.random((n, n)) > .992) & (np.abs(yy - (ev - .1)) < .08) & (np.abs(xx - .5) < .27), sk * .62, .9)
    if E.get('soot'):
        paint(noise(n, 20, rng) > .62, sk * .55, .5)
    return img


# ---------------------------------------------------------------- figures

def front(a):
    return abs(math.remainder(a, math.tau))


def person(M, P):
    """The common body: P holds cut and pose. Built at 5.5 tall, scaled to the resident after."""
    w = P.get('w', 1.0); fem = P.get('fem', False); hs = P.get('head', 1.0)
    if not P.get('skirt'):
        for s in (-1, 1):
            x = s * .2 * w
            M.tube('lower', [(x, 0, 2.7, .23 * w), (x, -.02, 1.55, .17), (x, 0, .45, .135)], seg=12)
            if P.get('patch_knee') and s == 1:
                M.blob('patch', (x, -.15, 1.5), (.12, .05, .14), seg=8, rings=6, smooth=False)
    for s in (-1, 1):
        x = s * (.15 if P.get('skirt') else .2 * w)
        M.tube('boots', [(x, .02, .55, .14), (x, .02, .1, .145)], seg=12)
        M.blob('boots', (x, -.13, .1), (.13, .24, .1), seg=12, rings=6, skip=lambda p: p.z < .02)
        M.lathe('sole', [(0, .15, .27, -.07, x), (.04, .15, .27, -.07, x)], seg=12)
    if P.get('skirt'):
        M.lathe('lower', [(3.2, .38, .25, 0), (2.8, .5, .36, .02), (2.0, .62, .5, .05), (1.0, .72, .6, .07),
                          (.12, .8, .68, .08), (.07, .79, .67, .08)], seg=28,
                matfn=lambda a, z: 'hem' if z < .3 else 'lower')
    bust = .06 if fem else 0
    waist = .34 if fem else .42
    M.lathe('coat', [(2.55, .5 * w, .3, 0), (2.9, .46 * w, .28, 0), (3.2, waist * w, .25, 0),
                     (3.6, .48 * w, .3 + bust * .5, -bust), (3.95, .55 * w, .29, -.01),
                     (4.15, .58 * w, .26, 0), (4.3, .48 * w, .22, 0), (4.4, .3 * w, .19, 0), (4.46, .2, .17, 0)], seg=24,
            matfn=P.get('torso_mat'))
    if P.get('coat_to'):
        M.lathe('coat', [(3.2, waist * w + .02, .27, 0), (2.6, .54 * w, .36, .01), (P['coat_to'], .6 * w + .04, .44, .03)],
                seg=24, caps=(False, False),
                matfn=lambda a, z: 'lower' if (front(a) < .18 and z < 2.7) else 'coat')
    for s in (-1, 1):
        el, wr, kind = P['armR' if s == 1 else 'armL']
        sh = (s * .58 * w, .02, 4.18)
        M.blob('coat', (s * .52 * w, .02, 4.12), (.2 * w, .19, .17), seg=12, rings=8)  # rounds the shoulder
        if kind == 'pocket':
            M.tube('coat', [sh + (.15,), el + (.13,), wr + (.11,)], seg=12)
            continue
        if kind == 'rolled':
            M.tube('coat', [sh + (.15,), el + (.13,)], seg=12)
            M.blob('shirt', el, (.15, .15, .1), seg=12, rings=6)
            M.tube('skin', [el + (.11,), wr + (.085,)], seg=12)
        else:
            M.tube('coat', [sh + (.15,), el + (.13,), wr + (.105,)], seg=12)
            d = (Vector(wr) - Vector(el)).normalized()
            M.tube('shirt', [tuple(Vector(wr) - d * .03) + (.1,), tuple(Vector(wr) + d * .04) + (.095,)], seg=12)
        hand = Vector(wr) + (Vector(wr) - Vector(el)).normalized() * .12
        M.blob('skin', hand, (.065, .09, .12), seg=10, rings=7)
        M.blob('skin', hand + Vector((-s * .06, -.05, .03)), (.03, .03, .06), seg=8, rings=5)
    M.tube('skin', [(0, 0, 4.38, .12), (0, .01, 4.72, .115)], seg=12)
    M.lathe('collar', [(4.4, .19, .17, 0), (4.58, .15, .14, -.01)], seg=16, caps=(False, False))
    hc = Vector((0, 0, 5.0 + (hs - 1) * .3)); r = (.29 * hs, .33 * hs, .39 * hs)

    def jaw(p):
        t = max(0, (hc.z - .05 - p.z) / (r[2] * .9))
        p.x *= 1 - .28 * t; p.y = p.y * (1 - .1 * t) - .03 * t
        return p
    M.blob('face', hc, r, seg=20, rings=14, deform=jaw)
    M.face_proj = (hc, r)
    M.blob('face', hc + Vector((0, -r[1] * .97, -.03 * hs)), (.045 * hs, .07 * hs, .09 * hs), seg=10, rings=6)
    for s in (-1, 1):
        M.blob('skin', hc + Vector((s * r[0] * .98, .02, -.02)), (.035, .07, .1), seg=8, rings=6)
    hl = P.get('hairline', .2)
    M.blob('hair', hc + Vector((0, .02, .03)), (r[0] * 1.07, r[1] * 1.06, r[2] * 1.04), seg=20, rings=12,
           skip=lambda p: (p.y < -.05 and p.z < hc.z + hl * hs) or p.z < hc.z - (.36 if p.y > .1 else .2) * hs or (p.y < .12 and p.z < hc.z - .02))
    if P.get('bun'):
        M.blob('hair', hc + Vector((0, .3 * hs, .16)), (.15, .13, .14), seg=12, rings=8)
    for t in P.get('tufts', []):
        M.blob('hair', hc + Vector(t[:3]), t[3], seg=8, rings=5)
    if P.get('moustache'):
        for s in (-1, 1):
            M.blob('hair', hc + Vector((s * .065, -r[1] * .92, -.18 * hs)), (.08, .045, .035), seg=8, rings=5,
                   deform=lambda p, s=s: p + Vector((0, 0, -abs(p.x - s * .065) * .25)))
    if P.get('chops'):
        for s in (-1, 1):
            M.blob('hair', hc + Vector((s * r[0] * .88, -.08, -.14)), (.06, .1, .17), seg=8, rings=6)
    return hc, r


def hat_peaked(M, hc, low=0.0):
    z0 = hc.z + .2 - low
    M.lathe('hat', [(z0, .31, .35, .03), (z0 + .08, .315, .355, .03), (z0 + .24, .33, .37, .04), (z0 + .26, .3, .34, .04)],
            seg=22, matfn=lambda a, z: 'band' if z < z0 + .08 else 'hat')
    M.blob('hat', (0, -.33, z0 + .01), (.25, .17, .025), seg=14, rings=6, smooth=False,
           skip=lambda p: p.y > -.2, deform=lambda p: p + Vector((0, 0, (p.y + .2) * .35)))
    M.box('trim', (0, -.37, z0 + .14), (.1, .02, .09))


def hat_visor(M, hc):
    z0 = hc.z + .1
    M.lathe('band', [(z0, .31, .35, .01), (z0 + .07, .31, .35, .01)], seg=22, caps=(False, False))
    M.blob('hat', (0, -.36, z0 + .04), (.26, .2, .02), seg=14, rings=6, smooth=False,
           skip=lambda p: p.y > -.22, deform=lambda p: p + Vector((0, 0, (p.y + .22) * .5)))


def hat_flat(M, hc, hs=1.0):
    z0 = hc.z + .2 * hs
    M.blob('hat', (0, -.05, z0 + .03), (.35 * hs, .41 * hs, .14 * hs), seg=18, rings=8, skip=lambda p: p.z < z0 - .02,
           deform=lambda p: p + Vector((0, 0, -max(0, -p.y - .1) * .25)))
    M.blob('hat', (0, -.39 * hs, z0 - .02), (.23 * hs, .12 * hs, .025), seg=12, rings=5, smooth=False,
           skip=lambda p: p.y > -.3 * hs)


def buttons(M, xs, zs, y, mat='trim', rr=.028):
    for x in xs:
        for z in zs:
            M.blob(mat, (x, y, z), (rr, rr * .6, rr), seg=8, rings=5)


def mabel(M):
    hc, r = person(M, dict(fem=True, skirt=True, w=.88, bun=True, hairline=.22,
                           armR=((.56, -.12, 3.42), (.24, -.42, 3.66), ''), armL=((-.6, .04, 3.35), (-.56, -.04, 2.55), ''),
                           torso_mat=lambda a, z: 'shirt' if z > 4.33 else 'coat'))
    hat_visor(M, hc)
    M.lathe('lace', [(4.42, .24, .2, 0), (4.5, .3, .26, -.01), (4.56, .2, .17, -.01)], seg=24, caps=(False, False))
    buttons(M, [0], [3.3 + i * .17 for i in range(6)], y=-.31)
    # belt with the ticket pouch
    M.lathe('leather', [(3.12, .32, .24, 0), (3.24, .33, .25, 0)], seg=20, caps=(False, False))
    M.box('leather', (-.24, -.24, 3.0), (.18, .08, .2))
    M.box('trim', (-.24, -.285, 3.06), (.06, .01, .04))
    # ticket punch in her right hand with a ticket in the jaws, a pack of tickets in the left
    M.box('metal', (.18, -.55, 3.78), (.05, .2, .06), rot=Matrix.Rotation(-.5, 3, 'X'))
    M.box('trim', (.2, -.5, 3.68), (.05, .06, .16))
    M.box('ticket', (.16, -.66, 3.86), (.12, .005, .07))
    M.box('ticket', (-.5, -.12, 2.55), (.005, .1, .16))


def dutch(M):
    hc, r = person(M, dict(w=1.22, moustache=True, chops=True, hairline=.22, coat_to=2.35,
                           armR=((.82, .02, 3.42), (.8, -.24, 2.95), 'rolled'), armL=((-.9, .1, 3.45), (-.58, .02, 3.0), 'rolled'),
                           torso_mat=lambda a, z: 'shirt' if (front(a) < .25 and z > 3.7) else 'coat'))
    hat_flat(M, hc)
    M.lathe('neck', [(4.38, .22, .2, 0), (4.48, .2, .18, 0)], seg=16, caps=(False, False))
    M.blob('neck', (0, -.21, 4.33), (.07, .05, .07), seg=10, rings=6)
    # leather apron, chest to knee, with a neck strap
    M.lathe('apron', [(3.95, .3, .33, -.01), (3.2, .44, .3, -.02), (2.6, .6, .36, -.03), (1.5, .62, .4, -.04)],
            seg=10, arc=(-.95, .95), caps=(False, False))
    for s in (-1, 1):
        M.tube('apron', [(s * .22, -.32, 3.95, .025), (s * .2, -.15, 4.35, .025), (0, .08, 4.45, .025)], seg=6, caps=False)
    M.lathe('leather', [(3.0, .52, .32, 0), (3.12, .52, .32, 0)], seg=22, caps=(False, False))
    M.box('trim', (0, -.34, 3.06), (.12, .02, .1))
    # coal shovel, blade on the floor, grip under his right hand
    M.tube('wood', [(.86, -.38, .4, .045), (.8, -.32, 2.75, .042)], seg=8)
    M.tube('metal', [(.72, -.32, 2.8, .025), (.88, -.32, 2.8, .025)], seg=6)
    M.box('metal', (.88, -.42, .2), (.4, .05, .44), rot=Matrix.Rotation(.25, 3, 'X'))
    M.box('metal', (.87, -.46, .44), (.1, .07, .12))


def varga(M):
    hc, r = person(M, dict(fem=True, skirt=True, w=.86, bun=True, hairline=.25,
                           armR=((.58, -.02, 3.35), (.3, -.4, 3.25), ''), armL=((-.62, .02, 3.35), (-.6, 0, 2.45), ''),
                           torso_mat=lambda a, z: 'shirt' if z > 4.33 else 'coat'))
    M.lathe('shirt', [(4.42, .22, .19, 0), (4.52, .21, .18, -.01)], seg=20, caps=(False, False))
    M.blob('trim', (0, -.21, 4.4), (.035, .02, .035), seg=8, rings=5)  # brooch
    # white apron with a bib, tied at the waist
    M.lathe('apron', [(3.95, .2, .36, -.03), (3.6, .26, .37, -.04), (3.2, .36, .3, -.02), (2.8, .52, .4, -.02), (1.2, .7, .62, -.04)],
            seg=10, arc=(-.8, .8), caps=(False, False))
    M.lathe('apron', [(3.18, .35, .26, 0), (3.26, .35, .26, 0)], seg=20, caps=(False, False))
    # spectacles
    for s in (-1, 1):
        cx = s * .1
        M.tube('metal', [(cx + .045 * math.cos(a), -r[1] - .03, hc.z + .045 * math.sin(a), .007)
                         for a in [i * math.tau / 10 for i in range(11)]], seg=4, caps=False)
    M.tube('metal', [(-.055, -r[1] - .03, hc.z + .01, .006), (.055, -r[1] - .03, hc.z + .01, .006)], seg=4)
    # case ledger in her right hand, the bag in her left
    rot = Matrix.Rotation(.3, 3, 'X') @ Matrix.Rotation(-.4, 3, 'Z')
    M.box('leather', (.16, -.48, 3.2), (.34, .07, .44), rot=rot)
    M.box('paper', (.16, -.465, 3.2), (.32, .06, .42), rot=rot)
    M.lathe('bag', [(1.62, .3, .1, 0, -.6), (1.75, .34, .14, 0, -.6), (2.02, .3, .13, 0, -.6), (2.1, .2, .05, 0, -.6)], seg=16)
    M.tube('bag', [(-.6 + .14 * math.cos(a), 0, 2.1 + .16 * math.sin(a), .022) for a in [i * math.pi / 8 for i in range(9)]], seg=6)
    M.box('trim', (-.6, -.14, 2.04), (.08, .03, .05))


def pip(M):
    hc, r = person(M, dict(w=.9, head=1.12, hairline=.12, coat_to=1.85, patch_knee=True,
                           armR=((.62, -.06, 3.3), (.42, -.28, 2.75), 'pocket'), armL=((-.62, -.06, 3.3), (-.42, -.28, 2.75), 'pocket'),
                           tufts=[(-.2, -.3, .1, (.1, .07, .08)), (.04, -.34, .12, (.12, .07, .07)), (.21, -.29, .09, (.09, .07, .08)),
                                  (.3, .05, .0, (.07, .12, .14)), (-.3, .05, .0, (.07, .12, .14))],
                           torso_mat=lambda a, z: 'shirt' if (front(a) < .3 and z > 3.75) else 'coat'))
    hat_flat(M, hc, hs=1.12)
    M.lathe('neck', [(4.38, .22, .2, 0), (4.5, .21, .19, 0)], seg=16, caps=(False, False))
    M.blob('neck', (-.08, -.22, 4.32), (.07, .05, .1), seg=10, rings=6)
    # patches on the coat, and the pockets the hands are pushed into
    M.blob('patch', (-.36, -.3, 3.7), (.1, .04, .1), seg=8, rings=6, smooth=False)
    M.blob('patch', (.48, .1, 3.9), (.08, .1, .09), seg=8, rings=6, smooth=False)
    for s in (-1, 1):
        M.box('coat', (s * .42, -.36, 2.68), (.24, .05, .06))
    # satchel strap and satchel at the left hip
    M.tube('leather', [(.5, -.2, 4.2, .03), (.2, -.33, 3.9, .03), (-.2, -.34, 3.3, .03), (-.45, -.28, 2.8, .03)], seg=6, caps=False)
    M.tube('leather', [(.5, .2, 4.2, .03), (.1, .3, 3.6, .03), (-.45, .28, 2.8, .03)], seg=6, caps=False)
    M.box('bag', (-.6, 0, 2.6), (.16, .44, .36))
    M.box('bag', (-.69, 0, 2.72), (.03, .45, .2))


def conductor(M):
    hc, r = person(M, dict(w=1.0, moustache=True, hairline=.1, coat_to=1.55,
                           armR=((.6, .06, 3.42), (.3, -.36, 3.58), ''), armL=((-.66, .04, 3.35), (-.66, 0, 2.45), '')))
    hat_peaked(M, hc, low=.06)
    buttons(M, [-.13, .13], [3.25 + i * .22 for i in range(5)], y=-.33)
    M.lathe('collar', [(4.42, .2, .18, 0), (4.6, .19, .17, -.01)], seg=16, caps=(False, False))
    # patent shoulder belt, left shoulder to the timekeeper pouch at the right hip
    M.tube('patent', [(-.42, -.24, 4.25, .035), (-.15, -.32, 3.8, .035), (.2, -.33, 3.2, .035), (.45, -.27, 2.75, .035)], seg=6, caps=False)
    M.tube('patent', [(-.42, .22, 4.25, .035), (0, .3, 3.5, .035), (.45, .27, 2.75, .035)], seg=6, caps=False)
    M.box('patent', (.5, -.25, 2.62), (.22, .1, .24))
    M.box('trim', (.5, -.305, 2.66), (.07, .01, .06))
    # pocket watch in his right hand, chain to the coat
    M.blob('trim', (.18, -.6, 3.8), (.08, .025, .08), seg=12, rings=6)
    M.tube('trim', [(.18, -.58, 3.72, .008), (.08, -.4, 3.45, .008), (0, -.33, 3.3, .008)], seg=4, caps=False)
    # hand lamp in his left hand
    lx, lz = -.66, 1.95
    M.lathe('metal', [(lz - .2, .13, .13, 0, lx), (lz + .12, .13, .13, 0, lx), (lz + .2, .08, .08, 0, lx)], seg=14)
    M.blob('lens', (lx, -.13, lz - .04), (.075, .03, .075), seg=12, rings=6)
    M.tube('metal', [(lx + .12 * math.cos(a), 0, lz + .2 + .14 * math.sin(a), .015) for a in [i * math.pi / 8 for i in range(9)]],
           seg=6, caps=False)


C = {  # material: rgb (0-255), grain kind, grime
    'Mabel': dict(build=mabel, h=5.35, eye=(84, 96, 70), lip=(176, 96, 92), extra=dict(smile=1),
                  mats=dict(skin=((234, 196, 168), 'skin', 0), hair=((96, 80, 72), 'hair', 0), coat=((40, 50, 78), 'cloth', .35),
                            lower=((40, 46, 70), 'cloth', .35), hem=((30, 34, 52), 'cloth', .5), boots=((30, 24, 22), 'leather', .4),
                            sole=((22, 18, 16), 'leather', .5), shirt=((226, 220, 206), 'cloth', .1), collar=((226, 220, 206), 'cloth', .1),
                            lace=((236, 230, 216), 'cloth', 0), trim=((201, 160, 82), 'metal', 0), band=((60, 48, 40), 'leather', 0),
                            hat=((44, 92, 66), 'cloth', 0), leather=((92, 60, 40), 'leather', .2), metal=((150, 150, 156), 'metal', 0),
                            ticket=((214, 196, 150), 'cloth', 0))),
    'Dutch': dict(build=dutch, h=5.6, eye=(70, 86, 104), lip=(150, 90, 80), extra=dict(lines=1, soot=1, brow=.01),
                  mats=dict(skin=((214, 170, 140), 'skin', .3), hair=((70, 58, 50), 'hair', 0), coat=((52, 66, 92), 'cloth', .7),
                            lower=((48, 46, 44), 'cloth', .7), boots=((30, 24, 20), 'leather', .6), sole=((20, 16, 14), 'leather', .6),
                            shirt=((190, 180, 160), 'cloth', .5), collar=((190, 180, 160), 'cloth', .4), hat=((44, 42, 40), 'cloth', .3),
                            neck=((150, 48, 40), 'cloth', .3), apron=((92, 64, 44), 'leather', .6), leather=((60, 40, 28), 'leather', .4),
                            trim=((150, 120, 80), 'metal', .3), metal=((70, 70, 72), 'metal', .6), wood=((120, 90, 60), 'cloth', .3))),
    'Varga': dict(build=varga, h=5.3, eye=(70, 52, 40), lip=(160, 92, 88), extra=dict(tired=1, brow=-.005),
                  mats=dict(skin=((222, 186, 156), 'skin', 0), hair=((40, 30, 28), 'hair', 0), coat=((56, 40, 44), 'cloth', .3),
                            lower=((44, 34, 38), 'cloth', .35), hem=((36, 28, 30), 'cloth', .45), boots=((26, 20, 20), 'leather', .4),
                            sole=((18, 14, 14), 'leather', .5), shirt=((226, 220, 206), 'cloth', .05), collar=((226, 220, 206), 'cloth', 0),
                            apron=((222, 216, 202), 'cloth', .45), trim=((190, 160, 100), 'metal', 0), metal=((170, 160, 130), 'metal', 0),
                            leather=((70, 44, 30), 'leather', .1), paper=((226, 214, 186), 'cloth', 0), bag=((58, 36, 26), 'leather', .2))),
    'Pip': dict(build=pip, h=4.7, eye=(88, 110, 80), lip=(176, 104, 96), extra=dict(freckles=1, smile=.6, eye_v=.47),
                mats=dict(skin=((228, 190, 160), 'skin', .15), hair=((150, 96, 60), 'hair', 0), coat=((104, 88, 64), 'cloth', .55),
                          lower=((70, 64, 58), 'cloth', .6), boots=((44, 34, 28), 'leather', .6), sole=((26, 20, 16), 'leather', .6),
                          shirt=((180, 170, 150), 'cloth', .3), collar=((180, 170, 150), 'cloth', .3), hat=((58, 50, 44), 'cloth', .2),
                          neck=((120, 40, 36), 'cloth', .2), patch=((132, 104, 70), 'cloth', .3), leather=((80, 56, 36), 'leather', .3),
                          bag=((96, 84, 60), 'cloth', .4))),
    'Conductor': dict(build=conductor, h=5.75, eye=(110, 112, 110), lip=(140, 100, 96), extra=dict(lines=1, brow=-.01),
                      mats=dict(skin=((200, 182, 168), 'skin', 0), hair=((60, 60, 64), 'hair', 0), coat=((22, 26, 38), 'cloth', .3),
                                lower=((22, 26, 38), 'cloth', .35), boots=((14, 12, 12), 'leather', .3), sole=((10, 9, 9), 'leather', .4),
                                shirt=((220, 214, 200), 'cloth', 0), collar=((22, 26, 38), 'cloth', 0), hat=((20, 24, 36), 'cloth', 0),
                                band=((12, 12, 16), 'cloth', 0), trim=((180, 148, 88), 'metal', 0), patent=((10, 10, 12), 'metal', 0),
                                metal=((40, 40, 44), 'metal', .2), lens=((255, 196, 110), 'emit', 0))),
}


def build(name, spec, seed):
    rng = np.random.default_rng(seed)
    M = Mesh(); spec['build'](M)
    used = sorted(set(M.mat) - {'face'})
    assert len(used) <= 60, name
    cells = {k: (i % 8, i // 8) for i, k in enumerate(used)}
    img = np.zeros((TEX, TEX, 3))
    for k, (cx, cy) in cells.items():
        rgb, kind, grime = spec['mats'][k]
        img[cy * CELL:(cy + 1) * CELL, cx * CELL:(cx + 1) * CELL] = cell_image(rgb, kind, grime, rng)
    fx, fy = FACE_CELL
    img[fy * CELL:(fy + 2) * CELL, fx * CELL:(fx + 2) * CELL] = face_image(
        spec['mats']['skin'][0], spec['mats']['hair'][0], spec['eye'], spec['lip'], spec['extra'], rng)
    im = bpy.data.images.new(f'{name}_tex', TEX, TEX)
    im.pixels.foreach_set(np.concatenate([img, np.ones((TEX, TEX, 1))], 2).astype(np.float32).ravel())
    im.filepath_raw = str(OUT / f'{name}.png'); im.file_format = 'PNG'; im.save()
    k = spec['h'] / 5.5
    me = bpy.data.meshes.new(name)
    me.from_pydata([(x * k, y * k, z * k) for x, y, z in M.v], [], M.f)
    me.update()
    uv = me.uv_layers.new(name='UV')
    hc, r = M.face_proj
    mg = .03  # cell margin, in cell units
    for poly, key, sm in zip(me.polygons, M.mat, M.smooth):
        poly.use_smooth = sm
        verts = M.f[poly.index]
        ctr = sum((Vector(M.v[i]) for i in verts), Vector()) / len(verts)
        face_front = key == 'face' and ctr.y < hc.y - r[1] * .15
        for li in poly.loop_indices:
            p = Vector(M.v[me.loops[li].vertex_index])
            if face_front:
                u = .5 + (p.x - hc.x) / (r[0] * 2.4)
                v = (p.z - (hc.z - r[2] * 1.08)) / (r[2] * 2.16)
                uv.data[li].uv = ((fx + 2 * min(max(u, .01), .99)) / 8, (fy + 2 * min(max(v, .01), .99)) / 8)
            else:
                cx, cy = cells['skin' if key == 'face' else key]
                u = mg + (1 - 2 * mg) * min(max(.5 + (p.x - p.y * .35) / 2.6, 0), 1)
                v = mg + (1 - 2 * mg) * min(max(p.z / 5.6, 0), 1)
                uv.data[li].uv = ((cx + u) / 8, (cy + v) / 8)
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob)
    mat = bpy.data.materials.new(f'{name}_mat'); mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']; bsdf.inputs['Roughness'].default_value = .82
    t = mat.node_tree.nodes.new('ShaderNodeTexImage'); t.image = im
    mat.node_tree.links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
    me.materials.append(mat)
    return ob, sum(p.loop_total - 2 for p in me.polygons)


bpy.ops.wm.read_factory_settings(use_empty=True)
report, objs = {}, []
for i, (name, spec) in enumerate(C.items()):
    ob, tris = build(name, spec, 1000 + i)
    report[name] = tris; objs.append(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.wm.obj_export(filepath=str(OUT / f'{name}.obj'), export_selected_objects=True, forward_axis='Z', up_axis='Y',
                          export_materials=True, path_mode='RELATIVE', export_normals=True, export_uv=True)
print('TRIS', report)

# ---------------------------------------------------------------- review renders (50%)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE'
sc.eevee.taa_render_samples = 8
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = 1920, 1080, 50
sc.view_settings.view_transform = 'AgX'
world = bpy.data.worlds.new('w'); sc.world = world; world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (.035, .04, .05, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = .6
floor = bpy.data.meshes.new('floor'); floor.from_pydata([(-20, -20, 0), (20, -20, 0), (20, 20, 0), (-20, 20, 0)], [], [(0, 1, 2, 3)])
fo = bpy.data.objects.new('floor', floor); sc.collection.objects.link(fo)
fm = bpy.data.materials.new('floor'); fm.use_nodes = True
fm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.09, .07, .055, 1); floor.materials.append(fm)
for i, ob in enumerate(objs):
    ob.location.x = (i - 2) * 1.9


def light(name, kind, loc, energy, color, size=2.0):
    d = bpy.data.lights.new(name, kind); d.energy = energy; d.color = color
    if kind == 'AREA':
        d.size = size
    o = bpy.data.objects.new(name, d); o.location = loc; sc.collection.objects.link(o)
    o.rotation_euler = (Vector((0, 0, 2.5)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()


light('key', 'AREA', (-4, -6, 7), 2200, (1, .86, .7), 4)
light('fill', 'AREA', (6, -5, 3), 500, (.7, .8, 1), 5)
light('rim', 'AREA', (0, 6, 6), 1400, (.75, .82, 1), 6)
light('lamp', 'POINT', (objs[4].location.x - .62 * 5.75 / 5.5, -.6, 1.9), 25, (1, .7, .35))
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam


def shot(path, loc, target, lens):
    cam.location = loc; cam.data.lens = lens
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = str(path); bpy.ops.render.render(write_still=True)


bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'npc-figures.blend'))
if '--no-render' in sys.argv:
    sys.exit(0)
shot(OUT / 'review_lineup_front.png', (2.0, -14, 4.2), (0, 0, 2.7), 42)
shot(OUT / 'review_lineup_back.png', (-5, 12, 5), (0, 0, 2.7), 40)
for ob in objs:
    hz = ob.dimensions.z * .91
    shot(OUT / f'review_head_{ob.name}.png', (ob.location.x + .9, -3.2, hz + .1), (ob.location.x, 0, hz - .15), 70)
print('DONE')
