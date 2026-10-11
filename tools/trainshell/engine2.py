"""
The engine and her tender (TrainBuilder's 4-4-0 "LAST LIGHT No. 1931" and the tender behind her), in
the carriages' language (carriage2.py): modelled over the primitives in train space, wear recorded
by cause in spec["feat"] for canvas.py and bake2.py.

  Tender      a riveted U-tank with rounded corners, one lined panel a side carrying the company's
              name in shaded gilt (canvas.py "letters"), flared coal boards with a rolled edge and
              coal rails, a raised deck at the rear with the water filler, tool lockers and the
              brake column at the front, steps, grab irons, ladder, lamp irons, buffers, drawbar
  Locomotive  an 1800s American cab (panelled, beaded, arched roof with a ventilator, spectacles,
              brass nameplates over the door), Russia-iron boiler with brass bands, wagon-top
              firebox with the ash pan glowing under it, sand and steam domes, bell on its yoke,
              whistle and safety valves, smokebox with a dished door, balloon stack, headlamp box
              on its platform, cylinders with valve chests, plate frames with axle boxes and
              springs, running boards on a lined valance, handrails, sand pipes, feed pipes and
              clack valves, buffer beam and slatted pilot, its own cab door leaves

The primitives keep collision, the cab interior and everything the scripts animate: the runtime
(Builders/TrainShell, `engine` cars) retires exactly the primitives listed in spec["retire"] (see
retire_list), and puts the kit's driving wheels, coupling rods, Mansell wheels, bogies and coal on
the primitives that carry WheelRadius, CrankRadius and CoalTier.

Pieces: <car>_Shell (Body), _Trim (Trim), _Roof (Roof), _Fittings, _Boiler (its own atlas <car>_B),
_Glow (Lamp), _Sign, and the cab's _DoorLeafL/R. Shell, Trim and Fittings split per side
(build_car2.split_sides) into the <car>_P / <car>_N atlases.
"""

import math

from mathutils import Vector

from kit import Piece, V

BEAD = [(0.045, 0.0), (0.039, 0.024), (0.022, 0.04), (0.0, 0.046), (-0.022, 0.04), (-0.039, 0.024), (-0.045, 0.0)]
FINE_BEAD = [(0.03, 0.0), (0.021, 0.022), (0.0, 0.03), (-0.021, 0.022), (-0.03, 0.0)]

TENDER = (23.0, 49.0)
RANGES = {"Tender": (21.5, 50.5), "Locomotive": (50.5, 100.0)}  # primitive centres each car owns (gen_config.py too)
CAB = (52.0, 64.0)
BOILER_Y, BOILER_R = 6.2, 4.0
SMOKEBOX_R = 4.25

# -- helpers -------------------------------------------------------------------------------------


def bar(p, a, b, w, h, up=(0, 1, 0)):
    """A rectangular bar from a to b (Roblox points): w across, h along `up` (made square to the bar)."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    u = Vector(up)
    u = u - d * u.dot(d)
    if u.length < 1e-6:
        u = Vector((1, 0, 0)) - d * d.x
    u.normalize()
    s = d.cross(u).normalized()

    def ring(c):
        return [V(*(c + u * (h / 2) * i + s * (w / 2) * j)) for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]

    p.quad_strip([ring(a), ring(b)])


def tube(p, pts, r, segs=6, caps=True):
    """A round pipe along a polyline (Roblox points), rings carried along without twisting."""
    P = [Vector(q) for q in pts]
    rings = []
    ref = None
    for i, c in enumerate(P):
        if i == 0:
            t = P[1] - P[0]
        elif i == len(P) - 1:
            t = P[-1] - P[-2]
        else:
            t = (P[i + 1] - P[i]).normalized() + (P[i] - P[i - 1]).normalized()
        t.normalize()
        if ref is None:
            ref = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
        n = (ref - t * ref.dot(t)).normalized()
        ref = n
        b = t.cross(n)
        rings.append([V(*(c + (n * math.cos(2 * math.pi * k / segs) + b * math.sin(2 * math.pi * k / segs)) * r)) for k in range(segs)])
    p.quad_strip(rings, caps=caps)


def round_rect(x0, y0, x1, y1, r, segs=3):
    """A rounded rectangle, counter-clockwise, (4 * (segs + 1)) points."""
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for k in range(segs + 1):
            a = math.radians(a0 + 90 * k / segs)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def ring_prism_y(p, outer, inner, y0, y1):
    """A wall between two closed (x, z) loops with the same number of points, from y0 to y1."""
    bm = p.bm
    n = len(outer)
    o0 = [bm.verts.new(V(x, y0, z)) for x, z in outer]
    o1 = [bm.verts.new(V(x, y1, z)) for x, z in outer]
    i0 = [bm.verts.new(V(x, y0, z)) for x, z in inner]
    i1 = [bm.verts.new(V(x, y1, z)) for x, z in inner]
    for k in range(n):
        j = (k + 1) % n
        bm.faces.new((o0[k], o0[j], o1[j], o1[k]))
        bm.faces.new((i0[j], i0[k], i1[k], i1[j]))
        bm.faces.new((o1[k], o1[j], i1[j], i1[k]))
        bm.faces.new((o0[j], o0[k], i0[k], i0[j]))


def bead_loop(p, side, pts2d, z, prof=FINE_BEAD):
    """A half-round bead round a closed (x, y) outline on a side face at |z|."""
    p.sweep([(x, y, side * z) for x, y in pts2d], prof, (0, 0, side), closed=True)


def bead_line(p, side, a, b, z, prof=FINE_BEAD):
    p.sweep([(a[0], a[1], side * z), (b[0], b[1], side * z)], prof, (0, 0, side), closed=False)


def end_bead_loop(p, end, pts2d, x, prof=FINE_BEAD):
    """A bead round a closed (z, y) outline on an end face at x, facing `end`."""
    p.sweep([(x, y, z) for z, y in pts2d], prof, (end, 0, 0), closed=True)


def rivet_row(p, feat, side, xa, xb, y, z, pitch=0.6, r=0.045):
    n = max(2, int(round((xb - xa) / pitch)) + 1)
    pts = [(xa + k * (xb - xa) / (n - 1), y) for k in range(n)]
    p.rivets([(x, yy, side * z) for x, yy in pts], (0, 0, side), r, 0.024, 6)
    feat["rivets"] += [{"side": side, "x": x, "y": yy} for x, yy in pts]


def buffer(fit, x, end, y, z):
    """A buffer on a beam face at x pointing `end` (+1 front): flanged housing, plunger, head."""
    prof = [(0.42, 0.0), (0.42, 0.06), (0.3, 0.16), (0.3, 0.6), (0.17, 0.6), (0.17, 0.82), (0.52, 0.82), (0.52, 0.92), (0.46, 0.97), (0.0, 0.99)]
    if end > 0:
        fit.lathe([(r, x + h) for r, h in prof], (0, y, z), "x", 14)
    else:
        fit.lathe([(r, x - h) for r, h in reversed(prof)], (0, y, z), "x", 14)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        fit.rivets([(x + end * 0.06, y + 0.33 * math.cos(a), z + 0.33 * math.sin(a))], (end, 0, 0), 0.05, 0.03, 6)


def lathe_x(p, prof, y, z, segs=16, caps=True):
    """Revolve an (r, x) profile about the line (y, z) parallel to X."""
    p.lathe(prof, (0, y, z), "x", segs, caps)


def dish_x(r):
    """The smokebox door's face: x at radius r."""
    pts = [(3.92, 94.3), (3.62, 94.36), (2.9, 94.52), (1.8, 94.64), (0.6, 94.7), (0.0, 94.71)]
    if r >= pts[0][0]:
        return pts[0][1]
    for (ra, xa), (rb, xb) in zip(pts, pts[1:]):
        if rb <= r <= ra:
            t = (ra - r) / (ra - rb)
            return xa + (xb - xa) * t
    return pts[-1][1]


