"""Candidate only: run stoker_textures.py, then Blender --background --python this file.
Z-up, front -Y. Exports are normalized for the existing SpecialMesh convention.
References: randijofab.com/products/copy-of-waxed-canvas-cap (compact crown/peak),
hardmill.com/collections/aprons (restrained leather pockets and hardware).
No existing uploads or gameplay configuration are changed.
"""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gear

OUT = Path(__file__).resolve().parents[2] / 'assets/crew-clothing/stoker-v2'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
atlas = gear.atlas_material(OUT/'hat-atlas.png', 'Olive leather brass smoke')

def material(name, color):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = .76
    return m

def box(name, loc, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object; o.name = name; o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    return o

class Mesh:
    def __init__(self): self.v=[]; self.f=[]; self.slots=[]
    def face(self, points, slot):
        n=len(self.v); self.v.extend(points)
        self.f.append(tuple(range(n,len(self.v)))); self.slots.append(slot)
    def block(self, loc, size, slot):
        x,y,z=loc; a,b,c=[s/2 for s in size]
        p=[(x+dx*a,y+dy*b,z+dz*c) for dx,dy,dz in
           [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        for ids in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:
            self.face([p[i] for i in ids],slot)
    def ring(self, x,y,z,rx,rz,r,slot):
        for i in range(16):
            for j in range(4):
                points=[]
                for a,b in [(i,j),(i+1,j),(i+1,j+1),(i,j+1)]:
                    t=a*math.tau/16; s=b*math.tau/4
                    points.append((x+(rx+r*math.cos(s))*math.cos(t),y+r*math.sin(s),z+(rz+r*math.cos(s))*math.sin(t)))
                self.face(points,slot)
    def export(self, name, origin):
        mesh=bpy.data.meshes.new(name); mesh.from_pydata(self.v,[],self.f); mesh.update()
        gear.assign_uv(mesh,self.slots)
        bm=bmesh.new(); bm.from_mesh(mesh)
        # Join coincident vertices so the OBJ importer sees a continuous shell.
        # Keep the authored UV loop data while welding the geometric seams.
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        # The two collar cards are front-facing; force their normals toward -Y.
        if name=='gear':
            cards=list(bm.faces)[:2]
            inward=[face for face in cards if face.normal.y > 0]
            if inward: bmesh.ops.reverse_faces(bm, faces=inward)
            bm.normal_update()
        bm.to_mesh(mesh); bm.free()
        ob=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(ob); mesh.materials.append(atlas)
        bounds=[(min(v.co[i] for v in mesh.vertices),max(v.co[i] for v in mesh.vertices)) for i in range(3)]
        dims=[b-a for a,b in bounds]; center=[(a+b)/2 for a,b in bounds]
        for v in mesh.vertices: v.co=Vector([(v.co[i]-center[i])/dims[i] for i in range(3)])
        if name=='hat':
            for poly in mesh.polygons[:segments*(len(levels)-1)]: poly.use_smooth=True
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob
        bpy.ops.wm.obj_export(filepath=str(OUT/(name+'.obj')), export_selected_objects=True,
            export_materials=False, export_triangulated_mesh=True, forward_axis='Z', up_axis='Y')
        ob.scale=dims; ob.location=center
        mesh.calc_loop_triangles()
        return {'mesh':name+'.obj','triangles':len(mesh.loop_triangles),
                'size':[round(dims[i],5) for i in (0,2,1)],
                'offset':[round(center[i]-origin[i],5) for i in (0,2,1)],
                'validated':False,'upload':'HUMAN pending'}

# Low asymmetric cloth crown: a narrow head-hugging oval, not a circular platter.
hat=Mesh(); segments=32
levels=[(5.0,1.025,.555,0),(5.09,1.03,.56,0),(5.22,1.025,.55,.015),
        (5.40,.88,.46,.045),(5.49,.57,.31,.07),(5.51,.015,.015,.07)]
for k in range(len(levels)-1):
    for i in range(segments):
        pts=[]
        for row,col in [(k,i),(k,i+1),(k+1,i+1),(k+1,i)]:
            z,rx,ry,shift=levels[row]; a=col*math.tau/segments
            pts.append((rx*math.cos(a),ry*math.sin(a)+shift,z+.025*math.cos(a)))
        hat.face(pts,1 if k==0 else 0)
# Short curved peak, all four edges closed; never extends behind the temples.
for i in range(20):
    a=-math.pi*.86+i*math.pi*.72/20; b=-math.pi*.86+(i+1)*math.pi*.72/20
    def peak(t,outer,lower):
        return ((1.025 if not outer else 1.09)*math.cos(t),
                (.54 if not outer else .86)*math.sin(t)-.015,
                5.035-(.075 if outer else 0)*(-math.sin(t))-(.045 if lower else 0))
    for lower in (False,True):
        hat.face([peak(a,False,lower),peak(b,False,lower),peak(b,True,lower),peak(a,True,lower)],0)
    for outer in (False,True):
        hat.face([peak(a,outer,False),peak(a,outer,True),peak(b,outer,True),peak(b,outer,False)],1)
    if i in (0,19):
        t=a if i==0 else b
        hat.face([peak(t,False,False),peak(t,True,False),peak(t,True,True),peak(t,False,True)],1)
# Compact goggles parked against the cap band, away from the face.
for x in (-.265,.265):
    hat.ring(x,-.565,5.24,.205,.145,.028,2)
    hat.face([(x+.179*math.cos(i*math.tau/16),-.569,5.24+.12*math.sin(i*math.tau/16)) for i in range(16)],3)
hat.block((0,-.585,5.25),(.10,.045,.045),1)
hat_stats=hat.export('hat',(0,0,4.5))

# Collar and a single readable leather pouch. Rigid detail stays within the torso.
equipment=Mesh()
for sign in (-1,1):
    equipment.face([(sign*.18,-.525,3.94),(sign*.62,-.525,3.98),
                    (sign*.77,-.56,3.66),(sign*.37,-.59,3.76)],0)
equipment.block((.62,-.58,2.38),(.45,.16,.46),1)
equipment.block((.62,-.678,2.51),(.47,.038,.20),1)
equipment.block((.62,-.710,2.45),(.085,.025,.13),2)
equipment.block((.62,-.725,2.45),(.035,.012,.055),3)
gear_stats=equipment.export('gear',(0,0,3))
assert hat_stats['triangles']+gear_stats['triangles']<=1500

skin=material('Warm mannequin',(.54,.35,.22)); cloth=material('Olive canvas',(.17,.21,.115))
trouser=material('Charcoal twill',(.065,.07,.059))
box('Torso',(0,0,3),(2,1,2),cloth)
head=box('Head',(0,0,4.5),(2,1,1),skin)
bevel=head.modifiers.new('R6 head softened edges','BEVEL'); bevel.width=.12; bevel.segments=3
head.modifiers.new('Head weighted normals','WEIGHTED_NORMAL')
for s in (-1,1):
    box('Arm',(s*1.5,0,3),(1,1,2),cloth)
    box('Leg',(s*.5,0,1),(1,1,2),trouser)

def panel(filename,loc,w,h,rotation=0):
    mat=bpy.data.materials.new(filename);mat.use_nodes=True
    p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.85
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/filename),check_existing=True)
    mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    mesh=bpy.data.meshes.new(filename)
    mesh.from_pydata([(-w/2,0,-h/2),(w/2,0,-h/2),(w/2,0,h/2),(-w/2,0,h/2)],[],[(0,1,2,3)])
    mesh.uv_layers.new()
    for loop in mesh.loops:mesh.uv_layers.active.data[loop.index].uv=[(0,0),(1,0),(1,1),(0,1)][loop.vertex_index]
    o=bpy.data.objects.new(filename,mesh);bpy.context.collection.objects.link(o)
    o.location=loc;o.rotation_euler.z=rotation;mesh.materials.append(mat)
panel('torso-front.png',(0,-.502,3),2,2)
panel('torso-back.png',(0,.502,3),2,2,math.pi)
for s in (-1,1):
    for y,angle in [(-.502,0),(.502,math.pi)]:
        panel('shirt-limb.png',(s*1.5,y,3),1,2,angle)
        panel('pants-limb.png',(s*.5,y,1),1,2,angle)
    panel('shirt-limb.png',(s*2.002,0,3),1,2,s*math.pi/2)
    panel('pants-limb.png',(s*1.002,0,1),1,2,s*math.pi/2)

floor=material('Review floor',(.055,.065,.075));box('floor',(0,0,-.17),(200,200,.3),floor)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48
scene.world.color=(.23,.23,.23)
for loc,power,size,col in [((-4,-6,10),1500,7,(1,.86,.70)),((5,-3,6),800,6,(.75,.85,1)),((1,4,8),1800,5,(1,.85,.65))]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.data.color=col
    o.rotation_euler=(Vector((0,0,3))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=6.8
scene.render.resolution_x=1400;scene.render.resolution_y=1400;scene.render.resolution_percentage=50
scene.view_settings.view_transform='AgX'
for name,pos in [('front',(3,-12,7)),('back',(-3,12,7)),('profile',(10,-3,6))]:
    cam.location=pos;cam.rotation_euler=(Vector((0,0,2.7))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
cam.location=(3,-12,7);cam.rotation_euler=(Vector((0,0,2.7))-cam.location).to_track_quat('-Z','Y').to_euler()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'stoker-v2.blend'))
(OUT/'manifest.json').write_text(json.dumps({'status':'candidate; no Roblox IDs assigned; engine fit pending',
    'hat':hat_stats,'gear':gear_stats,'totalTriangles':hat_stats['triangles']+gear_stats['triangles']},indent=2))
# Render the actual previous source under matching light, scale and viewing angle.
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'crew-clothing.blend'))
scene=bpy.context.scene;cam=scene.camera
for o in list(bpy.data.objects):
    if o.type=='LIGHT': bpy.data.objects.remove(o,do_unlink=True)
    elif o.type=='MESH' and o.name!='floor': o.hide_render=o.location.x>-12
scene.world.color=(.23,.23,.23)
for loc,power,size,col in [((-4,-6,10),1500,7,(1,.86,.70)),((5,-3,6),800,6,(.75,.85,1)),((1,4,8),1800,5,(1,.85,.65))]:
    bpy.ops.object.light_add(type='AREA',location=(loc[0]-15,loc[1],loc[2]));o=bpy.context.object;o.data.energy=power;o.data.size=size;o.data.color=col
    o.rotation_euler=(Vector((-15,0,3))-o.location).to_track_quat('-Z','Y').to_euler()
cam.location=(-12,-12,7);cam.data.ortho_scale=6.8
cam.rotation_euler=(Vector((-15,0,2.7))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=1400;scene.render.resolution_y=1400;scene.render.resolution_percentage=50
scene.render.filepath=str(OUT/'before.png');bpy.ops.render.render(write_still=True)
