"""
Unwraps a car's MeshParts into one atlas, bakes the geometry passes in Cycles and paints the
wear in NumPy by the design bible's rules, then saves the SurfaceAppearance maps:

  blender -b <car>.blend -P tools/trainshell/bake.py -- <out_dir> <atlas_name> <size> [spec.json]

Writes <atlas>_color.png (RGBA: for a tinted part the alpha is a wear overlay over the part's
livery colour; untinted materials are opaque), _normal.png (OpenGL tangent space), _rough.png,
_metal.png, and saves the .blend with UVs. Objects whose material is Lamp or Sign are skipped.

Every mark has a cause (docs/train-exterior/DESIGN_BIBLE.md): grime in occluded corners, spray
along the skirt, rain streaks under every window sill, soot under the cornice and on the roof
downwind of the lamp-tops, chipped paint and gilt on worn edges and round the doors at hand
height, rust bleeding down from iron edges, tarnish in brass recesses.
"""

import json
import math
import os
import sys

import bpy

import numpy as np

args = sys.argv[sys.argv.index("--") + 1 :]
OUT, ATLAS, SIZE = os.path.abspath(args[0]), args[1], int(args[2])
SPEC = json.load(open(args[3]))["spec"] if len(args) > 3 else {}
os.makedirs(OUT, exist_ok=True)

MATS = ["Paint", "Gilt", "Canvas", "Planks", "Iron", "Brass", "Teak"]
TINTED = {"Paint", "Gilt", "Canvas", "Planks"}

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 1
scene.render.bake.margin = 6
scene.render.bake.use_clear = True

targets = [ob for ob in bpy.data.objects if ob.type == "MESH" and not ob.hide_render and ob.get("material") not in ("Lamp", "Sign")
           and ob.get("atlas", ATLAS) == ATLAS]
print("BAKE", ATLAS, [ob.name for ob in targets])

# -- UVs: one shared atlas, equal texel density ------------------------------------------
# A baked file keeps its UVs (the uploaded meshes carry them), so re-painting never moves them.
if not all(ob.data.uv_layers for ob in targets):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in targets:
        ob.select_set(True)
        if not ob.data.uv_layers:
            ob.data.uv_layers.new(name="UVMap")
    bpy.context.view_layer.objects.active = targets[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0, scale_to_bounds=False)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")

# -- materials: every slot gets the pass network -------------------------------------------


def image(name, float_buffer):
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=False, float_buffer=float_buffer)
    img.colorspace_settings.name = "Non-Color"
    return img


