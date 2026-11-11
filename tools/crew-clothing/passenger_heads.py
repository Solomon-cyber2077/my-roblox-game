"""The hall passengers' heads and coats at Mabel's level: sculpted hair built from a shell plus
separate tapered locks, whiskers for the gentleman (full beard and moustache) and the porter (chin
curtain), a modelled hat each (bowler, poke bonnet with ribbon bow, silk top hat, peaked cap, eight
panel flat cap, the widow's crape veil), and one cloth piece each that changes the silhouette (sack
coat and reefer hems, frock coat skirts, a bustle, a knitted shawl, a knotted neckerchief).
Run passenger_head_textures.py first, then: blender -b --python tools/crew-clothing/passenger_heads.py
Pieces are built in their limb's space like mabel_r6.py (Blender Z-up, figure facing -Y, studs) and
exported as OBJ and FBX (the FBX is what gets uploaded; it imports the same way, hence yaw 180 in
Config/Passengers). All share one texture, heads.png. Renders (50%) go to $PASSENGER_OUT/renders.
PASSENGER_PLAIN=1 renders the before (sheets, skirts and bags, no hair or hats).
"""
import bpy, math, json, os, sys, random
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
OUT = Path(os.environ.get('PASSENGER_OUT', HERE.parents[1] / 'assets/crew-clothing/passengers-r6'))
PLAIN = os.environ.get('PASSENGER_PLAIN') == '1'
ns = {'__file__': str(HERE / 'passenger_r6.py'), '__name__': 'passenger_r6'}
exec(compile((HERE / 'passenger_r6.py').read_text().rsplit('\nmain()', 1)[0], 'passenger_r6.py', 'exec'), ns)
mb = ns['ns']  # the mabel_r6 namespace passenger_r6 loaded
M, export, head_point, phi_for, textured, shoot = mb['M'], mb['export'], mb['head_point'], mb['phi_for'], mb['textured'], mb['shoot']
person, bags, stage, LOOKS = ns['person'], ns['bags'], ns['stage'], ns['LOOKS']
TAU, PI = math.tau, math.pi
HEAD, TORSO = (0, 0, 4.5), (0, 0, 3)
# PASSENGER_LOD=0.5 builds the phone set (Config/Passengers `phone` ids, shown on the Performance setting): about
# half the segments round each shape, fewer rows, thinner lock paths. Same atlas and UV cells, so heads.png serves both.
LOD = float(os.environ.get('PASSENGER_LOD', '1'))
def lod(n, floor=8):
    return n if LOD >= 1 else max(floor, round(n * LOD))

# ------------------------------------------------------------------ atlas cells (passenger_head_textures.py)
CELL = dict(Clerk=0, Mother=1, Gentleman=2, Porter=3, Widow=4, Newsboy=5, felt=6, plush=7, bonnet=8, capcloth=9,
            tweed=10, crape=11, patent=12, brass=13, band=14, frock=15, sack=16, reefer=17, bustle=18, shawl=19,
            kerchief=20, ribbon=21, lining=22, brownfelt=23)

def cuv(k, s, t):
    """Cell k, s across 0..1, t up 0..1 (t = 1 is the top row of the cell: a hair root)."""
    c, r = k % 6, k // 6
    return ((c + .03 + .94 * s) / 6, 1 - (r + .03 + .94 * (1 - t)) / 6)

def V(*a):
    return Vector(a)

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

def sheet(m, k, P, out_fn, s_span=1.0, t_flip=False):
    """Open grid P[i][j] (rows down, columns across) with cell UVs; rows run t 1 -> 0."""
    rows, cols = len(P), len(P[0])
    for i in range(rows - 1):
        for j in range(cols - 1):
            pts = [P[i][j], P[i][j + 1], P[i + 1][j + 1], P[i + 1][j]]
            ta, tb = 1 - i / (rows - 1), 1 - (i + 1) / (rows - 1)
            if t_flip:
                ta, tb = 1 - ta, 1 - tb
            sa, sb = (j / (cols - 1) * s_span) % 1.0001, ((j + 1) / (cols - 1) * s_span) % 1.0001
            if sb < sa:
                sb = 1.0
            uvs = [cuv(k, sa, ta), cuv(k, sb, ta), cuv(k, sb, tb), cuv(k, sa, tb)]
            c = sum((Vector(p) for p in pts), Vector()) / 4
            m.face([tuple(p) for p in pts], uvs, out_fn(c))

