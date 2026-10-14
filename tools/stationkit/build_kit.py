"""
Station kit for Last Train Out (fix pass part 3), built headless:

    blender --background --factory-startup --python tools/stationkit/build_kit.py -- <out_dir> [preview.png] [--only=Name]

--only=Name exports that one piece to <out_dir>/<Name>.fbx and updates only its entry in
StationKit.json (StationKit.fbx and the .blend are left alone), so one piece can be re-uploaded.

Modular pieces the stations reuse, one object (one MeshPart) each, sized in studs to stand
exactly where the primitive builders put theirs (StationDressing, StructureKit), origin at the
piece's foot centre (moved to the bounding-box centre on export, like the train's meshes), -Z
toward the train:

  GasLamp      the yard lamp: plinth, fluted post, ladder bar, lantern frame and cap
               (its glass stays a Neon primitive, so it glows and carries the light)
  HazardRail   12 studs of the sinkhole edge's rail: post, top and mid rails, painted
               yellow and black in diagonal bands (collision stays on the primitives)
  FencePicket  12 studs of picket fence laid out like StationDressing's primitives (posts every 3
               studs, two rails, a pointed picket per stud clear of the posts) and nothing you
               cannot see (no bottoms, no rail ends, no 0.1-stud picket edges): 122 tris; the
               primitives average 12.2 blocks (146 tris) a tile once gaps and fallen pickets go
  Crate        4 x 4 x 4 plank crate with battens and corner irons
  SignBoard    an enamel name board, 8 wide, on two posts
  WallBrick    a 12 x 12 brick wall module with a window opening, sill and lintel
  RoofSlate    one 12-wide bay of a pitched slate roof (6 deep each side), ridge and rows

Colours are vertex colours: give each MeshPart a white Color so they show unchanged.
Units: 1 Blender unit = 1 stud. Export follows tools/trainshell/export.py (turned 180 degrees
about the vertical first, because Studio's importer turns it back).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
ONLY = next((a.split("=", 1)[1] for a in args if a.startswith("--only=")), None)
args = [a for a in args if not a.startswith("--only=")]
OUT_DIR = args[0] if args else "."
PREVIEW = args[1] if len(args) > 1 else None


def rgb(r, g, b):
    return (r / 255, g / 255, b / 255, 1.0)


IRON = rgb(36, 38, 42)
IRON_LIGHT = rgb(58, 60, 66)
HAZARD = rgb(226, 182, 58)
HAZARD_DARK = rgb(26, 24, 22)
RED = rgb(170, 40, 32)
PAINT = rgb(184, 190, 192)
WOOD = rgb(104, 78, 54)
WOOD_DARK = rgb(70, 50, 36)
BRICK = rgb(122, 74, 58)
BRICK_DARK = rgb(92, 56, 44)
STONE = rgb(176, 166, 150)
SLATE = rgb(58, 60, 66)
SLATE_DARK = rgb(44, 46, 52)
ENAMEL = rgb(24, 58, 54)
ENAMEL_EDGE = rgb(204, 222, 234)

bpy.ops.wm.read_factory_settings(use_empty=True)
pieces = {}


class Piece:
    """Collects boxes, cylinders and wedges into one bmesh with vertex colours."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")

    def _paint(self, faces, color):
        for face in faces:
            for loop in face.loops:
                loop[self.col] = color

    def box(self, size, at, color, rot=(0, 0, 0)):
        geom = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = geom["verts"]
        m = (
            Matrix.Translation(Vector(at))
            @ Matrix.Rotation(math.radians(rot[2]), 4, "Z")
            @ Matrix.Rotation(math.radians(rot[1]), 4, "Y")
            @ Matrix.Rotation(math.radians(rot[0]), 4, "X")
            @ Matrix.Diagonal(Vector((size[0], size[1], size[2], 1)))
        )
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        self._paint({f for v in verts for f in v.link_faces}, color)

    def cyl(self, radius, height, at, color, segments=10, axis="Z"):
        geom = bmesh.ops.create_cone(
            self.bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=height
        )
        verts = geom["verts"]
        rot = Matrix.Identity(4)
        if axis == "X":
            rot = Matrix.Rotation(math.pi / 2, 4, "Y")
        elif axis == "Y":
            rot = Matrix.Rotation(math.pi / 2, 4, "X")
        bmesh.ops.transform(self.bm, matrix=Matrix.Translation(Vector(at)) @ rot, verts=verts)
        self._paint({f for v in verts for f in v.link_faces}, color)

    def cone(self, r1, r2, height, at, color, segments=10):
        geom = bmesh.ops.create_cone(
            self.bm, cap_ends=True, segments=segments, radius1=r1, radius2=r2, depth=height
        )
        verts = geom["verts"]
        bmesh.ops.transform(self.bm, matrix=Matrix.Translation(Vector(at)), verts=verts)
        self._paint({f for v in verts for f in v.link_faces}, color)

    def faces(self, polys, centre, color):
        """Faces from corner lists, each turned to face away from the (convex) solid's centre."""
        made = []
        for poly in polys:
            face = self.bm.faces.new([self.bm.verts.new(Vector(c)) for c in poly])
            face.normal_update()
            if (face.calc_center_median() - Vector(centre)).dot(face.normal) < 0:
                face.normal_flip()
            made.append(face)
        self._paint(made, color)

    def open_box(self, size, at, color, skip=("bottom",)):
        """A box without the faces in `skip` (bottom, top, left, right, front, back)."""
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        x0, x1 = at[0] - hx, at[0] + hx
        y0, y1 = at[1] - hy, at[1] + hy
        z0, z1 = at[2] - hz, at[2] + hz
        sides = {
            "bottom": [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
            "top": [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
            "left": [(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)],
            "right": [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
            "front": [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
            "back": [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
        }
        self.faces([c for name, c in sides.items() if name not in skip], at, color)

    def picket(self, x, width, height, point, y, depth, z0, color):
        """A flat picket with a pointed top: faces, back and the two slopes, 10 tris (its edges
        are too thin to see)."""
        w = width / 2
        outline = [(x - w, z0), (x + w, z0), (x + w, z0 + height), (x, z0 + height + point), (x - w, z0 + height)]
        y0, y1 = y - depth / 2, y + depth / 2
        polys = [
            [(px, y0, pz) for px, pz in outline],
            [(px, y1, pz) for px, pz in outline],
        ]
        for a, b in ((2, 3), (3, 4)):  # the two slopes
            (ax, az), (bx, bz) = outline[a], outline[b]
            polys.append([(ax, y0, az), (bx, y0, bz), (bx, y1, bz), (ax, y1, az)])
        self.faces(polys, (x, y, z0 + height / 2), color)

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        ob = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(ob)
        pieces[self.name] = ob
        return ob


# Blender: X along the piece, Y away from the train (Roblox +Z), Z up (Roblox Y).

def gas_lamp():
    p = Piece("GasLamp")
    p.box((1.1, 1.1, 0.6), (0, 0, 0.3), IRON)
    p.box((0.8, 0.8, 0.3), (0, 0, 0.75), IRON_LIGHT)
    p.cyl(0.18, 9.0, (0, 0, 5.1), IRON, segments=12)
    for k in range(4):  # flutes
        a = k * math.pi / 2 + math.pi / 4
        p.box((0.08, 0.08, 6.0), (0.17 * math.cos(a), 0.17 * math.sin(a), 4.2), IRON_LIGHT)
    p.box((1.6, 0.16, 0.16), (0, 0, 8.6), IRON)  # the lamplighter's ladder bar
    for x in (-0.75, 0.75):
        p.cyl(0.1, 0.25, (x, 0, 8.75), IRON, segments=6)
    p.box((1.25, 1.25, 0.25), (0, 0, 9.82), IRON)  # lantern base
    for x in (-0.5, 0.5):  # frame posts round the glass
        for y in (-0.5, 0.5):
            p.box((0.1, 0.1, 1.2), (x, y, 10.55), IRON)
    p.cone(0.95, 0.15, 0.7, (0, 0, 11.5), IRON, segments=4)  # pyramid cap
    p.cyl(0.12, 0.4, (0, 0, 12.0), IRON, segments=6)
    return p.finish()


def hazard_rail():
    p = Piece("HazardRail")
    p.cyl(0.2, 3.6, (0, 0, 1.8), HAZARD, segments=10)
    p.cyl(0.22, 0.5, (0, 0, 2.4), HAZARD_DARK, segments=10)
    # the top rail painted in bands: yellow and black 1.5 studs each
    n = 8
    for k in range(n):
        x = -6 + (k + 0.5) * 12 / n
        p.box((12 / n - 0.02, 0.28, 0.28), (x, 0, 3.4), HAZARD if k % 2 == 0 else HAZARD_DARK)
    p.box((12, 0.22, 0.22), (0, -0.02, 1.7), RED)
    return p.finish()


def shaded(color, k):
    return (color[0] * k, color[1] * k, color[2] * k, 1.0)


def fence_picket():
    # StationDressing.FencePicket's layout for a 12-stud tile and its colours (C.paint, posts
    # 0.92 of it, rails 0.9): 4 posts (10 tris), 2 rails (6), 7 pickets (10) = 122 tris
    p = Piece("FencePicket")
    posts = [-6 + 0.25 + i * 3 for i in range(4)]
    for x in posts:
        p.open_box((0.32, 0.32, 3.4), (x, 0, 1.7), shaded(PAINT, 0.92))
    for z in (1.0, 2.6):
        p.open_box((12, 0.16, 0.24), (0, 0.25, z), shaded(PAINT, 0.9), skip=("bottom", "left", "right"))
    x = -6 + 0.6
    while x < 6 - 0.4:
        if all(abs(px - x) >= 0.36 for px in posts):
            p.picket(x, 0.42, 2.7, 0.3, 0.38, 0.1, 0.08, PAINT)
        x += 1.0
    return p.finish()


def crate():
    p = Piece("Crate")
    for k in range(4):  # planks, a hair apart
        p.box((4.0, 4.0, 0.96), (0, 0, 0.5 + k * 1.0), WOOD if k % 2 == 0 else WOOD_DARK)
    for x in (-1.9, 1.9):  # battens
        for y in (-2.03, 2.03):
            p.box((0.3, 0.12, 4.0), (x, y, 2.0), WOOD_DARK)
    for y in (-2.03, 2.03):
        p.box((3.4, 0.12, 0.3), (0, y, 2.0), WOOD_DARK, rot=(0, 45, 0))
    for x in (-2.0, 2.0):  # corner irons
        for y in (-2.0, 2.0):
            p.box((0.22, 0.22, 0.6), (x, y, 3.7), IRON)
    return p.finish()


def sign_board():
    p = Piece("SignBoard")
    for x in (-3.4, 3.4):
        p.box((0.3, 0.3, 5.8), (x, 0.2, 2.9), IRON)
    p.box((8.0, 0.2, 1.6), (0, 0, 4.9), ENAMEL_EDGE)
    p.box((7.6, 0.24, 1.2), (0, 0, 4.9), ENAMEL)
    return p.finish()


def wall_brick():
    p = Piece("WallBrick")
    # the wall in courses round a window opening (4 wide, sill 3.4, head 8)
    p.box((12, 1.0, 3.4), (0, 0, 1.7), BRICK)
    p.box((4.0, 1.0, 4.6), (-4.0, 0, 5.7), BRICK)
    p.box((4.0, 1.0, 4.6), (4.0, 0, 5.7), BRICK)
    p.box((12, 1.0, 4.0), (0, 0, 10.0), BRICK)
    p.box((4.8, 1.3, 0.35), (0, -0.15, 3.3), STONE)  # sill
    p.box((5.0, 1.1, 0.6), (0, -0.05, 8.3), STONE)  # lintel
    p.box((12.1, 1.15, 0.5), (0, -0.075, 0.25), BRICK_DARK)  # plinth course
    for z in (2.2, 6.6, 11.0):  # string courses
        p.box((12.04, 1.06, 0.18), (0, 0, z), BRICK_DARK)
    return p.finish()


def roof_slate():
    p = Piece("RoofSlate")
    pitch = math.degrees(math.atan2(4.0, 6.0))
    run = math.hypot(6.0, 4.0)
    for side in (-1, 1):
        for k in range(5):  # rows of slates, each lapping the one below
            t = (k + 0.5) / 5
            y = side * (6.0 - t * 6.0)
            z = t * 4.0
            p.box(
                (12.0, run / 5 + 0.25, 0.22),
                (0, y, z + 0.11),
                SLATE if k % 2 == 0 else SLATE_DARK,
                rot=(-side * pitch, 0, 0),
            )
    p.box((12.1, 0.5, 0.5), (0, 0, 4.15), SLATE_DARK)  # ridge
    return p.finish()


for build in (gas_lamp, hazard_rail, fence_picket, crate, sign_board, wall_brick, roof_slate):
    build()
if ONLY:
    for name in list(pieces):
        if name != ONLY:
            bpy.data.objects.remove(pieces.pop(name))

# lay them out for the preview; origins back to each piece's own bounding-box centre on export
tris = {}
for i, (name, ob) in enumerate(pieces.items()):
    ob.data.calc_loop_triangles()
    tris[name] = len(ob.data.loop_triangles)
    ob.location = Vector(((i - 3) * 16, 0, 0))

os.makedirs(OUT_DIR, exist_ok=True)
if not ONLY:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "StationKit.blend"))

if PREVIEW:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [
        e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items
    ] else "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1600, 560
    mat = bpy.data.materials.new("VertexColour")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    mat.node_tree.links.new(attr.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    for ob in pieces.values():
        ob.data.materials.append(mat)
    world = bpy.data.worlds.new("W")
    world.color = (0.2, 0.21, 0.24)
    scene.world = world
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.location = (0, -150, 34)
    cam.rotation_euler = (math.radians(80), 0, 0)
    cam.data.lens = 50
    scene.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(15), math.radians(-30))
    scene.collection.objects.link(sun)
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)

# export: each piece at the origin, centred on its bounding box, turned for the importer
turn = Matrix.Rotation(math.pi, 4, "Z")
info = {}
for name, ob in pieces.items():
    ob.location = Vector((0, 0, 0))
    corners = [Vector(c) for c in ob.bound_box]
    centre = sum(corners, Vector()) / 8
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    # Roblox axes: X along, Y up, Z away from the train
    info[name] = {
        "size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
        "centre": [round(centre.x, 3), round(centre.z, 3), round(centre.y, 3)],
        "tris": tris[name],
    }
    ob.data.transform(Matrix.Translation(-centre))
    ob.data.transform(turn)
    ob.select_set(True)
fbx = os.path.join(OUT_DIR, f"{ONLY}.fbx" if ONLY else "StationKit.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx,
    use_selection=True,
    apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_UNITS",
    axis_forward="-Z",
    axis_up="Y",
    mesh_smooth_type="FACE",
    use_triangles=True,
    path_mode="STRIP",
    embed_textures=False,
)
import json

path = os.path.join(OUT_DIR, "StationKit.json")
if ONLY and os.path.exists(path):
    with open(path) as f:
        info = {**json.load(f), **info}
with open(path, "w") as f:
    json.dump(info, f, indent=1)
print("STATIONKIT", fbx, tris)