def bump_for(nodes, links, kind, coord):
    """A Bump node fed by a height field fitting the material (in object space, studs)."""
    bump = nodes.new("ShaderNodeBump")
    if kind == "Planks":
        # vertical boards 0.35 apart: a groove at each joint, plus a long grain
        wave = nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "X"
        wave.wave_profile = "SAW"
        wave.inputs["Scale"].default_value = 1 / 0.35 / 1.0
        links.new(coord, wave.inputs["Vector"])
        ramp = nodes.new("ShaderNodeMath")
        ramp.operation = "GREATER_THAN"
        ramp.inputs[1].default_value = 0.06
        links.new(wave.outputs["Fac"], ramp.inputs[0])
        grain = nodes.new("ShaderNodeTexNoise")
        grain.inputs["Scale"].default_value = 6
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (6, 6, 0.25)
        links.new(coord, mapping.inputs["Vector"])
        links.new(mapping.outputs["Vector"], grain.inputs["Vector"])
        add = nodes.new("ShaderNodeMath")
        add.operation = "MULTIPLY_ADD"
        add.inputs[1].default_value = 0.15
        links.new(grain.outputs["Fac"], add.inputs[0])
        links.new(ramp.outputs[0], add.inputs[2])
        links.new(add.outputs[0], bump.inputs["Height"])
        bump.inputs["Strength"].default_value = 0.6
        bump.inputs["Distance"].default_value = 0.02
    else:
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = {"Canvas": 60, "Iron": 18, "Paint": 9, "Gilt": 30, "Brass": 25, "Teak": 12}.get(kind, 10)
        noise.inputs["Detail"].default_value = 6
        links.new(coord, noise.inputs["Vector"])
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        bump.inputs["Strength"].default_value = {"Canvas": 0.35, "Iron": 0.3, "Paint": 0.06, "Gilt": 0.05, "Brass": 0.08, "Teak": 0.25}.get(kind, 0.1)
        bump.inputs["Distance"].default_value = 0.01
    return bump


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
    bump = bump_for(nodes, links, kind, tex.outputs["Object"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    emit = nodes.new("ShaderNodeEmission")
    target = nodes.new("ShaderNodeTexImage")
    nodes.active = target
    # pass sources
    srcs = {}
    srcs["pos"] = geo.outputs["Position"]
    srcs["wnrm"] = geo.outputs["Normal"]
    bev = nodes.new("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = 0.06
    bev.samples = 8
    dot = nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    links.new(geo.outputs["Normal"], dot.inputs[0])
    links.new(bev.outputs["Normal"], dot.inputs[1])
    srcs["edge"] = dot.outputs["Value"]
    mid = MATS.index(kind) if kind in MATS else 7
    rgb = nodes.new("ShaderNodeRGB")
    rgb.outputs[0].default_value = ((mid + 0.5) / 8, 0, 0, 1)
    srcs["mat"] = rgb.outputs[0]
    # noise fields in object space: fine, medium, vertical streaks / chips, horizontal scratches, blotches
    def noise(scale, stretch, detail=4):
        m = nodes.new("ShaderNodeMapping")
        m.inputs["Scale"].default_value = stretch
        links.new(tex.outputs["Object"], m.inputs["Vector"])
        n = nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        links.new(m.outputs["Vector"], n.inputs["Vector"])
        return n.outputs["Fac"]
    comb = nodes.new("ShaderNodeCombineColor")
    links.new(noise(6, (1, 1, 1), 8), comb.inputs[0])
    links.new(noise(0.8, (1, 1, 1), 3), comb.inputs[1])
    links.new(noise(2.5, (6, 6, 0.12), 6), comb.inputs[2])  # Blender Z is Roblox up: long vertical runs
    srcs["noise1"] = comb.outputs[0]
    vor = nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 3.5
    links.new(tex.outputs["Object"], vor.inputs["Vector"])
    comb2 = nodes.new("ShaderNodeCombineColor")
    links.new(vor.outputs["Distance"], comb2.inputs[0])
    links.new(noise(9, (0.1, 0.1, 8), 4), comb2.inputs[1])  # horizontal scratches
    links.new(noise(1.6, (1, 1, 1), 2), comb2.inputs[2])
    srcs["noise2"] = comb2.outputs[0]
    passes[mat.name] = (nt, out, bsdf, emit, target, srcs)


slot_kind = {}
for ob in targets:
    for slot in ob.material_slots:
        mat = slot.material
        if mat and mat.name not in passes:
            setup(mat, mat.name.split(".")[0])


def bake(kind, name, float_buffer=True):
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
    if kind == "AO":
        scene.cycles.samples = 48
    elif kind == "EMIT" and name.endswith("edge"):
        scene.cycles.samples = 8
    else:
        scene.cycles.samples = 1
    bpy.ops.object.bake(type=kind, normal_space="TANGENT")
    arr = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    print("baked", name)
    return arr.reshape(SIZE, SIZE, 4), img


ao, _ = bake("AO", f"{ATLAS}_ao")
pos, _ = bake("EMIT", f"{ATLAS}_pos")
wn, _ = bake("EMIT", f"{ATLAS}_wnrm")
edge, _ = bake("EMIT", f"{ATLAS}_edge")
mat, _ = bake("EMIT", f"{ATLAS}_mat")
n1, _ = bake("EMIT", f"{ATLAS}_noise1")
n2, _ = bake("EMIT", f"{ATLAS}_noise2")
nrm, nimg = bake("NORMAL", f"{ATLAS}_nrmraw", float_buffer=False)

# -- paint the wear ---------------------------------------------------------------------------
# Blender -> Roblox: x, y(up) = Blender z, z = -Blender y
X, Y, Z = pos[..., 0], pos[..., 2], -pos[..., 1]
NY, NZ = wn[..., 2], -wn[..., 1]
A = np.clip(ao[..., 0], 0, 1)
E = np.clip((1 - edge[..., 0]) * 6, 0, 1)  # worn edges
M = np.clip((mat[..., 0] * 8).astype(int), 0, 7)
fine, med, streak = n1[..., 0], n1[..., 1], n1[..., 2]
cell, scratch, blot = n2[..., 0], n2[..., 1], n2[..., 2]
covered = mat[..., 0] > 0.01  # unbaked texels stay black


def ss(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def c(r, g, b):
    return np.array([r, g, b], np.float32) / 255


H, W = A.shape
rgb = np.zeros((H, W, 3), np.float32)
alpha = np.zeros((H, W), np.float32)
rough = np.full((H, W), 0.5, np.float32)
metal = np.zeros((H, W), np.float32)


def over(mask, col, a):
    """Lay a colour over what is there with alpha a (premultiplied 'over')."""
    a = np.clip(a, 0, 1) * mask
    rgb[:] = rgb * (1 - a[..., None]) + col * a[..., None]
    alpha[:] = alpha + a * (1 - alpha)


side = np.abs(NZ) > 0.5  # faces looking out of the sides
grime = (1 - A) ** 1.4
x0, x1 = SPEC.get("x0", -1e9), SPEC.get("x1", 1e9)
windows = SPEC.get("windows", {})
doors = SPEC.get("doors", {})

# shared dirt: occlusion grime, spray along the skirt
dirt_col = c(44, 30, 24)
spray = ss(1.8, -0.6, Y) * (0.55 + 0.45 * med)
soot_col = c(26, 22, 22)

for k, kind in enumerate(MATS):
    m = (M == k).astype(np.float32)
    if not m.any():
        continue
    if kind == "Paint":
        # weather fades the paint toward pale (so any livery lifts at night), the upper panels most
        over(m, c(176, 158, 146), (0.14 + 0.12 * ss(3.4, 8.0, Y)) * ss(0.25, 0.8, med) * side)
        over(m, dirt_col, 0.36 * grime + 0.32 * spray * side)
        for s_key, xs in windows.items():
            sg = 1 if int(s_key) > 0 else -1
            for wx in xs:
                under = (np.abs(X - wx) < 1.85) & (Y < 3.3) & (Y > -0.1) & (np.sign(Z) == sg)
                run = ss(0.45, 0.75, streak) * (1 - ss(0.0, 3.3, 3.3 - Y) * 0.7)
                over(m * under, c(36, 26, 22), 0.42 * run)
        over(m, soot_col, 0.4 * ss(7.4, 9.6, Y) * (0.4 + 0.6 * med) * side)
        # rust bleeding down from the corner straps and the solebar's rivets
        corner = (np.minimum(np.abs(X - x0), np.abs(X - x1)) < 0.75) & side
        over(m * corner, c(96, 50, 28), 0.45 * ss(0.5, 0.8, streak) * ss(9.0, 2.0, Y))
        over(m * side, c(96, 50, 28), 0.35 * ss(0.55, 0.85, streak) * ss(0.9, 0.0, Y))
        # chipped paint on worn edges, worst round the doors at hand height
        near_door = np.zeros_like(A)
        for s_key, xs in doors.items():
            sg = 1 if int(s_key) > 0 else -1
            for d in xs:
                near_door = np.maximum(near_door, ((np.abs(X - d) < 4.2) & (Y > 1.8) & (Y < 5.6) & (np.sign(Z) == sg)).astype(np.float32))
        chips = ((cell < 0.18 + 0.25 * E) & (E > 0.25)).astype(np.float32)
        over(m, c(58, 34, 26), 0.95 * chips)
        over(m * near_door, c(190, 150, 120), 0.5 * ss(0.62, 0.7, scratch) * ss(0.4, 0.7, fine))
        rough[:] = np.where(m > 0, 0.36 + 0.4 * grime + 0.2 * spray, rough)
    elif kind == "Gilt":
        over(m, c(60, 40, 20), 0.42 * grime)
        over(m, c(110, 30, 26), 0.9 * ((cell < 0.12) & (E > 0.15)))  # gold leaf off to the red ground
        over(m, dirt_col, 0.5 * spray * side)
        over(m, soot_col, 0.4 * ss(7.6, 9.6, Y))
        rough[:] = np.where(m > 0, 0.28 + 0.45 * grime, rough)
        metal[:] = np.where(m > 0, 0.65 * (1 - 0.6 * grime), metal)
    elif kind == "Canvas":
        over(m, soot_col, 0.5 * (0.4 + 0.6 * med) * (NY > 0.5))
        over(m, c(150, 150, 140), 0.18 * ss(5.6, 6.9, np.abs(Z)) * ss(0.4, 0.7, blot))  # salt at the eaves
        over(m, c(20, 18, 18), 0.45 * grime)
        rough[:] = np.where(m > 0, 0.88, rough)
    elif kind == "Planks":
        over(m, c(150, 172, 150), 0.16 * ss(0.3, 0.8, med))  # paint chalked pale by the weather
        over(m, c(18, 30, 24), 0.18 * ss(0.3, 0.7, fine))
        over(m, dirt_col, 0.3 * grime + 0.4 * ss(-1.2, -3.8, Y) * (0.5 + 0.5 * med))  # leaves are in local space: floor at y -3.75
        over(m, c(150, 128, 92), 0.6 * ((E > 0.2) & (cell < 0.3)))  # worn to bare wood on the edges
        over(m, c(140, 120, 88), 0.4 * ss(0.6, 0.7, scratch) * ((Y > -1.4) & (Y < 0.8)))  # hands round the pull bar
        rough[:] = np.where(m > 0, 0.62, rough)
    elif kind == "Iron":
        base = c(40, 38, 38) * (0.85 + 0.3 * fine[..., None])
        over(m, base, np.ones_like(A))
        rust = ss(0.42, 0.62, blot * 0.6 + (1 - A) * 0.7 + fine * 0.2)
        over(m, c(98, 54, 30), 0.85 * rust)
        over(m, c(120, 66, 34), 0.5 * rust * ss(0.5, 0.8, fine))
        over(m, c(84, 82, 80), 0.6 * E * (1 - rust))
        rough[:] = np.where(m > 0, 0.62 + 0.3 * rust, rough)
        metal[:] = np.where(m > 0, 0.35 * (1 - rust), metal)
    elif kind == "Brass":
        over(m, c(150, 120, 74), np.ones_like(A))
        over(m, c(84, 64, 36), 0.7 * grime)
        over(m, c(70, 100, 82), 0.5 * ((cell < 0.1) & (A < 0.75)))  # verdigris in the recesses
        over(m, c(200, 170, 110), 0.6 * E)
        rough[:] = np.where(m > 0, 0.3 + 0.35 * grime, rough)
        metal[:] = np.where(m > 0, 0.9, metal)
    elif kind == "Teak":
        ang = np.arctan2(Y, Z)
        seg = np.abs(((ang / (2 * np.pi / 16)) % 1) - 0.5) > 0.46
        over(m, c(78, 52, 32) * (0.8 + 0.35 * fine[..., None]), np.ones_like(A))
        over(m, c(30, 22, 16), 0.9 * seg)
        over(m, dirt_col, 0.5 * grime)
        rough[:] = np.where(m > 0, 0.65, rough)

# tinted materials keep a minimum of their own colour visible; untinted ones are opaque already
alpha[~covered] = 0


def save(name, arr):
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
    return img


ones = np.ones((H, W), np.float32)
# premultiplied -> straight alpha for the PNG
straight = np.where(alpha[..., None] > 1e-4, rgb / np.maximum(alpha[..., None], 1e-4), 0)
color = np.dstack([np.clip(straight, 0, 1), np.clip(alpha, 0, 1)])
save(f"{ATLAS}_color", color)
save(f"{ATLAS}_rough", np.dstack([rough, rough, rough, ones]))
save(f"{ATLAS}_metal", np.dstack([metal, metal, metal, ones]))
save(f"{ATLAS}_normal", nrm)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{ATLAS}_baked.blend"))
print("DONE", ATLAS)
