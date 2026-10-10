"""
Each carriage's own identity on top of the shared trim language (carriage2.py calls add() once the
shared body is built). Everything here keeps the envelope: nothing beyond |z| 6.92, nothing proud of
6.64 in a door's slide zone below y 7.5; collision stays on the primitives.

  LastTrainOut  the namesake: a painted crest in a garter on each side, double gilt lining and
                ornaments in every panel (canvas.py), the flagship name board (make_sign2.py)
  Workshop      diagonal bracing irons, a pipe run under the solebar, a tool rack by the end, a
                tarped load lashed on the roof, a louvred vent and a forge stovepipe with a spark
                arrester (soot and spark scorch round them), heavily braced sliding doors
  Stores        security straps across the boards, crates and barrels strapped in a cradle on the
                blind end and lashed on the roof, stencilled lettering (canvas.py), heavy sliding
                doors with a hasp and padlock
  GuardsVan     a lookout cupola with windows, the veranda's canopy, columns and balustrade, the
                hand-brake standard and wheel, tail lanterns

Wear causes go into spec["feat"] (canvas.py and bake2.py paint them).
"""

import math

from kit import Piece, V, rect_outline

SKIN = 6.58
TOP = 8.85
LOWER = (0.34, 2.68)
UPPER = (3.62, 6.84)
WIN_W = 3.36
LEAF_Y, LEAF_Z = 3.75, 6.74


def add(spec, P, C):
    for k in ("crests", "stencils", "scorch"):
        C.feat.setdefault(k, [])
    fn = globals().get(spec["name"])
    return fn(spec, P, C) or [] if fn else []


# -- helpers -------------------------------------------------------------------------------------


def free_spans(spec, C, side, margin=0.4):
    """Stretches of a side's wall clear of the doors' slide zones, the windows and the grab rails."""
    x0, x1 = spec["x0"], spec["x1"]
    spans = [(x0 + 1.05, x1 - 1.05)]

    def minus(spans, a, b):
        out = []
        for fa, fb in spans:
            if fa < a:
                out.append((fa, min(fb, a)))
            if fb > b:
                out.append((max(fa, b), fb))
        return [(p, q) for p, q in out if q - p > 0.2]

    for d in C.doors(side):
        spans = minus(spans, d - 5.56 - 0.3 - margin, d + 5.56 + 0.3 + margin)
    for w in C.windows(side):
        spans = minus(spans, w - WIN_W / 2 - 0.62 - margin, w + WIN_W / 2 + 0.62 + margin)
    return spans


def strap(piece, feat, side, xa, xb, y, h, z0, z1, rivets=6):
    """A riveted iron flat across the side at height y."""
    piece.box_between((xa, y - h / 2, side * z0), (xb, y + h / 2, side * z1))
    pts = [(xa + 0.12 + k * (xb - xa - 0.24) / max(1, rivets - 1), y) for k in range(rivets)]
    piece.rivets([(x, yy, side * z1) for x, yy in pts], (0, 0, side), 0.045, 0.022, 6)
    feat["rivets"] += [{"side": side, "x": x, "y": yy} for x, yy in pts]
    feat["ledges"].append({"side": side, "x": [xa, xb], "y": y - h / 2, "iron": True})


def lashing(piece, path_pts, w=0.06):
    """A rope or band over a load: a flat strip along a path (Roblox points, roughly in an XY or YZ plane)."""
    for a, b in zip(path_pts[:-1], path_pts[1:]):
        piece.box_between((min(a[0], b[0]) - w, min(a[1], b[1]) - 0.02, min(a[2], b[2]) - 0.02),
                          (max(a[0], b[0]) + w, max(a[1], b[1]) + 0.02, max(a[2], b[2]) + 0.02))


def barrel(crate, fit, c, r, h, axis="y", segs=12):
    """A coopered barrel (bulged staves) with three iron hoops."""
    prof = [(r * 0.86, -h / 2), (r * 0.96, -h * 0.3), (r, 0.0), (r * 0.96, h * 0.3), (r * 0.86, h / 2), (0.0, h / 2)]
    crate.lathe([(0.0, -h / 2)] + prof, c, axis, segs)
    for t, rr in ((-0.38, 0.89), (0.0, 1.0), (0.38, 0.89)):
        o = [(r * rr + 0.012, h * t - 0.05), (r * rr + 0.012, h * t + 0.05)]
        fit.lathe(o, c, axis, segs, caps=False)


