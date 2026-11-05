"""Mabel Orrin on the blocky R6 body: skirt + ticket pouch, hair + bun, eyeshade, ticket punch.
Run mabel_textures.py first, then: blender -b --python tools/crew-clothing/mabel_r6.py
Blender is Z-up with the figure facing -Y (her right hand at -X). Each piece is built in its
limb's space (origin at the limb centre) and exported in studs with forward_axis='Z', up_axis='Y'
like build.py, so OBJ = Roblox limb space (-Z front). Pieces are centred on their bounds; the
manifest offset is that centre in limb space, size is the native mesh size.
Output: $MABEL_OUT (default assets/crew-clothing/mabel-r6), renders at 50%.
"""
import bpy, math, json, os, sys
from pathlib import Path
from mathutils import Vector, Matrix
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gear

OUT = Path(os.environ.get('MABEL_OUT', Path(__file__).resolve().parents[2] / 'assets/crew-clothing/mabel-r6'))
BEFORE_ONLY = os.environ.get('MABEL_PLAIN') == '1'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
TAU = math.tau

def lin(c):
    return tuple((v / 255) ** 2.2 for v in c)

class M:
    """Polygon soup with per-corner UVs; faces are flipped to face `out` when given."""
    def __init__(self, name):
        self.name = name; self.v = []; self.f = []; self.uv = []
    def face(self, pts, uvs, out=None):
        if out is not None:
            a, b, c = Vector(pts[0]), Vector(pts[1]), Vector(pts[2])
            n = (b - a).cross(c - a)
            if n.length > 1e-9 and n.dot(Vector(out)) < 0:
                pts = list(reversed(pts)); uvs = list(reversed(uvs))
        s = len(self.v); self.v.extend(pts)
        self.f.append(tuple(range(s, s + len(pts)))); self.uv.append(list(uvs))
    def grid(self, P, U, out_fn, close=False):
        """P[i][j] points, U[i][j] uvs; rows i, columns j; out_fn(point) gives the outside."""
        rows, cols = len(P), len(P[0])
        for i in range(rows - 1):
            for j in range(cols - (0 if close else 1)):
                k = (j + 1) % cols
                pts = [P[i][j], P[i][k], P[i + 1][k], P[i + 1][j]]
                uvs = [U[i][j], U[i][k] if k else (U[i][k][0] + (1 if close else 0), U[i][k][1]), U[i + 1][k] if k else (U[i + 1][k][0] + (1 if close else 0), U[i + 1][k][1]), U[i + 1][j]]
                c = sum((Vector(p) for p in pts), Vector()) / 4
                self.face(pts, uvs, out_fn(c))
    def tube(self, path, radius, u0, u1, v0, v1, sides=6, close=False):
        n = len(path); ring = []
        for i, p in enumerate(path):
            a = Vector(path[min(i + 1, n - 1)] if not close else path[(i + 1) % n])
            b = Vector(path[max(i - 1, 0)] if not close else path[(i - 1) % n])
            t = (a - b).normalized()
            ref = Vector((0, 0, 1)) if abs(t.z) < .9 else Vector((1, 0, 0))
            s = t.cross(ref).normalized(); up = s.cross(t).normalized()
            r = radius(i / max(1, n - 1)) if callable(radius) else radius
            ring.append([Vector(p) + r * (math.cos(k * TAU / sides) * s + math.sin(k * TAU / sides) * up) for k in range(sides)])
        segs = n if close else n - 1
        for i in range(segs):
            i2 = (i + 1) % n
            for k in range(sides):
                k2 = (k + 1) % sides
                pts = [tuple(ring[i][k]), tuple(ring[i2][k]), tuple(ring[i2][k2]), tuple(ring[i][k2])]
                ua, ub = u0 + (u1 - u0) * i / segs, u0 + (u1 - u0) * (i + 1) / segs
                va, vb = v0 + (v1 - v0) * k / sides, v0 + (v1 - v0) * (k + 1) / sides
                c = (ring[i][k] + ring[i2][k2]) / 2
                axis = Vector(path[i]) + Vector(path[i2]); axis /= 2
                self.face(pts, [(ua, va), (ub, va), (ub, vb), (ua, vb)], c - axis)
    def box(self, center, size, uvrect, rot=None):
        cx, cy, cz = center; hx, hy, hz = [s / 2 for s in size]
        u0, v0, u1, v1 = uvrect
        corners = [Vector((x, y, z)) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)]
        R = rot or Matrix.Identity(3)
        P = [tuple(R @ c + Vector(center)) for c in corners]
        quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for q in quads:
            pts = [P[i] for i in q]
            c = sum((Vector(p) for p in pts), Vector()) / 4
            self.face(pts, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)], c - Vector(center))
    def tris(self):
        return sum(len(f) - 2 for f in self.f)
    def obj(self, material, location=(0, 0, 0)):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.v, [], self.f); mesh.update()
        uv = mesh.uv_layers.new()
        for poly, uvs in zip(mesh.polygons, self.uv):
            for li, t in zip(poly.loop_indices, uvs):
                uv.data[li].uv = t
        mesh.materials.append(material)
        for p in mesh.polygons:
            p.use_smooth = True
        ob = bpy.data.objects.new(self.name, mesh); bpy.context.collection.objects.link(ob)
        ob.location = location
        return ob

