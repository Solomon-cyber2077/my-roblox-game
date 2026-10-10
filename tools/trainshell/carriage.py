"""
A panelled clerestory carriage shell, from a spec measured off the primitive train.

Pieces (each one MeshPart):
  <car>_Shell  Livery Body: skin, cornice, window surrounds and reveals, waist rail, clerestory skin,
               with the untinted iron and brass fittings (solebar, corner straps, door track, step,
               grab handles, door lamp, underframe boxes) as their own materials in the same mesh
  <car>_Trim   Livery Trim: the gilt beading
  <car>_Roof   Livery Roof: cambered roof, gutters, clerestory cap, lamp-tops
  <car>_Lens   Livery Lamp (Neon): the door lamp's glass
  <car>_Sign   the painted name board (own texture)

Limits that keep gameplay unchanged (see docs/train-exterior/DESIGN_BIBLE.md):
  skin outer face z 6.58; in a door's slide zone nothing stands proud of 6.64 below y 7.5;
  nothing beyond |z| 6.98; openings are cut inside the primitive wall's holes.
"""

import math

from kit import Piece, arch_outline, cutter_object, offset_outline, on_end, on_side, rect_outline

SKIN_IN, SKIN = 6.5, 6.58
TOP = 8.85  # top of the side skin, under the cornice
EAVE_Y, EAVE_Z = 9.78, 6.82  # the roof's edge
MON_Z = 2.27  # clerestory skin outer face
WIN_W, WIN_SILL, WIN_SPRING, WIN_CROWN = 3.36, 3.5, 6.15, 6.88
DOOR_W, DOOR_H = 5.56, 7.48
SLIDE_TOP = 7.5
BEAD = [(0.03, 0.0), (0.024, 0.026), (0.0, 0.038), (-0.024, 0.026), (-0.03, 0.0)]  # half-round gilt bead


def roof_y(z):
    """The cambered roof's top surface height at |z| (a flat arc from the eaves to the middle)."""
    t = min(abs(z), EAVE_Z) / EAVE_Z
    return 10.06 - (10.06 - EAVE_Y) * t * t