def crate_box(crate, fit, a, b, bands=True):
    """A boarded crate with corner battens and two iron bands."""
    crate.box_between(a, b)
    (x0, y0, z0), (x1, y1, z1) = [min(a[i], b[i]) for i in range(3)], [max(a[i], b[i]) for i in range(3)]
    t = 0.05
    for x in (x0, x1 - 0.12):
        for z in (z0, z1 - 0.12):
            crate.box_between((x - t, y0, z - t), (x + 0.12 + t, y1 + t, z + 0.12 + t))
    if bands:
        for f in (0.28, 0.72):
            x = x0 + (x1 - x0) * f
            fit.box_between((x - 0.05, y0 - 0.01, z0 - 0.02), (x + 0.05, y1 + 0.02, z1 + 0.02))


# -- heavy sliding door leaves (Workshop, Stores) ----------------------------------------------


def heavy_leaves(spec, P, C, kind):
    """Car-specific leaves in train space at the closed position, painted in the car's platform-side
    atlas. The runtime drops them on the DoorPanel leaves' CFrames like the kit's (anchor = panel
    centre) and moves DoorSlide onto them. Face at 6.86, hardware to 6.92 at most."""
    name = spec["name"]
    feat = C.feat
    out, joins, anchors = [], {}, {}
    d = C.doors(1)[0]
    zb, zf, zt = 6.66, 6.78, 6.86
    hw, hh = 1.4, 3.75
    for key, cx, meeting in (("DoorLeafL", d - hw, 1), ("DoorLeafR", d + hw, -1)):
        pn = f"{name}_{key}"
        planks = Piece(pn, "Accent", "Planks")
        iron = Piece(pn + "_iron", None, "Iron")
        brass = Piece(pn + "_brass", None, "Brass")

        def B(pc, xa, ya, za, xb, yb, zz):
            pc.box_between((cx + xa, LEAF_Y + ya, za), (cx + xb, LEAF_Y + yb, zz))

        st = 0.36
        B(planks, -hw, -hh, zb, hw, hh, zf)  # the boarded field
        for a, b in ((-hw, -hw + st), (hw - st, hw)):
            B(planks, a, -hh, zf, b, hh, zt)
        rails = ((-hh, -hh + 0.55), (-0.45, 0.05), (hh - 0.5, hh))
        for ya, yb in rails:
            B(planks, -hw + st, ya, zf, hw - st, yb, zt)

        def brace(ya, yb, flip):
            xa, xb = -hw + st, hw - st
            if flip:
                xa, xb = xb, xa
            ang = math.atan2(yb - ya, xb - xa)
            w = 0.14
            nx, ny = -math.sin(ang) * w, math.cos(ang) * w
            prof = [(cx + xa - nx, LEAF_Y + ya - ny), (cx + xb - nx, LEAF_Y + yb - ny), (cx + xb + nx, LEAF_Y + yb + ny), (cx + xa + nx, LEAF_Y + ya + ny)]
            if xb < xa:
                prof.reverse()
            planks.prism_z(prof, zf - 0.01, zt - 0.015)

        lo, mid, hi = -hh + 0.55, -0.45, hh - 0.5
        if kind == "braced":
            # ledged, framed and double-braced: an X in the lower field, a diagonal above
            brace(lo, mid, False)
            brace(lo, mid, True)
            brace(0.05, hi, meeting < 0)
            strap_y = (-2.15, 1.75)
        else:
            # boarded and braced: a single diagonal in each field, three heavy straps
            brace(lo, mid, meeting < 0)
            brace(0.05, hi, meeting < 0)
            strap_y = (-2.75, -0.2, 2.55)
        sh = 0.26 if kind == "braced" else 0.3
        for y in strap_y:
            iron.box_between((cx - hw + 0.04, LEAF_Y + y - sh / 2, zt), (cx + hw - 0.04, LEAF_Y + y + sh / 2, zt + 0.03))
            pts = [(cx - hw + 0.2 + k * (2 * hw - 0.4) / 6, LEAF_Y + y) for k in range(7)]
            iron.rivets([(x, yy, zt + 0.03) for x, yy in pts], (0, 0, 1), 0.045, 0.025, 6)
            feat["rivets"] += [{"side": 1, "x": x, "y": yy} for x, yy in pts]
            feat["ledges"].append({"side": 1, "x": [cx - hw, cx + hw], "y": LEAF_Y + y - sh / 2, "iron": True})
            # the strap wraps the outer stile as a hinge knuckle
            ox = cx - meeting * (hw - 0.05)
            iron.cylinder((ox, LEAF_Y + y, 6.85), "y", 0.06, sh + 0.06, 8)
        # iron corner plates on the meeting edge, and a kick plate
        for y in (-hh + 0.04, hh - 0.5):
            mx = cx + meeting * (hw - 0.25)
            iron.box_between((mx - 0.22, LEAF_Y + y, zt), (mx + 0.22, LEAF_Y + y + 0.46, zt + 0.02))
        iron.box_between((cx - hw + 0.05, LEAF_Y - hh + 0.04, zt), (cx + hw - 0.05, LEAF_Y - hh + 0.5, zt + 0.02))
        mx = cx + meeting * (hw - 0.3)
        if kind == "braced":
            # a big D-handle near the meeting edge
            for y in (-0.95, 0.35):
                iron.box_between((mx - 0.05, LEAF_Y + y - 0.05, zt), (mx + 0.05, LEAF_Y + y + 0.05, 6.9))
            iron.cylinder((mx, LEAF_Y - 0.3, 6.89), "y", 0.03, 1.4, 6)
            feat["grips"].append({"side": 1, "x": mx, "y": [LEAF_Y - 1.0, LEAF_Y + 0.4]})
        else:
            # a pull ring, and the hasp: on the left leaf, folding over to a staple and padlock on the right
            brass.box_between((mx - 0.1, LEAF_Y - 0.9, zt), (mx + 0.1, LEAF_Y - 0.5, zt + 0.02))
            brass.lathe([(0.11, -0.02), (0.13, 0.0), (0.11, 0.02), (0.09, 0.0)], (mx, LEAF_Y - 0.82, 6.9), "z", 10, caps=False)
            feat["grips"].append({"side": 1, "x": mx, "y": [LEAF_Y - 1.0, LEAF_Y - 0.4]})
            hy = LEAF_Y + 0.75
            if meeting > 0:
                iron.box_between((cx + hw - 0.6, hy - 0.11, zt), (cx + hw - 0.02, hy + 0.11, zt + 0.025))
                iron.cylinder((cx + hw - 0.62, hy, zt + 0.03), "y", 0.04, 0.24, 6)
                iron.rivets([(cx + hw - 0.45, hy, zt + 0.025)], (0, 0, 1), 0.04, 0.02, 6)
            else:
                iron.box_between((cx - hw + 0.02, hy - 0.11, zt), (cx - hw + 0.42, hy + 0.11, zt + 0.025))
                iron.box_between((cx - hw + 0.2, hy - 0.06, zt + 0.025), (cx - hw + 0.28, hy + 0.06, 6.9))
                # the padlock: a body hanging from a shackle through the staple
                iron.box_between((cx - hw + 0.13, hy - 0.42, 6.87), (cx - hw + 0.35, hy - 0.14, 6.92))
                brass.lathe([(0.07, 0.0), (0.07, 0.02), (0.0, 0.02)], (cx - hw + 0.24, hy - 0.08, 6.89), "z", 8)
            feat["rivets"].append({"side": 1, "x": cx + meeting * (hw - 0.4), "y": hy})
        out += [planks, iron, brass]
        joins[pn] = [pn + "_iron", pn + "_brass"]
        anchors[key] = [cx, LEAF_Y, LEAF_Z]
    spec["leafJoins"] = joins
    spec["leafAnchors"] = anchors
    return out


