"""Close-up meshes for the Stalker (Builders/HollowBuilder stalker): skull, hand, forearm, sleeve, coat skirt.

The bounded pass built the Stalker from blocks and cylinders; seen at arm's length (a grab) it read as stick
arms, a flat coat and a block skull. These are single meshes, one colour each (the builder sets Color), built
from lofted tubes and a carved sphere. Performance keeps the old blocks (Builders/HollowBuilder tags them
DetailFallback).

  blender -b --python tools/stalker/build.py [-- --no-render]

Writes assets/stalker/<name>.fbx (+ .obj), tools/stalker/out/report.json (size in studs, triangles) and
tools/stalker/out/sheet.png. Axes: +Y up, front -Z. Arm bones run along X, proximal end at +X (the joint).
One Blender unit = one stud.
"""

import json
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "stalker"
OUT = ROOT / "tools" / "stalker" / "out"
ASSETS.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def to_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def tube(bm, pts, radii, sides=8, flat=1.0, close_end=True, twist=0.0):
    """Loft an elliptical ring (radius r, depth r*flat in local Z of the path) along pts."""
    rings = []
    n = len(pts)
    for i, (p, r) in enumerate(zip(pts, radii)):
        p = Vector(p)
        a = Vector(pts[min(i + 1, n - 1)]) - Vector(pts[max(i - 1, 0)])
        a.normalize()
        up = Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((1, 0, 0))
        u = a.cross(up).normalized()
        v = a.cross(u).normalized()
        ring = []
        for s in range(sides):
            t = s / sides * math.tau + twist * i
            ring.append(bm.verts.new(p + u * (math.cos(t) * r) + v * (math.sin(t) * r * flat)))
        rings.append(ring)
    for i in range(n - 1):
        for s in range(sides):
            bm.faces.new((rings[i][s], rings[i][(s + 1) % sides], rings[i + 1][(s + 1) % sides], rings[i + 1][s]))
    if close_end:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    return rings


def finish(obj, smooth=True, subdiv=0, decimate=None):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if subdiv:
        m = obj.modifiers.new("s", "SUBSURF")
        m.levels = subdiv
        m.render_levels = subdiv
        bpy.ops.object.modifier_apply(modifier=m.name)
    if decimate:
        m = obj.modifiers.new("d", "DECIMATE")
        m.ratio = decimate
        bpy.ops.object.modifier_apply(modifier=m.name)
    # built in Roblox axes (+Y up, front -Z); relabel to Blender's (+Z up, front -Y) so the exporter maps it back
    for v in obj.data.vertices:
        v.co = Vector((v.co.x, v.co.z, v.co.y))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


