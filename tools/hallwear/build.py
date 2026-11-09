"""Blender 5.2: the Depot hall's lived-in props (Builders/HallWear) as phone-cheap meshes.

blender -b --python tools/hallwear/build.py -- <out dir> [--no-render]

Each prop is one mesh with one baked 512 texture: procedural paint, tin, leather, canvas and wood
with grime gathering in the crevices (ambient occlusion baked into the colour). Sizes are in studs,
standing on z = 0 with the front toward -Y here (-Z in the exported OBJ, the MeshPart front).
Writes <id>.obj/.mtl/.png per prop and a 50% close-up render of each (review_<id>.png).

  churn    a 17-gallon milk churn: lathe body, shoulder and neck, rolled hoops, two handles,
           a lid with its knob, dents, the paint worn to the tin at the hoops and rust at the foot
  trunk    a steamer trunk: domed lid seam, two leather straps with buckles, brass corner caps,
           rivet rows, end handles and travel labels
  hatbox   a round hatbox with its lid rim and a strap
  barrow   a porter's barrow: plank bed on iron rails, nose plate, two spoked wheels, legs
  sack     a full canvas mail sack fallen over: wide flat base, sagging top, folds and creases, a
           pleated neck tied with two turns of rope, the Company's stencil
  coat     a travelling coat thrown over a case, skirts hanging in folds, a sleeve fallen down the front
  puddle   a thin pool with a ragged edge (Builders/HallWear makes it dark glass that holds the lamps)
"""
import bpy, bmesh, math, sys, random
from pathlib import Path
from mathutils import Vector, Matrix, noise

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = Path(args[0] if args else 'assets/hallwear')
OUT.mkdir(parents=True, exist_ok=True)
RENDER = '--no-render' not in args
TEX = 512
random.seed(1887)


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def mat(name, base, rough=.7, metal=0., grime=.55, rust=None, grain=None):
    """A procedural surface: base colour broken up by noise, darker where occluded (grime), with
    optional rust patches and wood/canvas grain."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; n = nt.nodes; L = nt.links
    bsdf = n['Principled BSDF']
    bsdf.inputs['Roughness'].default_value = rough; bsdf.inputs['Metallic'].default_value = metal
    tex = n.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value = 9; tex.inputs['Detail'].default_value = 8
    ramp = n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*[c * .78 for c in base], 1); ramp.color_ramp.elements[1].color = (*base, 1)
    L.new(tex.outputs['Fac'], ramp.inputs['Fac'])
    col = ramp.outputs['Color']
    if grain:
        wave = n.new('ShaderNodeTexWave'); wave.inputs['Scale'].default_value = grain; wave.inputs['Distortion'].default_value = 6
        mix = n.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs['Factor'].default_value = .35
        L.new(col, mix.inputs[6]); L.new(wave.outputs['Color'], mix.inputs[7]); col = mix.outputs[2]
    if rust:
        rn = n.new('ShaderNodeTexNoise'); rn.inputs['Scale'].default_value = 4; rn.inputs['Detail'].default_value = 10
        rr = n.new('ShaderNodeValToRGB'); rr.color_ramp.elements[0].position = .63; rr.color_ramp.elements[1].position = .68
        L.new(rn.outputs['Fac'], rr.inputs['Fac'])
        mix = n.new('ShaderNodeMix'); mix.data_type = 'RGBA'
        mix.inputs[7].default_value = (*rust, 1)
        L.new(rr.outputs['Color'], mix.inputs['Factor']); L.new(col, mix.inputs[6]); col = mix.outputs[2]
    ao = n.new('ShaderNodeAmbientOcclusion'); ao.inputs['Distance'].default_value = .35
    dirt = n.new('ShaderNodeMix'); dirt.data_type = 'RGBA'
    dirt.inputs[7].default_value = (.05, .04, .03, 1)
    inv = n.new('ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1
    L.new(ao.outputs['AO'], inv.inputs[1])
    gm = n.new('ShaderNodeMath'); gm.operation = 'MULTIPLY'; gm.inputs[1].default_value = grime
    L.new(inv.outputs[0], gm.inputs[0]); L.new(gm.outputs[0], dirt.inputs['Factor'])
    L.new(col, dirt.inputs[6])
    L.new(dirt.outputs[2], bsdf.inputs['Base Color'])
    return m


def obj_from(bm, name, material):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def lathe(profile, segs=24, name='lathe', material=None):
    """Revolve (radius, height) pairs about z."""
    bm = bmesh.new(); rings = []
    for r, z in profile:
        rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for a in
                      [2 * math.pi * i / segs for i in range(segs)]])
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            bm.faces.new((a[i], a[(i + 1) % segs], b[(i + 1) % segs], b[i]))
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    return obj_from(bm, name, material)


def torus(R, r, at, rot=(0, 0, 0), name='ring', material=None, segs=(24, 8)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=segs[0], minor_segments=segs[1],
                                     location=at, rotation=rot)
    ob = bpy.context.object; ob.name = name; ob.data.materials.append(material); return ob


def box(size, at, rot=(0, 0, 0), bevel=.04, name='box', material=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at, rotation=rot)
    ob = bpy.context.object; ob.scale = size; ob.name = name
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        mod = ob.modifiers.new('b', 'BEVEL'); mod.width = bevel; mod.segments = 2
        bpy.ops.object.modifier_apply(modifier='b')
    ob.data.materials.append(material); return ob


def cyl(r, depth, at, rot=(0, 0, 0), name='cyl', material=None, verts=16):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=at, rotation=rot, vertices=verts)
    ob = bpy.context.object; ob.name = name; ob.data.materials.append(material); return ob


def ball(r, at, name='ball', material=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=at, segments=10, ring_count=6)
    ob = bpy.context.object; ob.name = name; ob.data.materials.append(material); return ob


def dent(ob, centre, radius, depth):
    """Push vertices near `centre` inward along their normals."""
    for v in ob.data.vertices:
        d = (ob.matrix_world @ v.co - Vector(centre)).length
        if d < radius:
            v.co -= v.normal * depth * (1 - d / radius) ** 2


def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join(); ob = bpy.context.object; ob.name = name
    bpy.ops.object.shade_auto_smooth(angle=math.radians(35))
    return ob


def bake_export(ob):
    """One UV atlas, the materials' colour (with baked grime) into one 512 image, OBJ out."""
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    # stand it on its base, centred, as Builders/HallWear places it (MeshParts sit on their box centre)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo = [v.co for v in ob.data.vertices]
    shift = Vector(((min(v.x for v in lo) + max(v.x for v in lo)) / 2, (min(v.y for v in lo) + max(v.y for v in lo)) / 2,
                    min(v.z for v in lo)))
    for v in ob.data.vertices:
        v.co -= shift
        v.co.x, v.co.y = -v.co.x, -v.co.y  # half round, so the front (-Y) leaves the OBJ facing -Z
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    im = bpy.data.images.new(f'{ob.name}_tex', TEX, TEX)
    for m in ob.data.materials:
        node = m.node_tree.nodes.new('ShaderNodeTexImage'); node.image = im
        m.node_tree.nodes.active = node
    sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.samples = 32
    sc.render.bake.use_pass_direct = False; sc.render.bake.use_pass_indirect = False
    sc.render.bake.margin = 4
    bpy.ops.object.bake(type='DIFFUSE')
    im.filepath_raw = str(OUT / f'{ob.name}.png'); im.file_format = 'PNG'; im.save()
    # the exported mesh carries just the baked image
    baked = bpy.data.materials.new(f'{ob.name}_baked'); baked.use_nodes = True
    t = baked.node_tree.nodes.new('ShaderNodeTexImage'); t.image = im
    baked.node_tree.links.new(t.outputs['Color'], baked.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    ob.data.materials.clear(); ob.data.materials.append(baked)
    bpy.ops.wm.obj_export(filepath=str(OUT / f'{ob.name}.obj'), export_selected_objects=True, forward_axis='NEGATIVE_Z',
                          up_axis='Y', export_materials=True, path_mode='RELATIVE', export_normals=True, export_uv=True)
    return len(ob.data.polygons)


def shot(ob, path):
    sc = bpy.context.scene
    for o in list(sc.objects):
        if o.type in ('CAMERA', 'LIGHT'):
            bpy.data.objects.remove(o, do_unlink=True)
    lo = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    centre = sum(lo, Vector()) / 8; span = max((a - b).length for a in lo for b in lo)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
    cam.location = centre + Vector((span * .8, -span * 1.3, span * .55)); cam.data.lens = 50
    cam.rotation_euler = (centre - cam.location).to_track_quat('-Z', 'Y').to_euler(); sc.camera = cam
    for loc, e, col in [((3, -4, 5), 600, (1, .82, .62)), ((-4, -1, 3), 180, (.7, .78, 1))]:
        lamp = bpy.data.objects.new('l', bpy.data.lights.new('l', 'AREA')); sc.collection.objects.link(lamp)
        lamp.data.energy = e * span; lamp.data.size = span; lamp.data.color = col
        lamp.location = centre + Vector(loc) * span * .5
        lamp.rotation_euler = (centre - lamp.location).to_track_quat('-Z', 'Y').to_euler()
    sc.world.use_nodes = True; sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.03, .03, .035, 1)
    sc.render.resolution_x = sc.render.resolution_y = 480; sc.cycles.samples = 48; sc.cycles.use_denoising = True
    sc.view_settings.view_transform = 'AgX'; sc.render.filepath = str(path); bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------------------------------------