# -- the cars --------------------------------------------------------------------------------------


def LastTrainOut(spec, P, C):
    """The crest sits in the lower panel under the platform side's window (the far side's middle)."""
    cx = (spec["x0"] + spec["x1"]) / 2
    for side in (1, -1):
        target = min(C.windows(side) or [cx], key=lambda w: abs(w - cx))
        low = [p for p in C.feat["panels"] if p["side"] == side and p["rect"][1] < 1.0]
        clear = [p for p in low if not C.in_slide(side, p["rect"][0], p["rect"][2])] or low
        p = min(clear, key=lambda p: abs((p["rect"][0] + p["rect"][2]) / 2 - target))
        xa, ya, xb, yb = p["rect"]
        p["kind"] = "crest"  # the crest's panel: lined, no corner scrolls (canvas.py)
        C.feat["crests"].append({"side": side, "x": (xa + xb) / 2, "y": (ya + yb) / 2, "r": min(xb - xa, yb - ya) / 2 - 0.22})
    return []


def Workshop(spec, P, C):
    x0, x1 = spec["x0"], spec["x1"]
    cx = (x0 + x1) / 2
    feat = C.feat
    fit, crate, tarp, roof, brass = P.fit, P.crate, P.tarp, P.roof, P.brass
    # bracing irons across every lower panel, alternating, riveted at the frame
    for side in (1, -1):
        k = 0
        for p in [p for p in feat["panels"] if p["side"] == side and p["rect"][1] < 1.0]:
            xa, ya, xb, yb = p["rect"]
            ya, yb = ya + 0.05, yb - 0.05
            if k % 2:
                xa, xb = xb, xa
            k += 1
            ang = math.atan2(yb - ya, xb - xa)
            w = 0.07
            nx, ny = -math.sin(ang) * w, math.cos(ang) * w
            prof = [(xa - nx, ya - ny), (xb - nx, yb - ny), (xb + nx, yb + ny), (xa + nx, ya + ny)]
            if (xb < xa) != (side < 0):
                prof.reverse()
            fit.prism_z(prof, side * (SKIN - 0.01), side * (SKIN + 0.03))
            fit.rivets([(xa, ya + 0.1, side * (SKIN + 0.03)), (xb, yb - 0.1, side * (SKIN + 0.03))], (0, 0, side), 0.05, 0.025, 6)
            feat["rivets"] += [{"side": side, "x": xa, "y": ya + 0.1}, {"side": side, "x": xb, "y": yb - 0.1}]
        # the pipe run under the solebar: air and steam, clipped every two studs, a drain cock
        for zp, r in ((6.25, 0.08), (6.05, 0.06)):
            fit.cylinder(((x0 + x1) / 2, -1.25, side * zp), "x", r, x1 - x0 - 0.6, 8)
        for k in range(int((x1 - x0) / 2)):
            x = x0 + 1.0 + k * 2.0
            fit.box_between((x - 0.05, -1.36, side * 5.95), (x + 0.05, -1.0, side * 6.36))
        fit.cylinder((cx + 1.5, -1.45, side * 6.25), "y", 0.05, 0.35, 6)
    # the tool rack by the end on the platform side, clear of the grab rail and the window
    spans = [s for s in free_spans(spec, C, 1, 0.05) if s[1] - s[0] > 1.6]
    if spans:
        a, b = min(spans, key=lambda s: s[0])
        b = min(b, a + 2.3)
        r = P.crate
        r.box_between((a, 2.2, SKIN - 0.02), (b, 6.7, 6.64))
        for y in (2.5, 6.3):
            fit.box_between((a - 0.04, y - 0.08, SKIN), (b + 0.04, y + 0.08, 6.68))
            fit.rivets([(a + 0.1, y, 6.68), (b - 0.1, y, 6.68)], (0, 0, 1), 0.04, 0.02, 6)
            feat["ledges"].append({"side": 1, "x": [a, b], "y": y - 0.08, "iron": True})
        tools = []
        n = 4
        for k in range(n):
            tx = a + 0.3 + k * (b - a - 0.6) / (n - 1)
            tools.append(tx)
            # pegs
            r.cylinder((tx, 6.0, 6.71), "z", 0.04, 0.16, 6)
        # a long-handled shovel, a pickaxe, a sledge and a crowbar, hung on the pegs
        sx = tools[0]
        r.cylinder((sx, 4.6, 6.76), "y", 0.05, 2.9, 6)
        fit.box_between((sx - 0.28, 2.4, 6.72), (sx + 0.28, 3.25, 6.78))
        fit.box_between((sx - 0.08, 3.2, 6.72), (sx + 0.08, 3.5, 6.8))
        px = tools[1]
        r.cylinder((px, 4.4, 6.76), "y", 0.055, 3.0, 6)
        pick = [(px - 0.7, 5.6), (px, 5.82), (px + 0.7, 5.6), (px + 0.72, 5.68), (px, 6.02), (px - 0.72, 5.68)]
        fit.prism_z(pick, 6.7, 6.84)
        hx = tools[2]
        r.cylinder((hx, 4.2, 6.76), "y", 0.05, 2.6, 6)
        fit.box_between((hx - 0.24, 5.42, 6.66), (hx + 0.24, 5.78, 6.86))
        bx = tools[3]
        fit.cylinder((bx, 4.4, 6.74), "y", 0.04, 3.2, 6)
        fit.box_between((bx - 0.12, 2.8, 6.72), (bx + 0.04, 2.88, 6.76))
        feat["grips"].append({"side": 1, "x": (a + b) / 2, "y": [3.0, 5.0]})
        feat["scorch"].append({"side": 1, "x": (a + b) / 2, "y": 4.5, "r": 0.9, "n": 10})
    # a tarped load lashed on the platform side of the roof (timber and spare rail under it)
    ta, tb = spec["monitor"][0] + 1.0, cx - 0.5
    rings = []
    m = 9
    for k in range(m + 1):
        x = ta + (tb - ta) * k / m
        bump = 0.08 * math.sin(k * 2.1) + (0.06 if k in (0, m) else 0.0)
        prof = []
        for j in range(9):
            t = j / 8
            z = 3.0 + 2.6 * t
            y = C.roof_y(z) + 0.02 + (0.75 + bump) * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7
            prof.append(V(x, y, z))
        for j in range(8, -1, -1):
            z = 3.0 + 2.6 * j / 8
            prof.append(V(x, C.roof_y(z) - 0.02, z))
        rings.append(prof)
    tarp.quad_strip(rings, closed_path=False, closed_profile=True, caps=True)
    for k in range(4):
        x = ta + 0.6 + k * (tb - ta - 1.2) / 3
        pts = [(x, C.roof_y(2.9), 2.9), (x, C.roof_y(3.3) + 0.6, 3.3), (x, C.roof_y(4.3) + 0.86, 4.3), (x, C.roof_y(5.3) + 0.6, 5.3), (x, C.roof_y(5.7), 5.7)]
        lashing(crate, pts, 0.05)
    for x in (ta + 0.3, tb - 0.3):
        crate.box_between((x - 0.15, C.roof_y(5.8) - 0.1, 2.8), (x + 0.15, C.roof_y(5.8) + 0.18, 5.9))
    # the louvred roof vent over the bench and the forge's stovepipe with a spark arrester
    vx, sx = cx - 3.4, cx + 2.6
    yc = 11.36
    roof.box_between((vx - 1.0, yc - 0.1, -1.0), (vx + 1.0, yc + 0.7, 1.0))
    for side in (-1, 1):
        for k in range(4):
            y = yc + 0.05 + k * 0.16
            louv = [(y, side * 1.0), (y + 0.06, side * 1.18), (y + 0.12, side * 1.18), (y + 0.06, side * 1.0)]
            if side < 0:
                louv.reverse()
            roof.prism_x(louv, vx - 0.92, vx + 0.92)
    roof.box_between((vx - 1.15, yc + 0.7, -1.25), (vx + 1.15, yc + 0.82, 1.25))
    feat["vents"].append({"x": vx, "z": 0.0, "kind": "louvre"})
    fit.box_between((sx - 0.5, yc - 0.1, -0.5), (sx + 0.5, yc + 0.08, 0.5))
    fit.lathe([(0.32, 0.0), (0.32, 2.0), (0.36, 2.04), (0.36, 2.1), (0.3, 2.12)], (sx, yc, 0), "y", 12, caps=False)
    # the spark arrester: a mesh cage (rings and bars) under a conical cap
    for h in (2.2, 2.55, 2.9):
        fit.lathe([(0.46, h - 0.03), (0.46, h + 0.03)], (sx, yc, 0), "y", 12, caps=False)
    for k in range(8):
        a = 2 * math.pi * k / 8
        fit.box_between((sx + 0.46 * math.cos(a) - 0.02, yc + 2.12, 0.46 * math.sin(a) - 0.02), (sx + 0.46 * math.cos(a) + 0.02, yc + 2.95, 0.46 * math.sin(a) + 0.02))
    fit.lathe([(0.62, 0.0), (0.58, 0.06), (0.0, 0.42)], (sx, yc + 2.95, 0), "y", 12)
    feat["vents"].append({"x": sx, "z": 0.0, "kind": "stove"})
    for side in (1, -1):
        feat["scorch"].append({"side": side, "x": sx, "y": 7.8, "r": 1.6, "n": 26})
    return heavy_leaves(spec, P, C, "braced")


