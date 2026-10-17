"""
Dim-screen render harness, part 1 of 2: builds a REAL station in Blender and renders the
shots measure.py judges. Headless:

    lune run visibility <scratch>/vis.json
    blender -b --factory-startup --python tools/visibility/render.py -- <scratch>/vis.json <out_dir> <station> [--only=<prefix>]
    blender -b --factory-startup --python tools/visibility/render.py -- --calibrate

<station> is 0, 1 or 2 (early, mid, late in the export). Every shot is written as
<out_dir>/<station label>/<shot>.exr (linear light), <shot>_id.exr (object index in R) and
<shot>_pos.exr (world position, alpha 0 on sky): Blender 5.2 headless writes only Combined
into a multilayer EXR, so the two passes are 1-sample material-override renders. Plus <shot>.json (what is in it: the player, the crew, the targets by object index).

The scene is built from the export (.lune/visibility.luau): every visible station and train
part, the kit meshes from assets/stationkit/StationKit.blend, every station light, the sky as
Scenery/Sky composes it (with the readability floor and the chase), the crew's lanterns and
the bearer's cone from Tuning. Where it is not Roblox is listed in thresholds.py
("Roblox approximations"); the README repeats it.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import thresholds as T  # noqa: E402
from classify import LIP, classify  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KIT = os.path.join(ROOT, "assets", "stationkit", "StationKit.blend")
argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
CALIBRATE = "--calibrate" in argv
# --falloff=smooth: the other common curve, (1 - (d/R)^2)^2, instead of thresholds.FALLOFF
SMOOTH = "--falloff=smooth" in argv

# Light strength that makes Brightness 1 light a white surface facing it to white
# (measured by --calibrate: a Cycles point light, constant falloff, 1 W).
LIGHT_K = 39.278  # measured: --calibrate, white plane 2 studs under a Range-1e6 light


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(rgb):
    return tuple(srgb_to_linear(v) for v in rgb)


def conv(v):
    """Roblox (x, y up, z) -> Blender (x, -z, y z up): a proper rotation."""
    return Vector((v[0], -v[2], v[1]))


def frame_matrix(p, r, size):
    right, up, back = conv(r[0:3]), conv(r[3:6]), conv(r[6:9])
    m = Matrix.Identity(4)
    for i, (axis, s) in enumerate(((right, size[0]), (up, size[1]), (back, size[2]))):
        for row in range(3):
            m[row][i] = axis[row] * s
    t = conv(p)
    m[0][3], m[1][3], m[2][3] = t
    return m


# --- primitives in Roblox-local unit space (x right, y up, z back), Blender-converted ---
def make_mesh(name, verts, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([conv(v) for v in verts], [], faces)
    mesh.validate()
    mesh.update()
    return mesh


def unit_meshes():
    h = 0.5
    box_v = [(x, y, z) for x in (-h, h) for y in (-h, h) for z in (-h, h)]
    box_f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    box = make_mesh("unit_box", box_v, box_f)
    # Roblox WedgePart: full height at the back (+Z), the slope falling to the front (-Z)
    wedge_v = [(-h, -h, -h), (h, -h, -h), (h, -h, h), (-h, -h, h), (-h, h, h), (h, h, h)]
    wedge_f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    wedge = make_mesh("unit_wedge", wedge_v, wedge_f)
    n = 16  # Roblox Cylinder: axis along local X
    cyl_v = []
    for x in (-h, h):
        for i in range(n):
            a = 2 * math.pi * i / n
            cyl_v.append((x, h * math.cos(a), h * math.sin(a)))
    cyl_f = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    cyl_f += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    cyl = make_mesh("unit_cyl", cyl_v, cyl_f)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.5)
    ball_ob = bpy.context.active_object
    ball = ball_ob.data
    ball.name = "unit_ball"
    bpy.data.objects.remove(ball_ob)
    for m in (box, wedge, cyl, ball):
        m.polygons.foreach_set("use_smooth", [m is cyl or m is ball] * len(m.polygons))
    return {"B": box, "W": wedge, "C": cyl, "S": ball}


# --- materials ---------------------------------------------------------------------------
AMBIENT = None  # the RGB node every material reads Lighting.Ambient from


def ambient_group():
    g = bpy.data.node_groups.new("Ambient", "ShaderNodeTree")
    g.interface.new_socket("Color", in_out="OUTPUT", socket_type="NodeSocketColor")
    out = g.nodes.new("NodeGroupOutput")
    rgb = g.nodes.new("ShaderNodeRGB")
    rgb.name = "value"
    g.links.new(rgb.outputs[0], out.inputs[0])
    return g


def surface_material(name, kind):
    """kind: solid | neon | glass | kit. Base colour from the object's colour (and the kit's
    vertex colours). Lighting.Ambient added for camera rays only (no bounce: Roblox Future
    lights are direct only)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    info = nt.nodes.new("ShaderNodeObjectInfo")
    base = info.outputs["Color"]
    if kind == "kit":
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs["Factor"].default_value = 1
        nt.links.new(base, mul.inputs["A"])
        nt.links.new(attr.outputs["Color"], mul.inputs["B"])
        base = mul.outputs["Result"]
    if kind == "neon":
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(base, em.inputs["Color"])
        em.inputs["Strength"].default_value = 1.0
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        return mat
    bsdf = nt.nodes.new("ShaderNodeBsdfDiffuse")
    nt.links.new(base, bsdf.inputs["Color"])
    amb = nt.nodes.new("ShaderNodeGroup")
    amb.node_tree = AMBIENT
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1
    nt.links.new(base, tint.inputs["A"])
    nt.links.new(amb.outputs[0], tint.inputs["B"])
    path = nt.nodes.new("ShaderNodeLightPath")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(tint.outputs["Result"], em.inputs["Color"])
    nt.links.new(path.outputs["Is Camera Ray"], em.inputs["Strength"])
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(bsdf.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    shader = add.outputs[0]
    if kind == "glass":
        transp = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        alpha = nt.nodes.new("ShaderNodeAttribute")
        alpha.attribute_type = "OBJECT"
        alpha.attribute_name = "alpha"
        nt.links.new(alpha.outputs["Fac"], mix.inputs[0])
        nt.links.new(transp.outputs[0], mix.inputs[1])
        nt.links.new(shader, mix.inputs[2])
        shader = mix.outputs[0]
    nt.links.new(shader, out.inputs["Surface"])
    return mat


# --- lights: Roblox Range windowing on a Cycles light ------------------------------------
def roblox_light(name, color, brightness, rng, at, direction=None, angle=None, shadows=False):
    kind = "SPOT" if direction is not None else "POINT"
    data = bpy.data.lights.new(name, kind)
    data.energy = 1.0
    data.color = lin(color)
    data.shadow_soft_size = 0.15
    data.use_shadow = shadows
    if kind == "SPOT":
        data.spot_size = math.radians(min(angle, 179))
        data.spot_blend = 0.15
    data.use_nodes = True
    nt = data.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputLight")
    em = nt.nodes.new("ShaderNodeEmission")
    fall = nt.nodes.new("ShaderNodeLightFalloff")
    path = nt.nodes.new("ShaderNodeLightPath")
    # window = clamp(1 - d / Range, 0, 1)^2 (thresholds.FALLOFF), or (1 - (d/R)^2)^2 (SMOOTH)
    div = nt.nodes.new("ShaderNodeMath")
    div.name = "range"
    div.operation = "DIVIDE"
    nt.links.new(path.outputs["Ray Length"], div.inputs[0])
    div.inputs[1].default_value = max(rng, 0.01)
    ratio = div.outputs[0]
    if SMOOTH:
        sq_r = nt.nodes.new("ShaderNodeMath")
        sq_r.operation = "MULTIPLY"
        nt.links.new(div.outputs[0], sq_r.inputs[0])
        nt.links.new(div.outputs[0], sq_r.inputs[1])
        ratio = sq_r.outputs[0]
    sub = nt.nodes.new("ShaderNodeMath")
    sub.operation = "SUBTRACT"
    sub.use_clamp = True
    sub.inputs[0].default_value = 1.0
    nt.links.new(ratio, sub.inputs[1])
    sq = nt.nodes.new("ShaderNodeMath")
    sq.operation = "MULTIPLY"
    nt.links.new(sub.outputs[0], sq.inputs[0])
    nt.links.new(sub.outputs[0], sq.inputs[1])
    k = nt.nodes.new("ShaderNodeMath")
    k.name = "bright"
    k.operation = "MULTIPLY"
    nt.links.new(sq.outputs[0], k.inputs[0])
    k.inputs[1].default_value = brightness * LIGHT_K
    nt.links.new(k.outputs[0], fall.inputs["Strength"])
    fall.inputs["Smooth"].default_value = 0
    nt.links.new(fall.outputs["Constant"], em.inputs["Strength"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    ob = bpy.data.objects.new(name, data)
    ob.location = conv(at)
    if direction is not None:
        d = conv(direction).normalized()
        ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(ob)
    ob["range"] = rng
    ob["brightness"] = brightness
    return ob


def set_light(ob, brightness, rng):
    nodes = ob.data.node_tree.nodes
    nodes["range"].inputs[1].default_value = max(rng, 0.01)
    nodes["bright"].inputs[1].default_value = brightness * LIGHT_K


# --- scene ------------------------------------------------------------------------------
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = T.SAMPLES
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 0  # Roblox Future: direct light only
    scene.cycles.diffuse_bounces = 0
    scene.cycles.glossy_bounces = 0
    scene.cycles.transparent_max_bounces = 8
    scene.render.resolution_x = T.WIDTH
    scene.render.resolution_y = T.HEIGHT
    scene.render.resolution_percentage = 100
    scene.render.use_persistent_data = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "32"
    world = bpy.data.worlds.new("Sky")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    light = nt.nodes.new("ShaderNodeBackground")
    light.name = "light"
    seen = nt.nodes.new("ShaderNodeBackground")
    seen.name = "seen"
    path = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(path.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(light.outputs[0], mix.inputs[1])
    nt.links.new(seen.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    return scene


def calibrate():
    """A white plane under one Brightness-1 light, d = 2 studs: Range 1e6 should read 1.0
    (sets LIGHT_K) and Range 4 should read (1 - 2/4)^2 = 0.25 of it (proves the window)."""
    global AMBIENT
    import OpenImageIO as oiio

    scene = reset()
    AMBIENT = ambient_group()
    AMBIENT.nodes["value"].outputs[0].default_value = (0, 0, 0, 1)
    for node in ("light", "seen"):
        scene.world.node_tree.nodes[node].inputs["Color"].default_value = (0, 0, 0, 1)
    meshes = unit_meshes()
    meshes["B"].materials.append(surface_material("white", "solid"))
    plane = bpy.data.objects.new("plane", meshes["B"])
    plane.matrix_world = frame_matrix((0, -0.05, 0), (1, 0, 0, 0, 1, 0, 0, 0, 1), (40, 0.1, 40))
    plane.color = (1, 1, 1, 1)
    scene.collection.objects.link(plane)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 0.1
    cam.location = Vector((0, 0, 0.5))  # a camera looks down -Z by default
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 8
    path = os.path.join(os.environ.get("TEMP", "."), "lto_calib.exr")
    results = {}
    for rng in (1e6, 4.0):
        for ob in [o for o in scene.objects if o.type == "LIGHT"]:
            bpy.data.objects.remove(ob)
        roblox_light("L", (255, 255, 255), 1.0, rng, (0, 2.0, 0))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        px = oiio.ImageBuf(path).get_pixels(oiio.FLOAT)
        results[rng] = float(px[..., 0].mean())
        os.remove(path)
    print("CALIBRATE", results, "ratio", results[4.0] / results[1e6], "LIGHT_K should be", LIGHT_K / results[1e6])


if CALIBRATE:
    calibrate()
    sys.exit(0)

# --- the real scene ---------------------------------------------------------------------
SRC, OUT, STATION = argv[0], argv[1], int(argv[2])
ONLY = next((a.split("=", 1)[1] for a in argv if a.startswith("--only=")), None)
# what-if only (not the game): lantern Range = floor x REACH; shots are named x<REACH>_...
REACH = float(next((a.split("=", 1)[1] for a in argv if a.startswith("--reach=")), "1"))
# --tier=perf: the Performance graphics tier (Tuning.Visibility.Budget / Rim): the cone's
# shorter reach and no cone shadow, 4 rims; shots are named <shot>_perf
PERF = "--tier=perf" in argv
# --ceiling (what-if, not the game): every Tier A part and Tier B model painted pure white,
# everything else as built: the most albedo alone could give; shots are named ceil_<shot>
CEILING = "--ceiling" in argv
with open(SRC, encoding="utf-8") as fh:
    data = json.load(fh)
st = data["stations"][STATION]
OUT = os.path.join(OUT, st["label"])
os.makedirs(OUT, exist_ok=True)

scene = reset()
AMBIENT = ambient_group()
meshes = unit_meshes()
MATS = {k: surface_material(k, k) for k in ("solid", "neon", "glass", "kit")}

# object indices (Blender caps pass_index at 32767): 0 nothing, 1.. groups (station/train
# models), Tier A hazard parts from 20000 (each its own index), crew from 31000, the
# monster stand-in 32000
group_ids = {}
for key in sorted(st["groups"]):
    group_ids[key] = len(group_ids) + 1
TIERS = classify(st, data["edgeZ"])  # tools/visibility/classify.py: mechanical, not by hand
HAZARD_BASE = 20000
hazard_ids = {i: HAZARD_BASE + k for k, i in enumerate(sorted(TIERS["A"]))}
assert len(group_ids) < HAZARD_BASE and len(hazard_ids) < 11000
STANDIN_ID = 32000

ground_y = 0.0  # platform top (StationBuilder: slab top at y 0)
targets = {}  # index -> {kind, name, ...}
obstacle_boxes = {}  # group -> list of (min, max) roblox-space AABBs of its collidable parts


def aabb(p):
    r = p["r"]
    half = [p["z"][0] / 2, p["z"][1] / 2, p["z"][2] / 2]
    ext = [abs(r[i]) * half[0] + abs(r[3 + i]) * half[1] + abs(r[6 + i]) * half[2] for i in range(3)]
    return [p["p"][i] - ext[i] for i in range(3)], [p["p"][i] + ext[i] for i in range(3)]


coll = bpy.data.collections.new("station")
scene.collection.children.link(coll)
for i, p in enumerate(st["parts"]):
    kind = "neon" if p["m"] == "Neon" else ("glass" if p["t"] > 0.01 else "solid")
    ob = bpy.data.objects.new(f"p{i}", meshes[p["s"]])
    size = p["z"]
    if p["s"] == "S":
        d = min(size)
        size = [d, d, d]
    ob.matrix_world = frame_matrix(p["p"], p["r"], size)
    white = CEILING and (i in TIERS["A"] or p["g"] in TIERS["B"])
    ob.color = (1, 1, 1, 1) if white else (*lin(p["c"]), 1)
    ob["alpha"] = 1 - p["t"]
    ob.pass_index = hazard_ids.get(i) or group_ids.get(p["g"], 0)
    coll.objects.link(ob)
    ob["kind"] = kind
    lo, hi = aabb(p)
    if p["col"] and hi[1] > ground_y + T.STEP and lo[1] < ground_y + T.HEAD and (hi[0] - lo[0]) < 120 and (hi[2] - lo[2]) < 120:
        obstacle_boxes.setdefault(p["g"], []).append((lo, hi))

# shared meshes take an object-linked material slot each
for m in meshes.values():
    m.materials.append(MATS["solid"])
for ob in coll.objects:
    slot = ob.material_slots[0]
    slot.link = "OBJECT"
    slot.material = MATS[ob["kind"]]

# kit meshes from the Blender kit, converted to Roblox-local space (Y up, Z away from train)
with bpy.data.libraries.load(KIT, link=False) as (src, dst):
    dst.meshes = [n for n in src.meshes]
kit = {}
for mesh in dst.meshes:
    m = mesh.copy()
    m.transform(Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1))))  # (bx,by,bz)->(x,y=bz,z=by)
    m.flip_normals()
    m.transform(Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))))  # Roblox-local -> Blender
    m.materials.clear()
    m.materials.append(MATS["kit"])
    kit[mesh.name] = m