# ------------------------------------------------------------------ skull
def skull():
    """The head block is 0.82 x 1.4 x 0.98: a narrow, long skull, face toward -Z, skin drawn tight over bone."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=72, v_segments=52, radius=0.5)
    gauss = lambda d2, w: math.exp(-d2 / (w * w))
    for v in bm.verts:
        x, y, z = v.co
        # a long narrow egg: 0.8 wide, 1.4 tall, 0.98 deep
        x *= 0.76
        y *= 1.46
        z *= 0.98
        front = z < 0  # the face side
        if front:
            f = -z / 0.49  # 0..1 toward the face
            # the brow ridge over the sockets
            y_n = y / 0.7
            x += 0
            z -= 0.1 * gauss((y - 0.3) ** 2, 0.13) * f
            for sx in (-0.2, 0.2):
                # sockets: deep dents, a little slanted
                dy = y - (0.17 + (0.02 if sx > 0 else 0.02) * 0)
                z += 0.5 * gauss((x - sx) ** 2 + (dy * 1.05) ** 2, 0.105) * f
                z -= 0.05 * gauss((x - sx) ** 2 + (dy * 1.05) ** 2, 0.2) * f  # the bony rim round the socket
                # the cheekbone under each socket, the cheek fallen in below it
                z -= 0.1 * gauss((x - sx * 1.75) ** 2 + (y + 0.02) ** 2, 0.1) * f
                z += 0.2 * gauss((x - sx * 1.2) ** 2 + (y + 0.25) ** 2, 0.14) * f
                # the temples fallen in, the skin drawn tight to the bone
                z += 0.07 * gauss((x - sx * 2.0) ** 2 + (y - 0.22) ** 2, 0.14) * f
                # temple hollows
                x -= sx * 0.0
            # nose: a collapsed bridge, the nostrils a pit
            z -= 0.05 * gauss(x ** 2 + (y - 0.0) ** 2, 0.06) * f
            z += 0.2 * gauss((x / 0.8) ** 2 + (y + 0.09) ** 2, 0.07) * f
            # the grin: a wide dark pit cut into the face, the jaw drops from it
            z += 0.32 * math.exp(-((x / 0.24) ** 2 + ((y + 0.47) / 0.06) ** 2)) * f
            # the mouth area: a flat sunken plane where the grin sits
            z += 0.06 * gauss(x ** 2 + (y + 0.5) ** 2, 0.25) * f
        # the skull's back swells; a tight dome at the crown
        if y > 0.2:
            z += 0.04 * (y - 0.2)
        # taper the chin
        if y < -0.35:
            s = 1 - 0.7 * ((-y - 0.35) / 0.35)
            x *= max(s, 0.38)
            z *= max(0.5 + 0.5 * s, 0.6)
        # veins and sinew: a little noise
        rng_n = math.sin(x * 31 + y * 17) * math.cos(z * 23 + y * 11)
        # skin stretched in cords over the jaw and brow
        cord = 0.014 * math.sin(x * 55 + y * 6) * (1 if front else 0) * max(0.0, min(0.25, -y - 0.1))
        v.co = Vector((x, y, z - cord)) * (1 + 0.02 * rng_n)
    return finish(to_object("stalker_head", bm), subdiv=0)


# ------------------------------------------------------------------ hand
def hand():
    """Wrist at +0.25 Y, long knuckled fingers hanging to -1.4: an arm's too-long hand, thumb to the inside."""
    bm = bmesh.new()
    # palm: a flattened lump
    tube(bm, [(0, 0.22, 0), (0, 0.0, 0), (0, -0.28, 0)], [0.13, 0.2, 0.19], sides=10, flat=0.55)
    fingers = [(-0.15, 1.05, -4), (-0.05, 1.25, -1), (0.05, 1.2, 1), (0.15, 0.95, 4)]
    for x, length, curl in fingers:
        pts, rad = [], []
        segs = [0.3, 0.38, 0.32]
        y = -0.22
        z = 0.0
        ang = math.radians(curl)
        for i in range(4):
            pts.append((x + math.sin(ang) * (-y - 0.22) * 0.1, y, z))
            rad.append([0.05, 0.043, 0.036, 0.022][i])
            if i < 3:
                y -= segs[i] * (length / 1.0) * 0.98 / 1.0 * (1.0 if i < 2 else 0.7)
                z -= 0.03 * (i + 1) if i else 0.0  # curl toward the front
        tube(bm, pts, rad, sides=6, flat=0.85)
        # a knuckle on each joint
        for i in (1, 2):
            bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=rad[i] * 1.35,
                                      matrix=__import__("mathutils").Matrix.Translation(pts[i]))
        # the claw: a thin nail curling past the tip
        tip = Vector(pts[-1])
        tube(bm, [tip, tip + Vector((0, -0.07, -0.03)), tip + Vector((0, -0.14, -0.08))], [0.026, 0.017, 0.004], sides=5, flat=0.6)
    # the thumb, short, angled in
    tube(bm, [(0.17, 0.0, 0.0), (0.27, -0.2, -0.06), (0.3, -0.42, -0.1), (0.29, -0.55, -0.14)],
         [0.06, 0.048, 0.04, 0.02], sides=6, flat=0.8)
    obj = finish(to_object("stalker_hand", bm), subdiv=0)
    return obj


def hand_left():
    """The same hand mirrored, the thumb on the other side, for the left arm."""
    obj = hand()
    obj.name = obj.data.name = "stalker_handL"
    for v in obj.data.vertices:
        v.co.x = -v.co.x
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


