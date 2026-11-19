"""Body pieces for the Brute (see build.py for the design notes). Each function returns a Mesh in its part frame
(Roblox axes, studs) with sRGB vertex colours; build.py bakes and exports them."""

import math

import numpy as np

import b8lib as L
from build import (ASH, CHAR, COPPER, CORD, EMBER_RIM, IRON, IRON_BRIGHT, LEATHER, LEATHER_DARK, LEATHER_WORN,
                   MOLESKIN, MOLESKIN_DARK, RAG, RUST, SCAR, SCAR_RIDGE, SCAR_RIM, SKIN, SOOT, STITCH, WOOD, soot_skin)

S, mixc, Mesh = L.S, L.mixc, L.Mesh
rng0 = np.random.default_rng


def snap(surf, pts, off, smooth=2):
    P, N = [], []
    for p in pts:
        q, n, _ = surf.nearest(p)
        P.append(q + n * off)
        N.append(n)
    P, N = np.array(P), np.array(N)
    for _ in range(smooth):
        P[1:-1] = (P[:-2] + 2 * P[1:-1] + P[2:]) / 4
        N[1:-1] = L.unit(N[:-2] + 2 * N[1:-1] + N[2:])
    return P, N


def burn_paint(m, C, burn, cav):
    scar = mixc(np.tile(SCAR, (len(m.V), 1)), SCAR_RIM, S(0.6, 0.15, burn) * 0.8)
    scar = mixc(scar, SCAR_RIDGE, S(-0.15, -0.7, cav) * 0.25)
    scar = mixc(scar, SOOT, np.clip(0.4 + 0.5 * np.clip(cav, 0, 1), 0, 1))
    return mixc(C, scar, S(0.1, 0.45, burn) * 0.4)


def plaques(m, burn, rng, count, size, height):
    """Keloid: thick ropes and plaques laid inside a burn, and contracture lines between them."""
    idx = np.flatnonzero(burn > 0.5)
    if len(idx) == 0:
        return
    surf = L.Surface(m)
    for _ in range(count):
        c = m.V[rng.choice(idx)]
        d = rng.normal(0, 1, 3)
        d = d / np.linalg.norm(d) * size * rng.uniform(0.8, 1.6)
        pts = np.array([surf.nearest(c + d * t)[0] for t in np.linspace(-1, 1, 7)])
        m.ridge(pts, size * rng.uniform(0.25, 0.4), height * rng.uniform(0.6, 1.2), key="keloid")
    for _ in range(count):
        c = m.V[rng.choice(idx)]
        d = rng.normal(0, 1, 3)
        d = d / np.linalg.norm(d) * size * 0.6
        pts = np.array([surf.nearest(c + d * t)[0] for t in (-1, 0, 1)])
        m.crease(pts, size * 0.12, height * 0.5, 0.5)


# ------------------------------------------------------------------ torso: body, bib, neck strap, rag, fissures
FISSURES = [  # chest frame; rough paths, laid on the body; (path, width)
    ([(-1.62, 0.45, -0.15), (-1.66, 0.1, -0.2), (-1.6, -0.25, -0.3), (-1.55, -0.6, -0.35)], 1.0),
    ([(-1.66, 0.05, -0.18), (-1.75, -0.15, 0.05), (-1.72, -0.35, 0.25)], 0.7),
    ([(-1.15, 0.9, -0.82), (-1.28, 0.6, -0.82), (-1.38, 0.3, -0.74)], 0.8),
    ([(1.62, 0.05, -0.05), (1.6, -0.25, -0.15), (1.55, -0.5, -0.2)], 0.65),
    ([(-0.75, 1.05, 1.0), (-0.45, 0.7, 1.08), (-0.5, 0.3, 1.1), (-0.3, -0.05, 1.08)], 1.0),
    ([(0.55, -0.25, 1.05), (0.75, -0.6, 0.98), (0.95, -0.95, 0.88)], 0.75),
]
NECK_AXIS = (np.array((0, 1.1, -0.35)), np.array((0, 1.75, -0.85)))
TS = np.array((1.0, 1.0, 1.0))  # the torso's fit to its skeleton: the giant is narrower for its height (build.py)


def torso_body():
    m = L.Meta(0.05)
    m.ell((0, 0.35, 0.05), (1.45, 1.25, 1.0))  # ribcage
    m.ell((0, -0.72, -0.22), (1.32, 0.98, 1.04))  # the gut
    m.ell((0.66, 0.52, -0.68), (0.62, 0.42, 0.34))  # pecs, heavy and low
    m.ell((-0.68, 0.5, -0.66), (0.63, 0.44, 0.34))
    m.ell((1.3, -0.1, 0.12), (0.42, 1.0, 0.78))  # flanks
    m.ell((-1.3, -0.12, 0.12), (0.43, 1.0, 0.78))
    m.ell((0, 1.3, 0.2), (1.2, 0.5, 0.8))  # trapezius
    m.ell((0, 0.95, 0.7), (1.15, 0.75, 0.5))  # the hump
    m.ell((1.82, 0.88, 0.05), (0.52, 0.56, 0.58))  # deltoids; the right one bigger
    m.ell((-1.79, 0.86, 0.05), (0.49, 0.53, 0.55))
    m.ell((1.05, 1.32, 0.12), (0.75, 0.42, 0.62))  # trapezius sloping out to the shoulders
    m.ell((-1.05, 1.3, 0.12), (0.75, 0.42, 0.62))
    m.cap(NECK_AXIS[0], NECK_AXIS[1], 0.55)
    b = m.mesh(0.026)
    b.smooth(it=4)
    surf = L.Surface(b)
    out = lambda pts, axis=(0, 1, 0): snap(surf, L.smooth_path(pts, 24), 0.0, 0)[0]
    # clavicles, the fold under the pecs, armpits, the line between the pecs
    for s in (1, -1):
        b.ridge(out([(s * 0.18, 1.2, -0.9), (s * 0.7, 1.3, -0.75), (s * 1.3, 1.32, -0.42)]), 0.08, 0.02)
        b.crease(out([(s * 0.35, 0.12, -1.0), (s * 0.8, 0.12, -0.92), (s * 1.22, 0.32, -0.62)]), 0.08, 0.04, 0.5)
        b.inflate(b.ball((s * 1.5, 0.6, -0.15), 0.32), -0.06)
    b.crease(out([(0, 0.95, -1.05), (0, 0.4, -1.1), (0, 0.0, -1.1)]), 0.1, 0.035, 0.4)
    # back: spine, shoulder blades, rolls at the hump, rolls over the hips
    b.crease(out([(0, 1.35, 1.0), (0, 0.4, 1.12), (0, -0.6, 1.05), (0, -1.45, 0.88)]), 0.12, 0.04, 0.4)
    for s in (1, -1):
        b.ridge(out([(s * 0.35, 1.15, 1.02), (s * 0.85, 0.85, 0.98), (s * 0.95, 0.2, 0.9), (s * 0.55, -0.1, 1.0)]), 0.1, 0.03)
        b.crease(out([(s * 1.4, -0.45, 0.4), (s * 1.45, -0.55, 0.0), (s * 1.35, -0.6, -0.4)]), 0.07, 0.035, 0.5)
    b.crease(out([(-1.1, -1.05, 0.7), (0, -1.15, 0.95), (1.05, -1.0, 0.72)]), 0.09, 0.04, 0.5)
    b.crease(out([(-0.7, 1.4, 0.75), (0, 1.32, 0.95), (0.8, 1.42, 0.72)]), 0.07, 0.025, 0.5)
    # deltoid edges
    for s in (1, -1):
        b.crease(out([(s * 1.5, 1.45, -0.45), (s * 1.75, 0.9, -0.62), (s * 2.0, 0.45, -0.4)]), 0.08, 0.03, 0.5)
    # the burn: left shoulder, the left of the chest and flank, the left shoulder blade
    burn = np.maximum.reduce([b.ell((-1.35, 0.75, -0.25), (0.75, 0.8, 0.9)), b.ell((-1.45, -0.35, 0.1), (0.42, 0.9, 0.85)),
                              b.ell((-0.6, 1.2, 0.35), (0.5, 0.4, 0.6)), b.ell((-0.55, 0.45, 1.0), (0.5, 0.6, 0.3))])
    burn = S(0.15, 0.55, burn * (1.0 + 0.7 * L.fbm(b.V, 2.5, 2, 21)))
    b.smooth(burn, it=6, lam=0.6)
    rng = rng0(31)
    plaques(b, burn, rng, 14, 0.22, 0.03)
    # the fissures: a raised welt, the crack cut into it
    surf = L.Surface(b)
    lines = []
    for pts, wd in FISSURES:
        path = snap(surf, L.smooth_path(pts, 28, 0.012, int(rng.integers(99))), 0.0, 1)[0]
        b.ridge(path, 0.12 * wd, 0.03 * wd)
        b.crease(path, 0.05 * wd, 0.075 * wd, 0.5, key="fissure")
        lines.append((path, wd))
    b.masks["burn"] = burn
    b.fissures = lines
    b.smooth(it=1, lam=0.3)
    cav = b.cavity(3)
    C = soot_skin(b, cav, seed=4, coverage=0.66)
    C = burn_paint(b, C, burn, cav)
    for path, wd in lines:
        d = L.path_dist(b.V, path)[0]
        C = mixc(C, CHAR, S(0.16 * wd, 0.05 * wd, d) * 0.85)
        C = mixc(C, EMBER_RIM, S(0.07 * wd, 0.02 * wd, d))
        C = mixc(C, (0.85, 0.42, 0.12), S(0.035 * wd, 0.0, d) * 0.8)
    b.C = C
    b.V = b.V * TS
    b.fissures = [(np.asarray(p) * TS, wd) for p, wd in lines]
    return b