for j, k in enumerate(st["meshes"]):
    mesh = kit.get(k["piece"])
    if mesh is None:
        continue
    ob = bpy.data.objects.new(f"k{j}", mesh)
    ob.matrix_world = frame_matrix(k["p"], k["r"], (k["scale"], 1, 1))
    ob.color = (1, 1, 1, 1)
    coll.objects.link(ob)
    slot = ob.material_slots[0]
    slot.link = "OBJECT"
    slot.material = MATS["kit"]

station_lights = []
for j, l in enumerate(st["lights"]):
    ob = roblox_light(f"s{j}", l["c"], l["b"], l["r"], l["p"], l.get("d"), l.get("a"))
    station_lights.append(ob)

# moon / sun
moon = bpy.data.objects.new("moon", bpy.data.lights.new("moon", "SUN"))
moon.data.angle = math.radians(1)
scene.collection.objects.link(moon)

bpy.context.view_layer.update()
depsgraph = bpy.context.evaluated_depsgraph_get()


def ray(origin, direction, dist=1e4):
    """Blender-space ray against the station; returns (hit, location, object)."""
    hit, loc, _n, _i, ob, _m = scene.ray_cast(depsgraph, origin, direction.normalized(), distance=dist)
    return hit, loc, ob


def ground_at(x, z, top=3.0):
    """Roblox y of the walkable surface under (x, z), cast from `top` studs up."""
    hit, loc, _ob = ray(conv((x, top, z)), Vector((0, 0, -1)), 60)
    return (loc.z if hit else None)