def material(name, color, rough=.8):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*lin(color), 1); p.inputs['Roughness'].default_value = rough
    return m

def textured(path, name, rough=.8, metal=0.0):
    m = gear.atlas_material(path, name)
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Roughness'].default_value = rough; p.inputs['Metallic'].default_value = metal
    return m

def sup(c, n):
    return math.copysign(abs(c) ** (2 / n), c)

# ------------------------------------------------------------------ head shape (R6 head mesh)
HR, HH, HP = .6, .6, 3.0  # radius, half-height, profile exponent of the classic rounded head
def head_r(z):
    return HR * max(0.0, 1 - abs(z / HH) ** HP) ** (1 / HP)

def head_point(theta, phi, scale=1.0):
    """phi 0 = crown, pi = chin; theta 0 = front (-Y), positive toward her left (+X)."""
    z = HH * sup(math.cos(phi), HP) ; r = HR * abs(sup(math.sin(phi), HP))
    return Vector((r * math.sin(theta) * scale, -r * math.cos(theta) * scale, z * scale))

# ------------------------------------------------------------------ skirt + ticket pouch (Torso)
SKIRT_KEYS = [(-.55, 1.06, .58, 10), (-1.0, 1.08, .60, 8), (-1.4, 1.22, .72, 5), (-2.0, 1.36, .84, 3.5), (-2.85, 1.50, .96, 3)]
ROWS = [-.55, -.68, -.84, -1.0, -1.15, -1.3, -1.5, -1.75, -2.0, -2.3, -2.6, -2.85]
SEG = 40

def skirt_params(z):
    for (z0, *a), (z1, *b) in zip(SKIRT_KEYS, SKIRT_KEYS[1:]):
        if z1 <= z <= z0:
            t = (z0 - z) / (z0 - z1)
            return [x + (y - x) * t for x, y in zip(a, b)]
    return SKIRT_KEYS[-1][1:]

def pleat(z):
    return 0 if z > -1.0 else .05 * ((-1.0 - z) / 1.85)

def skirt_point(theta, z, pleated=True):
    hx, hd, n = skirt_params(z)
    t = max(0, (-1.0 - z) / 1.85)
    x = hx * sup(math.sin(theta), n)
    y = -hd * sup(math.cos(theta), n)
    if y > 0:
        y *= 1 + .12 * t  # fuller at the back
    k = 1 + (pleat(z) * math.cos(14 * theta) if pleated else pleat(z))
    zz = z + (.025 * math.sin(7 * theta + .6) * t ** 3 if pleated else 0)
    return Vector((x * k, y * k, zz))

