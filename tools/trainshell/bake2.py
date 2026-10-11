"""
Round 2 of bake.py: unwraps a car into one atlas with the texels where players look, bakes the
geometry passes and paints STRUCTURED wear (every mark is drawn at its cause), then saves the
SurfaceAppearance maps.

  blender -b <car>.blend -P tools/trainshell/bake2.py -- <out_dir> <atlas> <size> <car.json> <canvas.npz> [save_size]

<atlas> is <car> (ends, roof, underframe, gangway) or <car>_P / <car>_N (one side each): Roblox
caps a SurfaceAppearance map at 1024, so each side has its own. Bakes at <size> and saves the maps
box-filtered down to save_size (default 1024).

What is new against bake.py:
- UV islands are weighted before packing: eye-level side faces get the most texels, then the side's
  returns, the ends, the roof, and almost nothing for hidden backs and undersides.
- Each side of the car has a "canvas" painted by canvas.py from spec["feat"] (every mark drawn at
  its cause). It is sampled by position for everything on that side (paint, iron, brass alike).
- The normal map is baked through a Bevel shader (every edge rounded and catching light) plus the
  canvas height (board grooves, crazing, scuffs).
- Metals: brass bright where handled and dark in recesses, blackened iron worn to steel on edges,
  gilt chipped to the red ground.
"""

import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1 :]
OUT, ATLAS, SIZE = os.path.abspath(args[0]), args[1], int(args[2])
SAVE = int(args[5]) if len(args) > 5 else 1024
META = json.load(open(args[3]))
SPEC = META["spec"]
os.makedirs(OUT, exist_ok=True)

MATS = ["Paint", "Gilt", "Canvas", "Planks", "Iron", "Brass", "Teak", "Velvet", "Bellows", "Crate", "Tarp", "Coal", "Boiler", "Smokebox"]
NM = len(MATS) + 1

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 1
scene.render.bake.margin = 4
scene.render.bake.use_clear = True

targets = [ob for ob in bpy.data.objects if ob.type == "MESH" and not ob.hide_render and ob.get("atlas") == ATLAS
           and ob.get("material") not in ("Lamp", "Sign")]
print("BAKE", ATLAS, [ob.name for ob in targets])

x0, x1 = SPEC["x0"], SPEC["x1"]
FEAT = SPEC.get("feat", {})
rng = np.random.default_rng(sum(map(ord, ATLAS)))

# -- UVs ------------------------------------------------------------------------------------


def face_weight(c, n):
    """Linear texel-density weight for a face: centre c and normal n in Roblox space."""
    ax, ay, az = abs(n[0]), n[1], abs(n[2])
    side = abs(c[2]) > 5.9 and -1.6 < c[1] < 9.95
    if side and n[2] * c[2] < -0.5:
        return 0.12  # faces turned in towards the wall: never seen
    if side and az > 0.7:
        return 1.0
    if side:
        return 0.7
    if ay < -0.7:
        return 0.12
    if c[1] < -1.6:
        return 0.3
    if ax > 0.7:
        return 0.42
    if ay > 0.5:
        return 0.32
    return 0.38


stats = []