# --- people -----------------------------------------------------------------------------
R6 = [  # (name, size, centre offset from the root, colour)
    ("legL", (1, 2, 1), (-0.5, -2, 0), T.COAT),
    ("legR", (1, 2, 1), (0.5, -2, 0), T.COAT),
    ("torso", (2, 2, 1), (0, 0, 0), T.COAT),
    ("armL", (1, 2, 1), (-1.5, 0, 0), T.COAT),
    ("armR", (1, 2, 1), (1.5, 0, 0), T.COAT),
    ("head", (1.2, 1, 1), (0, 1.5, 0), T.SKIN),
]
people = []


def yaw_frame(yaw):
    """Roblox basis (right, up, back) for a character facing `yaw` (0 = +Z, away from the train)."""
    f = (math.sin(yaw), 0, math.cos(yaw))  # look
    right = (-f[2], 0, f[0])
    return right, (0, 1, 0), (-f[0], 0, -f[2])


def place_person(index, root, yaw, lantern, radius, chase, cone):
    right, up, back = yaw_frame(yaw)
    rot = list(right) + list(up) + list(back)
    obs = []
    body_id = 31000 + index * 10
    for name, size, off, colour in R6:
        centre = [root[i] + right[i] * off[0] + up[i] * off[1] + back[i] * off[2] for i in range(3)]
        ob = bpy.data.objects.new(f"c{index}{name}", meshes["B"])
        ob.matrix_world = frame_matrix(centre, rot, size)
        ob.color = (*lin(colour), 1)
        ob.pass_index = body_id
        scene.collection.objects.link(ob)
        slot = ob.material_slots[0]
        slot.link = "OBJECT"
        slot.material = MATS["solid"]
        obs.append(ob)
    # the lantern at the right hip (CosmeticService: torso * (1.4, belt, 0.05)), lens lower
    lens_at = [root[i] + right[i] * 1.4 + back[i] * 0.05 for i in range(3)]
    lens_at[1] = root[1] - 3 + T.LENS_HEIGHT
    lens = bpy.data.objects.new(f"c{index}lens", meshes["S"])
    lens.matrix_world = frame_matrix(lens_at, rot, (0.5, 0.5, 0.5))
    lens.color = (*lin(lantern["glass"]), 1)
    lens.pass_index = body_id + 1
    scene.collection.objects.link(lens)
    slot = lens.material_slots[0]
    slot.link = "OBJECT"
    slot.material = MATS["neon"]
    obs.append(lens)
    lamp = data["lantern"]
    reach = radius * REACH * (data["visibility"]["chase"]["LightRange"] if chase else 1)
    light = roblox_light(
        f"c{index}glow", lantern["light"], lamp["LightBrightness"] * lantern["glow"], reach,
        [lens_at[0], lens_at[1] + 0.3, lens_at[2]],
    )
    light.data.use_shadow = False  # Budget: lantern shadows forced off
    obs.append(light)
    if cone:
        cone_range = data["visibility"]["budget"]["ConeRangePerformance"] if PERF else lamp["ConeRange"]
        look = (-back[0], 0, -back[2])
        at = [root[0] - back[0] * 0.8, root[1] + lamp["ConeHeight"], root[2] - back[2] * 0.8]
        c = roblox_light(
            f"c{index}cone", lantern["light"], lamp["ConeBrightness"], max(cone_range, radius), at,
            direction=(look[0], -0.0, look[2]), angle=lamp["ConeAngle"], shadows=not PERF,
        )
        obs.append(c)
    people.append(obs)
    return {"body": body_id, "lens": body_id + 1, "root": root, "lensAt": lens_at}