def skirt():
    m = M('mabel skirt')
    V = lambda row: 1 - row / 1024
    P = [[tuple(skirt_point(j / SEG * TAU, z)) for j in range(SEG)] for z in ROWS]
    U = [[(j / SEG, V(600 * i / (len(ROWS) - 1))) for j in range(SEG)] for i, z in enumerate(ROWS)]
    out = lambda c: Vector((c.x, c.y, 0))
    m.grid(P, U, out, close=True)
    # turned hem, seen from below
    hem = P[-1]
    inner = [tuple(Vector(p) * Vector((.93, .93, 1)) + Vector((0, 0, .22))) for p in hem]
    for j in range(SEG):
        k = (j + 1) % SEG
        pts = [hem[j], hem[k], inner[k], inner[j]]
        c = sum((Vector(p) for p in pts), Vector()) / 4
        m.face(pts, [(j / SEG, V(640)), ((j + 1) / SEG, V(640)), ((j + 1) / SEG, V(604)), (j / SEG, V(604))], Vector((-c.x, -c.y, -.3)))
    # waistband
    wb = [[tuple(skirt_point(j / SEG * TAU, z) * Vector((1.018, 1.018, 1))) for j in range(SEG)] for z in (-.55, -.67)]
    m.grid(wb, [[(.5 + .25 * j / SEG, V(650 + 100 * i)) for j in range(SEG)] for i in range(2)], out, close=True)
    for j in range(SEG):  # band top lip so the edge has thickness
        k = (j + 1) % SEG
        a, b = Vector(wb[0][j]), Vector(wb[0][k])
        m.face([tuple(a), tuple(b), tuple(b * Vector((.96, .96, 1))), tuple(a * Vector((.96, .96, 1)))],
               [(.5, V(650)), (.75, V(650)), (.75, V(660)), (.5, V(660))], (0, 0, 1))
    # buckle
    f = skirt_point(0, -.61, False)
    m.box((0, f.y - .03, -.61), (.2, .03, .14), (.76, V(760), .99, V(650)))
    # ticket pouch on her left hip, hung from the belt on a short strap: a stitched leather body,
    # a flap with a brass turn-clasp, and the day's ticket stubs showing behind the flap
    th = .6  # front-left, in view from the front, clear of the arm
    out_d = Vector((math.sin(th), -math.cos(th), 0))
    R = Matrix.Rotation(th, 3, 'Z')
    hip = skirt_point(th, -.95, False)
    bw, bd, bh = .42, .14, .46  # body width, depth, height
    centre = hip + out_d * (bd / 2 + .02) + Vector((0, 0, 0))
    m.box(tuple(centre), (bw, bd, bh), (0, V(896), .5, V(640)), R)
    # flap over the top third, a touch proud of the body and wider
    flap_c = centre + out_d * .012 + Vector((0, 0, bh / 2 - .07))
    m.box(tuple(flap_c), (bw + .02, bd + .02, .16), (0, V(1024), .5, V(896)), R)
    # brass turn-clasp on the flap's front edge
    clasp = centre + out_d * (bd / 2 + .03) + Vector((0, 0, bh / 2 - .15))
    m.box(tuple(clasp), (.06, .02, .05), (.76, V(760), .99, V(650)), R)
    # strap from the belt to the pouch's back corners
    for k in (-1, 1):
        side = Vector((math.cos(th), math.sin(th), 0)) * k * (bw / 2 - .05)
        top = skirt_point(th, -.6, False) + out_d * .025 + side
        low = centre + side + out_d * (-bd / 2 + .01) + Vector((0, 0, bh / 2 - .02))
        m.tube([tuple(top), tuple(low)], .018, .5, .75, V(896), V(1024), sides=4)
    # stubs: three cream tickets sticking up behind the flap, slightly fanned
    for k, (dx, h, tilt) in enumerate(((-.09, .09, -.12), (0, .12, .02), (.08, .08, .14))):
        side = Vector((math.cos(th), math.sin(th), 0)) * dx
        c = centre + side + out_d * (-.02) + Vector((0, 0, bh / 2 + h / 2 - .02))
        m.box(tuple(c), (.07, .008, h), (.75 + .08 * k, V(896), .8 + .08 * k, V(768)), R @ Matrix.Rotation(tilt, 3, 'Y'))
    return m

