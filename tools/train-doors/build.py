"""Blender 5.2: the inner faces of the train's sliding door leaves (TrainShell's dressLeafInside).

blender -b --python tools/train-doors/build.py -- <dir with door_inside_*.png> [--no-render]

The leaves' meshes are modelled from outside, so their backs read flat. These sit on the back:
  door_inside_glazed_*  passenger leaf, 2.81 x 7.5: varnished teak stiles and rails, fielded
                        panels, the droplight opening (0.7 x 2.2, its middle 4.95 up) left open
                        in a bolection mould, a brass pull and kick plate
  door_inside_heavy_*   Workshop, Stores and cab leaves: oiled deal planks, three ledges and two
                        braces, iron straps and bolts, an iron pull (scale it to the cab's 2 x 7)
`_edgepos` puts the pull at +X (the meeting edge), `_edgeneg` at -X. Back on y = 0, built out
toward -Y; exported Y up with the face toward -Z. One 1024 texture set for all four.
"""
import bpy, bmesh, math, sys
from pathlib import Path
from mathutils import Vector

DIR = Path(sys.argv[sys.argv.index('--') + 1])
W, H = 2.81, 7.5
HW = W / 2
PX = 1 / 1024


def uvA(x, z):  # teak, grain up
    return ((x + 1.5) / 3 * 384 * PX, z / 7.6)


def uvB(x, z, z0, z1):  # teak, grain across, by place along the rail
    t = (z - z0) / max(1e-6, z1 - z0)
    return ((384 + (x + 1.5) / 3 * 384) * PX, 1 - (1 - t) * 128 * PX)


def uvC(x, z):  # deal planks, grain up
    return ((384 + (x + 1.5) / 3 * 384) * PX, 1 - (256 + (1 - z / 7.6) * 768) * PX)


def uvRegion(px0, py0, size=256):
    return lambda a, b: ((px0 + a * size) * PX, 1 - (py0 + (1 - b) * size) * PX)


uvD = uvRegion(768, 0)  # brass
uvE = uvRegion(768, 256)  # iron


class Leaf:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new('UV')

    def quad(self, pts, uvs):
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv
        return f

    def block(self, x0, x1, z0, z1, front, uvf, back=0.0, chamfer=0.0, sides=True):
        """A box from the leaf (y = back) out to y = front (< 0), its front edge chamfered."""
        c = chamfer
        fx0, fx1, fz0, fz1 = x0 + c, x1 - c, z0 + c, z1 - c
        sy = back + (front - back) * 0.4 if c else front  # the chamfer runs from the face to 40% of the depth
        F = lambda x, z, y: (x, y, z)
        # front
        self.quad([F(fx0, fz0, front), F(fx1, fz0, front), F(fx1, fz1, front), F(fx0, fz1, front)],
                  [uvf(fx0, fz0), uvf(fx1, fz0), uvf(fx1, fz1), uvf(fx0, fz1)])
        outer = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
        inner = [(fx0, fz0), (fx1, fz0), (fx1, fz1), (fx0, fz1)]
        for k in range(4):
            a, b = k, (k + 1) % 4
            if c:
                self.quad([F(*outer[b], sy), F(*outer[a], sy), F(*inner[a], front), F(*inner[b], front)],
                          [uvf(*outer[b]), uvf(*outer[a]), uvf(*inner[a]), uvf(*inner[b])])
            if sides:
                self.quad([F(*outer[a], back), F(*outer[a], sy), F(*outer[b], sy), F(*outer[b], back)],
                          [uvf(*outer[a]), uvf(*outer[a]), uvf(*outer[b]), uvf(*outer[b])])

    def strut(self, a, b, width, front, back, uvf):
        """A brace from a to b (x, z) on the leaf, `width` across, as a box."""
        a, b = Vector((a[0], a[1])), Vector((b[0], b[1]))
        d = (b - a).normalized(); n = Vector((-d.y, d.x)) * width / 2
        corners = [a - n, b - n, b + n, a + n]
        F = lambda p, y: (p.x, y, p.y)
        L = (b - a).length
        uvs = [uvf(0, 0), uvf(0, 1), uvf(1, 1), uvf(1, 0)]
        self.quad([F(p, front) for p in corners], uvs)
        for k in range(4):
            p, q = corners[k], corners[(k + 1) % 4]
            self.quad([F(p, back), F(p, front), F(q, front), F(q, back)], [uvs[k], uvs[k], uvs[(k + 1) % 4], uvs[(k + 1) % 4]])

    def stud(self, x, z, r, front, uvf, n=8):
        """A domed bolt or screw head."""
        ring = [self.bm.verts.new((x + r * math.cos(a), front, z + r * math.sin(a))) for a in [k * math.tau / n for k in range(n)]]
        top = self.bm.verts.new((x, front - r * 0.7, z))
        for k in range(n):
            f = self.bm.faces.new((ring[(k + 1) % n], ring[k], top))
            for loop in f.loops:
                loop[self.uv].uv = uvf(0.5, 0.5)

    def done(self):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        # every face looks into the car (-Y); flip any the recalc turned to the leaf
        for f in bm.faces:
            f.normal_update()
            if f.normal.y > 0.2:
                f.normal_flip()
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.collection.objects.link(ob)
        return ob