def Stores(spec, P, C):
    x0, x1 = spec["x0"], spec["x1"]
    cx = (x0 + x1) / 2
    feat = C.feat
    fit, crate = P.fit, P.crate
    # security straps across both bands (clear of the door opening)
    for side in (1, -1):
        spans = [(x0 + 0.6, x1 - 0.6)]
        for d in C.doors(side):
            spans = [(a, min(b, d - 2.95)) for a, b in spans if a < d - 2.95] + [(max(a, d + 2.95), b) for a, b in spans if b > d + 2.95]
        for a, b in spans:
            if b - a < 0.8:
                continue
            zt = C.zmax(side, a, b)
            for y in (1.5,):
                strap(fit, feat, side, a, b, y, 0.24, SKIN - 0.01, min(zt, 6.64) - 0.02, max(2, int((b - a) / 0.9)))
    # the blind front end: a cradle of crates and barrels strapped to the end wall over the buffers
    xf = x1 + 0.22
    fit.box_between((xf, 0.18, -5.6), (xf + 0.9, 0.32, 5.6))
    for z in (-5.4, -3.0, 3.0, 5.4):
        fit.box_between((xf, -0.6, z - 0.06), (xf + 0.9, 0.2, z + 0.06))
    crate_box(crate, fit, (xf + 0.04, 0.32, -5.5), (xf + 0.86, 1.3, -4.3))
    crate_box(crate, fit, (xf + 0.08, 1.3, -5.3), (xf + 0.8, 2.0, -4.5))
    barrel(crate, fit, (xf + 0.45, 0.32 + 0.65, -3.5), 0.4, 1.3)
    barrel(crate, fit, (xf + 0.45, 0.32 + 0.65, 3.4), 0.4, 1.3)
    crate_box(crate, fit, (xf + 0.04, 0.32, 4.1), (xf + 0.86, 1.2, 5.5))
    for y in (0.9, 1.7):
        fit.box_between((xf + 0.86, y - 0.05, -5.6), (xf + 0.92, y + 0.05, -2.9))
        fit.box_between((xf + 0.86, y - 0.05, 2.9), (xf + 0.92, y + 0.05, 5.6))
    # barrels and crates lashed on the platform side of the roof, chocked
    ra = spec["monitor"][1] - 4.6
    for k, x in enumerate((ra + 0.6, ra + 1.6)):
        barrel(crate, fit, (x, P and C.roof_y(4.6) + 0.42, 4.6), 0.42, 1.5, "z", 12)
    crate_box(crate, fit, (ra + 2.3, C.roof_y(4.0), 3.2), (ra + 3.4, C.roof_y(4.0) + 0.9, 5.4))
    crate_box(crate, fit, (ra + 2.45, C.roof_y(4.0) + 0.9, 3.5), (ra + 3.25, C.roof_y(4.0) + 1.45, 4.6))
    for x in (ra + 0.2, ra + 2.1, ra + 3.6):
        crate.box_between((x - 0.1, C.roof_y(5.9) - 0.05, 3.0), (x + 0.1, C.roof_y(5.9) + 0.2, 5.85))  # inside 5.9, or split_sides takes the end caps
    for z in (3.8, 5.0):
        lashing(crate, [(ra, C.roof_y(z), z), (ra + 0.4, C.roof_y(z) + 0.86, z), (ra + 2.3, C.roof_y(z) + 0.95, z), (ra + 3.5, C.roof_y(z) + 1.0, z), (ra + 3.8, C.roof_y(z), z)], 0.04)
    # stencils (canvas.py paints them in the stencil layer; the far side's read mirrored)
    for side in (1, -1):
        ws = C.windows(side)
        big = (ws[-1] if side > 0 and ws else cx)
        feat["stencils"].append({"side": side, "x": big, "y": 1.55, "h": 0.78, "text": "STORES"})
        feat["stencils"].append({"side": side, "x": x0 + 2.0 if side > 0 else x1 - 2.0, "y": 2.15, "h": 0.3, "text": "L.T.O. No 5"})
        feat["stencils"].append({"side": side, "x": x0 + 2.0 if side > 0 else x1 - 2.0, "y": 1.7, "h": 0.22, "text": "TARE 11-4-0"})
        feat["stencils"].append({"side": side, "x": x0 + 2.0 if side > 0 else x1 - 2.0, "y": 1.3, "h": 0.22, "text": "KEEP DRY"})
    for d in C.doors(1):
        feat["stencils"].append({"side": 1, "x": d + 1.4, "y": 1.75, "h": 0.55, "text": "No 5"})
    return heavy_leaves(spec, P, C, "hasp")


