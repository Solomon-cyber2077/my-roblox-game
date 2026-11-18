"""Renders the painted hall tiles in a stand-in of the depot hall, for the look gate.

  blender --background --python tools/lobby-tiles/render.py -- <maps_dir> <out_dir>

Roblox will not show a MaterialVariant's maps in a play test until they are uploaded, so this is the
preview of the painted look before upload. Hall coordinates are Roblox studs (x, y up, z) mapped to
Blender (x, -z, y). The two cameras match the Studio shots: the walk from the east, the back-wall dado.
The surrounding floor, brick and plinth are rough stand-ins; only the tiles are the real maps.
"""

import json
import math
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
MAPS = argv[0] if argv else os.path.join(os.path.dirname(__file__), "out")
OUT = argv[1] if len(argv) > 1 else MAPS

# part tints as Logic/LobbyTiles makes them: old colour (Builders/LobbyBuilder) * 255 / map mean
with open(os.path.join(MAPS, "means.json")) as f:
    MEANS = json.load(f)
QUARRY_TINT = tuple(min(255, round(c * 255 / m)) for c, m in zip((84, 38, 34), MEANS["quarry"]))
DADO_TINT = tuple(min(255, round(c * 255 / m)) for c, m in zip((28, 68, 54), MEANS["dado"]))


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rb(x, y, z):
    return (x, -z, y)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1620, 694
scene.render.resolution_percentage = 50
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.04, 0.032, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0


def image(name, non_color=False):
    img = bpy.data.images.load(os.path.join(MAPS, name + ".png"))
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def tiled_material(name, key, tint, studs, axes):
    """A Principled material on the painted maps, box-mapped in object space at `studs` per repeat.
    axes picks which two object axes carry the texture (U, V)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    n, ln = nt.nodes, nt.links
    bsdf = n["Principled BSDF"]
    coord = n.new("ShaderNodeTexCoord")
    sep = n.new("ShaderNodeSeparateXYZ")
    ln.new(coord.outputs["Object"], sep.inputs[0])
    comb = n.new("ShaderNodeCombineXYZ")
    for i, ax in enumerate(axes):
        div = n.new("ShaderNodeMath")
        div.operation = "DIVIDE"
        div.inputs[1].default_value = studs
        ln.new(sep.outputs[ax], div.inputs[0])
        ln.new(div.outputs[0], comb.inputs[i])
    col = n.new("ShaderNodeTexImage")
    col.image = image(key + "_color")
    rough = n.new("ShaderNodeTexImage")
    rough.image = image(key + "_roughness", True)
    nrm = n.new("ShaderNodeTexImage")
    nrm.image = image(key + "_normal", True)
    for t in (col, rough, nrm):
        ln.new(comb.outputs[0], t.inputs[0])
    mul = n.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    ln.new(col.outputs[0], mul.inputs["A"])
    mul.inputs["B"].default_value = (lin(tint[0]), lin(tint[1]), lin(tint[2]), 1)
    nmap = n.new("ShaderNodeNormalMap")
    ln.new(nrm.outputs[0], nmap.inputs["Color"])
    ln.new(rough.outputs[0], bsdf.inputs["Roughness"])
    ln.new(nmap.outputs[0], bsdf.inputs["Normal"])
    return m, n, ln, mul, bsdf, sep


def plain(name, rgb, rough, scale=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n, ln = m.node_tree.nodes, m.node_tree.links
    bsdf = n["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    base = (lin(rgb[0]), lin(rgb[1]), lin(rgb[2]), 1)
    if scale:
        tex = n.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = scale
        ramp = n.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = tuple(v * 0.7 for v in base[:3]) + (1,)
        ramp.color_ramp.elements[1].color = tuple(min(1, v * 1.25) for v in base[:3]) + (1,)
        ln.new(tex.outputs[0], ramp.inputs[0])
        ln.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = base
    return m


def brick(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n, ln = m.node_tree.nodes, m.node_tree.links
    bsdf = n["Principled BSDF"]
    b = n.new("ShaderNodeTexBrick")
    coord = n.new("ShaderNodeTexCoord")
    # walls stand in the x-z or y-z plane: lay the courses along (x + y) and up z
    sep = n.new("ShaderNodeSeparateXYZ")
    ln.new(coord.outputs["Object"], sep.inputs[0])
    run = n.new("ShaderNodeMath")
    ln.new(sep.outputs[0], run.inputs[0])
    ln.new(sep.outputs[1], run.inputs[1])
    comb = n.new("ShaderNodeCombineXYZ")
    ln.new(run.outputs[0], comb.inputs[0])
    ln.new(sep.outputs[2], comb.inputs[1])
    ln.new(comb.outputs[0], b.inputs["Vector"])
    b.inputs["Scale"].default_value = 0.35
    b.inputs["Color1"].default_value = (lin(96), lin(42), lin(30), 1)
    b.inputs["Color2"].default_value = (lin(80), lin(34), lin(26), 1)
    b.inputs["Mortar"].default_value = (lin(70), lin(58), lin(48), 1)
    b.inputs["Mortar Size"].default_value = 0.015
    ln.new(b.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return m


def box(name, size, centre, mat):
    """size and centre in Roblox studs."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=rb(*centre))
    o = bpy.context.object
    o.name = name
    o.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    return o


