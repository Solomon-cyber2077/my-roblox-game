"""
The shared kit: meshes every carriage reuses (one MeshId each, so they instance), each built in
the local frame of the primitive it stands in for, so the runtime can put it on that part's CFrame.

  DoorLeafL/R  on a DoorPanel leaf (2.8 x 7.5 x 0.25), 0.04 further out so the panels slide clear
  Bogie        on the bogie bolster (2.4 x 1.2 x 9.6 at y -3)
  Wheel        on a Mansell tyre (cylinder 0.6 x 3.2, axle on local X)
"""

import math

from kit import Piece

LEAF_W, LEAF_H = 2.8, 7.5
LEAF_Z0, LEAF_Z1 = -0.08, 0.16  # local z of the leaf's back and face (panel centre at 0)


def door_leaf(name, meeting):
    """meeting = +1 if the leaf's meeting edge (where the two leaves close) is at +x."""
    planks = Piece(name, "Accent", "Planks")
    iron = Piece(name + "_iron", None, "Iron")
    brass = Piece(name + "_brass", None, "Brass")
    hw, hh = LEAF_W / 2, LEAF_H / 2
    zb, zf = LEAF_Z0, LEAF_Z1 - 0.06
    # the boarded field, with the glazing slit (0.7 x 2.2, centre y +1.2) cut as a hole
    wx0, wx1, wy0, wy1 = -0.35, 0.35, 1.2 - 1.1, 1.2 + 1.1
    for a, b in ((-hw, wx0), (wx1, hw)):
        planks.box_between((a, -hh, zb), (b, hh, zf))
    planks.box_between((wx0, -hh, zb), (wx1, wy0, zf))
    planks.box_between((wx0, wy1, zb), (wx1, hh, zf))
    # framing: stiles and rails stand 0.06 proud, with a moulded edge round the glass
    st = 0.3
    for a, b in ((-hw, -hw + st), (hw - st, hw)):
        planks.box_between((a, -hh, zf), (b, hh, LEAF_Z1))
    for ya, yb in ((-hh, -hh + 0.4), (-0.55, -0.2), (hh - 0.4, hh)):
        planks.box_between((-hw + st, ya, zf), (hw - st, yb, LEAF_Z1))
    for a, b, c, d in ((wx0 - 0.14, wy0 - 0.14, wx1 + 0.14, wy0), (wx0 - 0.14, wy1, wx1 + 0.14, wy1 + 0.14),
                       (wx0 - 0.14, wy0, wx0, wy1), (wx1, wy0, wx1 + 0.14, wy1)):
        planks.box_between((a, b, zf), (c, d, LEAF_Z1))
    # iron straps across the boards, riveted, and a kick plate
    for y in (-2.5, 2.95):
        iron.box_between((-hw + 0.05, y - 0.12, LEAF_Z1), (hw - 0.05, y + 0.12, LEAF_Z1 + 0.03))
        iron.rivets([(-hw + 0.25 + k * (LEAF_W - 0.5) / 5, y, LEAF_Z1 + 0.03) for k in range(6)], (0, 0, 1), 0.045, 0.03)
    iron.box_between((-hw + 0.05, -hh + 0.05, LEAF_Z1), (hw - 0.05, -hh + 0.36, LEAF_Z1 + 0.02))
    # brass pull bar near the meeting edge, at hand height (floor is local y -3.75)
    hx = meeting * (hw - 0.45)
    brass.box_between((hx - 0.05, -0.95, LEAF_Z1 + 0.06), (hx + 0.05, 0.35, LEAF_Z1 + 0.1))
    for y in (-0.85, 0.25):
        brass.box_between((hx - 0.06, y - 0.06, LEAF_Z1), (hx + 0.06, y + 0.06, LEAF_Z1 + 0.08))
    planks.bevel = (0.02, 1, 40)
    return [planks, iron, brass]