def glazed(edge):
    L = Leaf(f'door_inside_glazed_{"edgepos" if edge > 0 else "edgeneg"}')
    D = -0.07  # frame depth
    st = 0.3
    rail = lambda z0, z1, x0=-HW + st, x1=HW - st: L.block(x0, x1, z0, z1, D, lambda x, z: uvB(x, z, z0, z1), chamfer=0.015)
    # stiles, full height
    L.block(-HW, -HW + st, 0, H, D, uvA, chamfer=0.015)
    L.block(HW - st, HW, 0, H, D, uvA, chamfer=0.015)
    rail(H - 0.4, H); rail(3.2, 3.65); rail(0, 0.65)
    # lower: two fielded panels either side of a muntin
    L.block(-0.1, 0.1, 0.65, 3.2, D, uvA, chamfer=0.015)
    for x0, x1 in ((-HW + st, -0.1), (0.1, HW - st)):
        L.block(x0, x1, 0.65, 3.2, -0.022, uvA, sides=False)
        L.block(x0 + 0.16, x1 - 0.16, 0.85, 3.0, -0.05, uvA, chamfer=0.1)
    # upper: the droplight opening in its own frame, tall fielded panels beside it, one over it
    ox, oz0, oz1 = 0.35, 3.85, 6.05
    for s in (-1, 1):
        L.block(min(s * ox, s * (ox + 0.14)), max(s * ox, s * (ox + 0.14)), 3.65, H - 0.4, D, uvA, chamfer=0.015)
    rail(3.65, oz0, -ox, ox); rail(oz1, oz1 + 0.22, -ox, ox)
    for x0, x1 in ((-HW + st, -ox - 0.14), (ox + 0.14, HW - st)):
        L.block(x0, x1, 3.65, H - 0.4, -0.022, uvA, sides=False)
        L.block(x0 + 0.12, x1 - 0.12, 3.85, H - 0.6, -0.05, uvA, chamfer=0.08)
    L.block(-ox, ox, oz1 + 0.22, H - 0.4, -0.022, uvA, sides=False)
    L.block(-ox + 0.1, ox - 0.1, oz1 + 0.36, H - 0.54, -0.05, uvA, chamfer=0.06)
    # bolection mould standing proud round the opening
    m, d = 0.07, -0.11
    L.block(-ox - m, -ox, oz0 - m, oz1 + m, d, uvA, back=D, chamfer=0.025)
    L.block(ox, ox + m, oz0 - m, oz1 + m, d, uvA, back=D, chamfer=0.025)
    L.block(-ox, ox, oz0 - m, oz0, d, lambda x, z: uvB(x, z, oz0 - m, oz0), back=D, chamfer=0.025)
    L.block(-ox, ox, oz1, oz1 + m, d, lambda x, z: uvB(x, z, oz1, oz1 + m), back=D, chamfer=0.025)
    # brass: finger plate and pull on the meeting stile, kick plate across the foot
    px = edge * (HW - 0.15)
    L.block(px - 0.1, px + 0.1, 1.45, 2.85, D - 0.006, uvD, back=D)
    L.block(px - 0.035, px + 0.035, 1.6, 2.7, D - 0.14, uvD, back=D - 0.1, chamfer=0.012)
    for z in (1.66, 2.64):
        L.block(px - 0.03, px + 0.03, z - 0.03, z + 0.03, D - 0.1, uvD, back=D - 0.006)
    L.block(-HW + 0.06, HW - 0.06, 0.06, 0.55, D - 0.008, uvD, back=D, chamfer=0.006)
    for x in (-HW + 0.16, -0.0, HW - 0.16):
        for z in (0.14, 0.47):
            L.stud(x, z, 0.022, D - 0.008, uvD, 6)
    return L.done()


