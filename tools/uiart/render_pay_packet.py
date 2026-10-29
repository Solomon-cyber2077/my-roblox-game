"""Blender render for the stop-five cash-out's pay packet (Theme.Image.payPacket, UI/CashOut): a buff
manila wage packet with a printed ruled form, its flap open, the company's brass fare tokens
(render_brass_token.py) tipping out. After old railway wage packets. Cycles, transparent film, 512 px,
cropped to 256 by the caller.

    blender -b --python tools/uiart/render_pay_packet.py -- <out_dir> <brass_token.blend>
"""

import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT, TOKEN_BLEND = args[0], args[1]
FONT = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

PW, PH, PT = 0.62, 0.92, 0.012  # packet width, height, paper thickness


def link(ob):
    scene.collection.objects.link(ob)
    return ob


def material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    return mat, nt.nodes, nt.links, bsdf


# --- manila: buff kraft, fibres, handled darker at the edges -----------------------------------
paper, N, L, bsdf = material("Manila")
tc = N.new("ShaderNodeTexCoord")


def noise(scale, detail, rough, vec):
    t = N.new("ShaderNodeTexNoise")
    t.inputs["Scale"].default_value, t.inputs["Detail"].default_value = scale, detail
    t.inputs["Roughness"].default_value = rough
    L.new(vec, t.inputs["Vector"])
    return t


def ramp(stops, inp):
    r = N.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position, r.color_ramp.elements[0].color = stops[0]
    r.color_ramp.elements[1].position, r.color_ramp.elements[1].color = stops[-1]
    for p, c in stops[1:-1]:
        r.color_ramp.elements.new(p).color = c
    L.new(inp, r.inputs[0])
    return r


def mix(a, b, fac):
    m = N.new("ShaderNodeMix")
    m.data_type = "RGBA"
    L.new(fac, m.inputs["Factor"])
    L.new(a, m.inputs[6])
    L.new(b, m.inputs[7])
    return m.outputs[2]


obj = tc.outputs["Object"]
tone = ramp([(0.3, (0.50, 0.29, 0.10, 1)), (0.7, (0.66, 0.42, 0.17, 1))], noise(4, 6, 0.6, obj).outputs["Fac"])
fibre = ramp([(0.4, (0, 0, 0, 1)), (0.75, (1, 1, 1, 1))], noise(260, 4, 0.8, obj).outputs["Fac"])
light_fibre = N.new("ShaderNodeRGB")
light_fibre.outputs[0].default_value = (0.72, 0.50, 0.24, 1)
c = mix(tone.outputs[0], light_fibre.outputs[0], fibre.outputs[0])
# handled edges: darker, grubby toward the borders of the packet
edge_d = N.new("ShaderNodeSeparateXYZ")
L.new(obj, edge_d.inputs[0])
ex = N.new("ShaderNodeMath")
ex.operation = "ABSOLUTE"
L.new(edge_d.outputs["X"], ex.inputs[0])
grub = ramp([(PW / 2 - 0.07, (0, 0, 0, 1)), (PW / 2, (0.75, 0.75, 0.75, 1))], ex.outputs[0])
dark = N.new("ShaderNodeRGB")
dark.outputs[0].default_value = (0.18, 0.11, 0.05, 1)
c = mix(c, dark.outputs[0], grub.outputs[0])
L.new(c, bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.88
bump = N.new("ShaderNodeBump")
bump.inputs["Strength"].default_value = 0.18
L.new(noise(90, 8, 0.7, obj).outputs["Fac"], bump.inputs["Height"])
L.new(bump.outputs[0], bsdf.inputs["Normal"])

ink, N2, L2, ib = material("Ink")
ib.inputs["Base Color"].default_value = (0.09, 0.045, 0.02, 1)
ib.inputs["Roughness"].default_value = 0.7


def slab(name, w, h, t, loc, mat, bevel=0.004):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = (w, h, t)
    bpy.ops.object.transform_apply(scale=True)
    b = ob.modifiers.new("b", "BEVEL")
    b.width, b.segments = bevel, 2
    ob.data.materials.append(mat)
    return ob


# the packet: back and front sheets (a token is tucked between), a soft crease across the front
back = slab("Back", PW, PH, PT, (0, 0, -PT), paper)
front = slab("Front", PW, PH * 0.97, PT, (0, -PH * 0.015, PT * 0.6), paper)
for ob in (front, back):
    sub = ob.modifiers.new("s", "SUBSURF")
    sub.levels, sub.subdivision_type = 3, "SIMPLE"
    tex = bpy.data.textures.new("crumple", "CLOUDS")
    tex.noise_scale = 0.45
    d = ob.modifiers.new("d", "DISPLACE")
    d.texture, d.strength = tex, 0.012

# the flap: a pointed flap hinged at the top of the back sheet, folded open and back
bm = bmesh.new()
pts = [(-PW / 2, 0), (PW / 2, 0), (PW / 2 - 0.05, 0.16), (0, 0.26), (-PW / 2 + 0.05, 0.16)]
bot = [bm.verts.new((x, y, 0)) for x, y in pts]
top = [bm.verts.new((x, y, PT)) for x, y in pts]
bm.faces.new(top)
bm.faces.new(list(reversed(bot)))
for i in range(len(pts)):
    j = (i + 1) % len(pts)
    bm.faces.new((bot[i], bot[j], top[j], top[i]))
me = bpy.data.meshes.new("flap")
bm.to_mesh(me)
bm.free()
flap = link(bpy.data.objects.new("Flap", me))
flap.location = (0, PH / 2, -PT * 1.4)
flap.rotation_euler.x = math.radians(-24)  # opened back past the top edge
flap.data.materials.append(paper)

# printed form on the front, in brown ink: a header, then ruled lines with labels
def text(body, size, loc, align="LEFT"):
    font = bpy.data.fonts.load(FONT, check_existing=True)
    cu = bpy.data.curves.new("t", "FONT")
    cu.body, cu.font, cu.size, cu.align_x = body, font, size, align
    ob = link(bpy.data.objects.new("t", cu))
    ob.location = loc
    ob.data.materials.append(ink)
    return ob


z_ink = PT * 0.6 + PT / 2 + 0.0018
text("LAST TRAIN OUT", 0.075, (0, 0.31, z_ink), "CENTER")
text("WAGES  ·  FARE SETTLED AT STOP 5", 0.032, (0, 0.255, z_ink), "CENTER")
for i, label in enumerate(("NAME", "No.", "STOPS", "BRASS")):
    y = 0.15 - i * 0.105
    text(label, 0.03, (-PW / 2 + 0.06, y + 0.012, z_ink))
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0.06, y, z_ink))
    rule = bpy.context.active_object
    rule.scale = (PW - 0.28, 0.0045, 1)
    rule.data.materials.append(ink)