def lock(m, k, path, width, flat=.45, sides=4, s0=None, rng=None):
    """A tapered hair lock along `path`, flattened against the head (radial = its thickness)."""
    rng = rng or random; s0 = rng.uniform(0, .75) if s0 is None else s0
    if LOD < 1:  # the phone set: fewer sides, every other point along the lock (ends kept)
        sides = max(3, sides - 2)
        path = list(path[:-1:2]) + [path[-1]] if len(path) > 4 else path
    n = len(path); rings = []
    for i, p in enumerate(path):
        p = Vector(p); a = Vector(path[min(i + 1, n - 1)]); b = Vector(path[max(i - 1, 0)])
        tdir = (a - b).normalized(); rad = (p - V(0, 0, 0)).normalized()
        side = tdir.cross(rad).normalized(); up = side.cross(tdir).normalized()
        w = width * (1 - .7 * (i / (n - 1)) ** 1.3)
        rings.append([p + w * math.cos(TAU * q / sides) * side + w * flat * math.sin(TAU * q / sides) * up for q in range(sides)])
    for i in range(n - 1):
        for q in range(sides):
            q2 = (q + 1) % sides
            pts = [rings[i][q], rings[i][q2], rings[i + 1][q2], rings[i + 1][q]]
            sa, sb = s0 + .25 * q / sides, s0 + .25 * (q + 1) / sides
            ta, tb = 1 - i / (n - 1), 1 - (i + 1) / (n - 1)
            axis = (Vector(path[i]) + Vector(path[i + 1])) / 2
            c = sum(pts, Vector()) / 4
            m.face([tuple(p) for p in pts], [cuv(k, sa, ta), cuv(k, sb, ta), cuv(k, sb, tb), cuv(k, sa, tb)], c - axis)
    tip = Vector(path[-1]) + (Vector(path[-1]) - Vector(path[-2])).normalized() * width * .3
    for q in range(sides):
        q2 = (q + 1) % sides
        m.face([tuple(rings[-1][q]), tuple(rings[-1][q2]), tuple(tip)], [cuv(k, s0, 0), cuv(k, s0 + .05, 0), cuv(k, s0 + .02, 0)],
               tip - Vector(path[-2]))

def surface_path(th0, ph0, th1, ph1, scale, lift=.02, curl=0.0, n=7, wave=0.0):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        th = th0 + (th1 - th0) * t + wave * math.sin(PI * t * 2)
        ph = ph0 + (ph1 - ph0) * t
        pts.append(tuple(head_point(th, ph, scale + lift * math.sin(PI * t) + curl * t * t)))
    return pts

def hair_shell(m, k, hairline, scale, seg=lod(36), rows=lod(11, 5)):
    """Mabel's hair cap generalised: crown to `hairline(theta)` (a z), radius scale(theta, phi)."""
    ths = [-PI + TAU * j / seg for j in range(seg + 1)]
    P = []
    for i in range(rows):
        t = i / (rows - 1)
        P.append([head_point(th, max(.05, t * phi_for(hairline(th))), scale(th, max(.05, t * phi_for(hairline(th))))) for th in ths])
    sheet(m, k, P, lambda c: c)
    top = head_point(0, 0, scale(0, 0) + .01)
    for j in range(seg):
        m.face([tuple(top), tuple(P[0][j]), tuple(P[0][j + 1])], [cuv(k, .5, 1), cuv(k, j / seg, 1), cuv(k, (j + 1) / seg, 1)], (0, 0, 1))
    for j in range(seg):  # rolled-under edge so the hairline has thickness
        a, b = ths[j], ths[j + 1]
        ia = head_point(a, phi_for(hairline(a)) + .05, 1.01); ib = head_point(b, phi_for(hairline(b)) + .05, 1.01)
        m.face([tuple(P[-1][j]), tuple(P[-1][j + 1]), tuple(ib), tuple(ia)], [cuv(k, j / seg, .06), cuv(k, (j + 1) / seg, .06), cuv(k, (j + 1) / seg, 0), cuv(k, j / seg, 0)],
               (ia + ib) / 2 - V(0, 0, .3))
    return P

def coil(m, k, centre, normal, r0, thick, turns=2.3, n=36):
    c = Vector(centre); nrm = Vector(normal).normalized()
    a1 = V(1, 0, 0) if abs(nrm.x) < .9 else V(0, 1, 0); a1 = (a1 - nrm * a1.dot(nrm)).normalized(); a2 = nrm.cross(a1)
    path = []
    for i in range(n):
        t = i / (n - 1); a = t * turns * TAU; r = r0 * (1 - .75 * t)
        path.append(tuple(c + r * (math.cos(a) * a1 + math.sin(a) * a2) + nrm * (.08 * t + .05 * math.sin(PI * t))))
    lock(m, k, path, thick, flat=.85, sides=6, s0=.1)

