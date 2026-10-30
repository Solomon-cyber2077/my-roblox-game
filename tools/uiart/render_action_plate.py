"""Blender render for the touch action button (Theme.Image.actionPlate, UI/ActionButton): a brass
signal-box lever plate, rounded ends, a slotted screw at each end and a black-wax field where the
label sits. After the brass lever plates of old railway signal boxes. Orthographic, top-down, Cycles,
transparent film with a shadow catcher; two states: "up" (raised, a soft shadow) and "down" (pressed
flat to the panel). 512 x 176, cut as a 9-slice (the ends keep their size, the middle stretches).

    blender -b --python tools/uiart/render_action_plate.py -- <out_dir> up|down
"""

import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT, STATE = args[0], args[1]
DOWN = STATE == "down"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

PX_W, PX_H = 512, 176
U = 1 / PX_H                      # one pixel in Blender units
MARGIN = 16 * U                   # room for the shadow
W, H = PX_W * U - 2 * MARGIN, PX_H * U - 2 * MARGIN
RAD = H * 0.32                    # corner radius
T = 0.05                          # plate thickness
FIELD_X, FIELD_Y = 64 * U, 24 * U  # the wax field's inset from the plate's edge
DEPTH = 0.016                     # how deep the field is cut
LIFT = 0.012 if DOWN else 0.05    # the plate's height above the panel


def link(ob):
    scene.collection.objects.link(ob)
    return ob


def rounded(w, h, r, seg=10):
    """A rounded rectangle outline, counter-clockwise; same vertex count for any size."""
    pts = []
    corners = [(w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)]
    for cx, cy, start in corners:
        for k in range(seg + 1):
            a = math.radians(start + 90 * k / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


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


# --- brass: handled, polished on the face, toned in the corners -------------------------------
brass, N, L, bsdf = material("Brass")
tc = N.new("ShaderNodeTexCoord")
geo = N.new("ShaderNodeNewGeometry")


def noise(scale, detail, rough):
    t = N.new("ShaderNodeTexNoise")
    t.inputs["Scale"].default_value, t.inputs["Detail"].default_value = scale, detail
    t.inputs["Roughness"].default_value = rough
    L.new(tc.outputs["Object"], t.inputs["Vector"])
    return t


def ramp(stops, inp):
    r = N.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position, r.color_ramp.elements[0].color = stops[0]
    r.color_ramp.elements[1].position, r.color_ramp.elements[1].color = stops[-1]
    for p, c in stops[1:-1]:
        r.color_ramp.elements.new(p).color = c
    L.new(inp, r.inputs[0])
    return r


def rgb(c):
    n = N.new("ShaderNodeRGB")
    n.outputs[0].default_value = (*c, 1)
    return n.outputs[0]


def mix(a, b, fac):
    m = N.new("ShaderNodeMix")
    m.data_type = "RGBA"
    L.new(fac, m.inputs["Factor"])
    L.new(a, m.inputs[6])
    L.new(b, m.inputs[7])
    return m.outputs[2]


tone = ramp([(0.35, (0, 0, 0, 1)), (0.65, (1, 1, 1, 1))], noise(2.6, 6, 0.6).outputs["Fac"])
c = mix(rgb((0.55, 0.34, 0.10)), rgb((0.78, 0.54, 0.18)), tone.outputs[0])
tarnish = ramp([(0.56, (0, 0, 0, 1)), (0.7, (0.45, 0.45, 0.45, 1))], noise(7, 8, 0.6).outputs["Fac"])
c = mix(c, rgb((0.18, 0.11, 0.04)), tarnish.outputs[0])
c = mix(c, rgb((0.90, 0.68, 0.32)), ramp([(0.5, (0, 0, 0, 1)), (0.56, (1, 1, 1, 1))], geo.outputs["Pointiness"]).outputs[0])
L.new(c, bsdf.inputs["Base Color"])
bsdf.inputs["Metallic"].default_value = 1
rough = ramp([(0.0, (0.2, 0.2, 0.2, 1)), (1.0, (0.36, 0.36, 0.36, 1))], noise(30, 6, 0.6).outputs["Fac"])
sep = N.new("ShaderNodeSeparateColor")
L.new(rough.outputs[0], sep.inputs[0])
L.new(sep.outputs[0], bsdf.inputs["Roughness"])
# polishing marks: fine scratches running along the plate
scr = N.new("ShaderNodeTexWave")
scr.wave_type, scr.bands_direction = "BANDS", "Y"
scr.inputs["Scale"].default_value = 140
scr.inputs["Distortion"].default_value = 6
scr.inputs["Detail"].default_value = 8
L.new(tc.outputs["Object"], scr.inputs["Vector"])
bump = N.new("ShaderNodeBump")
bump.inputs["Strength"].default_value = 0.06
L.new(scr.outputs["Fac"], bump.inputs["Height"])
L.new(bump.outputs[0], bsdf.inputs["Normal"])

wax, N2, L2, wb = material("Wax")
wb.inputs["Base Color"].default_value = (0.012, 0.010, 0.009, 1)
wb.inputs["Roughness"].default_value = 0.8

# --- the plate: a rounded slab with the field cut into its face (no booleans) ------------------
outer = rounded(W, H, RAD)
inner = rounded(W - 2 * FIELD_X, H - 2 * FIELD_Y, RAD * 0.55)
bm = bmesh.new()
z0, z1, zf = LIFT, LIFT + T, LIFT + T - DEPTH
ob_ = [bm.verts.new((x, y, z0)) for x, y in outer]
ot = [bm.verts.new((x, y, z1)) for x, y in outer]
it = [bm.verts.new((x, y, z1)) for x, y in inner]
ib = [bm.verts.new((x, y, zf)) for x, y in inner]
n = len(outer)
for i in range(n):
    j = (i + 1) % n
    bm.faces.new((ob_[i], ob_[j], ot[j], ot[i]))   # outer wall
    bm.faces.new((ot[i], ot[j], it[j], it[i]))     # the brass face round the field
    bm.faces.new((it[i], it[j], ib[j], ib[i]))     # the cut's wall
bm.faces.new(list(reversed(ob_)))                  # underside
field_face = bm.faces.new(ib)                      # the field floor
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("plate")
bm.to_mesh(me)
bm.free()
plate = link(bpy.data.objects.new("Plate", me))
plate.data.materials.append(brass)
plate.data.materials.append(wax)
plate.data.polygons[-1].material_index = 1
bev = plate.modifiers.new("bevel", "BEVEL")
bev.width, bev.segments, bev.limit_method = 0.012, 3, "ANGLE"
plate.modifiers.new("wn", "WEIGHTED_NORMAL").keep_sharp = True

# slotted, countersunk screws at each end, slots at odd angles as a fitter left them
for side, slot_angle in ((-1, 28), (1, -52)):
    x = side * (W / 2 - FIELD_X / 2)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=12, radius=0.135, location=(x, 0, z1 - 0.05))
    head = bpy.context.active_object
    head.scale.z = 0.45
    head.data.materials.append(brass)
    bpy.ops.object.shade_smooth()
    # the slot sits in the dome's top, inside the head
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 0, z1 + 0.008))
    slot = bpy.context.active_object
    slot.scale = (0.19, 0.026, 0.012)
    slot.rotation_euler.z = math.radians(slot_angle)
    slot.data.materials.append(wax)