STANDIN = [  # a Hollow-sized stand-in (not the game's Hollow): 7 studs tall, dark hide
    ("legL", (1.1, 3, 1.1), (-0.6, -2.5, 0)),
    ("legR", (1.1, 3, 1.1), (0.6, -2.5, 0)),
    ("torso", (2.4, 2.8, 1.2), (0, 0.4, 0)),
    ("armL", (0.9, 3.4, 0.9), (-1.7, 0.1, 0)),
    ("armR", (0.9, 3.4, 0.9), (1.7, 0.1, 0)),
    ("head", (1.2, 1.2, 1.2), (0, 2.4, 0)),
]
STANDIN_COLOR = (44, 40, 38)


def place_standin(root, yaw):
    right, up, back = yaw_frame(yaw)
    rot = list(right) + list(up) + list(back)
    obs = []
    for name, size, off in STANDIN:
        centre = [root[i] + right[i] * off[0] + up[i] * off[1] + back[i] * off[2] for i in range(3)]
        ob = bpy.data.objects.new(f"m{name}", meshes["B"])
        ob.matrix_world = frame_matrix(centre, rot, size)
        ob.color = (*lin(STANDIN_COLOR), 1)
        ob.pass_index = STANDIN_ID
        scene.collection.objects.link(ob)
        slot = ob.material_slots[0]
        slot.link = "OBJECT"
        slot.material = MATS["solid"]
        obs.append(ob)
    people.append(obs)


