"""Blender render for the phone bag button's icon (Theme.Image.bagIcon, UI/ToolBelt): a railway conductor's money bag,
after the antique ones: a rounded pouch of dark, worn leather on a metal frame with a kiss-lock clasp and a strap.
Three-quarter view, Cycles, transparent film, 512 px (downsampled to 256 by the caller).

    blender -b --python tools/uiart/render_bag.py -- <out_dir>
"""

import math
import os
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1:][0]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def link(ob):
    scene.collection.objects.link(ob)
    return ob


def leather_material():
    mat = bpy.data.materials.new("Leather")
    mat.use_nodes = True
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    b = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    geo = N.new("ShaderNodeNewGeometry")
    tone = N.new("ShaderNodeTexNoise")
    tone.inputs["Scale"].default_value = 3.5
    tone.inputs["Detail"].default_value = 6
    L.new(tc.outputs["Object"], tone.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.016, 0.010, 0.007, 1)
    ramp.color_ramp.elements[1].color = (0.055, 0.032, 0.018, 1)
    L.new(tone.outputs["Fac"], ramp.inputs[0])
    # rubbed edges and creases lighter, the way handled leather wears
    wear = N.new("ShaderNodeValToRGB")
    wear.color_ramp.elements[0].position = 0.5
    wear.color_ramp.elements[1].position = 0.6
    L.new(geo.outputs["Pointiness"], wear.inputs[0])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L.new(wear.outputs[0], mix.inputs["Factor"])
    L.new(ramp.outputs[0], mix.inputs[6])
    mix.inputs[7].default_value = (0.16, 0.10, 0.06, 1)
    L.new(mix.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.82
    b.inputs["Coat Weight"].default_value = 0.0
    grain = N.new("ShaderNodeTexVoronoi")
    grain.inputs["Scale"].default_value = 90
    L.new(tc.outputs["Object"], grain.inputs["Vector"])
    crease = N.new("ShaderNodeTexWave")
    crease.inputs["Scale"].default_value = 3
    crease.inputs["Distortion"].default_value = 12
    L.new(tc.outputs["Object"], crease.inputs["Vector"])
    add = N.new("ShaderNodeMath")
    add.operation = "ADD"
    L.new(grain.outputs["Distance"], add.inputs[0])
    L.new(crease.outputs["Fac"], add.inputs[1])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.7
    L.new(add.outputs[0], bump.inputs["Height"])
    L.new(bump.outputs[0], b.inputs["Normal"])
    return mat


def metal_material():
    mat = bpy.data.materials.new("Nickel")
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.55, 0.50, 0.42, 1)
    b.inputs["Metallic"].default_value = 1
    b.inputs["Roughness"].default_value = 0.3
    return mat


leather = leather_material()
metal = metal_material()

