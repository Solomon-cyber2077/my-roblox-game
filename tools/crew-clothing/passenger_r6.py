"""The six hall passengers on the R6 body: before (the kit's flat box clothing) and after (the
passenger_textures.py sheets, Mabel's skirt mesh in each woman's cloth, and sculpted bags).
Run passenger_textures.py first, then: blender -b --python tools/crew-clothing/passenger_r6.py
Builds the bag meshes (post bag, paper bag, reticule) on one atlas, bags.png, and exports them
like mabel_r6.py (limb space, studs, -Z front; Studio's OBJ import turns them round, hence yaw 180
in Config/Passengers). Renders go to $PASSENGER_OUT/renders at 50%.
"""
import bpy, math, json, os, sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
OUT = Path(os.environ.get('PASSENGER_OUT', HERE.parents[1] / 'assets/crew-clothing/passengers-r6'))
MABEL = HERE.parents[1] / 'assets/crew-clothing/mabel-r6'
sys.path.insert(0, str(HERE))
ns = {'__file__': str(HERE / 'mabel_r6.py'), '__name__': 'mabel_r6'}
exec(compile((HERE / 'mabel_r6.py').read_text().rsplit('\nmain()', 1)[0], 'mabel_r6.py', 'exec'), ns)
ns['OUT'] = OUT
M, export, sheet_material, body_block, limb_rects, TORSO_R = (ns[k] for k in ('M', 'export', 'sheet_material', 'body_block', 'limb_rects', 'TORSO_R'))
head_point, textured, material, lin, shoot = ns['head_point'], ns['textured'], ns['material'], ns['lin'], ns['shoot']
LOOKS = {k: {f: tuple(v) if isinstance(v, list) else v for f, v in look.items()}
         for k, look in json.loads((OUT / 'looks.json').read_text()).items()}  # written by passenger_textures.py
TAU = math.tau
SKIN = {'Clerk': (230, 192, 160), 'Mother': (236, 204, 178), 'Gentleman': (222, 182, 150),
        'Porter': (196, 150, 118), 'Widow': (226, 200, 184), 'Newsboy': (234, 196, 164)}
SPACING = 4.6

# ------------------------------------------------------------------ bags
def superellipse(t, e):
    c, s = math.cos(t), math.sin(t)
    return math.copysign(abs(c) ** e, c), math.copysign(abs(s) ** e, s)

def soft_box(m, center, size, uv, e=.35, rows=10, seg=28, sag=0.0):
    """A stuffed bag body: superellipse rings (in x, y) stacked up z, bulging at mid height."""
    cx, cy, cz = center; w, d, h = [v / 2 for v in size]; u0, v0, u1, v1 = uv
    P, U = [], []
    for i in range(rows):
        z = -h + 2 * h * i / (rows - 1)
        bulge = 1 + .08 * math.sin(math.pi * i / (rows - 1)) - sag * (i / (rows - 1)) ** 2
        ring, uvs = [], []
        for j in range(seg):
            a, b = superellipse(TAU * j / seg, e)
            ring.append((cx + a * w * bulge, cy + b * d * bulge, cz + z))
            uvs.append((u0 + (u1 - u0) * j / seg, v0 + (v1 - v0) * i / (rows - 1)))
        P.append(ring); U.append(uvs)
    m.grid(P, U, lambda c: Vector(c) - Vector((cx, cy, c[2])), close=True)
    for z, k in ((-h, 0), (h, rows - 1)):  # flat-ish base and top
        pts = [P[k][j] for j in range(seg)]
        m.face(pts, [U[k][j] for j in range(seg)], (0, 0, 1 if k else -1))

def flap(m, center, w, d, h, depth, uv, thick=.025):
    """A curved leather flap over the top, falling `depth` down the outer face (here +Y, the back)."""
    cx, cy, cz = center; u0, v0, u1, v1 = uv
    path = [(cy - d * .6 + (d * 1.2) * k / 6, cz + h + .02 + .03 * math.sin(math.pi * k / 6)) for k in range(7)]
    path += [(cy + d * .62 + .01 * k, cz + h - depth * k / 5) for k in range(1, 6)]
    cols = 9; P, U = [], []
    for i, (y, z) in enumerate(path):
        row, uvr = [], []
        for j in range(cols):
            x = -w * 1.02 + 2.04 * w * j / (cols - 1)
            dz = -.02 * (x / w) ** 2  # edges droop
            row.append((cx + x, y, z + dz)); uvr.append((u0 + (u1 - u0) * j / (cols - 1), v0 + (v1 - v0) * i / (len(path) - 1)))
        P.append(row); U.append(uvr)
    m.grid(P, U, lambda c: Vector((0, c[1] - cy, c[2] - cz)))
    # underside so the flap has thickness from any angle
    Q = [[(x, y - thick * .5, z - thick) for x, y, z in r] for r in P]
    m.grid(Q, U, lambda c: Vector((0, cy - c[1], cz - c[2])))

