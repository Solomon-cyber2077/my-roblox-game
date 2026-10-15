"""Render actual Hollow photo-rig JSON with Blender; no uploaded assets needed."""
import bpy, json, os, sys, math
from mathutils import Matrix, Vector
args = sys.argv[sys.argv.index('--') + 1:]
data = json.load(open(args[0], encoding='utf-8'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
convert = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
materials = {}
for part in data['parts']:
    shape = part['shape']
    if shape == 'Ball':
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.5)
    elif shape == 'Cylinder':
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.5, depth=1, rotation=(0,math.pi/2,0))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    elif shape == 'Wedge':
        verts=[(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)]
        mesh=bpy.data.meshes.new('wedge')
        mesh.from_pydata(verts,[],[(0,2,3,1),(2,4,5,3),(0,4,2),(1,3,5),(0,1,5,4)])
        obj=bpy.data.objects.new('wedge',mesh)
        bpy.context.collection.objects.link(obj)
        bpy.context.view_layer.objects.active=obj
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
    obj=bpy.context.view_layer.objects.active
    f=part['frame']; x,y,z=f[:3]; r=f[3:]
    obj.matrix_world=convert @ Matrix(((r[0],r[1],r[2],x),(r[3],r[4],r[5],y),(r[6],r[7],r[8],z),(0,0,0,1))) @ Matrix.Diagonal((*part['size'],1))
    obj.name=part['name']
    key=tuple(round(c,3) for c in part['color'])
    if key not in materials:
        mat=bpy.data.materials.new(str(key)); mat.diffuse_color=(*key,1); mat.use_nodes=True
        bsdf=mat.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Base Color'].default_value=(*key,1)
        bsdf.inputs['Roughness'].default_value=.85
        materials[key]=mat
    obj.data.materials.append(materials[key])
points=[obj.matrix_world @ Vector(corner) for obj in bpy.context.scene.objects if obj.type=='MESH' for corner in obj.bound_box]
center=(Vector(tuple(min(p[i] for p in points) for i in range(3)))+Vector(tuple(max(p[i] for p in points) for i in range(3))))/2
span=max(max(p[i] for p in points)-min(p[i] for p in points) for i in range(3))
bpy.ops.object.camera_add(location=center+Vector((span*.7,span*1.4,span*.35)))
cam=bpy.context.object; cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=span*1.3
scene=bpy.context.scene; scene.camera=cam
for offset,energy,size in [((4,-8,10),1800,8),((-6,1,5),1100,6)]:
    bpy.ops.object.light_add(type='AREA',location=center+Vector(offset))
    lamp=bpy.context.object; lamp.data.energy=energy; lamp.data.shape='DISK'; lamp.data.size=size; lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
scene.world.color=(.12,.12,.12)
scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.render.resolution_x=640; scene.render.resolution_y=640; scene.render.resolution_percentage=100
output_path=os.path.abspath(args[1])
scene.render.image_settings.file_format='PNG'; scene.render.filepath=output_path
bpy.ops.render.render(write_still=True)
