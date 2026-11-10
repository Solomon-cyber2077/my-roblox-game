"""Tree crowns for the station trees (Builders/StationDressing Oak, Elm, Poplar, Birch).

The crowns were 2-6 Part balls each (432 triangles a ball, whatever its size). These are single meshes
of a few hundred triangles that keep each species' shape: a broad, clumped oak dome; a billowing elm;
the Lombardy poplar's tall flame; a light, drooping birch. Built from leaf masses (metaballs) melted
into one skin, roughened at clump scale, then reduced. No texture image: in game each crown takes the
tree's own foliage colour and the LeafyGrass material, so the palette stays as it is.

  blender -b --python tools/trees/build.py [-- --no-render]

Writes assets/trees/<name>.obj (centred on its bounding box, +Y up, front -Z), tools/trees/out/
report.json (triangles, proportions) and, unless --no-render, tools/trees/out/compare.png: each crown
as balls (before) and as a mesh (after), same trunk and colour.
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
ASSETS = ROOT / "assets" / "trees"
OUT = ROOT / "tools" / "trees" / "out"


def oak(rng, flat):
    """A broad dome, wider than tall, in separate heavy clumps with a ragged underside."""
    lobes = [((0, 0.08, 0), 0.42), ((0, 0.2, 0), 0.36)]
    for i in range(12):
        a = i / 12 * math.tau + rng.uniform(-0.2, 0.2)
        up = rng.uniform(-0.1, 0.8)
        r = 0.48 * math.cos(up * 0.95)
        lobes.append(((math.cos(a) * r, up * 0.34 * flat, math.sin(a) * r), rng.uniform(0.2, 0.28)))
    for _ in range(5):  # clumps hanging lower at the rim, the oak's ragged skirt
        a = rng.uniform(0, math.tau)
        lobes.append(((math.cos(a) * 0.5, rng.uniform(-0.2, -0.08), math.sin(a) * 0.5), rng.uniform(0.14, 0.19)))
    return lobes


def elm(rng):
    """Billowing clouds piled on each other, wider than tall as the game's elm stands."""
    lobes = [((0, 0.0, 0), 0.34), ((0.18, 0.08, 0.05), 0.32), ((-0.1, 0.14, -0.08), 0.3)]
    for i in range(12):
        a = rng.uniform(0, math.tau)
        y = rng.uniform(-0.12, 0.28)
        r = rng.uniform(0.28, 0.46)
        lobes.append(((math.cos(a) * r + 0.06, y, math.sin(a) * r * 0.9), rng.uniform(0.17, 0.25)))
    return lobes


def poplar(rng):
    """The Lombardy poplar: a tight flame, widest a third of the way up, to a point."""
    lobes = []
    for i in range(24):
        t = i / 23
        width = 0.5 * math.sin(math.pi * min(1, t ** 0.75)) * (1 - 0.3 * t)
        a = rng.uniform(0, math.tau)
        off = width * rng.uniform(0.1, 0.3)
        lobes.append(((math.cos(a) * off, -1.25 + t * 2.6, math.sin(a) * off), max(0.09, width * rng.uniform(0.75, 0.95))))
    return lobes


def birch(rng):
    """Light and open: many small clumps round a main mass and a smaller one beside it, outer ones drooping."""
    lobes = [((0, 0.08, 0), 0.32), ((0.2, -0.12, 0.06), 0.24)]
    for i in range(18):
        a = rng.uniform(0, math.tau)
        y = rng.uniform(-0.38, 0.42)
        r = 0.34 * math.sqrt(max(0.05, 1 - (y / 0.5) ** 2))
        droop = -0.05 if r > 0.24 else 0
        lobes.append(((math.cos(a) * r * 0.85 + 0.05, y + droop, math.sin(a) * r * 0.85), rng.uniform(0.13, 0.17)))
    return lobes


# name: (lobes, triangles to keep, how lumpy, clump size)
CROWNS = {
    "crown_oak_a": (lambda: oak(random.Random(1), 1.0), 640, 0.035, 0.09),
    "crown_oak_b": (lambda: oak(random.Random(2), 0.85), 640, 0.035, 0.09),
    "crown_elm": (lambda: elm(random.Random(3)), 600, 0.035, 0.09),
    "crown_poplar": (lambda: poplar(random.Random(4)), 480, 0.015, 0.05),
    "crown_birch": (lambda: birch(random.Random(5)), 520, 0.025, 0.06),
}

# The game's balls (Builders/StationDressing), centred in their box and scaled to width 1: (centre, diameter)
def _before(balls):
    lo = [min(c[i] - d / 2 for c, d in balls) for i in range(3)]
    hi = [max(c[i] + d / 2 for c, d in balls) for i in range(3)]
    mid = [(lo[i] + hi[i]) / 2 for i in range(3)]
    w = max(hi[0] - lo[0], hi[2] - lo[2])
    return [(tuple((c[i] - mid[i]) / w for i in range(3)), d / w) for c, d in balls]


_oak = [((0, 0.3, 0), 1.0)] + [((math.cos(k / 5 * math.tau) * 0.36, 0.24, math.sin(k / 5 * math.tau) * 0.36), 0.69) for k in range(1, 6)]
BEFORE = {
    "crown_oak_a": _before(_oak),
    "crown_oak_b": _before(_oak),
    "crown_elm": _before([((0, 0.28, 0), 0.38), ((0.14, 0.28, 0), 0.38)]),
    "crown_poplar": _before([((0, 0.32 + i * 0.17, 0), 0.26 - i * 0.04) for i in range(4)]),
    "crown_birch": _before([((0, 0.78, 0), 0.44), ((0.12, 0.62, 0.06), 0.3)]),
}

