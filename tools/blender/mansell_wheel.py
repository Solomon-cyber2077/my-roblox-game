"""
Mansell carriage wheel for Last Train Out, built headless:

    blender --background --factory-startup --python tools/blender/mansell_wheel.py -- <out_dir> [preview.png]

One mesh replaces the two primitives TrainBuilder uses per carriage wheel (the iron tyre and the
teak centre), and shows what primitives cannot: the sixteen teak segments of a Mansell centre,
the iron boss and the ring of bolts that clamp the segments to the tyre.

Units are studs (1 Blender unit = 1 stud). The axle runs along +X and the origin is the wheel's
centre, so the mesh drops in where Kit.cylinder(model, 0.6, 3.2, cf) sits today. Colours are
vertex colours (iron and teak); give the MeshPart a white Color so they show unchanged.
Size: 0.84 x 3.2 x 3.2 studs, about 1.3k triangles. Collision: none needed (CanCollide off,
CollisionFidelity Box).
"""

import math
import sys

import bmesh
import bpy

args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT_DIR = args[0] if args else "."
PREVIEW = args[1] if len(args) > 1 else None

IRON = (40 / 255, 36 / 255, 36 / 255, 1.0)
TEAK = (78 / 255, 52 / 255, 32 / 255, 1.0)
TEAK_DARK = (62 / 255, 40 / 255, 25 / 255, 1.0)

TYRE_R, TYRE_IN, TYRE_W = 1.6, 1.25, 0.6
TEAK_W = 0.7
BOSS_R, BOSS_W = 0.42, 0.84
SEGMENTS = 16
GROOVE = math.radians(1.4)  # the gap between two teak segments, each side
TYRE_SIDES = 48

bpy.ops.wm.read_factory_settings(use_empty=True)
mesh = bpy.data.meshes.new("MansellWheel")
bm = bmesh.new()
color = bm.loops.layers.color.new("Col")


def paint(faces, rgba):
    for face in faces:
        for loop in face.loops:
            loop[color] = rgba


def ring(r_out, r_in, half_w, a0, a1, sides, rgba):
    """A solid annular sector around the X axis from angle a0 to a1."""
    rows = []
    for i in range(sides + 1):
        a = a0 + (a1 - a0) * i / sides
        c, s = math.cos(a), math.sin(a)
        rows.append(
            [
                bm.verts.new((x, r * c, r * s))
                for x, r in ((-half_w, r_out), (half_w, r_out), (half_w, r_in), (-half_w, r_in))
            ]
        )
    faces = []
    for i in range(sides):
        a, b = rows[i], rows[i + 1]
        for k in range(4):
            faces.append(bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k])))
    full = abs((a1 - a0) - 2 * math.pi) < 1e-6
    if not full:
        faces.append(bm.faces.new(tuple(reversed(rows[0]))))
        faces.append(bm.faces.new(tuple(rows[-1])))
    paint(faces, rgba)
    return faces


def disc(r, half_w, sides, rgba):
    """A closed cylinder along X."""
    left = [bm.verts.new((-half_w, r * math.cos(2 * math.pi * i / sides), r * math.sin(2 * math.pi * i / sides))) for i in range(sides)]
    right = [bm.verts.new((half_w, v.co.y, v.co.z)) for v in left]
    faces = [bm.faces.new((left[i], left[(i + 1) % sides], right[(i + 1) % sides], right[i])) for i in range(sides)]
    faces.append(bm.faces.new(tuple(reversed(left))))
    faces.append(bm.faces.new(tuple(right)))
    paint(faces, rgba)


def block(center, size, rgba):
    x, y, z = center
    sx, sy, sz = (s / 2 for s in size)
    v = [bm.verts.new((x + dx * sx, y + dy * sy, z + dz * sz)) for dx in (-1, 1) for dy in (-1, 1) for dz in (-1, 1)]
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    paint([bm.faces.new(tuple(v[i] for i in q)) for q in quads], rgba)


# the iron tyre
ring(TYRE_R, TYRE_IN, TYRE_W / 2, 0, 2 * math.pi, TYRE_SIDES, IRON)
# sixteen teak segments, alternate ones a shade darker (end grain catching the light differently)
step = 2 * math.pi / SEGMENTS
for k in range(SEGMENTS):
    a0, a1 = k * step + GROOVE, (k + 1) * step - GROOVE
    ring(TYRE_IN, BOSS_R, TEAK_W / 2, a0, a1, 3, TEAK if k % 2 == 0 else TEAK_DARK)
# the iron boss and its hub
disc(BOSS_R, BOSS_W / 2, 24, IRON)
# bolts through the segments into the tyre, both faces
for k in range(SEGMENTS):
    a = (k + 0.5) * step
    r = TYRE_IN - 0.12
    for side in (-1, 1):
        block((side * (TEAK_W / 2 + 0.02), r * math.cos(a), r * math.sin(a)), (0.05, 0.09, 0.09), IRON)

bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh)
bm.free()
# the colour layer is what the FBX carries and the preview shows
mesh.color_attributes.active_color = mesh.color_attributes["Col"]
mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
obj = bpy.data.objects.new("MansellWheel", mesh)
bpy.context.collection.objects.link(obj)
for poly in mesh.polygons:
    poly.use_smooth = False

tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
dims = tuple(round(d, 3) for d in obj.dimensions)
print(f"MansellWheel: {tris} triangles, dimensions {dims}")

bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.export_scene.fbx(
    filepath=f"{OUT_DIR}/MansellWheel.fbx",
    use_selection=True,
    apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_UNITS",
    axis_forward="-Z",
    axis_up="Y",
    colors_type="SRGB",
    mesh_smooth_type="FACE",
)
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT_DIR}/MansellWheel.blend")

if PREVIEW:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.light = "STUDIO"
    scene.render.resolution_x, scene.render.resolution_y = 640, 480
    scene.render.filepath = PREVIEW
    world = bpy.data.worlds.new("World")
    scene.world = world
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (5.2, 2.2, 1.6)
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (-cam.location).to_track_quat("-Z", "Z")
    scene.camera = cam
    bpy.ops.render.render(write_still=True)