def bogie(name):
    iron = Piece(name, None, "Iron")
    # bolster across the middle, with the centre casting on top
    iron.box_between((-1.2, -3.55, -4.8), (1.2, -2.45, 4.8))
    iron.lathe([(0.9, 0), (0.9, 0.18), (0.7, 0.26), (0, 0.26)], (0, -2.45, 0), "y", 12)
    for side in (-1, 1):
        zi, zo = side * 6.0, side * 6.3
        # the plate side frame, its ends swept up, with a flange along the top
        prof = [(-3.6, -3.35), (-3.0, -3.85), (3.0, -3.85), (3.6, -3.35), (3.6, -2.78), (-3.6, -2.78)]
        iron.prism_z(prof, min(zi, zo), max(zi, zo))
        iron.box_between((-3.6, -2.86, min(zi, side * 6.42)), (3.6, -2.74, max(zi, side * 6.42)))
        for ax in (-2.1, 2.1):
            # horn guides either side of the axlebox
            for gx in (ax - 0.5, ax + 0.5):
                iron.box_between((gx - 0.08, -4.1, min(side * 6.28, side * 6.42)), (gx + 0.08, -2.9, max(side * 6.28, side * 6.42)))
            # the axlebox and its domed lid
            iron.box_between((ax - 0.4, -4.05, min(side * 6.25, side * 6.58)), (ax + 0.4, -3.2, max(side * 6.25, side * 6.58)))
            lid = [(0.26, 0), (0.26, 0.05), (0.16, 0.09), (0.0, 0.1)]
            iron.lathe([(r, side * h) for r, h in lid], (ax, -3.62, side * 6.58), "z", 10)
            # a leaf spring over the box: five leaves, each shorter than the one above
            for k in range(5):
                half = 0.95 - k * 0.15
                y = -2.93 - k * 0.07
                iron.box_between((ax - half, y - 0.035, min(side * 6.42, side * 6.62)), (ax + half, y + 0.035, max(side * 6.42, side * 6.62)))
            # spring hangers
            for hx in (ax - 0.95, ax + 0.95):
                iron.box_between((hx - 0.05, -3.0, min(side * 6.44, side * 6.6)), (hx + 0.05, -2.8, max(side * 6.44, side * 6.6)))
            # brake blocks on the treads, inside the frame
            for bx in (ax - 1.72, ax + 1.72):
                if abs(bx) > 3.5:
                    continue
                iron.box_between((bx - 0.12, -4.0, min(side * 5.05, side * 5.55)), (bx + 0.12, -3.2, max(side * 5.05, side * 5.55)))
                iron.box_between((bx - 0.04, -3.2, min(side * 5.25, side * 5.35)), (bx + 0.04, -2.9, max(side * 5.25, side * 5.35)))
    iron.bevel = (0.02, 1, 40)
    return [iron]


def wheel(name):
    """Mansell wheel: iron tyre, sixteen teak segments (as faceted wedges), iron boss and bolts."""
    tyre = Piece(name, None, "Iron")
    teak = Piece(name + "_teak", None, "Teak")
    segs = 24
    # tyre with a flange: lathe about local X (profile r vs x)
    tyre.lathe([(1.25, -0.3), (1.6, -0.3), (1.6, 0.18), (1.74, 0.24), (1.74, 0.3), (1.25, 0.3), (1.25, -0.3)], (0, 0, 0), "x", segs, caps=False)
    # teak centre: a disc slightly inside the tyre, its faces carry the segment pattern in the texture
    teak.lathe([(0.0, -0.26), (1.27, -0.26), (1.27, 0.26), (0.0, 0.26)], (0, 0, 0), "x", 16)
    # boss and hub
    tyre.lathe([(0.0, -0.42), (0.42, -0.42), (0.42, 0.42), (0.0, 0.42)], (0, 0, 0), "x", 10)
    # bolts round the tyre's inner edge, both faces
    pts = []
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        for sx in (-1, 1):
            pts.append(((sx * 0.27, 1.12 * math.cos(a), 1.12 * math.sin(a)), (sx, 0, 0)))
    for p, ax in pts:
        tyre.rivets([p], ax, 0.07, 0.04, 6)
    return [tyre, teak]


