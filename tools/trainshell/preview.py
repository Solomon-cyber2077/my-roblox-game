"""
Renders a baked car the way Roblox will show it: each MeshPart's livery colour under the colour
map's alpha (SurfaceAppearance Overlay), with the normal, roughness and metalness maps.

  blender -b <atlas>_baked.blend -P tools/trainshell/preview.py -- <maps_dir> <atlas> <out.png> [view] [kit_baked.blend kit_atlas]

view: three_quarter (default), side, far, roof, low. Night: a cold moon and warm lamps.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1 :]
MAPS, ATLAS, OUT = args[0], args[1], args[2]
VIEW = args[3] if len(args) > 3 else "three_quarter"

LIVERY = {"Body": (96, 30, 26), "Trim": (150, 120, 74), "Roof": (34, 33, 34), "Accent": (38, 70, 58), "": (255, 255, 255)}


def srgb(c):
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    return (f(c[0]), f(c[1]), f(c[2]), 1)


KITDIR = os.path.dirname(args[4]) if len(args) > 5 else MAPS


def load(name, colorspace):
    path = os.path.join(MAPS, f"{name}.png")
    if not os.path.exists(path):
        path = os.path.join(KITDIR, f"{name}.png")
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = colorspace
    return img


def dress(ob, atlas):
    role = ob.get("role", "")
    if ob.get("material") == "Lamp":
        mat = bpy.data.materials.new("lamp")
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Emission Color"].default_value = srgb((255, 196, 120))
        bsdf.inputs["Emission Strength"].default_value = 12
        if ob.name.endswith("_Glow"):
            bsdf.inputs["Emission Strength"].default_value = 4
        if ob.name.endswith("_Haze"):
            # the warm veil: mostly see-through (Neon at Transparency ~0.85 in Roblox)
            bsdf.inputs["Emission Strength"].default_value = 0.6
            bsdf.inputs["Alpha"].default_value = 0.15
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        return
    if ob.get("material") == "Sign":
        mat = bpy.data.materials.new("sign")
        mat.use_nodes = True
        nt = mat.node_tree
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = load(f"{ATLAS}_sign", "sRGB")
        nt.links.new(t.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
        nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.4
        if os.path.exists(os.path.join(MAPS, f"{ATLAS}_signnormal.png")):
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = load(f"{ATLAS}_signnormal", "Non-Color")
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(n.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], nt.nodes["Principled BSDF"].inputs["Normal"])
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        return
    mat = bpy.data.materials.new(f"pv_{ob.name}")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    col = nodes.new("ShaderNodeTexImage")
    col.image = load(f"{atlas}_color", "sRGB")
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = srgb(LIVERY.get(role, (255, 255, 255)))
    links.new(col.outputs["Alpha"], mix.inputs["Factor"])
    links.new(col.outputs["Color"], mix.inputs["B"])
    links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    for key, inp in (("rough", "Roughness"), ("metal", "Metallic")):
        t = nodes.new("ShaderNodeTexImage")
        t.image = load(f"{atlas}_{key}", "Non-Color")
        links.new(t.outputs["Color"], bsdf.inputs[inp])
    n = nodes.new("ShaderNodeTexImage")
    n.image = load(f"{atlas}_normal", "Non-Color")
    nm = nodes.new("ShaderNodeNormalMap")
    links.new(n.outputs["Color"], nm.inputs["Color"])
    links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    ob.data.materials.clear()
    ob.data.materials.append(mat)


for ob in bpy.data.objects:
    if ob.type == "MESH" and not ob.hide_render:
        dress(ob, ob.get("atlas") or ATLAS)

if len(args) > 5:
    kit_blend, kit_atlas = args[4], args[5]
    with bpy.data.libraries.load(kit_blend) as (src, dst):
        dst.objects = list(src.objects)
    kit = {ob.name: ob for ob in dst.objects if ob and ob.type == "MESH"}
    for ob in kit.values():
        dress(ob, ob.get("atlas") or kit_atlas)
    # place them as the runtime will (train space -> Blender: x, -z, y)
    import json

    car = json.load(open(os.path.join(MAPS, f"{ATLAS}.json")))
    kmeta = {p["name"]: p for p in json.load(open(os.path.join(KITDIR, "Kit.json")))["parts"]}
    spec = car["spec"]
    x0, x1 = spec["x0"], spec["x1"]
    inset = 6.5 if x1 - x0 >= 24 else 4.5
    placed = []

    def put(name, c, rot_z90=False):
        src = kit[name]
        ob = src.copy()
        bpy.context.scene.collection.objects.link(ob)
        kc = kmeta[name]["center"]
        if rot_z90:
            # tyre: Roblox angles(0, 90, 0) turns local X onto world -Z
            ob.rotation_euler = (0, 0, math.radians(90))
        ob.location = Vector((c[0] + kc[0], -(c[2] + kc[2]), c[1] + kc[1]))
        placed.append(ob)

    for bx in (x0 + inset, x1 - inset):
        put("Bogie", (bx, -3, 0))
        for ax in (-2.1, 2.1):
            for s in (-1, 1):
                put("Wheel", (bx + ax, -3.6, s * 5.3), True)
    for s_key, xs in spec["doors"].items():
        s = 1 if int(s_key) > 0 else -1
        for d in xs:
            put("DoorLeafL", (d - 1.4, 3.75, s * 6.74))
            put("DoorLeafR", (d + 1.4, 3.75, s * 6.74))

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
world = bpy.data.worlds.new("night")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.013, 0.025, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
scene.world = world
scene.view_settings.view_transform = "AgX"
scene.view_settings.exposure = 0.6

# ground
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -5.4))

cx = sum(ob.location.x for ob in bpy.data.objects if ob.type == "MESH") / max(1, len([1 for ob in bpy.data.objects if ob.type == "MESH"]))
for ob in bpy.data.objects:
    if ob.name.endswith("_Shell"):
        cx = ob.location.x


def light(kind, loc, energy, color, size=1.0, rot=None):
    data = bpy.data.lights.new("L", kind)
    data.energy = energy
    data.color = color
    if hasattr(data, "shadow_soft_size"):
        data.shadow_soft_size = size
    ob = bpy.data.objects.new("L", data)
    ob.location = loc
    if rot:
        ob.rotation_euler = rot
    scene.collection.objects.link(ob)


light("SUN", (0, 0, 50), 0.25, (0.6, 0.7, 1.0), rot=(math.radians(50), 0, math.radians(30)))
# platform lamps (Roblox +Z side is Blender -Y)
for dx in (-8, 0, 8):
    light("POINT", (cx + dx, -14, 12), 2500, (1.0, 0.72, 0.42), 1.5)
light("POINT", (cx, 20, 10), 600, (1.0, 0.75, 0.5), 2)

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
target = Vector((cx, 0, 4))
views = {
    "three_quarter": Vector((cx + 16, -26, 7)),
    "side": Vector((cx, -30, 4.5)),
    "far": Vector((cx - 14, 26, 6)),
    "roof": Vector((cx + 14, -16, 22)),
    "low": Vector((cx + 9, -12, -2.5)),
    # the acceptance shot: on the platform 5-6 studs from the side at eye height (Roblox FOV 70)
    "platform": Vector((cx + 4.5, -12.4, 4.6)),
    "closeup": Vector((cx + 1.5, -10.6, 4.4)),
}
if VIEW in ("platform", "closeup"):
    target = Vector((cx + (3.0 if VIEW == "platform" else 3.6), 0, 4.0 if VIEW == "platform" else 4.6))
cam.location = views[VIEW]
cam_data.lens = 15 if VIEW in ("platform",) else 22 if VIEW == "closeup" else 35
cam.rotation_mode = "QUATERNION"
cam.rotation_quaternion = (target - cam.location).to_track_quat("-Z", "Y")
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
