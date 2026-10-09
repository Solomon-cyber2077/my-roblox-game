"""Blender renders for the ticket-office look (Theme.Image, see docs/ASSET_CREDITS.md):
Mabel's booking-office window, the mahogany surround, the engraved brass plate, the leather
blotter and crew-pass card, the brass rim for plates, the signal lamp, the tier arrows and
the company crest. Orthographic, top-down (+Z faces the camera), Cycles, transparent film.

    blender -b -P tools/uiart/render_booth.py -- assets/ui [only_name]
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = Path(ARGS[0] if ARGS else "assets/ui").resolve()
ONLY = ARGS[1] if len(ARGS) > 1 else None
OUT.mkdir(parents=True, exist_ok=True)


def reset(world_strength=0.5):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.03, 0.02, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = world_strength
    scene.world = world
    cam = bpy.data.cameras.new("C")
    cam.type = "ORTHO"
    cam_obj = bpy.data.objects.new("C", cam)
    cam_obj.location = (0, 0, 10)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    return scene, cam


def light(kind, name, loc, energy, color, size=1.0, target=(0, 0, 0)):
    data = bpy.data.lights.new(name, kind)
    data.energy, data.color = energy, color
    if kind == "AREA":
        data.size = size
    else:
        data.shadow_soft_size = size
    obj = bpy.data.objects.new(name, data)
    obj.location = loc
    obj.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(obj)
    return obj


def lamp_rig(key=900, rim=220):
    # warm gaslamp from the upper left, moon red from the lower right
    light("AREA", "Key", (-4, 5, 6), key, (1.0, 0.8, 0.55), 3)
    light("AREA", "Rim", (5, -4, 3), rim, (1.0, 0.25, 0.18), 2)


def principled(name, color, metallic=0.0, roughness=0.4, coat=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Coat Weight"].default_value = coat
    return mat, mat.node_tree.nodes, mat.node_tree.links, bsdf


def bumped(mat_tuple, scale, strength, detail=8):
    mat, nodes, links, bsdf = mat_tuple
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    b = nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = strength
    links.new(noise.outputs["Fac"], b.inputs["Height"])
    links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def gilt():
    return bumped(principled("Gilt", (0.86, 0.6, 0.26), metallic=1, roughness=0.27), 50, 0.06)


def brass():
    return bumped(principled("Brass", (0.72, 0.5, 0.22), metallic=1, roughness=0.36), 40, 0.08)


def wood(direction="X", dark=(0.06, 0.016, 0.009), light_=(0.14, 0.042, 0.022)):
    """Mahogany: wave bands along one axis, warped by noise, French-polished."""
    mat, nodes, links, bsdf = principled("Wood" + direction, dark, roughness=0.4, coat=0.08)
    coord = nodes.new("ShaderNodeTexCoord")
    wave = nodes.new("ShaderNodeTexWave")
    wave.bands_direction = direction
    wave.inputs["Scale"].default_value = 5.5
    wave.inputs["Distortion"].default_value = 4
    wave.inputs["Detail"].default_value = 6
    wave.inputs["Detail Scale"].default_value = 1.5
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*light_, 1)
    links.new(coord.outputs["Object"], wave.inputs["Vector"])
    links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    pores = nodes.new("ShaderNodeTexNoise")
    pores.inputs["Scale"].default_value = 160
    b = nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = 0.05
    links.new(pores.outputs["Fac"], b.inputs["Height"])
    links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def leather(color=(0.03, 0.009, 0.008)):
    return bumped(principled("Leather", color, roughness=0.55, coat=0.15), 140, 0.22, 10)


def emit(name, color, strength):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.remove(nodes["Principled BSDF"])
    e = nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (*color, 1)
    e.inputs["Strength"].default_value = strength
    mat.node_tree.links.new(e.outputs[0], nodes["Material Output"].inputs[0])
    return mat


def finish(obj, mat=None, smooth=True):
    if obj.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(obj)
    if mat:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    if smooth and obj.type == "MESH":
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def mesh_from(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return bpy.data.objects.new(name, me)


def box(name, size, loc, bevel=0.0, segments=3, mat=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=segments, affect="EDGES", profile=0.6)
    obj = mesh_from(name, bm)
    obj.location = loc
    return finish(obj, mat)


def prism(name, outline, z0, z1, bevel=0.0, mat=None):
    """Extrude a closed 2D outline from z0 to z1."""
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, z0)) for x, y in outline]
    face = bm.faces.new(verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z = z1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=3, affect="EDGES", profile=0.5, clamp_overlap=True)
    return finish(mesh_from(name, bm), mat)


def band(name, outer, inner, z0, z1, bevel=0.0, mat=None, closed=True):
    """A strip between two matching polylines (a frame or an arch moulding)."""
    bm = bmesh.new()
    vo = [bm.verts.new((x, y, z0)) for x, y in outer]
    vi = [bm.verts.new((x, y, z0)) for x, y in inner]
    n = len(outer)
    for k in range(n if closed else n - 1):
        bm.faces.new((vo[k], vo[(k + 1) % n], vi[(k + 1) % n], vi[k]))
    ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z = z1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=3, affect="EDGES", profile=0.5, clamp_overlap=True)
    return finish(mesh_from(name, bm), mat)


def sphere(name, r, loc, scale=(1, 1, 1), mat=None, seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=seg // 2)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    return finish(obj, mat)


def cyl(name, r, depth, loc, rot=(0, 0, 0), mat=None, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat)


def torus(name, R, r, loc, rot=(0, 0, 0), mat=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=64, minor_segments=16)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat)


def cut(target, cutter):
    mod = target.modifiers.new("Cut", "BOOLEAN")
    mod.operation, mod.object, mod.solver = "DIFFERENCE", cutter, "EXACT"
    cutter.hide_render = True


def text(body, size, loc, mat, extrude=0.01, align="CENTER", bevel=0.004):
    curve = bpy.data.curves.new("T", "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = extrude
    curve.bevel_depth = bevel
    curve.align_x = align
    curve.align_y = "CENTER"
    obj = bpy.data.objects.new("T", curve)
    obj.location = loc
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def render(name, w, h, cam, ortho, samples=None):
    if ONLY and ONLY != name:
        return
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = w, h
    if samples:
        scene.cycles.samples = samples
    cam.ortho_scale = ortho
    scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
    print("wrote", OUT / name)


def arch(halfw, bottom, cy, n=24):
    """An arch-topped opening, bottom right going round anticlockwise to bottom left."""
    pts = [(halfw, bottom)]
    for k in range(n + 1):
        a = k * math.pi / n
        pts.append((math.cos(a) * halfw, cy + math.sin(a) * halfw))
    pts.append((-halfw, bottom))
    return pts


def wanted(name):
    return ONLY is None or ONLY == name


# 1. Mabel's window: 360x420 over 1.8 x 2.1 units. A mahogany booking-office front, an arched
#    gilt moulding, a brass grille, Mabel at her desk under a hanging lamp, the counter in front.
if wanted("booth_mabel.png"):
    scene, cam = reset(0.15)
    COUNTER, CY, HW = -0.66, 0.2, 0.54
    opening = arch(HW, COUNTER - 0.2, CY)
    # the front: a mahogany board with the arch cut through it
    front = box("Front", (1.8, 2.1, 0.12), (0, 0, 0.06), mat=wood("Y"))
    hole = prism("Hole", opening, -1, 1)
    cut(front, hole)
    # gilt arch moulding: a fat bead and a fine inner fillet
    band("Moulding", arch(HW + 0.1, COUNTER, CY), arch(HW, COUNTER, CY), 0.1, 0.17, 0.025, gilt(), closed=False)
    band("Fillet", arch(HW + 0.16, COUNTER, CY), arch(HW + 0.13, COUNTER, CY), 0.12, 0.15, 0.008, gilt(), closed=False)
    # keystone at the crown, engraved with the booking-office number
    box("Key", (0.16, 0.18, 0.06), (0, CY + HW + 0.05, 0.18), 0.02, mat=gilt())
    # the sign board over the window
    box("Sign", (1.2, 0.15, 0.04), (0, 0.97, 0.13), 0.015, mat=wood("X", (0.03, 0.01, 0.006), (0.08, 0.025, 0.015)))
    text("BOOKING  OFFICE", 0.085, (0, 0.965, 0.155), gilt(), extrude=0.008)
    # inside the booth: a dark green lincrusta wall and a rack of pigeonholes full of tickets
    wall = bumped(principled("Lincrusta", (0.02, 0.055, 0.04), roughness=0.5), 30, 0.4, 6)
    box("Back", (1.6, 2.0, 0.05), (0, 0, -1.0), mat=wall)
    shelf = wood("X", (0.05, 0.014, 0.008), (0.13, 0.04, 0.02))
    paper = principled("Ticket", (0.42, 0.33, 0.2), roughness=0.8)[0]
    for row in range(3):
        y = 0.52 - row * 0.17
        box("Shelf", (1.2, 0.025, 0.14), (0, y - 0.08, -0.92), mat=shelf)
        for col in range(7):
            x = -0.48 + col * 0.16
            if (row * 7 + col) % 4 != 2:  # a few empty holes
                box("Stub", (0.1, 0.07, 0.01), (x, y - 0.03, -0.9 + (col % 2) * 0.01), mat=paper)
    for col in range(8):
        box("Upright", (0.02, 0.52, 0.14), (-0.56 + col * 0.16, 0.36, -0.92), mat=shelf)
    # Mabel: half-moon spectacles, a green eyeshade, hair in a bun, a high collar
    skin = principled("Skin", (0.55, 0.33, 0.22), roughness=0.5)[0]
    hair = principled("Hair", (0.06, 0.035, 0.03), roughness=0.45)[0]
    dress = bumped(principled("Dress", (0.035, 0.012, 0.014), roughness=0.75), 90, 0.15)
    collar = principled("Collar", (0.36, 0.3, 0.2), roughness=0.7)[0]
    shade_mat = principled("Eyeshade", (0.02, 0.2, 0.1), roughness=0.2)
    shade_mat[3].inputs["Transmission Weight"].default_value = 0.6
    sphere("Body", 0.5, (0.04, -0.66, -0.55), (1.0, 0.55, 0.4), dress)
    cyl("Collar", 0.095, 0.12, (0.04, -0.33, -0.45), (math.radians(80), 0, 0), collar)
    cyl("Neck", 0.07, 0.2, (0.04, -0.24, -0.45), (math.radians(80), 0, 0), skin)
    sphere("Head", 0.19, (0.04, -0.04, -0.42), (0.85, 1.0, 0.9), skin)
    sphere("Hair", 0.205, (0.04, 0.02, -0.47), (0.92, 0.9, 0.85), hair)
    sphere("Bun", 0.09, (0.04, 0.22, -0.5), (1.1, 0.9, 0.9), hair)
    bpy.ops.mesh.primitive_cone_add(radius1=0.2, radius2=0.16, depth=0.05, location=(0.04, 0.07, -0.27), rotation=(math.radians(-80), 0, 0), vertices=48)
    finish(bpy.context.object, shade_mat[0])
    lens = principled("Lens", (0.9, 0.7, 0.4), metallic=1, roughness=0.15)[0]
    for sx in (-1, 1):
        torus("Spec", 0.05, 0.008, (0.04 + sx * 0.07, -0.06, -0.25), mat=lens)
    cyl("Bridge", 0.006, 0.05, (0.04, -0.05, -0.25), (0, math.radians(90), 0), lens)
    # the brooch and the punch on its chain
    sphere("Brooch", 0.028, (0.04, -0.4, -0.36), (1, 1, 0.5), gilt())
    # the hanging lamp: a brass shade with a lit mantle under it
    cyl("Rod", 0.008, 0.6, (-0.3, 0.86, -0.6), (math.radians(90), 0, 0), brass())
    bpy.ops.mesh.primitive_cone_add(radius1=0.16, radius2=0.04, depth=0.12, location=(-0.3, 0.56, -0.6), rotation=(math.radians(-90), 0, 0), vertices=48)
    finish(bpy.context.object, brass())
    sphere("Mantle", 0.06, (-0.3, 0.5, -0.6), mat=emit("Mantle", (1.0, 0.62, 0.25), 18))
    light("POINT", "Lamp", (-0.3, 0.42, -0.45), 60, (1.0, 0.6, 0.28), 0.06)
    light("SPOT", "Pool", (-0.3, 0.45, -0.3), 120, (1.0, 0.62, 0.3), 0.1, target=(0.04, -0.1, -0.42))
    # moon red through the window behind her, catching her right edge
    light("AREA", "Moon", (0.9, 0.1, -0.95), 25, (1.0, 0.16, 0.12), 0.6, target=(0.04, -0.1, -0.42))
    # the grille: brass bars, a rail, a sunburst in the arch and the slot above the counter
    bar = bumped(principled("Grille", (0.42, 0.28, 0.11), metallic=1, roughness=0.45), 40, 0.05)
    for k in range(-3, 3):  # spaced so her face sits between two bars
        x = 0.04 + (k + 0.5) * 0.26
        cyl("Bar", 0.01, 1.2, (x, CY - 0.18, 0.0), (math.radians(90), 0, 0), bar, 12)
    cyl("Rail", 0.016, 1.3, (0, CY, 0.01), (0, math.radians(90), 0), bar)
    cyl("Slot", 0.018, 1.3, (0, COUNTER + 0.22, 0.01), (0, math.radians(90), 0), bar)
    for k in range(1, 8):
        a = k * math.pi / 8
        L = HW
        cyl("Ray", 0.009, L, (math.cos(a) * L / 2, CY + math.sin(a) * L / 2, 0.0), (0, math.radians(90), a), bar, 12)
    torus("Hub", 0.07, 0.014, (0, CY, 0.02), mat=bar)
    # the bars stop at the slot rail, leaving the gap the money goes through
    trim = box("Trim", (1.4, 0.22, 0.4), (0, COUNTER + 0.1, 0.0))
    for obj in [o for o in scene.objects if o.name.startswith("Bar")]:
        cut(obj, trim)
    # the counter: a deep mahogany ledge with a brass nosing and a worn dip in the middle
    box("Counter", (1.8, 0.4, 0.3), (0, COUNTER - 0.2, 0.22), 0.03, mat=wood("X"))
    cyl("Nosing", 0.025, 1.8, (0, COUNTER, 0.37), (0, math.radians(90), 0), gilt())
    box("Tray", (0.42, 0.14, 0.03), (0, COUNTER - 0.15, 0.38), 0.03, mat=brass())
    # light on the front: a dim warm wash from the carriage lamps
    light("AREA", "Carriage", (-2, 3, 5), 160, (1.0, 0.72, 0.45), 3)
    light("AREA", "MoonFront", (3, -2, 3), 40, (1.0, 0.22, 0.15), 2)
    render("booth_mabel.png", 360, 420, cam, 2.1, 128)

# 2. Mahogany surround, 9-slice 256 (centre 64..192): mitred rails with grain along each one,
#    a gilt bead on the inner edge and gilt corner rosettes. Transparent middle.
if wanted("frame_mahogany.png"):
    scene, cam = reset()
    lamp_rig()
    O, I = 1.0, 0.56
    rails = {
        "Top": ([(-O, O), (O, O), (I, I), (-I, I)], "X"),
        "Bottom": ([(-O, -O), (-I, -I), (I, -I), (O, -O)], "X"),
        "Left": ([(-O, -O), (-O, O), (-I, I), (-I, -I)], "Y"),
        "Right": ([(O, -O), (I, -I), (I, I), (O, O)], "Y"),
    }
    for name, (pts, d) in rails.items():
        prism(name, pts, 0, 0.1, 0.01, wood(d))
    sq = lambda h: [(-h, -h), (h, -h), (h, h), (-h, h)]
    band("Bead", sq(0.64), sq(0.56), 0.1, 0.16, 0.022, gilt())
    band("Lip", sq(0.985), sq(0.94), 0.1, 0.13, 0.012, wood("X", (0.04, 0.01, 0.006), (0.1, 0.03, 0.016)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = (sx * 0.79, sy * 0.79)
            sphere("Boss", 0.06, (*c, 0.14), (1, 1, 0.6), gilt())
            torus("Ring", 0.1, 0.018, (*c, 0.12), mat=gilt())
            for k in range(4):
                a = k * math.pi / 2 + math.pi / 4
                sphere("Leaf", 0.05, (c[0] + math.cos(a) * 0.15, c[1] + math.sin(a) * 0.15, 0.12), (1.0, 0.45, 0.35), gilt()).rotation_euler.z = a
    render("frame_mahogany.png", 256, 256, cam, 2.0)

# 3. Engraved brass plate with screwed ends, 512x112 (slice the middle 96..416).
if wanted("plate_engraved.png"):
    scene, cam = reset(1.2)  # brushed brass needs something even to reflect
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.36, 0.2, 1)
    lamp_rig(500, 120)
    W, H = 3.92, 0.82
    face = bumped(principled("Brushed", (0.8, 0.58, 0.27), metallic=1, roughness=0.55), 60, 0.05)
    plate = box("Plate", (W, H, 0.1), (0, 0, 0), 0.05, 5, face)
    groove = box("Groove", (W - 0.36, H - 0.22, 0.2), (0, 0, 0.1))
    inner = box("Inner", (W - 0.42, H - 0.28, 0.4), (0, 0, 0.1))
    cut(groove, inner)
    groove.hide_render = True
    cut(plate, groove)
    inner.hide_render = True
    for sx in (-1, 1):
        head = cyl("Screw", 0.08, 0.06, (sx * (W / 2 - 0.12), 0, 0.06), mat=brass())
        slot = box("SlotCut", (0.18, 0.025, 0.1), (sx * (W / 2 - 0.12), 0, 0.1))
        slot.rotation_euler.z = math.radians(30 * sx)
        cut(head, slot)
    render("plate_engraved.png", 512, 112, cam, 4.0)

# 4. Leather blotter (recessed, a tooled gilt line), and the crew-pass card (same, brass rim).
for name, rim in (("blotter.png", False), ("card_leather.png", True)):
    if not wanted(name):
        continue
    scene, cam = reset()
    lamp_rig(700, 140)
    box("Leather", (1.98, 1.98, 0.08), (0, 0, 0), 0.07, 6, leather())
    sq = lambda h: [(-h, -h), (h, -h), (h, h), (-h, h)]
    band("Tooling", sq(0.82), sq(0.805), 0.04, 0.046, 0.0, gilt())
    band("Tooling2", sq(0.79), sq(0.785), 0.04, 0.044, 0.0, gilt())
    if rim:
        band("Rim", sq(1.0), sq(0.92), 0.0, 0.08, 0.02, brass())
    render(name, 256, 256, cam, 2.0)

# 5. Brass rim for plates (9-slice 128, centre 24..104): a plain bevelled ring, no rosettes.
if wanted("rim_brass.png"):
    scene, cam = reset()
    lamp_rig()
    sq = lambda h: [(-h, -h), (h, -h), (h, h), (-h, h)]
    band("Rim", sq(1.0), sq(0.8), 0, 0.08, 0.03, brass())
    band("Inner", sq(0.79), sq(0.76), 0, 0.03, 0.008, brass())
    render("rim_brass.png", 128, 128, cam, 2.0)

# 6. Signal lamp, lit and dark, 96px: amber glass dome in a brass bezel.
for name, lit in (("lamp_lit.png", True), ("lamp_dark.png", False)):
    if not wanted(name):
        continue
    scene, cam = reset()
    lamp_rig()
    torus("Bezel", 0.78, 0.13, (0, 0, 0), mat=brass())
    if lit:
        glass = emit("Lit", (0.95, 0.45, 0.1), 1.3)
    else:
        glass = principled("Dark", (0.12, 0.05, 0.02), roughness=0.08, coat=1.0)[0]
    sphere("Dome", 0.68, (0, 0, 0), (1, 1, 0.5), glass)
    sphere("Glint", 0.12, (-0.25, 0.28, 0.32), (1, 0.6, 0.3), emit("Glint", (1, 0.9, 0.7), 2 if lit else 0.6))
    render(name, 96, 96, cam, 2.0)

# 7. Tier arrows, 96px: a brass knob with a raised chevron (right; left is mirrored in Blender).
for name, sign in (("knob_right.png", 1), ("knob_left.png", -1)):
    if not wanted(name):
        continue
    scene, cam = reset()
    lamp_rig()
    knob = cyl("Knob", 0.9, 0.16, (0, 0, 0), mat=brass(), verts=64)
    knob.modifiers.new("B", "BEVEL").width = 0.05
    torus("Knurl", 0.86, 0.04, (0, 0, 0.06), mat=brass())
    tri = [(sign * 0.45, 0), (sign * -0.3, 0.42), (sign * -0.3, -0.42)]
    if sign < 0:
        tri = list(reversed(tri))
    prism("Arrow", tri, 0.08, 0.2, 0.04, principled("Dark", (0.09, 0.03, 0.02), roughness=0.35, coat=0.8)[0])
    render(name, 96, 96, cam, 2.0)

# 8. Company crest, 192px: a winged wheel in gilt.
if wanted("crest.png"):
    scene, cam = reset()
    lamp_rig(1000, 200)
    g = gilt()
    torus("Tyre", 0.36, 0.06, (0, 0, 0.05), mat=g)
    sphere("Hub", 0.09, (0, 0, 0.06), (1, 1, 0.6), g)
    for k in range(8):
        a = k * math.pi / 4
        box("Spoke", (0.6, 0.035, 0.035), (0, 0, 0.05), mat=g).rotation_euler.z = a
    for side in (-1, 1):
        for k in range(5):
            length = 0.34 + k * 0.08
            a = math.radians(10 + k * 14)
            x = side * (0.38 + length / 2 * math.cos(a))
            y = 0.06 + length / 2 * math.sin(a)
            f = sphere("Feather", 0.5, (x, y, 0.02 - k * 0.01), (length, 0.09, 0.04), g)
            f.rotation_euler.z = side * a
    render("crest.png", 192, 192, cam, 2.0)
