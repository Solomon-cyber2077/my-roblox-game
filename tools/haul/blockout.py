"""Blender blockout for the procedural payroll prop; no uploaded assets.
Run: blender --background --python tools/haul/blockout.py
Coordinates are Roblox X/Z footprint, Blender Z height. Validates below-eye carry.
"""
import bpy
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
def block(name, size, pos, color):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    obj.data.materials.append(mat)
    return obj
block('Square payroll case', (2.6, 2.6, 1.6), (0, 0, .8), (.26,.17,.10))
for y in [-.85,.85]:
    block('Iron binding', (2.65,.15,.08), (0,y,1.65), (.10,.11,.12))
block('Wax seal', (.35,.35,.1), (0,0,1.67), (.38,.08,.05))
for x in [-1.5,1.5]:
    block('Lamp bracket', (.25,.6,.5), (x,0,1.1), (.12,.12,.12))
crate_parts = list(bpy.context.scene.objects)
block('Strongbox', (3.2,2.2,1.8), (5,0,.9), (.12,.13,.14))
block('Lock', (.4,.15,.5), (5,-1.2,1.2), (.45,.32,.12))
bpy.context.view_layer.update()
assert max((obj.matrix_world @ v.co).z for obj in crate_parts for v in obj.data.vertices) < 2
print('HAUL BLOCKOUT: square case 2.6 x 2.6; height 1.6, lamps below eye line; strongbox 3.2 x 2.2')