def clear_people():
    for obs in people:
        for ob in obs:
            bpy.data.objects.remove(ob, do_unlink=True)
    people.clear()


# --- the player's spot: on the platform, the coping 0.9 floor radii behind --------------
def lantern(id_):
    return next(l for l in data["lanterns"] if l["id"] == id_)


EDGE_Z = next(p for p in st["parts"] if p.get("edge"))["p"][2]  # the coping's centre line


def obstacle_distance(group, x, z):
    best = 1e9
    for lo, hi in obstacle_boxes.get(group, []):
        dx = max(lo[0] - x, 0, x - hi[0])
        dz = max(lo[2] - z, 0, z - hi[2])
        best = min(best, math.hypot(dx, dz))
    return best


def choose_spot(radius):
    """The platform spot (x, z) with the most obstacles in the must-see bands: the coping
    0.9 floor radii behind it where the platform allows, else nearer or further."""
    best, spot = -1, None
    half = st["length"] / 2 - radius
    for share in (0.9, 0.8, 1.0, 0.7, 0.6):
        z = EDGE_Z + share * radius
        for step in range(-12, 13):
            x = step * half / 12
            y = ground_at(x, z)
            if y is None or abs(y - ground_y) > 0.6:
                continue
            if any(obstacle_distance(g, x, z) < 2.5 for g in obstacle_boxes):
                continue
            n = sum(
                1
                for g in obstacle_boxes
                if T.BAND_INSIDE[0] * radius <= obstacle_distance(g, x, z) <= T.BAND_AT[1] * radius
            )
            if n > best:
                best, spot = n, (x, z)
        if spot:
            return spot
    raise RuntimeError(f"no walkable spot for a {radius}-stud floor at {st['id']}")


