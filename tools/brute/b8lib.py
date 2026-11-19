"""Helpers for tools/brute/build.py: a small numpy sculpting kit, colour fields, and the bake/export/render
pipeline (the same rules as tools/stalker/build.py: one mesh and one sRGB colour texture per piece, no vertex
colours in the FBX, +Y up, front -Z, one Blender unit = one stud).

Sculpting works on dense, even triangle meshes held as numpy arrays in Roblox axes:
  blockout (metaballs) -> voxel remesh -> strokes (move, inflate, crease, ridge, flatten, smooth)
Detail is placed stroke by stroke, never mirrored, so no two sides come out the same.
"""

import math
import random
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

OUT = Path(".")
V3 = Vector


# ------------------------------------------------------------------ small maths
def S(a, b, x):
    """Smoothstep from a to b on scalars or arrays (a may be above b)."""
    t = np.clip((np.asarray(x, dtype=float) - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def lin(c):
    return tuple(max(0.0, v) ** 2.2 for v in c)


def mixc(C, c2, t):
    """Mix an (n,3) colour array toward colour c2 (tuple or (n,3)) by t (scalar or (n,))."""
    t = np.clip(np.asarray(t, dtype=float), 0, 1)
    if t.ndim == 1:
        t = t[:, None]
    return C + (np.asarray(c2, dtype=float) - C) * t


def norm(X):
    return np.linalg.norm(X, axis=-1)


def unit(X):
    n = norm(X)[..., None]
    return X / np.maximum(n, 1e-12)


def _hash(ix, iy, iz, seed):
    n = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    n = n & 0x7FFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
    n = n ^ (n >> 16)
    return (n & 0xFFFF) / 32767.5 - 1.0


def vnoise(P, scale=1.0, seed=0, stretch=(1, 1, 1)):
    """Value noise in [-1, 1] at points P (n,3); stretch < 1 on an axis makes streaks along it."""
    p = np.asarray(P, dtype=float) * scale * np.asarray(stretch, dtype=float) + 31.7 * seed
    i = np.floor(p).astype(np.int64)
    f = p - i
    u = f * f * (3 - 2 * f)
    x, y, z = i[:, 0], i[:, 1], i[:, 2]
    out = 0.0
    for dx in (0, 1):
        wx = u[:, 0] if dx else 1 - u[:, 0]
        for dy in (0, 1):
            wy = u[:, 1] if dy else 1 - u[:, 1]
            for dz in (0, 1):
                wz = u[:, 2] if dz else 1 - u[:, 2]
                out = out + wx * wy * wz * _hash(x + dx, y + dy, z + dz, seed)
    return out


def fbm(P, scale=1.0, octaves=3, seed=0, stretch=(1, 1, 1)):
    total, amp, normf, s = 0.0, 1.0, 0.0, scale
    for k in range(octaves):
        total = total + vnoise(P, s, seed + k * 7, stretch) * amp
        normf += amp
        amp *= 0.5
        s *= 2.07
    return total / normf


def path_dist(P, pts):
    """Distance from each point to a polyline, the arc parameter u in [0, 1] of the closest point, and that point."""
    pts = np.asarray(pts, dtype=float)
    seg = pts[1:] - pts[:-1]
    lens = norm(seg)
    cum = np.concatenate([[0.0], np.cumsum(lens)])
    total = max(cum[-1], 1e-9)
    best = np.full(len(P), np.inf)
    bu = np.zeros(len(P))
    bc = np.zeros_like(P)
    for i in range(len(seg)):
        a, ab, L2 = pts[i], seg[i], max(lens[i] ** 2, 1e-12)
        t = np.clip(((P - a) @ ab) / L2, 0, 1)
        c = a + t[:, None] * ab
        d = norm(P - c)
        m = d < best
        best[m] = d[m]
        bu[m] = (cum[i] + t[m] * lens[i]) / total
        bc[m] = c[m]
    return best, bu, bc


def smooth_path(pts, n=40, wobble=0.0, seed=0):
    """Catmull-Rom through control points, n samples, optional sideways wobble (studs)."""
    P = [V3(p) for p in pts]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    segs = len(P) - 3
    for k in range(n):
        s = k / (n - 1) * segs
        i = min(int(s), segs - 1)
        t = s - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
        out.append(tuple(q))
    out = np.array(out)
    if wobble:
        rng = np.random.default_rng(seed)
        jitter = np.cumsum(rng.normal(0, wobble, out.shape), axis=0)
        jitter -= np.linspace(jitter[0], jitter[-1], len(out))
        out = out + jitter * 0.5
    return out


# ------------------------------------------------------------------ meshes as arrays
class Mesh:
    """Triangles in Roblox axes. C is an optional (n,3) sRGB colour per vertex."""

    def __init__(self, V, F, C=None):
        self.V = np.asarray(V, dtype=float)
        self.F = np.asarray(F, dtype=np.int64)
        self.C = None if C is None else np.asarray(C, dtype=float)
        self._E = None
        self.masks = {}

    # topology
    @property
    def E(self):
        if self._E is None:
            e = np.vstack([self.F[:, [0, 1]], self.F[:, [1, 2]], self.F[:, [2, 0]]])
            e.sort(axis=1)
            self._E = np.unique(e, axis=0)
            self.deg = np.maximum(np.bincount(self._E.ravel(), minlength=len(self.V)), 1)
        return self._E

    def N(self):
        v0, v1, v2 = self.V[self.F[:, 0]], self.V[self.F[:, 1]], self.V[self.F[:, 2]]
        fn = np.cross(v1 - v0, v2 - v0)
        vn = np.zeros_like(self.V)
        for k in range(3):
            np.add.at(vn, self.F[:, k], fn)
        return unit(vn)

    def avg(self, X):
        E = self.E
        acc = np.zeros_like(X)
        np.add.at(acc, E[:, 0], X[E[:, 1]])
        np.add.at(acc, E[:, 1], X[E[:, 0]])
        return acc / (self.deg[:, None] if X.ndim == 2 else self.deg)

    def blur(self, X, it=2):
        for _ in range(it):
            X = 0.5 * X + 0.5 * self.avg(X)
        return X

    # falloffs
    def ball(self, c, r, hard=False):
        d = norm(self.V - np.asarray(c, dtype=float)) / r
        return (1 - np.clip(d, 0, 1)) ** 2 if hard else S(1.0, 0.0, d)

    def ell(self, c, semi, rot=None):
        q = self.V - np.asarray(c, dtype=float)
        if rot is not None:
            q = q @ np.asarray(rot, dtype=float)
        d = norm(q / np.asarray(semi, dtype=float))
        return S(1.0, 0.0, d)

    def line(self, pts, r, prof="smooth"):
        """Weight along a polyline; r is a number or a (start, end) pair; ends taper. Returns w, u, closest."""
        d, u, c = path_dist(self.V, pts)
        rr = r if np.isscalar(r) else r[0] + (r[1] - r[0]) * u
        x = d / rr
        if prof == "sharp":
            w = (1 - np.clip(x, 0, 1)) ** 3
        else:
            w = S(1.0, 0.0, x)
        taper = S(0.0, 0.12, u) * S(1.0, 0.88, u)
        return w * taper, u, c

    # strokes
    def move(self, w, vec):
        self.V += w[:, None] * np.asarray(vec, dtype=float)

    def inflate(self, w, amt):
        self.V += self.N() * (w * amt)[:, None]

    def crease(self, pts, r, depth, pinch=0.6, key=None):
        """A sharp groove along pts: pushed in along the normal and pinched toward the line."""
        w, u, c = self.line(pts, r, "sharp")
        n = self.N()
        self.V -= n * (w * depth)[:, None]
        tang = c - self.V
        tang -= n * np.sum(tang * n, axis=1)[:, None]
        self.V += tang * (w * pinch * 0.5)[:, None]
        if key:
            self.masks[key] = np.maximum(self.masks.get(key, 0), w)
        return w

    def ridge(self, pts, r, h, key=None):
        w, u, c = self.line(pts, r)
        self.V += self.N() * (w * h)[:, None]
        if key:
            self.masks[key] = np.maximum(self.masks.get(key, 0), w)
        return w

    def flatten(self, w, amt=1.0, normal=None):
        if w.sum() < 1e-6:
            return
        p0 = (self.V * w[:, None]).sum(0) / w.sum()
        n = normal if normal is not None else (self.N() * w[:, None]).sum(0)
        n = np.asarray(n, dtype=float)
        n = n / np.linalg.norm(n)
        d = (self.V - p0) @ n
        self.V -= (w * amt * d)[:, None] * n

    def smooth(self, w=None, it=2, lam=0.5):
        for _ in range(it):
            delta = self.avg(self.V) - self.V
            k = lam if w is None else (lam * w)[:, None]
            self.V += delta * k

    def cavity(self, it=3):
        """+ in folds and pits, - on ridges and edges (scaled to about [-1, 1])."""
        lap = self.avg(self.V) - self.V
        c = np.sum(lap * self.N(), axis=1)
        c = self.blur(c, it)
        s = np.percentile(np.abs(c), 97) + 1e-9
        return np.clip(c / s, -1, 1)


def join(*meshes):
    V, F, C, off = [], [], [], 0
    for m in meshes:
        V.append(m.V)
        F.append(m.F + off)
        C.append(m.C if m.C is not None else np.full((len(m.V), 3), 0.5))
        off += len(m.V)
    return Mesh(np.vstack(V), np.vstack(F), np.vstack(C))


def transform(m, M):
    """Apply a 4x4 (mathutils Matrix, Roblox axes) to a Mesh in place."""
    A = np.array(M)
    m.V = m.V @ A[:3, :3].T + A[:3, 3]
    return m


# ------------------------------------------------------------------ building blocks
def to_bl(p):
    return V3((p[0], p[2], p[1]))


K = 0.672  # an isolated metaball's surface sits at K * radius (stiffness 2, threshold 0.6)


class Meta:
    """Metaball blockout in Roblox axes, sizes given as surface sizes (studs)."""

    count = 0

    def __init__(self, res=0.04):
        Meta.count += 1
        self.mb = bpy.data.metaballs.new(f"mb{Meta.count}")
        self.mb.resolution = res
        self.mb.render_resolution = res
        self.mb.threshold = 0.6
        self.obj = bpy.data.objects.new(f"mb{Meta.count}", self.mb)
        bpy.context.scene.collection.objects.link(self.obj)

    def _el(self, kind, co, neg, stiff):
        e = self.mb.elements.new(type=kind)
        e.co = to_bl(co)
        e.use_negative = neg
        e.stiffness = stiff
        return e

    def ball(self, co, r, neg=False, stiff=2.0):
        self._el("BALL", co, neg, stiff).radius = r / K
        return self

    def ell(self, co, semi, neg=False, stiff=2.0, rot=None):
        e = self._el("ELLIPSOID", co, neg, stiff)
        e.radius = 1 / K
        e.size_x, e.size_y, e.size_z = semi[0], semi[2], semi[1]
        if rot is not None:
            e.rotation = rot
        return self

    def cap(self, a, b, r, neg=False, stiff=2.0):
        a, b = V3(a), V3(b)
        d = b - a
        e = self._el("CAPSULE", (a + b) / 2, neg, stiff)
        e.radius = r / K
        e.size_x = d.length / 2
        e.rotation = V3((1, 0, 0)).rotation_difference(to_bl(d).normalized())
        return self

    def chain(self, pts, radii, stiff=2.0):
        for i in range(len(pts) - 1):
            self.cap(pts[i], pts[i + 1], (radii[i] + radii[i + 1]) / 2, stiff=stiff)
        return self

    def mesh(self, voxel):
        """Voxel-remeshed surface as a Mesh (Roblox axes)."""
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(self.obj.evaluated_get(dg))
        bpy.data.objects.remove(self.obj)
        bpy.data.metaballs.remove(self.mb)
        return remesh(me, voxel)


def remesh(me, voxel):
    o = bpy.data.objects.new("rm", me)
    bpy.context.scene.collection.objects.link(o)
    m = o.modifiers.new("rm", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = voxel
    m.adaptivity = 0.0
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    bpy.data.objects.remove(o)
    bpy.data.meshes.remove(me)
    out = from_bl_mesh(me2)
    bpy.data.meshes.remove(me2)
    return out


def from_bl_mesh(me):
    me.calc_loop_triangles()
    n = len(me.vertices)
    co = np.empty(n * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    t = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", t)
    t = t.reshape(-1, 3)
    V = co[:, [0, 2, 1]]  # Blender -> Roblox axes (a mirror: flip the winding back)
    return Mesh(V, t[:, [0, 2, 1]])


def grid(nu, nv, place, keep=None):
    """A sheet of (nu+1) x (nv+1) verts; place(U, W) -> (n,3) from arrays; keep(u, w) drops faces (holes)."""
    u, w = np.meshgrid(np.linspace(0, 1, nu + 1), np.linspace(0, 1, nv + 1))
    V = place(u.ravel(), w.ravel())
    F = []
    idx = lambda i, j: j * (nu + 1) + i
    for j in range(nv):
        for i in range(nu):
            if keep is not None and not keep((i + 0.5) / nu, (j + 0.5) / nv):
                continue
            a, b, c, d = idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)
            F += [(a, b, c), (a, c, d)]
    m = Mesh(V, np.array(F))
    m.UV = np.stack([u.ravel(), w.ravel()], 1)
    return m


def boundary_edges(F):
    e = np.vstack([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    s = np.sort(e, axis=1)
    _, inv, cnt = np.unique(s, axis=0, return_inverse=True, return_counts=True)
    return e[cnt[inv.ravel()] == 1]


def slab(m, thick, colour_back=None, colour_rim=None):
    """Give an open sheet a thickness (toward -normal): back faces and a rim on every open edge."""
    n = m.N()
    n0 = len(m.V)
    V = np.vstack([m.V, m.V - n * thick])
    Fb = m.F[:, ::-1] + n0
    rim = []
    for a, b in boundary_edges(m.F):
        rim += [(b, a, a + n0), (b, a + n0, b + n0)]
    F = np.vstack([m.F, Fb, np.array(rim, dtype=np.int64).reshape(-1, 3)])
    C = None
    if m.C is not None:
        back = m.C * 0.7 if colour_back is None else np.broadcast_to(colour_back, m.C.shape)
        C = np.vstack([m.C, back])
        if colour_rim is not None:
            edge = np.zeros(2 * n0, bool)
            b = boundary_edges(m.F).ravel()
            edge[b] = True
            edge[b + n0] = True
            C[edge] = mixc(C[edge], colour_rim, 0.6)
    out = Mesh(V, F, C)
    out.masks = {k: np.concatenate([v, v]) for k, v in m.masks.items()}
    return out


def tube(pts, radii, sides=8, flat=1.0, up=(0, 0, -1), twist=0.0, cap=True):
    """A tube along pts (n,3) with per-point radii; flat < 1 squashes it toward `up` (a strap or a lace)."""
    pts = np.asarray(pts, dtype=float)
    radii = np.broadcast_to(np.asarray(radii, dtype=float), (len(pts),))
    n = len(pts)
    V, F = [], []
    upv = np.asarray(up, dtype=float)
    for i in range(n):
        t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        t = t / (np.linalg.norm(t) + 1e-12)
        a = upv - t * (upv @ t)
        if np.linalg.norm(a) < 1e-6:
            a = np.cross(t, [1, 0, 0])
        a = a / np.linalg.norm(a)
        b = np.cross(t, a)
        for s in range(sides):
            ang = s / sides * math.tau + twist * i
            V.append(pts[i] + (a * math.cos(ang) * flat + b * math.sin(ang)) * radii[i])
    for i in range(n - 1):
        for s in range(sides):
            a, b = i * sides + s, i * sides + (s + 1) % sides
            c, d = b + sides, a + sides
            F += [(a, c, b), (a, d, c)]
    V = np.array(V)
    if cap:
        for end, flip in ((0, True), (n - 1, False)):
            ci = len(V)
            V = np.vstack([V, pts[end]])
            for s in range(sides):
                a, b = end * sides + s, end * sides + (s + 1) % sides
                F.append((ci, a, b) if flip else (ci, b, a))
    return Mesh(V, np.array(F))


def sphere(c, r, scale=(1, 1, 1), seg=10, rings=7):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    V = np.array([v.co[:] for v in bm.verts]) * np.asarray(scale) * r + np.asarray(c)
    F = np.array([[v.index for v in f.verts] for f in bm.faces])
    bm.free()
    return Mesh(V, F)


class Surface:
    """Ray casts and nearest points on a Mesh (for laying straps, cloth and seams onto a body)."""

    def __init__(self, m):
        self.m = m
        self.tree = BVHTree.FromPolygons(m.V.tolist(), m.F.tolist())

    def cast(self, p, d, off=0.0):
        p, d = V3(p), V3(d).normalized()
        hit = self.tree.ray_cast(p - d * 6.0, d)
        if hit[0] is None:
            return None, None
        n = hit[1] if hit[1].dot(d) < 0 else -hit[1]
        return np.array(hit[0] + n * off), np.array(n)

    def nearest(self, p):
        hit = self.tree.find_nearest(V3(p))
        return np.array(hit[0]), np.array(hit[1]), hit[3]

    def outside(self, P, centre, margin):
        """Push points that sank inside the body back out to `margin` above its surface."""
        out = P.copy()
        for i, p in enumerate(P):
            q, n, d = self.nearest(p)
            if np.dot(p - q, n) < margin:
                out[i] = q + n * margin
        return out


def lay(surface, pts, centre_fn, off, smooth=3):
    """Points of a path laid onto a surface by rays out from centre_fn(p); returns points and normals."""
    P, N = [], []
    for p in pts:
        c = np.asarray(centre_fn(p), dtype=float)
        d = c - np.asarray(p, dtype=float)
        q, n = surface.cast(p, d / (np.linalg.norm(d) + 1e-12) * -1.0 if False else -(np.asarray(p) - c), off)
        if q is not None:
            P.append(q)
            N.append(n)
    P, N = np.array(P), np.array(N)
    for _ in range(smooth):
        P[1:-1] = (P[:-2] + 2 * P[1:-1] + P[2:]) / 4
        N[1:-1] = unit(N[:-2] + 2 * N[1:-1] + N[2:])
    return P, N


def strap(P, N, width, thick):
    """A flat leather strap along points P lying on normals N (box section)."""
    n = len(P)
    V, F = [], []
    for i in range(n):
        t = P[min(i + 1, n - 1)] - P[max(i - 1, 0)]
        t = t / (np.linalg.norm(t) + 1e-12)
        side = np.cross(t, N[i])
        side = side / (np.linalg.norm(side) + 1e-12) * width / 2
        up = N[i] * thick / 2
        for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            V.append(P[i] + side * a + up * b)
    for i in range(n - 1):
        for s in range(4):
            a, b = i * 4 + s, i * 4 + (s + 1) % 4
            F += [(a, b, b + 4), (a, b + 4, a + 4)]
    F += [(0, 2, 1), (0, 3, 2), ((n - 1) * 4, (n - 1) * 4 + 1, (n - 1) * 4 + 2), ((n - 1) * 4, (n - 1) * 4 + 2, (n - 1) * 4 + 3)]
    m = Mesh(np.array(V), np.array(F))
    m.u = np.repeat(np.linspace(0, 1, n), 4)
    m.side = np.tile(np.array([-1, 1, 1, -1]), n)
    return m


def rivet(at, normal, r=0.03, height=0.5):
    m = sphere((0, 0, 0), r, (1, 1, height), seg=8, rings=5)
    q = V3((0, 0, 1)).rotation_difference(V3(normal)).to_matrix()
    m.V = m.V @ np.array(q).T + np.asarray(at)
    return m


def orient_out(m, centre):
    """Flip faces of an open mesh whose normals point toward centre(p)."""
    v0, v1, v2 = m.V[m.F[:, 0]], m.V[m.F[:, 1]], m.V[m.F[:, 2]]
    fn = np.cross(v1 - v0, v2 - v0)
    mid = (v0 + v1 + v2) / 3
    flip = np.sum(fn * (mid - centre(mid)), axis=1) < 0
    m.F[flip] = m.F[flip][:, ::-1]


# ------------------------------------------------------------------ Blender objects, bake, export
def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.lights, bpy.data.cameras):
        for x in list(coll):
            if x.users == 0:
                coll.remove(x)


def to_object(name, m):
    """A Blender object from a Mesh (Roblox axes -> Blender axes), colours in the 'col' attribute (linear)."""
    V = m.V[:, [0, 2, 1]]
    F = m.F[:, [0, 2, 1]]
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(V))
    me.vertices.foreach_set("co", V.astype(np.float32).ravel())
    me.loops.add(len(F) * 3)
    me.loops.foreach_set("vertex_index", F.astype(np.int32).ravel())
    me.polygons.add(len(F))
    me.polygons.foreach_set("loop_start", np.arange(0, len(F) * 3, 3, dtype=np.int32))
    me.update()
    me.validate()
    if m.C is not None and len(me.vertices) == len(m.C):
        attr = me.color_attributes.new("col", "FLOAT_COLOR", "POINT")
        c = np.clip(m.C, 0, None) ** 2.2
        rgba = np.hstack([c, np.ones((len(c), 1))]).astype(np.float32)
        attr.data.foreach_set("color", rgba.ravel())
    me.shade_smooth()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def apply_mod(obj, kind, **props):
    m = obj.modifiers.new(kind, kind)
    for k, v in props.items():
        setattr(m, k, v)
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_apply(modifier=m.name)


def select_only(*objs, active=None):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def vc_material():
    m = bpy.data.materials.get("vc")
    if m:
        return m
    m = bpy.data.materials.new("vc")
    m.use_nodes = True
    nt = m.node_tree
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "col"
    b = nt.nodes["Principled BSDF"]
    nt.links.new(attr.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.85
    return m


def emit_vc_material():
    m = bpy.data.materials.get("emit_vc")
    if m:
        return m
    m = bpy.data.materials.new("emit_vc")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "col"
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(attr.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs[0], out.inputs[0])
    return m


def neon_material():
    m = bpy.data.materials.get("neon")
    if m:
        return m
    m = bpy.data.materials.new("neon")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (1.0, 0.2, 0.03, 1)
    b.inputs["Emission Color"].default_value = (1.0, 0.2, 0.03, 1)
    b.inputs["Emission Strength"].default_value = 8.0
    return m


def preview(name, m):
    o = to_object(name, m)
    o.data.materials.append(vc_material())
    return o


def piece(name, m, target, size, ao_dist, ao_mix=0.7):
    """Low mesh (decimated to `target` triangles, unwrapped) with one colour texture baked from the high mesh:
    its vertex colours times its own occlusion (so folds, pores and seams survive the decimation)."""
    high = to_object(name + "_hi", m)
    high.data.materials.append(emit_vc_material())
    low = high.copy()
    low.data = high.data.copy()
    low.name = name
    bpy.context.scene.collection.objects.link(low)
    if tris(high) > target:
        apply_mod(low, "DECIMATE", ratio=target / tris(high))
    apply_mod(low, "TRIANGULATE")
    for a in list(low.data.color_attributes):
        low.data.color_attributes.remove(a)
    select_only(low)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62), island_margin=0.008)
    bpy.ops.object.mode_set(mode="OBJECT")

    img_c = bpy.data.images.new(name + "_c", size, size, float_buffer=True)
    img_a = bpy.data.images.new(name + "_ao", size, size, float_buffer=True)
    img_a.colorspace_settings.name = "Non-Color"
    lm = bpy.data.materials.new(name)
    lm.use_nodes = True
    nt = lm.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.88
    node = nt.nodes.new("ShaderNodeTexImage")
    low.data.materials.clear()
    low.data.materials.append(lm)

    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.world.light_settings.distance = ao_dist
    others = [o for o in sc.objects if o not in (low, high) and not o.hide_render]
    for o in others:
        o.hide_render = True
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = 0.03
    bk.max_ray_distance = 0.12
    bk.margin = 6
    select_only(high, low, active=low)
    node.image = img_c
    nt.nodes.active = node
    sc.cycles.samples = 1
    bpy.ops.object.bake(type="EMIT", use_selected_to_active=True, cage_extrusion=0.03, max_ray_distance=0.12, margin=6)
    node.image = img_a
    sc.cycles.samples = 64
    high.data.materials.clear()
    high.data.materials.append(vc_material())
    bpy.ops.object.bake(type="AO", use_selected_to_active=True, cage_extrusion=0.03, max_ray_distance=0.12, margin=6)
    for o in others:
        o.hide_render = False

    c = np.empty(size * size * 4, dtype=np.float32)
    a = np.empty(size * size * 4, dtype=np.float32)
    img_c.pixels.foreach_get(c)
    img_a.pixels.foreach_get(a)
    c = c.reshape(-1, 4)
    a = a.reshape(-1, 4)[:, :1]
    c[:, :3] *= (1 - ao_mix) + ao_mix * a
    c[:, 3] = 1
    tex = bpy.data.images.new(name + "_tex", size, size, float_buffer=True)
    tex.pixels.foreach_set(c.ravel())
    png = bpy.data.images.new(name + "_png", size, size)
    e = c.copy()
    e[:, :3] = np.where(e[:, :3] <= 0.0031308, 12.92 * e[:, :3], 1.055 * np.power(np.clip(e[:, :3], 0, None), 1 / 2.4) - 0.055)
    png.pixels.foreach_set(np.clip(e, 0, 1).ravel())
    png.filepath_raw = str(OUT / f"{name}.png")
    png.file_format = "PNG"
    png.save()
    bpy.data.images.remove(png)
    node.image = tex
    nt.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    bpy.data.images.remove(img_c)
    bpy.data.images.remove(img_a)
    me = high.data
    bpy.data.objects.remove(high)
    bpy.data.meshes.remove(me)
    return low


def neon_piece(name, m, target):
    o = to_object(name, m)
    for a in list(o.data.color_attributes):
        o.data.color_attributes.remove(a)
    if tris(o) > target:
        apply_mod(o, "DECIMATE", ratio=target / tris(o))
    apply_mod(o, "TRIANGULATE")
    o.data.materials.clear()
    o.data.materials.append(neon_material())
    return o


def export(obj, report, texture):
    """FBX centred on its box; the report keeps the box (size, centre) in the part's frame, Roblox axes."""
    select_only(obj)
    bb = [obj.matrix_world @ V3(c) for c in obj.bound_box]
    lo = V3((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = V3((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    mid = (lo + hi) / 2
    report[obj.name] = {
        "size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
        "center": [round(mid.x, 3), round(mid.z, 3), round(mid.y, 3)],
        "tris": tris(obj),
        "texture": texture,
    }
    for v in obj.data.vertices:
        v.co -= mid
    bpy.ops.export_scene.fbx(filepath=str(OUT / f"{obj.name}.fbx"), use_selection=True, axis_forward="-Z",
                             axis_up="Y", apply_unit_scale=True, global_scale=1.0, path_mode="STRIP",
                             colors_type="NONE")
    for v in obj.data.vertices:
        v.co += mid


# ------------------------------------------------------------------ figure and renders (Roblox axes in, Blender out)
def A(x=0.0, y=0.0, z=0.0):
    """Roblox CFrame.Angles in degrees."""
    return Matrix.Rotation(math.radians(x), 4, "X") @ Matrix.Rotation(math.radians(y), 4, "Y") @ Matrix.Rotation(math.radians(z), 4, "Z")


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def place(obj, M):
    o = obj.copy()
    o.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(o)
    o.hide_render = False
    for v in o.data.vertices:
        r = M @ V3((v.co.x, v.co.z, v.co.y))
        v.co = V3((r.x, r.z, r.y))
    o["figure"] = True
    return o


def flat_material(c, emit=0.0):
    key = "flat%.3f_%.3f_%.3f_%.1f" % (*c, emit)
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(c), 1)
    b.inputs["Roughness"].default_value = 0.8
    if emit:
        b.inputs["Emission Color"].default_value = (*lin(c), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


def prim(kind, size, M, colour, emit=0.0):
    bm = bmesh.new()
    if kind == "box":
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = V3((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    elif kind == "rod":
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=size[1] / 2, radius2=size[1] / 2, depth=size[0])
        for v in bm.verts:
            v.co = V3((v.co.z, v.co.x, v.co.y))
    else:
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=size[0] / 2)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    V = np.array([v.co[:] for v in bm.verts])
    F = np.array([[v.index for v in f.verts] for f in bm.faces])
    bm.free()
    o = to_object("p", Mesh(V, F))
    o.data.materials.append(flat_material(colour, emit))
    out = place(o, M)
    me = o.data
    bpy.data.objects.remove(o)
    bpy.data.meshes.remove(me)
    return out


def clear_figure():
    for o in list(bpy.context.scene.objects):
        if o.get("figure") or o.type in ("LIGHT", "CAMERA"):
            data = o.data
            bpy.data.objects.remove(o)
            if isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)


def clear_lights():
    for o in list(bpy.context.scene.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o)


def to_b(p):
    return V3((p[0], p[2], p[1]))


def camera(eye_r, at_r, fov=40):
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.scene.collection.objects.link(cam)
    eye, at = to_b(eye_r), to_b(at_r)
    cam.location = eye
    cam.rotation_euler = (at - eye).to_track_quat("-Z", "Y").to_euler()
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(fov)
    cam.data.clip_start = 0.05
    bpy.context.scene.camera = cam


def light(kind, pos_r, energy, colour, size=0.2, at_r=None):
    ld = bpy.data.lights.new("l", kind)
    ld.energy = energy
    ld.color = colour
    if kind == "POINT":
        ld.shadow_soft_size = size
    lo = bpy.data.objects.new("l", ld)
    lo.location = to_b(pos_r)
    if at_r is not None:
        lo.rotation_euler = (to_b(at_r) - to_b(pos_r)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(lo)


def world(c, strength=1.0):
    if bpy.context.scene.world is None:
        bpy.context.scene.world = bpy.data.worlds.new("w")
    w = bpy.context.scene.world
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*c, 1)
    bg.inputs[1].default_value = strength


def daylight(at):
    world((0.18, 0.19, 0.21), 1.0)
    light("SUN", V3((3, 9, -6)), 3.0, (1, 0.97, 0.92), at_r=at)


def gaslight(at):
    world((0.004, 0.005, 0.008), 1.0)
    light("POINT", V3(at) + V3((-2.4, 1.0, -2.2)), 220, (1.0, 0.62, 0.30), size=0.15)
    light("POINT", V3(at) + V3((2.0, 0.6, 2.4)), 25, (0.45, 0.55, 0.8), size=0.5)


def render(path, w, h, samples=40, pct=50):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = pct
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