# The box each crown fills in game today (Builders/StationDressing), as height / width: the mesh is
# sized into that same box so trees keep their place in a shot.
BOX = {"crown_oak_a": 0.7, "crown_oak_b": 0.7, "crown_elm": 0.73, "crown_poplar": 2.73, "crown_birch": 1.08}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def crown(name, lobes, tris, lump, clump):
    parts = []
    for (x, y, z), r in lobes:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=r, location=(x, -z, y))  # Blender is Z up
        parts.append(bpy.context.object)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    ob = bpy.context.object
    ob.name = name
    # one skin over the union of the clumps
    rem = ob.modifiers.new("skin", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = 0.018
    bpy.ops.object.modifier_apply(modifier="skin")
    # leaf clumps: the skin bulges and dents at clump scale, so it never reads as a smooth balloon
    tex = bpy.data.textures.new(name + "_clumps", "VORONOI")
    tex.noise_scale = clump
    disp = ob.modifiers.new("clumps", "DISPLACE")
    disp.texture = tex
    disp.strength = lump * 2
    disp.mid_level = 0.5
    bpy.ops.object.modifier_apply(modifier="clumps")
    sm = ob.modifiers.new("soften", "SMOOTH")
    sm.factor, sm.iterations = 0.5, 2
    bpy.ops.object.modifier_apply(modifier="soften")
    dec = ob.modifiers.new("reduce", "DECIMATE")
    dec.ratio = min(1.0, tris / max(1, 2 * len(ob.data.polygons)))  # the remesh gives quads: two triangles each
    bpy.ops.object.modifier_apply(modifier="reduce")
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    for p in ob.data.polygons:
        p.use_smooth = True
    # texture coordinates, so the game's LeafyGrass material tiles over the crown instead of smearing
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=0.35)
    bpy.ops.object.mode_set(mode="OBJECT")
    # centre on the bounding box and scale into the game's box: width 1, height BOX[name]
    lo = Vector([min(v.co[i] for v in ob.data.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in ob.data.vertices) for i in range(3)])
    mid, size = (lo + hi) / 2, hi - lo
    w = max(size.x, size.y)
    k = Vector((1 / w, 1 / w, BOX[name] / size.z))
    for v in ob.data.vertices:
        v.co = (v.co - mid) * k
    size = Vector((size.x * k.x, size.y * k.y, size.z * k.z))
    return ob, {"tris": len(ob.data.polygons), "size_xyz_up": [round(size.x, 3), round(size.z, 3), round(size.y, 3)]}


def export(ob):
    ASSETS.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.wm.obj_export(filepath=str(ASSETS / f"{ob.name}.obj"), export_selected_objects=True,
                          forward_axis="NEGATIVE_Z", up_axis="Y", export_materials=False, export_normals=True,
                          export_uv=True)


def render(made):
    """Each crown twice on one trunk, balls (left) and mesh (right), in a row."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.device = "CPU"
    sc.render.resolution_x, sc.render.resolution_y = 1600, 520
    sc.render.resolution_percentage = 50
    leaf = bpy.data.materials.new("leaf")
    leaf.use_nodes = True
    nt = leaf.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (50 / 255, 64 / 255, 44 / 255, 1)
    bsdf.inputs["Roughness"].default_value = 0.9
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 40
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    bark = bpy.data.materials.new("bark")
    bark.use_nodes = True
    bark.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.09, 0.07, 1)
    for ob, _ in made.values():
        ob.hide_render = True  # the originals sit at the origin; the row uses copies
    x = 0.0
    for name, (ob, lobes) in made.items():
        w = ob.dimensions.x
        for side, dx in (("balls", 0.0), ("mesh", 1.25 * w)):
            at = Vector((x + dx, 0, 0))
            bpy.ops.mesh.primitive_cylinder_add(radius=0.04 * w, depth=0.9 * w, location=at + Vector((0, 0, -0.35 * ob.dimensions.z - 0.45 * w)))
            bpy.context.object.data.materials.append(bark)
            if side == "balls":  # the crown as the game builds it today, in the same box
                for (bx, by, bz), d in BEFORE[name]:
                    bpy.ops.mesh.primitive_uv_sphere_add(radius=d / 2 * w, location=at + Vector((bx, -bz, by)) * w)
                    bpy.ops.object.shade_smooth()
                    bpy.context.object.data.materials.append(leaf)
            else:
                dup = ob.copy()
                dup.hide_render = False
                dup.data = ob.data.copy()
                dup.data.materials.append(leaf)
                dup.location = at
                sc.collection.objects.link(dup)
        x += 2.7 * w
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = x * 1.02
    cam.location = (x / 2 - 0.35, -20, 0.1)
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(20), math.radians(30))
    sc.collection.objects.link(sun)
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.6, 0.65, 1)
    sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    OUT.mkdir(parents=True, exist_ok=True)
    sc.render.filepath = str(OUT / "compare.png")
    bpy.ops.render.render(write_still=True)


def main():
    clear()
    report, made = {}, {}
    for name, (make, tris, lump, clump) in CROWNS.items():
        lobes = make()
        ob, info = crown(name, lobes, tris, lump, clump)
        export(ob)
        report[name] = info
        made[name] = (ob, lobes)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "report.json").write_text(json.dumps(report, indent=1))
    print(json.dumps(report))
    if "--no-render" not in sys.argv:
        render(made)


main()
