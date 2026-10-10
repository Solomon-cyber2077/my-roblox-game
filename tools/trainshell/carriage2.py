"""
Round 2 of the panelled clerestory carriage: the same envelope as carriage.py, but the side is
carved instead of painted. Depth comes from cutting INTO a thick skin (the primitive side walls are
hidden behind it at runtime, so recesses cost no clearance), with real mouldings, beading and
hardware standing proud only where the door leaves never pass.

Pieces (each one MeshPart):
  <car>_Shell     Livery Body: carved side skins, ends, cornice, frieze, window surrounds, pilasters,
                  corbels and dentils, clerestory skin
  <car>_Trim      Livery Trim: half-round gilt beading, pilaster capitals, keystones
  <car>_Roof      Livery Roof: cambered roof with seams, gutters, clerestory cap, lamp-tops, vents
  <car>_Fittings  untinted: iron (solebar, straps, bolts, track, step, buffers, coupling, underframe),
                  brass (grab rails, lamp, curtain rails, plates' rims), teak glazing bars, velvet
                  curtains, the gangway bellows over the gap in front of the car
  <car>_Lens      Livery Lamp (Neon + the door light): the door lamp's glass
  <car>_Glow      Livery Lamp (Neon, no light): leaded fanlights over the windows
  <car>_Haze      Livery Lamp (Neon, mostly transparent): warm veil over the window glass
  <car>_Sign      the name boards and cast plates (own texture, make_sign2.py)

Envelope (docs/train-exterior/DESIGN_BIBLE.md): skin face z 6.58; in a door's slide zone nothing
stands proud of 6.64 below y 7.5; nothing beyond |z| 6.92 anywhere.

Every wear mark bake2.py paints has a cause, so this module also records where the causes are
(spec["feat"]): panels, ledges, rivets, grab rails, the step, door edges, vents.
"""

import math
from types import SimpleNamespace

import identity
from kit import Piece, V, arch_outline, cutter_object, offset_outline, on_end, on_side, rect_outline

SKIN_IN, SKIN = 6.32, 6.58  # the skin is a thick slab; the wall primitive behind it is hidden
TOP = 8.85
EAVE_Y, EAVE_Z = 9.78, 6.82
MON_Z = 2.27
WIN_W, WIN_SILL, WIN_SPRING, WIN_CROWN = 3.36, 3.5, 6.15, 6.88
DOOR_W, DOOR_H = 5.56, 7.48
SLIDE_TOP = 7.5
SLIDE_MAX = 6.64
FREE_MAX = 6.9
GAP = 3.0  # between two cars

# heights of the side's bands
SOLE = (0.0, 0.34)
LOWER = (0.34, 2.68)
LRAIL = (2.68, 2.98)
WAIST = (2.98, 3.34)
UPPER = (3.62, 6.84)
FRIEZE = (6.84, 7.06)
EAVES = (7.06, 8.5)
DENTIL = (8.52, 8.74)

BEAD = [(0.045, 0.0), (0.039, 0.024), (0.022, 0.04), (0.0, 0.046), (-0.022, 0.04), (-0.039, 0.024), (-0.045, 0.0)]
FINE_BEAD = [(0.03, 0.0), (0.021, 0.022), (0.0, 0.03), (-0.021, 0.022), (-0.03, 0.0)]


def roof_y(z):
    t = min(abs(z), EAVE_Z) / EAVE_Z
    return 10.06 - (10.06 - EAVE_Y) * t * t


def bolection(depth, proud):
    """Moulding over a recess edge: on the skin outside (across < 0), rolling over the edge and
    stepping down into the recess (across > 0); `out` is measured from the skin face."""
    d = depth
    return [
        (-0.09, 0.0), (-0.085, proud * 0.5), (-0.06, proud), (-0.01, proud), (0.02, proud * 0.8),
        (0.045, proud * 0.2), (0.06, -d * 0.35), (0.09, -d * 0.6), (0.13, -d + 0.02), (0.16, -d),
        (0.0, -d),
    ]


def spans_minus(spans, a, b):
    out = []
    for fa, fb in spans:
        if fa < a:
            out.append((fa, min(fb, a)))
        if fb > b:
            out.append((max(fa, b), fb))
    return [(p, q) for p, q in out if q - p > 1e-3]


