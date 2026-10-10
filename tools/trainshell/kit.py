"""
The train exterior's modelling kit for Blender (bpy + bmesh), shared by every car.

All coordinates are Roblox train space in studs: +X the engine's front, +Y up (0 = floor),
+Z the platform side. `V` turns them into Blender's Z-up frame. A `Piece` is one future
MeshPart: it collects bmesh geometry and becomes one Blender object, which may carry modifiers
(Bevel, Boolean, Array) that are applied when the car is exported.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector


def V(x, y, z):
    return Vector((x, -z, y))


def R(v):
    """Blender vector back to Roblox (x, y, z)."""
    return (v.x, v.z, -v.y)


class Piece:
    def __init__(self, name, role, material=None):
        self.name = name
        self.role = role  # Body, Trim, Roof, Accent, Lamp or None (untinted)
        self.material = material or role or "Iron"
        self.bm = bmesh.new()
        self.cutters = []  # objects subtracted with a Boolean modifier
        self.bevel = None  # (width, segments, angle in degrees)

    # -- primitives -------------------------------------------------------------------

    def quad_strip(self, rings, closed_path=False, closed_profile=True, caps=True):
        """Connect rings of verts (each a list) into a tube; caps close open ends."""
        bm = self.bm
        vs = [[bm.verts.new(p) for p in ring] for ring in rings]
        n = len(vs[0])
        count = len(vs) if closed_path else len(vs) - 1
        for i in range(count):
            a, b = vs[i], vs[(i + 1) % len(vs)]
            for j in range(n if closed_profile else n - 1):
                k = (j + 1) % n
                bm.faces.new((a[j], b[j], b[k], a[k]))
        if caps and not closed_path and closed_profile:
            bm.faces.new(list(reversed(vs[0])))
            bm.faces.new(vs[-1])
        return vs

    def box(self, c, s):
        x, y, z = c
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        ring = lambda xx: [V(xx, y - hy, z - hz), V(xx, y + hy, z - hz), V(xx, y + hy, z + hz), V(xx, y - hy, z + hz)]
        self.quad_strip([ring(x - hx), ring(x + hx)])

    def box_between(self, a, b):
        c = [(a[i] + b[i]) / 2 for i in range(3)]
        s = [abs(b[i] - a[i]) for i in range(3)]
        self.box(c, s)

    def prism_x(self, profile, x0, x1):
        """A closed (y, z) profile extruded along X from x0 to x1."""
        self.quad_strip([[V(x, y, z) for y, z in profile] for x in (x0, x1)])

    def prism_z(self, profile, z0, z1):
        """A closed (x, y) profile extruded along Z from z0 to z1."""
        self.quad_strip([[V(x, y, z) for x, y in profile] for z in (z0, z1)])

    def prism_y(self, profile, y0, y1):
        """A closed (x, z) profile extruded along Y."""
        self.quad_strip([[V(x, y, z) for x, z in profile] for y in (y0, y1)])

    def lathe(self, profile, c, axis="y", segs=16, caps=True):
        """Revolve an open (r, h) profile (bottom to top, r = 0 ends get capped) about an axis."""
        cx, cy, cz = c
        rings = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            ca, sa = math.cos(a), math.sin(a)
            ring = []
            for r, h in profile:
                if axis == "y":
                    p = (cx + r * ca, cy + h, cz + r * sa)
                elif axis == "x":
                    p = (cx + h, cy + r * ca, cz + r * sa)
                else:
                    p = (cx + r * ca, cy + r * sa, cz + h)
                ring.append(V(*p))
            rings.append(ring)
        bm = self.bm
        vs = [[bm.verts.new(p) for p in ring] for ring in rings]
        n = len(profile)
        for k in range(segs):
            a, b = vs[k], vs[(k + 1) % segs]
            for j in range(n - 1):
                bm.faces.new((a[j], a[j + 1], b[j + 1], b[j]))
        # caps where the profile does not close on the axis
        if caps and profile[0][0] > 1e-6:
            bm.faces.new([vs[k][0] for k in range(segs)])
        if caps and profile[-1][0] > 1e-6:
            bm.faces.new([vs[k][-1] for k in reversed(range(segs))])

    def cylinder(self, c, axis, r, length, segs=12):
        self.lathe([(r, -length / 2), (r, length / 2)], c, axis, segs)

    def sweep(self, path, profile, normal, closed=True):
        """
        Sweep a 2D profile along a path on a plane (mitred corners).
        path: points (Roblox), all on one plane with unit normal `normal` (pointing out).
        profile: closed list of (across, out): across is in-plane, perpendicular to the path and
        positive to the path's left when looking along `normal`; out is along `normal`.
        """
        n = Vector(normal)
        pts = [Vector(p) for p in path]
        m = len(pts)
        rings = []
        for i in range(m):
            if closed:
                prev, nxt = pts[i - 1], pts[(i + 1) % m]
            else:
                prev = pts[i - 1] if i > 0 else pts[i] - (pts[i + 1] - pts[i])
                nxt = pts[i + 1] if i < m - 1 else pts[i] + (pts[i] - pts[i - 1])
            d0 = (pts[i] - prev).normalized()
            d1 = (nxt - pts[i]).normalized()
            l0, l1 = n.cross(d0).normalized(), n.cross(d1).normalized()
            miter = (l0 + l1).normalized()
            scale = 1 / max(0.2, miter.dot(l1))
            ring = []
            for across, out in profile:
                p = pts[i] + miter * (across * scale) + n * out
                ring.append(V(*p))
            rings.append(ring)
        self.quad_strip(rings, closed_path=closed, closed_profile=True, caps=not closed)

    # -- assembled shapes ---------------------------------------------------------------

    def rivets(self, points, axis, r=0.05, h=0.04, segs=6):
        """Domed rivet heads standing out along an axis vector from each point."""
        ax = Vector(axis).normalized()
        for p in points:
            base = Vector(p)
            # a squat cone: cheap and catches the light like a dome
            u = ax.orthogonal().normalized()
            w = ax.cross(u)
            ring = [base + (u * math.cos(2 * math.pi * k / segs) + w * math.sin(2 * math.pi * k / segs)) * r for k in range(segs)]
            vs = [self.bm.verts.new(V(*q)) for q in ring]
            top = self.bm.verts.new(V(*(base + ax * h)))
            for k in range(segs):
                self.bm.faces.new((vs[k], vs[(k + 1) % segs], top))
            self.bm.faces.new(list(reversed(vs)))

    # -- output -------------------------------------------------------------------------

    def build(self, collection):
        mesh = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(mesh)
        self.bm.free()
        ob = bpy.data.objects.new(self.name, mesh)
        collection.objects.link(ob)
        ob["role"] = self.role or ""
        ob["material"] = self.material
        for poly in mesh.polygons:
            poly.use_smooth = False
        if self.bevel:
            width, segs, angle = self.bevel
            mod = ob.modifiers.new("Bevel", "BEVEL")
            mod.width = width
            mod.segments = segs
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(angle)
            mod.harden_normals = False
        for cutter in self.cutters:
            mod = ob.modifiers.new("Cut", "BOOLEAN")
            mod.operation = "DIFFERENCE"
            mod.solver = "EXACT"
            mod.object = cutter
        after = getattr(self, "bevel_after", None)
        if after:
            # chamfer the edges the cuts made (recess lips catch the lamp light)
            width, segs, angle = after
            mod = ob.modifiers.new("BevelCuts", "BEVEL")
            mod.width = width
            mod.segments = segs
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(angle)
        return ob


def cutter_object(name, collection, build):
    """A hidden helper solid for Boolean cuts; build(piece) fills it."""
    p = Piece(name, None)
    build(p)
    ob = p.build(collection)
    ob.hide_render = True
    ob.display_type = "WIRE"
    return ob


# -- outlines --------------------------------------------------------------------------


def arch_outline(cx, y0, w, spring, crown, segs=10):
    """A window outline on a wall: straight jambs to `spring`, a segmental arch to `crown`.
    Returned counter-clockwise seen from outside +Z (x right, y up)."""
    half = w / 2
    rise = crown - spring
    # radius of the circle through the jamb tops and the crown
    rad = (half * half + rise * rise) / (2 * rise)
    cyc = crown - rad
    a0 = math.atan2(spring - cyc, half)
    pts = [(cx - half, y0), (cx + half, y0)]
    for k in range(segs + 1):
        a = a0 + (math.pi - 2 * a0) * k / segs
        pts.append((cx + rad * math.cos(a), cyc + rad * math.sin(a)))
    return pts


def rect_outline(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def offset_outline(pts, d):
    """Offset a CCW polygon outward by d (mitred)."""
    out = []
    m = len(pts)
    for i in range(m):
        p = Vector(pts[i])
        a = (p - Vector(pts[i - 1])).normalized()
        b = (Vector(pts[(i + 1) % m]) - p).normalized()
        na = Vector((a.y, -a.x))
        nb = Vector((b.y, -b.x))
        mi = (na + nb).normalized()
        out.append(tuple(p + mi * (d / max(0.2, mi.dot(nb)))))
    return out


def on_side(pts2d, side, z):
    """2D wall outline (x, y) onto the side wall plane at |z|, as 3D Roblox points.
    The path runs CCW seen from outside on either side."""
    path = [(x, y, side * z) for x, y in pts2d]
    return path if side > 0 else list(reversed(path))


def on_end(pts2d, end, x):
    """2D outline (z, y) on an end wall at x, facing `end` (-1 rear, +1 front)."""
    path = [(x, y, zz) for zz, y in pts2d]
    return path if end < 0 else list(reversed(path))


# -- materials (viewport colours and bake roles) -------------------------------------------

PALETTE = {
    "Body": (96, 30, 26),
    "Trim": (170, 132, 70),
    "Roof": (34, 33, 34),
    "Accent": (30, 58, 46),
    "Iron": (38, 37, 38),
    "Brass": (150, 120, 74),
    "Lamp": (255, 196, 120),
    "Sign": (30, 24, 20),
    "Teak": (78, 52, 32),
}


def material(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    r, g, b = PALETTE.get(name, (128, 128, 128))
    mat.diffuse_color = (r / 255, g / 255, b / 255, 1)
    return mat


def triangles(ob):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(deps)
    me = ev.to_mesh()
    n = sum(len(p.vertices) - 2 for p in me.polygons)
    ev.to_mesh_clear()
    return n


def apply_modifiers(ob):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    for mod in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def bbox_roblox(ob):
    """World bounding box of an object in Roblox coordinates: (center, size)."""
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    rp = [R(p) for p in pts]
    lo = [min(p[i] for p in rp) for i in range(3)]
    hi = [max(p[i] for p in rp) for i in range(3)]
    return [(lo[i] + hi[i]) / 2 for i in range(3)], [hi[i] - lo[i] for i in range(3)]


def recenter(ob):
    """Move the origin to the bounding-box centre (where Roblox puts a MeshPart's pivot)."""
    me = ob.data
    pts = [Vector(v.co) for v in me.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    c = (lo + hi) / 2
    me.transform(Matrix.Translation(-c))
    ob.matrix_world = Matrix.Translation(c) @ ob.matrix_world


def assemble(col, pieces, joins):
    """Build every piece, apply modifiers, drop cutters, and join each group into its main
    object: joins = {main_name: [names...]}. Returns {name: object} of the MeshParts."""
    objs = {}
    for p in pieces:
        ob = p.build(col)
        ob.data.materials.append(material(p.material))
        objs[p.name] = ob
    for ob in list(objs.values()):
        apply_modifiers(ob)
    for ob in list(col.objects):
        if ob.hide_render:
            bpy.data.objects.remove(ob)
    for main, names in joins.items():
        target = objs[main]
        for key in names:
            ob = objs.pop(key, None)
            if ob is None:
                continue
            if not ob.data.polygons:
                bpy.data.objects.remove(ob)
                continue
            bpy.ops.object.select_all(action="DESELECT")
            ob.select_set(True)
            target.select_set(True)
            bpy.context.view_layer.objects.active = target
            bpy.ops.object.join()
    return {k: v for k, v in objs.items() if v.data.polygons}


def describe(objs):
    """Recentre each MeshPart and list its centre, size and triangles (Roblox space)."""
    parts = []
    for key, ob in objs.items():
        recenter(ob)
        c, s = bbox_roblox(ob)
        parts.append({"name": key, "role": ob["role"], "center": c, "size": s, "tris": triangles(ob)})
        print(f"PART {key:24s} tris {parts[-1]['tris']:6d} size {[round(v, 2) for v in s]}")
    print("TOTAL TRIS", sum(p["tris"] for p in parts))
    return parts


def sign_uv(ob, boards, width=13.0, y0=7.8, y1=8.62):
    """UVs for a name board: each board's outer face takes the middle of the sign image in
    proportion to its length (the image stands for a `width`-stud board), read from outside;
    every other face samples the plain ground at the image's edge."""
    me = ob.data
    uv = me.uv_layers.new(name="UVMap")
    mw = ob.matrix_world
    for poly in me.polygons:
        n = mw.to_3x3() @ poly.normal
        rz = -n.y  # Roblox z of the face normal
        for li in poly.loop_indices:
            p = R(mw @ me.vertices[me.loops[li].vertex_index].co)
            if abs(rz) > 0.9:
                side = 1 if rz > 0 else -1
                bc = boards[side][0] if side in boards else boards[str(side)][0]
                u = 0.5 + side * (p[0] - bc) / width
                v = (p[1] - y0) / (y1 - y0)
                uv.data[li].uv = (u, v)
            else:
                uv.data[li].uv = (0.005, 0.5)