# ------------------------------------------------------------------ hair styles
def hair_clerk():
    m = M('clerk hair'); k = CELL['Clerk']; rng = random.Random(1)
    line = lambda th: .30 - .38 * smooth(.6, 1.5, abs(th)) - .2 * smooth(1.6, 3.0, abs(th))
    part = .55
    hair_shell(m, k, line, lambda th, ph: 1.05 + .012 * math.cos(30 * th) * math.sin(ph) - .015 * math.exp(-((th - part) / .08) ** 2))
    for i in range(26):  # oiled locks combed away from the side part
        th0 = part + rng.uniform(-.05, .05); ph0 = rng.uniform(.25, .9)
        if i < 16:
            th1 = th0 - rng.uniform(.9, 2.2); ph1 = ph0 + rng.uniform(.2, .6)
        else:
            th1 = th0 + rng.uniform(.7, 1.6); ph1 = ph0 + rng.uniform(.3, .7)
        ph1 = min(ph1, phi_for(line(th1)) - .05)
        lock(m, k, surface_path(th0, ph0, th1, ph1, 1.06, .02, n=7), rng.uniform(.06, .09), rng=rng)
    for i in range(14):  # short back and sides, combed down
        th = rng.uniform(1.4, TAU - 1.4); ph0 = rng.uniform(.9, 1.3)
        lock(m, k, surface_path(th, ph0, th + rng.uniform(-.1, .1), phi_for(line(th)) - .03, 1.055, .01, n=5), .07, rng=rng)
    return m

def hair_gentleman():
    m = M('gentleman hair'); k = CELL['Gentleman']; rng = random.Random(2)
    line = lambda th: .40 - .32 * smooth(.5, 1.4, abs(th)) - .32 * smooth(1.5, 3.0, abs(th))
    hair_shell(m, k, line, lambda th, ph: 1.05 + .02 * smooth(1.8, 3.0, abs(th)) * math.sin(ph) + .01 * math.cos(26 * th))
    for i in range(26):  # swept back under the hat, lifting into a soft flick at the collar
        th = rng.uniform(1.0, TAU - 1.0); ph0 = phi_for(.2)
        th1 = th + rng.uniform(-.12, .12); ph1 = phi_for(line(th1)) - .02
        lock(m, k, surface_path(th, ph0, th1, ph1, 1.06, .02, curl=.035, n=6), rng.uniform(.07, .1), rng=rng)
    return m

def beard_gentleman():
    m = M('gentleman beard'); k = CELL['Gentleman']; rng = random.Random(3)
    seg, rows = lod(28), lod(9, 4)
    ths = [-1.75 + 3.5 * j / seg for j in range(seg + 1)]
    def top(th):  # sideburns high at the ears, under the mouth at the front
        return phi_for(.16) + (phi_for(-.26) - phi_for(.16)) * (1 - smooth(.55, 1.35, abs(th)))
    P = []
    for i in range(rows):
        t = i / (rows - 1); row = []
        for th in ths:
            ph = top(th) + (2.95 - top(th)) * t
            front = math.cos(th) ** 2 if abs(th) < PI / 2 else 0
            bulk = 1.06 + .05 * math.sin(PI * t) + .22 * front * smooth(.45, 1, t) + .01 * math.cos(22 * th)
            p = head_point(th, min(ph, 2.95), bulk)
            p.z -= .28 * front * smooth(.5, 1, t)  # the beard falls below the chin
            row.append(p)
        P.append(row)
    sheet(m, k, P, lambda c: c - V(0, 0, c.z * .2))
    # underside closing the beard back to the throat
    Q = [P[-1], [head_point(th, 2.6, .9) - V(0, -.05, .05) for th in ths]]
    sheet(m, k, Q, lambda c: V(0, 0, -1))
    for s in (-1, 1):  # moustache: full, drooping into the beard at the corners of the mouth
        path = [tuple(head_point(s * a, phi_for(-.07 - .22 * a * a), 1.09 + .03 * (1 - a))) for a in (0.0, .15, .3, .45, .6, .72)]
        lock(m, k, path, .075, flat=.7, sides=6, s0=.2, rng=rng)
    for i in range(14):  # combed ridges down the beard, short of the hem
        th = -.9 + 1.8 * i / 13
        lock(m, k, surface_path(th, phi_for(-.3), th * 1.05, 2.45, 1.14, .04, n=5), .045, flat=.5, rng=rng)
    return m

def hair_porter():
    m = M('porter hair'); k = CELL['Porter']; rng = random.Random(4)
    line = lambda th: .30 - .36 * smooth(.6, 1.4, abs(th)) - .26 * smooth(1.6, 3.0, abs(th))
    hair_shell(m, k, line, lambda th, ph: 1.04 + .01 * math.cos(34 * th) * math.sin(ph))
    for i in range(16):  # cropped short, brushed down at the back and sides
        th = rng.uniform(1.1, TAU - 1.1); ph1 = phi_for(line(th)) - .02
        lock(m, k, surface_path(th, ph1 - .35, th, ph1, 1.045, .01, n=4), .06, rng=rng)
    return m