# -- the hall stand-in (hall space: walk z 20..28, back wall inner face z 72) -------------------------
quarry, qn, qln, qmul, qbsdf, qsep = tiled_material("Quarry", "quarry", QUARRY_TINT, 6, (0, 1))
# the worn path: a texture across the walk's 8 studs, 16 studs along, alpha-mixed over the tiles
path = qn.new("ShaderNodeTexImage")
path.image = image("path_color")
pu = qn.new("ShaderNodeMath")
pu.operation = "DIVIDE"
pu.inputs[1].default_value = 16
qln.new(qsep.outputs[0], pu.inputs[0])
pv = qn.new("ShaderNodeMath")
pv.operation = "MULTIPLY_ADD"
pv.inputs[1].default_value = -1 / 8  # object y = -z; the walk's centre line is at object 0
pv.inputs[2].default_value = 0.5
qln.new(qsep.outputs[1], pv.inputs[0])
pc = qn.new("ShaderNodeCombineXYZ")
qln.new(pu.outputs[0], pc.inputs[0])
qln.new(pv.outputs[0], pc.inputs[1])
qln.new(pc.outputs[0], path.inputs[0])
over = qn.new("ShaderNodeMix")
over.data_type = "RGBA"
qln.new(path.outputs["Alpha"], over.inputs["Factor"])
qln.new(qmul.outputs["Result"], over.inputs["A"])
qln.new(path.outputs["Color"], over.inputs["B"])
qln.new(over.outputs["Result"], qbsdf.inputs["Base Color"])

dado, *_ = tiled_material("Dado", "dado", DADO_TINT, 4, (0, 2))
dado_end, *_ = tiled_material("DadoEnd", "dado", DADO_TINT, 4, (1, 2))
# the dado's base colour tint goes through the multiply node already; link it to the BSDF
for m in (dado, dado_end):
    n = m.node_tree.nodes
    mix = [x for x in n if x.bl_idname == "ShaderNodeMix"][0]
    m.node_tree.links.new(mix.outputs["Result"], n["Principled BSDF"].inputs["Base Color"])

flags = plain("Flags", (92, 84, 74), 0.8, scale=0.4)
slate = plain("Slate", (46, 44, 42), 0.75, scale=1.5)
plinth = plain("Plinth", (110, 100, 86), 0.85, scale=2)
bricks = brick("Brick")

box("Floor", (240, 1, 110), (0, -0.52, 25), flags)
box("Walk", (218, 1, 8), (0, -0.5, 24), quarry)
box("BackWall", (240, 30, 1), (0, 14, 72.6), bricks)
box("Plinth", (240, 1.2, 0.6), (0, 0.6, 71.7), plinth)
box("Dado", (240, 4, 0.15), (0, 3.2, 71.905), dado)
box("EndWall", (1, 30, 110), (112.6, 14, 20), bricks)
box("EndDado", (0.15, 4, 92.8), (111.905, 3.2, 25.4), dado_end)

for x, z, e in ((40, 24, 9000), (0, 24, 9000), (-40, 24, 9000), (24, 62, 6000), (60, 62, 5000), (4, 62, 5000)):
    bpy.ops.object.light_add(type="POINT", location=rb(x, 13, z))
    lamp = bpy.context.object
    lamp.data.energy = e
    lamp.data.color = (1.0, 0.72, 0.42)
    lamp.data.shadow_soft_size = 0.6


def shoot(name, eye, at):
    cam = bpy.data.cameras.new(name)
    cam.sensor_fit = "VERTICAL"
    cam.angle = math.radians(60)
    o = bpy.data.objects.new(name, cam)
    scene.collection.objects.link(o)
    o.location = rb(*eye)
    tgt = bpy.data.objects.new(name + "Target", None)
    scene.collection.objects.link(tgt)
    tgt.location = rb(*at)
    c = o.constraints.new("TRACK_TO")
    c.target = tgt
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"
    scene.camera = o
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


os.makedirs(OUT, exist_ok=True)
shoot("painted_walk", (62, 5, 17), (30, 0.5, 24))
shoot("painted_dado", (32, 5, 58), (16, 3, 72))
shoot("painted_walk_close", (14, 3.2, 21), (6, 0, 25))
shoot("painted_dado_close", (20, 3.5, 69), (17, 3, 72))
