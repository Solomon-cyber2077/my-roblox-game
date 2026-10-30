"""Blender render for the crew queue's block instrument (Theme.Image.queueDial, UI/CarBoarding): a railway
signal-box block instrument dial: brass bezel, cream enamel face with LINE CLEAR (green, left), LINE BLOCKED
(grey, top) and TRAIN ON LINE (red, right) sectors, and a separate black needle on a brass boss that the UI
swings. Orthographic, top-down, Cycles, transparent film, 512 px (downsampled to 256 by the caller).

    blender -b --python tools/uiart/render_queue_dial.py -- <out_dir> face|needle
"""

import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT, PART = args[0], args[1]
FONT = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
R = 1.0


def link(ob):
    scene.collection.objects.link(ob)
    return ob


def material(name, color, metallic=0.0, rough=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    return mat


def brass_material():
    mat = bpy.data.materials.new("Brass")
    mat.use_nodes = True
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    b = N["Principled BSDF"]
    b.inputs["Metallic"].default_value = 1
    b.inputs["Roughness"].default_value = 0.32
    tc = N.new("ShaderNodeTexCoord")
    noise = N.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 6
    noise.inputs["Detail"].default_value = 6
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.42, 0.26, 0.08, 1)
    ramp.color_ramp.elements[1].color = (0.80, 0.56, 0.20, 1)
    L.new(noise.outputs["Fac"], ramp.inputs[0])
    L.new(ramp.outputs[0], b.inputs["Base Color"])
    return mat


brass = brass_material()
enamel = material("Enamel", (0.80, 0.74, 0.60), 0.0, 0.28)
ink = material("Ink", (0.04, 0.035, 0.03), 0.0, 0.6)
green = material("Clear", (0.18, 0.36, 0.20), 0.0, 0.35)
grey = material("Blocked", (0.40, 0.40, 0.38), 0.0, 0.35)
red = material("OnLine", (0.55, 0.08, 0.06), 0.0, 0.35)


def ring(r0, r1, z0, z1, mat, seg=128):
    bm = bmesh.new()
    rings = []
    for z, r in ((z0, r0), (z0, r1), (z1, r1), (z1, r0)):
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)])
    for k in range(4):
        a, b = rings[k], rings[(k + 1) % 4]
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    me = bpy.data.meshes.new("ring")
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new("ring", me))
    ob.data.materials.append(mat)
    bev = ob.modifiers.new("b", "BEVEL")
    bev.width, bev.segments = 0.02, 3
    ob.data.shade_smooth()
    return ob


def sector(r0, r1, a0, a1, z, mat, seg=48):
    """A flat annular sector between angles a0 and a1 (degrees, 0 = up, clockwise positive)."""
    bm = bmesh.new()
    pts = []
    for i in range(seg + 1):
        a = math.radians(90 - (a0 + (a1 - a0) * i / seg))
        pts.append((r1 * math.cos(a), r1 * math.sin(a)))
    for i in range(seg + 1):
        a = math.radians(90 - (a1 - (a1 - a0) * i / seg))
        pts.append((r0 * math.cos(a), r0 * math.sin(a)))
    bm.faces.new([bm.verts.new((x, y, z)) for x, y in pts])
    me = bpy.data.meshes.new("sector")
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new("sector", me))
    ob.data.materials.append(mat)
    return ob


def label(text, angle, radius, size, mat=None, upright=False):
    font = bpy.data.fonts.load(FONT, check_existing=True)
    cu = bpy.data.curves.new("t", "FONT")
    cu.body, cu.font, cu.size, cu.align_x, cu.align_y = text, font, size, "CENTER", "CENTER"
    ob = link(bpy.data.objects.new("t", cu))
    a = math.radians(90 - angle)
    ob.location = (radius * math.cos(a), radius * math.sin(a), 0.032)
    ob.rotation_euler.z = 0 if upright else math.radians(-angle)
    ob.data.materials.append(mat or ink)


if PART == "face":
    # bezel, a stepped brass ring, and the enamel face inside it
    ring(0.80, R, 0.0, 0.10, brass)
    ring(0.76, 0.86, 0.06, 0.13, brass)
    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=0.80, depth=0.06, location=(0, 0, 0.0))
    face = bpy.context.active_object
    face.data.materials.append(enamel)
    # the three indications: green left, grey top, red right
    sector(0.42, 0.70, -80, -25, 0.031, green)
    sector(0.42, 0.70, -20, 20, 0.031, grey)
    sector(0.42, 0.70, 25, 80, 0.031, red)
    # each indication's words inside its own sector, in cream, as on the enamel originals
    cream = material("Cream", (0.86, 0.80, 0.66), 0.0, 0.3)
    label("LINE CLEAR", -52, 0.56, 0.052, cream)
    label("LINE BLOCKED", 0, 0.56, 0.052, cream)
    label("TRAIN ON LINE", 52, 0.56, 0.052, cream)
    # the railway's name under the boss, as the instrument makers stamped it
    label("LAST TRAIN OUT", 180, 0.36, 0.07, None, True)
    label("BLOCK INSTRUMENT No. 5", 180, 0.50, 0.045, None, True)
    # fine tick ring
    for i in range(-80, 81, 10):
        a = math.radians(90 - i)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0.73 * math.cos(a), 0.73 * math.sin(a), 0.032))
        t = bpy.context.active_object
        t.scale = (0.008, 0.045, 0.002)
        t.rotation_euler.z = math.radians(-i)
        t.data.materials.append(ink)
else:
    # the needle, pointing up (the UI rotates it about the image centre), on a brass boss
    bm = bmesh.new()
    pts = [(-0.035, -0.12), (0.035, -0.12), (0.012, 0.64), (0, 0.68), (-0.012, 0.64)]
    bot = [bm.verts.new((x, y, 0.05)) for x, y in pts]
    top = [bm.verts.new((x, y, 0.07)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    me = bpy.data.meshes.new("needle")
    bm.to_mesh(me)
    bm.free()
    nd = link(bpy.data.objects.new("needle", me))
    nd.data.materials.append(ink)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.085, location=(0, 0, 0.06))
    boss = bpy.context.active_object
    boss.scale.z = 0.45
    boss.data.materials.append(brass)
    bpy.ops.object.shade_smooth()


def area(loc, energy, color, size):
    ld = bpy.data.lights.new("l", "AREA")
    ld.energy, ld.color, ld.size = energy, color, size
    ob = link(bpy.data.objects.new("l", ld))
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


area((-2.4, 2.2, 3.0), 260, (1.0, 0.86, 0.68), 2.0)
area((2.4, -2.0, 2.6), 70, (0.75, 0.82, 1.0), 3.0)
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.34, 0.24, 1)

cam_d = bpy.data.cameras.new("cam")
cam_d.type, cam_d.ortho_scale = "ORTHO", 2.08
cam = link(bpy.data.objects.new("cam", cam_d))
cam.location = (0, 0, 5)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Punchy"
scene.view_settings.exposure = -0.3
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.filepath = os.path.join(OUT, f"queue_dial_{PART}.png")
bpy.ops.render.render(write_still=True)
print("DIAL_DONE", scene.render.filepath)