# -- round 2 -------------------------------------------------------------------------------------
# The leaves keep their envelope (local z -0.08..0.16, so 6.66..6.90 on the car) and get real joinery:
# framed and braced boards, a beaded glazing light, strap hinges with bolts, a kick plate, and a
# flush brass pull with a backplate (a sliding door's pull sits in the leaf, it never sticks out).


def door_leaf2(name, meeting):
    planks = Piece(name, "Accent", "Planks")
    iron = Piece(name + "_iron", None, "Iron")
    brass = Piece(name + "_brass", None, "Brass")
    hw, hh = LEAF_W / 2, LEAF_H / 2
    zb, zf, zt = LEAF_Z0, LEAF_Z1 - 0.07, LEAF_Z1
    wx0, wx1, wy0, wy1 = -0.35, 0.35, 0.1, 2.3  # the glass slit the old leaf had (y local)
    # boards (recessed field) round the light
    for a, b in ((-hw, wx0), (wx1, hw)):
        planks.box_between((a, -hh, zb), (b, hh, zf))
    planks.box_between((wx0, -hh, zb), (wx1, wy0, zf))
    planks.box_between((wx0, wy1, zb), (wx1, hh, zf))
    st = 0.32
    # stiles and three rails, proud of the boards
    for a, b in ((-hw, -hw + st), (hw - st, hw)):
        planks.box_between((a, -hh, zf), (b, hh, zt))
    for ya, yb in ((-hh, -hh + 0.5), (-0.62, -0.22), (hh - 0.42, hh)):
        planks.box_between((-hw + st, ya, zf), (hw - st, yb, zt))
    # a diagonal brace in the lower field (ledged, braced and framed)
    dx0, dy0, dx1, dy1 = -hw + st, -hh + 0.5, hw - st, -0.62
    ang = math.atan2(dy1 - dy0, dx1 - dx0)
    if meeting < 0:
        dx0, dx1 = dx1, dx0
        ang = math.atan2(dy1 - dy0, dx1 - dx0)
    w = 0.13
    nx, ny = -math.sin(ang) * w, math.cos(ang) * w
    prof = [(dx0 - nx, dy0 - ny), (dx1 - nx, dy1 - ny), (dx1 + nx, dy1 + ny), (dx0 + nx, dy0 + ny)]
    if meeting < 0:
        prof.reverse()
    planks.prism_z(prof, zf - 0.01, zt - 0.02)
    # the light: a moulded frame round the glass with a brass bead
    for a, b, c, d in ((wx0 - 0.16, wy0 - 0.16, wx1 + 0.16, wy0), (wx0 - 0.16, wy1, wx1 + 0.16, wy1 + 0.16),
                       (wx0 - 0.16, wy0, wx0, wy1), (wx1, wy0, wx1 + 0.16, wy1)):
        planks.box_between((a, b, zf), (c, d, zt + 0.01))
    brass.box_between((wx0 - 0.03, wy0 - 0.03, zt - 0.06), (wx1 + 0.03, wy0, zt - 0.02))
    brass.box_between((wx0 - 0.03, wy1, zt - 0.06), (wx1 + 0.03, wy1 + 0.03, zt - 0.02))
    brass.box_between((wx0 - 0.03, wy0, zt - 0.06), (wx0, wy1, zt - 0.02))
    brass.box_between((wx1, wy0, zt - 0.06), (wx1 + 0.03, wy1, zt - 0.02))
    # strap hinges on the outer stile side: tapered straps with bolt heads
    ox = -meeting * hw
    for y in (-2.55, 2.85):
        L = 1.7
        tip = ox + meeting * L
        pts = [(ox, y - 0.11), (tip - meeting * 0.25, y - 0.06), (tip, y), (tip - meeting * 0.25, y + 0.06), (ox, y + 0.11)]
        if meeting < 0:
            pts.reverse()
        iron.prism_z(pts, zt, zt + 0.025)
        iron.rivets([(ox + meeting * (0.15 + k * 0.38), y, zt + 0.025) for k in range(4)], (0, 0, 1), 0.04, 0.025)
    # kick plate, riveted
    iron.box_between((-hw + 0.06, -hh + 0.04, zt), (hw - 0.06, -hh + 0.42, zt + 0.02))
    iron.rivets([(-hw + 0.2 + k * (LEAF_W - 0.4) / 6, -hh + 0.23, zt + 0.02) for k in range(7)], (0, 0, 1), 0.035, 0.02)
    # flush pull near the meeting edge at hand height: brass backplate, a dark cup, a grip bar inside
    hx = meeting * (hw - 0.17)
    brass.box_between((hx - 0.1, -1.05, zt), (hx + 0.1, 0.25, zt + 0.02))
    brass.box_between((hx - 0.06, -0.75, zt - 0.05), (hx + 0.06, -0.05, zt + 0.0))
    brass.box_between((hx - 0.02, -0.7, zt - 0.03), (hx + 0.02, -0.1, zt + 0.015))
    brass.rivets([(hx, y, zt + 0.02) for y in (-0.95, 0.15)], (0, 0, 1), 0.025, 0.015, 6)
    return [planks, iron, brass]