# linear colours (they read lighter on screen): dark, as the hall's lamps will lift them
TIN = (.34, .35, .33); PAINT = (.07, .11, .09); RUST = (.11, .035, .012)
LEATHER = (.16, .07, .035); BRASS = (.5, .34, .12); CANVAS = (.19, .15, .09); WOOD = (.2, .1, .05); IRON = (.05, .045, .04)


def churn():
    painted = mat('churn_paint', PAINT, rough=.6, rust=RUST, grime=.6)
    tin = mat('churn_tin', TIN, rough=.35, metal=.85, rust=RUST, grime=.5)
    body = lathe([(.0, 0), (.6, 0), (.64, .05), (.65, .3), (.66, 1.3), (.6, 1.55), (.42, 1.82), (.34, 1.9), (.34, 2.08),
                  (.4, 2.1), (.4, 2.16), (.0, 2.16)], segs=28, name='body', material=painted)
    for c, r, d in [((.5, -.4, .9), .3, .05), ((-.45, .45, .6), .25, .04), ((.2, .62, 1.2), .22, .035)]:
        dent(body, c, r, d)
    parts = [body]
    for z in (.32, 1.3):
        parts.append(torus(.665, .035, (0, 0, z), name='hoop', material=tin))
    for s in (-1, 1):
        parts.append(torus(.16, .03, (s * .5, 0, 1.62), rot=(math.pi / 2, 0, 0), name='handle', material=tin))
    parts.append(cyl(.43, .12, (0, 0, 2.22), name='lid', material=tin, verts=24))
    parts.append(cyl(.12, .14, (0, 0, 2.34), name='knob', material=tin, verts=12))
    parts.append(ball(.07, (0, 0, 2.43), name='knob_top', material=tin))
    for i in range(16):  # rivets round the shoulder seam
        a = 2 * math.pi * i / 16
        parts.append(ball(.025, (.61 * math.cos(a), .61 * math.sin(a), 1.52), name='rivet', material=tin))
    return join(parts, 'churn')