# a hand-pencilled tally in the BRASS line, and a border round the form
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0.02, z_ink - 0.0005))
frame = bpy.context.active_object
frame.scale = (PW - 0.07, 0.5, 1)
wf = frame.modifiers.new("w", "WIREFRAME")
wf.thickness = 0.005
frame.data.materials.append(ink)

# --- brass fare tokens from the token render, tipping out of the open top ---------------------
with bpy.data.libraries.load(TOKEN_BLEND, link=False) as (src, dst):
    dst.objects = ["Token"]
token = dst.objects[0]
token.rotation_euler = (0, 0, 0)
placements = [
    ((0.07, PH / 2 + 0.05, 0.0), (math.radians(-62), math.radians(14), math.radians(-12)), 0.16),
    ((-0.13, PH / 2 + 0.0, -0.004), (math.radians(-55), math.radians(-20), math.radians(16)), 0.16),
    # tilted away from the key so it shows its brass, not a mirror of the lamp
    ((0.24, -PH / 2 + 0.06, 0.04), (math.radians(-34), math.radians(-26), math.radians(-20)), 0.15),
]
for i, (loc, rot, s) in enumerate(placements):
    ob = token if i == 0 else token.copy()
    if i > 0:
        ob.data = token.data
    link(ob)
    ob.location, ob.rotation_euler, ob.scale = loc, rot, (s, s, s)

# --- staging: three-quarter view, lantern key, cool rim ---------------------------------------
root = bpy.data.objects.new("root", None)
link(root)
for ob in list(scene.objects):
    if ob is not root and ob.parent is None and ob.type in ("MESH", "FONT"):
        ob.parent = root
root.rotation_euler = (math.radians(-30), math.radians(10), math.radians(-14))


def area(loc, energy, color, size):
    ld = bpy.data.lights.new("l", "AREA")
    ld.energy, ld.color, ld.size = energy, color, size
    ob = link(bpy.data.objects.new("l", ld))
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


area((-2.4, -2.0, 3.2), 230, (1.0, 0.82, 0.6), 1.8)
area((2.6, 2.4, 1.0), 110, (0.62, 0.74, 1.0), 1.0)
area((0.4, -3.2, -0.4), 25, (1.0, 0.9, 0.8), 3.0)
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.09, 0.06, 0.035, 1)

cam_d = bpy.data.cameras.new("cam")
cam_d.lens = 70
cam = link(bpy.data.objects.new("cam", cam_d))
cam.location = (0, 0.04, 2.55)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Punchy"
scene.view_settings.exposure = -0.6  # keep the manila buff and the brass gold, not blown to cream
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.filepath = os.path.join(OUT, "pay_packet.png")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "pay_packet.blend"))
bpy.ops.render.render(write_still=True)
print("PACKET_DONE", scene.render.filepath)