# ------------------------------------------------------------------ hair + bun (Head)
def hairline(theta):
    s = (1 - math.cos(theta)) / 2
    return .32 - .72 * s

def phi_for(z):
    c = abs(z / HH) ** (HP / 2) * (1 if z >= 0 else -1)
    return math.acos(max(-1, min(1, c)))

def hair_scale(theta, phi):
    s = (1 - math.cos(theta)) / 2
    pomp = .05 * math.exp(-(theta / .7) ** 2) * math.exp(-((phi - .75) / .35) ** 2)  # swept-up front roll
    side = .03 * math.exp(-((abs(theta) - 1.5) / .5) ** 2) * math.exp(-((phi - 1.25) / .3) ** 2)
    ridge = .008 * math.cos(28 * theta) * math.sin(phi)
    part = -.012 * math.exp(-(theta / .1) ** 2) * math.exp(-((phi - .5) / .3) ** 2)
    return 1.085 + .02 * s + pomp + side + ridge + part

def hair():
    m = M('mabel hair')
    seg, rows = 32, 11
    ths = [-math.pi + TAU * j / seg for j in range(seg)]
    P, U = [], []
    for i in range(rows):
        t = i / (rows - 1)
        row, urow = [], []
        for j, th in enumerate(ths):
            ph = max(.06, t * phi_for(hairline(th)))
            row.append(tuple(head_point(th, ph, hair_scale(th, ph))))
            urow.append((j / seg, 1 - .75 * t))
        P.append(row); U.append(urow)
    m.grid(P, U, lambda c: c, close=True)
    # crown cap
    top = tuple(head_point(0, 0, 1.12))
    for j in range(seg):
        k = (j + 1) % seg
        m.face([top, P[0][j], P[0][k]], [(.5, 1), (j / seg, 1), ((j + 1) / seg, 1)], (0, 0, 1))
    # rolled-under hairline edge
    for j in range(seg):
        k = (j + 1) % seg
        pa, pb = phi_for(hairline(ths[j])), phi_for(hairline(ths[k]))
        ia, ib = head_point(ths[j], pa + .05, 1.04), head_point(ths[k], pb + .05, 1.04)
        m.face([P[-1][j], P[-1][k], tuple(ib), tuple(ia)], [(j / seg, .26), ((j + 1) / seg, .26), ((j + 1) / seg, .25), (j / seg, .25)],
               (ia + ib) / 2 + Vector((0, 0, -.5)))
    # coiled bun at the back of the crown, two and a half turns
    c = Vector((0, .64, .40)); nrm = Vector((0, .87, .5)).normalized()
    a1 = Vector((1, 0, 0)); a2 = nrm.cross(a1).normalized()
    path = []
    for k in range(41):
        t = k / 40; a = t * 2.5 * TAU
        r = .22 * (1 - .78 * t)
        path.append(tuple(c + r * (math.cos(a) * a1 + math.sin(a) * a2) + nrm * (.07 * t + .04 * math.sin(math.pi * t))))
    m.tube(path, lambda t: .085 * (1 - .35 * t), 0, .92, .25, .08, sides=6)
    # hairpins
    for s in (-1, 1):
        p0 = c + .2 * s * a1 + .06 * a2 + nrm * .1
        m.tube([tuple(p0), tuple(p0 + Vector((-s * .1, -.02, .1)))], .012, .93, 1, .25, 0, sides=3)
    return m

# ------------------------------------------------------------------ eyeshade (Head)
def band_z(theta):
    s = (1 - math.cos(theta)) / 2
    return .31 - .23 * s