def leather_colour(P, n, cav, seed, edge=None):
    """Hide that has been worked in: grain, darker with grease and soot in the folds, rubbed pale on what stands
    proud, cut edges dark."""
    C = np.tile(LEATHER, (len(P), 1))
    C = mixc(C, LEATHER_DARK, 0.35 + 0.25 * L.fbm(P, 3.0, 3, seed))
    C = mixc(C, LEATHER_DARK * 0.6, np.clip(cav, 0, 1) * 0.8)
    C = mixc(C, LEATHER_WORN, S(-0.15, -0.7, cav) * 0.6)
    C = mixc(C, SOOT, 0.12 + 0.12 * L.fbm(P, 9.0, 2, seed + 1))
    grain = L.vnoise(P, 60.0, seed + 2)
    C = C * (1 + 0.06 * grain[:, None])
    if edge is not None:
        C = mixc(C, LEATHER_DARK * 0.5, edge)
    return C


def stitch_mask(d_edge, arc, inset=0.035, pitch=0.05, width=0.008):
    on = S(width * 1.6, width * 0.6, np.abs(d_edge - inset))
    dash = S(0.1, 0.4, np.sin(arc / pitch * math.tau))
    return on * dash


def bib(body):
    """The apron's bib laid on the chest: one hide, rounded top corners, sprung off the hollows, folds over the
    gut, spark holes and a scorch. Returns the bib mesh and its corner points."""
    surf = L.Surface(body)
    top, bot = 0.92 * TS[1], -1.75 * TS[1]
    wt, wb = 1.45 * TS[0], 2.35 * TS[0]

    def place(u, v):
        y = top - v * (top - bot)
        w = wt + (wb - wt) * S(0.0, 1.0, v) ** 0.8
        x = (u - 0.5) * w
        P = np.zeros((len(u), 3))
        for i in range(len(u)):
            q, n = surf.cast((x[i], y[i], -4.0), (0, 0, 1), 0.05)
            P[i] = q if q is not None else (x[i], y[i], -1.1)
        return P

    def keep(u, v):  # rounded top corners
        r = 0.08
        for cu in (r, 1 - r):
            if v < r and abs(u - cu) > 0 and ((u < r and cu == r) or (u > 1 - r and cu == 1 - r)):
                if (u - cu) ** 2 + (v - r) ** 2 > r * r:
                    return False
        return True

    m = L.grid(40, 64, place, keep)
    # spring the hide off the hollows: smooth the sheet, then keep it outside the body
    for _ in range(6):
        m.V = 0.5 * m.V + 0.5 * m.avg(m.V)
    m.V = surf.outside(m.V, None, 0.035)
    m.orient = None
    L.orient_out(m, lambda p: np.stack([np.zeros(len(p)), p[:, 1], np.full(len(p), 0.4)], 1))
    # folds where it bends over the gut, uneven and slanted
    u, v = m.UV[:, 0], m.UV[:, 1]
    n = m.N()
    fold = np.zeros(len(u))
    for v0, a, tilt in ((0.52, 0.016, 0.04), (0.62, 0.022, -0.03), (0.71, 0.014, 0.06), (0.8, 0.018, -0.02)):
        fold += a * np.exp(-((v - v0 - tilt * (u - 0.5)) / 0.025) ** 2) * S(0.0, 0.25, u) * S(1.0, 0.75, u)
    m.V += n * fold[:, None]
    m.masks["fold"] = fold / 0.022
    P = m.V
    cav = m.cavity(2)
    edge_d = np.minimum.reduce([u, 1 - u, v]) * np.array([1.0])
    edge = S(0.02, 0.0, edge_d)
    C = leather_colour(P, m.N(), cav, 7, edge)
    # grease where hands wipe at the sides of the gut, scorch low on the bib, spark holes
    C = mixc(C, LEATHER_DARK * 0.4, S(0.32, 0.05, np.minimum(u, 1 - u)) * S(0.45, 0.75, v) * 0.6)
    C = mixc(C, CHAR, S(0.3, 0.0, np.hypot((u - 0.66) / 1.4, v - 0.9)) * 0.55)
    rng = rng0(9)
    for _ in range(9):
        cu, cv, r = rng.uniform(0.1, 0.9), rng.uniform(0.15, 0.95), rng.uniform(0.004, 0.009)
        d = np.hypot((u - cu) * 1.6, (v - cv) * 2.65)
        C = mixc(C, CHAR, S(r * 2.6, r * 1.2, d) * 0.7)
        C = mixc(C, (0.02, 0.015, 0.012), S(r, r * 0.6, d))
    m.C = C
    corners = {}
    for name, (cu, cv) in {"tl": (0.06, 0.02), "tr": (0.94, 0.02)}.items():
        i = np.argmin((u - cu) ** 2 + (v - cv) ** 2)
        corners[name] = (m.V[i].copy(), n[i].copy())
    m.uv_place = place
    return L.slab(m, 0.035, colour_rim=LEATHER_DARK * 0.5), corners, m


def pocket(bibsheet, surf_body):
    """A patch pocket on the bib, saddle-stitched, the top corners riveted, the mouth sprung open a little."""
    bs = L.Surface(bibsheet)
    u0, u1, v0, v1 = 0.18, 0.42, 0.1, 0.28

    def place(u, w):
        uu = u0 + (u1 - u0) * u
        vv = v0 + (v1 - v0) * w
        P = bibsheet.uv_place(uu, vv)
        return P

    m = L.grid(14, 12, place)
    for i, p in enumerate(m.V):
        q, n, _ = bs.nearest(p)
        lift = 0.008 + 0.018 * S(0.25, 0.0, m.UV[i, 1]) * math.sin(math.pi * m.UV[i, 0])
        m.V[i] = q + n * lift
    L.orient_out(m, lambda p: np.stack([np.zeros(len(p)), p[:, 1], np.full(len(p), 0.4)], 1))
    u, w = m.UV[:, 0], m.UV[:, 1]
    cav = m.cavity(1)
    C = leather_colour(m.V, m.N(), cav, 12)
    W, H = 0.6, 0.45
    d_edge = np.minimum.reduce([u * W, (1 - u) * W, (1 - w) * H])
    arc = np.where(u * W < 0.06, w * H, np.where((1 - u) * W < 0.06, w * H + 2, u * W + 4))
    st = stitch_mask(d_edge, arc, 0.03, 0.045)
    C = mixc(C, STITCH, st)
    C = mixc(C, LEATHER_DARK * 0.4, S(0.012, 0.0, np.minimum.reduce([u * W, (1 - u) * W, w * H, (1 - w) * H])))
    m.C = C
    rivets = []
    for cu in (0.04, 0.96):
        i = np.argmin((u - cu) ** 2 + (w - 0.05) ** 2)
        n = m.N()[i]
        r = L.rivet(m.V[i] + n * 0.008, n, 0.025)
        r.C = np.tile(COPPER, (len(r.V), 1))
        rivets.append(r)
    return L.join(L.slab(m, 0.02, colour_rim=LEATHER_DARK * 0.5), *rivets)


