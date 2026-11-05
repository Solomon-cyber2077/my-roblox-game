"""Blender 5.2: meshes for the period signage, UV'd onto tools/signage/textures.py's maps.

blender -b --python tools/signage/build.py -- <dir with atlas.json and the maps> [--no-render]

One mesh per sign, sized in studs to the part its SurfaceGui sat on: X across, Y up, the face
toward -Z in the OBJ (Roblox front), its back at z = 0 so it sits on the old part's face.
Paper waves, curls at the foot and loses its torn corner; plates are bevelled with screw
heads; stone and slate faces lie flush. Writes <sign>.obj, signage.blend, review renders.
"""
import bpy, bmesh, json, math, random, sys
from pathlib import Path
from mathutils import Vector

DIR = Path(sys.argv[sys.argv.index('--') + 1])
SIGNS = json.loads((DIR / 'atlas.json').read_text())
RNG = random.Random(7)


def uv_of(rect, u, v):
    """u, v in 0-1 across the sign (v up) to the atlas rect (rect origin top-left)."""
    x0, y0, x1, y1 = rect
    return (x0 + (x1 - x0) * u, 1 - (y0 + (y1 - y0) * (1 - v)))


def sheet(name, sign, nx, ny, wave, curl, torn, tack):
    w, h = sign['size']
    rect = sign['rect']
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new('UV')
    grid = {}
    cut = 0.62 * (w / 7) if torn else 0
    for j in range(ny + 1):
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            x, y = (u - .5) * w, v * h
            z = wave * (1 + math.sin(u * 7.1 + v * 3.3) * .5 + math.sin(v * 11.0 - u * 2.0) * .3) * u * (1 - u) * 2
            for cu in (0, 1):  # the foot's corners lift off the board
                d = math.hypot(u - cu, v) * min(w, h)
                if d < curl[0]:
                    z += curl[1] * (1 - d / curl[0]) ** 2
            grid[i, j] = (bm.verts.new((x, y, -(0.004 + z))), u, v)
    for j in range(ny):
        for i in range(nx):
            q = [grid[i, j], grid[i + 1, j], grid[i + 1, j + 1], grid[i, j + 1]]
            cu, cv = (i + .5) / nx, (j + .5) / ny
            if torn and cv * h > h - cut * 1.2:
                corner_u = 1 if torn > 0 else 0
                if abs(cu - corner_u) * w + (h - cv * h) < cut:
                    continue
            f = bm.faces.new([g[0] for g in reversed(q)])
            for loop, g in zip(f.loops, reversed(q)):
                loop[uvl].uv = uv_of(rect, g[1], g[2])
    if tack:
        c = Vector((0, h - 0.12 * h / 2.3, -0.02))
        r = 0.045
        ring = [bm.verts.new(c + Vector((r * math.cos(a), r * math.sin(a), 0))) for a in [k * math.tau / 10 for k in range(10)]]
        top = bm.verts.new(c + Vector((0, 0, -0.025)))
        for k in range(10):
            f = bm.faces.new((ring[(k + 1) % 10], ring[k], top))
            for loop in f.loops:
                loop[uvl].uv = (0.97, 0.02)  # the atlas's dark margin: an iron tack
    return finish(name, bm)


