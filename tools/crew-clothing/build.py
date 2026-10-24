"""Blender 5.2: original low-poly crew hats, normalized OBJ exports, R6 review renders.
Run textures.py first, then blender --background --python tools/crew-clothing/build.py.
Render resolution is explicitly 50%; sheets are review evidence, not engine validation.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import gear

ROOT=Path(__file__).resolve().parents[2]/'assets'/'crew-clothing'
NAMES=['stoker','brakeman','conductor','trackwalker','wayfarer','stoker_veteran','conductor_terminus']
COLORS=[(.20,.25,.27),(.29,.26,.19),(.10,.16,.24),(.35,.35,.21),(.35,.19,.16),(.17,.22,.24),(.18,.12,.23)]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def material(name,color):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=.78
    return m

def box(name,loc,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat); return o

skin=material('warm identity skin',(.57,.38,.25)); dark=material('boots leather',(.055,.046,.038))
neutral=material('avatar before neutral',(.28,.29,.30))

def panel(path,loc,w,h):
    m=bpy.data.materials.new(path.stem); m.use_nodes=True
    nodes=m.node_tree.nodes; p=nodes.get('Principled BSDF'); p.inputs['Roughness'].default_value=.87
    t=nodes.new('ShaderNodeTexImage'); t.image=bpy.data.images.load(str(path),check_existing=True)
    m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
    # vertical front-facing panel, pixel top corresponds to +Z
    mesh=bpy.data.meshes.new('garment face'); mesh.from_pydata([(-w/2,0,-h/2),(w/2,0,-h/2),(w/2,0,h/2),(-w/2,0,h/2)],[],[(0,1,2,3)])
    mesh.uv_layers.new(); uv=[(0,0),(1,0),(1,1),(0,1)]
    for loop in mesh.loops: mesh.uv_layers.active.data[loop.index].uv=uv[loop.vertex_index]
    ob=bpy.data.objects.new('classic cloth surface',mesh); bpy.context.collection.objects.link(ob); ob.location=loc; ob.data.materials.append(m)
    return ob

def hat(name,color):
    verts=[]; faces=[]; slots=[]
    def rings(levels,sy=0.85,slot=0,seg=32):
        start=len(verts)
        for z,r in levels:
            for i in range(seg):
                a=i*math.tau/seg; verts.append((r*math.cos(a),sy*r*math.sin(a),z))
        for j in range(len(levels)-1):
            for i in range(seg):
                a=start+j*seg+i; b=start+j*seg+(i+1)%seg
                faces.append((a,b,b+seg,a+seg)); slots.append(slot)
        faces.append(tuple(start+i for i in reversed(range(seg)))); slots.append(slot)
        faces.append(tuple(start+(len(levels)-1)*seg+i for i in range(seg))); slots.append(slot)
    base=name.split('_')[0]
    if base=='wayfarer':
        rings([(0,1.08),(.04,1.13),(.09,.98),(.12,.82),(.44,.70),(.55,.58)],slot=0)
        rings([(.10,.84),(.21,.80)],slot=1)
    elif base=='trackwalker':
        rings([(0,.92),(.12,.98),(.35,.90),(.58,.65),(.67,.05)],slot=0)
        rings([(-.03,.96),(.17,.98)],slot=3)
    else:
        high=.59 if base=='conductor' else .40
        rings([(0,.92),(.13,.94),(.18,1.05),(high-.06,1.07),(high,.86),(high+.01,.04)],slot=0)
        if base=='stoker':
            # Soft work-cap crown: gathered rim and a flattened, forward-sloping top.
            for i,(vx,vy,vz) in enumerate(verts):
                if vz>.13: verts[i]=(vx*(1+.025*math.cos(i*2.1)),vy-.07,vz-.09*(1-vy))
        rings([(0,.93),(.12,.95)],slot=1)
        # Curved peak, with depth and a stitched edge; front is negative Y.
        start=len(verts); seg=16
        for z in (-.035,.015):
            for radius in (.65,1.30):
                for i in range(seg+1):
                    a=math.pi+(i/seg)*math.pi
                    verts.append((radius*math.cos(a),radius*.9*math.sin(a)-.05,z+.06*math.cos(a)**2))
        for i in range(seg):
            for off in (0,34):
                faces.append((start+off+i,start+off+i+1,start+off+18+i,start+off+17+i)); slots.append(1)
            faces.append((start+17+i,start+18+i,start+52+i,start+51+i)); slots.append(3)
        if base=='conductor':
            # Small raised brass oval badge on the band, no text/modern insignia.
            start=len(verts)
            verts.append((0,-.86,.15))
            for i in range(16):
                a=i*math.tau/16; verts.append((.17*math.cos(a),-.86,.15+.07*math.sin(a)))
            for i in range(16): faces.append((start,start+1+i,start+1+(i+1)%16)); slots.append(2)
    mesh=bpy.data.meshes.new(name+' hat'); mesh.from_pydata(verts,[],faces); mesh.update()
    ob=bpy.data.objects.new(name+' hat',mesh); bpy.context.collection.objects.link(ob)
    mesh.materials.append(gear.atlas_material(ROOT/name/'hat-atlas.png',name+' hat atlas'))
    gear.assign_uv(mesh,slots)
    mesh.calc_loop_triangles(); count=len(mesh.loop_triangles)
    assert count<=1500,(name,count)
    # Normalize geometry to a unit bounding box for SpecialMesh.Scale = manifest size.
    bounds=[(min(v.co[i] for v in mesh.vertices),max(v.co[i] for v in mesh.vertices)) for i in range(3)]
    dims=[b-a for a,b in bounds]; center=[(a+b)/2 for a,b in bounds]
    for v in mesh.vertices:
        v.co=Vector([(v.co[i]-center[i])/dims[i] for i in range(3)])
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob
    bpy.ops.wm.obj_export(filepath=str(ROOT/name/'hat.obj'),export_selected_objects=True,export_materials=False,export_triangulated_mesh=True,forward_axis='Z',up_axis='Y')
    ob.scale=dims; ob.location.z=5.55
    return ob,{'triangles':count,'mesh':'hat.obj','texture':'hat-atlas.png','size':[round(dims[0],4),round(dims[2],4),round(dims[1],4)],'offset':[0,round(.55+dims[2]/2,4),0],'upload':'HUMAN pending','validated':False}

manifest={}
def mannequin(name,x,color,before=False):
    start=set(bpy.data.objects)
    cloth=material(name+' cloth body',color)
    box('Torso',(0,0,3),(2,1,2),neutral if before else cloth)
    box('Head',(0,0,4.5),(2,1,1),skin)
    for side in (-1,1):
        box('Arm',(side*1.5,0,3),(1,1,2),neutral if before else cloth)
        box('Leg',(side*.5,0,1),(1,1,2),dark)
        if not before:
            panel(ROOT/name/'shirt-limb.png',(side*1.5,-.502,3),1,2)
            panel(ROOT/name/'pants-limb.png',(side*.5,-.502,1),1,2)
    if not before:
        panel(ROOT/name/'torso-front.png',(0,-.502,3),2,2)
        back=panel(ROOT/name/'torso-back.png',(0,.502,3),2,2); back.rotation_euler.z=math.pi
        ob,stats=hat(name,color); ob.location.z=5.05+stats['size'][1]/2
        _,equipment=gear.build(name,ROOT/name)
        stats['gear']=equipment
        stats['totalTriangles']=stats['triangles']+equipment['triangles']
        assert stats['totalTriangles']<=1500,(name,stats['totalTriangles'])
        stats['accessoryCount']=2
        manifest[name]=stats
    for ob in set(bpy.data.objects)-start: ob.location.x+=x

for i,name in enumerate(NAMES): mannequin(name,(i-3)*5,COLORS[i])
ground=material('review floor',(.075,.084,.09)); box('floor',(0,0,-.18),(42,14,.3),ground)
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=32
scene.world.color=(.18,.18,.18)
for loc,power,size,color in [((0,-9,15),2600,12,(1,.84,.65)),((0,5,10),3300,10,(.55,.68,1))]:
    bpy.ops.object.light_add(type='AREA',location=loc); l=bpy.context.object; l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.data.color=color
    l.rotation_euler=(Vector((0,0,2))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-29,14)); cam=bpy.context.object; cam.data.type='ORTHO'; cam.data.ortho_scale=38
cam.rotation_euler=(Vector((0,0,2.5))-cam.location).to_track_quat('-Z','Y').to_euler(); scene.camera=cam
scene.render.resolution_x=2800;scene.render.resolution_y=1000;scene.render.resolution_percentage=50
scene.view_settings.view_transform='AgX'
scene.render.filepath=str(ROOT/'lineup-after.png');bpy.ops.render.render(write_still=True)
cam.location=(-15,-10,7);cam.rotation_euler=(Vector((-15,0,2.5))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=9
scene.render.resolution_x=1400;scene.render.resolution_y=1400
for ob in bpy.data.objects:
    if ob.type=='MESH' and ob.name!='floor' and ob.location.x>-12: ob.hide_render=True
scene.render.filepath=str(ROOT/'stoker-after.png');bpy.ops.render.render(write_still=True)
for ob in bpy.data.objects: ob.hide_render=False
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'crew-clothing.blend'))
for ob in list(bpy.data.objects):
    if ob.type=='MESH' and ob.name!='floor': bpy.data.objects.remove(ob,do_unlink=True)
mannequin('stoker',-15,COLORS[0],before=True)
scene.render.filepath=str(ROOT/'stoker-before.png');bpy.ops.render.render(write_still=True)
(ROOT/'manifest.json').write_text(json.dumps({'status':'source assets; engine upload/pose validation pending','recipes':manifest},indent=2))
