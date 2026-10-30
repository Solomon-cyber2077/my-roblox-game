"""Blender render for the hunted cue (Theme.Image.huntedEyes, UI/HuntedCue): the Stalker's face in the dark,
as HollowBuilder makes it: no eyes, two sunken sockets with a pinprick of warm-white shine deep in each
(SHINE 236, 226, 170), a gaunt brow catching a little cold light. Rendered on black, then turned into a
glowing sprite by the caller: a soft halo from the bright pinpricks, alpha from brightness, 256 px.

    blender -b --python tools/uiart/render_hunted_eyes.py -- <out_dir>
"""

import math
import os
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1:][0]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def material(name, color, rough=0.6, emit=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return mat


def srgb(r, g, b):
    return tuple(((c / 255) ** 2.2) for c in (r, g, b))


skin = material("Skin", srgb(40, 38, 42), 0.85)  # dry, matte: only a suggestion of a face
ichor = material("Socket", srgb(18, 12, 14), 0.9)
shine = material("Shine", srgb(236, 226, 170), 0.3, srgb(236, 226, 170), 40.0)

# the head: a gaunt, too-long skull, seen from the front
bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1, location=(0, 0, 0))
head = bpy.context.active_object
head.scale = (0.78, 0.82, 1.05)
head.data.materials.append(skin)
bpy.ops.object.shade_smooth()

for side in (-1, 1):
    x = side * 0.27
    # the socket: a dark hollow pressed into the face
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1, location=(x, -0.74, 0.16))
    socket = bpy.context.active_object
    socket.scale = (0.17, 0.06, 0.13)
    socket.data.materials.append(ichor)
    bpy.ops.object.shade_smooth()
    # the pinprick, deep inside and a little off-centre, as if it is looking at you
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.034, location=(x + side * 0.015, -0.79, 0.15))
    bpy.context.active_object.data.materials.append(shine)

# light: one cold glance from above, so only the brow and the sockets' rims show
def area(loc, energy, color, size):
    ld = bpy.data.lights.new("l", "AREA")
    ld.energy, ld.color, ld.size = energy, color, size
    ob = bpy.data.objects.new("l", ld)
    scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


# a faint cold light grazing down from above: the brow and cheekbones, nothing more
area((0, -0.9, 3.2), 18, (0.7, 0.8, 1.0), 0.8)
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)

cam_d = bpy.data.cameras.new("cam")
cam_d.lens = 85
cam = bpy.data.objects.new("cam", cam_d)
scene.collection.objects.link(cam)
cam.location = (0, -3.4, 0.12)  # in close: the eyes fill the mark
cam.rotation_euler = (math.radians(90), 0, 0)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 128
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Base Contrast"
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"

scene.render.filepath = os.path.join(OUT, "hunted_eyes_black.png")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "hunted_eyes.blend"))
bpy.ops.render.render(write_still=True)
print("EYES_DONE", scene.render.filepath)
