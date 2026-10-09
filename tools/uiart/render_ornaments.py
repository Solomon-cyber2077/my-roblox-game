"""Blender renders of the UI's metal and wax: brass frame, enamel plate, rivet, wax seal,
watch bezel. Orthographic, top-down, transparent film, Cycles.

    blender -b -P tools/uiart/render_ornaments.py -- assets/ui
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

OUT = Path(sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/ui").resolve()
OUT.mkdir(parents=True, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.035, 0.03, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world
    cam = bpy.data.cameras.new("C")
    cam.type = "ORTHO"
    cam_obj = bpy.data.objects.new("C", cam)
    cam_obj.location = (0, 0, 10)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    # key: warm gaslamp from upper left; rim: moon red from lower right
    for name, loc, energy, color, size in (
        ("Key", (-4, 5, 6), 900, (1.0, 0.82, 0.6), 3),
        ("Rim", (5, -4, 3), 250, (1.0, 0.25, 0.18), 2),
        ("Fill", (0, 0, 8), 120, (0.9, 0.9, 1.0), 6),
    ):
        light = bpy.data.lights.new(name, "AREA")
        light.energy, light.color, light.size = energy, color, size
        obj = bpy.data.objects.new(name, light)
        obj.location = loc
        obj.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(obj)
    return scene, cam


def material(name, color, metallic=0.0, roughness=0.4, coat=0.0, bump=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Coat Weight"].default_value = coat
    if bump > 0:
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 40
        noise.inputs["Detail"].default_value = 8
        b = nodes.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump
        links.new(noise.outputs["Fac"], b.inputs["Height"])
        links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def link(obj, mat=None):
    bpy.context.scene.collection.objects.link(obj)
    if mat:
        obj.data.materials.append(mat)
    return obj


def render(name, px, cam, ortho):
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = px
    cam.ortho_scale = ortho
    scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
    print("wrote", OUT / name)


def box_mesh(name, w, h, d, bevel, segments=4):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co.x *= w
        v.co.y *= h
        v.co.z *= d
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=segments, affect="EDGES", profile=0.6)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    return bpy.data.objects.new(name, me)


def frame_mesh(name, outer, inner, depth, bevel):
    """A square ring (outer/inner half-widths) bevelled on every edge."""
    bm = bmesh.new()
    pts_o = [(-outer, -outer), (outer, -outer), (outer, outer), (-outer, outer)]
    pts_i = [(-inner, -inner), (inner, -inner), (inner, inner), (-inner, inner)]
    vo = [bm.verts.new((x, y, 0)) for x, y in pts_o]
    vi = [bm.verts.new((x, y, 0)) for x, y in pts_i]
    for k in range(4):
        bm.faces.new((vo[k], vo[(k + 1) % 4], vi[(k + 1) % 4], vi[k]))
    ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z += depth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=3, affect="EDGES", profile=0.5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    return bpy.data.objects.new(name, me)


brass = lambda: material("Brass", (0.78, 0.55, 0.24), metallic=1, roughness=0.32, bump=0.08)

# 1. Brass frame, 9-slice 128px over a 2.0 ortho: rim 0.30 wide, engraved inner groove, corner rosettes.
scene, cam = reset()
mat = brass()
link(frame_mesh("Outer", 0.98, 0.80, 0.08, 0.025), mat)
link(frame_mesh("Inner", 0.76, 0.70, 0.05, 0.012), mat)
for sx in (-1, 1):
    for sy in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(sx * 0.89, sy * 0.89, 0.06), segments=24, ring_count=12)
        bpy.context.object.scale.z = 0.5
        bpy.context.object.data.materials.append(mat)
        bpy.ops.object.shade_smooth()
        bpy.ops.mesh.primitive_torus_add(major_radius=0.12, minor_radius=0.018, location=(sx * 0.89, sy * 0.89, 0.07))
        bpy.context.object.data.materials.append(mat)
        bpy.ops.object.shade_smooth()
render("brass_frame.png", 128, cam, 2.0)

# 2. Enamel plate, 9-slice 128: near-white glossy bevelled slab (tinted per style by ImageColor3).
scene, cam = reset()
link(box_mesh("Plate", 1.9, 1.9, 0.12, 0.14, 5), material("Enamel", (0.86, 0.85, 0.82), roughness=0.18, coat=0.6, bump=0.02))
render("enamel_plate.png", 128, cam, 2.0)

# 3. Rivet, 32px.
scene, cam = reset()
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.8, segments=32, ring_count=16)
bpy.context.object.scale.z = 0.45
bpy.context.object.data.materials.append(brass())
bpy.ops.object.shade_smooth()
render("rivet.png", 32, cam, 2.0)

# 4. Wax seal, 256px: ragged poured disc, raised rim, a six-spoke wheel pressed into it.
scene, cam = reset()
wax = material("Wax", (0.16, 0.008, 0.01), roughness=0.2, coat=1.0, bump=0.04)
bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=0.9, depth=0.18)
seal = bpy.context.object
seal.data.materials.append(wax)
bm = bmesh.new()
bm.from_mesh(seal.data)
for v in bm.verts:
    a = math.atan2(v.co.y, v.co.x)
    r = 1 + 0.07 * math.sin(a * 5 + 0.7) + 0.04 * math.sin(a * 11 + 2.1) + 0.025 * math.sin(a * 23)
    v.co.x *= r
    v.co.y *= r
bm.to_mesh(seal.data)
bm.free()
mod = seal.modifiers.new("Bevel", "BEVEL")
mod.width, mod.segments = 0.08, 6
bpy.ops.object.shade_smooth()
# the impression: a sunken ring and spokes, cut with booleans
cutters = []
bpy.ops.mesh.primitive_torus_add(major_radius=0.55, minor_radius=0.06, location=(0, 0, 0.1))
cutters.append(bpy.context.object)
bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.12, depth=0.1, location=(0, 0, 0.11))
cutters.append(bpy.context.object)
for k in range(6):
    a = k * math.pi / 3
    bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * 0.3, math.sin(a) * 0.3, 0.1))
    c = bpy.context.object
    c.scale = (0.4, 0.05, 0.06)
    c.rotation_euler.z = a
    cutters.append(c)
for c in cutters:
    b = seal.modifiers.new("Cut", "BOOLEAN")
    b.operation, b.object = "DIFFERENCE", c
    c.hide_render = True
render("wax_seal.png", 256, cam, 2.2)

# 5. Watch bezel, 256px: knurled brass ring with a crown, open face.
scene, cam = reset()
mat = brass()
bpy.ops.mesh.primitive_torus_add(major_radius=0.86, minor_radius=0.1, major_segments=96, minor_segments=24)
bpy.context.object.data.materials.append(mat)
bpy.ops.object.shade_smooth()
bpy.ops.mesh.primitive_torus_add(major_radius=0.74, minor_radius=0.035, major_segments=96, minor_segments=12, location=(0, 0, 0.02))
bpy.context.object.data.materials.append(mat)
bpy.ops.object.shade_smooth()
for k in range(72):
    a = k * math.tau / 72
    bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * 0.95, math.sin(a) * 0.95, 0))
    c = bpy.context.object
    c.scale = (0.05, 0.022, 0.1)
    c.rotation_euler.z = a
    c.data.materials.append(mat)
bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.08, depth=0.12, location=(0, 1.04, 0))
bpy.context.object.data.materials.append(mat)
render("watch_bezel.png", 256, cam, 2.3)