def buckle(at, along, normal, w=0.2, h=0.17):
    """An iron roller buckle: frame, roller on the front bar, centre bar and prong."""
    along = along / np.linalg.norm(along)
    normal = normal / np.linalg.norm(normal)
    side = np.cross(along, normal)
    corners = [at + side * (-w / 2) + along * (-h / 2), at + side * (w / 2) + along * (-h / 2),
               at + side * (w / 2) + along * (h / 2), at + side * (-w / 2) + along * (h / 2)]
    path = []
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        for t in np.linspace(0, 1, 5)[:-1]:
            path.append(a + (b - a) * t)
    path.append(path[0])
    frame = L.tube(np.array(path), 0.018, sides=6, up=normal, cap=False)
    roller = L.tube(np.array([corners[0] + side * 0.01, corners[1] - side * 0.01]), 0.026, sides=8, up=normal)
    prong = L.tube(np.array([at + normal * 0.015, at + along * (-h / 2) + normal * 0.03]), 0.012, sides=5, up=normal)
    m = L.join(frame, roller, prong)
    t = L.vnoise(m.V, 40, 3)
    m.C = mixc(np.tile(IRON, (len(m.V), 1)), RUST, S(0.0, 0.6, t) * 0.7)
    return m


def neck_strap(body, corners):
    surf = L.Surface(body)
    tl, tr = corners["tl"][0], corners["tr"][0]
    pts = [tl + (0, 0.02, 0)] + [np.array(p) * TS for p in ((-0.74, 1.25, -0.98), (-0.7, 1.62, -0.55), (-0.45, 1.82, 0.0),
                                   (0.0, 1.78, 0.32), (0.45, 1.82, 0.0), (0.7, 1.62, -0.55), (0.74, 1.28, -0.98), (0.68, 1.12, -1.07))]
    path = L.smooth_path(pts, 60)
    P, N = snap(surf, path, 0.035, 3)
    s = L.strap(P, N, 0.13, 0.03)
    # the tab from the buckle down to the right corner, and the buckle on the strap
    tab_P, tab_N = snap(surf, L.smooth_path([P[-1], tr + (0, 0.03, -0.01)], 8), 0.05, 0)
    tab = L.strap(tab_P, tab_N, 0.13, 0.03)
    bk = buckle(P[-3] + N[-3] * 0.03, P[-1] - P[-5], N[-3])
    tail_P, tail_N = snap(surf, L.smooth_path([P[-4], P[-4] + (0.02, -0.12, -0.04), P[-4] + (0.05, -0.24, -0.03)], 8), 0.07, 0)
    tail = L.strap(tail_P, tail_N, 0.12, 0.025)
    parts = []
    for st, seed in ((s, 1), (tab, 2), (tail, 3)):
        cav = np.zeros(len(st.V))
        edge = (np.abs(st.side) > 0) * 0.0
        C = leather_colour(st.V, None, cav, 20 + seed)
        C = mixc(C, LEATHER_DARK * 0.5, 0.2)
        st.C = C
        parts.append(st)
    # punched holes along the tail, rivets at the left tab
    tail.C = mixc(tail.C, (0.02, 0.015, 0.01), S(0.3, 0.6, np.sin(tail.u * math.tau * 3.0)) * (np.abs(tail.side) < 2) * 0.0)
    rivets = []
    for k in (0.03, 0.09):
        i = int(k * len(P))
        r = L.rivet(P[i] + N[i] * 0.017, N[i], 0.024)
        r.C = np.tile(COPPER, (len(r.V), 1))
        rivets.append(r)
    for k in (0.4, 0.75):
        i = int(k * len(tab_P))
        r = L.rivet(tab_P[i] + tab_N[i] * 0.017, tab_N[i], 0.024)
        r.C = np.tile(COPPER, (len(r.V), 1))
        rivets.append(r)
    return L.join(*parts, bk, *rivets)


def neck_rag(body):
    """A sweat rag knotted round the neck where it meets the shoulders; it hides the seam with the head."""
    a0, a1 = NECK_AXIS[0] * TS, NECK_AXIS[1] * TS
    axis = (a1 - a0) / np.linalg.norm(a1 - a0)
    centre = a0 + (a1 - a0) * 0.62
    u = np.cross(axis, (1, 0, 0))
    u /= np.linalg.norm(u)
    w = np.cross(axis, u)
    surf = L.Surface(body)
    ring = []
    for t in np.linspace(0, math.tau, 49)[:-1]:
        d = u * math.cos(t) + w * math.sin(t)
        q, n = surf.cast(centre + d * 1.5, -d, 0.06)
        ring.append(q if q is not None else centre + d * 0.6)
    ring = np.array(ring)
    ring = np.vstack([ring, ring[:1]])
    rag = L.tube(ring, 0.075, sides=7, flat=0.65, up=axis, twist=0.55, cap=False)
    # the knot at the front left and its two ends
    k = np.argmin(np.linalg.norm(ring - (centre + np.array((-0.35, -0.15, -0.6))), axis=1))
    kp = ring[k]
    knot = L.sphere(kp + np.array((0, -0.03, -0.05)), 0.1, (1.2, 0.85, 0.8), seg=10, rings=7)
    ends = []
    for off, ln, wd in (((-0.04, 0, 0), 0.38, 0.1), ((0.06, 0, 0), 0.28, 0.085)):
        pts = L.smooth_path([kp + off + (0, -0.06, -0.07), kp + off + (0.02, -ln * 0.5, -0.1), kp + off + (0.05, -ln, -0.04)], 10)
        P, N = snap(surf, pts, 0.07, 1)
        e = L.strap(P, N, wd, 0.02)
        ends.append(e)
    m = L.join(rag, knot, *ends)
    P = m.V
    C = np.tile(RAG, (len(P), 1))
    C = mixc(C, RAG * 0.5, 0.4 + 0.3 * L.fbm(P, 7, 2, 5))
    C = mixc(C, SOOT, 0.45 + 0.2 * L.fbm(P, 14, 2, 6))
    C = mixc(C, (0.3, 0.27, 0.2), S(0.2, 0.7, L.vnoise(P, 6, 8)) * 0.25)  # dried sweat
    m.C = C
    return m


def embers(fissures):
    """Neon: a thin glowing seam set into the bottom of each fissure (chest frame)."""
    out = []
    for path, wd in fissures:
        P = np.asarray(path)
        n = len(P)
        cen = np.array((0.0, 0.0, 0.0))
        dirs = L.unit(P - np.stack([np.zeros(n), P[:, 1], np.full(n, 0.1)], 1))
        P2 = P - dirs * 0.018 * wd
        radii = 0.032 * wd * np.sin(np.linspace(0.15, math.pi - 0.15, n)) ** 0.6
        out.append(L.tube(P2, radii, sides=5))
    return L.join(*out)


def torso():
    body = torso_body()
    b, corners, sheet = bib(body)
    pk = pocket(sheet, body)
    strap_m = neck_strap(body, corners)
    rag = neck_rag(body)
    glow = embers(body.fissures)
    return L.join(body, b, pk, strap_m, rag), glow