# the panel it is fixed to: catches the shadow only
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
bpy.context.active_object.is_shadow_catcher = True

# --- light: a low lantern key from the top left, so the cut and the screws read -----------------
def area(loc, energy, color, size):
    ld = bpy.data.lights.new("l", "AREA")
    ld.energy, ld.color, ld.size = energy, color, size
    ob = link(bpy.data.objects.new("l", ld))
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


key = 1.0 if not DOWN else 0.68  # pressed: a touch darker, sunk into the panel's shade
area((-3.2, 2.6, 2.4), 300 * key, (1.0, 0.84, 0.64), 2.0)
area((3.0, -2.0, 2.6), 60 * key, (0.72, 0.8, 1.0), 3.0)
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
# the room the polished face reflects (the film is transparent, so only the metal shows it)
world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.33, 0.22, 1)

cam_d = bpy.data.cameras.new("cam")
cam_d.type, cam_d.ortho_scale = "ORTHO", PX_W * U
cam = link(bpy.data.objects.new("cam", cam_d))
cam.location = (0, 0, 5)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 128
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Punchy"
scene.view_settings.exposure = -0.15
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.resolution_x, scene.render.resolution_y = PX_W, PX_H
scene.render.filepath = os.path.join(OUT, f"action_plate_{STATE}.png")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"action_plate_{STATE}.blend"))
bpy.ops.render.render(write_still=True)
print("PLATE_DONE", scene.render.filepath)