def plate(name, sign, t, bevel, screws, dome=0.0):
    w, h = sign['size']
    rect = sign['rect']
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new('UV')
    nx, ny = 8, 4

    def face(pts_uv):
        vs = [bm.verts.new(p) for p, _ in pts_uv]
        f = bm.faces.new(vs)
        for loop, (_, uv) in zip(f.loops, pts_uv):
            loop[uvl].uv = uv
        return f
    # the face, inset by the bevel, slightly domed for enamel
    for j in range(ny):
        for i in range(nx):
            q = []
            for (a, b) in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)):
                u, v = a / nx, b / ny
                x, y = (u - .5) * (w - 2 * bevel), bevel + v * (h - 2 * bevel)
                z = -t - dome * math.sin(u * math.pi) * math.sin(v * math.pi)
                uu = bevel / w + u * (1 - 2 * bevel / w)
                vv = bevel / h + v * (1 - 2 * bevel / h)
                q.append(((x, y, z), uv_of(rect, uu, vv)))
            face(list(reversed(q)))
    # the bevel and sides, sampled from the rim of the rect
    outer = [(-w / 2, 0), (w / 2, 0), (w / 2, h), (-w / 2, h)]
    inner = [(-w / 2 + bevel, bevel), (w / 2 - bevel, bevel), (w / 2 - bevel, h - bevel), (-w / 2 + bevel, h - bevel)]
    rim_uv = [uv_of(rect, .015, .5)] * 4  # bevel, sides and screws take the rim's colour, not a stretch of the face
    for k in range(4):
        a, b = k, (k + 1) % 4
        face([((outer[b][0], outer[b][1], -t * .45), rim_uv[b]), ((outer[a][0], outer[a][1], -t * .45), rim_uv[a]),
              ((inner[a][0], inner[a][1], -t), rim_uv[a]), ((inner[b][0], inner[b][1], -t), rim_uv[b])])
        face([((outer[a][0], outer[a][1], 0), rim_uv[a]), ((outer[a][0], outer[a][1], -t * .45), rim_uv[a]),
              ((outer[b][0], outer[b][1], -t * .45), rim_uv[b]), ((outer[b][0], outer[b][1], 0), rim_uv[b])])
    for sx, sy in screws:
        c = Vector((sx * (w / 2 - bevel * 1.6), bevel * 1.6 if sy < 0 else h - bevel * 1.6, -t - dome * .2))
        r = min(w, h) * 0.035
        ring = [bm.verts.new(c + Vector((r * math.cos(a), r * math.sin(a), 0))) for a in [k * math.tau / 12 for k in range(12)]]
        mid = [bm.verts.new(c + Vector((r * .6 * math.cos(a), r * .6 * math.sin(a), -r * .45))) for a in [k * math.tau / 12 for k in range(12)]]
        top = bm.verts.new(c + Vector((0, 0, -r * .6)))
        for k in range(12):
            for f in (bm.faces.new((ring[(k + 1) % 12], ring[k], mid[k], mid[(k + 1) % 12])), bm.faces.new((mid[(k + 1) % 12], mid[k], top))):
                for loop in f.loops:
                    loop[uvl].uv = rim_uv[0]
    return finish(name, bm)


def flat(name, sign, offset=0.004):
    w, h = sign['size']
    rect = sign['rect']
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new('UV')
    pts = [((-w / 2, 0), (0, 0)), ((w / 2, 0), (1, 0)), ((w / 2, h), (1, 1)), ((-w / 2, h), (0, 1))]
    vs = [bm.verts.new((p[0], p[1], -offset)) for p, _ in reversed(pts)]
    f = bm.faces.new(vs)
    for loop, (_, uv) in zip(f.loops, reversed(pts)):
        loop[uvl].uv = uv_of(rect, *uv)
    return finish(name, bm)


def finish(name, bm):
    # built as X across, Y up, face toward -Z; Blender stands it up (Z up, face toward -Y),
    # which the export turns back into Y up, face toward -Z
    for v in bm.verts:
        v.co = Vector((v.co.x, v.co.z, v.co.y))
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


MATS = {}


def material(tex):
    if tex in MATS:
        return MATS[tex]
    m = bpy.data.materials.new(tex); m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes['Principled BSDF']
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(str(DIR / f'{tex}_color.png'))
    nt.links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
    if (DIR / f'{tex}_normal.png').exists():
        n = nt.nodes.new('ShaderNodeTexImage'); n.image = bpy.data.images.load(str(DIR / f'{tex}_normal.png'))
        n.image.colorspace_settings.name = 'Non-Color'
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nt.links.new(n.outputs['Color'], nm.inputs['Color']); nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    for key, sock in (('rough', 'Roughness'), ('metal', 'Metallic')):
        if (DIR / f'{tex}_{key}.png').exists():
            r = nt.nodes.new('ShaderNodeTexImage'); r.image = bpy.data.images.load(str(DIR / f'{tex}_{key}.png'))
            r.image.colorspace_settings.name = 'Non-Color'
            nt.links.new(r.outputs['Color'], bsdf.inputs[sock])
    if tex.startswith('chalk'):
        bsdf.inputs['Roughness'].default_value = .9
    MATS[tex] = m
    return m