def beard_porter():
    m = M('porter whiskers'); k = CELL['Porter']; rng = random.Random(5)
    seg, rows = lod(30), lod(5, 3)
    ths = [-1.7 + 3.4 * j / seg for j in range(seg + 1)]
    def top(th):  # a chin curtain: a band along the jaw, sideburn to sideburn, no moustache
        return phi_for(.14) + (phi_for(-.36) - phi_for(.14)) * (1 - smooth(.4, 1.4, abs(th)))
    P = []
    for i in range(rows):
        t = i / (rows - 1); row = []
        for th in ths:
            ph = top(th) + .55 * t + (.25 * t if abs(th) < .8 else 0)
            front = math.cos(th) ** 2 if abs(th) < PI / 2 else 0
            p = head_point(th, min(ph, 2.95), 1.06 + .04 * math.sin(PI * t) + .08 * front * t + .012 * math.cos(30 * th))
            p.z -= .1 * front * t
            row.append(p)
        P.append(row)
    sheet(m, k, P, lambda c: c)
    Q = [P[-1], [head_point(th, 2.55, .9) for th in ths]]
    sheet(m, k, Q, lambda c: V(0, 0, -1))
    return m

def hair_newsboy():
    m = M('newsboy hair'); k = CELL['Newsboy']; rng = random.Random(6)
    line = lambda th: .14 - .2 * smooth(.6, 1.4, abs(th)) - .26 * smooth(1.5, 3.0, abs(th))
    hair_shell(m, k, line, lambda th, ph: 1.06 + .02 * math.sin(7 * th + 3 * ph) + .015 * math.cos(23 * th))
    for i in range(34):  # tousled: locks spilling out from under the cap, tips kicking outward
        th = rng.uniform(-PI, PI); ph0 = phi_for(.22) + rng.uniform(0, .08)
        ph1 = phi_for(line(th)) + rng.uniform(.05, .2)
        lock(m, k, surface_path(th, ph0, th + rng.uniform(-.3, .3), ph1, 1.07, .03, curl=rng.uniform(.03, .09), n=6, wave=rng.uniform(-.08, .08)),
             rng.uniform(.08, .12), rng=rng)
    return m

