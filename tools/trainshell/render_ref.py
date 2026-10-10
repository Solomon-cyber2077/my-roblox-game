"""
Orthographic elevations of a stretch of the train from the measured dump:

  blender -b --factory-startup -P tools/trainshell/render_ref.py -- dump.json out_prefix x0 x1 [blend files to append...]

Writes <prefix>_side.png (platform side, +Z), _far.png, _end.png and _top.png. Extra .blend
files have their objects appended (to see a shell over the reference).
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import refload  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1 :]
dump, prefix, x0, x1 = args[0], args[1], float(args[2]), float(args[3])
extra = args[4:]

bpy.ops.wm.read_factory_settings(use_empty=True)
if not os.environ.get("NOREF"):
    refload.load(dump, (x0 - 3, x1 + 3))
for path in extra:
    with bpy.data.libraries.load(path) as (src, dst):
        dst.objects = [n for n in src.objects]
    for ob in dst.objects:
        if ob and ob.type == "MESH":
            bpy.context.scene.collection.objects.link(ob)

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "OBJECT"
scene.display.shading.show_cavity = True
scene.display.shading.show_object_outline = True
world = bpy.data.worlds.new("W")
scene.world = world
cx = (x0 + x1) / 2
cam_data = bpy.data.cameras.new("Cam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def shot(name, loc, rot, scale, w, h):
    cam.location = loc
    cam.rotation_euler = rot
    cam_data.ortho_scale = scale
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.filepath = f"{prefix}_{name}.png"
    bpy.ops.render.render(write_still=True)


L = x1 - x0 + 6
# platform side (+Z in Roblox is -Y in Blender): camera at -Y looking +Y
shot("side", (cx, -60, 3), (math.pi / 2, 0, 0), L, 1200, int(1200 * 18 / L))
shot("far", (cx, 60, 3), (math.pi / 2, 0, math.pi), L, 1200, int(1200 * 18 / L))
shot("end", (x0 - 40, 0, 3), (math.pi / 2, 0, -math.pi / 2), 18, 600, 600)
shot("top", (cx, 0, 60), (0, 0, 0), L, 1200, int(1200 * 16 / L))