def build(spec, col):
    x0, x1 = spec["x0"], spec["x1"]
    cx = (x0 + x1) / 2
    name = spec["name"]
    shell = Piece(f"{name}_Shell", "Body", "Paint")
    trim = Piece(f"{name}_Trim", "Trim", "Gilt")
    roof = Piece(f"{name}_Roof", "Roof", "Canvas")
    lens = Piece(f"{name}_Lens", "Lamp", "Lamp")
    glow = Piece(f"{name}_Glow", "Lamp", "Lamp")
    haze = Piece(f"{name}_Haze", "Lamp", "Lamp")
    sign = Piece(f"{name}_Sign", None, "Sign")
    fit = Piece(f"{name}_Fittings", None, "Iron")
    brass = Piece(f"{name}_Brass", None, "Brass")
    teak = Piece(f"{name}_Teak", None, "Teak")
    velvet = Piece(f"{name}_Velvet", None, "Velvet")
    bellows = Piece(f"{name}_Bellows", None, "Bellows")
    crate = Piece(f"{name}_Crate", None, "Crate")
    tarp = Piece(f"{name}_Tarp", None, "Tarp")
    extra = []
    # "saloon": panelled, gilt-beaded, arched curtained windows; "van": matchboarded framing, square
    # windows behind bars or mesh, plain cornice (Workshop, Stores, Guard's van)
    van = spec.get("style", "saloon") == "van"
    feat = {"panels": [], "ledges": [], "rivets": [], "grips": [], "steps": [], "doorEdges": [],
            "vents": [], "straps": [], "plates": [], "windows": [], "boards": [], "lamps": []}
    labels = []  # (piece, label name, rect in train space, side) for make_sign2's atlas
    spec["feat"] = feat
    spec["labels"] = labels
    lights = []

    def doors(side):
        return spec["doors"].get(side, [])

    def windows(side):
        return spec["windows"].get(side, [])

    def slide_zones(side):
        return [(d - DOOR_W - 0.3, d + DOOR_W + 0.3) for d in doors(side)]

    def in_slide(side, xa, xb):
        return any(xa < b and xb > a for a, b in slide_zones(side))

    def zmax(side, xa, xb, ya=0.0):
        return SLIDE_MAX if (ya < SLIDE_TOP and in_slide(side, xa, xb)) else FREE_MAX

    def zz(side, z):
        return side * z

    def zbox(piece, side, xa, ya, za, xb, yb, zb):
        """box_between with z given as distances from the car's centre line on one side."""
        piece.box_between((xa, ya, side * za), (xb, yb, side * zb))

    # ---------------------------------------------------------------------------------
    # side skins
    for side in (-1, 1):
        cuts_open = []
        cuts_recess = []
        for wx in windows(side):
            o = rect_outline(wx - WIN_W / 2, WIN_SILL, wx + WIN_W / 2, WIN_CROWN) if van else arch_outline(wx, WIN_SILL, WIN_W, WIN_SPRING, WIN_CROWN)
            cuts_open.append(o)
        door_rects = []
        for d in doors(side):
            door_rects.append(rect_outline(d - DOOR_W / 2, -0.3, d + DOOR_W / 2, DOOR_H))

        # -- the bay layout: vertical members (posts) and the panels between them --------
        corner = 0.56
        free = [(x0 + corner, x1 - corner)]
        for d in doors(side):
            free = spans_minus(free, d - DOOR_W / 2 - 0.34, d + DOOR_W / 2 + 0.34)
        win_bays = [(wx - WIN_W / 2 - 0.62, wx + WIN_W / 2 + 0.62) for wx in windows(side)]

        def split(spans, width, post=0.34):
            """Divide each span into panels about `width` long with posts between."""
            out = []
            for a, b in spans:
                n = max(1, round((b - a) / width))
                step = (b - a + post) / n
                for k in range(n):
                    pa = a + k * step
                    out.append((pa, pa + step - post))
            return out

        lower = split(free, 3.0)
        upper_spans = free
        for a, b in win_bays:
            upper_spans = spans_minus(upper_spans, a - 0.34, b + 0.34)
        upper = split(upper_spans, 2.4)
        posts = []  # x centres of the vertical members between upper panels (pilasters)
        for (a, b), (c, _) in zip(upper[:-1], upper[1:]):
            if c - b < 0.8:
                posts.append((b + c) / 2)
        for a, b in win_bays:
            for p in (a, b):
                if any(fa - 0.01 <= p <= fb + 0.01 for fa, fb in free):
                    posts.append(p)

        # the name board: the longest eaves stretch clear of a door lamp
        board_spans = [(x0 + 0.7, x1 - 0.7)]
        for d in doors(side):
            board_spans = spans_minus(board_spans, d - DOOR_W / 2 - 0.2, d + DOOR_W / 2 + 0.6)
        ba, bb = max(board_spans, key=lambda s: s[1] - s[0])
        blen = min(spec["board"], bb - ba - 0.5)
        bc = (ba + bb) / 2
        spec.setdefault("boards", {})[side] = (bc, blen)
        eaves = [(x0 + corner, x1 - corner)]
        for d in doors(side):
            eaves = spans_minus(eaves, d - DOOR_W / 2 - 0.34, d + DOOR_W / 2 + 0.34)
        eaves = spans_minus(eaves, bc - blen / 2 - 0.42, bc + blen / 2 + 0.42)
        eaves = split(eaves, 2.6)

        def panel(xa, xb, ya, yb, depth, kind, bead=True):
            if xb - xa < 0.7 or yb - ya < 0.5:
                return
            o = rect_outline(xa, ya, xb, yb)
            cuts_recess.append((o, depth))
            if van:
                # a square framing lip, chamfered into the boarded recess
                prof = [(-0.07, 0.0), (-0.07, 0.025), (0.0, 0.025), (0.03, -depth + 0.01), (0.07, -depth), (0.0, -depth)]
                kind = {"boards": "plainboards", "upper": "plainboards", "eaves": "plain"}.get(kind, kind)
            else:
                prof = bolection(depth, 0.035 if zmax(side, xa, xb, ya) < 6.7 else 0.06)
                kind = spec.get("panelKinds", {}).get(kind, kind)
            shell.sweep(on_side(o, side, SKIN), prof, (0, 0, side))
            if bead and not van:
                trim.sweep(on_side(offset_outline(o, -0.27), side, SKIN - depth), BEAD, (0, 0, side))
            feat["panels"].append({"side": side, "rect": [xa, ya, xb, yb], "depth": depth, "kind": kind})

        for i, (a, b) in enumerate(lower):
            panel(a, b, LOWER[0], LOWER[1], 0.14, "boards")
        for i, (a, b) in enumerate(upper):
            panel(a, b, UPPER[0], UPPER[1], 0.1 if i % 2 == 0 else 0.13, "upper")
        for a, b in eaves:
            panel(a, b, EAVES[0] + 0.08, EAVES[1] - 0.06, 0.07, "eaves")

        # -- pilasters: fluted posts between upper panels, with base and capital ----------
        for p in posts if van else []:
            # a plain timber stanchion with an iron cap
            zt = min(zmax(side, p - 0.2, p + 0.2), 6.64)
            zbox(shell, side, p - 0.15, UPPER[0] - 0.28, SKIN - 0.02, p + 0.15, UPPER[1] + 0.02, zt)
            zbox(fit, side, p - 0.17, UPPER[1] - 0.12, SKIN - 0.02, p + 0.17, UPPER[1] + 0.04, zt + 0.02)
            fit.rivets([(p, UPPER[1] - 0.04, side * (zt + 0.02))], (0, 0, side), 0.045, 0.025, 6)
            feat["rivets"].append({"side": side, "x": p, "y": UPPER[1] - 0.04})
            feat["ledges"].append({"side": side, "x": [p - 0.17, p + 0.17], "y": UPPER[1] - 0.12, "iron": True})
        for p in [] if van else posts:
            zt = min(zmax(side, p - 0.2, p + 0.2), 6.66)
            w = 0.2
            prof = [(-w, SKIN - 0.02), (-w, zt - 0.02), (-w + 0.02, zt)]
            for k in range(3):
                c = -0.1 + 0.1 * k
                prof += [(c - 0.035, zt), (c - 0.02, zt - 0.03), (c + 0.02, zt - 0.03), (c + 0.035, zt)]
            prof += [(w - 0.02, zt), (w, zt - 0.02), (w, SKIN - 0.02)]
            prof = [(p + px, side * pz) for px, pz in prof]
            if side < 0:
                prof.reverse()
            shell.prism_y(prof, UPPER[0] + 0.3, UPPER[1] - 0.34)
            zbox(shell, side, p - 0.26, UPPER[0] - 0.02, SKIN - 0.02, p + 0.26, UPPER[0] + 0.3, zt + 0.01)
            zbox(shell, side, p - 0.29, UPPER[0] + 0.3, SKIN - 0.02, p + 0.29, UPPER[0] + 0.36, zt)
            zbox(trim, side, p - 0.27, UPPER[1] - 0.34, SKIN - 0.02, p + 0.27, UPPER[1] - 0.26, zt + 0.005)
            zbox(shell, side, p - 0.31, UPPER[1] - 0.26, SKIN - 0.02, p + 0.31, UPPER[1] + 0.02, zt + 0.01)
            feat["ledges"].append({"side": side, "x": [p - 0.31, p + 0.31], "y": UPPER[1] - 0.26})

        # -- rails: proud horizontal members with bead lines ------------------------------
        rail_spans = [(x0 - 0.06, x1 + 0.06)]
        for d in doors(side):
            rail_spans = spans_minus(rail_spans, d - DOOR_W / 2 - 0.02, d + DOOR_W / 2 + 0.02)
        for a, b in rail_spans:
            zt = zmax(side, a, b)
            zw = min(zt, 6.64)
            # waist rail: a moulded rail with a drip lip on top
            prof = [(WAIST[0], SKIN - 0.02), (WAIST[0], zw - 0.03), (WAIST[0] + 0.04, zw), (WAIST[1] - 0.06, zw),
                    (WAIST[1] - 0.02, zw - 0.02), (WAIST[1], zw - 0.06), (WAIST[1] + 0.04, SKIN - 0.02)]
            prof = [(y, side * z) for y, z in prof]
            if side < 0:
                prof.reverse()
            shell.prism_x(prof, a, b)
            for yb in () if van else (WAIST[0] + 0.07, WAIST[1] - 0.09):
                trim.sweep([(a + 0.05, yb, side * zw), (b - 0.05, yb, side * zw)], FINE_BEAD, (0, 0, side), closed=False)
            feat["ledges"].append({"side": side, "x": [a, b], "y": WAIST[0]})
            feat["ledges"].append({"side": side, "x": [a, b], "y": LOWER[0] - 0.02})
            # bottom rail kick: a chamfered plinth
            prof = [(SOLE[0] - 0.02, SKIN - 0.02), (SOLE[0] - 0.02, zw - 0.02), (SOLE[1] - 0.08, zw - 0.02),
                    (SOLE[1], SKIN - 0.02)]
            prof = [(y, side * z) for y, z in prof]
            if side < 0:
                prof.reverse()
            shell.prism_x(prof, a, b)
        # frieze rail under the eaves (above the doors too: it is above the leaves' reach)
        prof = [(FRIEZE[0], SKIN - 0.02), (FRIEZE[0], 6.62), (FRIEZE[0] + 0.05, 6.64), (FRIEZE[1] - 0.04, 6.64),
                (FRIEZE[1], 6.6), (FRIEZE[1], SKIN - 0.02)]
        for a, b in rail_spans:
            pr = [(y, side * z) for y, z in prof]
            if side < 0:
                pr.reverse()
            shell.prism_x(pr, a, b)
            if not van:
                trim.sweep([(a + 0.05, FRIEZE[0] + 0.11, side * 6.64), (b - 0.05, FRIEZE[0] + 0.11, side * 6.64)], FINE_BEAD, (0, 0, side), closed=False)
            feat["ledges"].append({"side": side, "x": [a, b], "y": FRIEZE[0]})

        # -- van windows: a square timber frame, a drip board, a plain sill, bars or mesh ----
        for wx in windows(side) if van else []:
            hw = WIN_W / 2
            o = rect_outline(wx - hw, WIN_SILL, wx + hw, WIN_CROWN)
            shell.sweep(on_side(o, side, SKIN), [(0.07, -0.44), (0.07, 0.07), (-0.2, 0.07), (-0.24, 0.0), (0.0, 0.0), (0.0, -0.44)], (0, 0, side))
            dp = [(WIN_CROWN + 0.08, SKIN - 0.02), (WIN_CROWN + 0.08, SKIN + 0.2), (WIN_CROWN + 0.14, SKIN + 0.22), (WIN_CROWN + 0.3, SKIN - 0.02)]
            dp = [(y, side * z) for y, z in dp]
            if side < 0:
                dp.reverse()
            shell.prism_x(dp, wx - hw - 0.4, wx + hw + 0.4)
            feat["ledges"].append({"side": side, "x": [wx - hw - 0.4, wx + hw + 0.4], "y": WIN_CROWN + 0.08})
            sp = [(WIN_SILL - 0.2, SKIN - 0.02), (WIN_SILL - 0.2, SKIN + 0.16), (WIN_SILL - 0.02, SKIN + 0.2), (WIN_SILL - 0.02, SKIN - 0.02)]
            sp = [(y, side * z) for y, z in sp]
            if side < 0:
                sp.reverse()
            shell.prism_x(sp, wx - hw - 0.3, wx + hw + 0.3)
            feat["ledges"].append({"side": side, "x": [wx - hw - 0.3, wx + hw + 0.3], "y": WIN_SILL - 0.2})
            feat["windows"].append({"side": side, "x": wx})
            zg0, zg1 = 6.36, 6.43
            zbox(teak, side, wx - 0.1, WIN_SILL, zg0, wx + 0.1, WIN_CROWN, zg1)
            zbox(teak, side, wx - hw, 5.2 - 0.07, zg0, wx + hw, 5.2 + 0.07, zg1)
            hz = [(wx - hw, WIN_SILL + 0.05), (wx + hw, WIN_SILL + 0.05), (wx + hw, WIN_CROWN - 0.05), (wx - hw, WIN_CROWN - 0.05)]
            haze.prism_z(hz, side * 6.335, side * 6.34)
            guard = spec.get("windowGuard", "bars")
            zb = 6.5
            if guard == "bars":
                # round iron bars in two flat ties, let into the frame
                for k in range(7):
                    bx = wx - hw + 0.24 + k * (WIN_W - 0.48) / 6
                    fit.cylinder((bx, (WIN_SILL + WIN_CROWN) / 2, side * zb), "y", 0.045, WIN_CROWN - WIN_SILL, 6)
                for by in (WIN_SILL + 0.7, WIN_CROWN - 0.7):
                    zbox(fit, side, wx - hw - 0.05, by - 0.06, zb - 0.05, wx + hw + 0.05, by + 0.06, zb + 0.05)
                    fit.rivets([(wx + sx * (hw + 0.0), by, side * (zb + 0.05)) for sx in (-1, 1)], (0, 0, side), 0.04, 0.02, 6)
            else:
                # a wire-mesh guard in an iron frame (the grille as a lattice of thin flats)
                zbox(fit, side, wx - hw, WIN_SILL, zb - 0.03, wx - hw + 0.08, WIN_CROWN, zb + 0.03)
                zbox(fit, side, wx + hw - 0.08, WIN_SILL, zb - 0.03, wx + hw, WIN_CROWN, zb + 0.03)
                zbox(fit, side, wx - hw, WIN_SILL, zb - 0.03, wx + hw, WIN_SILL + 0.08, zb + 0.03)
                zbox(fit, side, wx - hw, WIN_CROWN - 0.08, zb - 0.03, wx + hw, WIN_CROWN, zb + 0.03)
                for k in range(1, 9):
                    bx = wx - hw + k * WIN_W / 9
                    zbox(fit, side, bx - 0.012, WIN_SILL, zb - 0.01, bx + 0.012, WIN_CROWN, zb + 0.01)
                for k in range(1, 9):
                    by = WIN_SILL + k * (WIN_CROWN - WIN_SILL) / 9
                    zbox(fit, side, wx - hw, by - 0.012, zb - 0.02, wx + hw, by + 0.012, zb)
                fit.rivets([(wx + sx * (hw - 0.04), by, side * (zb + 0.03)) for sx in (-1, 1) for by in (WIN_SILL + 0.3, WIN_CROWN - 0.3)], (0, 0, side), 0.035, 0.02, 6)

        # -- windows: deep moulded frame, drip mould, sill on brackets, glazing, curtains --
        for wx in [] if van else windows(side):
            outline = arch_outline(wx, WIN_SILL, WIN_W, WIN_SPRING, WIN_CROWN)
            prof = [(0.07, -0.44), (0.07, 0.04), (0.04, 0.08), (-0.02, 0.1), (-0.12, 0.12), (-0.2, 0.1), (-0.26, 0.05),
                    (-0.3, 0.0), (0.0, 0.0), (0.0, -0.44)]
            shell.sweep(on_side(outline, side, SKIN), prof, (0, 0, side))
            trim.sweep(on_side(offset_outline(outline, 0.09), side, SKIN + 0.12), FINE_BEAD, (0, 0, side))
            # drip mould: an arched hood over the frame, stopping on two small label stops
            hood = arch_outline(wx, WIN_SILL, WIN_W + 0.9, WIN_SPRING, WIN_CROWN + 0.42)
            arc = [p for p in hood[2:]]
            path = on_side(arc, side, SKIN)
            hp = [(0.06, 0.0), (0.06, 0.1), (0.0, 0.18), (-0.1, 0.22), (-0.12, 0.16), (-0.08, 0.0)]
            shell.sweep(path, hp, (0, 0, side), closed=False)
            for sx in (-1, 1):
                zbox(shell, side, wx + sx * (WIN_W / 2 + 0.36) - 0.09, WIN_SPRING - 0.28, SKIN - 0.02, wx + sx * (WIN_W / 2 + 0.36) + 0.09, WIN_SPRING + 0.02, SKIN + 0.2)
            feat["ledges"].append({"side": side, "x": [wx - WIN_W / 2 - 0.5, wx + WIN_W / 2 + 0.5], "y": WIN_SPRING - 0.3})
            # keystone, stepped
            zbox(shell, side, wx - 0.2, WIN_CROWN - 0.04, SKIN, wx + 0.2, WIN_CROWN + 0.46, SKIN + 0.16)
            zbox(trim, side, wx - 0.12, WIN_CROWN + 0.04, SKIN + 0.16, wx + 0.12, WIN_CROWN + 0.36, SKIN + 0.19)
            # sill: a thick moulded sill with a drip groove, on two scroll brackets
            sp = [(WIN_SILL - 0.3, SKIN - 0.02), (WIN_SILL - 0.3, SKIN + 0.12), (WIN_SILL - 0.24, SKIN + 0.2),
                  (WIN_SILL - 0.1, SKIN + 0.24), (WIN_SILL - 0.02, SKIN + 0.2), (WIN_SILL - 0.02, SKIN - 0.02)]
            sp = [(y, side * z) for y, z in sp]
            if side < 0:
                sp.reverse()
            shell.prism_x(sp, wx - WIN_W / 2 - 0.42, wx + WIN_W / 2 + 0.42)
            for bx in (wx - WIN_W / 2 + 0.05, wx + WIN_W / 2 - 0.05):
                br = [(WIN_SILL - 0.3, SKIN - 0.02), (WIN_SILL - 0.3, SKIN + 0.18), (WIN_SILL - 0.42, SKIN + 0.14),
                      (WIN_SILL - 0.62, SKIN + 0.06), (WIN_SILL - 0.72, SKIN - 0.02)]
                br = [(y, side * z) for y, z in br]
                if side < 0:
                    br.reverse()
                shell.prism_x(br, bx - 0.08, bx + 0.08)
            feat["ledges"].append({"side": side, "x": [wx - WIN_W / 2 - 0.42, wx + WIN_W / 2 + 0.42], "y": WIN_SILL - 0.3})
            feat["windows"].append({"side": side, "x": wx})
            # glazing: a moulded mullion over the old one, a transom at the spring, leaded fanlight
            zg0, zg1 = 6.36, 6.43
            zbox(teak, side, wx - 0.17, WIN_SILL, zg0, wx + 0.17, WIN_SPRING, zg1)
            zbox(teak, side, wx - 0.09, WIN_SILL, zg1, wx + 0.09, WIN_SPRING, zg1 + 0.03)
            zbox(teak, side, wx - WIN_W / 2, WIN_SPRING - 0.08, zg0, wx + WIN_W / 2, WIN_SPRING + 0.08, zg1 + 0.02)
            zbox(teak, side, wx - WIN_W / 2, WIN_SILL, zg0, wx + WIN_W / 2, WIN_SILL + 0.12, zg1 + 0.02)
            # upper sash bars: two lights per half
            for sx in (-1, 1):
                bx = wx + sx * WIN_W / 4
                zbox(teak, side, bx - 0.04, 4.6, zg0, bx + 0.04, WIN_SPRING, zg1)
                zbox(teak, side, wx + sx * 0.17 if sx > 0 else wx - WIN_W / 2, 4.56, zg0, wx + WIN_W / 2 if sx > 0 else wx - 0.17, 4.64, zg1)
            # fanlight: amber glass in lead cames, a fan of bars from the transom's centre
            S = WIN_SPRING + 0.08
            half = WIN_W / 2
            rise = WIN_CROWN - WIN_SPRING
            rad = (half * half + rise * rise) / (2 * rise)
            cyc = WIN_CROWN - rad
            fan = [(wx - half, S), (wx + half, S)] + [p for p in outline[2:] if p[1] > S]
            glow.prism_z(fan, side * 6.33, side * 6.345)
            for k in range(1, 6):
                ex = wx + half * math.cos(math.pi * k / 6)
                ey = cyc + math.sqrt(max(0.0, rad * rad - (ex - wx) ** 2))
                fit.sweep([(wx, S, side * 6.35), (ex, ey, side * 6.35)], [(0.016, -0.01), (0.016, 0.01), (-0.016, 0.01), (-0.016, -0.01)], (0, 0, side), closed=False)
            # warm veil over the lower glass
            hz = [(wx - WIN_W / 2, WIN_SILL + 0.12), (wx + WIN_W / 2, WIN_SILL + 0.12), (wx + WIN_W / 2, WIN_SPRING - 0.08), (wx - WIN_W / 2, WIN_SPRING - 0.08)]
            haze.prism_z(hz, side * 6.335, side * 6.34)
            # brass curtain rail under the transom, velvet curtains tied back behind the glass
            brass.cylinder((wx, WIN_SPRING - 0.2, side * 6.2), "x", 0.03, WIN_W + 0.1, 8)
            for sx in (-1, 1):
                brass.lathe([(0.0, 0), (0.05, 0.02), (0.05, 0.06), (0.0, 0.08)], (wx + sx * (WIN_W / 2 + 0.05), WIN_SPRING - 0.2, side * 6.2), "x", 8)
                # a drape: rings of a wavy cross-section, gathered at the tie-back
                rings = []
                for y, w in ((WIN_SPRING - 0.18, 0.62), (5.0, 0.42), (4.45, 0.2), (4.1, 0.3), (WIN_SILL + 0.14, 0.42)):
                    edge = wx + sx * (WIN_W / 2 - 0.02)
                    ring = []
                    m = 7
                    for j in range(m):
                        t = j / (m - 1)
                        x = edge - sx * w * t
                        z = 6.16 + 0.05 * math.sin(t * math.pi * 3) + 0.02
                        ring.append((x, y, side * z))
                    back = [(x, y, side * 6.13) for x, y, _ in reversed(ring)]
                    rings.append(ring + back)
                velvet.quad_strip([[V(*p) for p in r] for r in rings], closed_path=False, closed_profile=True, caps=True)
                brass.cylinder((wx + sx * (WIN_W / 2 - 0.18), 4.45, side * 6.22), "x", 0.035, 0.36, 6)

        # -- doors: reveal, flush architrave with a sunk bead, hanging track with hood -----
        for d in doors(side):
            o = rect_outline(d - DOOR_W / 2, -0.02, d + DOOR_W / 2, DOOR_H)
            shell.sweep(on_side(o, side, SKIN), [(0.05, -0.44), (0.05, 0.0), (0.0, 0.0), (0.0, -0.44)], (0, 0, side))
            # architrave: flat, 0.3 wide, with a groove and a bead sunk in it (leaves pass over)
            arch = [(0.0, 0.0), (0.0, 0.04), (-0.12, 0.04), (-0.14, 0.01), (-0.2, 0.01), (-0.22, 0.04), (-0.32, 0.04), (-0.34, 0.0)]
            shell.sweep(on_side(o, side, SKIN), arch, (0, 0, side))
            if not van:
                trim.sweep(on_side(offset_outline(o, 0.17), side, SKIN + 0.0), FINE_BEAD, (0, 0, side))
            feat["doorEdges"].append({"side": side, "x": [d - DOOR_W / 2, d + DOOR_W / 2]})
            # the hanging track over the opening: a hooded rail on brackets
            a, b = max(x0 + 0.05, d - DOOR_W - 0.25), min(x1 - 0.05, d + DOOR_W + 0.25)
            trk = [(SLIDE_TOP + 0.02, SKIN - 0.02), (SLIDE_TOP + 0.02, 6.9), (SLIDE_TOP + 0.24, 6.9), (SLIDE_TOP + 0.3, 6.86),
                   (SLIDE_TOP + 0.36, 6.72), (SLIDE_TOP + 0.36, SKIN - 0.02)]
            trk = [(y, side * z) for y, z in trk]
            if side < 0:
                trk.reverse()
            fit.prism_x(trk, a, b)
            feat["ledges"].append({"side": side, "x": [a, b], "y": SLIDE_TOP + 0.02, "iron": True})
            for bx in (a + 0.25, d - DOOR_W / 2, d + DOOR_W / 2, b - 0.25):
                zbox(fit, side, bx - 0.1, SLIDE_TOP + 0.36, SKIN - 0.02, bx + 0.1, SLIDE_TOP + 0.7, 6.74)
                bolts = [(bx, SLIDE_TOP + 0.56, side * 6.74)]
                fit.rivets(bolts, (0, 0, side), 0.05, 0.035, 6)
                feat["rivets"] += [{"side": side, "x": bx, "y": SLIDE_TOP + 0.5}]
            pts = [(x, SLIDE_TOP + 0.14, side * 6.9) for x in [a + 0.5 + k * (b - a - 1.0) / 8 for k in range(9)]]
            fit.rivets(pts, (0, 0, side), 0.04, 0.03)
            # the step: a tread with a nosing, two angle-iron hangers and mud guards
            fit.box_between((d - 1.9, -1.34, side * 5.9), (d + 1.9, -1.2, side * 6.86))
            nose = [(-1.34, 6.8), (-1.14, 6.8), (-1.14, 6.86), (-1.4, 6.86), (-1.4, 6.8)]
            fp = [(y, side * z) for y, z in [(-1.4, 6.8), (-1.14, 6.8), (-1.14, 6.88), (-1.4, 6.88)]]
            if side < 0:
                fp.reverse()
            fit.prism_x(fp, d - 1.92, d + 1.92)
            for hx in (d - 1.7, d + 1.7):
                hp = [(-1.2, 5.9), (-1.2, 6.7), (-1.0, 6.7), (0.0, 6.62), (0.0, 6.5), (-0.95, 6.5), (-1.1, 6.0)]
                hp = [(y, side * z) for y, z in hp]
                if side < 0:
                    hp.reverse()
                fit.prism_x(hp, hx - 0.05, hx + 0.05)
                fit.rivets([(hx + 0.05 * s, -0.6, side * 6.6) for s in (1,)], (1, 0, 0), 0.035, 0.02)
            for gx in (d - 1.95, d + 1.95):
                zbox(fit, side, gx - 0.025, -1.4, 5.95, gx + 0.025, -0.95, 6.86)
            feat["steps"].append({"side": side, "x": [d - 1.9, d + 1.9], "y": -1.2})
            # door lamp on the track's middle: brass back plate, hooded body, caged glass
            ly = 8.2
            zbox(brass, side, d - 0.13, SLIDE_TOP + 0.36, SKIN - 0.02, d + 0.13, ly + 0.3, 6.62)
            zbox(brass, side, d - 0.3, ly - 0.34, 6.6, d + 0.3, ly - 0.26, 6.86)
            for sx in (-1, 1):
                zbox(brass, side, d + sx * 0.27 - 0.03, ly - 0.26, 6.62, d + sx * 0.27 + 0.03, ly + 0.26, 6.84)
            zbox(brass, side, d - 0.36, ly + 0.26, 6.6, d + 0.36, ly + 0.34, 6.9)
            brass.lathe([(0.15, 0), (0.11, 0.1), (0.05, 0.16), (0.06, 0.2), (0.0, 0.24)], (d, ly + 0.34, side * 6.74), "y", 10)
            for k in (-1, 0, 1):
                zbox(brass, side, d + k * 0.09 - 0.012, ly - 0.26, 6.85, d + k * 0.09 + 0.012, ly + 0.26, 6.865)
            zbox(lens, side, d - 0.24, ly - 0.26, 6.64, d + 0.24, ly + 0.26, 6.845)
            lights.append((d, ly, side * 7.2))
            feat["lamps"].append({"side": side, "x": d, "y": ly})

        # -- grab rails: tubular brass on standoffs, near the ends, clear of slide zones ---
        for ex, ed in ((x0, 1), (x1, -1)):
            hx = ex + ed * 0.85
            if in_slide(side, hx - 0.2, hx + 0.2):
                continue
            brass.cylinder((hx, 3.4, side * 6.79), "y", 0.055, 4.4, 10)
            for hy in (1.35, 5.45):
                brass.cylinder((hx, hy, side * 6.68), "z", 0.035, 0.22, 8)
                brass.lathe([(0.0, 0.0), (0.11, 0.0), (0.11, side * 0.025), (0.05, side * 0.05), (0.0, side * 0.05)], (hx, hy, side * SKIN), "z", 10)
                fit.rivets([(hx + 0.07 * math.cos(a), hy + 0.07 * math.sin(a), side * (SKIN + 0.025)) for a in (0.8, 2.4, 3.9, 5.5)], (0, 0, side), 0.02, 0.012, 5)
            feat["grips"].append({"side": side, "x": hx, "y": [1.2, 5.6]})

        # -- plates: builder's plate on the solebar, number plate on the waist rail ---------
        px = cx + side * 1.2
        # an oval builder's plate
        ov = []
        for k in range(24):
            a = 2 * math.pi * k / 24
            ov.append((px + 0.5 * math.cos(a), -0.5 + 0.3 * math.sin(a)))
        plate = Piece(f"{name}_Sign_bp{side}", None, "Sign")
        oo = ov if side > 0 else list(reversed(ov))
        plate.prism_z(oo, side * 6.68, side * 6.71)
        extra.append(plate)
        labels.append({"piece": plate.name, "label": "builders", "side": side, "rect": [px - 0.5, -0.8, px + 0.5, -0.2], "z": 6.71})
        brass.sweep(on_side([(px + 0.53 * math.cos(2 * math.pi * k / 24), -0.5 + 0.33 * math.sin(2 * math.pi * k / 24)) for k in range(24)], side, 6.68),
                    [(0.03, 0.0), (0.03, 0.04), (-0.03, 0.04), (-0.03, 0.0)], (0, 0, side))
        feat["plates"].append({"side": side, "rect": [px - 0.55, -0.85, px + 0.55, -0.15]})
        # cast number plate at the end of the waist rail furthest from a door
        ends = [x0 + 1.6, x1 - 1.6]
        nx = max(ends, key=lambda e: min([abs(e - d) for d in doors(side)] or [99]))
        zw = 6.64
        np_ = Piece(f"{name}_Sign_np{side}", None, "Sign")
        np_.box_between((nx - 0.32, WAIST[0] + 0.02, side * zw), (nx + 0.32, WAIST[1] - 0.02, side * (zw + 0.03)))
        extra.append(np_)
        labels.append({"piece": np_.name, "label": "number", "side": side, "rect": [nx - 0.32, WAIST[0] + 0.02, nx + 0.32, WAIST[1] - 0.02], "z": zw + 0.03})
        feat["plates"].append({"side": side, "rect": [nx - 0.34, WAIST[0], nx + 0.34, WAIST[1]]})

        # -- the name board: dark sunk ground, moulded frame, gilt bead -------------------
        by0, by1 = 7.66, 8.38
        board = spec.get("nameBoard", True)
        if board:
            sb = Piece(f"{name}_Sign_board{side}", None, "Sign")
            sb.box_between((bc - blen / 2, by0, side * (SKIN - 0.03)), (bc + blen / 2, by1, side * (SKIN + 0.02)))
            extra.append(sb)
            labels.append({"piece": sb.name, "label": f"board{side}", "side": side, "rect": [bc - blen / 2, by0, bc + blen / 2, by1], "z": SKIN + 0.02})
            bo = rect_outline(bc - blen / 2, by0, bc + blen / 2, by1)
            shell.sweep(on_side(bo, side, SKIN), [(0.0, -0.02), (0.0, 0.08), (-0.04, 0.11), (-0.09, 0.11), (-0.12, 0.05), (-0.12, 0.0)], (0, 0, side))
            if not van:
                trim.sweep(on_side(offset_outline(bo, 0.065), side, SKIN + 0.11), FINE_BEAD, (0, 0, side))
        for sx in (-1, 1) if board and not van else ():
            # scroll ends either side of the board
            ex = bc + sx * (blen / 2 + 0.26)
            zbox(shell, side, ex - 0.1, by0 + 0.05, SKIN, ex + 0.1, by1 - 0.05, SKIN + 0.1)
            zbox(trim, side, ex - 0.05, (by0 + by1) / 2 - 0.12, SKIN + 0.1, ex + 0.05, (by0 + by1) / 2 + 0.12, SKIN + 0.13)
        if board:
            feat["boards"].append({"side": side, "rect": [bc - blen / 2, by0, bc + blen / 2, by1]})

        # -- dentil course and corbels under the cornice -----------------------------------
        y0d, y1d = DENTIL
        if van:
            # a plain cornice: a fascia with a drip, no dentils or corbels
            cor = [(TOP - 0.3, SKIN_IN), (TOP - 0.3, SKIN + 0.02), (TOP - 0.22, SKIN + 0.08), (TOP + 0.3, SKIN + 0.12),
                   (TOP + 0.36, SKIN + 0.2), (EAVE_Y - 0.06, SKIN + 0.22), (EAVE_Y - 0.06, SKIN_IN)]
            cor = [(y, side * z) for y, z in cor]
            if side < 0:
                cor.reverse()
            shell.prism_x(cor, x0 - 0.12, x1 + 0.12)
            feat["ledges"].append({"side": side, "x": [x0, x1], "y": TOP - 0.3})
        if not van:
            shell.box_between((x0 - 0.06, y0d - 0.02, side * (SKIN - 0.02)), (x1 + 0.06, y0d + 0.04, side * 6.66))
            n = int((x1 - x0) / 0.24)
            for k in range(n):
                xa = x0 + 0.06 + k * (x1 - x0 - 0.12) / n
                if any(abs(xa + 0.06 - d) < 0.55 for d in doors(side)):
                    continue
                zbox(shell, side, xa, y0d + 0.04, SKIN - 0.02, xa + 0.12, y1d, 6.7)
            corbels = [x0 + 0.25, x1 - 0.25] + posts
            for d in doors(side):
                corbels += [d - DOOR_W / 2 - 0.2, d + DOOR_W / 2 + 0.2]
            for wx in windows(side):
                corbels.append(wx)
            corbels = sorted(set(round(c, 2) for c in corbels if abs(c - bc) > blen / 2 + 0.5 and min([abs(c - d) for d in doors(side)] or [9]) > 0.6))
            for c in corbels:
                cp = [(y1d, SKIN - 0.02), (TOP + 0.02, SKIN - 0.02), (TOP + 0.02, 6.84), (TOP - 0.06, 6.84), (TOP - 0.16, 6.76),
                      (y1d - 0.08, 6.7), (y1d - 0.3, 6.66), (y1d - 0.46, 6.62), (y1d - 0.52, SKIN - 0.02)]
                cp = [(y, side * z) for y, z in cp]
                if side < 0:
                    cp.reverse()
                shell.prism_x(cp, c - 0.09, c + 0.09)
                trim.box_between((c - 0.1, y1d - 0.53, side * (SKIN - 0.02)), (c + 0.1, y1d - 0.47, side * 6.64))

            # -- cornice: ogee with a fascia, carrying the roof's edge --------------------------
            cor = [(TOP - 0.1, SKIN_IN), (TOP - 0.1, SKIN + 0.02), (TOP + 0.02, SKIN + 0.06), (TOP + 0.08, SKIN + 0.12),
                   (TOP + 0.2, SKIN + 0.12), (TOP + 0.26, SKIN + 0.18), (TOP + 0.38, SKIN + 0.2), (TOP + 0.46, SKIN + 0.28),
                   (TOP + 0.5, SKIN + 0.3), (EAVE_Y - 0.06, SKIN + 0.3), (EAVE_Y - 0.06, SKIN_IN)]
            cor = [(y, side * z) for y, z in cor]
            if side < 0:
                cor.reverse()
            shell.prism_x(cor, x0 - 0.12, x1 + 0.12)
            trim.sweep([(x0 - 0.1, TOP + 0.14, side * (SKIN + 0.12)), (x1 + 0.1, TOP + 0.14, side * (SKIN + 0.12))], FINE_BEAD, (0, 0, side), closed=False)
            feat["ledges"].append({"side": side, "x": [x0, x1], "y": y0d - 0.02})

        # -- the skin: one slab with every opening and recess cut into it ------------------
        skin = Piece(f"{name}_skin{side}", "Body", "Paint")
        z0, z1 = sorted((side * SKIN_IN, side * SKIN))
        skin.box_between((x0 - 0.08, -0.02, z0), (x1 + 0.08, TOP, z1))

        def cut_open(p, side=side):
            for o in cuts_open + door_rects:
                p.prism_z(o, side * 6.0, side * 6.9)

        def cut_recess(p, side=side):
            for o, dep in cuts_recess:
                p.prism_z(o, side * (SKIN - dep), side * 6.9)

        skin.cutters = [cutter_object(f"cut_open{side}", col, cut_open), cutter_object(f"cut_rec{side}", col, cut_recess)]
        skin.bevel_after = (0.012, 1, 50)
        extra.append(skin)

        # -- iron: solebar with bolts, corner straps, truss, valance -----------------------
        sol = [(-1.0, SKIN_IN), (-1.0, 6.68), (-0.92, 6.7), (-0.9, 6.62), (-0.1, 6.62), (-0.08, 6.7), (0.0, 6.68), (0.0, SKIN_IN)]
        sol = [(y, side * z) for y, z in sol]
        if side < 0:
            sol.reverse()
        fit.prism_x(sol, spec.get("rearDeck", x0) - 0.1, x1 + 0.1)
        n = int((x1 - x0) / 0.55)
        rv = []
        for k in range(n + 1):
            x = x0 + 0.3 + k * (x1 - x0 - 0.6) / n
            if abs(x - px) < 0.7:
                continue
            rv += [(x, -0.2, side * 6.7), (x, -0.8, side * 6.7)]
        fit.rivets(rv, (0, 0, side), 0.055, 0.04, 6)
        feat["rivets"] += [{"side": side, "x": p[0], "y": p[1]} for p in rv]
        for ex, ed in ((x0, -1), (x1, 1)):
            za = min(zmax(side, ex - 0.5, ex + 0.5), 6.64)
            zbox(fit, side, ex - ed * 0.44, -0.02, SKIN - 0.02, ex + ed * 0.02, TOP - 0.1, za - 0.02)
            rows = [(ex - ed * 0.12, 0.3 + k * 0.62) for k in range(14)] + [(ex - ed * 0.32, 0.3 + k * 1.24) for k in range(7)]
            fit.rivets([(x, y, side * (za - 0.02)) for x, y in rows], (0, 0, side), 0.05, 0.02, 6)
            feat["rivets"] += [{"side": side, "x": x, "y": y} for x, y in rows]
            feat["straps"].append({"side": side, "x": [min(ex, ex - ed * 0.44), max(ex, ex - ed * 0.44)]})
            # knee plate where the strap meets the solebar
            kp = [(ex, -0.02), (ex - ed * 0.9, -0.02), (ex - ed * 0.44, 0.6), (ex, 0.6)]
            if ed < 0:
                kp.reverse()
            fit.prism_z(kp if side > 0 else list(reversed(kp)), side * (SKIN - 0.02), side * (za - 0.01))
        # queen-post truss rods under the floor between the bogies
        ta, tb = x0 + 5.0, x1 - 5.0
        if tb - ta > 2:
            for zt in (5.2,):
                path = [(ta - 1.0, -1.0, side * zt), (ta, -2.1, side * zt), (tb, -2.1, side * zt), (tb + 1.0, -1.0, side * zt)]
                fit.sweep(path, [(0.05, -0.05), (0.05, 0.05), (-0.05, 0.05), (-0.05, -0.05)], (0, 0, side), closed=False)
                for qx in (ta, tb):
                    fit.box_between((qx - 0.08, -2.1, side * (zt - 0.08)), (qx + 0.08, -1.0, side * (zt + 0.08)))
            # the valance: a dirty skirt hanging under the solebar between the bogies
            zbox(fit, side, ta - 0.4, -1.55, 6.5, tb + 0.4, -1.0, 6.56)

    # ---------------------------------------------------------------------------------
    # end walls: panelled, with gangway frame, handrails, downspouts, buffers
    for ex, ed, gang in ((x0, -1, spec["rearGangway"]), (x1, 1, spec["frontGangway"])):
        end = Piece(f"{name}_end{ed}", "Body", "Paint")
        xa, xb = sorted((ex, ex + ed * 0.22))
        end.box_between((xa, -0.02, -SKIN), (xb, TOP, SKIN))
        xf = ex + ed * 0.22  # the end's outer face
        cutters = []
        rects = [(-5.9, 0.5, -2.75, 3.4), (2.75, 0.5, 5.9, 3.4), (-5.9, 3.8, -2.75, 8.2), (2.75, 3.8, 5.9, 8.2)]

        def rec(p, rects=rects, xf=xf, ed=ed):
            for za, ya, zb, yb in rects:
                p.box_between((xf - ed * 0.1, ya, za), (xf + ed * 0.3, yb, zb))
            if gang:
                p.box_between((xf - ed * 0.6, -0.3, -2.04), (xf + ed * 0.3, 7.04, 2.04))

        cutters.append(cutter_object(f"cut_end{ed}", col, rec))
        end.cutters = cutters
        end.bevel_after = (0.012, 1, 50)
        extra.append(end)
        for za, ya, zb, yb in rects:
            o = rect_outline(za, ya, zb, yb)
            if van:
                shell.sweep(on_end(o, ed, xf), [(-0.07, 0.0), (-0.07, 0.025), (0.0, 0.025), (0.03, -0.09), (0.07, -0.1), (0.0, -0.1)], (ed, 0, 0))
            else:
                shell.sweep(on_end(o, ed, xf), bolection(0.1, 0.05), (ed, 0, 0))
                trim.sweep(on_end(offset_outline(o, -0.27), ed, xf - ed * 0.1), BEAD, (ed, 0, 0))
        # gangway frame round the opening, iron, bolted
        if gang:
            gp = rect_outline(-2.04, -0.02, 2.04, 7.04)
            fit.sweep(on_end(gp, ed, xf), [(0.0, -0.02), (0.0, 0.08), (-0.3, 0.08), (-0.3, -0.02)], (ed, 0, 0))
            fit.rivets([(xf + ed * 0.08, y, s * 2.2) for s in (-1, 1) for y in (0.5, 2.0, 3.5, 5.0, 6.5)], (ed, 0, 0), 0.05, 0.03)
        # end handrails: brass tubes on standoffs
        for zz_ in (-3.25, 3.25):
            brass.cylinder((xf + ed * 0.2, 3.5, zz_), "y", 0.05, 5.6, 8)
            for hy in (0.9, 6.1):
                brass.cylinder((xf + ed * 0.1, hy, zz_), "x", 0.03, 0.22, 6)
        # roof ladder rungs on the left end panel
        for k in range(6):
            fit.cylinder((xf + ed * 0.16, 3.9 + k * 0.7, -4.3), "z", 0.035, 1.0, 6)
        for zl in (-4.8, -3.8):
            fit.box_between((min(xf, xf + ed * 0.2), 3.7, zl - 0.04), (max(xf, xf + ed * 0.2), 8.6, zl + 0.04))
        # downspouts from the gutter to the solebar near each corner
        for s_ in (-1, 1):
            zs = s_ * 6.2
            xp = xf + ed * 0.14
            fit.cylinder((xp, EAVE_Y - 0.25, s_ * 6.52), "z", 0.06, 0.66, 8)
            fit.cylinder((xp, (EAVE_Y - 0.25 + 0.2) / 2, zs), "y", 0.07, EAVE_Y - 0.25 - 0.2, 8)
            fit.lathe([(0.07, 0.0), (0.1, -0.04), (0.1, -0.16), (0.0, -0.16)], (xp, 0.2, zs), "y", 8)
            for by in (1.5, 4.0, 6.5):
                fit.box_between((min(xf, xf + ed * 0.2), by - 0.04, zs - 0.1), (max(xf, xf + ed * 0.2), by + 0.04, zs + 0.1))
        # headstock: the end beam, bolted, with buffers and a coupling hook
        if ed < 0 and "rearDeck" in spec:
            xf = spec["rearDeck"]  # the guard's veranda: the buffers are at the deck's end
        hs0, hs1 = sorted((xf, xf + ed * 0.16))
        fit.box_between((hs0, -1.05, -SKIN), (hs1, 0.0, SKIN))
        fit.rivets([(xf + ed * 0.16, y, z) for z in (-5.6, -4.6, -2.6, 2.6, 4.6, 5.6) for y in (-0.25, -0.8)], (ed, 0, 0), 0.05, 0.035)
        hx = xf + ed * 0.16
        reach = (GAP - 2 * 0.38) / 2 - 0.06  # buffers almost meet in the middle of the gap
        for bz in (-3.7, 3.7):
            fit.box_between((min(hx, hx + ed * 0.08), -0.95, bz - 0.42), (max(hx, hx + ed * 0.08), -0.05, bz + 0.42))
            fit.rivets([(hx + ed * 0.08, -0.5 + dy, bz + dz) for dy in (-0.3, 0.3) for dz in (-0.3, 0.3)], (ed, 0, 0), 0.05, 0.035)
            prof = [(0.0, 0.0), (0.26, 0.0), (0.26, 0.1), (0.22, 0.14), (0.22, reach * 0.55), (0.16, reach * 0.6), (0.16, reach - 0.1),
                    (0.36, reach - 0.08), (0.38, reach - 0.04), (0.34, reach), (0.0, reach + 0.02)]
            fit.lathe([(r, ed * h) for r, h in prof], (hx + ed * 0.08, -0.5, bz), "x", 12)
        # coupling hook below the gangway floor
        hk = [(hx, -1.25), (hx + ed * 0.5, -1.25), (hx + ed * 0.62, -1.4), (hx + ed * 0.6, -1.62), (hx + ed * 0.48, -1.66), (hx + ed * 0.46, -1.5),
              (hx + ed * 0.4, -1.38), (hx, -1.4)]
        hk = [(x, y) for x, y in hk]
        if ed < 0:
            hk.reverse()
        fit.prism_z(hk, -0.07, 0.07)

    # ---------------------------------------------------------------------------------
    # the gangway in front of the car: bellows, frames, chain, hoses (the car owns its front gap)
    if spec["frontGangway"]:
        g0, g1 = x1 + 0.22, x1 + spec.get("frontGap", GAP) - 0.22
        folds = 11
        rings = []
        for k in range(folds + 1):
            x = g0 + (g1 - g0) * k / folds
            w = 2.56 + (0.26 if k % 2 else 0.0)
            yt = 7.66 + (0.26 if k % 2 else 0.0)
            u = [(-0.3, -w), (yt - 0.3, -w), (yt, -w + 0.3), (yt, w - 0.3), (yt - 0.3, w), (-0.3, w)]
            t = 0.05
            inner = [(-0.3, -w + t), (yt - 0.3 - t * 0.5, -w + t), (yt - t, -w + 0.3 + t * 0.5), (yt - t, w - 0.3 - t * 0.5),
                     (yt - 0.3 - t * 0.5, w - t), (-0.3, w - t)]
            rings.append([V(x, y, z) for y, z in u + list(reversed(inner))])
        bellows.quad_strip(rings, closed_path=False, closed_profile=True, caps=True)
        for gx in (g0, g1):
            o = rect_outline(-2.92, -0.3, 2.92, 8.0)
            path = [(gx, y, z) for z, y in o]
            fit.sweep(path, [(0.0, -0.06), (0.0, 0.06), (0.22, 0.06), (0.22, -0.06)], (1, 0, 0))
        feat["gangway"] = [g0, g1]
    if spec.get("frontGap", GAP) > 0:
        coupling(fit, x1, spec.get("frontGap", GAP))
    spec["lights"] = lights
    pieces = SimpleNamespace(shell=shell, trim=trim, roof=roof, lens=lens, glow=glow, haze=haze, sign=sign, fit=fit, brass=brass,
                             teak=teak, velvet=velvet, bellows=bellows, crate=crate, tarp=tarp)
    roof_and_under(spec, pieces, van, col)
    extra += spec.pop("_extra", [])
    extra += identity.add(spec, pieces, SimpleNamespace(feat=feat, labels=labels, lights=lights, zbox=zbox, zmax=zmax, in_slide=in_slide,
                                                        doors=doors, windows=windows, roof_y=roof_y, van=van, col=col))
    # no geometric bevel on the many small parts: bake2 rounds every edge in the normal map
    for p in extra:
        if not hasattr(p, "bevel_after"):
            p.bevel_after = None
    return [shell, trim, roof, lens, glow, haze, fit, brass, teak, velvet, bellows, crate, tarp, sign] + extra