# ------------------------------------------------------------------ pelvis: trousers, belt, apron skirt, thongs, rag
def apron_skirt():
    m = L.Meta(0.05)
    m.ell((0, -0.05, 0.05), (1.2, 0.75, 0.82))  # hips
    m.ell((0.45, -0.35, 0.45), (0.5, 0.5, 0.4))  # seat
    m.ell((-0.45, -0.35, 0.45), (0.5, 0.5, 0.4))
    m.ell((0, 0.3, -0.42), (1.1, 0.5, 0.6))  # the gut's underside
    for s in (1, -1):
        m.cap((s * 0.72, -0.4, 0.0), (s * 0.75, -0.95, 0.02), 0.5)  # thigh roots
    hips = m.mesh(0.03)
    hips.smooth(it=4)
    surf = L.Surface(hips)
    sp = lambda pts: snap(surf, L.smooth_path(pts, 20), 0.0, 0)[0]
    for s in (1, -1):  # crotch folds, side seams, seat seam
        hips.crease(sp([(s * 0.15, -0.6, -0.55), (s * 0.45, -0.75, -0.55), (s * 0.7, -0.95, -0.5)]), 0.05, 0.03, 0.5)
        hips.crease(sp([(s * 1.2, 0.3, 0.0), (s * 1.18, -0.4, 0.05), (s * 1.15, -1.0, 0.05)]), 0.025, 0.012, 0.6, key="seam")
    hips.crease(sp([(0, 0.3, 0.85), (0, -0.4, 0.8), (0, -0.85, 0.5)]), 0.03, 0.025, 0.6, key="seam")
    cav = hips.cavity(2)
    C = np.tile(MOLESKIN, (len(hips.V), 1))
    C = mixc(C, MOLESKIN_DARK, np.clip(cav, 0, 1) * 0.8 + 0.2)
    C = mixc(C, MOLESKIN * 1.35, S(-0.1, -0.6, cav) * 0.4)
    C = mixc(C, SOOT, 0.35 + 0.15 * L.fbm(hips.V, 8, 2, 3))
    C = mixc(C, STITCH * 0.7, hips.masks["seam"] * S(0.2, 0.5, np.sin(hips.V[:, 1] * 120)) * 0.5)
    hips.C = C
    # belt round the waist
    ring = []
    for t in np.linspace(0, math.tau, 61)[:-1]:
        d = np.array((math.cos(t), 0, math.sin(t)))
        q, n = surf.cast(np.array((0, 0.38, 0)) + d * 2.5, -d, 0.03)
        ring.append(q if q is not None else d)
    ring = np.vstack([ring, ring[:1]])
    N = L.unit(ring - np.array((0, 0.38, 0)))
    N[:, 1] = 0
    N = L.unit(N)
    belt = L.strap(ring, N, 0.2, 0.035)
    belt.C = leather_colour(belt.V, None, np.zeros(len(belt.V)), 40) * 0.7
    # the skirt: one hide hanging from the waist, flaring off the thighs, folds deepening to the hem
    top, hem = 0.52, -2.05

    def place(u, v):
        y = top - v * (top - hem)
        W = 2.15 + 0.35 * v
        x = (u - 0.5) * W
        z = -0.86 - 0.2 * v ** 1.3 + 0.55 * (x / 1.3) ** 2 * (1 - 0.5 * v)
        return np.stack([x, y, z], 1)

    holes = [(0.3, 0.55, 0.018), (0.62, 0.72, 0.012), (0.77, 0.4, 0.014)]

    def keep(u, v):
        for cu, cv, r in holes:
            if ((u - cu) * 2.3) ** 2 + ((v - cv) * 2.57) ** 2 < r * r * 4:
                return False
        if u > 0.86 and v > 0.94 and (u - 0.86) * 1.2 > (1.0 - v) * 0.8:  # a torn corner
            return False
        return True

    sk = L.grid(48, 56, place, keep)
    sk.V = surf.outside(sk.V, None, 0.05)
    u, v = sk.UV[:, 0], sk.UV[:, 1]
    folds = (0.05 * np.sin(u * math.tau * 2.6 + 0.7) + 0.03 * np.sin(u * math.tau * 4.3 + 2.1)) * v ** 1.4
    sk.V[:, 2] += folds
    sk.V[:, 1] += -0.03 * np.sin(u * math.tau * 1.3) * v ** 2  # the hem not quite level
    L.orient_out(sk, lambda p: np.stack([np.zeros(len(p)), p[:, 1], np.full(len(p), 0.5)], 1))
    cav = sk.cavity(2)
    edge = S(0.015, 0.0, np.minimum.reduce([u, 1 - u, 1 - v]))
    C = leather_colour(sk.V, sk.N(), cav, 51, edge)
    C = mixc(C, CHAR, S(0.85, 1.0, v) * (0.5 + 0.4 * L.fbm(sk.V, 6, 2, 4)) * 0.7)  # scorched at the hem
    C = mixc(C, LEATHER_DARK * 0.4, S(0.15, 0.0, np.minimum(u, 1 - u)) * 0.5)  # greasy edges where hands wipe
    for cu, cv, r in holes:
        d = np.hypot((u - cu) * 2.3, (v - cv) * 2.57)
        C = mixc(C, CHAR, S(r * 3.2, r * 1.6, d) * 0.85)
    rng = rng0(14)
    for _ in range(7):
        cu, cv, r = rng.uniform(0.08, 0.92), rng.uniform(0.1, 0.95), rng.uniform(0.004, 0.008)
        d = np.hypot((u - cu) * 2.3, (v - cv) * 2.57)
        C = mixc(C, CHAR, S(r * 2.6, r * 1.2, d) * 0.7)
        C = mixc(C, (0.02, 0.015, 0.012), S(r, r * 0.6, d))
    sk.C = C
    skirt = L.slab(sk, 0.035, colour_rim=LEATHER_DARK * 0.5)
    # the waist thongs: from the skirt's top corners round the hips to a knot at the back, two ends hanging
    thongs = []
    for s in (1, -1):
        pts = [(s * 1.1, 0.5, -0.45), (s * 1.25, 0.5, 0.05), (s * 0.9, 0.52, 0.62), (s * 0.12, 0.5, 0.86)]
        P, N = snap(surf, L.smooth_path(pts, 24), 0.06, 2)
        thongs.append(L.strap(P, N, 0.06, 0.02))
    kp = snap(surf, [(0, 0.5, 0.95)], 0.08, 0)[0][0]
    knot = L.sphere(kp, 0.07, (1.3, 0.9, 0.8), seg=8, rings=6)
    for off, ln in ((-0.03, 0.45), (0.04, 0.33)):
        P, N = snap(surf, L.smooth_path([kp + (off, -0.03, 0.02), kp + (off * 2, -ln * 0.5, 0.0), kp + (off * 2.5, -ln, -0.02)], 10), 0.07, 0)
        thongs.append(L.strap(P, N, 0.05, 0.018))
    th = L.join(*thongs, knot)
    th.C = leather_colour(th.V, None, np.zeros(len(th.V)), 60) * 0.8
    # a wiping rag pushed under the belt at the left hip
    rp = snap(surf, [(-1.2, 0.36, 0.25)], 0.06, 0)[0][0]

    def rplace(u, w):
        return np.stack([rp[0] - 0.03 - 0.06 * w + 0.04 * np.sin(u * 9), rp[1] - w * 0.55, rp[2] + (u - 0.5) * (0.26 + 0.08 * w)], 1)

    rag = L.grid(8, 10, rplace)
    rag.V[:, 0] += 0.025 * np.sin(rag.UV[:, 0] * math.tau * 1.5) * rag.UV[:, 1]
    L.orient_out(rag, lambda p: np.tile(np.array((0, 0, 0)), (len(p), 1)))
    rag.C = mixc(np.tile(RAG * 0.8, (len(rag.V), 1)), SOOT, 0.5 + 0.2 * L.fbm(rag.V, 10, 2, 3))
    rag = L.slab(rag, 0.02)
    return L.join(hips, belt, skirt, th, rag)


# ------------------------------------------------------------------ arms
def arm_colour(m, burn, seed, hair_side):
    cav = m.cavity(2)
    C = soot_skin(m, cav, seed=seed, coverage=0.6)
    if hair_side is not None:  # forearm hair: a tone on the back of the forearm
        C = mixc(C, (0.08, 0.075, 0.07), S(0.0, 0.8, hair_side) * 0.35)
    if burn is not None:
        C = burn_paint(m, C, burn, cav)
    return C