def GuardsVan(spec, P, C):
    x0, x1 = spec["x0"], spec["x1"]
    feat = C.feat
    fit, brass, roof, shell, glow = P.fit, P.brass, P.roof, P.shell, P.glow
    deck = spec["rearDeck"]
    out = []
    # -- the lookout cupola, over the clerestory at the veranda end ------------------------------
    ca, cb = x0 + 1.6, x0 + 6.4
    cz = 3.05
    yb, yt = 9.9, 13.2
    for side in (-1, 1):
        shell.box_between((ca, yb, side * (cz - 0.2)), (cb, yt, side * cz))
        # windows: two lights each side in moulded frames, glazed warm (the guard's lamp inside)
        for wx in (ca + 1.25, cb - 1.25):
            o = rect_outline(wx - 0.62, 11.25, wx + 0.62, 12.65)
            glow.box_between((wx - 0.62, 11.25, side * (cz - 0.06)), (wx + 0.62, 12.65, side * (cz + 0.005)))
            for (xa, ya, xb, yb2) in ((wx - 0.76, 11.1, wx + 0.76, 11.25), (wx - 0.76, 12.65, wx + 0.76, 12.82), (wx - 0.76, 11.25, wx - 0.62, 12.65), (wx + 0.62, 11.25, wx + 0.76, 12.65)):
                shell.box_between((xa, ya, side * cz), (xb, yb2, side * (cz + 0.1)))
            fit.box_between((wx - 0.03, 11.25, side * cz), (wx + 0.03, 12.65, side * (cz + 0.04)))
            shell.box_between((wx - 0.86, 10.95, side * cz), (wx + 0.86, 11.1, side * (cz + 0.22)))
        # weatherboards below the windows
        for k in range(4):
            y = yb + 0.1 + k * 0.25
            shell.box_between((ca, y, side * cz), (cb, y + 0.22, side * (cz + 0.05 + 0.02 * (k % 2))))
        for x in (ca, cb):
            shell.box_between((x - 0.12, yb, side * (cz - 0.1)), (x + 0.12, yt, side * (cz + 0.12)))
    for x, d in ((ca, -1), (cb, 1)):
        shell.box_between((min(x, x + d * 0.2), yb, -cz), (max(x, x + d * 0.2), yt, cz))
        glow.box_between((x + d * 0.2 - 0.005 * d, 11.35, -1.0), (x + d * 0.2 + 0.01 * d, 12.55, 1.0))
        for (za, ya, zb_, yb2) in ((-1.14, 11.2, 1.14, 11.35), (-1.14, 12.55, 1.14, 12.7), (-1.14, 11.35, -1.0, 12.55), (1.0, 11.35, 1.14, 12.55)):
            shell.box_between((x + d * 0.2, ya, za), (x + d * 0.3, yb2, zb_))
    # its roof: cambered, with an overhang and a lamp-top
    cap = []
    for k in range(9):
        z = -(cz + 0.45) + 2 * (cz + 0.45) * k / 8
        cap.append((yt + 0.3 * (1 - (z / (cz + 0.45)) ** 2), z))
    roof.prism_x(cap + [(y - 0.14, z) for y, z in reversed(cap)], ca - 0.4, cb + 0.4)
    roof.lathe([(0.3, -0.05), (0.3, 0.1), (0.22, 0.2), (0.1, 0.36), (0.12, 0.4), (0.0, 0.46)], ((ca + cb) / 2, yt + 0.28, 0), "y", 10)
    feat["vents"].append({"x": (ca + cb) / 2, "z": 0.0, "kind": "lamp"})
    # -- the veranda: canopy roof, columns with brackets, balustrade, hand brake, tail lanterns -----
    va, vb = deck - 0.3, x0 + 0.1
    prof = []
    for k in range(13):
        z = -6.9 + 13.8 * k / 12
        prof.append((C.roof_y(z), z))
    roof.prism_x(prof + [(y - 0.16, z) for y, z in reversed(prof)], va, vb)
    # a valance board along the open end, with a dog-tooth edge
    shell.box_between((va - 0.06, 9.2, -6.9), (va + 0.06, 9.66, 6.9))
    n = 23
    for k in range(n):
        z = -6.9 + (k + 0.5) * 13.8 / n
        shell.prism_z([(va - 0.05, 9.2), (va + 0.05, 9.2), (va, 9.0)], z - 0.2, z + 0.2) if False else shell.box_between((va - 0.05, 9.0, z - 0.12), (va + 0.05, 9.2, z + 0.12))
    for side in (-1, 1):
        zc = side * 6.2
        cxp = deck + 0.4
        fit.lathe([(0.3, 0.0), (0.3, 0.16), (0.2, 0.26), (0.18, 0.4)], (cxp, 0.0, zc), "y", 10, caps=False)
        fit.cylinder((cxp, 4.6, zc), "y", 0.17, 8.4, 10)
        fit.lathe([(0.17, 0.0), (0.26, 0.2), (0.3, 0.3), (0.3, 0.4)], (cxp, 8.8, zc), "y", 10, caps=False)
        # a curved bracket from the column to the canopy (as a stepped knee)
        for k in range(4):
            fit.box_between((cxp + 0.1 + k * 0.28, 8.3 + k * 0.22, zc - 0.05), (cxp + 0.38 + k * 0.28, 8.5 + k * 0.22, zc + 0.05))
    # balustrade: the rear end, and the far (-Z) side; the platform side stays open to step on
    def rail(a, b, horiz_z=None, horiz_x=None):
        for y, r, pc in ((3.2, 0.065, brass), (1.75, 0.04, fit), (0.3, 0.05, fit)):
            if horiz_z is not None:
                pc.cylinder(((a + b) / 2, y, horiz_z), "x", r, b - a, 8)
            else:
                pc.cylinder((horiz_x, y, (a + b) / 2), "z", r, b - a, 8)
        n = max(2, int((b - a) / 0.42))
        for k in range(n + 1):
            t = a + k * (b - a) / n
            p = (t, 1.75, horiz_z) if horiz_z is not None else (horiz_x, 1.75, t)
            fit.cylinder(p, "y", 0.025, 2.9, 4)
            if k % 3 == 1:
                fit.lathe([(0.0, -0.08), (0.07, 0.0), (0.0, 0.08)], (p[0], 1.0, p[2]), "y", 6)

    rail(-5.95, 5.95, horiz_x=deck + 0.15)
    rail(deck + 0.6, x0 - 0.3, horiz_z=-6.25)
    feat["grips"].append({"side": -1, "x": (deck + x0) / 2, "y": [3.0, 3.4]})
    # the hand-brake standard: a column with its screw housing and a wheel on top
    bx, bz = x0 - 0.75, -5.35
    fit.box_between((bx - 0.25, 0.0, bz - 0.25), (bx + 0.25, 0.7, bz + 0.25))
    fit.cylinder((bx, 2.0, bz), "y", 0.09, 2.6, 8)
    fit.lathe([(0.55, -0.04), (0.6, 0.0), (0.55, 0.04), (0.5, 0.0)], (bx, 3.35, bz), "y", 16, caps=False)
    for k in range(5):
        a = 2 * math.pi * k / 5
        fit.box_between((bx + 0.26 * math.cos(a) - 0.25 * abs(math.cos(a)), 3.32, bz + 0.26 * math.sin(a) - 0.25 * abs(math.sin(a))),
                        (bx + 0.26 * math.cos(a) + 0.25 * abs(math.cos(a)) + 0.03, 3.38, bz + 0.26 * math.sin(a) + 0.25 * abs(math.sin(a)) + 0.03))
    fit.lathe([(0.12, -0.08), (0.12, 0.08), (0.0, 0.1)], (bx, 3.35, bz), "y", 8)
    brass.cylinder((bx + 0.55, 3.55, bz), "y", 0.05, 0.4, 6)
    # tail lanterns hung on the columns: brass bodies with a hood, a red lens facing back
    tail = Piece(f"{spec['name']}_Tail", None, "Lamp")
    for side in (-1, 1):
        lz = side * 5.65
        lx = deck - 0.05
        brass.box_between((lx - 0.2, 5.1, lz - 0.32), (lx + 0.3, 5.9, lz + 0.32))
        brass.box_between((lx - 0.26, 5.9, lz - 0.38), (lx + 0.36, 5.98, lz + 0.38))
        brass.lathe([(0.2, 0.0), (0.14, 0.12), (0.06, 0.2), (0.07, 0.26), (0.0, 0.3)], (lx + 0.05, 5.98, lz), "y", 8)
        brass.lathe([(0.27, -0.02), (0.27, 0.06), (0.0, 0.06)], (lx - 0.2, 5.5, lz), "x", 12)
        tail.lathe([(0.22, -0.06), (0.22, 0.0), (0.0, 0.02)], (lx - 0.2, 5.5, lz), "x", 12)
        fit.box_between((lx + 0.3, 5.45, lz - 0.05), (lx + 0.62, 5.55, lz + 0.05))
        feat["lamps"].append({"side": side, "x": lx, "y": 5.5})
    out.append(tail)
    return out