def new_feat():
    return {"panels": [], "ledges": [], "rivets": [], "grips": [], "steps": [], "doorEdges": [], "vents": [], "straps": [],
            "plates": [], "windows": [], "boards": [], "lamps": [], "crests": [], "stencils": [], "scorch": [],
            "letters": [], "boilerFittings": []}


# -- the tender ----------------------------------------------------------------------------------


def tender(spec):
    n = spec["name"]
    x0, x1 = TENDER
    cx = (x0 + x1) / 2
    shell = Piece(f"{n}_Shell", "Body", "Paint")
    trim = Piece(f"{n}_Trim", "Trim", "Gilt")
    fit = Piece(f"{n}_Fittings", None, "Iron")
    brass = Piece(f"{n}_Brass", None, "Brass")
    wood = Piece(f"{n}_Wood", None, "Crate")
    feat = new_feat()
    labels = []
    spec["feat"], spec["labels"] = feat, labels
    out = [shell, trim, fit, brass, wood]
    SK, IN = 6.58, 5.9
    TOPY = 7.0

    # the tank: a U of plate with rounded corners, open over the coal
    outer = round_rect(x0 - 0.05, -SK, x1 + 0.05, SK, 0.6, 4)
    inner = round_rect(x0 + 0.6, -IN, x1 - 0.6, IN, 0.08, 4)
    ring_prism_y(shell, [(x, z) for x, z in outer], [(x, z) for x, z in inner], -0.05, TOPY)
    # rivets: along the top and bottom angles, and up the corners
    for s in (1, -1):
        rivet_row(fit, feat, s, x0 + 0.7, x1 - 0.7, TOPY - 0.2, SK, 0.62)
        rivet_row(fit, feat, s, x0 + 0.7, x1 - 0.7, 0.18, SK, 0.62)
        for xx in (x0 + 0.35, x1 - 0.35):
            pts = [(xx, 0.6 + k * 0.6) for k in range(10)]
            fit.rivets([(x, y, s * (SK - 0.04)) for x, y in pts], (0, 0, s), 0.045, 0.024, 6)
            feat["rivets"] += [{"side": s, "x": x, "y": y} for x, y in pts]
        feat["ledges"].append({"side": s, "x": [x0, x1], "y": TOPY - 0.25, "iron": True})
        # the lined panel and the company's name
        pa = (x0 + 1.2, 0.6, x1 - 1.2, TOPY - 0.65)
        bead_loop(trim, s, round_rect(*pa, 0.45, 3), SK, BEAD)
        feat["panels"].append({"side": s, "rect": list(pa), "kind": "upper"})
        feat["ledges"].append({"side": s, "x": [pa[0], pa[2]], "y": pa[1]})
        feat["letters"].append({"side": s, "text": "LAST TRAIN OUT", "x": cx, "y": 3.55, "h": 1.3, "w": 19.5})
        # flared coal boards: lean out to a rolled edge, coal rails above on stanchions
        fy0, fy1, fz0, fz1 = TOPY - 0.02, 8.2, 6.3, 6.8
        prof = [(fy0, s * fz0), (fy1, s * fz1), (fy1, s * (fz1 - 0.1)), (fy0, s * (fz0 - 0.12))]
        shell.prism_x(prof, x0 + 0.3, x1 - 0.2)
        fit.cylinder((cx, fy1 + 0.04, s * (fz1 - 0.03)), "x", 0.07, x1 - x0 - 0.5, 8)
        rivet_row(fit, feat, s, x0 + 0.6, x1 - 0.6, TOPY + 0.12, 6.36, 0.9, 0.04)
        for y in (8.75, 9.3):
            fit.cylinder((cx, y, s * 6.62), "x", 0.055, x1 - x0 - 0.7, 6)
        for k in range(7):
            xx = x0 + 0.6 + k * (x1 - x0 - 1.2) / 6
            bar(fit, (xx, 8.1, s * 6.74), (xx, 9.42, s * 6.6), 0.1, 0.07)
        # the valance: an iron sole under the tank, riveted, with the steps at its corners
        fit.box_between((x0 - 0.05, -1.0, s * 6.3), (x1 + 0.05, -0.05, s * 6.62))
        rivet_row(fit, feat, s, x0 + 0.3, x1 - 0.3, -0.52, 6.62, 0.75)
        feat["ledges"].append({"side": s, "x": [x0, x1], "y": -1.0, "iron": True})
        for a, b in ((x0 + 0.5, x0 + 2.0), (x1 - 2.0, x1 - 0.5)):
            for xx in (a + 0.1, b - 0.1):
                bar(fit, (xx, -0.9, s * 6.55), (xx, -2.0, s * 6.7), 0.12, 0.06, (0, 0, 1))
            fit.box_between((a, -2.08, s * 6.0), (b, -1.94, s * 6.88))
            feat["steps"].append({"side": s, "x": [a, b]})
        # grab irons at the four corners, on standoffs
        for xx in (x0 - 0.22, x1 + 0.22):
            brass.cylinder((xx, 3.6, s * 6.25), "y", 0.055, 5.0, 8)
            for y in (1.15, 6.05):
                fit.cylinder((xx * 0.5 + (x0 + 0.05 if xx < cx else x1 - 0.05) * 0.5, y, s * 6.25), "x", 0.04, 0.24, 6)
            feat["grips"].append({"side": s, "x": xx, "y": [1.2, 6.0]})
    # the builder's plate on the platform side's valance, the far side's too
    for s in (1, -1):
        px = x0 + 3.2
        plate = Piece(f"{n}_plateB{'P' if s > 0 else 'N'}", None, "Sign")
        plate.box_between((px - 0.5, -0.86, s * 6.62), (px + 0.5, -0.2, s * 6.68))
        out.append(plate)
        labels.append({"piece": plate.name, "label": "builders", "side": s, "rect": [px - 0.5, -0.86, px + 0.5, -0.2], "z": 6.68})

    # rear end: ladder, lamp irons, number plate, end beam with buffers and the coupling
    rx = x0 - 0.05
    for zz in (-3.5, -2.5):
        fit.box_between((rx - 0.2, -0.9, zz - 0.05), (rx - 0.1, TOPY + 0.9, zz + 0.05))
        for y in (TOPY + 0.9,):
            fit.box_between((rx - 0.1, y - 0.1, zz - 0.05), (rx + 0.3, y, zz + 0.05))
    for k in range(12):
        fit.cylinder((rx - 0.15, -0.4 + k * 0.62, -3.0), "z", 0.04, 1.0, 6)
    for zz in (-5.2, 5.2):
        fit.box_between((rx - 0.36, 6.3, zz - 0.07), (rx, 6.42, zz + 0.07))
        fit.box_between((rx - 0.36, 6.3, zz - 0.07), (rx - 0.3, 6.9, zz + 0.07))
    num = Piece(f"{n}_plateNum", None, "Sign")
    num.box_between((rx - 0.06, 5.2, 0.4), (rx, 5.8, 2.0))
    out.append(num)
    labels.append({"piece": num.name, "label": "number", "face": "x", "end": -1, "rect": [0.4, 5.2, 2.0, 5.8], "x": rx - 0.06})
    for xb, end in ((x0 - 0.05, -1), (x1 + 0.05, 1)):
        a, b = (xb - 0.55, xb) if end < 0 else (xb, xb + 0.55)
        shell.box_between((a, -2.05, -5.3), (b, -0.05, 5.3))
        for zz in (-5.1, 5.1):
            fit.box_between((a - 0.01, -2.02, zz - 0.18), (b + 0.01, -0.08, zz + 0.18))
        face = a if end < 0 else b
        for zz in (-3.6, 3.6):
            buffer(fit, face, end, -1.4, zz)
        if end < 0:
            # hook and link
            fit.box_between((face - 0.45, -1.55, -0.1), (face, -1.25, 0.1))
            fit.lathe([(0.16, -0.05), (0.16, 0.05)], (face - 0.55, -1.55, 0), "z", 10, caps=False)
        else:
            # the drawbar to the engine
            fit.box_between((face, -1.3, -0.16), (CAB[0] - 0.05, -1.0, 0.16))
    # front end: a coal gate between two tool lockers, the brake column
    fx = x1 + 0.05
    fit.box_between((fx, 4.0, -2.4), (fx + 0.06, TOPY, 2.4))
    for zz in (-2.4, 2.4):
        fit.box_between((fx, 4.0, zz - 0.08), (fx + 0.1, TOPY + 0.2, zz + 0.08))
    for zz, za, zb in ((1, 3.2, 5.85), (-1, -5.85, -3.2)):
        wood.box_between((x1 - 2.3, TOPY - 1.0, za), (x1 - 0.6, TOPY + 0.6, zb))
        wood.box_between((x1 - 2.4, TOPY + 0.6, za - 0.08), (x1 - 0.5, TOPY + 0.72, zb + 0.08))
        fit.box_between((x1 - 0.62, TOPY + 0.1, za + 0.4), (x1 - 0.55, TOPY + 0.3, za + 0.7))
    fit.cylinder((x1 - 1.2, TOPY + 0.8, -1.2), "y", 0.07, 1.8, 8)
    fit.lathe([(0.5, -0.03), (0.5, 0.03), (0.44, 0.03), (0.44, -0.03)], (x1 - 1.2, TOPY + 1.7, -1.2), "y", 16, caps=False)
    for k in range(3):
        a = k * math.pi / 3
        bar(fit, (x1 - 1.2 - 0.47 * math.cos(a), TOPY + 1.7, -1.2 - 0.47 * math.sin(a)),
            (x1 - 1.2 + 0.47 * math.cos(a), TOPY + 1.7, -1.2 + 0.47 * math.sin(a)), 0.05, 0.05)
    # rear deck over the tank with the water filler, and the coal bulkhead in front of it
    fit.box_between((x0 + 0.6, 6.5, -IN), (x0 + 3.4, 6.62, IN))
    fit.box_between((x0 + 3.4, 6.0, -IN), (x0 + 3.52, 7.5, IN))
    fz = -3.4
    fit.lathe([(1.05, 6.62), (1.05, 7.0), (1.16, 7.0), (1.16, 7.12)], (x0 + 1.9, 0, fz), "y", 20, caps=False)
    fit.lathe([(1.12, 7.12), (0.95, 7.28), (0.4, 7.36), (0.0, 7.38)], (x0 + 1.9, 0, fz), "y", 20)
    brass.cylinder((x0 + 0.78, 7.15, fz), "z", 0.08, 0.7, 8)
    brass.box_between((x0 + 2.85, 7.15, fz - 0.22), (x0 + 3.05, 7.35, fz + 0.22))
    spec["bogies"] = [29.0, 43.0]
    spec["kit"] = []
    return out, {f"{n}_Fittings": [f"{n}_Brass", f"{n}_Wood"]}