def upperarm(side):
    """side: 'L' or 'R'. Bone frame: +X to the shoulder, -Z front, +Y the figure's left (outer for L)."""
    o = 1 if side == "L" else -1  # outer side along Y
    k = 1.0 if side == "L" else 1.06
    m = L.Meta(0.04)
    m.chain([(1.35, 0, 0.02), (0.4, 0, 0.0), (-0.6, 0, 0.0), (-1.25, 0, 0.02)], [0.42 * k, 0.4 * k, 0.34 * k, 0.3 * k])
    m.ell((-0.1, -o * 0.02, -0.17), (0.72 * k, 0.27 * k, 0.25 * k))  # biceps
    m.ell((0.3, o * 0.04, 0.2), (0.85 * k, 0.33 * k, 0.3 * k))  # triceps
    m.ell((0.45, o * 0.22, 0.05), (0.5, 0.18, 0.22))  # lateral head / deltoid insertion
    m.ball((-1.15, 0, 0.28), 0.13)  # elbow point
    a = m.mesh(0.022)
    a.smooth(it=3)
    surf = L.Surface(a)
    sp = lambda pts: snap(surf, L.smooth_path(pts, 20), 0.0, 0)[0]
    a.crease(sp([(0.9, o * 0.4, -0.05), (0.0, o * 0.42, 0.0), (-0.9, o * 0.4, 0.02)]), 0.06, 0.02, 0.4)  # biceps | triceps
    a.ridge(sp([(-1.05, o * 0.2, -0.33), (-0.3, o * 0.3, -0.3), (0.5, o * 0.36, -0.22)]), 0.035, 0.018)  # cephalic vein
    a.crease(sp([(-1.2, 0.2, -0.35), (-1.25, 0.0, -0.4), (-1.2, -0.2, -0.35)]), 0.04, 0.02, 0.5)  # inner elbow
    for dy in (-0.06, 0.02, 0.09):  # loose skin over the elbow
        a.crease(sp([(-1.12 + dy, -0.12, 0.38), (-1.1 + dy, 0.0, 0.42), (-1.12 + dy, 0.13, 0.38)]), 0.018, 0.008, 0.5)
    burn = None
    if side == "L":  # the burn runs down from the shoulder over the outer and back of the arm
        burn = np.maximum(a.ell((0.9, 0.35, 0.1), (0.7, 0.35, 0.5)), a.ell((0.2, 0.3, 0.3), (0.6, 0.3, 0.3)))
        burn = S(0.15, 0.55, burn * (1.0 + 0.7 * L.fbm(a.V, 3.0, 2, 23)))
        a.smooth(burn, it=5, lam=0.6)
        plaques(a, burn, rng0(41), 8, 0.18, 0.025)
        a.masks["burn"] = burn
    else:  # an old straight cut across the biceps
        a.ridge(sp([(0.1, -0.1, -0.45), (-0.2, -0.3, -0.38)]), 0.015, 0.008, key="cut")
    a.C = arm_colour(a, burn, 30 + o, None)
    if side == "R":
        a.C = mixc(a.C, SCAR * 0.8, a.masks["cut"] * 0.7)
    return a


def forearm(side):
    """Bone frame: +X to the elbow; the palm faces the body (inner side), the thumb side forward (-Z)."""
    o = 1 if side == "L" else -1
    k = 1.0 if side == "L" else 1.05
    m = L.Meta(0.035)
    m.chain([(1.3, 0, 0), (0.55, 0, -0.02), (-0.5, 0, 0), (-1.22, 0, 0)], [0.36 * k, 0.43 * k, 0.33 * k, 0.25 * k])
    m.ell((0.55, -o * 0.12, 0.0), (0.7, 0.26, 0.3))  # flexors, inner side
    m.ell((0.6, o * 0.1, -0.15), (0.65, 0.26, 0.26))  # brachioradialis, outer front
    m.ell((-1.05, o * 0.12, 0.15), (0.08, 0.06, 0.06))  # wrist bone
    f = m.mesh(0.02)
    f.smooth(it=3)
    surf = L.Surface(f)
    sp = lambda pts: snap(surf, L.smooth_path(pts, 20), 0.0, 0)[0]
    for dz in (-0.07, 0.0, 0.08):  # tendons at the inner wrist
        f.ridge(sp([(-0.5, -o * 0.27, dz), (-1.15, -o * 0.24, dz * 1.2)]), 0.025, 0.014)
    f.ridge(sp([(-1.15, o * 0.22, -0.05), (-0.5, o * 0.32, -0.1), (0.2, o * 0.38, -0.05), (0.9, o * 0.3, -0.12)]), 0.03, 0.018)
    f.ridge(sp([(-0.5, o * 0.32, -0.1), (-0.1, o * 0.25, 0.25), (0.6, o * 0.2, 0.3)]), 0.026, 0.014)  # veins
    f.crease(sp([(0.9, o * 0.36, -0.25), (0.2, o * 0.34, -0.28), (-0.6, o * 0.28, -0.22)]), 0.05, 0.015, 0.4)
    burn, extra = None, []
    if side == "L":
        burn = np.maximum(f.ell((-0.5, o * 0.3, 0.05), (0.8, 0.25, 0.35)), f.ell((0.3, o * 0.25, 0.25), (0.5, 0.2, 0.25)))
        burn = S(0.15, 0.55, burn * (1.0 + 0.7 * L.fbm(f.V, 3.5, 2, 29)))
        f.smooth(burn, it=5, lam=0.6)
        plaques(f, burn, rng0(43), 9, 0.16, 0.022)
        f.masks["burn"] = burn
    f.C = arm_colour(f, burn, 50 + o, S(0.0, 0.25, f.V[:, 1] * o) * S(-1.1, -0.6, f.V[:, 0]) * S(1.0, 0.6, f.V[:, 0]))
    if side == "R":  # a leather wrist strap with a buckle on the outer side, a keeper, stitched edges
        rings = []
        xs = np.linspace(-1.08, -0.78, 7)
        for x in xs:
            ring = []
            for t in np.linspace(0, math.tau, 33)[:-1]:
                d = np.array((0, math.cos(t), math.sin(t)))
                q, n = surf.cast(np.array((x, 0, 0)) + d * 1.2, -d, 0.035)
                ring.append(q if q is not None else d * 0.3)
            rings.append(ring)
        V = np.array([p for r in rings for p in r])
        F = []
        n = 32
        for i in range(len(xs) - 1):
            for j in range(n):
                a_, b_ = i * n + j, i * n + (j + 1) % n
                F += [(a_, b_ + n, b_), (a_, a_ + n, b_ + n)]
        band = Mesh(V, np.array(F))
        L.orient_out(band, lambda p: np.stack([p[:, 0], np.zeros(len(p)), np.zeros(len(p))], 1))
        x = band.V[:, 0]
        C = leather_colour(band.V, None, np.zeros(len(x)), 70) * 0.85
        arc = np.arctan2(band.V[:, 2], band.V[:, 1])
        C = mixc(C, STITCH, stitch_mask(np.minimum(x + 1.08, -0.78 - x), arc * 0.28, 0.03, 0.04))
        band.C = C
        band = L.slab(band, 0.025, colour_rim=LEATHER_DARK * 0.5)
        q, nrm = surf.cast(np.array((-0.93, o * 1.2, 0.0)), (0, -o, 0), 0.075)
        bk = buckle(q, np.array((1.0, 0, 0)), nrm, w=0.16, h=0.13)
        extra = [band, bk]
    return L.join(f, *extra)


