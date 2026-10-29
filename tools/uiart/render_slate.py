"""Blender render for the departure slate (Theme.Image.slate, UI/Overlay): a station chalk slate in a
stained oak frame with brass corner plates, after old "train bulletin" boards and school writing
slates. Orthographic, top-down, Cycles, transparent film, sized for the 280 x 36 slate (2x) and cut
as a 9-slice: the frame and corners keep their size, the slate stretches.

    blender -b --python tools/uiart/render_slate.py -- <out_dir> [preview]
"""

import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
PREVIEW = len(args) > 1 and args[1] == "preview"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

PX_W, PX_H = 1120, 144     # the image; the slate is drawn at 280 x 36, so 4x
UNIT = 1 / 144              # one pixel of the image, in Blender units (the board is 1 unit tall)
W, H = PX_W * UNIT, PX_H * UNIT
FRAME = 18 * UNIT           # oak frame width
DEPTH = 0.05


def link(ob):
    scene.collection.objects.link(ob)
    return ob


def node_tools(nt):
    N, L = nt.nodes, nt.links

    def noise(scale, detail, rough, vec=None, dim="3D"):
        t = N.new("ShaderNodeTexNoise")
        t.noise_dimensions = dim
        t.inputs["Scale"].default_value = scale
        t.inputs["Detail"].default_value = detail
        t.inputs["Roughness"].default_value = rough
        if vec is not None:
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

    def scaled(vec, sx, sy, sz=1.0):
        m = N.new("ShaderNodeMapping")
        m.inputs["Scale"].default_value = (sx, sy, sz)
        L.new(vec, m.inputs["Vector"])
        return m.outputs[0]

    return N, L, noise, ramp, rgb, mix, scaled