bpy.ops.wm.read_factory_settings(use_empty=True)
objs = []
for name, sign in SIGNS.items():
    k = sign['kind']
    if k == 'poster':
        ob = sheet(name, sign, 14, 18, 0.025, (1.1, 0.09), sign['corner'], False)
    elif k == 'bill':
        ob = sheet(name, sign, 6, 9, 0.012, (0.35, 0.05), 0, name != 'bill_tom')
    elif k == 'iron':
        ob = plate(name, sign, 0.05, min(sign['size']) * 0.07, [(-1, -1), (1, -1), (-1, 1), (1, 1)])
    elif k == 'plaque':
        ob = plate(name, sign, 0.035, min(sign['size']) * 0.06, [(-1, -1), (1, -1), (-1, 1), (1, 1)])
    elif k == 'enamel':
        ob = plate(name, sign, 0.025, 0.03, [(-1, -1), (1, -1)], dome=0.012)
    elif k == 'stone':
        ob = flat(name, sign, 0.006)
    elif k == 'chalk':
        ob = flat(name, sign, 0.004)
    else:  # framed: samplers and cards behind the glass
        ob = flat(name, sign, 0.003)
    ob.data.materials.append(material(sign['tex']))
    objs.append(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.wm.obj_export(filepath=str(DIR / f'{name}.obj'), export_selected_objects=True, forward_axis='Z', up_axis='Y',
                          export_materials=False, export_normals=True, export_uv=True)
print('TRIS', {o.name: sum(p.loop_total - 2 for p in o.data.polygons) for o in objs})

# ---------------------------------------------------------------- review board: every sign on a dark wall, rows by kind
sc = bpy.context.scene
ROWS = [('poster',), ('chalk',), ('bill', 'iron', 'plaque', 'enamel'), ('stone', 'sampler', 'card')]
top = 26.0
for kinds in ROWS:
    row = [o for o in objs if SIGNS[o.name]['kind'] in kinds]
    x, tall = 0.0, max(SIGNS[o.name]['size'][1] for o in row)
    for ob in row:
        w, h = SIGNS[ob.name]['size']
        ob.location = (x + w / 2, 0, top - h)
        x += w + 0.6
    top -= tall + 0.8
print('NORMAL_Y', objs[0].data.polygons[0].normal.y)
wall = bpy.data.meshes.new('wall'); wall.from_pydata([(-5, 0.02, -5), (70, 0.02, -5), (70, 0.02, 30), (-5, 0.02, 30)], [], [(0, 1, 2, 3)])
wo = bpy.data.objects.new('wall', wall); sc.collection.objects.link(wo)
wm = bpy.data.materials.new('wall'); wm.use_nodes = True
wm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.05, .04, .035, 1); wall.materials.append(wm)
bpy.ops.wm.save_as_mainfile(filepath=str(DIR / 'signage.blend'))
if '--no-render' in sys.argv:
    sys.exit(0)
sc.render.engine = 'BLENDER_EEVEE'; sc.eevee.taa_render_samples = 6
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = 1920, 1080, 50
sc.view_settings.view_transform = 'AgX'
world = bpy.data.worlds.new('w'); sc.world = world; world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Strength'].default_value = .3


def light(loc, energy, color, size):
    d = bpy.data.lights.new('l', 'AREA'); d.energy = energy; d.color = color; d.size = size
    o = bpy.data.objects.new('l', d); o.location = loc; sc.collection.objects.link(o)
    o.rotation_euler = (Vector((loc[0], 0, loc[2] - 2)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()


cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam


def shot(path, loc, target, lens, lights):
    for o in [o for o in sc.objects if o.type == 'LIGHT']:
        bpy.data.objects.remove(o)
    for l in lights:
        light(*l)
    cam.location = loc; cam.data.lens = lens
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = str(path); bpy.ops.render.render(write_still=True); print('OK', path.name)


shot(DIR / 'review_posters.png', (15, -30, 19), (15, 0, 19), 50, [((6, -8, 12), 6000, (1, .85, .65), 10), ((28, -6, 4), 2500, (.7, .8, 1), 8)])
shot(DIR / 'review_signs_raking.png', (13, -26, 4), (13, 0, 4), 50,
     [((-2, -3, 8), 5000, (1, .82, .6), 4), ((30, -12, 2), 1500, (.7, .8, 1), 8)])
