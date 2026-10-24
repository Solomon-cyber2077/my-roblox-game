"""Original rigid torso details. Blender Z-up, front -Y; no long rigid coats."""
import math
import bpy
from mathutils import Vector

def atlas_material(path, name):
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF'); shader.inputs['Roughness'].default_value=.64
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(path),check_existing=True)
    mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
    return mat

def assign_uv(mesh,slots):
    mesh.uv_layers.new()
    for face,slot in zip(mesh.polygons,slots):
        axes=sorted(range(3),key=lambda a:abs(face.normal[a]))[:2]
        values=[[mesh.vertices[v].co[a] for v in face.vertices] for a in axes]
        spans=[(min(v),max(v)-min(v)) for v in values]
        for li in face.loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co
            u=(co[axes[0]]-spans[0][0])/max(spans[0][1],.00001)
            v=(co[axes[1]]-spans[1][0])/max(spans[1][1],.00001)
            mesh.uv_layers.active.data[li].uv=((slot+.05+.9*u)/4,.05+.9*v)

def build(name,directory):
    verts=[];faces=[];slots=[]
    def poly(points,slot):
        start=len(verts);verts.extend(points);faces.append(tuple(range(start,len(verts))));slots.append(slot)
    def front(points,slot):
        # Single-sided cloth must face Roblox front after OBJ axis conversion.
        area=sum(p[0]*q[2]-q[0]*p[2] for p,q in zip(points,points[1:]+points[:1]))
        poly(points if area>0 else list(reversed(points)),slot)
    def block(center,size,slot=1,bevel=.025):
        x,y,z=center;w,d,h=[v/2 for v in size];b=min(bevel,w/2,h/2)
        outline=[(-w+b,-h),(w-b,-h),(w,-h+b),(w,h-b),(w-b,h),(-w+b,h),(-w,h-b),(-w,-h+b)]
        a=[(x+u,y-d,z+v) for u,v in outline];c=[(x+u,y+d,z+v) for u,v in outline]
        poly(a,slot);poly(list(reversed(c)),slot)
        for i in range(8):poly([a[i],c[i],c[(i+1)%8],a[(i+1)%8]],slot)
    def tube(points,radius,slot=2,seg=5):
        start=len(verts)
        for i,p in enumerate(points):
            tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
            tangent.normalize();side=tangent.cross(Vector((0,1,0))).normalized();up=tangent.cross(side).normalized()
            for j in range(seg):verts.append(tuple(Vector(p)+radius*(math.cos(j*math.tau/seg)*side+math.sin(j*math.tau/seg)*up)))
        for i in range(len(points)-1):
            for j in range(seg):
                a=start+i*seg+j;b=start+i*seg+(j+1)%seg
                faces.append((a,b,b+seg,a+seg));slots.append(slot)
    def ring(x,z,rx,rz,radius=.025,slot=2,segments=12):
        tube([(x+rx*math.cos(i*math.tau/segments),-.70,z+rz*math.sin(i*math.tau/segments)) for i in range(segments+1)],radius,slot,4)
    def pouch(x,z,w=.48,h=.48):
        block((x,-.61,z),(w,.19,h),1)
        block((x,-.73,z+h*.24),(w+.035,.045,h*.47),3)
        block((x,-.77,z+.015),(.055,.035,.10),2,.008)
        tube([(x-w*.42,-.765,z+h*.12),(x,-.77,z+h*.02),(x+w*.42,-.765,z+h*.12)],.009,2,4)
    base=name.split('_')[0]
    if base=='stoker':
        for x in (-.23,.23):
            ring(x,.58,.19,.14)
            front([(x+.16*math.cos(i*math.tau/12),-.683,.58+.11*math.sin(i*math.tau/12)) for i in range(12)],0)
        tube([(-.05,-.70,.59),(0,-.72,.62),(.05,-.70,.59)],.027,1)
        for s in (-1,1):tube([(s*.43,-.66,.59),(s*.60,-.57,.82),(s*.65,-.52,.96)],.035,1)
        pouch(.58,-.54,.36,.37)
    elif base=='brakeman':
        pouch(-.55,-.48,.51,.52);pouch(.52,-.52,.34,.40)
        block((-.58,-.55,.43),(.14,.055,.92),1,.01)
        ring(-.58,.26,.065,.09,.015,2,8)
    elif base=='conductor':
        front([(-.78,-.52,.97),(-.39,-.59,.78),(-.12,-.62,.12),(-.55,-.60,.41)],3)
        front([(.78,-.52,.97),(.39,-.59,.78),(.12,-.62,.12),(.55,-.60,.41)],3)
        tube([(-.48,-.56,-.17),(-.36,-.62,-.34),(-.16,-.63,-.39),(.06,-.63,-.35),(.25,-.60,-.18)],.017,2,6)
        ring(.30,-.18,.07,.09,.014,2,10)
        block((-.50,-.56,.37),(.14,.045,.10),2,.015)
        if name.endswith('terminus'):tube([(-.64,-.55,.90),(-.48,-.62,.65),(-.32,-.64,.43)],.018,2)
    elif base=='trackwalker':
        front([(-.68,-.52,.98),(0,-.69,.73),(.68,-.52,.98),(.24,-.63,.52),(-.19,-.65,.59)],3)
        front([(-.14,-.69,.69),(.16,-.71,.62),(.25,-.66,.18),(-.05,-.65,.27)],3)
        pouch(.57,-.47,.48,.49)
        block((.57,-.77,-.28),(.23,.045,.065),2,.01)
    else:
        pouch(.45,-.40,.78,.73)
        front([(-.73,-.54,.96),(-.52,-.55,.98),(.70,-.56,-.55),(.48,-.57,-.66)],1)
        ring(-.15,.30,.075,.09,.017,2,8)
    mesh=bpy.data.meshes.new(name+' gear');mesh.from_pydata(verts,[],faces);mesh.update()
    assign_uv(mesh,slots)
    ob=bpy.data.objects.new(name+' gear',mesh);bpy.context.collection.objects.link(ob)
    mesh.materials.append(atlas_material(directory/'hat-atlas.png',name+' gear atlas'))
    mesh.calc_loop_triangles();count=len(mesh.loop_triangles)
    bounds=[(min(v.co[i] for v in mesh.vertices),max(v.co[i] for v in mesh.vertices)) for i in range(3)]
    dims=[b-a for a,b in bounds];center=[(a+b)/2 for a,b in bounds]
    for v in mesh.vertices:v.co=Vector([(v.co[i]-center[i])/dims[i] for i in range(3)])
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    bpy.ops.wm.obj_export(filepath=str(directory/'gear.obj'),export_selected_objects=True,export_materials=False,export_triangulated_mesh=True,forward_axis='Z',up_axis='Y')
    ob.scale=dims;ob.location=center;ob.location.z+=3
    return ob,{'name':'Gear','limb':'Torso','triangles':count,'mesh':'gear.obj','texture':'hat-atlas.png',
        'size':[round(dims[i],4) for i in (0,2,1)],'offset':[round(center[i],4) for i in (0,2,1)],'upload':'HUMAN pending','validated':False}