def new_mat(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    return mat, nt, bsdf


# --- slate: blue-black stone, ghosts of erased chalk wiped sideways ----------------------------
slate_mat, nt, bsdf = new_mat("Slate")
N, L, noise, ramp, rgb, mix, scaled = node_tools(nt)
tc = N.new("ShaderNodeTexCoord")
obj = tc.outputs["Object"]
stone = noise(9, 10, 0.7, obj)
base = mix(rgb((0.022, 0.026, 0.030)), rgb((0.040, 0.046, 0.050)), stone.outputs["Fac"])
# wiped haze: long sideways strokes of old chalk, faint and uneven
wipe = noise(2.4, 7, 0.6, scaled(obj, 0.32, 1.7))
haze = ramp([(0.48, (0, 0, 0, 1)), (0.72, (0.55, 0.55, 0.55, 1))], wipe.outputs["Fac"])
blotch = ramp([(0.4, (0.25, 0.25, 0.25, 1)), (0.7, (1, 1, 1, 1))], noise(1.2, 3, 0.5, obj).outputs["Fac"])
fac = N.new("ShaderNodeMath")
fac.operation = "MULTIPLY"
L.new(haze.outputs[0], fac.inputs[0])
L.new(blotch.outputs[0], fac.inputs[1])
fac2 = N.new("ShaderNodeMath")
fac2.operation = "MULTIPLY"
fac2.inputs[1].default_value = 0.32
L.new(fac.outputs[0], fac2.inputs[0])
col = mix(base, rgb((0.30, 0.31, 0.30)), fac2.outputs[0])
L.new(col, bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.82
bump = N.new("ShaderNodeBump")
bump.inputs["Strength"].default_value = 0.08
L.new(noise(60, 8, 0.7, obj).outputs["Fac"], bump.inputs["Height"])
L.new(bump.outputs[0], bsdf.inputs["Normal"])

bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
slate = bpy.context.active_object
slate.scale = (W - FRAME, H - FRAME, 1)
slate.data.materials.append(slate_mat)

# --- oak frame: stained, grain along each rail, edges worn pale ----------------------------
oak_mat, nt, bsdf = new_mat("Oak")
N, L, noise, ramp, rgb, mix, scaled = node_tools(nt)
tc = N.new("ShaderNodeTexCoord")
geo = N.new("ShaderNodeNewGeometry")
grain = N.new("ShaderNodeTexWave")
grain.wave_type = "BANDS"
grain.bands_direction = "Y"  # rails are built along their local X, see rail(): grain runs with them
grain.inputs["Scale"].default_value = 70
grain.inputs["Distortion"].default_value = 9
grain.inputs["Detail"].default_value = 6
grain.inputs["Detail Scale"].default_value = 1.4
L.new(tc.outputs["Object"], grain.inputs["Vector"])
g = ramp([(0.2, (0.045, 0.022, 0.010, 1)), (0.55, (0.11, 0.055, 0.025, 1)), (0.9, (0.18, 0.095, 0.042, 1))], grain.outputs["Fac"])
dirt = noise(4, 6, 0.6, tc.outputs["Object"])
c = mix(g.outputs[0], rgb((0.05, 0.03, 0.016)), ramp([(0.45, (0, 0, 0, 1)), (0.7, (0.6, 0.6, 0.6, 1))], dirt.outputs["Fac"]).outputs[0])
worn = ramp([(0.5, (0, 0, 0, 1)), (0.6, (1, 1, 1, 1))], geo.outputs["Pointiness"])
c = mix(c, rgb((0.30, 0.17, 0.08)), worn.outputs[0])
L.new(c, bsdf.inputs["Base Color"])
rough = ramp([(0.0, (0.42, 0.42, 0.42, 1)), (1.0, (0.62, 0.62, 0.62, 1))], grain.outputs["Fac"])
sep = N.new("ShaderNodeSeparateColor")
L.new(rough.outputs[0], sep.inputs[0])
L.new(sep.outputs[0], bsdf.inputs["Roughness"])
bump = N.new("ShaderNodeBump")
bump.inputs["Strength"].default_value = 0.45
L.new(grain.outputs["Fac"], bump.inputs["Height"])
L.new(bump.outputs[0], bsdf.inputs["Normal"])


def rail(length, x, y, angle):
    """A rounded oak rail along local X with mitred ends, centred at (x, y), turned by angle."""
    bm = bmesh.new()
    half_l, half_w = length / 2, FRAME / 2
    # mitred: the inner edge is shorter than the outer by the frame width at each end
    outline = [(-half_l, half_w), (half_l, half_w), (half_l - FRAME, -half_w), (-half_l + FRAME, -half_w)]
    bot = [bm.verts.new((px, py, 0)) for px, py in outline]
    top = [bm.verts.new((px, py, DEPTH)) for px, py in outline]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    me = bpy.data.meshes.new("rail")
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new("rail", me))
    ob.location = (x, y, 0)
    ob.rotation_euler.z = angle
    bev = ob.modifiers.new("bevel", "BEVEL")
    bev.width = FRAME * 0.28
    bev.segments = 4
    bev.limit_method = "ANGLE"
    ob.modifiers.new("sub", "SUBSURF").levels = 1
    ob.data.materials.append(oak_mat)
    ob.data.shade_smooth()
    return ob


hw, hh = W / 2 - FRAME / 2, H / 2 - FRAME / 2
rail(W, 0, hh, 0)
rail(W, 0, -hh, math.pi)
rail(H, hw, 0, -math.pi / 2)
rail(H, -hw, 0, math.pi / 2)

# --- brass corner plates, the same aged brass as the fare token -------------------------------
brass_mat, nt, bsdf = new_mat("Brass")
N, L, noise, ramp, rgb, mix, scaled = node_tools(nt)
tc = N.new("ShaderNodeTexCoord")
geo = N.new("ShaderNodeNewGeometry")
bsdf.inputs["Metallic"].default_value = 1
c = mix(rgb((0.22, 0.12, 0.035)), rgb((0.52, 0.33, 0.09)), ramp([(0.4, (0, 0, 0, 1)), (0.62, (1, 1, 1, 1))], noise(30, 6, 0.6, tc.outputs["Object"]).outputs["Fac"]).outputs[0])
c = mix(c, rgb((0.88, 0.64, 0.30)), ramp([(0.5, (0, 0, 0, 1)), (0.56, (1, 1, 1, 1))], geo.outputs["Pointiness"]).outputs[0])
L.new(c, bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.45

PLATE = FRAME * 1.55
for sx in (-1, 1):
    for sy in (-1, 1):
        cx, cy = sx * (W / 2 - PLATE / 2 + UNIT), sy * (H / 2 - PLATE / 2 + UNIT)
        bm = bmesh.new()
        # an L-shaped plate hugging the corner
        t = FRAME * 0.62
        pts = [(0, 0), (PLATE, 0), (PLATE, t), (t, t), (t, PLATE), (0, PLATE)]
        bot = [bm.verts.new((px, py, 0)) for px, py in pts]
        top = [bm.verts.new((px, py, 0.012)) for px, py in pts]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for i in range(len(pts)):
            j = (i + 1) % len(pts)
            bm.faces.new((bot[i], bot[j], top[j], top[i]))
        me = bpy.data.meshes.new("plate")
        bm.to_mesh(me)
        bm.free()
        ob = link(bpy.data.objects.new("plate", me))
        # the L's corner sits in the frame's outer corner
        ob.scale = (-sx, -sy, 1)
        ob.location = (sx * (W / 2 - UNIT), sy * (H / 2 - UNIT), DEPTH)
        bev = ob.modifiers.new("bevel", "BEVEL")
        bev.width = 0.004
        bev.segments = 2
        ob.data.materials.append(brass_mat)
        # one domed screw in the plate's corner
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=t * 0.28,
                                             location=(sx * (W / 2 - UNIT - t * 0.5), sy * (H / 2 - UNIT - t * 0.5), DEPTH + 0.012))
        screw = bpy.context.active_object
        screw.scale.z = 0.45
        screw.data.materials.append(brass_mat)
        bpy.ops.object.shade_smooth()

# --- lights and camera: soft top-left key for UI, transparent film ---------------------------
def area(loc, energy, color, size):
    ld = bpy.data.lights.new("l", "AREA")
    ld.energy, ld.color, ld.size = energy, color, size
    ob = link(bpy.data.objects.new("l", ld))
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


# a low key from the top left: the frame's bevels catch it and the frame shades the slate
area((-4.5, 3.2, 1.5), 420, (1.0, 0.84, 0.64), 2.5)
area((3, -2, 3), 45, (0.75, 0.82, 1.0), 4)
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.045, 0.04, 1)

cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = W
cam = link(bpy.data.objects.new("cam", cam_d))
cam.location = (0, 0, 5)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 128
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Base Contrast"
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.resolution_x, scene.render.resolution_y = PX_W, PX_H
name = "slate_preview.png" if PREVIEW else "slate.png"
scene.render.filepath = os.path.join(OUT, name)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "slate.blend"))
bpy.ops.render.render(write_still=True)
print("SLATE_DONE", scene.render.filepath)