def heavy(edge):
    L = Leaf(f'door_inside_heavy_{"edgepos" if edge > 0 else "edgeneg"}')
    n = 6
    pw = W / n
    for i in range(n):
        x0 = -HW + i * pw
        L.block(x0 + 0.006, x0 + pw - 0.006, 0, H, -0.04, uvC, chamfer=0.018)
    ledges = ((0.7, 1.12), (3.54, 3.96), (6.4, 6.82))
    rot = lambda z0, z1: (lambda x, z: ((384 + (z - z0) / (z1 - z0) * 48) * PX, 1 - (256 + (x + 1.5) / 3 * 768) * PX))
    for z0, z1 in ledges:
        L.block(-HW + 0.08, HW - 0.08, z0, z1, -0.1, rot(z0, z1), back=-0.04, chamfer=0.02)
    # braces rise from the hinge side to the meeting edge, as a ledged door's do
    lo, hi = -edge * (HW - 0.25), edge * (HW - 0.25)
    bu = lambda u, v: ((384 + u * 40) * PX, 1 - (256 + v * 700) * PX)
    L.strut((lo, 1.12), (hi, 3.54), 0.36, -0.09, -0.04, bu)
    L.strut((lo, 3.96), (hi, 6.4), 0.36, -0.09, -0.04, bu)
    # iron straps over the ledges, bolted through
    for z0, z1 in ledges:
        zc = (z0 + z1) / 2
        L.block(-HW + 0.04, HW - 0.04, zc - 0.07, zc + 0.07, -0.115, uvE, back=-0.1, chamfer=0.008)
        for k in range(7):
            L.stud(-HW + 0.18 + k * (W - 0.36) / 6, zc, 0.03, -0.115, uvE, 6)
    px = edge * (HW - 0.2)
    L.block(px - 0.035, px + 0.035, 1.6, 2.7, -0.2, uvE, back=-0.12, chamfer=0.012)
    for z in (1.66, 2.64):
        L.block(px - 0.05, px + 0.05, z - 0.05, z + 0.05, -0.12, uvE, back=-0.04)
    L.block(-HW + 0.04, HW - 0.04, 0.04, 0.5, -0.05, uvE, back=-0.04)
    return L.done()


bpy.ops.wm.read_factory_settings(use_empty=True)
mat = bpy.data.materials.new('door_inside'); mat.use_nodes = True
nt = mat.node_tree; bsdf = nt.nodes['Principled BSDF']


def tex(key, sock=None, data=False):
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(str(DIR / f'door_inside_{key}.png'))
    if data:
        t.image.colorspace_settings.name = 'Non-Color'
    if sock:
        nt.links.new(t.outputs['Color'], bsdf.inputs[sock])
    return t


tex('color', 'Base Color'); tex('rough', 'Roughness', True); tex('metal', 'Metallic', True)
nm = nt.nodes.new('ShaderNodeNormalMap'); nt.links.new(tex('normal', None, True).outputs['Color'], nm.inputs['Color'])
nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
objs = []
for fn in (glazed, heavy):
    for edge in (1, -1):
        ob = fn(edge)
        ob.data.materials.append(mat)
        objs.append(ob)
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
        bpy.ops.wm.obj_export(filepath=str(DIR / f'{ob.name}.obj'), export_selected_objects=True, forward_axis='Z',
                              up_axis='Y', export_materials=False, export_normals=True, export_uv=True)
print('TRIS', {o.name: sum(p.loop_total - 2 for p in o.data.polygons) for o in objs})

# ---------------------------------------------------------------- review: the four leaves side by side, and the old inside for comparison
sc = bpy.context.scene
for i, ob in enumerate(objs):
    ob.location.x = i * 3.4
for i, ob in enumerate(objs):  # the leaf itself, a green board behind each
    bpy.ops.mesh.primitive_cube_add(size=1, location=(i * 3.4, 0.13, H / 2))
    back = bpy.context.object; back.scale = (W, 0.25, H)
    bm_ = bpy.data.materials.new('green'); bm_.use_nodes = True
    bm_.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.03, .08, .06, 1)
    back.data.materials.append(bm_)
bpy.ops.wm.save_as_mainfile(filepath=str(DIR / 'door-inside.blend'))
if '--no-render' in sys.argv:
    sys.exit(0)
sc.render.engine = 'BLENDER_EEVEE'; sc.eevee.taa_render_samples = 6
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = 1920, 1080, 50
sc.view_settings.view_transform = 'AgX'
world = bpy.data.worlds.new('w'); sc.world = world; world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (.03, .025, .02, 1)
for loc, e, col, size in (((1, -5, 7), 900, (1, .78, .5), 3), ((9, -6, 3), 300, (.7, .8, 1), 6)):
    d = bpy.data.lights.new('l', 'AREA'); d.energy = e; d.color = col; d.size = size
    o = bpy.data.objects.new('l', d); o.location = loc; sc.collection.objects.link(o)
    o.rotation_euler = (Vector((5, 0, 3.5)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam


def shot(name, loc, target, lens):
    cam.location = loc; cam.data.lens = lens
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = str(DIR / name); bpy.ops.render.render(write_still=True); print('OK', name)


shot('review_door_inside.png', (5.1, -15, 4.2), (5.1, 0, 3.75), 45)
shot('review_door_inside_close.png', (1.6, -4.2, 3.4), (0.4, 0, 3.0), 40)