def build(spec, col):
    x0, x1 = spec["x0"], spec["x1"]
    cx = (x0 + x1) / 2
    name = spec["name"]
    shell = Piece(f"{name}_Shell", "Body", "Paint")
    trim = Piece(f"{name}_Trim", "Trim", "Gilt")
    roof = Piece(f"{name}_Roof", "Roof", "Canvas")
    lens = Piece(f"{name}_Lens", "Lamp", "Lamp")
    sign = Piece(f"{name}_Sign", None, "Sign")
    iron = []  # (piece-builder) faces tagged later by material: we keep separate Pieces and join
    fit = Piece(f"{name}_Iron", None, "Iron")
    brass = Piece(f"{name}_Brass", None, "Brass")

    def slide_zones(side):
        return [(d - 2 * DOOR_W / 2 - 0.2, d + 2 * DOOR_W / 2 + 0.2) for d in spec["doors"].get(side, [])]

    def in_slide(side, xa, xb, ya=0.0):
        if ya >= SLIDE_TOP:
            return False
        return any(xa < b and xb > a for a, b in slide_zones(side))

    # -- side skins with their openings ------------------------------------------------
    for side in (-1, 1):
        cuts = []
        for wx in spec["windows"].get(side, []):
            outline = arch_outline(wx, WIN_SILL, WIN_W, WIN_SPRING, WIN_CROWN)
            cuts.append(cutter_object(f"cut_w{side}_{wx}", col, lambda p, o=outline: p.prism_z(o, side * 6.0, side * 6.9)))
        for d in spec["doors"].get(side, []):
            o = rect_outline(d - DOOR_W / 2, -0.3, d + DOOR_W / 2, DOOR_H)
            cuts.append(cutter_object(f"cut_d{side}_{d}", col, lambda p, o=o: p.prism_z(o, side * 6.0, side * 6.9)))
        skin = Piece(f"{name}_skin{side}", "Body", "Paint")
        z0, z1 = sorted((side * SKIN_IN, side * SKIN))
        skin.box_between((x0 - 0.08, -0.02, z0), (x1 + 0.08, TOP, z1))
        skin.cutters = cuts
        spec.setdefault("_extra", []).append(skin)

        # window surrounds: a raised frame, the reveal lining into the wall, a sill and a keystone
        for wx in spec["windows"].get(side, []):
            outline = arch_outline(wx, WIN_SILL, WIN_W, WIN_SPRING, WIN_CROWN)
            prof = [(0.06, -0.46), (0.06, 0.05), (0.02, 0.09), (-0.22, 0.09), (-0.28, 0.04), (-0.28, 0.0), (0.0, 0.0), (0.0, -0.46)]
            shell.sweep(on_side(outline, side, SKIN), prof, (0, 0, side))
            shell.box_between((wx - WIN_W / 2 - 0.36, WIN_SILL - 0.22, side * SKIN), (wx + WIN_W / 2 + 0.36, WIN_SILL - 0.02, side * (SKIN + 0.16)))
            shell.box_between((wx - 0.16, WIN_CROWN - 0.06, side * SKIN), (wx + 0.16, WIN_CROWN + 0.34, side * (SKIN + 0.11)))
            # gilt bead just inside the frame's outer edge
            trim.sweep(on_side(offset_outline(outline, 0.2), side, SKIN + 0.09), BEAD, (0, 0, side))
        # door reveals and a flat gilt architrave (flush: the leaves slide over it)
        for d in spec["doors"].get(side, []):
            o = rect_outline(d - DOOR_W / 2, -0.02, d + DOOR_W / 2, DOOR_H)
            shell.sweep(on_side(o, side, SKIN), [(0.05, -0.46), (0.05, 0.0), (0.0, 0.0), (0.0, -0.46)], (0, 0, side))
            trim.sweep(on_side(offset_outline(o, 0.14), side, SKIN), BEAD, (0, 0, side))

        # waist rail under the windows (stops at doors), with a bead above and below
        rail_spans = [(x0 - 0.08, x1 + 0.08)]
        for d in spec["doors"].get(side, []):
            nxt = []
            for a, b in rail_spans:
                l, r = d - DOOR_W / 2 - 0.02, d + DOOR_W / 2 + 0.02
                if a < l:
                    nxt.append((a, min(b, l)))
                if b > r:
                    nxt.append((max(a, r), b))
            rail_spans = nxt
        zs, zo = side * SKIN, side * (SKIN + 0.05)
        for a, b in rail_spans:
            shell.box_between((a, 2.98, zs), (b, 3.32, zo))
            for yb in (2.98, 3.32):
                trim.sweep([(a + 0.04, yb, side * (SKIN + 0.05)), (b - 0.04, yb, side * (SKIN + 0.05))], BEAD, (0, 0, side), closed=False)

        # panel beading: a ring in every lower panel, pier and eaves panel, clear of openings
        def ring(xa, xb, ya, yb):
            if xb - xa < 0.8 or yb - ya < 0.6:
                return
            o = rect_outline(xa, ya, xb, yb)
            trim.sweep(on_side(o, side, SKIN), BEAD, (0, 0, side))

        blocks = []  # x spans taken by doors (full height)
        for d in spec["doors"].get(side, []):
            blocks.append((d - DOOR_W / 2 - 0.35, d + DOOR_W / 2 + 0.35))
        free = [(x0 + 0.35, x1 - 0.35)]
        for a, b in blocks:
            nxt = []
            for fa, fb in free:
                if fa < a:
                    nxt.append((fa, min(fb, a)))
                if fb > b:
                    nxt.append((max(fa, b), fb))
            free = nxt
        for fa, fb in free:
            n = max(1, round((fb - fa) / 4.2))
            for k in range(n):
                xa = fa + (fb - fa) * k / n + 0.1
                xb = fa + (fb - fa) * (k + 1) / n - 0.1
                ring(xa, xb, 0.42, 2.66)
        # piers between windows (and between a window and an end or a door)
        edges = [x0 + 0.35, x1 - 0.35]
        for d in spec["doors"].get(side, []):
            edges += [d - DOOR_W / 2 - 0.35, d + DOOR_W / 2 + 0.35]
        for wx in spec["windows"].get(side, []):
            edges += [wx - WIN_W / 2 - 0.45, wx + WIN_W / 2 + 0.45]
        edges.sort()
        for i in range(0, len(edges) - 1):
            a, b = edges[i], edges[i + 1]
            mid = (a + b) / 2
            if b - a < 0.9:
                continue
            if any(abs(mid - wx) < WIN_W / 2 for wx in spec["windows"].get(side, [])):
                continue
            if any(abs(mid - d) < DOOR_W / 2 + 0.3 for d in spec["doors"].get(side, [])):
                continue
            ring(a + 0.12, b - 0.12, 3.62, 6.86)
        # the name board sits in the longest stretch of the eaves clear of a door lamp
        spans = [(x0 + 0.5, x1 - 0.5)]
        for d in spec["doors"].get(side, []):
            nxt = []
            for a, b in spans:
                l, r = d - 0.9, d + 0.9
                if a < l:
                    nxt.append((a, min(b, l)))
                if b > r:
                    nxt.append((max(a, r), b))
            spans = nxt
        a, b = max(spans, key=lambda s: s[1] - s[0])
        blen = min(spec["board"], b - a - 0.6)
        bc = (a + b) / 2
        spec.setdefault("boards", {})[side] = (bc, blen)
        bx0, bx1 = bc - blen / 2 - 0.3, bc + blen / 2 + 0.3
        for a, b in ((x0 + 0.35, bx0), (bx1, x1 - 0.35)):
            if not any(a < d + 0.9 and b > d - 0.9 for d in spec["doors"].get(side, [])):
                ring(a, b, 7.66, 8.6)

        # the name board: dark ground, raised edge, painted gilt letters (texture)
        sign.box_between((bc - blen / 2, 7.8, side * SKIN), (bc + blen / 2, 8.62, side * (SKIN + 0.07)))
        trim.sweep(on_side(rect_outline(bc - blen / 2 - 0.12, 7.68, bc + blen / 2 + 0.12, 8.74), side, SKIN), BEAD, (0, 0, side))

        # cornice: an ogee that carries the roof's edge
        cor = [(TOP - 0.1, SKIN_IN), (TOP - 0.1, SKIN + 0.02), (TOP + 0.02, SKIN + 0.06), (TOP + 0.2, SKIN + 0.07),
               (TOP + 0.38, SKIN + 0.16), (TOP + 0.5, SKIN + 0.22), (EAVE_Y - 0.06, SKIN + 0.22), (EAVE_Y - 0.06, SKIN_IN)]
        cor = [(y, side * z) for y, z in cor]
        if side < 0:
            cor.reverse()
        shell.prism_x(cor, x0 - 0.12, x1 + 0.12)

        # iron: the solebar (a channel on its side) with a row of rivets
        sol = [(-1.0, SKIN_IN), (-1.0, 6.68), (-0.9, 6.68), (-0.9, 6.6), (-0.1, 6.6), (-0.1, 6.68), (0.0, 6.68), (0.0, SKIN_IN)]
        sol = [(y, side * z) for y, z in sol]
        if side < 0:
            sol.reverse()
        fit.prism_x(sol, x0 - 0.1, x1 + 0.1)
        n = int((x1 - x0) / 0.7)
        fit.rivets([(x0 + 0.35 + k * (x1 - x0 - 0.7) / n, -0.5, side * 6.6) for k in range(n + 1)], (0, 0, side), 0.06, 0.04)
        # corner straps: riveted angle iron down every corner
        for ex, ed in ((x0, -1), (x1, 1)):
            fit.box_between((ex + ed * 0.1 - ed * 0.42, -0.02, side * SKIN), (ex + ed * 0.1, TOP - 0.1, side * (SKIN + 0.04)))
            fit.rivets([(ex - ed * 0.12, 0.4 + k * 0.9, side * (SKIN + 0.04)) for k in range(10)], (0, 0, side), 0.05, 0.035)
        # doors: the hanging track over the opening, its brackets, the step and a lamp above
        for d in spec["doors"].get(side, []):
            a, b = max(x0 + 0.05, d - DOOR_W - 0.25), min(x1 - 0.05, d + DOOR_W + 0.25)
            trk = [(SLIDE_TOP + 0.02, SKIN), (SLIDE_TOP + 0.02, 6.96), (SLIDE_TOP + 0.22, 6.96), (SLIDE_TOP + 0.22, 6.9),
                   (SLIDE_TOP + 0.08, 6.9), (SLIDE_TOP + 0.08, SKIN)]
            trk = [(y, side * z) for y, z in trk]
            if side < 0:
                trk.reverse()
            fit.prism_x(trk, a, b)
            for bx in (a + 0.2, d, b - 0.2):
                fit.box_between((bx - 0.12, SLIDE_TOP + 0.02, side * SKIN), (bx + 0.12, SLIDE_TOP + 0.36, side * 6.92))
            fit.rivets([(x, SLIDE_TOP + 0.15, side * 6.96) for x in (a + 0.6, d - 1.5, d + 1.5, b - 0.6)], (0, 0, side), 0.04, 0.03)
            # a recessed step under the doorway on two hangers
            fit.box_between((d - 1.8, -1.32, side * 5.9), (d + 1.8, -1.18, side * 6.86))
            for hx in (d - 1.6, d + 1.6):
                fit.box_between((hx - 0.06, -1.32, side * 6.55), (hx + 0.06, -0.9, side * 6.68))
            # the door lamp: a hooded brass box on the track's middle bracket, glass towards the platform
            ly = SLIDE_TOP + 0.62
            brass.box_between((d - 0.32, ly - 0.25, side * SKIN), (d + 0.32, ly + 0.32, side * 6.78))
            brass.box_between((d - 0.4, ly + 0.32, side * SKIN), (d + 0.4, ly + 0.4, side * 6.9))
            brass.lathe([(0.12, 0), (0.09, 0.12), (0.03, 0.2), (0.0, 0.22)], (d, ly + 0.4, side * 6.7), "y", 8)
            lens.box_between((d - 0.24, ly - 0.17, side * 6.78), (d + 0.24, ly + 0.24, side * 6.84))
        # grab handles near the ends, outside any slide zone
        for ex, ed in ((x0, 1), (x1, -1)):
            hx = ex + ed * 0.75
            if in_slide(side, hx - 0.2, hx + 0.2):
                continue
            brass.box_between((hx - 0.05, 1.2, side * 6.74), (hx + 0.05, 5.6, side * 6.84))
            for hy in (1.3, 5.5):
                brass.box_between((hx - 0.07, hy - 0.07, side * SKIN), (hx + 0.07, hy + 0.07, side * 6.76))

    # -- end walls ---------------------------------------------------------------------
    for ex, ed, gang in ((x0, -1, spec["rearGangway"]), (x1, 1, spec["frontGangway"])):
        end = Piece(f"{name}_end{ed}", "Body", "Paint")
        xa, xb = sorted((ex, ex + ed * 0.08))
        end.box_between((xa, -0.02, -SKIN_IN), (xb, TOP, SKIN_IN))
        if gang:
            o = rect_outline(-2.04, -0.3, 2.04, 7.04)
            end.cutters = [cutter_object(f"cut_g{ed}", col, lambda p, o=o: p.prism_y([(xa - 0.3, -2.04), (xb + 0.3, -2.04), (xb + 0.3, 2.04), (xa - 0.3, 2.04)], -0.3, 7.04))]
        spec["_extra"].append(end)
        # end beading and the cornice's return
        xf = ex + ed * 0.08
        for za, zb in ((-6.1, -2.6), (2.6, 6.1)):
            o = rect_outline(za, 0.42, zb, 8.4)
            trim.sweep(on_end(o, ed, xf), BEAD, (ed, 0, 0))
        # the headstock: the underframe's end beam
        fit.box_between((min(xf, xf + ed * 0.12), -1.0, -SKIN_IN), (max(xf, xf + ed * 0.12), 0.0, SKIN_IN))
        # gangway: an iron frame round the opening
        if gang:
            gp = rect_outline(-2.04, -0.02, 2.04, 7.04)
            fit.sweep(on_end(gp, ed, xf), [(0.0, 0.0), (0.0, 0.06), (-0.22, 0.06), (-0.22, 0.0)], (ed, 0, 0))
        # end handrails up each side of the gangway
        for zz in (-3.2, 3.2):
            brass.box_between((xf + ed * 0.2 - 0.05, 0.6, zz - 0.05), (xf + ed * 0.2 + 0.05, 6.4, zz + 0.05))
            for hy in (0.7, 6.3):
                brass.box_between((min(xf, xf + ed * 0.22), hy - 0.06, zz - 0.06), (max(xf, xf + ed * 0.22), hy + 0.06, zz + 0.06))

    # -- roof ---------------------------------------------------------------------------
    ma, mb = spec["monitor"]
    def roof_strip(za, zb, xa, xb, segs=6):
        prof_top = [(roof_y(za + (zb - za) * k / segs), za + (zb - za) * k / segs) for k in range(segs + 1)]
        prof = prof_top + [(y - 0.12, z) for y, z in reversed(prof_top)]
        roof.prism_x(prof, xa, xb)
    for side in (-1, 1):
        za, zb = sorted((side * (MON_Z - 0.06), side * EAVE_Z))
        roof_strip(za, zb, x0 - 0.3, x1 + 0.3)
        # gutter along the eaves
        g = [(EAVE_Y - 0.14, side * (EAVE_Z - 0.04)), (EAVE_Y + 0.06, side * (EAVE_Z - 0.04)), (EAVE_Y + 0.06, side * 6.92),
             (EAVE_Y - 0.14, side * 6.92)]
        if side < 0:
            g.reverse()
        roof.prism_x(g, x0 - 0.3, x1 + 0.3)
    for xa, xb in ((x0 - 0.3, ma), (mb, x1 + 0.3)):
        roof_strip(-(MON_Z - 0.06), MON_Z - 0.06, xa, xb, 4)
    # clerestory skin with the long light band, and its ends
    for side in (-1, 1):
        mon = Piece(f"{name}_mon{side}", "Body", "Paint")
        z0, z1 = sorted((side * 2.2, side * MON_Z))
        mon.box_between((ma, 9.9, z0), (mb, 11.12, z1))
        b0, b1 = ma + 0.4, mb - 0.4
        mon.cutters = [cutter_object(f"cut_m{side}", col, lambda p: p.box_between((b0, 10.2, side * 2.0), (b1, 10.8, side * 2.5)))]
        spec["_extra"].append(mon)
        trim.sweep(on_side(rect_outline(b0 - 0.1, 10.1, b1 + 0.1, 10.9), side, MON_Z), BEAD, (0, 0, side))
        # glazing bars in front of the amber glass
        n = max(1, round((b1 - b0) / 2.4))
        for k in range(n + 1):
            bx = b0 + (b1 - b0) * k / n
            shell.box_between((bx - 0.07, 10.2, side * 2.2), (bx + 0.07, 10.8, side * (MON_Z + 0.03)))
    for x, d in ((ma, -1), (mb, 1)):
        shell.box_between((min(x, x + d * 0.07), 9.9, -MON_Z), (max(x, x + d * 0.07), 11.12, MON_Z))
    # the clerestory's arched cap with a dripping edge
    cap = []
    segs = 8
    for k in range(segs + 1):
        z = -2.78 + 5.56 * k / segs
        cap.append((11.12 + 0.3 * (1 - (z / 2.78) ** 2), z))
    capp = cap + [(y - 0.1, z) for y, z in reversed(cap)]
    roof.prism_x(capp, ma - 0.55, mb + 0.55)
    # lamp-tops over the far-side windows
    for wx in spec["windows"].get(-1, []):
        for side in (-1, 1):
            zz = side * 4.4
            roof.lathe([(0.44, -0.1), (0.44, 0.12), (0.36, 0.22), (0.18, 0.42), (0.2, 0.48), (0.06, 0.58), (0.0, 0.6)], (wx, roof_y(zz), zz), "y", 10)

    # -- underframe dressing --------------------------------------------------------------
    fit.lathe([(0.0, 0.0), (0.42, 0.0), (0.42, 0.9), (0.3, 1.0), (0.1, 1.05), (0.1, 1.4)], (cx, -2.4 - 1.4, -2.2), "y", 12)
    fit.box_between((cx - 1.0, -2.3, 2.6), (cx + 1.0, -1.0, 4.4))

    for p in (shell, trim, roof, lens, sign, fit, brass):
        p.bevel = (0.02, 1, 40) if p in (shell, fit, brass) else None
    return [shell, trim, roof, lens, sign, fit, brass] + spec["_extra"]