# -- the locomotive ------------------------------------------------------------------------------


def locomotive(spec):
    n = spec["name"]
    c0, c1 = CAB
    shell = Piece(f"{n}_Shell", "Body", "Paint")
    planks = Piece(f"{n}_Planks", "Body", "Planks")
    trim = Piece(f"{n}_Trim", "Trim", "Gilt")
    roof = Piece(f"{n}_Roof", "Roof", "Canvas")
    fit = Piece(f"{n}_Fittings", None, "Iron")
    brass = Piece(f"{n}_Brass", None, "Brass")
    teak = Piece(f"{n}_Teak", None, "Teak")
    boiler = Piece(f"{n}_Boiler", None, "Boiler")
    smoke = Piece(f"{n}_Smoke", None, "Smokebox")
    lagging = Piece(f"{n}_Lagging", None, "Boiler")
    glow = Piece(f"{n}_Glow", "Lamp", "Lamp")
    for p in (boiler, smoke, lagging):
        p.smooth = 40
    feat = new_feat()
    labels = []
    spec["feat"], spec["labels"] = feat, labels
    out = [shell, planks, trim, roof, fit, brass, teak, boiler, smoke, lagging, glow]
    SK, SKI = 6.58, 6.5
    TOP = 9.3
    door = (56.0, 60.0)
    win = (56.2, 59.8, 3.4, 7.0)

    # -- cab sides: a thin skin over the primitive walls (they stay the cab's inside) ------------
    for s in (1, -1):
        def slab(xa, ya, xb, yb):
            shell.box_between((xa, ya, s * SKI), (xb, yb, s * SK))

        if s > 0:
            slab(c0, -0.4, door[0], TOP)
            slab(door[1], -0.4, c1, TOP)
            slab(door[0], 7.0, door[1], TOP)
            lower = [(c0 + 0.4, 0.25, door[0] - 0.35, 3.15), (door[1] + 0.35, 0.25, c1 - 0.4, 3.15)]
            upper = [(c0 + 0.4, 3.5, door[0] - 0.35, 6.7), (door[1] + 0.35, 3.5, c1 - 0.4, 6.7)]
            feat["doorEdges"].append({"side": s, "x": list(door)})
        else:
            slab(c0, -0.4, c1, win[2])
            slab(c0, win[3], c1, TOP)
            slab(c0, win[2], win[0], win[3])
            slab(win[1], win[2], c1, win[3])
            lower = [(c0 + 0.4, 0.25, c1 - 0.4, 3.0)]
            upper = [(c0 + 0.4, 3.5, win[0] - 0.4, 6.7), (win[1] + 0.4, 3.5, c1 - 0.4, 6.7)]
            # the window: teak frame and glazing bar in the opening, a sill, a drip moulding over it
            xa, xb, ya, yb = win
            for a, b in (((xa, ya), (xa + 0.12, yb)), ((xb - 0.12, ya), (xb, yb)), ((xa, ya), (xb, ya + 0.12)), ((xa, yb - 0.12), (xb, yb))):
                teak.box_between((a[0], a[1], s * 6.3), (b[0], b[1], s * SKI))
            teak.box_between(((xa + xb) / 2 - 0.05, ya, s * 6.3), ((xa + xb) / 2 + 0.05, yb, s * 6.42))
            shell.box_between((xa - 0.3, ya - 0.22, s * SKI), (xb + 0.3, ya, s * 6.76))
            bead_line(trim, s, (xa - 0.35, yb + 0.22), (xb + 0.35, yb + 0.22), SK, BEAD)
            feat["ledges"].append({"side": s, "x": [xa - 0.3, xb + 0.3], "y": ya - 0.22})
            feat["windows"].append({"side": s, "x": (xa + xb) / 2})
        for r in lower:
            bead_loop(trim, s, round_rect(*r, 0.25, 2), SK)
            feat["panels"].append({"side": s, "rect": list(r), "kind": "crest"})
            feat["ledges"].append({"side": s, "x": [r[0], r[2]], "y": r[1]})
        for r in upper:
            bead_loop(trim, s, round_rect(*r, 0.25, 2), SK)
            feat["panels"].append({"side": s, "rect": list(r), "kind": "upper"})
        frieze = (c0 + 0.4, 7.45, c1 - 0.4, 9.0)
        bead_loop(trim, s, round_rect(*frieze, 0.2, 2), SK, BEAD)
        feat["panels"].append({"side": s, "rect": list(frieze), "kind": "eaves"})
        # corner beads and a waist bead
        for xx in (c0, c1):
            trim.cylinder((xx, (TOP - 0.4) / 2, s * SK), "y", 0.06, TOP + 0.4, 8)
        # the nameplate over the door (over the window on the far side)
        np_ = Piece(f"{n}_plateN{'P' if s > 0 else 'N'}", None, "Sign")
        np_.box_between((56.5, 7.75, s * SK), (59.5, 8.65, s * 6.66))
        out.append(np_)
        labels.append({"piece": np_.name, "label": "nameplate", "side": s, "rect": [56.5, 7.75, 59.5, 8.65], "z": 6.66})
        feat["ledges"].append({"side": s, "x": [56.5, 59.5], "y": 7.75})
        # grab irons clear of the door leaves' slide (53.95..62.05)
        for xx in ((53.55, 62.45) if s > 0 else (c0 + 0.5, c1 - 0.5)):
            brass.cylinder((xx, 3.0, s * 6.82), "y", 0.05, 4.6, 8)
            for y in (0.9, 5.1):
                fit.cylinder((xx, y, s * 6.7), "z", 0.035, 0.26, 6)
            feat["grips"].append({"side": s, "x": xx, "y": [0.9, 5.1]})
        # the valance under the cab, with a step under the door
        fit.box_between((c0 - 0.1, -1.05, s * 6.42), (c1, -0.4, s * 6.62))
        rivet_row(fit, feat, s, c0 + 0.2, c1 - 0.2, -0.72, 6.62, 0.7)
        feat["ledges"].append({"side": s, "x": [c0, c1], "y": -1.05, "iron": True})
        if s > 0:
            for xx in (56.4, 59.6):
                bar(fit, (xx, -1.0, s * 6.55), (xx, -1.95, s * 6.72), 0.12, 0.06, (0, 0, 1))
            fit.box_between((56.2, -2.02, s * 6.0), (59.8, -1.9, s * 6.88))
            feat["steps"].append({"side": s, "x": [56.2, 59.8]})

    # -- cab front (spectacles either side of the boiler) and back sheets ------------------------
    shell.box_between((c1, -0.4, -SK), (c1 + 0.12, TOP, SK))
    for zz in (-4.95, 4.95):
        lathe_x(brass, [(0.78, c1 + 0.12), (0.78, c1 + 0.2), (0.6, c1 + 0.2), (0.6, c1 + 0.14)], 7.5, zz, 18, caps=False)
        lathe_x(glow, [(0.62, c1 + 0.12), (0.62, c1 + 0.15)], 7.5, zz, 18)
        teak.box_between((c1 + 0.13, 7.47, zz - 0.6), (c1 + 0.17, 7.53, zz + 0.6))
    shell.box_between((c0 - 0.12, -0.4, -SK), (c0, TOP, SK))
    for r in ((-6.0, 0.4, -0.5, 3.4), (0.5, 0.4, 6.0, 3.4), (-6.0, 3.8, 6.0, 8.6)):
        z0_, y0_, z1_, y1_ = r
        end_bead_loop(trim, -1, round_rect(z0_, y0_, z1_, y1_, 0.25, 2), c0 - 0.12)
    for zz in (-6.2, 6.2):
        for xx, e in ((c0 - 0.12, -1), (c1 + 0.12, 1)):
            trim.cylinder((xx, (TOP - 0.4) / 2, zz * SK / 6.2), "y", 0.06, TOP + 0.4, 8)
        brass.cylinder((c0 - 0.35, 4.4, zz * 0.93), "y", 0.05, 5.2, 8)
        for y in (2.0, 6.8):
            fit.cylinder((c0 - 0.24, y, zz * 0.93), "x", 0.035, 0.24, 6)

    # -- cab roof: an arch with deep eaves and fascia, seam ribs and a louvred ventilator ---------
    RZ, RY, RISE = 7.1, 9.85, 0.72

    def arch(z, off=0.0):
        t = min(1.0, abs(z) / RZ)
        return RY + RISE * (1 - t * t) + off

    segs = 16
    zs = [-RZ + 2 * RZ * k / segs for k in range(segs + 1)]
    outer = [(arch(z), z) for z in zs]
    zi = [-(RZ - 0.08) + 2 * (RZ - 0.08) * k / segs for k in range(segs + 1)]
    inner = [(arch(z, -0.1), z) for z in zi]
    prof = [(9.22, -RZ)] + outer + [(9.22, RZ), (9.22, RZ - 0.08)] + list(reversed(inner)) + [(9.22, -(RZ - 0.08))]
    roof.prism_x(prof, c0 - 1.0, c1 + 1.0)
    for xx in (c0 - 1.0, c1 + 0.92):
        roof.prism_x([(9.22, -RZ + 0.08)] + [(arch(z, -0.1), z) for z in zi[1:-1]] + [(9.22, RZ - 0.08)], xx, xx + 0.08)
    for k in range(1, 8):
        xx = c0 - 1.0 + k * (c1 - c0 + 2.0) / 8
        roof.prism_x([(arch(z, 0.035), z) for z in zs] + [(arch(z, -0.01), z) for z in reversed(zs)], xx - 0.04, xx + 0.04)
    vx0, vx1 = 56.6, 59.4
    roof.box_between((vx0, arch(0) - 0.15, -1.1), (vx1, arch(0) + 0.45, 1.1))
    roof.box_between((vx0 - 0.2, arch(0) + 0.45, -1.32), (vx1 + 0.2, arch(0) + 0.57, 1.32))
    for zz in (-1.12, 1.12):
        for k in range(5):
            xx = vx0 + 0.3 + k * (vx1 - vx0 - 0.6) / 4
            roof.box_between((xx - 0.18, arch(0) + 0.0, zz - 0.04), (xx + 0.18, arch(0) + 0.38, zz + 0.04))
    feat["vents"].append({"x": 58.0, "z": 0.0})

    # -- boiler, firebox, smokebox ---------------------------------------------------------------
    by, br = BOILER_Y, BOILER_R
    lathe_x(boiler, [(br, c1 - 0.05), (br, 88.05)], by, 0, 48)
    for xx in (66.5, 70.0, 75.0, 80.0, 84.5, 87.6):
        lathe_x(trim, [(br + 0.01, xx - 0.14), (br + 0.07, xx - 0.1), (br + 0.07, xx + 0.1), (br + 0.01, xx + 0.14)], by, 0, 48, caps=False)
    # wagon-top firebox under the boiler's back end, foundation ring, washout plugs, ash pan
    fb = (c1 + 0.05, 68.4)
    boiler.box_between((fb[0], 0.7, -3.15), (fb[1], 5.0, 3.15))
    fit.box_between((fb[0] - 0.02, 0.5, -3.25), (fb[1] + 0.05, 0.78, 3.25))
    for s in (1, -1):
        brass.rivets([(xx, 2.6, s * 3.15) for xx in (65.0, 66.3, 67.6)], (0, 0, s), 0.1, 0.05, 8)
        feat["boilerFittings"].append({"x": 66.3, "y": 2.6, "side": s, "w": 0.9})
    fit.box_between((fb[0] + 0.2, -0.95, -2.7), (fb[1] - 0.3, 0.5, 2.7))
    glow.box_between((fb[0] + 0.35, -1.05, -2.45), (fb[1] - 0.45, -0.95, 2.45))
    # smokebox with its front ring and dished door, hinge straps and dart handle
    lathe_x(smoke, [(SMOKEBOX_R, 87.95), (SMOKEBOX_R, 94.0), (4.32, 94.0), (4.32, 94.14), (3.92, 94.14), (3.92, 94.3),
                    (3.62, 94.36), (2.9, 94.52), (1.8, 94.64), (0.6, 94.7), (0.0, 94.71)], by, 0, 48)
    trim.rivets([(87.98, by + 4.25 * math.cos(a), 4.25 * math.sin(a)) for a in [2 * math.pi * k / 24 for k in range(24)]], (-1, 0, 0), 0.06, 0.03, 6)
    for dy in (-1.7, 1.7):
        pts = []
        for k in range(9):
            zz = -3.0 + 6.2 * k / 8
            rr = math.hypot(zz, dy)
            pts.append((dish_x(rr) + 0.04, by + dy, zz))
        tube(fit, pts, 0.09, 6)
        fit.cylinder((94.25, by + dy, 3.45), "y", 0.12, 0.5, 8)
    lathe_x(brass, [(0.36, 94.68), (0.36, 94.84), (0.22, 94.9), (0.0, 94.91)], by, 0, 14)
    for a, b in (((94.88, by, -0.85), (94.88, by, 0.85)), ((94.88, by - 0.85, 0), (94.88, by + 0.85, 0))):
        bar(brass, a, b, 0.1, 0.1, (1, 0, 0))
    # saddle under the smokebox, the stack on it (balloon: a narrow neck flaring to a wide crown)
    fit.box_between((88.6, 0.3, -3.3), (93.4, 2.6, 3.3))
    lathe_x(fit, [(0.0, 88.55), (1.6, 88.55)], 1.45, 0, 4, caps=False)
    stack = [(1.45, 9.6), (1.45, 10.75), (1.05, 11.0), (0.9, 11.5), (0.95, 12.4), (1.2, 13.2), (1.65, 14.0), (2.0, 14.8), (2.1, 15.25)]
    smoke.lathe(stack, (91.0, 0, 0), "y", 28, caps=False)
    brass.lathe([(2.12, 15.2), (2.2, 15.25), (2.2, 15.72), (2.12, 15.78)], (91.0, 0, 0), "y", 28, caps=False)
    smoke.lathe([(2.1, 15.25), (2.1, 15.75), (1.9, 15.8), (1.2, 15.94), (0.0, 15.98)], (91.0, 0, 0), "y", 28)
    feat["boilerFittings"].append({"x": 91.0, "y": 10.6, "w": 1.6})

    # -- domes, bell, whistle, safety valves (on the boiler's top) -------------------------------
    for dx, r, top in ((80.0, 1.5, 13.25), (71.0, 1.2, 12.5)):
        h = top - 9.3
        prof = [(r + 0.25, 9.3), (r + 0.25, 10.3), (r + 0.1, 10.45), (r, 10.6), (r, 9.3 + h * 0.7), (r + 0.08, 9.3 + h * 0.72), (r + 0.08, 9.3 + h * 0.76),
                (r - 0.06, 9.3 + h * 0.8), (r * 0.8, 9.3 + h * 0.9), (r * 0.5, 9.3 + h * 0.97), (0.0, top)]
        trim.lathe(prof, (dx, 0, 0), "y", 28)
        feat["boilerFittings"].append({"x": dx, "y": 10.3, "w": r * 0.9})
    for dz in (-0.42, 0.42):
        brass.lathe([(0.17, 12.9), (0.17, 13.55), (0.24, 13.6), (0.24, 13.72), (0.0, 13.78)], (80.0, 0, dz), "y", 10)
    bar(brass, (79.6, 13.8, 0), (80.6, 13.8, 0), 0.06, 0.06)
    # the bell on its yoke
    bx = 75.5
    fit.lathe([(0.62, 9.9), (0.62, 10.4), (0.45, 10.5), (0.45, 10.62), (0.0, 10.62)], (bx, 0, 0), "y", 12)
    fit.box_between((bx - 0.12, 10.55, -1.05), (bx + 0.12, 10.7, 1.05))
    for dz in (-0.98, 0.98):
        fit.box_between((bx - 0.1, 10.6, dz - 0.07), (bx + 0.1, 12.45, dz + 0.07))
    fit.cylinder((bx, 12.25, 0), "z", 0.06, 2.1, 8)
    brass.lathe([(0.82, 11.0), (0.8, 11.12), (0.62, 11.3), (0.52, 11.7), (0.46, 12.1), (0.38, 12.25), (0.2, 12.33), (0.0, 12.34)], (bx, 0, 0), "y", 20)
    # whistle on the firebox top by the cab, safety valves behind the sand dome
    wz = 1.2
    fit.cylinder((64.8, 10.4, wz), "y", 0.08, 1.0, 8)
    brass.lathe([(0.18, 10.85), (0.2, 11.0), (0.26, 11.02), (0.26, 11.75), (0.3, 11.8), (0.22, 11.95), (0.08, 12.05), (0.0, 12.06)], (64.8, 0, wz), "y", 14)
    bar(brass, (64.8, 10.95, wz), (64.2, 10.8, wz + 0.2), 0.05, 0.05)
    for dz in (-0.4, 0.4):
        brass.lathe([(0.16, 9.9), (0.16, 10.75), (0.22, 10.8), (0.22, 10.98), (0.0, 11.04)], (66.4, 0, dz), "y", 10)
    bar(brass, (66.0, 11.08, 0), (67.0, 11.08, 0), 0.06, 0.06)

    # -- headlamp box on its platform (the primitive Headlamp's neon and beam stay inside) --------
    fit.box_between((92.9, 10.3, -1.35), (95.7, 10.5, 1.35))
    for dz in (-1.0, 1.0):
        bar(fit, (95.3, 10.32, dz), (94.2, 9.95, dz), 0.12, 0.08, (0, 0, 1))
    hx0, hx1, hy0, hy1, hz = 93.05, 95.55, 10.5, 12.95, 1.3
    fit.box_between((hx0, hy0, -hz), (hx1, hy1, hz))
    for zz in (-hz, hz):
        for yy in (hy0, hy1):
            brass.cylinder(((hx0 + hx1) / 2, yy, zz), "x", 0.05, hx1 - hx0, 6)
    for zz in (-hz, hz):
        brass.cylinder((hx1, (hy0 + hy1) / 2, zz), "y", 0.05, hy1 - hy0, 6)
    ap = (10.6, 12.6, 1.0)
    for a, b in (((hx1, ap[0] - 0.2, -ap[2] - 0.2), (hx1 + 0.2, ap[0], ap[2] + 0.2)), ((hx1, ap[1], -ap[2] - 0.2), (hx1 + 0.2, ap[1] + 0.2, ap[2] + 0.2)),
                 ((hx1, ap[0], -ap[2] - 0.2), (hx1 + 0.2, ap[1], -ap[2])), ((hx1, ap[0], ap[2]), (hx1 + 0.2, ap[1], ap[2] + 0.2))):
        brass.box_between(a, b)
    fit.prism_x([(hy1, -hz - 0.25), (hy1 + 0.7, 0.0), (hy1, hz + 0.25), (hy1 - 0.08, hz + 0.25), (hy1 + 0.6, 0.0), (hy1 - 0.08, -hz - 0.25)], hx0 - 0.15, hx1 + 0.3)
    fit.lathe([(0.2, hy1 + 0.4), (0.2, hy1 + 0.95), (0.3, hy1 + 1.0), (0.3, hy1 + 1.08), (0.0, hy1 + 1.12)], (hx0 + 0.7, 0, 0), "y", 8)
    feat["boilerFittings"].append({"x": 94.3, "y": 10.3, "w": 1.0})

    # -- cylinders and valve chests, guides ------------------------------------------------------
    for s in (1, -1):
        cz = s * 4.45
        lathe_x(lagging, [(1.15, 89.3), (1.15, 93.7)], 0.2, cz, 24)
        lathe_x(fit, [(1.24, 93.68), (1.24, 93.85), (0.95, 93.98), (0.0, 94.02)], 0.2, cz, 24)
        lathe_x(fit, [(0.0, 88.98), (0.95, 89.02), (1.24, 89.15), (1.24, 89.32)], 0.2, cz, 24)
        for xx in (89.42, 93.58):
            lathe_x(brass, [(1.16, xx - 0.06), (1.19, xx - 0.04), (1.19, xx + 0.04), (1.16, xx + 0.06)], 0.2, cz, 24, caps=False)
        fit.box_between((89.55, 1.05, s * 3.75), (93.45, 1.95, s * 5.15))
        fit.box_between((89.45, 1.9, s * 3.65), (93.55, 2.02, s * 5.25))
        for y in (-0.1, 0.55):
            fit.box_between((84.3, y - 0.07, s * 4.95), (89.0, y + 0.07, s * 5.15))
        fit.box_between((88.8, -0.35, s * 4.8), (89.05, 0.8, s * 5.25))
        lathe_x(fit, [(0.11, 84.4), (0.11, 89.0)], 0.22, cz, 8)
        feat["boilerFittings"].append({"x": 91.5, "y": 1.3, "side": s, "w": 1.8})

    # -- frames, axle boxes and springs, running boards and the lined valance --------------------
    for s in (1, -1):
        fit.box_between((c1 - 0.2, -1.7, s * 2.9), (95.1, 1.5, s * 3.2))
        rivet_row(fit, feat, s, 64.5, 94.5, 1.25, 3.2, 0.8, 0.04)
        for ax in (70.5, 79.5):
            fit.box_between((ax - 0.55, -3.05, s * 3.2), (ax + 0.55, -1.75, s * 3.85))
            for k, w in enumerate((3.2, 2.7, 2.2, 1.7)):
                fit.box_between((ax - w / 2, -1.7 + k * 0.1, s * 3.25), (ax + w / 2, -1.6 + k * 0.1, s * 3.75))
            fit.cylinder((ax, -2.4, 0), "z", 0.26, 2 * 4.95, 10) if s > 0 else None
        bar(fit, (71.6, -1.3, s * 3.5), (78.4, -1.3, s * 3.5), 0.3, 0.22)
        # running board: plate, edge angle, lined valance with a gilt bead along its foot
        rb0, rb1 = c1 + 0.2, 89.2
        fit.box_between((rb0, 1.75, s * 4.15), (rb1, 2.05, s * 6.3))
        fit.box_between((rb0, 1.55, s * 6.2), (rb1, 2.08, s * 6.32))
        shell.box_between((rb0, 0.95, s * 6.18), (rb1, 1.55, s * 6.26))
        bead_line(trim, s, (rb0, 0.98), (rb1, 0.98), 6.26)
        rivet_row(fit, feat, s, rb0 + 0.2, rb1 - 0.2, 1.82, 6.32, 0.8, 0.04)
        feat["ledges"].append({"side": s, "x": [rb0, rb1], "y": 0.95, "iron": True})
        feat["panels"].append({"side": s, "rect": [rb0 + 0.1, 0.98, rb1 - 0.1, 1.53], "kind": "crest"})
        # the deck in front of the cylinders, up to the buffer beam
        fit.box_between((93.8, 1.75, s * 3.3), (95.1, 2.05, s * 6.0))
        # handrails along the boiler on knobbed stanchions
        hz_ = 4.48
        brass.cylinder((78.6, 7.0, s * hz_), "x", 0.06, 27.2, 8)
        for xx in (65.6, 70.0, 74.5, 79.0, 83.5, 87.5, 91.8):
            rr = SMOKEBOX_R if xx > 88 else BOILER_R
            zb = math.sqrt(rr * rr - (7.0 - by) ** 2)
            fit.cylinder((xx, 7.0, s * (zb + hz_) / 2), "z", 0.04, hz_ - zb + 0.05, 6)
            fit.lathe([(0.0, -0.09), (0.08, -0.06), (0.09, 0.0), (0.08, 0.06), (0.0, 0.09)], (xx, 7.0, s * hz_), "z", 8)
            feat["boilerFittings"].append({"x": xx, "y": 6.9, "side": s, "w": 0.2})
        # sand pipe from the sand dome to the rail ahead of the leading driver
        tube(brass, [(71.4, 10.3, s * 0.9), (72.0, 9.7, s * 2.55), (72.6, 7.4, s * 3.95), (73.0, 4.0, s * 4.3), (73.3, 0.6, s * 4.55), (73.55, -3.9, s * 5.2)], 0.07, 6)
        # feed pipe from the injector under the cab, along the boiler to the clack valve
        tube(fit, [(c1 + 0.2, 0.6, s * 3.45), (c1 + 0.8, 3.6, s * 3.45), (82.6, 3.6, s * 3.45), (83.7, 5.6, s * 3.95), (84.0, 6.4, s * 4.0)], 0.08, 6)
        brass.box_between((83.7, 6.25, s * 3.85), (84.3, 6.85, s * 4.2))
        brass.lathe([(0.12, 6.85), (0.12, 7.05), (0.0, 7.08)], (84.0, 0, s * 4.02), "y", 8)
        feat["boilerFittings"].append({"x": 84.0, "y": 6.2, "side": s, "kind": "scale", "w": 0.4})

    # -- buffer beam, buffers, hook, number plate, the slatted pilot -----------------------------
    bx0, bx1 = 95.1, 96.15
    planks.box_between((bx0, -1.35, -6.1), (bx1, 0.95, 6.1))
    for zz in (-6.0, 6.0):
        fit.box_between((bx0 - 0.02, -1.38, zz - 0.18), (bx1 + 0.03, 0.98, zz + 0.18))
    for zz in (-4.0, 4.0):
        buffer(fit, bx1, 1, -0.2, zz)
    fit.box_between((bx1, -0.75, -0.12), (bx1 + 0.5, -0.45, 0.12))
    fit.lathe([(0.17, -0.05), (0.17, 0.05)], (bx1 + 0.62, -0.75, 0), "z", 10, caps=False)
    nump = Piece(f"{n}_plateNum", None, "Sign")
    nump.box_between((bx1, 0.2, -0.85), (bx1 + 0.06, 0.8, 0.85))
    out.append(nump)
    labels.append({"piece": nump.name, "label": "number", "face": "x", "end": 1, "rect": [-0.85, 0.2, 0.85, 0.8], "x": bx1 + 0.06})
    for i in range(-4, 5):
        z = i * 1.25
        front = 99.4 - abs(z) * 0.4
        bar(planks, (96.2, -1.3, z), (front, -4.6, z * 1.04), 0.24, 0.2, (0, 0, 1))
    tube(fit, [(99.4 - 5.2 * 0.4, -4.6, -5.4), (99.4, -4.6, 0.0), (99.4 - 5.2 * 0.4, -4.6, 5.4)], 0.11, 6)
    bar(fit, (96.2, -1.42, -5.3), (96.2, -1.42, 5.3), 0.22, 0.18, (0, 1, 0))
    fit.box_between((99.0, -4.45, -0.28), (99.75, -3.95, 0.28))
    # builder's plates on the smokebox sides
    for s in (1, -1):
        pl = Piece(f"{n}_plateB{'P' if s > 0 else 'N'}", None, "Sign")
        pl.box_between((90.4, 5.9, s * 4.24), (91.6, 6.55, s * 4.3))
        out.append(pl)
        labels.append({"piece": pl.name, "label": "builders", "side": s, "rect": [90.4, 5.9, 91.6, 6.55], "z": 4.3})

    # -- the cab door's own leaves: framed and panelled, a glazing slit for the sliding glass ------
    joins, anchors = {}, {}
    zb, zf, zt = 6.62, 6.78, 6.86
    for key, cxl, meeting in (("DoorLeafL", 57.0, 1), ("DoorLeafR", 59.0, -1)):
        pn = f"{n}_{key}"
        lp = Piece(pn, "Accent", "Planks")
        li = Piece(pn + "_iron", None, "Iron")
        lb = Piece(pn + "_brass", None, "Brass")
        hw = 1.0
        gx, gy0, gy1 = 0.38, 3.55, 5.85  # the glass (0.7 x 2.2 at y 4.7) slides in this slit
        for a, b in (((cxl - hw, 0.0), (cxl + hw, gy0)), ((cxl - hw, gy1), (cxl + hw, 7.0)), ((cxl - hw, gy0), (cxl - gx, gy1)), ((cxl + gx, gy0), (cxl + hw, gy1))):
            lp.box_between((a[0], a[1], zb), (b[0], b[1], zf))
        for a, b in (((cxl - hw, 0.0), (cxl - hw + 0.28, 7.0)), ((cxl + hw - 0.28, 0.0), (cxl + hw, 7.0)), ((cxl - hw + 0.28, 0.0), (cxl + hw - 0.28, 0.45)),
                     ((cxl - hw + 0.28, 2.95), (cxl + hw - 0.28, 3.35)), ((cxl - hw + 0.28, 6.55), (cxl + hw - 0.28, 7.0))):
            lp.box_between((a[0], a[1], zf), (b[0], b[1], zt))
        for ya, yb in ((0.45, 2.95),):
            lp.box_between((cxl - hw + 0.42, ya + 0.14, zf), (cxl + hw - 0.42, yb - 0.14, zf + 0.04))
        teak.box_between((cxl - gx - 0.06, gy0 - 0.06, zf), (cxl + gx + 0.06, gy0, zt))
        mx = cxl + meeting * (hw - 0.2)
        lb.cylinder((mx, 3.2, 6.89), "y", 0.035, 1.2, 6)
        for y in (2.7, 3.7):
            li.box_between((mx - 0.04, y - 0.04, zt), (mx + 0.04, y + 0.04, 6.9))
        feat["grips"].append({"side": 1, "x": mx, "y": [2.6, 3.8]})
        out += [lp, li, lb]
        joins[pn] = [pn + "_iron", pn + "_brass"]
        anchors[key] = [cxl, 3.5, 6.74]
    spec["leafJoins"] = joins
    spec["leafAnchors"] = anchors
    spec["bogies"] = [70.5, 79.5, 90.0]
    spec["kit"] = [[f"DriveWheel{t}", [x, -2.4, s * 5.3], True] for x in (70.5, 79.5) for s, t in ((1, "P"), (-1, "N"))]
    spec["kit"] += [[f"Rod{t}", [75.0, -1.3, s * 5.95], False] for s, t in ((1, "P"), (-1, "N"))]
    spec["smokeboxX"] = 88.0
    return out, {
        f"{n}_Shell": [f"{n}_Planks"],
        f"{n}_Fittings": [f"{n}_Brass", f"{n}_Teak"],
        f"{n}_Boiler": [f"{n}_Smoke", f"{n}_Lagging"],
    }