def bogie2(name):
    """The bogie at about half the triangles: what shows under the skirt kept, the rest simplified."""
    iron = Piece(name, None, "Iron")
    iron.box_between((-1.2, -3.55, -4.8), (1.2, -2.45, 4.8))
    iron.lathe([(0.9, 0), (0.9, 0.18), (0.0, 0.26)], (0, -2.45, 0), "y", 8)
    for side in (-1, 1):
        zi, zo = side * 6.0, side * 6.3
        prof = [(-3.6, -3.35), (-3.0, -3.85), (3.0, -3.85), (3.6, -3.35), (3.6, -2.78), (-3.6, -2.78)]
        iron.prism_z(prof, min(zi, zo), max(zi, zo))
        iron.box_between((-3.6, -2.86, min(zi, side * 6.42)), (3.6, -2.74, max(zi, side * 6.42)))
        for ax in (-2.1, 2.1):
            for gx in (ax - 0.5, ax + 0.5):
                iron.box_between((gx - 0.08, -4.1, min(side * 6.28, side * 6.42)), (gx + 0.08, -2.9, max(side * 6.28, side * 6.42)))
            iron.box_between((ax - 0.4, -4.05, min(side * 6.25, side * 6.58)), (ax + 0.4, -3.2, max(side * 6.25, side * 6.58)))
            iron.lathe([(0.26, 0), (0.2, side * 0.06), (0.0, side * 0.1)], (ax, -3.62, side * 6.58), "z", 8)
            for k in range(3):
                half = 0.95 - k * 0.22
                y = -2.94 - k * 0.09
                iron.box_between((ax - half, y - 0.045, min(side * 6.42, side * 6.62)), (ax + half, y + 0.045, max(side * 6.42, side * 6.62)))
            for hx in (ax - 0.95, ax + 0.95):
                iron.box_between((hx - 0.05, -3.0, min(side * 6.44, side * 6.6)), (hx + 0.05, -2.8, max(side * 6.44, side * 6.6)))
    return [iron]


# -- round 3 -------------------------------------------------------------------------------------
# The Mansell wheel at ~60% of the triangles: the tyre's bore (hidden by the teak) and the bolts on
# the face nobody sees go, the round parts drop segments (the skirt hides the top third anyway).


def wheel3(name):
    tyre = Piece(name, None, "Iron")
    teak = Piece(name + "_teak", None, "Teak")
    segs = 18
    tyre.lathe([(1.25, -0.3), (1.6, -0.3), (1.6, 0.18), (1.74, 0.24), (1.74, 0.3), (1.25, 0.3)], (0, 0, 0), "x", segs, caps=False)
    teak.lathe([(0.0, -0.26), (1.27, -0.26), (1.27, 0.26), (0.0, 0.26)], (0, 0, 0), "x", 12)
    tyre.lathe([(0.0, -0.42), (0.42, -0.42), (0.42, 0.42), (0.0, 0.42)], (0, 0, 0), "x", 8)
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        for sx in (-1, 1):
            tyre.rivets([(sx * 0.27, 1.1 * math.cos(a), 1.1 * math.sin(a))], (sx, 0, 0), 0.08, 0.04, 4)
    return [tyre, teak]