def fist():
    """The left hand, clenched: palm toward the body (+X), the back outward (-X), thumb forward (-Z)."""
    m = L.Meta(0.03)
    m.ell((-0.06, 0.12, 0.0), (0.17, 0.3, 0.31))  # the back of the hand
    m.cap((-0.02, 0.5, 0.0), (-0.04, 0.2, 0.0), 0.26)  # wrist
    fingers = [(-0.27, 0.095, 0.0), (-0.09, 0.09, -0.01), (0.09, 0.085, 0.0), (0.25, 0.075, 0.04)]
    for z, r, dy in fingers:
        k0 = (-0.13, -0.2 + dy, z)
        k1 = (0.05, -0.43 + dy, z * 1.02)
        k2 = (0.22, -0.3 + dy, z * 1.02)
        k3 = (0.17, -0.14 + dy, z)
        m.ball(k0, r * 1.05)
        m.chain([k0, k1, k2, k3], [r, r * 0.92, r * 0.82, r * 0.75])
    m.chain([(0.1, 0.22, -0.2), (0.07, 0.0, -0.36), (0.02, -0.2, -0.36), (0.08, -0.32, -0.24)], [0.11, 0.095, 0.08, 0.07])  # thumb
    h = m.mesh(0.014)
    h.smooth(it=2)
    surf = L.Surface(h)
    sp = lambda pts, n=16: snap(surf, L.smooth_path(pts, n), 0.0, 0)[0]
    for z0, z1 in ((-0.27, -0.09), (-0.09, 0.09), (0.09, 0.25)):  # the gaps between the fingers
        zm = (z0 + z1) / 2
        h.crease(sp([(-0.14, -0.28, zm), (0.0, -0.45, zm), (0.14, -0.42, zm), (0.24, -0.25, zm)]), 0.025, 0.035, 0.8, key="gap")
    for z, r, dy in fingers:  # skin folds over each knuckle, the tendons on the back of the hand
        for k in (-0.03, 0.03):
            h.crease(sp([(-0.2, -0.22 + dy + k, z - 0.05), (-0.22, -0.22 + dy + k, z), (-0.2, -0.22 + dy + k, z + 0.05)], 6), 0.012, 0.006, 0.5)
        h.ridge(sp([(-0.2, 0.35, z * 0.5), (-0.21, 0.05, z * 0.8), (-0.19, -0.15 + dy, z)]), 0.022, 0.012)
    h.crease(sp([(0.05, 0.15, -0.28), (0.02, -0.05, -0.42), (0.0, -0.22, -0.43)]), 0.02, 0.02, 0.7, key="gap")  # thumb against the fist
    # the thumbnail
    tn = h.ell((0.0, -0.3, -0.3), (0.05, 0.06, 0.06))
    h.flatten(tn, 0.6)
    burn = S(0.15, 0.55, h.ell((-0.2, 0.25, 0.0), (0.15, 0.3, 0.3)) * (1 + 0.7 * L.fbm(h.V, 5, 2, 7)))
    plaques(h, burn, rng0(45), 5, 0.1, 0.012)
    cav = h.cavity(2)
    C = soot_skin(h, cav, seed=61, coverage=0.72, streaks=False)
    C = burn_paint(h, C, burn, cav)
    C = mixc(C, (0.03, 0.02, 0.018), h.masks["gap"] * 0.6)
    C = mixc(C, (0.33, 0.27, 0.2), tn * 0.7)  # nail, dirty
    # split knuckles: dry dark cracks, no blood
    for z, r, dy in fingers[:3]:
        d = np.linalg.norm(h.V - np.array((-0.2, -0.22 + dy, z)), axis=1)
        C = mixc(C, (0.06, 0.035, 0.03), S(0.035, 0.015, d) * 0.8)
    h.C = C
    return h


def shovel():
    """The right hand round the fireman's shovel: the hand grown over the shaft, the wooden shaft, the riveted
    socket and a pressed-steel blade with turned-up sides, its working face scoured and its edge worn thin."""
    m = L.Meta(0.03)
    m.ell((0.12, -0.05, 0.0), (0.12, 0.28, 0.2))  # the back of the hand, outward (+X)
    m.cap((0.06, 0.3, 0.0), (0.08, 0.05, 0.0), 0.2)  # wrist
    axis_x, axis_z = -0.08, 0.02
    Rr = 0.17
    for k, (y, r) in enumerate(((-0.02, 0.085), (-0.14, 0.085), (-0.26, 0.08), (-0.37, 0.07))):
        knuckle = np.array((0.07, y, -0.14))
        pts = [knuckle]
        for ang in np.radians(np.linspace(-50, -235, 6)):
            pts.append(np.array((axis_x + Rr * math.cos(ang), y - 0.01 * k, axis_z + Rr * math.sin(ang))))
        m.chain(pts, list(np.linspace(r, r * 0.75, len(pts))))
    m.chain([(0.08, 0.15, -0.13), (0.0, 0.0, -0.2), (-0.08, -0.06, -0.19), (-0.15, -0.04, -0.12)], [0.1, 0.09, 0.08, 0.065])  # thumb
    m.cap((axis_x, 0.25, axis_z), (axis_x, 0.0, axis_z), 0.14)  # flesh grown up the shaft
    m.cap((axis_x, -0.4, axis_z), (axis_x, -0.6, axis_z), 0.135)  # and down it
    h = m.mesh(0.014)
    h.smooth(it=2)
    surf = L.Surface(h)
    grown = np.maximum(S(0.0, 0.12, h.V[:, 1] - 0.0) * S(0.2, 0.12, np.hypot(h.V[:, 0] - axis_x, h.V[:, 2] - axis_z)),
                       S(-0.38, -0.5, h.V[:, 1]) * S(0.2, 0.12, np.hypot(h.V[:, 0] - axis_x, h.V[:, 2] - axis_z)))
    for y in (-0.08, -0.2, -0.32):  # gaps between the fingers round the shaft
        ring = [np.array((axis_x + 0.18 * math.cos(a), y, axis_z + 0.18 * math.sin(a))) for a in np.radians(np.linspace(-60, -230, 10))]
        h.crease(snap(surf, ring, 0.0, 0)[0], 0.02, 0.03, 0.8, key="gap")
    plaques(h, grown, rng0(47), 6, 0.08, 0.012)
    cav = h.cavity(2)
    C = soot_skin(h, cav, seed=63, coverage=0.72, streaks=False)
    C = burn_paint(h, C, np.maximum(grown, 0.0), cav)
    C = mixc(C, (0.03, 0.02, 0.018), h.masks["gap"] * 0.6)
    h.C = C
    # the shaft
    ys = np.linspace(0.2, -1.0, 24)
    shaft = L.tube(np.stack([np.full_like(ys, axis_x) + 0.004 * np.sin(ys * 7), ys, np.full_like(ys, axis_z)], 1), 0.085, sides=10)
    g = L.vnoise(shaft.V, 30, 5, stretch=(1, 0.06, 1))
    C = mixc(np.tile(WOOD, (len(shaft.V), 1)), WOOD * 0.5, S(-0.3, 0.6, g) * 0.6)
    C = mixc(C, CHAR, S(-0.6, -0.95, shaft.V[:, 1]) * 0.8)  # charred near the socket
    C = mixc(C, SOOT, 0.35)
    shaft.C = C
    # the socket: a tapered steel collar, flattened at the bottom into the strap riveted to the blade
    ys = np.linspace(-0.82, -1.18, 8)
    radii = np.linspace(0.1, 0.125, 8)
    sock = L.tube(np.stack([np.full_like(ys, axis_x), ys, np.full_like(ys, axis_z)], 1), radii, sides=10, flat=1.0)
    sock.V[:, 2] = np.where(sock.V[:, 1] < -1.05, axis_z + (sock.V[:, 2] - axis_z) * 0.55 + 0.03, sock.V[:, 2])
    sock.C = mixc(np.tile(IRON, (len(sock.V), 1)), RUST, S(-0.2, 0.5, L.vnoise(sock.V, 25, 7)) * 0.7)
    # the blade
    hw_heel, hw_mouth, y_heel, y_mouth = 0.62, 0.8, -1.1, -2.35

    def place(u, v):
        y = y_heel + (y_mouth - y_heel) * v
        hw = hw_heel + (hw_mouth - hw_heel) * v
        x = (u - 0.5) * 2 * hw
        edge = np.abs(u - 0.5) * 2
        z = axis_z + 0.06 - 0.16 * S(0.78, 1.0, edge) - 0.13 * S(0.12, 0.0, v) - 0.035 * (1 - edge ** 2) * S(0.0, 0.3, v)
        y = y + 0.06 * (1 - edge ** 2) * S(0.9, 1.0, v)  # the mouth worn hollow
        return np.stack([x + axis_x * 0, y, z], 1)

    chips = [(0.3, 0.012), (0.58, 0.01), (0.81, 0.014)]

    def keep(u, v):
        for cu, r in chips:
            if v > 0.97 and abs(u - cu) < r:
                return False
        return True

    bl = L.grid(32, 30, place, keep)
    for c, r, a in (((0.25, -1.75, 0), 0.12, 0.025), ((-0.3, -2.0, 0), 0.09, 0.02), ((0.05, -1.45, 0), 0.08, -0.015)):
        d = np.hypot(bl.V[:, 0] - c[0], bl.V[:, 1] - c[1]) / r
        bl.V[:, 2] += a * S(1.0, 0.0, d)  # dents
    L.orient_out(bl, lambda p: p + np.array((0, 0, 1.0)))
    u, v = bl.UV[:, 0], bl.UV[:, 1]
    scour = L.vnoise(bl.V, 18, 9, stretch=(1, 0.05, 1))
    C = mixc(np.tile(IRON, (len(bl.V), 1)), IRON_BRIGHT, S(0.2, 0.9, scour) * 0.35 + S(0.9, 1.0, v) * 0.5)
    C = mixc(C, RUST, S(0.82, 1.0, np.abs(u - 0.5) * 2) * 0.6 + S(0.15, 0.0, v) * 0.4)
    C = mixc(C, SOOT, 0.3)
    bl.C = C
    blade = L.slab(bl, 0.035, colour_back=RUST * 0.8, colour_rim=IRON_BRIGHT * 0.8)
    rivets = []
    for x in (axis_x - 0.06, axis_x + 0.06):
        rv = L.rivet((x, -1.14, axis_z + 0.07), (0, 0, 1), 0.026)
        rv.C = np.tile(IRON * 1.2, (len(rv.V), 1))
        rivets.append(rv)
    return L.join(h, shaft, sock, blade, *rivets)


