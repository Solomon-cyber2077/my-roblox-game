"""
Exports a baked car (or the kit) as one FBX, one object per MeshPart, for Studio's 3D Importer:

  blender -b <atlas>_baked.blend -P tools/trainshell/export.py -- <out.fbx>

Studs as units (1 Blender unit = 1 stud), Y up, -Z forward, flat shading, triangulated.
Studio's 3D Importer turns what it reads 180 degrees about the vertical (it normalises the file's
axes whatever the header says), so the geometry is turned the other way here first: the uploaded
meshes then sit in train space exactly, and a MeshPart's local X is the primitive's local X.
Each object keeps its origin at its bounding-box centre (where Roblox puts a MeshPart's pivot).
"""

import sys

import math

import bpy
from mathutils import Matrix

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.object.select_all(action="DESELECT")
for ob in bpy.data.objects:
    if ob.type == "MESH" and not ob.hide_render and ob.library is None:
        ob.select_set(True)
turn = Matrix.Rotation(math.pi, 4, "Z")  # Blender Z is Roblox Y
for ob in bpy.context.selected_objects:
    ob.data.transform(turn)
    ob.location = turn @ ob.location
bpy.ops.export_scene.fbx(
    filepath=out,
    use_selection=True,
    apply_unit_scale=True,
    apply_scale_options="FBX_SCALE_UNITS",
    axis_forward="-Z",
    axis_up="Y",
    mesh_smooth_type="FACE",
    use_triangles=True,
    use_mesh_modifiers=True,
    path_mode="STRIP",
    embed_textures=False,
)
print("EXPORTED", out, [ob.name for ob in bpy.context.selected_objects])