def drive_wheel(name, r=2.8, width=0.7):
    """A locomotive driving wheel on a cylinder primitive (axle on local X, radius r): flanged tyre,
    rim, fourteen tapered spokes, a crescent balance weight and a hub with its axle cap."""
    iron = Piece(name, None, "Iron")
    hw = width / 2
    segs = 28
    # tyre and flange (the flange on the inner face, local -X is towards the track centre on +Z)
    iron.lathe([(r - 0.42, -hw), (r - 0.05, -hw), (r, -hw + 0.06), (r, hw - 0.18), (r + 0.16, hw - 0.1), (r + 0.16, hw), (r - 0.42, hw)], (0, 0, 0), "x", segs, caps=False)
    # rim: a ring inside the tyre, a little narrower, with a bead on each face
    ri = r - 0.68
    iron.lathe([(ri, -hw + 0.1), (r - 0.42, -hw + 0.1), (r - 0.42, hw - 0.1), (ri, hw - 0.1), (ri, -hw + 0.1)], (0, 0, 0), "x", segs, caps=False)
    # spokes: tapered, thicker at the hub, oval-ish (two bevels)
    n = 14
    for k in range(n):
        a = 2 * math.pi * k / n
        ca, sa = math.cos(a), math.sin(a)
        ux, uy = -sa, ca  # across
        r0, r1 = 0.62, ri + 0.04
        w0, w1 = 0.15, 0.09
        prof = [(ca * r0 - ux * w0, sa * r0 - uy * w0), (ca * r1 - ux * w1, sa * r1 - uy * w1),
                (ca * r1 + ux * w1, sa * r1 + uy * w1), (ca * r0 + ux * w0, sa * r0 + uy * w0)]
        # prism_x takes (y, z)
        iron.prism_x([(py, pz) for py, pz in prof], -0.16, 0.16)
    # balance weight: a crescent filling the spokes opposite the crank
    arc = []
    m = 9
    for j in range(m + 1):
        t = -0.9 + 1.8 * j / m
        arc.append((math.cos(math.pi + t) * (ri - 0.02), math.sin(math.pi + t) * (ri - 0.02)))
    inner = []
    for j in range(m + 1):
        t = 0.75 - 1.5 * j / m
        inner.append((math.cos(math.pi + t) * (ri - 0.9), math.sin(math.pi + t) * (ri - 0.9)))
    iron.prism_x([(py, pz) for py, pz in arc + inner], -0.2, 0.2)
    # hub and axle cap, with six nuts on the outer face
    iron.lathe([(0.0, -0.36), (0.5, -0.36), (0.72, -0.3), (0.72, 0.3), (0.0, 0.3)], (0, 0, 0), "x", 14)
    # the hub's outer face is local -X (the platform side's wheels; mirror() makes the far side's)
    iron.lathe([(0.0, -0.56), (0.32, -0.5), (0.32, -0.36), (0.0, -0.36)], (0, 0, 0), "x", 10)
    iron.rivets([(-0.36, 0.5 * math.cos(2 * math.pi * k / 6), 0.5 * math.sin(2 * math.pi * k / 6)) for k in range(6)], (-1, 0, 0), 0.07, 0.06, 6)
    return [iron]