# ------------------------------------------------------------------ arms
def forearm(length=2.75, d=0.32 * 0.82):
    """Along X, wrist at -X end... proximal (elbow) at +X: a bony forearm with ridged tendons and a knobbed elbow and wrist."""
    bm = bmesh.new()
    n = 14
    pts, rad = [], []
    for i in range(n):
        t = i / (n - 1)  # 0 distal (-X) .. 1 proximal (+X)
        x = -length / 2 + t * length
        r = d / 2 * (0.62 + 0.55 * t)  # wrist thin, elbow thick
        r *= 1 + 0.14 * math.exp(-((t - 0.97) / 0.06) ** 2)  # elbow knob
        r *= 1 + 0.2 * math.exp(-((t - 0.04) / 0.05) ** 2)  # wrist knob
        r *= 1 + 0.07 * math.sin(t * 38)  # sinew ridges
        pts.append((x, 0, 0))
        rad.append(r)
    tube(bm, pts, rad, sides=9, flat=0.9, twist=0.12)
    return finish(to_object("stalker_forearm", bm), subdiv=0)


def sleeve(length=2.9, d=0.32):
    """The coat sleeve over the upper arm: wide at the shoulder, frayed ragged cuff at the elbow end (-X)."""
    bm = bmesh.new()
    n = 12
    pts, rad = [], []
    for i in range(n):
        t = i / (n - 1)  # 0 cuff (-X) .. 1 shoulder (+X)
        x = -length / 2 + t * length
        r = d / 2 * (0.9 + 0.45 * t)
        r *= 1 + 0.06 * math.sin(t * 25 + 1.0)  # creases
        pts.append((x, 0, 0))
        rad.append(r)
    rings = tube(bm, pts, rad, sides=10, flat=0.95, close_end=True)
    # fray the cuff: drag every other cuff vertex out along the arm
    rnd = random.Random(7)
    for k, v in enumerate(rings[0]):
        v.co.x -= rnd.uniform(0.05, 0.4) * (1 if k % 2 else 0.35)
        v.co.y *= 1.05
    for k, v in enumerate(rings[1]):
        v.co.x -= rnd.uniform(0.0, 0.1)
    # torn strips hanging off the cuff
    cuff = [Vector(v.co) for v in rings[0]]
    for k in range(0, len(cuff), 2):
        a = cuff[k]
        b = cuff[(k + 1) % len(cuff)]
        mid = (a + b) / 2
        tip = mid + Vector((-rnd.uniform(0.25, 0.55), rnd.uniform(-0.05, 0.05), rnd.uniform(-0.03, 0.03)))
        bm.faces.new((bm.verts.new(a), bm.verts.new(b), bm.verts.new(tip)))
        bm.faces.new((bm.verts.new(b), bm.verts.new(a), bm.verts.new(tip)))
    return finish(to_object("stalker_sleeve", bm), subdiv=0)


# ------------------------------------------------------------------ coat
def coat():
    """The skirt of the greatcoat, in the pelvis frame: five tails behind (long and short), a torn rag each side at the
    front, a hem that bows out and hangs ragged. Thin cloth with thickness so it holds from both sides."""
    bm = bmesh.new()
    rnd = random.Random(11)
    top = -0.45

    def strip(x, z, width, length, bow, lean, taper, zig):
        cols = 3
        rows = 9
        grid = []
        for r in range(rows):
            t = r / (rows - 1)
            y = top - t * length
            w = width * (1 - taper * t)
            zz = z + bow * math.sin(t * math.pi * 0.9) + lean * t
            row = []
            for c in range(cols):
                u = c / (cols - 1) - 0.5
                xx = x + u * w + (zig * t * math.sin(t * 9 + x * 5)) * 0.05
                # the ragged hem: a point at the bottom, uneven
                yy = y - (0.0 if r < rows - 1 else rnd.uniform(0.0, 0.3) * (1 - abs(u) * 1.2))
                row.append(bm.verts.new((xx, yy, zz + 0.02 * math.sin(c * 2 + r))))
            grid.append(row)
        for r in range(rows - 1):
            for c in range(cols - 1):
                bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
        # thickness: a second skin 0.05 behind, so it reads from both sides
        grid2 = [[bm.verts.new(v.co + Vector((0, 0, 0.05))) for v in row] for row in grid]
        for r in range(rows - 1):
            for c in range(cols - 1):
                bm.faces.new((grid2[r][c + 1], grid2[r][c], grid2[r + 1][c], grid2[r + 1][c + 1]))
        for r in range(rows - 1):  # side walls
            bm.faces.new((grid[r][0], grid[r + 1][0], grid2[r + 1][0], grid2[r][0]))
            bm.faces.new((grid[r + 1][-1], grid[r][-1], grid2[r][-1], grid2[r + 1][-1]))
        bm.faces.new((grid[-1][1], grid[-1][0], grid2[-1][0], grid2[-1][1]))
        bm.faces.new((grid[-1][-1], grid[-1][1], grid2[-1][1], grid2[-1][-1]))

    # seven tails behind, narrower and of every length, each tapering to a ragged point
    lengths = [3.9, 2.2, 3.4, 2.7, 3.8, 1.9, 3.2]
    for i, x in enumerate([-0.78, -0.52, -0.26, 0.0, 0.26, 0.52, 0.78]):
        strip(x, 0.42 + i * 0.008, 0.3, lengths[i], 0.05 + 0.03 * (i % 3), 0.2 + 0.03 * (i % 4), 0.55, 1.6)
    for s in (-1, 1):  # the front rags, torn to long strips
        strip(s * 0.62, -0.46, 0.26, 3.3, -0.04, -0.12, 0.6, 2.0)
        strip(s * 0.4, -0.47, 0.18, 2.1, -0.03, -0.08, 0.7, 2.4)
    # shreds that hang loose below the torn hem
    for i, x in enumerate([-0.62, -0.18, 0.3, 0.64]):
        strip(x, 0.46, 0.1, 1.2, 0.02, 0.1, 0.8, 3.0)
    # a waist band of cloth to hide the joins
    tube(bm, [(0, top + 0.05, 0), (0, top - 0.2, 0)], [0.8, 0.82], sides=16, flat=0.6, close_end=False)
    return finish(to_object("stalker_coat", bm), smooth=False)