# the pouch: a squashed sphere, flatter front to back, its top cut flat by the frame
bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1, location=(0, 0, 0))
pouch = bpy.context.active_object
pouch.scale = (1.0, 0.32, 0.8)
bpy.ops.object.transform_apply(scale=True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
for v in pouch.data.vertices:
    if v.co.z > 0.42:
        v.co.z = 0.42 + (v.co.z - 0.42) * 0.15  # the mouth is gathered flat under the frame
    elif v.co.z < -0.2:
        v.co.x *= 1.0 + (-0.2 - v.co.z) * 0.12  # soft leather sags wider at the bottom
pouch.modifiers.new("sub", "SUBSURF").levels = 1
pouch.data.materials.append(leather)
bpy.ops.object.shade_smooth()

# the frame: a curved metal bar along the mouth, both halves, and the kiss-lock balls
for side in (-1, 1):
    curve = bpy.data.curves.new("frame", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.035
    curve.bevel_resolution = 4
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(2)
    pts = [(-0.92, side * 0.10, 0.36), (0, side * 0.13, 0.52), (0.92, side * 0.10, 0.36)]
    for bp, co in zip(spline.bezier_points, pts):
        bp.co = co
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    ob = link(bpy.data.objects.new("frame", curve))
    ob.data.materials.append(metal)
for side in (-1, 1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.07, location=(side * 0.06, 0.0, 0.6))
    bpy.context.active_object.data.materials.append(metal)
    bpy.ops.object.shade_smooth()

# the strap: one flat leather band from one end of the frame, over the top, to the other
curve = bpy.data.curves.new("strap", "CURVE")
curve.dimensions = "3D"
spline = curve.splines.new("BEZIER")
spline.bezier_points.add(2)
for bp, co in zip(spline.bezier_points, [(-0.9, 0, 0.38), (0, -0.04, 1.55), (0.9, 0, 0.38)]):
    bp.co = co
    bp.handle_left_type = bp.handle_right_type = "AUTO"
strap = link(bpy.data.objects.new("strap", curve))
bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, -5))
profile = bpy.context.active_object
profile.scale = (0.07, 0.014, 1)
profile.hide_render = True
curve.bevel_mode = "OBJECT"
curve.bevel_object = profile
strap.data.materials.append(leather)

# a stitched seam round the pouch's edge and a small brass plate on the front
thread = bpy.data.materials.new("Thread")
thread.use_nodes = True
thread.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.10, 0.08, 0.05, 1)
seam = bpy.data.curves.new("seam", "CURVE")
seam.dimensions = "3D"
seam.bevel_depth = 0.012
sp = seam.splines.new("POLY")
pts = []
for i in range(41):
    a = math.radians(-10 - 160 * i / 40)
    pts.append((0.985 * math.cos(a), 0.0, 0.79 * math.sin(a)))
sp.points.add(len(pts) - 1)
for p_, co in zip(sp.points, pts):
    p_.co = (*co, 1)
seam_ob = link(bpy.data.objects.new("seam", seam))
seam_ob.data.materials.append(thread)
brass = bpy.data.materials.new("Brass")
brass.use_nodes = True
bb = brass.node_tree.nodes["Principled BSDF"]
bb.inputs["Base Color"].default_value = (0.62, 0.42, 0.14, 1)
bb.inputs["Metallic"].default_value = 1
bb.inputs["Roughness"].default_value = 0.35
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.335, -0.05))
plate = bpy.context.active_object
plate.scale = (0.32, 0.02, 0.13)
plate.rotation_euler.x = math.radians(-8)
bev = plate.modifiers.new("b", "BEVEL")
bev.width, bev.segments = 0.01, 2
plate.data.materials.append(brass)

root = bpy.data.objects.new("root", None)
link(root)
for ob in list(scene.objects):
    if ob is not root and ob.parent is None and ob.type in ("MESH", "CURVE"):
        ob.parent = root
root.rotation_euler = (math.radians(8), 0, math.radians(-24))


def area(loc, energy, color, size):
    ld = bpy.data.lights.new("l", "AREA")
    ld.energy, ld.color, ld.size = energy, color, size
    ob = link(bpy.data.objects.new("l", ld))
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


area((-3.0, -3.2, 3.0), 380, (1.0, 0.84, 0.64), 3.5)  # lantern-warm key, soft
area((3.2, 2.0, 1.6), 260, (0.62, 0.74, 1.0), 1.5)  # cool rim
area((0.5, -4.0, -0.5), 60, (1.0, 0.9, 0.8), 3.0)
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.10, 0.08, 0.06, 1)

cam_d = bpy.data.cameras.new("cam")
cam_d.lens = 60
cam = link(bpy.data.objects.new("cam", cam_d))
cam.location = (0, -6.3, 1.6)
cam.rotation_euler = (math.radians(78), 0, 0)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Punchy"
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.filepath = os.path.join(OUT, "bag_icon.png")
bpy.ops.render.render(write_still=True)
print("BAG_DONE", scene.render.filepath)