def trunk():
    hide = mat('trunk_hide', LEATHER, rough=.75, grime=.6)
    brass = mat('trunk_brass', BRASS, rough=.3, metal=.9, grime=.55)
    strap = mat('trunk_strap', (.16, .08, .05), rough=.65, grime=.5)
    label = mat('trunk_label', (.42, .34, .2), rough=.9, grime=.4)
    W, D, H = 2.2, 1.3, 1.25
    parts = [box((W, D, H * .72), (0, 0, H * .36), name='base', material=hide, bevel=.05),
             box((W, D, H * .28), (0, 0, H * .86), name='lid', material=hide, bevel=.07)]
    parts.append(box((W + .02, D + .02, .05), (0, 0, H * .72), name='seam', material=brass, bevel=.01))
    for x in (-.55, .55):
        parts.append(box((.16, D + .04, H + .04), (x, 0, H / 2), name='strap', material=strap, bevel=.01))
        parts.append(box((.2, .04, .16), (x, -D / 2 - .03, H * .62), name='buckle', material=brass, bevel=.008))
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (0, 1):
                parts.append(box((.18, .18, .18), (sx * (W / 2 - .07), sy * (D / 2 - .07), .07 + sz * (H - .14)),
                                 name='corner', material=brass, bevel=.03))
        parts.append(box((.06, .5, .1), (sx * (W / 2 + .03), 0, H * .62), name='handle', material=strap, bevel=.02))
    for i in range(9):  # rivet row along the lid seam
        parts.append(ball(.022, (-W / 2 + .2 + i * (W - .4) / 8, -D / 2 - .01, H * .68), name='rivet', material=brass))
    for x, z, r in [(-.25, .45, 8), (.2, .25, -5)]:  # travel labels on the front
        lab = box((.38, .01, .26), (x, -D / 2 - .012, z), rot=(0, math.radians(r), 0), name='label', material=label, bevel=0)
        parts.append(lab)
    return join(parts, 'trunk')