VIEWS = {"fwd": 0.0, "side": math.pi / 2, "back": math.pi}


def camera_for(root, yaw):
    cam = scene.camera
    pitch = math.radians(T.CAMERA_PITCH)
    look = Vector((math.sin(yaw) * math.cos(pitch), -math.sin(pitch), math.cos(yaw) * math.cos(pitch)))
    focus = Vector((root[0], root[1] + T.FOCUS, root[2]))
    want = focus - look * data["camera"]["zoom"]
    # Roblox pops the camera in front of whatever is between it and the focus
    f_b, w_b = conv(focus), conv(want)
    hit, loc, _ob = ray(f_b, w_b - f_b, (w_b - f_b).length)
    pos_b = loc + (f_b - loc).normalized() * 0.5 if hit else w_b
    cam.location = pos_b
    cam.rotation_euler = conv(look).to_track_quat("-Z", "Y").to_euler()
    return pos_b


cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.sensor_fit = "VERTICAL"
cam.data.angle = math.radians(data["camera"]["fov"])
cam.data.clip_start = 0.1
cam.data.clip_end = 3000
scene.collection.objects.link(cam)
scene.camera = cam


def apply_sky(sky):
    amb = lin(sky["ambient"])
    outdoor = lin(sky["outdoor"])
    AMBIENT.nodes["value"].outputs[0].default_value = (*amb, 1)
    w = scene.world.node_tree.nodes
    w["light"].inputs["Color"].default_value = (*[max(o - a, 0) for o, a in zip(outdoor, amb)], 1)
    w["light"].inputs["Strength"].default_value = 1
    air = lin(sky["atmosphere"]["color"])
    w["seen"].inputs["Color"].default_value = (*[c * 0.3 for c in air], 1)  # the night sky seen: dark air
    clock = sky["clock"] % 24
    night = clock < 6 or clock > 18
    # the sun/moon's height through the day: the moon opposite the sun
    elev = math.sin((clock - 6) / 12 * math.pi) if not night else math.sin(((clock + 6) % 24 - 6) / 12 * math.pi)
    elev = max(elev, 0.15)
    moon.rotation_euler = (-Vector((0.4, 0.6, elev))).normalized().to_track_quat("-Z", "Y").to_euler()
    moon.data.color = lin(sky["shiftTop"])
    moon.data.energy = sky["brightness"] * (T.MOON_SHARE if night else 1.0) * math.pi