# ------------------------------------------------------------------ legs
def thigh(side):
    """Trouser leg. Bone frame: +X to the hip, -Z front, +Y the figure's left; inner side is -Y for L."""
    o = 1 if side == "L" else -1
    m = L.Meta(0.04)
    m.chain([(1.15, 0, 0), (0.0, 0, -0.02), (-1.05, 0, -0.03)], [0.52, 0.48, 0.41])
    m.ell((-0.85, 0, -0.3), (0.25, 0.3, 0.18))  # the knee bagged out
    t = m.mesh(0.022)
    t.smooth(it=3)
    surf = L.Surface(t)
    sp = lambda pts: snap(surf, L.smooth_path(pts, 20), 0.0, 0)[0]
    rng = rng0(70 + o)
    for k in range(4):  # drape folds from the crotch down and outward
        x0 = 0.95 - k * 0.25
        t.crease(sp([(x0, -o * 0.45, -0.1), (x0 - 0.35, -o * 0.1, -0.45), (x0 - 0.6, o * 0.25, -0.38)]), 0.04, 0.02 + 0.008 * rng.random(), 0.5)
    for k in range(3):  # behind the knee
        x0 = -0.72 - k * 0.09
        t.crease(sp([(x0, -0.3, 0.3), (x0 - 0.03, 0.0, 0.4), (x0, 0.3, 0.3)]), 0.03, 0.022, 0.6)
    t.crease(sp([(1.1, o * 0.5, 0.0), (0.0, o * 0.48, 0.0), (-1.05, o * 0.41, 0.0)]), 0.02, 0.01, 0.6, key="seam")
    cav = t.cavity(2)
    P = t.V
    C = np.tile(MOLESKIN, (len(P), 1))
    C = mixc(C, MOLESKIN_DARK, np.clip(cav, 0, 1) * 0.8 + 0.15)
    C = mixc(C, MOLESKIN * 1.4, S(-0.1, -0.6, cav) * 0.4 + S(-0.4, -0.9, P[:, 0]) * S(-0.1, -0.4, P[:, 2]) * 0.3)
    C = mixc(C, SOOT, 0.35 + 0.15 * L.fbm(P, 8, 2, 3 + o))
    C = mixc(C, STITCH * 0.7, t.masks["seam"] * S(0.2, 0.5, np.sin(P[:, 0] * 120)) * 0.5)
    t.C = C
    extra = []
    if side == "L":  # a patch over the knee, sewn on with big stitches
        def place(u, w):
            x = -0.88 + 0.45 * w
            ang = (u - 0.5) * 1.4 - math.pi / 2
            P = np.zeros((len(u), 3))
            for i in range(len(u)):
                d = np.array((0, math.cos(ang[i]), math.sin(ang[i])))
                q, n = surf.cast(np.array((x[i], 0, 0)) + d * 1.5, -d, 0.012)
                if q is None:
                    q0, n0, _ = surf.nearest(np.array((x[i], 0, 0)) + d * 0.5)
                    q = q0 + n0 * 0.012
                P[i] = q
            return P

        pt = L.grid(10, 10, place)
        L.orient_out(pt, lambda p: np.stack([p[:, 0], np.zeros(len(p)), np.zeros(len(p))], 1))
        u, w = pt.UV[:, 0], pt.UV[:, 1]
        d_edge = np.minimum.reduce([u * 0.55, (1 - u) * 0.55, w * 0.5, (1 - w) * 0.5])
        C = np.tile(MOLESKIN * 0.75, (len(pt.V), 1))
        C = mixc(C, SOOT, 0.4 + 0.1 * L.fbm(pt.V, 9, 2, 8))
        C = mixc(C, STITCH, stitch_mask(d_edge, u * 0.55 + w * 0.5, 0.025, 0.05, 0.01) * 0.8)
        pt.C = C
        extra.append(L.slab(pt, 0.012))
    else:  # a tear on the outer thigh
        d = L.path_dist(P, sp([(0.3, o * 0.5, -0.1), (0.05, o * 0.5, -0.05)]))[0]
        t.inflate(S(0.03, 0.0, d), -0.03)
        t.C = mixc(t.C, (0.03, 0.025, 0.02), S(0.025, 0.008, d))
    return L.join(t, *extra)


def shin(side):
    """Trouser leg below the knee, bloused over the york (a strap on the right, a cord on the left), the hem
    frayed over the boot. +X to the knee."""
    o = 1 if side == "L" else -1
    m = L.Meta(0.04)
    m.chain([(0.98, 0, -0.02), (0.55, 0, 0.0), (0.42, 0, 0.0), (-0.95, 0, 0.0)], [0.42, 0.46, 0.36, 0.36])
    m.ell((0.68, 0, 0.0), (0.22, 0.47, 0.47))  # the blouse over the york
    s_ = m.mesh(0.02)
    s_.smooth(it=3)
    surf = L.Surface(s_)
    ring = lambda x, off: np.array([surf.cast(np.array((x, 0, 0)) + np.array((0, math.cos(t), math.sin(t))) * 1.2,
                                              -np.array((0, math.cos(t), math.sin(t))), off)[0] for t in np.linspace(0, math.tau, 41)])
    s_.crease(ring(0.45, 0.0), 0.05, 0.05, 0.6)  # the york pulls it in
    rng = rng0(80 + o)
    for k in range(7):  # fabric gathered above it
        t = rng.uniform(0, math.tau)
        d = np.array((0, math.cos(t), math.sin(t)))
        p0 = surf.cast(np.array((0.5, 0, 0)) + d * 1.2, -d, 0)[0]
        p1 = surf.cast(np.array((0.85, 0, 0)) + d * 1.2, -d, 0)[0]
        if p0 is not None and p1 is not None:
            s_.crease([p0, p1], 0.03, 0.02, 0.5)
    # frayed hem: the last band scalloped and pulled loose
    hem = S(-0.7, -0.92, s_.V[:, 0])
    s_.V[:, 0] -= hem * 0.04 * (0.5 + 0.5 * np.sin(np.arctan2(s_.V[:, 2], s_.V[:, 1]) * 9))
    cav = s_.cavity(2)
    P = s_.V
    C = np.tile(MOLESKIN, (len(P), 1))
    C = mixc(C, MOLESKIN_DARK, np.clip(cav, 0, 1) * 0.8 + 0.15)
    C = mixc(C, SOOT, 0.38 + 0.15 * L.fbm(P, 8, 2, 13 + o))
    C = mixc(C, (0.2, 0.17, 0.13), S(-0.3, -0.9, P[:, 0]) * 0.4)  # dust and mud low down
    s_.C = C
    rp = ring(0.45, 0.03)
    rp = np.vstack([rp, rp[:1]])
    N = L.unit(rp - np.stack([rp[:, 0], np.zeros(len(rp)), np.zeros(len(rp))], 1))
    if side == "R":
        york = L.strap(rp, N, 0.1, 0.03)
        york.C = leather_colour(york.V, None, np.zeros(len(york.V)), 90) * 0.85
        q, nrm = surf.cast(np.array((0.45, -1.2, 0.0)), (0, 1, 0), 0.06)
        bk = buckle(q, np.array((0, 0, 1.0)), nrm, w=0.11, h=0.1)
        parts = [york, bk]
    else:
        york = L.tube(rp, 0.022, sides=6, twist=1.2, cap=False)
        q = rp[np.argmax(rp[:, 1])]
        knot = L.sphere(q + (0, 0.03, 0), 0.04, (1, 1.2, 1), seg=8, rings=5)
        ends = [L.tube(np.array([q + (0, 0.03, 0), q + (-0.08, 0.06, -0.02), q + (-0.18, 0.05, -0.04)]), 0.016, sides=5),
                L.tube(np.array([q + (0, 0.03, 0), q + (-0.06, 0.05, 0.04), q + (-0.12, 0.06, 0.07)]), 0.016, sides=5)]
        parts = [york, knot] + ends
        for p in parts:
            p.C = mixc(np.tile(CORD, (len(p.V), 1)), SOOT, 0.45)
    return L.join(s_, *parts)