def hatbox():
    card = mat('hat_card', (.14, .045, .04), rough=.85, grime=.5)
    band = mat('hat_band', (.12, .07, .05), rough=.6, grime=.4)
    parts = [lathe([(0, 0), (.5, 0), (.5, .55), (0, .55)], segs=28, name='box', material=card),
             lathe([(0, .5), (.53, .5), (.53, .72), (0, .72)], segs=28, name='lid', material=card),
             box((.08, 1.1, .02), (0, 0, .73), name='strap', material=band, bevel=0),
             box((.08, .02, .7), (0, -.53, .37), name='strap2', material=band, bevel=0),
             box((.08, .02, .7), (0, .53, .37), name='strap3', material=band, bevel=0)]
    return join(parts, 'hatbox')


def barrow():
    wood = mat('bar_wood', WOOD, rough=.8, grime=.6, grain=6)
    iron = mat('bar_iron', IRON, rough=.5, metal=.8, rust=RUST, grime=.4)
    L = 4.6
    parts = []
    for i in range(5):  # the plank bed, gaps between planks
        parts.append(box((L * .78, .38, .1), (-.2, -.84 + i * .42, .95), name='plank', material=wood, bevel=.015))
    for s in (-1, 1):  # rails running out into handles
        parts.append(box((L + .4, .12, .12), (-.1, s * 1.02, 1.0), name='rail', material=iron, bevel=.02))
        parts.append(cyl(.06, .5, (-L / 2 - .3, s * 1.02, 1.0), rot=(0, math.pi / 2, 0), name='grip', material=wood))
        parts.append(box((.1, .1, .9), (-1.6, s * .95, .5), name='leg', material=iron, bevel=.015))
        # a spoked wheel
        hub = (1.3, s * 1.2, .75)
        parts.append(torus(.7, .06, hub, rot=(math.pi / 2, 0, 0), name='rim', material=iron, segs=(28, 8)))
        parts.append(cyl(.14, .22, hub, rot=(math.pi / 2, 0, 0), name='hub', material=iron, verts=12))
        for k in range(8):
            a = math.pi * k / 4
            parts.append(box((.05, .05, 1.28), hub, rot=(0, a, 0), name='spoke', material=iron, bevel=0))
    parts.append(box((.12, 2.3, .9), (L / 2 - .25, 0, 1.4), name='nose', material=iron, bevel=.02))
    parts.append(cyl(.05, 2.5, (1.3, 0, .75), rot=(math.pi / 2, 0, 0), name='axle', material=iron, verts=10))
    return join(parts, 'barrow')