def coupling(fit, x1, gap):
    """Screw coupling, safety chains, steam-heat hose and vacuum pipe across the gap at x1..x1+gap."""
    if True:
        # the screw coupling: two links and a screw with its tommy bar, slung between the hooks
        cy = -1.5
        for k, (xa, xb) in enumerate(((x1 + 0.6, x1 + gap * 0.42), (x1 + gap * 0.58, x1 + gap - 0.6))):
            lk = [(xa, cy - 0.08), (xb, cy - 0.12), (xb, cy + 0.0), (xa, cy + 0.04)]
            fit.prism_z(lk, -0.16, -0.1)
            fit.prism_z(lk, 0.1, 0.16)
        fit.cylinder((x1 + gap / 2, cy - 0.06, 0), "x", 0.07, gap * 0.22, 8)
        fit.cylinder((x1 + gap / 2, cy - 0.06, 0), "z", 0.035, 0.7, 6)
        fit.lathe([(0.0, -0.1), (0.13, -0.1), (0.13, 0.1), (0.0, 0.1)], (x1 + gap / 2, cy - 0.06, 0), "x", 8)
        # buffer-height safety chains either side, sagging between the cars
        for cz in (-1.5, 1.5):
            pts = []
            for k in range(9):
                t = k / 8
                pts.append((x1 + 0.4 + (gap - 0.8) * t, -1.35 - 0.35 * math.sin(math.pi * t), cz))
            for k in range(len(pts) - 1):
                a, b = pts[k], pts[k + 1]
                mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
                if k % 2:
                    fit.box_between((mx - 0.16, my - 0.05, cz - 0.015), (mx + 0.16, my + 0.05, cz + 0.015))
                else:
                    fit.box_between((mx - 0.16, my - 0.015, cz - 0.05), (mx + 0.16, my + 0.015, cz + 0.05))
        # steam-heat hose and vacuum brake pipe, drooping between the headstocks
        for hz, r in ((-0.9, 0.1), (0.9, 0.12)):
            path = []
            for k in range(11):
                t = k / 10
                path.append((x1 + 0.3 + (gap - 0.6) * t, -1.2 - 0.6 * math.sin(math.pi * t), hz))
            prof = [(r * math.cos(2 * math.pi * j / 8), r * math.sin(2 * math.pi * j / 8)) for j in range(8)]
            fit.sweep(path, prof, (0, 0, 1), closed=False)
            for gx in (x1 + 0.3, x1 + gap - 0.3):
                fit.cylinder((gx, -1.2, hz), "x", r + 0.04, 0.16, 8)