def override(name, socket):
    """An unlit material writing an object's index or a surface's position as its colour."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    if socket == "index":
        src = nt.nodes.new("ShaderNodeObjectInfo").outputs["Object Index"]
    else:
        src = nt.nodes.new("ShaderNodeNewGeometry").outputs["Position"]
    nt.links.new(src, em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return mat


ID_MAT, POS_MAT = override("id", "index"), override("pos", "position")


def render_shot(path):
    """The lit frame, then the index and position passes (1 sample, no filter, no sky)."""
    layer = bpy.context.view_layer
    scene.render.filepath = path + ".exr"
    bpy.ops.render.render(write_still=True)
    samples, filt, denoise = scene.cycles.samples, scene.cycles.filter_width, scene.cycles.use_denoising
    scene.cycles.samples, scene.cycles.filter_width, scene.cycles.use_denoising = 1, 0.01, False
    scene.render.film_transparent = True
    for mat, suffix in ((ID_MAT, "_id"), (POS_MAT, "_pos")):
        layer.material_override = mat
        scene.render.filepath = path + suffix + ".exr"
        bpy.ops.render.render(write_still=True)
    layer.material_override = None
    scene.render.film_transparent = False
    scene.cycles.samples, scene.cycles.filter_width, scene.cycles.use_denoising = samples, filt, denoise


# --- the shot list ----------------------------------------------------------------------
R0 = data["visibility"]["radius"]
SWEEP_LOW = [r for r in data["radii"] if r < R0]
SWEEP_HIGH = [r for r in data["radii"] if r > R0]
BRIGHT = max(data["lanterns"], key=lambda l: sum(v * w for v, w in zip(lin(l["light"]), (0.2126, 0.7152, 0.0722))) * l["glow"])
DARK = min(data["lanterns"], key=lambda l: sum(v * w for v, w in zip(lin(l["light"]), (0.2126, 0.7152, 0.0722))) * l["glow"])
STD = next(l for l in data["lanterns"] if l["id"] == "lantern_brakeman")
STATES = {
    "calm": {"chase": False, "own": STD, "crew": STD},
    "chase": {"chase": True, "own": STD, "crew": STD},
    "worst": {"chase": True, "own": DARK, "crew": DARK},  # chase dark + the darkest cosmetic
    "bright": {"chase": False, "own": BRIGHT, "crew": BRIGHT},  # mood ceiling's worst case
}
shots = []
for state in ("calm", "chase", "worst"):
    for crew in (1, 4):
        for view in VIEWS:
            shots.append((f"r{R0}_{state}_c{crew}_{view}", R0, state, crew, view))
# (no sweep below the floor: the slider's minimum comes from reaction distance, thresholds.py)
for r in [R0] + SWEEP_HIGH:
    for view in VIEWS:
        shots.append((f"r{r}_bright_c4_{view}", r, "bright", 4, view))
if REACH != 1:
    shots = [(f"x{REACH:g}_{s[0]}", *s[1:]) for s in shots if s[2] in ("worst", "bright") and s[1] == R0]
if PERF:  # the Performance tier: the gate matrix only (the mood sweep is Quality's)
    shots = [(s[0] + "_perf", *s[1:]) for s in shots if s[2] != "bright" or s[1] == R0]
if SMOOTH:
    shots = [("f2_" + s[0], *s[1:]) for s in shots if s[2] != "bright" or s[1] == R0]
if CEILING:
    shots = [("ceil_" + s[0], *s[1:]) for s in shots if s[2] in ("calm", "chase")]
if ONLY:
    shots = [s for s in shots if s[0].startswith(ONLY)]

spots = {}
for name, radius, state, crew, view in shots:
    if os.path.exists(os.path.join(OUT, name + ".json")) and "--fresh" not in argv:
        continue  # already rendered (pass --fresh to redo)
    s = STATES[state]
    sky = st["skies"][str(radius)]["chase" if s["chase"] else "calm"]
    apply_sky(sky)
    ch = data["visibility"]["chase"]
    for ob in station_lights:
        set_light(
            ob,
            brightness=ob["brightness"] * (ch["LightBrightness"] if s["chase"] else 1),
            rng=ob["range"] * (ch["LightRange"] if s["chase"] else 1),
        )
    clear_people()  # before any ray: the last shot's bodies must not be stood on
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    if radius not in spots:
        spots[radius] = choose_spot(radius)
    x, z = spots[radius]
    root = [x, ground_at(x, z) + 3, z]
    yaw = VIEWS[view]
    info = {"shot": name, "station": st["id"], "label": st["label"], "radius": radius, "state": state,
            "crew": [], "view": view, "root": root, "yaw": yaw, "sky": sky, "lantern": s["own"]["id"],
            "reach": REACH, "tier": "perf" if PERF else "quality", "falloff": "smooth" if SMOOTH else "linear"}
    # the camera and the crew's spots are found against the station alone (no bodies yet)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    cam_at = camera_for(root, yaw)
    spots_crew = []
    if crew > 1:
        for k, (dist, bearing) in enumerate(zip(T.CREW_DISTANCES, (-0.30, 0.18, 0.05))):
            placed = None
            for tries in range(12):
                b = yaw + bearing + (tries // 2) * 0.08 * (1 if tries % 2 else -1)
                cx, cz = root[0] + math.sin(b) * dist, root[2] + math.cos(b) * dist
                gy = ground_at(cx, cz)
                if gy is None or abs(gy - ground_y) > 1.5:
                    continue
                lens = conv((cx, gy + T.LENS_HEIGHT, cz))
                hit, loc, _ = ray(cam_at, lens - cam_at, (lens - cam_at).length - 0.6)
                if not hit:
                    placed = (cx, gy + 3, cz)
                    break
            if placed:
                spots_crew.append((dist, placed))
    info["you"] = place_person(0, root, yaw, s["own"], radius, s["chase"], cone=True)
    for k, (dist, placed) in enumerate(spots_crew):
        p = place_person(k + 1, list(placed), yaw + math.pi, s["crew"], radius, s["chase"], cone=False)
        p["distance"] = dist
        info["crew"].append(p)
    # the stand-in (report only): ahead at the floor's distance, on the platform, crew of 1
    if crew == 1 and view == "fwd":
        for share in (1.0, 0.95, 1.05, 0.9):
            sx, sz = root[0] + 2.0, root[2] + radius * share
            gy = ground_at(sx, sz)
            if gy is not None and abs(gy - ground_y) < 1.5:
                place_standin([sx, gy + 4, sz], yaw + math.pi)
                info["standin"] = {"id": STANDIN_ID, "distance": radius * share}
                break
    info["camera"] = list(cam_at)
    # must-see targets: tools/visibility/classify.py's Tier A parts (each judged near its
    # lip) and Tier B models, by index
    info["targets"] = {
        str(group_ids[g]): {"kind": "obstacle", "tier": "B", "name": g.split("#")[0], "family": fam}
        for g, fam in TIERS["B"].items() if g in group_ids
    }
    for i, idx in hazard_ids.items():
        a = TIERS["A"][i]
        info["targets"][str(idx)] = {"kind": a["kind"], "tier": "A", "name": a["family"], "family": a["family"],
                                     "lips": a["lips"], "lip": LIP}
    info["rims"] = sorted(
        (
            (math.dist(st["groups"][g]["pivot"], root), group_ids[g])
            for g in st["groups"]
            if st["groups"][g].get("rim") and st["groups"][g].get("pivot")
        )
    )[: data["visibility"]["rim"]["Max"]]
    info["rims"] = [i for d, i in info["rims"] if d <= data["visibility"]["rim"]["Range"]]
    if PERF:
        info["rims"] = info["rims"][: data["visibility"]["rim"]["MaxPerformance"]]
    render_shot(os.path.join(OUT, name))
    with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as fh:
        json.dump(info, fh)
    print("SHOT", st["label"], name, flush=True)