def sack():
    canvas = mat('sack_canvas', CANVAS, rough=.95, grime=.7, grain=40)
    ink = mat('sack_ink', (.012, .01, .008), rough=.9, grime=.2)
    rope = mat('sack_rope', (.16, .11, .05), rough=.9, grime=.5, grain=60)
    # a full canvas sack fallen over: a wide flat base settled onto the floor, the top sagging
    # between what is packed inside, folds and creases in the cloth, narrowing to a bunched neck at +X
    bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 0))
    bag = bpy.context.object; bag.name = 'bag'; bag.data.materials.append(canvas)
    sub = bag.modifiers.new('s', 'SUBSURF'); sub.levels = 3; bpy.ops.object.modifier_apply(modifier='s')
    for v in bag.data.vertices:
        x, y, z = v.co  # each in -1..1 (rounded)
        neck = max(x - .25, 0) / .75
        w = .55 * (1 - .62 * neck ** 1.3) * (1 + .16 * min(max(-z, 0), 1))  # the base spreads wider
        h = .32 * (1 - .5 * neck ** 1.1)
        top = max(z, 0)
        sag = .3 * math.exp(-((x + .15) / .55) ** 2) * top  # the middle settles
        fold = .045 * math.sin(x * 9 + 2.2 * math.sin(y * 3.1)) * (z > -.4)  # long folds across the cloth
        crease = .03 * math.sin(math.atan2(y, z + 1.2) * 11) * neck  # pleats gathering to the neck
        lump = noise.noise(Vector((x * 1.6, y * 1.6, z * 1.6))) * .06 * top
        zz = (z * h + h) * (1 - sag) + (fold + lump) * (z > -.3)
        if z < -.6:
            zz = min(zz, .015)  # flat on the floor
        v.co = Vector((x * .78, y * w + crease * y, max(zz, 0)))
    parts = [bag]
    # the neck: canvas gathered into pleats, flaring above the tie
    bpy.ops.mesh.primitive_cylinder_add(radius=1, depth=1, vertices=32, location=(0, 0, 0))
    neck = bpy.context.object; neck.name = 'neck'; neck.data.materials.append(canvas)
    sub = neck.modifiers.new('s', 'SUBSURF'); sub.levels = 2; bpy.ops.object.modifier_apply(modifier='s')
    for v in neck.data.vertices:
        t = v.co.z + .5  # 0..1 along the neck
        r = .2 - .08 * math.sin(math.pi * min(t / .55, 1)) + .07 * max(t - .55, 0) / .45
        a = math.atan2(v.co.y, v.co.x)
        r *= 1 + .16 * math.sin(a * 9 + t * 3)  # pleats
        v.co = Vector((t * .42, r * math.cos(a), r * math.sin(a)))
    neck.location = (.66, 0, .22)
    parts.append(neck)
    for k, dx in enumerate((.86, .9)):  # two turns of rope round the gather
        parts.append(torus(.135 + k * .01, .028, (dx, 0, .22), rot=(0, math.pi / 2, 0), name='tie', material=rope, segs=(18, 6)))
    tail = cyl(.022, .4, (.92, -.12, .07), rot=(math.radians(70), 0, math.radians(20)), name='end', material=rope, verts=6)
    parts.append(tail)
    bpy.ops.object.text_add(location=(-.12, 0, 1.0))
    txt = bpy.context.object; txt.data.body = 'C.D. MAILS'; txt.data.size = .22; txt.data.align_x = 'CENTER'
    txt.data.align_y = 'CENTER'; txt.data.extrude = .003
    bpy.ops.object.convert(target='MESH'); txt.data.materials.append(ink)
    sw = txt.modifiers.new('w', 'SHRINKWRAP'); sw.target = bag; sw.wrap_method = 'PROJECT'
    sw.use_project_z = True; sw.use_negative_direction = True; sw.offset = .004
    bpy.context.view_layer.objects.active = txt; bpy.ops.object.modifier_apply(modifier='w')
    parts.append(txt)
    return join(parts, 'sack')