def roof_and_under(spec, P, van, col):
    """The cambered roof, clerestory, gutters, vents, and the underframe's boxes."""
    x0, x1 = spec["x0"], spec["x1"]
    cx = (x0 + x1) / 2
    name = spec["name"]
    roof, shell, trim, fit = P.roof, P.shell, P.trim, P.fit
    feat = spec["feat"]
    extra = spec.setdefault("_extra", [])

    def windows(side):
        return spec["windows"].get(side, [])

    # ---------------------------------------------------------------------------------
    # roof
    ma, mb = spec["monitor"]

    def roof_strip(za, zb, xa, xb, segs=8):
        prof_top = [(roof_y(za + (zb - za) * k / segs), za + (zb - za) * k / segs) for k in range(segs + 1)]
        prof = prof_top + [(y - 0.14, z) for y, z in reversed(prof_top)]
        roof.prism_x(prof, xa, xb)

    for side in (-1, 1):
        za, zb = sorted((side * (MON_Z - 0.06), side * EAVE_Z))
        roof_strip(za, zb, x0 - 0.3, x1 + 0.3)
        # thickened drip edge and a half-round gutter along the eaves
        g = [(EAVE_Y - 0.22, side * (EAVE_Z - 0.04)), (EAVE_Y + 0.06, side * (EAVE_Z - 0.04)), (EAVE_Y + 0.06, side * 6.9),
             (EAVE_Y - 0.06, side * 6.92), (EAVE_Y - 0.2, side * 6.86)]
        if side < 0:
            g.reverse()
        roof.prism_x(g, x0 - 0.3, x1 + 0.3)
        # canvas seams over the roof boards: raised welts across the slope
        n = int((x1 - x0) / 1.15)
        for k in range(1, n):
            sx = x0 + k * (x1 - x0) / n
            zs = [side * (MON_Z - 0.02 + (EAVE_Z - MON_Z + 0.02) * j / 6) for j in range(7)]
            path = [(sx, roof_y(z) - 0.02, z) for z in zs]
            roof.sweep(path if side > 0 else path, [(0.04, -0.02), (0.04, 0.02), (-0.04, 0.02), (-0.04, -0.02)], (1, 0, 0), closed=False)
    for xa, xb in ((x0 - 0.3, ma), (mb, x1 + 0.3)):
        roof_strip(-(MON_Z - 0.06), MON_Z - 0.06, xa, xb, 4)
    for side in (-1, 1):
        mon = Piece(f"{name}_mon{side}", "Body", "Paint")
        z0, z1 = sorted((side * 2.2, side * MON_Z))
        mon.box_between((ma, 9.9, z0), (mb, 11.12, z1))
        b0, b1 = ma + 0.4, mb - 0.4
        mon.cutters = [cutter_object(f"cut_m{side}", col, lambda p: p.box_between((b0, 10.2, side * 2.0), (b1, 10.8, side * 2.5)))]
        extra.append(mon)
        if not van:
            trim.sweep(on_side(rect_outline(b0 - 0.1, 10.1, b1 + 0.1, 10.9), side, MON_Z), FINE_BEAD, (0, 0, side))
        n = max(1, round((b1 - b0) / 1.2))
        for k in range(n + 1):
            bx = b0 + (b1 - b0) * k / n
            shell.box_between((bx - 0.06, 10.2, side * 2.2), (bx + 0.06, 10.8, side * (MON_Z + 0.04)))
    for x, d in ((ma, -1), (mb, 1)):
        shell.box_between((min(x, x + d * 0.07), 9.9, -MON_Z), (max(x, x + d * 0.07), 11.12, MON_Z))
    cap = []
    segs = 10
    for k in range(segs + 1):
        z = -2.82 + 5.64 * k / segs
        cap.append((11.12 + 0.3 * (1 - (z / 2.82) ** 2), z))
    capp = cap + [(y - 0.12, z) for y, z in reversed(cap)]
    roof.prism_x(capp, ma - 0.55, mb + 0.55)
    # lamp-tops over every window, and torpedo vents between them on the platform side
    for side in (-1, 1):
        for wx in [] if van else (windows(side) or [cx]):
            zz_ = side * 4.4
            roof.lathe([(0.44, -0.1), (0.44, 0.12), (0.36, 0.22), (0.18, 0.42), (0.2, 0.48), (0.06, 0.58), (0.0, 0.6)], (wx, roof_y(zz_), zz_), "y", 12)
            feat["vents"].append({"x": wx, "z": zz_, "kind": "lamp"})
    vx = [x0 + 2.2, x1 - 2.2]
    for x in vx:
        for side in (-1, 1):
            zz_ = side * 5.5
            if any(abs(x - w) < 1.2 for w in windows(side)):
                continue
            y = roof_y(zz_)
            roof.box_between((x - 0.15, y - 0.1, zz_ - 0.12), (x + 0.15, y + 0.22, zz_ + 0.12))
            roof.lathe([(0.0, -0.5), (0.12, -0.42), (0.18, -0.2), (0.18, 0.25), (0.14, 0.42), (0.08, 0.5), (0.0, 0.52)], (x, y + 0.36, zz_), "x", 10)
            feat["vents"].append({"x": x, "z": zz_, "kind": "torpedo"})

    # underframe: a battery box and the gas cylinder
    fit.lathe([(0.0, 0.0), (0.42, 0.0), (0.42, 0.9), (0.3, 1.0), (0.1, 1.05), (0.1, 1.4)], (cx, -2.4 - 1.4, -2.2), "y", 12)
    fit.box_between((cx - 1.0, -2.3, 2.6), (cx + 1.0, -1.0, 4.4))
    fit.rivets([(cx + dx, -1.6, 4.4) for dx in (-0.8, -0.4, 0.0, 0.4, 0.8)], (0, 0, 1), 0.04, 0.03)