def boot(side):
    """Hobnailed ankle boot. Foot frame: ankle joint at y +0.275, sole at -0.275, toe forward (-Z)."""
    o = 1 if side == "L" else -1
    m = L.Meta(0.03)
    m.ell((0, -0.08, 0.36), (0.31, 0.2, 0.22))  # heel
    m.ell((0, -0.02, -0.08), (0.35, 0.23, 0.4))  # instep
    m.ell((o * 0.02, -0.11, -0.5), (0.33, 0.15, 0.24))  # blunt toe
    m.cap((0, -0.05, 0.16), (0, 0.48, 0.12), 0.31)  # the shaft up the ankle
    b = m.mesh(0.016)
    b.smooth(it=3)
    b.V[:, 1] = np.maximum(b.V[:, 1], -0.17)  # flat where it sits on the sole
    surf = L.Surface(b)
    sp = lambda pts, n=20: snap(surf, L.smooth_path(pts, n), 0.0, 0)[0]
    b.crease(sp([(-0.3, -0.08, -0.32), (0, 0.06, -0.36), (0.3, -0.08, -0.32)]), 0.02, 0.015, 0.6, key="seam")  # toe cap
    for k, z in enumerate((-0.22, -0.15, -0.08, -0.02)):  # flex creases across the vamp
        w = 0.24 - k * 0.02
        b.crease(sp([(-w, 0.06 + k * 0.02, z + 0.02), (0, 0.13 + k * 0.025, z), (w, 0.06 + k * 0.02, z + 0.03)], 10), 0.022, 0.016, 0.6)
    for s in (1, -1):  # quarter seams and the heel counter
        b.crease(sp([(s * 0.2, 0.3, -0.05), (s * 0.31, 0.05, 0.05), (s * 0.3, -0.12, 0.2)]), 0.018, 0.012, 0.6, key="seam")
    b.crease(sp([(-0.25, -0.1, 0.35), (0, 0.1, 0.56), (0.25, -0.1, 0.35)]), 0.02, 0.012, 0.6, key="seam")
    cav = b.cavity(2)
    P = b.V
    C = np.tile((0.07, 0.06, 0.055), (len(P), 1))
    C = mixc(C, (0.24, 0.17, 0.11), S(-0.1, -0.7, cav) * 0.6)  # worn brown on what sticks out
    C = mixc(C, (0.33, 0.31, 0.28), S(0.3, 0.9, b.N()[:, 1]) * 0.35 + 0.1)  # dust
    C = mixc(C, (0.02, 0.018, 0.015), np.clip(cav, 0, 1) * 0.7)
    C = mixc(C, STITCH * 0.6, b.masks["seam"] * S(0.2, 0.5, np.sin((P[:, 0] + P[:, 2]) * 140)) * 0.4)
    if side == "R":
        C = mixc(C, (0.36, 0.27, 0.18), S(0.15, 0.0, np.linalg.norm(P - np.array((0.1, -0.02, -0.6)), axis=1)) * 0.7)  # scuffed toe
    b.C = C
    # lacing up the front of the shaft: eyelets, hooks at the top, criss-crossed lace; the left one broken
    eyes_l, eyes_r = [], []
    for k, t in enumerate(np.linspace(0, 1, 7)):
        y = -0.0 + t * 0.45
        z = -0.18 + t * 0.12
        for s, lst in ((-1, eyes_l), (1, eyes_r)):
            q, n = surf.cast(np.array((s * 0.08, y, z - 1.0)), (0, 0, 1), 0.01)
            lst.append((q, n))
    parts = []
    for lst in (eyes_l, eyes_r):
        for k, (q, n) in enumerate(lst):
            if q is None:
                continue
            e = L.rivet(q, n, 0.022 if k < 5 else 0.018, 0.6)
            e.C = np.tile(IRON * 1.3, (len(e.V), 1))
            parts.append(e)
    top = 6 if side == "R" else 3
    lace = []
    for k in range(top):
        a, b_ = eyes_l[k][0], eyes_r[k + 1][0] if k + 1 < len(eyes_r) else None
        c, d = eyes_r[k][0], eyes_l[k + 1][0] if k + 1 < len(eyes_l) else None
        for p0, p1 in ((a, b_), (c, d)):
            if p0 is not None and p1 is not None:
                lace.append(L.tube(np.array([p0, (p0 + p1) / 2 + np.array((0, 0, -0.025)), p1]), 0.013, sides=5))
    if side == "L":  # broken: knotted at the third pair, a loose end hanging
        q = eyes_r[3][0]
        lace.append(L.sphere(q + (0, 0, -0.03), 0.03, seg=8, rings=5))
        lace.append(L.tube(np.array([q + (0, 0, -0.03), q + (0.05, -0.1, -0.06), q + (0.08, -0.22, -0.04)]), 0.012, sides=5))
    else:
        q = eyes_r[6][0]
        lace.append(L.sphere(q + (-0.05, 0.02, -0.03), 0.035, seg=8, rings=5))
    for p in lace:
        p.C = mixc(np.tile((0.12, 0.1, 0.08), (len(p.V), 1)), SOOT, 0.3)
    parts += lace
    # the sole: welt, thick sole and heel, hobnails round the edge and a heel iron
    def outline(t):
        z = 0.58 - t * 1.32
        hw = 0.34 * np.sqrt(np.clip(1 - ((z + 0.08) / 0.68) ** 2, 0.02, 1)) + 0.02
        return z, hw

    ring_pts = []
    for t in np.linspace(0, 1, 30):
        z, hw = outline(t)
        ring_pts.append((hw, z))
    poly = [(x, z) for x, z in ring_pts] + [(-x, z) for x, z in reversed(ring_pts)]
    rings = []
    for y, grow in ((-0.165, 1.0), (-0.19, 1.06), (-0.22, 1.06), (-0.275, 1.04)):
        rings.append([(x * grow + 0.02 * o * 0, y if not (z > 0.25 and y < -0.2) else y - 0.06, z * (1 + (grow - 1) * 0.3)) for x, z in poly])
    V = np.array([p for r in rings for p in r])
    n = len(poly)
    F = []
    for i in range(len(rings) - 1):
        for j in range(n):
            a_, b_ = i * n + j, i * n + (j + 1) % n
            F += [(a_, b_, b_ + n), (a_, b_ + n, a_ + n)]
    c_bot = len(V)
    V = np.vstack([V, [np.mean(V[-n:], axis=0)]])
    for j in range(n):
        F.append((c_bot, (len(rings) - 1) * n + (j + 1) % n, (len(rings) - 1) * n + j))
    sole = Mesh(V, np.array(F))
    L.orient_out(sole, lambda p: np.tile(np.array((0, -0.2, 0.0)), (len(p), 1)))
    sole.C = np.tile((0.1, 0.075, 0.055), (len(V), 1))
    sole.C[(V[:, 1] > -0.2)] = (0.2, 0.15, 0.1)  # the welt, lighter
    nails = []
    for j in range(0, n, 2):
        x, z = poly[j]
        y = -0.275 if z <= 0.25 else -0.335
        nl = L.sphere((x * 0.93, y - 0.008, z * 0.98), 0.022, (1, 0.5, 1), seg=6, rings=4)
        nails.append(nl)
    iron = L.tube(np.array([(0.25 * math.cos(a), -0.34, 0.42 + 0.17 * math.sin(a)) for a in np.linspace(-0.3, math.pi + 0.3, 12)]), 0.02, sides=5)
    nails.append(iron)
    for p in nails:
        p.C = mixc(np.tile(IRON * 1.4, (len(p.V), 1)), RUST, 0.3)
    return L.join(b, *parts, sole, *nails)