def post_bag():
    m = M('post bag'); A = 1 / 1024
    c = (-.62, .72, -1.2)  # Torso space
    soft_box(m, c, (.95, .34, .75), (0, 0, 512 * A, 1 - 512 * A * .2), .3)
    flap(m, c, .475, .17, .375, .42, (0, .5, .5, 1))
    m.box((c[0], c[1] + .2, c[2] - .02), (.14, .03, .16), (768 * A, 1 - 640 * A, 1, 1 - 512 * A))  # brass catch
    for s in (-1, 1):  # strap stubs and their rings
        m.tube([(c[0] + s * .44, c[1], c[2] + .3), (c[0] + s * .48, c[1], c[2] + .48)], .035, .5, 1, 0, .25, 6)
    return m

def paper_bag():
    m = M('paper bag'); A = 1 / 1024
    c = (-.62, .72, -1.2)  # Torso space
    soft_box(m, c, (.95, .36, .75), (.5, 1 - .5, 1, 1), .4, sag=.06)
    for i, x in enumerate((-.24, .02, .26)):  # folded papers standing out of the open top
        cx = c[0] + x * .4; y = c[1] - .06 + i * .03; z0 = c[2] + .3
        P = [[(cx - .35 + .7 * j / 4, y + .02 * math.sin(j), z0 + .5 * k / 3) for j in range(5)] for k in range(4)]
        U = [[(0 + .5 * j / 4, .0 + .5 * k / 3) for j in range(5)] for k in range(4)]
        m.grid(P, U, lambda p: (0, -1, 0))
        Pb = [[(px, py + .012, pz) for px, py, pz in row] for row in P]
        m.grid(Pb, U, lambda p: (0, 1, 0))
    return m

def reticule():
    m = M('reticule'); A = 1 / 1024
    cx, cy, cz = 0, -.1, -1.81  # Left Arm space
    prof = [(0.0, -.27), (.12, -.25), (.22, -.17), (.26, -.04), (.24, .08), (.15, .16), (.09, .2), (.13, .27), (.16, .31)]
    seg = 20; P, U = [], []
    for i, (r, z) in enumerate(prof):
        ring, uvs = [], []
        for j in range(seg):
            t = TAU * j / seg
            rr = r * (1 + (.12 * math.sin(6 * t) if i >= len(prof) - 2 else 0))  # the ruffle above the drawstring
            ring.append((cx + rr * math.cos(t), cy + rr * math.sin(t), cz + z))
            uvs.append((.5 + .25 * j / seg, .5 - .25 * i / (len(prof) - 1) + .25))
        P.append(ring); U.append(uvs)
    m.grid(P, U, lambda c: Vector(c) - Vector((cx, cy, c[2])), close=True)
    # drawstring at the neck and the cord up to the wrist, a tassel below
    m.tube([(cx + .1 * math.cos(TAU * k / 12), cy + .1 * math.sin(TAU * k / 12), cz + .2) for k in range(12)],
           .022, .75, 1, .25, .5, 5, True)
    m.tube([(cx + .09, cy, cz + .2), (cx + .05, cy, cz + .45), (cx, cy, cz + .66)], .016, .75, 1, .25, .5, 5)
    m.tube([(cx - .09, cy, cz + .2), (cx - .05, cy, cz + .45), (cx, cy, cz + .66)], .016, .75, 1, .25, .5, 5)
    m.tube([(cx, cy, cz - .27), (cx, cy, cz - .4)], lambda t: .03 + .03 * t, .75, 1, .5, .75, 6)
    return m

# ------------------------------------------------------------------ bodies
def skin_head(skin, dx):
    m = M('head'); seg, rows = 32, 14
    P = [[tuple(head_point(-math.pi + TAU * j / seg, .02 + (math.pi - .04) * i / (rows - 1))) for j in range(seg)] for i in range(rows)]
    m.grid(P, [[(0, 0)] * seg for _ in range(rows)], lambda c: c, close=True)
    return m.obj(material('skin', skin, .6), (dx, 0, 4.5))

def person(pid, look, dx, plain):
    shirt = None if plain else OUT / f'{pid.lower()}-shirt.png'
    pants = None if plain else OUT / f'{pid.lower()}-pants.png'
    skin = SKIN.get(pid) or tuple(look['skin'])  # the staff carry theirs in looks.json
    torso = sheet_material(pid + ' torso', shirt, look['coat'])
    arms = sheet_material(pid + ' arms', shirt, skin if not plain else look['coat'])
    legs = sheet_material(pid + ' legs', pants, look['lower'])
    body_block(pid + ' Torso', (dx, 0, 3), (2, 1, 2), TORSO_R, torso)
    body_block(pid + ' Right Arm', (dx - 1.5, 0, 3), (1, 1, 2), limb_rects(True), arms)
    body_block(pid + ' Left Arm', (dx + 1.5, 0, 3), (1, 1, 2), limb_rects(False), arms)
    body_block(pid + ' Right Leg', (dx - .5, 0, 1), (1, 1, 2), limb_rects(True), legs)
    body_block(pid + ' Left Leg', (dx + .5, 0, 1), (1, 1, 2), limb_rects(False), legs)
    skin_head(skin, dx)
    if look.get('skirt'):
        if plain:  # the kit's skirt block
            m = M(pid + ' skirt'); m.box((0, 0, 0), (2.3, 1.5, 2.0), (0, 0, 1, 1))
            m.obj(material(pid + ' skirt', look['lower']), (dx, 0, 1.0))
        else:
            sk = ns['skirt'](); ob = sk.obj(textured(OUT / f'{pid.lower()}-skirt.png', pid + ' skirt'), (dx, 0, 3))
            ob.name = pid + ' skirt mesh'