def coupling_rod(name, length=10.2, h=0.45, t=0.3):
    """The coupling rod on its block primitive (length on local X): an I-section rod with bossed
    ends, bronze bushes and crank pins with collars."""
    iron = Piece(name, None, "Iron")
    brass = Piece(name + "_brass", None, "Brass")
    half = length / 2 - 0.45
    # the rod: flanged edges with a fluted web (front face recessed)
    iron.box_between((-half, -h / 2, -t / 2), (half, -h / 2 + 0.1, t / 2))
    iron.box_between((-half, h / 2 - 0.1, -t / 2), (half, h / 2, t / 2))
    iron.box_between((-half, -h / 2 + 0.1, -t / 2), (half, h / 2 - 0.1, t / 2 - 0.08))
    for ex in (-1, 1):
        cx = ex * (length / 2 - 0.45)
        iron.lathe([(0.0, -t / 2), (0.46, -t / 2), (0.46, t / 2), (0.0, t / 2)], (cx, 0, 0), "z", 16)
        brass.lathe([(0.0, t / 2), (0.24, t / 2), (0.24, t / 2 + 0.04), (0.0, t / 2 + 0.04)], (cx, 0, 0), "z", 10)
        iron.lathe([(0.0, t / 2 + 0.04), (0.14, t / 2 + 0.04), (0.14, t / 2 + 0.22), (0.2, t / 2 + 0.24), (0.2, t / 2 + 0.3), (0.0, t / 2 + 0.32)], (cx, 0, 0), "z", 8)
        # oil cup on top of the boss
        brass.lathe([(0.0, 0.0), (0.08, 0.0), (0.1, 0.12), (0.06, 0.16), (0.0, 0.17)], (cx, 0.44, 0), "y", 8)
    return [iron, brass]


def coal_lump(name, seed=7):
    """A heap of coal lumps for a unit-diameter Ball (the runtime scales it to each CoalTier ball):
    a faceted mound of angular lumps, flat-bottomed where the bunker hides it."""
    import random

    rnd = random.Random(seed)
    coal = Piece(name, None, "Coal")
    # the mound: a low-poly dome with jittered verts
    rings, segs = 5, 11
    pts = []
    for i in range(rings + 1):
        phi = (math.pi / 2) * i / rings
        row = []
        for k in range(segs):
            th = 2 * math.pi * (k + 0.5 * (i % 2)) / segs
            rr = 0.5 * math.cos(phi) * rnd.uniform(0.86, 1.06)
            yy = 0.5 * math.sin(phi) * rnd.uniform(0.82, 1.04) - 0.02
            row.append((rr * math.cos(th), yy, rr * math.sin(th)))
        pts.append(row)
    from kit import V

    bm = coal.bm
    vs = [[bm.verts.new(V(*p)) for p in row] for row in pts]
    for i in range(rings):
        for k in range(segs):
            a, b = vs[i][k], vs[i][(k + 1) % segs]
            c, d = vs[i + 1][(k + 1) % segs], vs[i + 1][k]
            bm.faces.new((a, b, c, d))
    bm.faces.new(list(reversed(vs[0])))
    # lumps on top: little irregular octahedra poking out of the mound
    for _ in range(22):
        th = rnd.uniform(0, 2 * math.pi)
        phi = rnd.uniform(0.15, 1.35)
        cx, cy, cz = 0.47 * math.cos(phi) * math.cos(th), 0.45 * math.sin(phi) - 0.02, 0.47 * math.cos(phi) * math.sin(th)
        s = rnd.uniform(0.06, 0.13)
        ax = [(s * rnd.uniform(0.7, 1.3), 0, 0), (-s * rnd.uniform(0.7, 1.3), 0, 0), (0, s * rnd.uniform(0.6, 1.2), 0),
              (0, -s * rnd.uniform(0.4, 0.8), 0), (0, 0, s * rnd.uniform(0.7, 1.3)), (0, 0, -s * rnd.uniform(0.7, 1.3))]
        v = [bm.verts.new(V(cx + dx, cy + dy, cz + dz)) for dx, dy, dz in ax]
        for f in ((0, 2, 4), (4, 2, 1), (1, 2, 5), (5, 2, 0), (4, 3, 0), (1, 3, 4), (5, 3, 1), (0, 3, 5)):
            bm.faces.new([v[j] for j in f])
    return [coal]


def mirror(pieces, axis):
    """Mirror pieces through their local origin along a Roblox axis ("x" or "z")."""
    import bmesh

    vec = (-1, 1, 1) if axis == "x" else (1, -1, 1)  # Blender (x, y, z) = Roblox (x, -z, y)
    for p in pieces:
        bmesh.ops.scale(p.bm, vec=vec, verts=p.bm.verts)
        bmesh.ops.reverse_faces(p.bm, faces=p.bm.faces)
    return pieces