def hair_bands(name, k, seed, bun_centre, bun_normal, bun_r):
    """Centre-parted bands drawn down over the temples and back into a low bun (Mother, Widow)."""
    m = M(name); rng = random.Random(seed)
    line = lambda th: .31 - .36 * smooth(.5, 1.4, abs(th)) - .22 * smooth(1.6, 3.0, abs(th))
    hair_shell(m, k, line, lambda th, ph: 1.05 + .015 * math.exp(-((abs(th) - 1.4) / .45) ** 2) * math.exp(-((ph - 1.3) / .35) ** 2)
               - .018 * math.exp(-(th / .07) ** 2) * math.exp(-((ph - .5) / .4) ** 2) + .008 * math.cos(30 * th))
    for i in range(36):  # from the parting straight down the sides, then back over the ears to the bun
        s = 1 if i % 2 else -1; th0 = s * rng.uniform(.04, .09); ph0 = .12 + .5 * (i // 2) / 18
        th1 = s * (1.5 + 1.3 * (i // 2) / 18); ph1 = phi_for(line(th1)) - .04
        path = surface_path(th0, ph0, th0 + s * .35, ph0 + (ph1 - ph0) * .55, 1.055, .008, n=4)
        path += surface_path(th0 + s * .35, ph0 + (ph1 - ph0) * .55, th1, ph1, 1.055, .008, n=5)[1:]
        lock(m, k, path, rng.uniform(.05, .065), flat=.35, rng=rng)
    coil(m, k, bun_centre, bun_normal, bun_r, .09)
    return m

def hair_mother():
    return hair_bands('mother hair', CELL['Mother'], 7, (0, .58, -.05), (0, 1, -.1), .19)

def hair_widow():
    return hair_bands('widow hair', CELL['Widow'], 8, (0, .62, .02), (0, 1, .1), .22)

# ------------------------------------------------------------------ hats
def lathe(m, k, prof, out_fn, seg=lod(36), sy=1.06, mod=None, cap=False):
    """Profile [(r, z)] spun round the head axis (front -Y), ovalled front to back by sy."""
    P = []
    for r, z in prof:
        row = []
        for j in range(seg + 1):
            th = -PI + TAU * j / seg
            rr, zz = (r, z) if mod is None else mod(th, r, z)
            row.append(V(rr * math.sin(th), -rr * math.cos(th) * sy, zz))
        P.append(row)
    sheet(m, k, P, out_fn)
    if cap:
        r, z = prof[-1]; c = V(0, 0, z)
        for j in range(seg):
            m.face([tuple(c), tuple(P[-1][j]), tuple(P[-1][j + 1])], [cuv(k, .5, .5), cuv(k, j / seg, 0), cuv(k, (j + 1) / seg, 0)], (0, 0, 1))
    return P

def brim(m, k, r0, r1, zb, curl, dip=0.0, roll=.035, seg=lod(40), sy=1.06, droop=0.0):
    """A hat brim from r0 to r1 at height zb, sides curling up by `curl`, a rolled edge."""
    def z_at(th, f):
        s2 = math.sin(th) ** 2
        return zb + f * f * (curl * s2 - dip * (1 - s2)) - droop * f * max(0, -math.cos(th)) * 0
    top, bot = [], []
    for i in range(4):
        f = i / 3; r = r0 + (r1 - r0) * f
        top.append([V(r * math.sin(th), -r * math.cos(th) * sy, z_at(th, f) + .012) for th in (-PI + TAU * j / seg for j in range(seg + 1))])
        bot.append([V(r * math.sin(th), -r * math.cos(th) * sy, z_at(th, f) - .012) for th in (-PI + TAU * j / seg for j in range(seg + 1))])
    sheet(m, k, top, lambda c: V(0, 0, 1)); sheet(m, k, bot, lambda c: V(0, 0, -1))
    edge = [tuple(V(r1 * math.sin(th), -r1 * math.cos(th) * sy, z_at(th, 1))) for th in (-PI + TAU * j / seg for j in range(seg + 1))]
    lock(m, k, edge, roll, flat=1, sides=5, s0=.3)

def hat_bowler():
    m = M('clerk bowler'); k = CELL['felt']
    prof = [(.66, .24), (.68, .36), (.67, .5), (.62, .64), (.52, .76), (.36, .85), (.18, .89), (.02, .9)]
    lathe(m, k, prof, lambda c: c - V(0, 0, .3), sy=1.08)
    lathe(m, CELL['band'], [(.69, .245), (.705, .30), (.70, .36)], lambda c: c - V(0, 0, c.z), sy=1.08)
    brim(m, k, .66, .9, .24, .12, dip=.02, sy=1.08)
    return m

def hat_top():
    m = M('gentleman top hat'); k = CELL['plush']
    prof = [(.63, .26), (.61, .45), (.6, .7), (.62, 1.0), (.65, 1.26), (.64, 1.29)]
    lathe(m, k, prof, lambda c: c - V(0, 0, c.z), sy=1.08)
    lathe(m, k, [(.64, 1.29), (.4, 1.3), (.01, 1.3)], lambda c: V(0, 0, 1), sy=1.08)
    lathe(m, CELL['band'], [(.635, .27), (.625, .38), (.62, .48)], lambda c: c - V(0, 0, c.z), sy=1.08)
    brim(m, k, .62, .96, .26, .14, dip=.03, sy=1.08)
    return m

def hat_peaked():
    m = M('porter cap'); k = CELL['capcloth']
    lathe(m, k, [(.65, .2), (.655, .33), (.66, .44)], lambda c: c - V(0, 0, c.z), sy=1.06)  # band
    lathe(m, k, [(.66, .44), (.72, .52), (.76, .6), (.75, .64)], lambda c: c - V(0, 0, .2), sy=1.06)
    lathe(m, k, [(.75, .64), (.5, .67), (.02, .68)], lambda c: V(0, 0, 1), sy=1.06)
    lathe(m, CELL['patent'], [(.665, .22), (.67, .27)], lambda c: c - V(0, 0, c.z), sy=1.06)  # chin strap
    # the peak: a stiff patent leather half moon angled down over the eyes
    for side, off in ((1, .012), (-1, -.012)):
        P = []
        for i in range(4):
            f = i / 3; row = []
            for j in range(17):
                th = -1.2 + 2.4 * j / 16
                r = .66 + .38 * f * (1 - .45 * (th / 1.2) ** 2)
                z = .22 - .2 * f - .03 * f * (1 - (th / 1.2) ** 2) + off
                row.append(V(r * math.sin(th), -r * math.cos(th) * 1.06, z))
            P.append(row)
        sheet(m, CELL['patent'], P, lambda c, s=side: V(0, 0, s))
    m.box((0, -.705, .33), (.16, .03, .13), (*cuv(CELL['brass'], .2, .2), *cuv(CELL['brass'], .8, .8)))  # badge
    for s in (-1, 1):  # strap buttons
        m.box((s * .62, -.26, .245), (.05, .05, .05), (*cuv(CELL['brass'], .1, .1), *cuv(CELL['brass'], .9, .9)))
    return m

def hat_flat():
    m = M('newsboy cap'); k = CELL['tweed']
    def mod(th, r, z):  # the soft crown slides forward and down over the peak
        f = max(0, -math.cos(th + PI)) if False else max(0, math.cos(th))
        lift = min(1.0, max(0, z - .22) / .42) * min(1.0, r / .7)
        return r * (1 + .1 * f * lift), z - .1 * f * lift
    prof = [(.66, .2), (.7, .3), (.75, .42), (.75, .52), (.68, .62), (.5, .7), (.28, .74), (.02, .75)]
    lathe(m, k, prof, lambda c: c - V(0, 0, .1), mod=mod, sy=1.1, seg=lod(48))
    for j in range(8):  # panel seams
        th = TAU * j / 8
        path = [tuple(V(r * math.sin(th), -r * math.cos(th) * 1.1, z)) for r, z in [mod(th, r, z) for r, z in prof[2:]]]
        lock(m, k, path, .012, flat=1, sides=3, s0=.0)
    m.box((0, 0, .76), (.09, .09, .04), (*cuv(k, .2, .2), *cuv(k, .5, .5)))  # button
    for side, off in ((1, .012), (-1, -.012)):
        P = []
        for i in range(3):
            f = i / 2; row = []
            for j in range(13):
                th = -1.1 + 2.2 * j / 12
                r = .66 + .26 * f * (1 - .5 * (th / 1.1) ** 2)
                row.append(V(r * math.sin(th), -r * math.cos(th) * 1.1, .21 - .17 * f + off))
            P.append(row)
        sheet(m, k, P, lambda c, s=side: V(0, 0, s))
    return m

def hat_bonnet():
    m = M('mother bonnet'); k = CELL['bonnet']; beta = 1.3
    rows, seg = lod(9, 4), lod(26)
    def th_at(s):
        return beta + (TAU - 2 * beta) * s
    phmax = lambda th: 1.85 + .2 * (1 - math.cos(th)) / 2
    def bsc(th, ph):  # swelling over the bun at the back
        return 1.2 + .05 * ph / 2 + .2 * math.exp(-((th - PI) / .7) ** 2) * math.exp(-((ph - 1.55) / .45) ** 2)
    P = []
    for i in range(rows):
        row = []
        for j in range(seg + 1):
            th = th_at(j / seg); ph = .04 + (phmax(th) - .04) * i / (rows - 1)
            row.append(head_point(th, ph, bsc(th, ph)))
        P.append(row)
    sheet(m, k, P, lambda c: c)
    Pi = [[p * .97 for p in row] for row in P]
    sheet(m, CELL['lining'], Pi, lambda c: -c)
    # the poke: a deep brim round the face opening, flaring forward
    edge = [head_point(beta, phi, 1.2) for phi in [.04 + (phmax(beta) - .04) * (1 - i / 10) for i in range(11)]]
    edge += [head_point(-beta, phi, 1.2) for phi in [.04 + (phmax(beta) - .04) * i / 10 for i in range(11)]]
    for side, sc in ((1, 0), (-1, -.02)):
        R = []
        for f in (0, .5, 1):
            row = []
            for p in edge:
                outdir = V(p.x, 0, p.z * 1.2).normalized() if (abs(p.x) + abs(p.z)) > 1e-6 else V(0, 0, 1)
                row.append(p + outdir * (.26 * f + sc) + V(0, -.42 * f, 0))
            R.append(row)
        sheet(m, k if side > 0 else CELL['lining'], R, lambda c, s=side: (c - V(0, -.2, 0)) * s)
    # ribbon ties from the brim under the chin to a bow at her left cheek
    rb = CELL['ribbon']
    for s in (-1, 1):
        start = head_point(s * beta, phmax(beta) - .05, 1.2)
        path = [tuple(start), tuple(head_point(s * 1.0, 2.45, 1.12)), tuple(head_point(s * .5, 2.75, 1.1)), tuple(V(.3, -.5, -.48))]
        lock(m, rb, path, .075, flat=.25, sides=4, s0=.1)
    bow = V(.32, -.55, -.48)
    for s in (-1, 1):
        loop = [tuple(bow + V(s * .2 * math.sin(a) * (1 - .3 * math.cos(a)), -.03, .09 * math.sin(2 * a) * .8)) for a in [PI * q / 10 for q in range(11)]]
        lock(m, rb, loop, .06, flat=.3, sides=4, s0=.3)
        lock(m, rb, [tuple(bow), tuple(bow + V(s * .07, -.02, -.18)), tuple(bow + V(s * .1, -.02, -.34))], .06, flat=.25, sides=4, s0=.5)
    m.box(tuple(bow + V(0, -.03, 0)), (.08, .06, .08), (*cuv(rb, .2, .2), *cuv(rb, .6, .6)))
    return m

def veil_widow():
    m = M('widow veil'); k = CELL['crape']; seg, rows = lod(30), lod(12, 5)
    beta = 1.15
    ths = [beta + (TAU - 2 * beta) * j / seg for j in range(seg + 1)]
    P = []
    for i in range(rows):
        t = i / (rows - 1); row = []
        for th in ths:
            if t < .45:  # over the crown and down the back of the head, swelling over the bun
                ph = .35 + (2.0 - .35) * t / .45
                bun = .24 * math.exp(-((th - PI) / .65) ** 2) * math.exp(-((ph - 1.55) / .45) ** 2)
                p = head_point(th, ph, 1.13 + bun)
            else:  # then hanging in folds to the shoulders
                base = head_point(th, 2.0, 1.13); f = (t - .45) / .55
                outv = V(base.x, base.y, 0).normalized()
                p = base + outv * (.12 * f + .05 * math.sin(9 * th) * f) + V(0, .1 * f, -1.05 * f)
            row.append(p)
        P.append(row)
    sheet(m, k, P, lambda c: V(c.x, c.y, c.z * .3))
    sheet(m, CELL['lining'], [[p * .985 - V(0, 0, .005) for p in row] for row in P], lambda c: -V(c.x, c.y, c.z * .3))
    return m

# ------------------------------------------------------------------ cloth pieces (Torso space)
def superellipse(t, e=.4):
    c, s = math.cos(t), math.sin(t)
    return math.copysign(abs(c) ** e, c), math.copysign(abs(s) ** e, s)

def coat_skirt(name, k, z0, z1, w0, d0, w1, d1, gap0, gap1, seg=lod(40), rows=lod(8, 4), flare_back=0.0, vent=False):
    """A coat's skirts from the waist down, open at the front by gap (radians each side)."""
    m = M(name)
    for layer, sc, cell in ((0, 1.0, k), (1, .975, CELL['lining'])):
        P = []
        for i in range(rows):
            f = i / (rows - 1); z = z0 + (z1 - z0) * f
            w = w0 + (w1 - w0) * f ** 1.4; d = d0 + (d1 - d0) * f ** 1.4
            gap = gap0 + (gap1 - gap0) * f
            row = []
            for j in range(seg + 1):
                t = -PI / 2 + gap + (TAU - 2 * gap) * j / seg
                a, b = superellipse(t)
                back = max(0, b) * flare_back * f
                fold = .025 * math.sin(10 * t) * f
                row.append(V(a * (w + fold) * sc, b * (d + back + fold) * sc, z))
            P.append(row)
        sheet(m, cell, P, (lambda c: V(c.x, c.y, 0)) if layer == 0 else (lambda c: -V(c.x, c.y, 0)))
        if layer == 0:
            outer = P
    for j in range(seg + 1):  # hem binding
        pass
    lock(m, k, [tuple(p) for p in outer[-1]], .025, flat=1, sides=4, s0=.2)
    for s in (0, -1):  # front edges
        lock(m, k, [tuple(row[s]) for row in outer], .022, flat=1, sides=4, s0=.4)
    return m

def bustle():
    m = M('mother bustle'); k = CELL['bustle']; seg, rows = lod(22), lod(10, 4)
    P = []
    for i in range(rows):
        f = i / (rows - 1); z = -.45 - 1.35 * f
        puff = .22 + .5 * math.sin(PI * min(1, f / .75)) ** .8
        row = []
        for j in range(seg + 1):
            t = PI * j / seg  # the back half only (+Y)
            a, b = math.cos(t), math.sin(t)
            swag = .04 * math.sin(3 * PI * f) * b
            row.append(V(a * (1.0 + .12 * f), .55 + b * (puff + swag) + .05 * f, z - .06 * math.sin(4 * t) * f))
        P.append(row)
    sheet(m, k, P, lambda c: V(c.x, c.y - .5, 0))
    sheet(m, CELL['lining'], [[p - V(0, .02, 0) for p in row] for row in P], lambda c: -V(c.x, c.y - .5, 0))
    lock(m, k, [tuple(p) for p in P[-1]], .03, flat=1, sides=4, s0=.2)
    rb = CELL['bustle']  # the bow at the small of the back
    c = V(0, .62, -.5)
    for s in (-1, 1):
        lock(m, rb, [tuple(c + V(s * .32 * math.sin(a), .12 * math.sin(a), .14 * math.sin(2 * a))) for a in [PI * q / 10 for q in range(11)]], .07, flat=.3, sides=4)
        lock(m, rb, [tuple(c), tuple(c + V(s * .1, .1, -.35)), tuple(c + V(s * .16, .12, -.7))], .07, flat=.25, sides=4)
    return m

def shawl():
    m = M('widow shawl'); k = CELL['shawl']; seg, rows = lod(40), lod(8, 4)
    a0 = .55  # the front opening either side of the chest
    def length(a):  # long points front and back, short over the shoulders
        f = abs(math.sin(a))
        return 1.25 - .25 * (1 - f) + (.45 if math.sin(a) > 0 else .2) * f ** 4
    P = []
    for i in range(rows):
        s = i / (rows - 1); row = []
        for j in range(seg + 1):
            a = -PI / 2 + a0 + (TAU - 2 * a0) * j / seg
            d = V(math.cos(a), math.sin(a), 0)
            r0 = .42; edge = min(1.04 / max(1e-6, abs(d.x)), .56 / max(1e-6, abs(d.y)))
            L = length(a) * s; flat = edge - r0
            if L <= flat:
                p = d * (r0 + L) + V(0, 0, 1.03 + .03 * (1 - s))
            else:
                drop = L - flat
                p = d * (edge + .03 + .04 * min(1, drop)) + V(0, 0, 1.03 - drop)
            p += d * .03 * math.sin(11 * a) * s
            row.append(p)
        P.append(row)
    sheet(m, k, P, lambda c: V(c.x, c.y, max(0, c.z - .95) * 4))
    sheet(m, k, [[p - V(p.x, p.y, 0).normalized() * .02 - V(0, 0, .02) for p in row] for row in P], lambda c: -V(c.x, c.y, max(0, c.z - .95) * 4))
    return m

def kerchief():
    m = M('newsboy kerchief'); k = CELL['kerchief']
    band = [tuple(V(.46 * math.sin(a), -.36 * math.cos(a) - .02, 1.02 - .03 * math.cos(a))) for a in [-1.9 + 3.8 * q / 12 for q in range(13)]]
    lock(m, k, band, .08, flat=.6, sides=6, s0=.1)
    knot = V(.08, -.55, .9)
    m.box(tuple(knot), (.16, .1, .14), (*cuv(k, .1, .1), *cuv(k, .5, .5)))
    for s, l in ((-1, .45), (1, .38)):
        lock(m, k, [tuple(knot), tuple(knot + V(s * .1, -.04, -l * .5)), tuple(knot + V(s * .18, -.02, -l))], .1, flat=.2, sides=4, s0=.4)
    return m

# ------------------------------------------------------------------ build, render, export
PIECES = {
    'Clerk': [(hair_clerk, 'Head'), (hat_bowler, 'Head'), (lambda: coat_skirt('clerk coat', CELL['sack'], -.55, -1.5, 1.05, .55, 1.1, .6, .25, .55), 'Torso')],
    'Mother': [(hair_mother, 'Head'), (hat_bonnet, 'Head'), (bustle, 'Torso')],
    'Gentleman': [(hair_gentleman, 'Head'), (beard_gentleman, 'Head'), (hat_top, 'Head'),
                  (lambda: coat_skirt('gentleman frock', CELL['frock'], -.55, -2.5, 1.06, .56, 1.16, .74, .18, .3, flare_back=.12, vent=True), 'Torso')],
    'Porter': [(hair_porter, 'Head'), (beard_porter, 'Head'), (hat_peaked, 'Head'),
               (lambda: coat_skirt('porter reefer', CELL['reefer'], -.55, -1.4, 1.04, .54, 1.06, .57, .0, .0), 'Torso')],
    'Widow': [(hair_widow, 'Head'), (veil_widow, 'Head'), (shawl, 'Torso')],
    'Newsboy': [(hair_newsboy, 'Head'), (hat_flat, 'Head'), (kerchief, 'Torso')],
}

def fbx_from_objs(files):
    for f in files:
        bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
        bpy.ops.wm.obj_import(filepath=str(OUT / f))
        bpy.ops.export_scene.fbx(filepath=str(OUT / f.replace('.obj', '.fbx')), use_selection=False,
                                 apply_scale_options='FBX_SCALE_UNITS', axis_forward='-Z', axis_up='Y')

def main():
    (OUT / 'renders').mkdir(parents=True, exist_ok=True)
    ids = list(LOOKS)
    dx_of = {pid: (i - (len(ids) - 1) / 2) * ns['SPACING'] for i, pid in enumerate(ids)}
    scene = stage(18)
    for pid in ids:  # each head wears its painted face, as in the game
        def faced(skin, dx, pid=pid):
            mb['head_proxy'](mb['head_material'](OUT / f'{pid.lower()}-face.png')).location.x = dx
        ns['skin_head'] = faced
        person(pid, LOOKS[pid], dx_of[pid], False)
    bags(dx_of, False)
    made = {}
    if not PLAIN:
        atlas = textured(OUT / 'heads.png', 'heads atlas', .7)
        before = set(mb['manifest'])
        for pid in ids:
            for build, limb in PIECES[pid]:
                ob = export(build(), limb, HEAD if limb == 'Head' else TORSO, atlas, 'heads.png')
                ob.location.x += dx_of[pid]
        made = {k: v for k, v in mb['manifest'].items() if k not in before}
    tag = 'heads-before' if PLAIN else 'heads-after'
    shoot(scene, f'{tag}-lineup.png', (0, -48, 4.2), (0, 0, 2.9), 50, (2000, 900))
    shoot(scene, f'{tag}-34-left.png', (dx_of['Clerk'] - 6, -9, 5), (dx_of['Mother'] - .6, 0, 3.2), 45, (1400, 1000))
    bpy.data.objects['wall'].hide_render = True
    shoot(scene, f'{tag}-back.png', (2, 46, 4.8), (0, 0, 2.9), 50, (2000, 900))
    bpy.data.objects['wall'].hide_render = False
    for pid in ids:
        shoot(scene, f'{tag}-close-{pid.lower()}.png', (dx_of[pid] - 1.6, -4.2, 5.0), (dx_of[pid], 0, 4.1), 50, (1000, 1000))
    if not PLAIN:
        (OUT / 'heads-manifest.json').write_text(json.dumps({
            'texture': 'heads.png', 'units': 'studs, limb space, -Z is the front; FBX uploads import turned round, yaw 180',
            'totalTriangles': sum(v['triangles'] for v in made.values()), 'pieces': list(made.values())}, indent=2))
        fbx_from_objs([v['mesh'] for v in made.values()])

main()
