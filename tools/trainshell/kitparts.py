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