def band_r(z):
    return head_r(z) * 1.13 + .035

def eyeshade():
    m = M('mabel eyeshade')
    seg = 32
    ths = [-math.pi + TAU * j / seg for j in range(seg)]
    def ring(th, dz, extra=0):
        z = band_z(th) + dz; r = band_r(band_z(th)) + extra
        return (r * math.sin(th), -r * math.cos(th), z)
    P = [[ring(th, dz) for th in ths] for dz in (.075, -.075)]
    U = [[(j / seg, 1 - .5 * i) for j in range(seg)] for i in range(2)]
    m.grid(P, U, lambda c: Vector((c.x, c.y, 0)), close=True)
    for j in range(seg):  # top edge
        k = (j + 1) % seg
        a, b = P[0][j], P[0][k]
        ia, ib = ring(ths[j], .075, -.03), ring(ths[k], .075, -.03)
        m.face([a, b, ib, ia], [(j / seg, 1), ((j + 1) / seg, 1), ((j + 1) / seg, .98), (j / seg, .98)], (0, 0, 1))
    # brim: three rows, curved down, double-sided, brass bound edge
    bs = 14; lim = 1.2
    bth = [-lim + 2 * lim * j / bs for j in range(bs + 1)]
    def brim(th, t, under=0.0):
        base = Vector(ring(th, -.07, .005))
        L = .37 * max(0, math.cos(th / lim * math.pi / 2)) ** .55 + .03
        d = Vector((math.sin(th), -math.cos(th), 0))
        return base + d * (L * t) + Vector((0, 0, -.11 * t ** 1.4 * (L / .4) - under))
    for under in (0, .018):
        Pb = [[tuple(brim(th, t, under)) for th in bth] for t in (0, .5, 1)]
        Ub = [[(j / bs, .5 - .375 * i / 2) for j in range(bs + 1)] for i in range(3)]
        m.grid(Pb, Ub, (lambda c: Vector((0, 0, 1))) if under == 0 else (lambda c: Vector((0, 0, -1))))
    edge = [brim(th, 1, .009) for th in bth]
    m.tube([tuple(p) for p in edge], .014, 0, 1, .125, 0, sides=4)
    # back strap buckle
    b = Vector(ring(math.pi, 0, .015))
    m.box(tuple(b), (.12, .025, .1), (0, .02, 1, .1))
    return m

# ------------------------------------------------------------------ ticket punch (Right Arm)
def punch():
    m = M('mabel ticket punch'); slots = []
    def add(fn, slot):
        before = len(m.f); fn(); slots.extend([slot] * (len(m.f) - before))
    R = Matrix.Rotation(math.radians(28), 3, 'X')  # head tipped forward out of the grip
    o = Vector((0, -.4, -.84))
    T = lambda p: tuple(R @ (Vector(p) * 1.4) + o)
    def lever(x, slot):
        add(lambda: m.box(T((x, 0, -.12)), (.06, .05, .34), (0, 0, 1, 1), R), slot)
    lever(-.035, 0); lever(.035, 1)
    add(lambda: m.box(T((0, -.02, -.34)), (.16, .1, .12), (0, 0, 1, 1), R), 0)  # head
    add(lambda: m.box(T((0, -.07, -.43)), (.1, .05, .08), (0, 0, 1, 1), R), 2)  # die
    add(lambda: m.box(T((0, .03, -.43)), (.1, .04, .08), (0, 0, 1, 1), R), 2)  # jaw
    add(lambda: m.tube([T((-.09, -.02, -.30)), T((.09, -.02, -.30))], .03, 0, 1, 0, 1, sides=6), 1)  # pivot rivet
    add(lambda: m.tube([T((0, -.025, .05)), T((0, -.06, .08)), T((0, -.025, .11))], .015, 0, 1, 0, 1, sides=4), 3)  # chain ring
    # short chain up the front of the hand to the cuff button
    pts = [Vector(T((0, -.06, .1)))]
    end = Vector((.05, -.535, -.56))
    links = 6
    for k in range(1, links + 1):
        t = k / links
        p = pts[0].lerp(end, t)
        p.y = min(p.y, -.53) - .012 * math.sin(math.pi * t)
        pts.append(p)
    for k in range(links):
        a, b = pts[k], pts[k + 1]
        mid = (a + b) / 2; ax = (b - a).normalized()
        side = ax.cross(Vector((0, 1, 0))).normalized() if k % 2 == 0 else Vector((0, -1, 0))
        loop = [tuple(mid + ax * .045 * math.cos(q) + side * .02 * math.sin(q)) for q in [i / 6 * TAU for i in range(6)]]
        add(lambda: m.tube(loop, .007, 0, 1, 0, 1, sides=3, close=True), 3)
    return m, slots