# -- which primitives the meshes replace ---------------------------------------------------------

INTERIOR = {"DoorBlocker", "DoorPanel", "Seat", "Firebox", "FireFlame", "FireDoor", "GaugeLamp", "Headlamp", "SteamVent",
            "Breach_CAB", "DoorSign", "DoorSignRim", "Nameboard"}


def retire_list(dump, car, x0, x1):
    """Every primitive the car's meshes stand in for, as [cx, cy, cz, sx, sy, sz] (train space). The
    runtime hides the colliding ones (and ChimneyTop, whose smoke it keeps) and archives the rest.
    Wheels, rods, coal and the bogies are matched at runtime by attribute and size instead."""
    out = []
    for p in dump:
        x, y, z = p["cf"][:3]
        sx, sy, sz = p["size"]
        if not (x0 <= x < x1):
            continue
        a = p["attrs"]
        if p["name"] in INTERIOR or "WheelRadius" in a or "CrankRadius" in a or "CoalTier" in a:
            continue
        # extent below: a rotated part's half height is at most its half diagonal
        rot = p["cf"][3:] != [1, 0, 0, 0, 1, 0, 0, 0, 1]
        half_y = (math.sqrt(sx * sx + sy * sy + sz * sz) if rot else sy) / 2
        if y + half_y <= -2.3 or (p["material"] == "Wood" and abs(sx - 0.7) < 0.01 and abs(sy - 2.5) < 0.01):
            continue  # bogie (the runtime's kit) and the Mansell wheels' teak centres
        role = a.get("Livery")
        if car == "Tender":
            take = (
                p["name"] == "TenderLettering"
                or role in ("Body", "Trim")
                or (p["shape"] == "Cylinder" and p["material"] == "Metal")  # buffers and the filler
                or (abs(sx - 26) < 0.01 and abs(sy - 1) < 0.01)  # the frame slab under the tank
            )
        elif x >= CAB[1]:
            take = True  # boiler, smokebox, stack, domes, frames, running gear dressing, beam, pilot, lamp box
        elif x < CAB[0] - 0.3:
            take = p["shape"] == "Cylinder"  # the buffers to the tender
        else:
            # the cab: its walls, floor, roof and everything inside stay
            take = (
                p["name"] == "Nameplate"
                or role == "Trim"
                or (p["material"] == "Wood" and 6.0 <= abs(z) <= 6.6)  # the far window's arch, mullion and sill
                or (abs(y - 10.4) < 0.01 and abs(sx - 3) < 0.01)  # the roof ventilator
            )
        if take:
            out.append([round(v, 3) for v in (x, y, z, sx, sy, sz)])
    return out


def build(spec, dump):
    car = spec["name"]
    pieces, joins = (tender if car == "Tender" else locomotive)(spec)
    x0, x1 = RANGES[car]
    spec["retire"] = retire_list(dump, car, x0, x1)
    return pieces, joins
