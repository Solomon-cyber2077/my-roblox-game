"""
The Settings "lantern" slider, mocked up before it is built from GuiObjects:

    blender -b --factory-startup --python tools/visibility/slider_mockup.py -- <out.png>

A Victorian duplex lamp's wick winder (Hinks' 1865 duplex burner: a knurled brass thumbwheel
on a spindle through the burner's gallery, oldcopper.org) laid flat as a slider: a pierced
brass gallery strip is the track, the knurled winder is the thumb, and a flame engraved in
the plate grows from "Dread" to "Clear" with a notch at "Steady". Every shape here maps to
a native UI object: the plate and slot are Frames with UICorner/UIStroke and a UIGradient,
the knurls are thin Frames, the flame is a Frame pair with UIGradients.
Rendered at 0.5 scale (480 x 160).
"""

import math
import sys

import bpy

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.render.resolution_x, scene.render.resolution_y = 480, 160
scene.view_settings.view_transform = "AgX"


def mat(name, color, metal=0.0, rough=0.5, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


BRASS = mat("brass", (0.78, 0.55, 0.22), 1.0, 0.32)
DARK = mat("tarnish", (0.30, 0.20, 0.08), 1.0, 0.55)
LEATHER = mat("leather", (0.10, 0.02, 0.02), 0.0, 0.7)
INK = mat("ink", (0.02, 0.015, 0.01), 0.0, 0.9)
FLAME = mat("flame", (1.0, 0.55, 0.15), 0.0, 0.5, emit=6)


def box(size, at, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    ob = bpy.context.active_object
    ob.scale = size
    ob.data.materials.append(material)
    if bevel:
        mod = ob.modifiers.new("b", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    return ob


box((12, 0.2, 4.2), (0, 0.3, 0), LEATHER)  # the Settings row's oxblood leather
box((10, 0.2, 2.2), (0, 0.1, 0.2), BRASS, bevel=0.12)  # the gallery plate
box((8.4, 0.25, 0.32), (0, 0.0, 0.2), INK, bevel=0.05)  # the wick slot
for i in range(15):  # the gallery's piercings along the slot
    x = -4.2 + i * 0.6
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.3, location=(x, 0.0, -0.45), rotation=(math.pi / 2, 0, 0))
    bpy.context.active_object.data.materials.append(INK)
# notch at Steady (the default) and the two ends
for x, h in ((-4.2, 0.5), (-1.4, 0.8), (4.2, 0.5)):
    box((0.07, 0.3, h), (x, 0.0, 0.85), INK)
# the engraved flame: small at Dread, tall at Clear
for i in range(9):
    x = -3.9 + i * 0.98
    hgt = 0.12 + 0.07 * i
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=(x, -0.02, 0.95 + hgt / 2))
    f = bpy.context.active_object
    f.scale = (0.05 + 0.006 * i, 0.02, hgt / 2)
    f.data.materials.append(FLAME if i <= 3 else DARK)
# the winder: a knurled thumbwheel at Steady
knob_x = -1.4
bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.62, depth=0.5, location=(knob_x, -0.35, 0.2), rotation=(math.pi / 2, 0, 0))
bpy.context.active_object.data.materials.append(BRASS)
for k in range(24):
    a = 2 * math.pi * k / 24
    bpy.ops.mesh.primitive_cube_add(size=1, location=(knob_x + 0.62 * math.cos(a), -0.35, 0.2 + 0.62 * math.sin(a)), rotation=(0, -a, 0))
    ob = bpy.context.active_object
    ob.scale = (0.06, 0.52, 0.06)
    ob.data.materials.append(DARK)
bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.22, depth=0.2, location=(knob_x, -0.62, 0.2), rotation=(math.pi / 2, 0, 0))
bpy.context.active_object.data.materials.append(DARK)
# labels
for text, x in (("Dread", -4.6), ("Steady", -1.9), ("Clear", 3.7)):
    bpy.ops.object.text_add(location=(x, -0.05, -1.35), rotation=(math.pi / 2, 0, 0))
    t = bpy.context.active_object
    t.data.body = text
    t.data.size = 0.5
    t.data.materials.append(BRASS)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 12
cam.location = (0, -20, 0)
cam.rotation_euler = (math.pi / 2, 0, 0)
scene.collection.objects.link(cam)
scene.camera = cam
light = bpy.data.objects.new("key", bpy.data.lights.new("key", "AREA"))
light.data.energy = 900
light.data.size = 8
light.location = (-4, -10, 6)
light.rotation_euler = (math.radians(60), 0, math.radians(-20))
scene.collection.objects.link(light)
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.025, 1)
scene.world = world
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
