"""Production R6 pose study. Run Blender --background --python tools/limbloss/render.py.
No assets downloaded; poses.json comes from export.luau and the real lantern builder.
"""
import bpy, json, math
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent
EXPORT = json.loads((ROOT / 'poses.json').read_text())
DATA = EXPORT['samples']
OUT = ROOT / 'renders'
OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 2400
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 50
scene.world.color = (0.18,0.18,0.18)
scene.view_settings.view_transform = 'AgX'
CONVERT = Matrix(((1,0,0,0),(0,0,1,0),(0,1,0,0),(0,0,0,1)))
materials = {}
def material(color, glow=False):
    key = (tuple(color),glow)
    if key not in materials:
        m=bpy.data.materials.new('Lantern glow' if glow else 'Crew fabric')
        m.diffuse_color=(*color,1)
        m.use_nodes=True
        p=m.node_tree.nodes.get('Principled BSDF')
        p.inputs['Base Color'].default_value=(*color,1)
        p.inputs['Roughness'].default_value=0.64
        if glow:
            p.inputs['Emission Color'].default_value=(*color,1)
            p.inputs['Emission Strength'].default_value=1.5
        materials[key]=m
    return materials[key]

def crew(sample, shift):
    objects=[]
    for part in sample['parts']:
        cf=part['cf']; s=part['size']
        matrix=Matrix(((cf[3],cf[4],cf[5],cf[0]),(cf[6],cf[7],cf[8],cf[1]),(cf[9],cf[10],cf[11],cf[2]),(0,0,0,1)))
        if 'Cylinder' in part['shape']:
            bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=0.5,depth=1)
            obj=bpy.context.object
            # Roblox cylinders run along X; rotate vertices before scaling.
            obj.data.transform(Matrix.Rotation(math.pi/2,4,'Y'))
        else:
            bpy.ops.mesh.primitive_cube_add(size=1)
            obj=bpy.context.object
        obj.name=part['name']
        obj.matrix_world=CONVERT@matrix@Matrix.Diagonal((*s,1))
        obj.location.x += shift
        obj.data.materials.append(material(part['color'],part['name']=='Lens'))
        bevel=obj.modifiers.new('R6 edge softening','BEVEL'); bevel.width=0.025; bevel.segments=2
        obj.modifiers.new('Weighted face normals','WEIGHTED_NORMAL')
        objects.append(obj)
    return objects

def area(name,location,power,size):
    bpy.ops.object.light_add(type='AREA',location=location)
    lamp=bpy.context.object; lamp.name=name; lamp.data.energy=power; lamp.data.shape='DISK'; lamp.data.size=size
    lamp.rotation_euler=(Vector((0,0,2))-lamp.location).to_track_quat('-Z','Y').to_euler()
area('Warm key',(0,-8,12),2000,10)
area('Cool silhouette rim',(0,5,9),2400,9)
bpy.ops.mesh.primitive_plane_add(size=200)
floor=bpy.context.object; floor.data.materials.append(material((0.035,0.05,0.055)))
bpy.ops.object.camera_add(location=(1,-23,12))
cam=bpy.context.object; scene.camera=cam; cam.data.type='ORTHO'; cam.data.ortho_scale=30
cam.rotation_euler=(Vector((0,0,2.5))-cam.location).to_track_quat('-Z','Y').to_euler()
for row in range(2):
    temporary=[]
    for i,sample in enumerate(DATA[row*5:row*5+5]):
        shift=(i-2)*5.2
        temporary+=crew(sample,shift)
        bpy.ops.object.text_add(location=(shift-1.9,-1.5,6.5))
        t=bpy.context.object; t.data.body=sample['name']; t.data.size=0.25
        t.rotation_euler=cam.rotation_euler; t.data.materials.append(material((0.8,0.72,0.55)))
        temporary.append(t)
    scene.render.filepath=str(OUT/('before.png' if row==0 else 'after.png'))
    bpy.ops.render.render(write_still=True)
    for obj in temporary: bpy.data.objects.remove(obj,do_unlink=True)

# Same corpse, old and revised camera framing. Camera specs correspond to the
# minimum-distance case in DeathCamController (the closest/injury-critical case).
crew(DATA[9],0)
cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'
cam.data.lens=cam.data.sensor_height/(2*math.tan(math.radians(70)/2))
scene.render.resolution_x=1600; scene.render.resolution_y=1000
w=EXPORT['witness']
torso=next(p['cf'] for p in DATA[9]['parts'] if p['name']=='Torso')
for name,position,target in [
    ('witness-before',(0,-4.5,6),(torso[0],torso[2],torso[1])),
    ('witness-after',(0,-w['DistanceMin']*(1-w['PushFraction']),3+w['Height']),(0,0,3-w['FocusDrop'])),
]:
    cam.location=position
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)
print('Rendered 4 comparisons at resolution_percentage=50')