def puddle():
    water = mat('puddle_water', (.006, .007, .009), rough=.05, grime=.0)
    # a thin pool with a ragged, uneven edge: a fan of points round a noisy outline
    bm = bmesh.new(); n = 56
    centre = bm.verts.new((0, 0, .004))
    ring = []
    for i in range(n):
        a = 2 * math.pi * i / n
        r = 1 + .32 * noise.noise(Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, .3))) + .12 * math.sin(a * 5 + 1) \
            + .07 * math.sin(a * 13)
        ring.append(bm.verts.new((r * math.cos(a) * 1.15, r * math.sin(a) * .78, .004)))
    for i in range(n):
        bm.faces.new((centre, ring[i], ring[(i + 1) % n]))
    return obj_from(bm, 'puddle', water)


def coat():
    wool = mat('coat_wool', (.2, .17, .12), rough=.95, grime=.6, grain=80)
    lining = mat('coat_lining', (.12, .03, .03), rough=.7, grime=.5)
    # a travelling coat thrown over a case: a cloth draped over a 1.5 x 1.0 top, its skirts hanging down
    # the front and side in folds, a sleeve fallen down the front, the collar turned up at the back
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=28, y_subdivisions=36, size=1)
    cloth = bpy.context.object; cloth.name = 'cloth'; cloth.data.materials.append(wool)
    for v in cloth.data.vertices:
        u, w = v.co.x + .5, v.co.y + .5  # 0..1 across, 0..1 down the length
        x = (u - .5) * 1.6
        d = w * 2.6  # distance laid along the coat from the collar
        if d < 1.05:  # lying over the top, a little crumpled
            y, z = .5 - d, 0.0 + .03 * math.sin(u * 17) * math.sin(d * 6)
        else:  # over the front edge and hanging, folds deepening as it falls
            t = d - 1.05
            y = -.55 - .06 * t - .05 * math.sin(u * 13 + t * 2)
            z = -t
        z += noise.noise(Vector((x * 2, y * 2, d))) * .025
        v.co = Vector((x * (1 + .05 * max(d - 1.05, 0)), y, z))
    sol = cloth.modifiers.new('t', 'SOLIDIFY'); sol.thickness = .04
    bpy.context.view_layer.objects.active = cloth; bpy.ops.object.modifier_apply(modifier='t')
    parts = [cloth]
    sleeve = cyl(.16, 1.3, (-.62, -.62, -.55), rot=(math.radians(12), math.radians(8), 0), name='sleeve', material=wool, verts=12)
    parts.append(sleeve)
    parts.append(cyl(.17, .14, (-.55, -.66, -1.2), rot=(math.radians(12), 0, 0), name='cuff', material=lining, verts=12))
    dark = mat('coat_collar', (.1, .08, .06), rough=.9, grime=.5)
    parts.append(box((1.1, .16, .2), (0, .46, .09), rot=(math.radians(-25), 0, 0), name='collar', material=dark, bevel=.05))
    ob = join(parts, 'coat')
    for v in ob.data.vertices:
        v.co.z += 1.55  # its top lies 1.55 above the floor, the hem ends near the floor
    return ob


report = {}
for build in (churn, trunk, hatbox, barrow, sack, puddle, coat):
    clear()
    ob = build()
    report[ob.name] = bake_export(ob)
    if RENDER:
        shot(ob, OUT / f'review_{ob.name}.png')
print('HALLWEAR', report)
