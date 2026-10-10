"""
Loads the measured train (dump_train.luau JSON) into Blender as boxes and cylinders, for
modelling against and for before/after elevations.

Roblox train space -> Blender: (x, y, z) -> (x, -z, y). Blender Z is up, studs throughout.
"""

import json

import bpy
from mathutils import Matrix, Vector


def rb_to_bl(v):
    return Vector((v[0], -v[2], v[1]))


# Roblox basis change as a 4x4 (rows map Roblox axes to Blender axes)
BASIS = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def part_matrix(p):
    c = p["cf"]
    m = Matrix(
        (
            (c[3], c[4], c[5], c[0]),
            (c[6], c[7], c[8], c[1]),
            (c[9], c[10], c[11], c[2]),
            (0, 0, 0, 1),
        )
    )
    return BASIS @ m @ BASIS.inverted()


def load(path, x_range=None, collection_name="REF"):
    parts = json.load(open(path))
    col = bpy.data.collections.new(collection_name)
    bpy.context.scene.collection.children.link(col)
    mats = {}
    cube = bpy.data.meshes.new("refcube")
    import bmesh

    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bm.to_mesh(cube)
    bm.free()
    cyl = bpy.data.meshes.new("refcyl")
    bm = bmesh.new()
    # Roblox cylinders run along their local X
    bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.5, radius2=0.5, depth=1)
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(1.5707963, 4, "Y"))
    bm.to_mesh(cyl)
    bm.free()
    out = []
    for p in parts:
        x = p["cf"][0]
        if x_range and not (x_range[0] <= x <= x_range[1]):
            continue
        if p["transparency"] >= 0.99:
            continue
        key = (tuple(p["color"]), p["material"])
        if key not in mats:
            m = bpy.data.materials.new(f"ref_{len(mats)}")
            m.diffuse_color = (*[c / 255 for c in p["color"]], 1 - min(p["transparency"], 0.8))
            mats[key] = m
        mesh = cyl if p["shape"] == "Cylinder" else cube
        ob = bpy.data.objects.new(p["name"], mesh.copy() if False else mesh)
        ob.matrix_world = part_matrix(p)
        s = p["size"]
        # scale in Roblox-local axes (x, y, z) -> Blender local (x, -z, y) keeps magnitudes
        ob.scale = (s[0], s[2], s[1])
        ob.color = mats[key].diffuse_color
        col.objects.link(ob)
        out.append((ob, p))
    return out
