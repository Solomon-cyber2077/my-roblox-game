import json
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "lobby")
LUA_OUT = os.path.join(ROOT, "src", "shared", "Visual", "LobbyMeshes.luau")
os.makedirs(OUT, exist_ok=True)

def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def mesh(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], [tuple(reversed(face)) for face in faces])
    me.update()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    return ob

def join_parts(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    parts[0].name = name
    bpy.ops.object.select_all(action="DESELECT")
    return parts[0]

def cylinder(r, z0, z1, n=16, x=0, y=0):
    vs=[]; fs=[]
    for z in (z0,z1):
        vs += [(x+r*math.cos(2*math.pi*i/n), y+r*math.sin(2*math.pi*i/n), z) for i in range(n)]
    fs.append(tuple(range(n-1,-1,-1))); fs.append(tuple(range(n,2*n)))
    for i in range(n): fs.append((i,(i+1)%n,(i+1)%n+n,i+n))
    return mesh("part",vs,fs)

def shaft():
    parts=[cylinder(.44,0,.14,24), cylinder(.4,.14,.26,24), cylinder(.34,.26,3.35,24), cylinder(.42,3.35,3.48,24), cylinder(.5,3.48,3.62,24)]
    # twelve narrow longitudinal ribs are fused into the shaft.
    for i in range(12):
        a=2*math.pi*i/12; parts.append(cylinder(.05,.28,3.34,8,.34*math.cos(a),.34*math.sin(a)))
    return join_parts("FlutedCastIronShaft",parts)

def capital():
    parts=[cylinder(.56,0,.14,24), cylinder(.7,.14,.27,24), cylinder(.62,.27,.4,24), cylinder(.5,.4,.55,24)]
    for i in range(8):
        a=2*math.pi*i/8; x=.52*math.cos(a); y=.52*math.sin(a)
        p=cylinder(.16,.28,.68,10,x,y); p.scale.x=1.8; p.scale.y=.7; p.rotation_euler[2]=a; parts.append(p)
    parts.append(cylinder(.45,.55,.7,20))
    return join_parts("OrnateCastIronCapital",parts)

def box(x0,x1,y0,y1,z0,z1):
    return mesh("part",[(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(4,0,3,7)])

def chair_back():
    verts=[]; faces=[]; sides=6; tube=.09
    path=[]
    for i in range(17):
        t=i/16*math.pi
        path.append((.735*math.cos(t), 0, .95+.85*math.sin(t)))
    path += [(-.735,0,0),(.735,0,0)]
    for j,(x,y,z) in enumerate(path):
        tangent=Vector((0,0,1)) if j in (0,len(path)-1) else Vector((path[min(j+1,len(path)-1)][0]-path[max(j-1,0)][0],0,path[min(j+1,len(path)-1)][2]-path[max(j-1,0)][2])).normalized()
        normal=Vector((tangent.z,0,-tangent.x));
        for i in range(sides):
            a=2*math.pi*i/sides; off=normal*(tube*math.cos(a))+Vector((0,tube*math.sin(a),0)); verts.append((x+off.x,y+off.y,z+off.z))
    for j in range(len(path)-1):
        for i in range(sides): faces.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
    ob=mesh("BentwoodChairBack",verts,faces); return ob

def export(ob):
    me=ob.data; center=sum((ob.matrix_world @ Vector(c) for c in ob.bound_box), Vector()) / 8; verts=[[round(v.co.x-center.x,5),round(v.co.z-center.z,5),round(-v.co.y+center.y,5)] for v in me.vertices]; tris=[]
    for p in me.polygons:
        if len(p.vertices)==3: tris.append(list(reversed(p.vertices)))
        else:
            for i in range(1,len(p.vertices)-1): tris.append([p.vertices[0],p.vertices[i+1],p.vertices[i]])
    dims=[round(ob.dimensions.x,5),round(ob.dimensions.z,5),round(ob.dimensions.y,5)]
    data={"name":ob.name,"coordinateSystem":"Roblox Y-up; X width, Y height, Z depth","dimensions":dims,"vertices":verts,"triangles":tris,"triangleCount":len(tris)}
    with open(os.path.join(OUT,ob.name+".json"),"w",encoding="utf-8") as f: json.dump(data,f,separators=(",",":"))
    return data

def write_luau(items):
    def triple(values):
        return "{" + ", ".join(str(v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v) for v in values) + "}"
    with open(LUA_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("--!strict\n\nreturn {\n")
        for item in items:
            f.write(f"\t{item['name']} = {{\n")
            f.write(f"\t\tsize = {triple(item['dimensions'])},\n")
            f.write("\t\tvertices = {\n")
            for vertex in item["vertices"]: f.write(f"\t\t\t{triple(vertex)},\n")
            f.write("\t\t},\n\t\ttriangles = {\n")
            for tri in item["triangles"]: f.write(f"\t\t\t{triple([i + 1 for i in tri])},\n")
            f.write("\t\t},\n\t},\n")
        f.write("}\n")

reset(); objects=[shaft(),capital(),chair_back()]
meta=[export(o) for o in objects]
write_luau(meta)
for o in objects: o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"lobby_shell.blend"))
with open(os.path.join(OUT,"metadata.json"),"w",encoding="utf-8") as f: json.dump([{k:m[k] for k in ("name","dimensions","triangleCount")} for m in meta],f,indent=2)
print(json.dumps([{k:m[k] for k in ("name","dimensions","triangleCount")} for m in meta]))