def export(obj, report):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # centre on the bounding box (the builder offsets it), +Y up, front -Z
    bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    mid = (lo + hi) / 2
    # keep the original origin, and report where the box centre sits in that frame
    report[obj.name] = {
        "size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
        "center": [round(mid.x, 3), round(mid.z, 3), round(mid.y, 3)],
        "tris": len(obj.data.polygons),
    }
    for v in obj.data.vertices:
        v.co -= mid
    path = ASSETS / f"{obj.name}"
    bpy.ops.wm.obj_export(filepath=str(path) + ".obj", export_selected_objects=True, forward_axis="NEGATIVE_Z", up_axis="Y")
    bpy.ops.export_scene.fbx(filepath=str(path) + ".fbx", use_selection=True, axis_forward="-Z", axis_up="Y",
                             apply_unit_scale=True, global_scale=1.0)


def sheet(objs):
    bpy.context.scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = 1200, 600
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.06, 1)
    sc.world = world
    colors = {"stalker_head": (0.71, 0.70, 0.63), "stalker_hand": (0.45, 0.12, 0.12), "stalker_handL": (0.45, 0.12, 0.12), "stalker_forearm": (0.71, 0.70, 0.63),
              "stalker_sleeve": (0.17, 0.16, 0.15), "stalker_coat": (0.17, 0.16, 0.15)}
    x = -5.8
    for o in objs:
        o.location = Vector((x, 0, 0)) + Vector((0, 0, 0))
        mat = bpy.data.materials.new(o.name)
        mat.diffuse_color = (*colors[o.name], 1)
        o.data.materials.append(mat)
        x += 2.3
    for loc, e in ((( 4, -8, 6), 1000), ((-6, -6, 2), 400)):
        ld = bpy.data.lights.new("l", "SUN" if e == 1000 else "POINT")
        ld.energy = 5 if e == 1000 else 2000
        lo = bpy.data.objects.new("l", ld)
        lo.location = loc
        lo.rotation_euler = (math.radians(55), 0, math.radians(25))
        sc.collection.objects.link(lo)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 15
    cam.location = (0, -12, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.filepath = str(OUT / "sheet.png")
    bpy.ops.render.render(write_still=True)


def main():
    clear()
    report = {}
    objs = [skull(), hand(), hand_left(), forearm(), sleeve(), coat()]
    for o in objs:
        export(o, report)
    (OUT / "report.json").write_text(json.dumps(report, indent=1))
    print(json.dumps(report))
    if "--no-render" not in sys.argv:
        sheet(objs)


main()