def weight_islands(ob):
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv.active
    bm.faces.ensure_lookup_table()
    parent = list(range(len(bm.faces)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for e in bm.edges:
        lf = e.link_faces
        if len(lf) != 2:
            continue
        ls = list(e.link_loops)
        if len(ls) != 2:
            continue
        l1, l2 = ls
        a1, b1 = l1[uvl].uv, l1.link_loop_next[uvl].uv
        if l2.vert == l1.vert:
            a2, b2 = l2[uvl].uv, l2.link_loop_next[uvl].uv
        else:
            a2, b2 = l2.link_loop_next[uvl].uv, l2[uvl].uv
        if (a1 - a2).length < 1e-6 and (b1 - b2).length < 1e-6:
            ra, rb = find(l1.face.index), find(l2.face.index)
            if ra != rb:
                parent[ra] = rb
    mw = ob.matrix_world
    groups = {}
    for f in bm.faces:
        groups.setdefault(find(f.index), []).append(f)
    for faces in groups.values():
        wsum = asum = 0.0
        for f in faces:
            c = mw @ f.calc_center_median()
            n = (mw.to_3x3() @ f.normal).normalized()
            rc, rn = (c.x, c.z, -c.y), (n.x, n.z, -n.y)
            a = f.calc_area()
            wsum += face_weight(rc, rn) * a
            asum += a
        w = wsum / max(asum, 1e-9)
        if asum < 0.03:
            w *= 0.55  # rivets, dentils and the like: tiny, and their margins cost more than they do
        stats.append((w, asum))
        uvs = [l[uvl] for f in faces for l in f.loops]
        cu = sum(u.uv.x for u in uvs) / len(uvs)
        cv = sum(u.uv.y for u in uvs) / len(uvs)
        for u in uvs:
            u.uv.x = cu + (u.uv.x - cu) * w
            u.uv.y = cv + (u.uv.y - cv) * w
    bm.to_mesh(me)
    bm.free()


if not all(ob.data.uv_layers for ob in targets):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in targets:
        ob.select_set(True)
        if not ob.data.uv_layers:
            ob.data.uv_layers.new(name="UVMap")
    bpy.context.view_layer.objects.active = targets[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(50), island_margin=0.0, scale_to_bounds=False)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode="OBJECT")
    for ob in targets:
        weight_islands(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    print("ISLANDS", len(stats), "tiny", sum(1 for w, a in stats if a < 0.03))
    bpy.ops.uv.pack_islands(margin=0.0007, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def density_report():
    """Texels per stud on eye-level side faces (median)."""
    vals = []
    for ob in targets:
        me = ob.data
        uv = me.uv_layers.active.data
        mw = ob.matrix_world
        for poly in me.polygons:
            c = mw @ poly.center
            n = (mw.to_3x3() @ poly.normal).normalized()
            if abs(n.y) < 0.9 or abs(c.y) < 5.9 or not (0 < c.z < 9) or poly.area < 0.05:
                continue
            pts = [uv[li].uv for li in poly.loop_indices]
            a = 0.0
            for i in range(1, len(pts) - 1):
                u1, u2 = pts[i] - pts[0], pts[i + 1] - pts[0]
                a += abs(u1.x * u2.y - u1.y * u2.x) / 2
            vals.append(math.sqrt(a * SIZE * SIZE / poly.area))
    vals.sort()
    if vals:
        k = SAVE / SIZE
        print(f"DENSITY side texels/stud (saved) median {vals[len(vals) // 2] * k:.1f} p10 {vals[len(vals) // 10] * k:.1f}")


density_report()

# -- the side canvases (painted by canvas.py) --------------------------------------------------
NPZ = np.load(args[4])
CX0, CX1, CY0, CY1, PPU = [float(v) for v in NPZ["geom"]]
PPU = int(PPU)
CH, CW = NPZ["height1"].shape
LAYERS = ("height", "dirt", "rain", "rust", "soot", "scuff", "chip", "gild", "pin", "craze", "polish", "spray", "stencil")


class Canvas:
    pass


canvases = {}
for s in (1, -1):
    cv = Canvas()
    for k in LAYERS:
        v = NPZ[f"{k}{s}"] if f"{k}{s}" in NPZ.files else np.zeros((CH, CW), np.uint8)  # older canvases
        setattr(cv, k, v.astype(np.float32) if k == "height" else v.astype(np.float32) / 255)
    canvases[s] = cv

# height canvases as Blender images (row 0 = bottom)
himgs = {}
for s, cv in canvases.items():
    name = f"{ATLAS}_h{s}"
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, CW, CH, alpha=False, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    h = cv.height[::-1]
    img.pixels.foreach_set(np.dstack([h, h, h, np.ones_like(h)]).astype(np.float32).ravel())
    img.pack()
    himgs[s] = img

# -- materials ----------------------------------------------------------------------------------


def image(name, float_buffer):
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=False, float_buffer=float_buffer)
    img.colorspace_settings.name = "Non-Color"
    return img


MICRO = {  # (scale, amplitude in studs, stretch) of a material's own surface
    "Canvas": (40, 0.006, (1, 1, 1)),
    "Iron": (14, 0.005, (1, 1, 1)),
    "Paint": (5, 0.0015, (1, 1, 1)),
    "Gilt": (30, 0.002, (1, 1, 1)),
    "Brass": (22, 0.002, (1, 1, 1)),
    "Teak": (10, 0.004, (6, 6, 0.3)),
    "Velvet": (3, 0.02, (1, 1, 0.2)),
    "Bellows": (8, 0.006, (1, 1, 1)),
    "Planks": (10, 0.004, (6, 6, 0.3)),
    "Crate": (10, 0.005, (6, 6, 0.3)),
    "Tarp": (12, 0.008, (1, 1, 1)),
    "Coal": (30, 0.02, (1, 1, 1)),
    "Boiler": (6, 0.0015, (1, 1, 1)),
    "Smokebox": (20, 0.004, (1, 1, 1)),
}

passes = {}


def setup(mat, kind):
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    tex = nodes.new("ShaderNodeTexCoord")
    geo = nodes.new("ShaderNodeNewGeometry")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    emit = nodes.new("ShaderNodeEmission")
    target = nodes.new("ShaderNodeTexImage")
    nodes.active = target

    def math_node(op, a, b=None):
        m = nodes.new("ShaderNodeMath")
        m.operation = op
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                m.inputs[i].default_value = v
            else:
                links.new(v, m.inputs[i])
        return m.outputs[0]

    # canvas height, projected onto each side by position
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Position"], sep.inputs[0])
    u = math_node("DIVIDE", math_node("SUBTRACT", sep.outputs["X"], CX0), CX1 - CX0)
    v = math_node("DIVIDE", math_node("SUBTRACT", sep.outputs["Z"], CY0), CY1 - CY0)
    comb = nodes.new("ShaderNodeCombineXYZ")
    links.new(u, comb.inputs[0])
    links.new(v, comb.inputs[1])
    hs = {}
    for s, img in himgs.items():
        t = nodes.new("ShaderNodeTexImage")
        t.image = img
        t.interpolation = "Linear"
        t.extension = "EXTEND"
        links.new(comb.outputs[0], t.inputs["Vector"])
        hs[s] = t.outputs["Color"]
    plus = math_node("LESS_THAN", sep.outputs["Y"], 0.0)  # Blender -Y is Roblox +Z
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "FLOAT"
    links.new(plus, mix.inputs["Factor"])
    links.new(hs[-1], mix.inputs[2])
    links.new(hs[1], mix.inputs[3])
    onside = math_node("GREATER_THAN", math_node("ABSOLUTE", sep.outputs["Y"]), 5.75)
    hcan = math_node("MULTIPLY", mix.outputs[0], onside)
    # the material's own micro surface
    sc, amp, stretch = MICRO.get(kind, (10, 0.002, (1, 1, 1)))
    mp = nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = stretch
    links.new(tex.outputs["Object"], mp.inputs["Vector"])
    nz = nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = sc
    nz.inputs["Detail"].default_value = 6
    links.new(mp.outputs["Vector"], nz.inputs["Vector"])
    height = math_node("ADD", hcan, math_node("MULTIPLY", nz.outputs["Fac"], amp))
    bev = nodes.new("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = 0.035
    bev.samples = 8
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 1.0
    bump.inputs["Distance"].default_value = 1.6
    links.new(height, bump.inputs["Height"])
    links.new(bev.outputs["Normal"], bump.inputs["Normal"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    srcs = {"pos": geo.outputs["Position"], "wnrm": geo.outputs["Normal"]}
    bev2 = nodes.new("ShaderNodeBevel")
    bev2.inputs["Radius"].default_value = 0.05
    bev2.samples = 8
    dot = nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    links.new(geo.outputs["Normal"], dot.inputs[0])
    links.new(bev2.outputs["Normal"], dot.inputs[1])
    srcs["edge"] = dot.outputs["Value"]
    mid = MATS.index(kind) + 1 if kind in MATS else 0
    rgb = nodes.new("ShaderNodeRGB")
    rgb.outputs[0].default_value = (mid / NM, 0, 0, 1)
    srcs["mat"] = rgb.outputs[0]
    passes[mat.name] = (nt, out, bsdf, emit, target, srcs)


for ob in targets:
    for slot in ob.material_slots:
        mat = slot.material
        if mat and mat.name not in passes:
            setup(mat, mat.name.split(".")[0])


def bake(kind, name, chans, float_buffer=True, samples=1):
    img = image(name, float_buffer)
    for nt, out, bsdf, emit, target, srcs in passes.values():
        target.image = img
        nt.nodes.active = target
        for l in list(out.inputs["Surface"].links):
            nt.links.remove(l)
        if kind == "EMIT":
            src = srcs[name.split("_")[-1]]
            for l in list(emit.inputs["Color"].links):
                nt.links.remove(l)
            nt.links.new(src, emit.inputs["Color"])
            nt.links.new(emit.outputs[0], out.inputs["Surface"])
        else:
            nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    bpy.ops.object.select_all(action="DESELECT")
    for ob in targets:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = targets[0]
    scene.cycles.samples = samples
    bpy.ops.object.bake(type=kind, normal_space="TANGENT")
    arr = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    arr = arr.reshape(SIZE, SIZE, 4)
    res = [arr[..., c].copy() for c in chans]
    del arr
    if kind != "NORMAL":
        bpy.data.images.remove(img)
    print("baked", name)
    return res


(A,) = bake("AO", f"{ATLAS}_ao", (0,), samples=24)
X, BY, BZ = bake("EMIT", f"{ATLAS}_pos", (0, 1, 2))
Y, Z = BZ, -BY
del BY, BZ
NBX, NBY, NBZ = bake("EMIT", f"{ATLAS}_wnrm", (0, 1, 2))
NY, NZ, NX = NBZ, -NBY, NBX
del NBY, NBZ
(EDGE,) = bake("EMIT", f"{ATLAS}_edge", (0,), samples=8)
(MAT,) = bake("EMIT", f"{ATLAS}_mat", (0,))
nimg_arr = bake("NORMAL", f"{ATLAS}_nrmraw", (0, 1, 2, 3), float_buffer=False, samples=6)
nrm = np.dstack(nimg_arr)
del nimg_arr

# -- paint ------------------------------------------------------------------------------------
A = np.clip(A, 0, 1)
E = np.clip((1 - EDGE) * 5, 0, 1)
del EDGE
M = np.clip(np.round(MAT * NM).astype(np.int8), 0, NM - 1)
del MAT
covered = M > 0
H_, W_ = A.shape


def ss(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def c(r, g, b):
    return np.array([r, g, b], np.float32) / 255


rgb = np.zeros((H_, W_, 3), np.float32)
alpha = np.zeros((H_, W_), np.float32)
rough = np.full((H_, W_), 0.5, np.float32)
metal = np.zeros((H_, W_), np.float32)


def over(mask, col, a):
    a = np.clip(a, 0, 1) * mask
    rgb[:] = rgb * (1 - a[..., None]) + col * a[..., None]
    alpha[:] = alpha + a * (1 - alpha)


# sample the side canvases for every texel on a side
onside = covered & (np.abs(Z) > 5.75) & (Y > CY0) & (Y < CY1) & (X > CX0) & (X < CX1)
ci = np.clip(((X - CX0) * PPU).astype(np.int32), 0, CW - 1)
cj = np.clip(((CY1 - Y) * PPU).astype(np.int32), 0, CH - 1)
plus = Z > 0
S = {}
for k in LAYERS:
    if k == "height":
        continue
    lay = np.zeros((H_, W_), np.float32)
    for s, m in ((1, onside & plus), (-1, onside & ~plus)):
        L = getattr(canvases[s], k)
        lay[m] = L[cj[m], ci[m]]
    S[k] = lay
del ci, cj
print("canvas sampled")

# a little large-scale variation for the parts the canvases do not cover (ends, roof, under)
def noise_pos(scale, sx=1.0, sy=1.0, sz=1.0):
    g = rng.random((64, 64, 64)).astype(np.float32)
    fx = (X * sx / scale) % 64
    fy = (Y * sy / scale) % 64
    fz = (Z * sz / scale) % 64
    i, j, k = fx.astype(np.int32), fy.astype(np.int32), fz.astype(np.int32)
    tx, ty, tz = fx - i, fy - j, fz - k
    i, j, k = i % 64, j % 64, k % 64
    i1, j1, k1 = (i + 1) % 64, (j + 1) % 64, (k + 1) % 64
    def L(a, b, t):
        return a + (b - a) * t
    out = L(L(L(g[i, j, k], g[i1, j, k], tx), L(g[i, j1, k], g[i1, j1, k], tx), ty),
            L(L(g[i, j, k1], g[i1, j, k1], tx), L(g[i, j1, k1], g[i1, j1, k1], tx), ty), tz)
    return out


streakn = noise_pos(0.12, 1.0, 0.08, 1.0)  # long vertical runs
blot = noise_pos(1.4)
grime = (1 - A) ** 1.3
up = NY > 0.65
dust_col = c(112, 98, 84)
dirt_col = c(48, 34, 26)
mud_col = c(70, 54, 38)
rain_col = c(34, 26, 22)
soot_col = c(22, 18, 17)
rust_col = c(112, 52, 24)
rust_dark = c(70, 34, 18)
end = (np.abs(NX) > 0.7) & ~onside
roofm = covered & (Y > 9.6)
under = covered & (Y < -1.0) & ~onside

for k, kind in enumerate(MATS, start=1):
    m = (M == k).astype(np.float32)
    if not m.any():
        continue
    if kind == "Paint":
        # the paint itself: varnished, faded a little on the upper panels (structured by height)
        over(m, c(150, 112, 100), 0.10 * ss(3.6, 8.4, Y) * onside)
        over(m, dirt_col, 0.6 * grime ** 0.85)
        over(m, dust_col, 0.45 * up * (0.5 + 0.5 * grime))
        over(m, rain_col, 0.55 * S["rain"])
        over(m, soot_col, 0.62 * S["soot"])
        over(m, mud_col, 0.5 * S["spray"] + 0.4 * S["dirt"])
        over(m, rust_col, 0.7 * S["rust"])
        over(m, rust_dark, 0.35 * S["rust"] ** 2)
        over(m, c(26, 16, 14), 0.3 * S["craze"])
        over(m, c(16, 11, 10), 0.85 * S["pin"])
        over(m, c(186, 146, 76), 0.95 * S["gild"] * (1 - 0.6 * S["chip"]))
        over(m, c(150, 118, 100), 0.55 * S["scuff"])
        over(m, c(188, 180, 158), 0.8 * S["stencil"] * (1 - 0.7 * S["chip"]) * (1 - 0.5 * S["rain"]))  # stencilled lettering
        # chips: a pale rim of primer round dark undercoat
        over(m, c(150, 128, 104), 0.7 * np.clip(S["chip"] * 3, 0, 1) * (1 - np.clip(S["chip"] * 1.6 - 0.6, 0, 1)))
        over(m, c(44, 30, 24), 0.9 * np.clip(S["chip"] * 1.6 - 0.6, 0, 1))
        # edges rubbed thin where things knock them (only where the canvas says so, or low down)
        over(m, c(160, 100, 84), 0.35 * E * np.clip(S["chip"] * 2 + S["scuff"] + ss(1.2, 0.0, Y) * onside, 0, 1))
        # ends: grime streaks from the roof and spray from the buffers
        over(m * end, rain_col, 0.4 * ss(0.55, 0.8, streakn) * ss(5, 9.5, Y))
        over(m * end, mud_col, 0.5 * ss(2.0, -0.2, Y) * (0.5 + 0.5 * blot))
        rough[:] = np.where(m > 0, 0.38 + 0.35 * grime + 0.3 * S["rain"] + 0.4 * S["spray"] + 0.3 * S["soot"] + 0.3 * up, rough)
    elif kind == "Gilt":
        # aged gold leaf, not bright yellow: a darker, less saturated film over the Trim colour
        # (so the livery tint still shows through), patchy, dulled in recesses, chipped at edges
        gv = 0.75 + 0.5 * blot
        over(m, c(112, 86, 50) * gv[..., None], 0.5 + 0.12 * ss(0.3, 0.8, streakn))
        over(m, c(70, 50, 28), 0.55 * grime)
        over(m, c(112, 32, 26), 0.95 * np.clip(S["chip"] * 2 + 0.9 * E * ss(0.5, 0.8, blot), 0, 1))  # leaf off to the red ground
        over(m, rain_col, 0.45 * S["rain"])
        over(m, soot_col, 0.55 * S["soot"])
        over(m, mud_col, 0.5 * S["spray"])
        over(m, c(196, 160, 98), 0.22 * E * (1 - grime) * (1 - S["chip"]))  # rubbed on the crests
        rough[:] = np.where(m > 0, 0.3 + 0.28 * blot + 0.4 * grime + 0.3 * S["soot"] + 0.2 * S["rain"], rough)
        metal[:] = np.where(m > 0, 0.75 * (1 - 0.7 * grime) * (1 - S["chip"]) * (0.8 + 0.2 * blot), metal)
    elif kind == "Canvas":
        # tarred canvas: soot blown back from the vents and lamp tops, runs down to the eaves
        over(m, soot_col, 0.35 + 0.3 * blot)
        for v in FEAT.get("vents", []):
            dx = X - v["x"]
            plume = np.exp(-((Z - v["z"]) / (0.4 + 0.12 * np.clip(-dx, 0, 20))) ** 2) * ss(0.6, -0.2, dx) * ss(-6, -0.2, dx)
            over(m, c(10, 9, 9), 0.75 * plume)
        over(m, c(160, 156, 146), 0.25 * ss(5.4, 6.9, np.abs(Z)) * ss(0.45, 0.8, streakn))  # salt at the eaves
        over(m, c(20, 18, 18), 0.5 * grime)
        over(m, c(60, 52, 44), 0.35 * E)
        rough[:] = np.where(m > 0, 0.82 + 0.1 * blot, rough)
    elif kind == "Iron":
        over(m, c(34, 32, 32) * (0.85 + 0.3 * blot[..., None]), np.ones_like(A))
        rust = np.clip(0.8 * S["rust"] + ss(0.45, 0.75, grime * 0.8 + blot * 0.5) * 0.8, 0, 1)
        over(m, rust_dark, 0.8 * rust)
        over(m, rust_col, 0.6 * rust * ss(0.4, 0.8, streakn))
        over(m, mud_col, 0.6 * S["spray"] + 0.5 * under * (0.4 + 0.6 * blot))
        over(m, dust_col, 0.35 * up)
        over(m, c(120, 116, 110), 0.65 * E * (1 - rust))  # edges worn to bright steel
        over(m, c(150, 146, 138), 0.5 * S["scuff"])
        rough[:] = np.where(m > 0, 0.5 + 0.35 * rust + 0.2 * S["spray"] - 0.2 * E, rough)
        metal[:] = np.where(m > 0, np.clip(0.55 * (1 - rust) + 0.35 * E, 0, 1), metal)
    elif kind == "Brass":
        polish = np.clip(S["polish"] + E * 0.6, 0, 1)
        over(m, c(150, 116, 66), np.ones_like(A))
        over(m, c(78, 58, 30), 0.75 * grime * (1 - polish))  # tarnish in the recesses
        over(m, c(64, 104, 84), 0.55 * ss(0.55, 0.8, grime) * ss(0.4, 0.7, blot))  # verdigris
        over(m, c(232, 200, 128), 0.8 * polish)
        over(m, soot_col, 0.4 * S["soot"])
        rough[:] = np.where(m > 0, 0.42 - 0.3 * polish + 0.3 * grime, rough)
        metal[:] = np.where(m > 0, 1.0 - 0.4 * grime * (1 - polish), metal)
    elif kind == "Teak":
        over(m, c(74, 46, 26) * (0.8 + 0.4 * streakn[..., None]), np.ones_like(A))
        over(m, dirt_col, 0.5 * grime)
        over(m, c(130, 92, 56), 0.4 * E)
        rough[:] = np.where(m > 0, 0.4, rough)
    elif kind == "Velvet":
        over(m, c(104, 26, 34), np.ones_like(A))
        over(m, c(30, 8, 12), 0.7 * grime)
        over(m, c(150, 60, 64), 0.25 * E)
        rough[:] = np.where(m > 0, 0.9, rough)
    elif kind == "Bellows":
        over(m, c(30, 27, 25), np.ones_like(A))
        over(m, c(8, 7, 7), 0.75 * grime)
        over(m, dust_col, 0.35 * up)
        over(m, c(80, 70, 60), 0.4 * E)
        rough[:] = np.where(m > 0, 0.85, rough)

    elif kind == "Planks":
        # painted door boards (Accent tint underneath): the same weathering as the body, by cause
        over(m, c(150, 150, 130), 0.08 * ss(3.6, 7.4, Y) * onside)
        over(m, dirt_col, 0.55 * grime ** 0.85 + 0.4 * S["dirt"])
        over(m, rain_col, 0.5 * S["rain"])
        over(m, soot_col, 0.55 * S["soot"])
        over(m, mud_col, 0.55 * S["spray"])
        over(m, rust_col, 0.7 * S["rust"])
        over(m, rust_dark, 0.35 * S["rust"] ** 2)
        over(m, c(20, 24, 20), 0.32 * S["craze"])
        over(m, c(150, 146, 120), 0.5 * S["scuff"])
        over(m, c(188, 180, 158), 0.8 * S["stencil"] * (1 - 0.7 * S["chip"]) * (1 - 0.5 * S["rain"]))
        # worn through to grey timber at the chips and along knocked edges
        over(m, c(122, 108, 88), 0.85 * np.clip(S["chip"] * 1.8, 0, 1))
        over(m, c(120, 112, 92), 0.45 * E * np.clip(S["chip"] * 2 + S["scuff"] * 1.5 + ss(1.0, 0.0, Y) * onside, 0, 1))
        rough[:] = np.where(m > 0, 0.5 + 0.3 * grime + 0.25 * S["rain"] + 0.3 * S["spray"] + 0.25 * S["chip"], rough)
    elif kind == "Crate":
        # raw, untinted timber: crates, barrels' staves, toolboxes, tool racks
        g = 0.75 + 0.45 * streakn
        over(m, c(104, 80, 54) * g[..., None], np.ones_like(A))
        over(m, c(70, 60, 50), 0.5 * ss(0.4, 0.8, blot))  # weathered grey
        over(m, dirt_col, 0.6 * grime + 0.5 * S["spray"] + 0.4 * S["dirt"])
        over(m, rust_col, 0.6 * S["rust"])
        over(m, soot_col, 0.5 * S["soot"])
        over(m, c(160, 136, 100), 0.35 * E * (1 - grime))
        rough[:] = np.where(m > 0, 0.72 + 0.2 * grime, rough)
    elif kind == "Tarp":
        # an oiled tarpaulin, olive drab, pale where it folds over edges, dark in the folds
        over(m, c(64, 66, 50) * (0.85 + 0.3 * blot[..., None]), np.ones_like(A))
        over(m, c(20, 20, 16), 0.6 * grime)
        over(m, c(120, 118, 96), 0.45 * E)
        over(m, dust_col, 0.4 * up)
        over(m, soot_col, 0.5 * S["soot"])
        rough[:] = np.where(m > 0, 0.78 - 0.15 * grime, rough)
    elif kind == "Coal":
        over(m, c(20, 19, 19) * (0.7 + 0.6 * blot[..., None]), np.ones_like(A))
        over(m, c(70, 70, 74), 0.45 * E)  # glinting fracture faces
        over(m, c(6, 6, 6), 0.6 * grime)
        rough[:] = np.where(m > 0, 0.45 + 0.3 * grime - 0.2 * E, rough)
        metal[:] = np.where(m > 0, 0.15 * E, metal)
    elif kind == "Boiler":
        # Russia iron: planished blue-grey sheet, mottled where it was rolled: streaks below every
        # fitting, scale from the clack valves, heat darkening towards the smokebox, soot from the chimney
        over(m, c(66, 80, 92) * (0.82 + 0.36 * blot[..., None]), np.ones_like(A))
        over(m, c(112, 124, 134), 0.35 * ss(0.55, 0.9, noise_pos(0.35)))  # the planished mottle
        over(m, c(150, 160, 166), 0.10 * ss(0.3, 0.9, NY))  # sky on the top
        over(m, dirt_col, 0.45 * grime)
        over(m, rain_col, 0.5 * ss(0.55, 0.85, streakn) * ss(0.2, -0.6, NY))
        for v in FEAT.get("boilerFittings", []):
            # a run below the fitting, down the side of the barrel it sits over (side 0 = both)
            run = np.exp(-((X - v["x"]) / v.get("w", 0.35)) ** 2) * ss(v["y"] + 0.1, v["y"] - 0.4, Y) * ss(v["y"] - 6, v["y"] - 0.5, Y)
            if v.get("side"):
                run = run * (Z * v["side"] > 0)
            over(m, c(196, 196, 180) if v.get("kind") == "scale" else rain_col, 0.55 * run * (0.5 + 0.5 * streakn))
        over(m, soot_col, 0.6 * ss(SPEC.get("smokeboxX", 1e9) - 6, SPEC.get("smokeboxX", 1e9), X) * ss(0.0, 0.8, NY))
        over(m, c(150, 150, 146), 0.3 * E)
        rough[:] = np.where(m > 0, 0.26 + 0.35 * grime + 0.15 * blot, rough)
        metal[:] = np.where(m > 0, 0.45 + 0.25 * E - 0.3 * grime, metal)
    elif kind == "Smokebox":
        # graphite-and-oil black, burnt brown where the heat sits, ash at the bottom of the door
        over(m, c(26, 25, 25) * (0.85 + 0.3 * blot[..., None]), np.ones_like(A))
        over(m, c(62, 48, 38), 0.18 * ss(0.55, 0.9, blot) * ss(-0.2, 0.6, NY))
        over(m, c(110, 108, 104), 0.2 * ss(0.35, -0.5, NY) * ss(0.5, 0.85, streakn))  # ash
        over(m, c(96, 96, 96), 0.4 * E)
        rough[:] = np.where(m > 0, 0.75 - 0.25 * E, rough)
        metal[:] = np.where(m > 0, 0.3 + 0.3 * E, metal)
alpha[~covered] = 0


def save(name, arr, normal=False):
    f = SIZE // SAVE
    if f > 1:
        h0, w0, ch = arr.shape
        arr = arr.reshape(h0 // f, f, w0 // f, f, ch).mean(axis=(1, 3))
        if normal:
            v = arr[..., :3] * 2 - 1
            v /= np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)
            arr[..., :3] = v * 0.5 + 0.5
    h, w = arr.shape[:2]
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)  # a re-bake must not save under a ".001" name
    img = bpy.data.images.new(name, w, h, alpha=arr.shape[-1] == 4, float_buffer=False)
    img.colorspace_settings.name = "sRGB" if name.endswith("color") else "Non-Color"
    img.pixels.foreach_set(arr.astype(np.float32).ravel())
    img.filepath_raw = os.path.join(OUT, f"{name}.png")
    img.file_format = "PNG"
    img.save()
    if not os.path.exists(img.filepath_raw):
        raise RuntimeError(f"did not write {img.filepath_raw}")
    bpy.data.images.remove(img)


ones = np.ones((H_, W_), np.float32)
straight = np.where(alpha[..., None] > 1e-4, rgb / np.maximum(alpha[..., None], 1e-4), 0)
save(f"{ATLAS}_color", np.dstack([np.clip(straight, 0, 1), np.clip(alpha, 0, 1)]))
del straight
save(f"{ATLAS}_rough", np.dstack([np.clip(rough, 0, 1)] * 3 + [ones]))
save(f"{ATLAS}_metal", np.dstack([np.clip(metal, 0, 1)] * 3 + [ones]))
save(f"{ATLAS}_normal", nrm, normal=True)
# drop the packed height canvases and pass images before saving the .blend
for img in list(bpy.data.images):
    if img.name.startswith(f"{ATLAS}_h") or img.name.endswith("_nrmraw"):
        bpy.data.images.remove(img)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{ATLAS}_baked.blend"))
print("DONE", ATLAS)
