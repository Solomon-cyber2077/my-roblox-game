"""Render actual Hollow photo-rig JSON with Blender; no uploaded assets needed.
Also renders a `lune run preview` export (e.g. the Depot Hall) from a given camera, where node is not installed:
  blender -b --python hollow-photo.py -- scene.json out.png x,y,z lx,ly,lz"""
import bpy, json, os, sys, math
from mathutils import Matrix, Vector
args = sys.argv[sys.argv.index('--') + 1:]
data = json.load(open(args[0], encoding='utf-8'))


def render_scene(data, out, cam_pos, cam_look, width=960, height=540, samples=48, exposure=1.6, ambient=.16, mesh_dir=None):
    """A `lune run preview` export (parts as s/z/p/r/c/m/t, point lights as p/c/b/r) seen from cam_pos
    toward cam_look (Roblox studs, Y up), lit only by its own lights and a dim sky."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    convert = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    meshes = {}
    def base(code):
        if code in meshes:
            return meshes[code]
        if code == 'S':
            bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=.5)
        elif code == 'C':
            bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=.5, depth=1, rotation=(0, math.pi/2, 0))
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        elif code == 'W':
            mesh = bpy.data.meshes.new('wedge')
            mesh.from_pydata([(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)], [],
                             [(0,2,3,1),(2,4,5,3),(0,4,2),(1,3,5),(0,1,5,4)])
            meshes[code] = mesh
            return mesh
        else:
            bpy.ops.mesh.primitive_cube_add(size=1)
        obj = bpy.context.view_layer.objects.active
        meshes[code] = obj.data
        bpy.data.objects.remove(obj)
        return meshes[code]
    mats = {}
    def material(c, m, t):
        key = (tuple(c), m, round(t, 2))
        if key in mats:
            return mats[key]
        mat = bpy.data.materials.new(str(key)); mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get('Principled BSDF')
        col = tuple((v / 255) ** 2.2 for v in c) + (1,)
        bsdf.inputs['Base Color'].default_value = col
        bsdf.inputs['Roughness'].default_value = .35 if m in ('Metal', 'Glass', 'SmoothPlastic', 'Marble') else .85
        if m == 'Metal':
            bsdf.inputs['Metallic'].default_value = .6
        if m == 'Neon':
            bsdf.inputs['Emission Color'].default_value = col
            bsdf.inputs['Emission Strength'].default_value = 4
        if t > 0.01:
            bsdf.inputs['Alpha'].default_value = 1 - t
        mats[key] = mat
        return mat
    coll = bpy.context.collection
    for part in data['parts']:
        obj = bpy.data.objects.new('p', base(part['s']))
        x, y, z = part['p']; r = part['r']
        # r holds the right, up and back vectors (the frame's columns)
        rot = Matrix(((r[0], r[3], r[6], x), (r[1], r[4], r[7], y), (r[2], r[5], r[8], z), (0, 0, 0, 1)))
        obj.matrix_world = convert @ rot @ Matrix.Diagonal((*part['z'], 1))
        coll.objects.link(obj)
        if part.get('g'):
            obj['meshed'] = True  # a part its cluster's mesh replaces
        if not obj.data.materials:
            obj.data.materials.append(None)  # one slot on the shared mesh; each object fills its own
        obj.material_slots[0].link = 'OBJECT'
        obj.material_slots[0].material = material(part['c'], part['m'], part.get('t', 0))
    for light in data.get('lights', []):
        lamp = bpy.data.lights.new('l', 'POINT')
        lamp.color = tuple((v / 255) ** 2.2 for v in light['c'])
        lamp.energy = light['b'] * light['r'] ** 2 * 2.5
        lamp.shadow_soft_size = .3
        lamp.use_custom_distance = True
        lamp.cutoff_distance = light['r'] * 1.5
        obj = bpy.data.objects.new('l', lamp)
        x, y, z = light['p']
        obj.location = convert @ Vector((x, y, z))
        coll.objects.link(obj)
    # the hall's Blender props (Builders/HallWear placements), from mesh_dir/<key>.obj: each replaces
    # the part-built version standing in its box
    if mesh_dir:
        parts = {o.name: o for o in coll.objects if o.get('meshed')}
        for m in data.get('meshes', []):
            path = os.path.join(mesh_dir, m['k'] + '.obj')
            if not os.path.exists(path):
                continue
            bpy.ops.wm.obj_import(filepath=path, forward_axis='NEGATIVE_Z', up_axis='Y')
            ob = bpy.context.selected_objects[0]
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)  # the importer's own turn
            if m.get('c'):  # a face piece: Roblox centres a MeshPart on its box, and its placement assumes that
                vs = ob.data.vertices
                mid = Vector([(min(v.co[i] for v in vs) + max(v.co[i] for v in vs)) / 2 for i in range(3)])
                for v in vs:
                    v.co -= mid
            x, y, z = m['p']; r = m['r']
            rot = Matrix(((r[0], r[3], r[6], x), (r[1], r[4], r[7], y), (r[2], r[5], r[8], z), (0, 0, 0, 1)))
            # the OBJ comes in Y-up turned to Blender's Z-up; take it back to Roblox axes, place, then convert
            back = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
            ob.matrix_world = convert @ rot @ Matrix.Diagonal((m['s'], m['s'], m['s'], 1)) @ back
            if m.get('c'):  # a tinted mesh (Builders/FaceKit): its Color shows where the texture is clear
                for slot in ob.material_slots:
                    nt = slot.material.node_tree if slot.material else None
                    tex = next((n for n in nt.nodes if n.type == 'TEX_IMAGE'), None) if nt else None
                    if tex:
                        bsdf = nt.nodes.get('Principled BSDF')
                        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'
                        mix.inputs[6].default_value = tuple((v / 255) ** 2.2 for v in m['c']) + (1,)
                        nt.links.new(tex.outputs['Alpha'], mix.inputs['Factor']); nt.links.new(tex.outputs['Color'], mix.inputs[7])
                        nt.links.new(mix.outputs[2], bsdf.inputs['Base Color'])
                        for link in [l for l in nt.links if l.to_socket == bsdf.inputs['Alpha']]:
                            nt.links.remove(link)
                        bsdf.inputs['Alpha'].default_value = 1
                        bsdf.inputs['Roughness'].default_value = .65
            if m['k'] == 'puddle':  # dark glass, as the game makes it
                for slot in ob.material_slots:
                    if slot.material:
                        bsdf = slot.material.node_tree.nodes.get('Principled BSDF')
                        bsdf.inputs['Roughness'].default_value = .03
                        bsdf.inputs['Specular IOR Level'].default_value = 1.0
            bpy.context.view_layer.update()
            corners = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
            pad = .35 if m.get('c') else .15  # a face swallows the whole kit face round it
            lo = Vector([min(c[i] for c in corners) - pad for i in range(3)])
            hi = Vector([max(c[i] for c in corners) + pad for i in range(3)])
            for name in [n for n, o in parts.items() if all(lo[i] <= o.matrix_world.translation[i] <= hi[i] for i in range(3))]:
                bpy.data.objects.remove(parts.pop(name), do_unlink=True)
    camera = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    coll.objects.link(camera)
    camera.location = convert @ Vector(cam_pos)
    camera.rotation_euler = ((convert @ Vector(cam_look)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.lens = 24
    scene = bpy.context.scene
    scene.camera = camera
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (ambient, ambient * .82, ambient * .62, 1)  # Studio-like warm ambient
    scene.render.engine = 'CYCLES'; scene.cycles.samples = samples; scene.cycles.use_denoising = True
    scene.render.resolution_x = width; scene.render.resolution_y = height; scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'AgX'
    scene.view_settings.exposure = exposure
    scene.render.image_settings.file_format = 'PNG'; scene.render.filepath = os.path.abspath(out)
    bpy.ops.render.render(write_still=True)


# A preview export: <scene.json> <out.png> <x,y,z> <lx,ly,lz> [exposure] [mesh dir]
if data.get('parts') and 's' in data['parts'][0]:
    vec = lambda text: tuple(float(v) for v in text.split(','))
    render_scene(data, args[1], vec(args[2]), vec(args[3]), exposure=float(args[4]) if len(args) > 4 else 1.6,
                 mesh_dir=args[5] if len(args) > 5 else None)
    sys.exit(0)
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