# ------------------------------------------------------------------ export
manifest = {}
def export(m, limb, origin, mat, texture, slots=None):
    ob = m.obj(mat)
    if slots is not None:
        gear.assign_uv(ob.data, slots)
    me = ob.data; me.calc_loop_triangles(); count = len(me.loop_triangles)
    lo = [min(v.co[i] for v in me.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in me.vertices) for i in range(3)]
    c = Vector([(a + b) / 2 for a, b in zip(lo, hi)]); dims = [b - a for a, b in zip(lo, hi)]
    for v in me.vertices:
        v.co -= c
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    file = m.name.replace('mabel ', '').replace(' ', '-') + '.obj'
    bpy.ops.wm.obj_export(filepath=str(OUT / file), export_selected_objects=True, export_materials=False,
                          export_triangulated_mesh=True, forward_axis='Z', up_axis='Y')
    ob.location = Vector(origin) + c
    key = m.name.replace('mabel ', '').title().replace(' ', '')
    manifest[key] = {'name': key, 'limb': limb, 'mesh': file, 'texture': texture,
                     'size': [round(dims[0], 3), round(dims[2], 3), round(dims[1], 3)],
                     'offset': [round(-c.x, 3), round(c.z, 3), round(c.y, 3)], 'yaw': 0, 'triangles': count}
    return ob

# ------------------------------------------------------------------ R6 review body
SHEET = (585, 559)
TORSO_R = {'front': (231, 74, 128, 128), 'back': (427, 74, 128, 128), 'right': (165, 74, 64, 128),
           'left': (361, 74, 64, 128), 'up': (231, 8, 128, 64), 'down': (231, 204, 128, 64)}
def limb_rects(right):
    if right:
        return {'left': (19, 355, 64, 128), 'back': (85, 355, 64, 128), 'right': (151, 355, 64, 128),
                'front': (217, 355, 64, 128), 'up': (217, 289, 64, 64), 'down': (217, 485, 64, 64)}
    return {'front': (308, 355, 64, 128), 'left': (374, 355, 64, 128), 'back': (440, 355, 64, 128),
            'right': (506, 355, 64, 128), 'up': (308, 289, 64, 64), 'down': (308, 485, 64, 64)}

def faces(hx, hy, hz):
    return {'front': [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)],
            'back': [(hx, hy, -hz), (-hx, hy, -hz), (-hx, hy, hz), (hx, hy, hz)],
            'right': [(-hx, hy, -hz), (-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz)],
            'left': [(hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (hx, -hy, hz)],
            'up': [(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)],
            'down': [(-hx, hy, -hz), (hx, hy, -hz), (hx, -hy, -hz), (-hx, -hy, -hz)]}

def sheet_material(name, path, base):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes.get('Principled BSDF'); p.inputs['Roughness'].default_value = .85
    if path is None:
        p.inputs['Base Color'].default_value = (*lin(base), 1); return m
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(str(path), check_existing=True)
    t.interpolation = 'Closest' if False else 'Linear'
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'
    mix.inputs['A'].default_value = (*lin(base), 1)
    nt.links.new(t.outputs['Alpha'], mix.inputs['Factor']); nt.links.new(t.outputs['Color'], mix.inputs['B'])
    nt.links.new(mix.outputs['Result'], p.inputs['Base Color'])
    return m