def bags(dx_of, plain):
    atlas = textured(OUT / 'bags.png', 'bag atlas', .7)
    if plain:
        for pid, size, color in (('Porter', (.95, .34, .75), (78, 50, 32)), ('Newsboy', (.95, .34, .75), (150, 136, 104))):
            m = M(pid + ' kit bag'); m.box((0, 0, 0), size, (0, 0, 1, 1)); m.obj(material(pid + ' bag', color), (dx_of[pid] - .62, .72, 1.8))
        m = M('kit purse'); m.box((0, 0, 0), (.5, .5, .5), (0, 0, 1, 1)); m.obj(material('purse', (137, 119, 84)), (dx_of['Mother'] + 1.5, -.1, 1.19))
        return
    for build, pid, limb, origin in ((post_bag, 'Porter', 'Torso', (0, 0, 3)), (paper_bag, 'Newsboy', 'Torso', (0, 0, 3)),
                                     (reticule, 'Mother', 'Left Arm', (1.5, 0, 3))):
        ob = export(build(), limb, origin, atlas, 'bags.png')
        ob.location.x += dx_of[pid]

def stage(width):
    scene = bpy.context.scene; scene.render.engine = 'CYCLES'; scene.cycles.samples = 40; scene.cycles.use_denoising = True
    scene.world.color = (.035, .03, .028)
    floor = M('floor'); floor.face([(-width, -9, 0), (width, -9, 0), (width, 6, 0), (-width, 6, 0)], [(0, 0)] * 4, (0, 0, 1))
    floor.obj(material('platform flags', (70, 64, 58), .8))
    wall = M('wall'); wall.face([(-width, 3.5, 0), (width, 3.5, 0), (width, 3.5, 10), (-width, 3.5, 10)], [(0, 0)] * 4, (0, -1, 0))
    wall.obj(material('hall brick', (92, 52, 38), .85))
    for loc, power, size, color in [((-5, -9, 9), 1400, 7, (1, .8, .58)), ((7, -5, 7), 450, 4, (.7, .78, 1)), ((0, 2, 9), 350, 5, (1, .85, .7))]:
        bpy.ops.object.light_add(type='AREA', location=loc); l = bpy.context.object
        l.data.energy = power; l.data.size = size; l.data.color = color
        l.rotation_euler = (Vector((0, 0, 3)) - l.location).to_track_quat('-Z', 'Y').to_euler()
    scene.view_settings.view_transform = 'AgX'; scene.render.resolution_percentage = 50
    return scene

def main():
    plain = os.environ.get('PASSENGER_PLAIN') == '1'
    (OUT / 'renders').mkdir(parents=True, exist_ok=True)
    ids = list(LOOKS)
    dx_of = {pid: (i - (len(ids) - 1) / 2) * SPACING for i, pid in enumerate(ids)}
    scene = stage(18)
    for pid in ids:
        person(pid, LOOKS[pid], dx_of[pid], plain)
    if 'Porter' in LOOKS:  # the staff (staff_textures.py) carry no bag meshes
        bags(dx_of, plain)
    tag = 'before' if plain else 'after'
    shoot(scene, f'{tag}-lineup.png', (0, -34, 4.0), (0, 0, 2.6), 50, (2000, 900))
    shoot(scene, f'{tag}-34-left.png', (dx_of[ids[0]] - 6, -9, 4.5), (dx_of[ids[1]] - .6, 0, 2.6), 45, (1400, 1000))
    bpy.data.objects['wall'].hide_render = True
    shoot(scene, f'{tag}-back.png', (2, 24, 4.5), (0, 0, 2.6), 50, (2000, 900))
    bpy.data.objects['wall'].hide_render = False
    if not plain:
        for pid in ('Porter', 'Gentleman') if 'Porter' in LOOKS else ids:
            shoot(scene, f'after-arms-length-{pid.lower()}.png', (dx_of[pid] - 1, -4.2, 4.2), (dx_of[pid], 0, 3.2), 45, (1200, 1000))
        manifest = ns['manifest']
        (OUT / 'manifest.json').write_text(json.dumps({
            'status': 'source assets; uploads and a Studio arm\'s-length check pending (HUMAN pending)',
            'sheets': {pid: {'shirt': f'{pid.lower()}-shirt.png', 'pants': f'{pid.lower()}-pants.png',
                             **({'skirtTexture': f'{pid.lower()}-skirt.png', 'skirtMesh': 'Mabel skirt 96135756126639'} if LOOKS[pid].get('skirt') else {})}
                       for pid in ids},
            'units': 'studs, limb space, -Z is the front', 'totalTriangles': sum(v['triangles'] for v in manifest.values()),
            'pieces': list(manifest.values())}, indent=2))

main()