def body_block(name, center, size, rects, mat):
    m = M(name); hx, hy, hz = [s / 2 for s in size]
    for side, quad in faces(hx, hy, hz).items():
        x, y, w, h = rects[side]
        u0, u1, v0, v1 = x / SHEET[0], (x + w) / SHEET[0], 1 - (y + h) / SHEET[1], 1 - y / SHEET[1]
        m.face(quad, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    ob = m.obj(mat, center)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob

def head_proxy(mat):
    m = M('R6 head'); seg, rows = 40, 16
    P = [[tuple(head_point(-math.pi + TAU * j / seg, .02 + (math.pi - .04) * i / (rows - 1))) for j in range(seg)] for i in range(rows)]
    U = [[(0, 0)] * seg for _ in range(rows)]
    m.grid(P, U, lambda c: c, close=True)
    return m.obj(mat, (0, 0, 4.5))

def head_material(decal):
    m = bpy.data.materials.new('R6 head skin + face'); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes.get('Principled BSDF'); p.inputs['Roughness'].default_value = .6
    skin = (*lin((234, 196, 168)), 1)
    if decal is None:
        p.inputs['Base Color'].default_value = skin; return m
    tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(tc.outputs['Object'], sep.inputs['Vector'])
    comb = nt.nodes.new('ShaderNodeCombineXYZ')
    for axis, src in (('X', 'X'), ('Y', 'Z')):
        mth = nt.nodes.new('ShaderNodeMath'); mth.operation = 'MULTIPLY_ADD'
        mth.inputs[1].default_value = 1 / 1.2; mth.inputs[2].default_value = .5
        nt.links.new(sep.outputs[src], mth.inputs[0]); nt.links.new(mth.outputs[0], comb.inputs[axis])
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(str(decal), check_existing=True); t.extension = 'CLIP'
    nt.links.new(comb.outputs['Vector'], t.inputs['Vector'])
    front = nt.nodes.new('ShaderNodeMath'); front.operation = 'LESS_THAN'; front.inputs[1].default_value = -.1
    nt.links.new(sep.outputs['Y'], front.inputs[0])
    fac = nt.nodes.new('ShaderNodeMath'); fac.operation = 'MULTIPLY'
    nt.links.new(t.outputs['Alpha'], fac.inputs[0]); nt.links.new(front.outputs[0], fac.inputs[1])
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.inputs['A'].default_value = skin
    nt.links.new(fac.outputs[0], mix.inputs['Factor']); nt.links.new(t.outputs['Color'], mix.inputs['B'])
    nt.links.new(mix.outputs['Result'], p.inputs['Base Color'])
    return m

def body(plain):
    shirt = None if plain else OUT / 'mabel-shirt.png'
    pants = None if plain else OUT / 'mabel-pants.png'
    skin, coat, lower = (234, 196, 168), (40, 50, 78), (40, 46, 70)
    torso_m = sheet_material('torso', shirt, coat)
    arm_m = sheet_material('arms', shirt, skin)
    leg_m = sheet_material('legs', pants, lower)
    body_block('Torso', (0, 0, 3), (2, 1, 2), TORSO_R, torso_m)
    body_block('Right Arm', (-1.5, 0, 3), (1, 1, 2), limb_rects(True), arm_m)
    body_block('Left Arm', (1.5, 0, 3), (1, 1, 2), limb_rects(False), arm_m)
    body_block('Right Leg', (-.5, 0, 1), (1, 1, 2), limb_rects(True), leg_m)
    body_block('Left Leg', (.5, 0, 1), (1, 1, 2), limb_rects(False), leg_m)
    head_proxy(head_material(None if plain else OUT / 'mabel-face.png'))

# ------------------------------------------------------------------ scene, renders
def stage():
    scene = bpy.context.scene; scene.render.engine = 'CYCLES'; scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.world.color = (.035, .03, .028)
    floor = M('floor'); floor.face([(-8, -8, 0), (8, -8, 0), (8, 8, 0), (-8, 8, 0)], [(0, 0)] * 4, (0, 0, 1))
    floor.obj(material('saloon floor', (74, 46, 30), .7))
    wall = M('wall'); wall.face([(-8, 3, 0), (8, 3, 0), (8, 3, 9), (-8, 3, 9)], [(0, 0)] * 4, (0, -1, 0))
    wall.obj(material('saloon wall', (66, 34, 24), .8))
    for loc, power, size, color in [((-3, -7, 8), 900, 5, (1, .78, .55)), ((4, -4, 6), 300, 3, (.7, .78, 1)), ((0, 2, 8), 250, 3, (1, .85, .7))]:
        bpy.ops.object.light_add(type='AREA', location=loc); l = bpy.context.object
        l.data.energy = power; l.data.size = size; l.data.color = color
        l.rotation_euler = (Vector((0, 0, 3)) - l.location).to_track_quat('-Z', 'Y').to_euler()
    scene.view_settings.view_transform = 'AgX'
    scene.render.resolution_percentage = 50
    return scene

def shoot(scene, name, loc, target, lens=50, res=(1000, 1400)):
    bpy.ops.object.camera_add(location=loc); cam = bpy.context.object; cam.data.lens = lens
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat('-Z', 'Y').to_euler(); scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.filepath = str(OUT / 'renders' / name); bpy.ops.render.render(write_still=True)

def main():
    (OUT / 'renders').mkdir(parents=True, exist_ok=True)
    scene = stage()
    body(BEFORE_ONLY)
    if not BEFORE_ONLY:
        sk = textured(OUT / 'skirt-pouch.png', 'skirt wool + pouch leather', .8)
        hr = textured(OUT / 'hair-bun.png', 'grey hair', .55)
        vs = textured(OUT / 'eyeshade.png', 'navy felt eyeshade', .7)
        pu = textured(OUT / 'ticket-punch.png', 'brass punch', .35, .85)
        export(skirt(), 'Torso', (0, 0, 3), sk, 'skirt-pouch.png')
        export(hair(), 'Head', (0, 0, 4.5), hr, 'hair-bun.png')
        export(eyeshade(), 'Head', (0, 0, 4.5), vs, 'eyeshade.png')
        p, slots = punch()
        export(p, 'Right Arm', (-1.5, 0, 3), pu, 'ticket-punch.png', slots)
    tag = 'plain' if BEFORE_ONLY else 'after'
    shoot(scene, f'{tag}-front.png', (0, -16, 3.0), (0, 0, 2.6), 60)
    shoot(scene, f'{tag}-34.png', (-9, -12, 4.2), (0, 0, 2.6), 60)
    if not BEFORE_ONLY:
        shoot(scene, 'after-arms-length.png', (-.9, -3.6, 4.6), (0, 0, 4.25), 50, (1200, 1000))
        bpy.data.objects['wall'].hide_render = True
        shoot(scene, 'after-back.png', (6, 12, 4.5), (0, 0, 2.8), 60)
        bpy.data.objects['wall'].hide_render = False
        shoot(scene, 'after-hem-low.png', (-3, -6, 1.2), (0, 0, 1.0), 45, (1200, 1000))
        total = sum(v['triangles'] for v in manifest.values())
        (OUT / 'manifest.json').write_text(json.dumps({
            'npc': 'Mabel', 'status': 'source assets; upload and Studio arm\'s-length check pending',
            'shirt': 'mabel-shirt.png', 'pants': 'mabel-pants.png', 'face': 'mabel-face.png',
            'units': 'studs, limb space, -Z is her front', 'totalTriangles': total,
            'pieces': list(manifest.values())}, indent=2))
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'mabel-r6.blend'))

main()
