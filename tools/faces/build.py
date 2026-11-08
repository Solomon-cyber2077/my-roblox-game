"""Blender 5.2: sculpted heads and hands for the Depot hall's people (Builders/FaceKit).

blender -b --python tools/faces/build.py -- <out dir> [--no-render]

Four base heads (male/female, young/old) with their own noses, jaws, brows, cheeks and ears, a
six facial-hair pieces (walrus, handlebar and chevron moustaches; Van Dyke, boxed and full beards,
none with sideburns) and a left and right hand with fingers.
References: 1880s cabinet-card portraits and railway staff photographs (long faces, heavy brows,
weathered skin, side whiskers on older men).

Each mesh carries one 512 texture that is transparent where the skin is plain, so the MeshPart's
own Color (the person's skin, Config/Outfits look.skin) shows through: the texture holds only the
shading in the creases, lips, cheek colour, brows, the eyes and, on the old heads, the lines. That
way 11 people with different skins share these 7 meshes. Sizes in studs; each head fits the kit's
1.3-stud head ball, each hand its 0.62 hand ball. Writes <id>.obj/.mtl/.png, review renders, and
faces.json (each mesh's box centre relative to its anchor, for Config/FaceKit).
"""
import bpy, bmesh, math, sys, json
from pathlib import Path
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree
import numpy as np

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = Path(args[0] if args else 'assets/faces')
OUT.mkdir(parents=True, exist_ok=True)
RENDER = '--no-render' not in args
TEX = 512
SKIN_PREVIEW = (.62, .42, .32)
# how far the chin is brought forward, in studs (man, woman): tuned with --chin-sweep against the
# E-line (nose tip to chin), where the lower lip should sit about 2 mm behind and the upper about 4 mm
CHIN = {False: 0.14, True: 0.20}  # the sweet spot from --chin-sweep (2026-11-07)
# how far the whole lower face (mouth and chin together) is brought forward, so it does not slope
# away under the nose: tuned with --chin-sweep against the profile's convexity angle (about 168 deg)
LOWER = {False: 0.06, True: 0.06}  # the sweet spot from --chin-sweep (2026-11-07)
for _i, _a in enumerate(args):
    if _a == '--chin' and _i + 2 < len(args):
        CHIN = {False: float(args[_i + 1]), True: float(args[_i + 2])}
    if _a == '--lower' and _i + 2 < len(args):
        LOWER = {False: float(args[_i + 1]), True: float(args[_i + 2])}  # only for the review renders: the game tints by the person's skin


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def smooth(t, a, b):
    t = min(max((t - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)


def bump(p, c, r):
    """1 at c, falling to 0 at distance r."""
    d = (p - Vector(c)).length / r
    return max(0.0, 1 - d * d) ** 2


def paint(ob, rule):
    """Per-vertex colour and coverage: rule(p) -> (r, g, b, a); a = 0 lets the skin show through."""
    me = ob.data
    attr = me.color_attributes.new('paint', 'FLOAT_COLOR', 'POINT')
    for v in me.vertices:
        attr.data[v.index].color = rule(v.co)
    return attr


LINEN = (.78, .74, .66)


def sphere(r, at, scale=(1, 1, 1), seg=(16, 10), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg[0], ring_count=seg[1], radius=r, location=at, rotation=rot)
    ob = bpy.context.object; ob.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def tint(ob, col, a=1.0):
    """A whole piece one painted colour (a = 1 opaque; a = 0 leaves it to the skin)."""
    attr = ob.data.color_attributes.new('paint', 'FLOAT_COLOR', 'POINT')
    for v in ob.data.vertices:
        attr.data[v.index].color = (*col, a)


def joined(parts, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join(); ob = bpy.context.object; ob.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    return ob


def head(female, old):
    """A head on the kit head ball's centre, face toward -Y, up +Z, in studs (about 1.2 tall)."""
    skull = shaped_skull(female, old)
    return dress_head(skull, female, old)


def shaped_skull(female, old):
    """The bare skull and face of a head (no eyes, ears, neck): also the form the beards are grown on."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=34, ring_count=24, radius=1)
    skull = bpy.context.object
    jaw_w = .68 if female else .96         # man: a wide, square jaw; woman: narrow, to a point
    brow = .02 if female else .075          # man: a heavy brow ridge
    full = (.05 if female else .02) if old else (.025 if female else 0)  # cheek fullness
    for v in skull.data.vertices:
        p = v.co.copy(); x, y, z = p
        q = Vector((x * (.43 if female else .47), y * (.5 if female else .52), z * (.57 if female else .6)))
        if z > .55:
            q.z *= .97
        if z < -.05:  # the jaw: narrowing below the cheekbones, a square (man) or pointed (woman) chin
            t = smooth(-z, .05, 1)
            q.x *= 1 - (1 - jaw_w) * t * (1 if abs(y) > .3 else .6)
            q.y *= 1 - .16 * t * (1 - max(-y, 0))
        q.y -= (.05 if female else .08) * bump(p, (0, -1, -.78), .35 if female else .5)  # chin
        q.y -= CHIN[female] * bump(p, (0, -.8, -.88), .3 if female else .36)  # the chin alone brought forward to the E-line
        q.y -= LOWER[female] * smooth(-z, .3, .62) * max(-y, 0) ** 2 * (1 - smooth(abs(x), .35, .7))  # mouth and chin together
        if not female:
            for s in (-1, 1):  # the corners of a square jaw
                q.x += s * .05 * bump(p, (s * .72, -.35, -.68), .32)
                q.z -= .03 * bump(p, (s * .72, -.35, -.68), .32)
        for s in (-1, 1):
            q.x += s * .04 * bump(p, (s * .8, -.55, .02), .4)  # cheekbones
            q.y -= full * bump(p, (s * .55, -.8, -.25), .45)  # fuller cheeks
            q.y += .04 * bump(p, (s * .36, -.93, .1), .25)  # eye sockets
            q.y -= brow * bump(p, (s * .33, -.93, .3), .32)  # brow ridge
            if old:
                q.y += .025 * bump(p, (s * .55, -.8, -.2), .2) * (0 if female else 1)  # hollow under the cheekbone
                q.z -= .075 * bump(p, (s * .55, -.65, -.62), .32)  # jowls
                q.x += s * .04 * bump(p, (s * .55, -.65, -.62), .32)
                q.y += .035 * bump(p, (s * .27, -.96, -.45), .11)  # nasolabial fold
                q.y -= .02 * bump(p, (s * .34, -.93, -.06), .11)  # bags under the eyes
                q.z -= .02 * bump(p, (s * .2, -.98, -.6), .08)  # the mouth's corners turned down
                q.y += .02 * bump(p, (s * .3, -.9, .32), .16)  # the temples sunken
        # the nose: a narrow bridge from between the eyes, a rounded tip a little up, nostril wings
        nose = (.085 if female else .11) * (1.08 if old else 1)
        if abs(x) < .16 and -.42 < z < .12 and y < 0:
            t = smooth(z, -.42, .12)
            ridge = (1 - abs(x) / .16) ** 1.5
            q.y -= nose * ridge * (.45 + .55 * (1 - t)) * smooth(-z + .12, 0, .18) * smooth(z + .42, 0, .08)
        q.y -= nose * .45 * bump(p, (0, -1, -.33), .14)  # tip
        for s in (-1, 1):
            q.y -= nose * .35 * bump(p, (s * .11, -.99, -.37), .09)  # wings
            q.y += .02 * bump(p, (s * .06, -1, -.43), .05)  # nostrils
        # the mouth: lips and the line between them
        q.y -= (.03 if female else .02) * bump(p, (0, -1, -.56), .17)
        q.y += .012 * bump(p, (0, -1, -.59), .06)
        if old:  # forehead creases
            q.y += .006 * max(math.sin(z * 55), 0) * smooth(z, .35, .55) * max(-y, 0)
        v.co = q
    return skull


def dress_head(skull, female, old):
    parts = [skull]
    paint_skull = lambda p: (.0, .0, .0, .0)
    # ears, set a little behind the middle, sized to the head
    for s in (-1, 1):
        ear = sphere(1, (s * (.41 if female else .45), .04, .0), (.035 if female else .04, (.09 if female else .1) * (1.12 if old else 1),
                     (.13 if female else .15) * (1.15 if old else 1)), rot=(0, 0, s * -.2), seg=(12, 8))
        tint(ear, (0, 0, 0), 0); parts.append(ear)
    # the eyes: a white ball in the socket, a dark iris and pupil, a lid over the top and a rim under
    for s in (-1, 1):
        ex, ey, ez = s * .16, -.468, .05
        white = sphere(.06, (ex, ey, ez), (1.15, .6, .75), seg=(12, 8)); tint(white, (.82, .78, .72)); parts.append(white)
        iris = sphere(.028, (ex, ey - .033, ez - .004), (1, .35, 1), seg=(12, 8)); tint(iris, (.12, .08, .05)); parts.append(iris)
        pupil = sphere(.012, (ex, ey - .044, ez - .004), (1, .3, 1), seg=(8, 6)); tint(pupil, (.01, .01, .01)); parts.append(pupil)
        lid = sphere(.066, (ex, ey + .004, ez + .012), (1.18, .62, .55), rot=(.35, 0, 0), seg=(12, 8))
        for v in lid.data.vertices:  # keep the upper half: a lid
            if v.co.z < ez + .006:
                v.co.z = ez + .006 + (v.co.z - ez - .006) * .1
        tint(lid, (0, 0, 0), 0); parts.append(lid)
        rim = sphere(.064, (ex, ey + .01, ez - .03), (1.15, .5, .3), seg=(10, 6)); tint(rim, (.05, .02, .01), .15); parts.append(rim)
        # the brow: hair over the ridge, arched
        for k in range(5):
            u = (k - 2) / 2
            parts.append(sphere(.028, (ex + s * u * .07, -.528 + abs(u) * .025, ez + .115 + .018 * (1 - u * u) - (u * s) * .008),
                                (1.4, .45, .5), seg=(6, 4)))
            tint(parts[-1], (.07, .05, .04), .9 if not female else .8)
    # the neck, and a linen collar round its foot (it replaces the kit's block collar)
    # (the head sits 0.1 above the kit's head centre, Config/FaceKit.Seat, so the kit's collar at -0.67 is -0.77 here)
    bpy.ops.mesh.primitive_cylinder_add(radius=.2 if female else .24, depth=.5, vertices=20, location=(0, .04, -.6))
    neck = bpy.context.object; tint(neck, (0, 0, 0), 0); parts.append(neck)
    bpy.ops.mesh.primitive_cylinder_add(radius=1, depth=.2, vertices=20, location=(0, .02, -.77))
    collar = bpy.context.object; collar.scale = (.38 if not female else .34, .34, 1)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for v in collar.data.vertices:  # a turned-down band, a little wider at the foot
        if v.co.z < -.8:
            v.co.x *= 1.08; v.co.y *= 1.06
    tint(collar, LINEN); parts.append(collar)
    tint(skull, (0, 0, 0), 0)
    ob = joined(parts, 'head')
    # shade the creases on the skin (a clear texture elsewhere): under the brows, beside the nose,
    # the lips' colour and the cheeks' warmth, lines on the old
    attr = ob.data.color_attributes['paint']
    for v in ob.data.vertices:
        c = list(attr.data[v.index].color)
        if c[3] > .5:
            continue  # eyes, brows, collar keep their own colour
        x, y, z = v.co; f = Vector((x, 0, z)); a = 0.0; col = [.0, .0, .0]
        def over(cc, k):
            nonlocal a, col
            if k <= 0:
                return
            tot = a + k - a * k
            col = [(col[i] * a * (1 - k) + cc[i] * k) / tot for i in range(3)]; a = tot
        if y < -.35:
            over((.38, .1, .09), min(bump(Vector((x * .75, 0, z)), (0, 0, -.335), .06) * 2.2, .7))  # lips
            for s in (-1, 1):
                over((.55, .2, .16), bump(f, (s * .25, 0, -.12), .14) * (.22 if female else .12))
                over((.06, .03, .02), bump(f, (s * .09, 0, -.24), .06) * .3)
            if old:
                for s in (-1, 1):
                    over((.1, .05, .04), bump(f, (s * .25, 0, .05), .07) * .25 * (.5 + .5 * math.sin(z * 120)))
        if not female and z < -.15 and y < -.1 and abs(x) < .4:
            over((.08, .07, .06), .1 * smooth(-z, .15, .45))  # shaved
        attr.data[v.index].color = (*col, a)
    return ob


HAIR_PREVIEW = (.16, .1, .07)  # only for the review renders: the game tints whiskers by the person's hair


def strands(ob, depth=.008, lines=160):
    """Clumped hair: a little noise on the surface and combed light/dark lines in the coverage."""
    for v in ob.data.vertices:
        v.co += v.normal * noise.noise(v.co * 14) * depth
    paint(ob, lambda p: (.0, .0, .0, .25 + .2 * max(math.sin(p.x * lines + p.z * 40), 0)))
    return ob


_SKIN = {}


def face_y(x, z):
    """How far forward (-Y) the man's face is at (x, z): the moustaches sit on the skin, not at a guess."""
    if 'tree' not in _SKIN:
        sk = shaped_skull(False, False)
        dg = bpy.context.evaluated_depsgraph_get()
        _SKIN['tree'] = BVHTree.FromObject(sk, dg)
        bpy.data.objects.remove(sk, do_unlink=True)
    hit = _SKIN['tree'].ray_cast(Vector((x, -2, z)), Vector((0, 1, 0)))
    return hit[0].y if hit[0] else -.5


def on_lip(x, z, depth):
    """A point that puts a piece `depth` thick against the upper lip at (x, z)."""
    return (x, face_y(x, z) - depth * .45, z)


def moustache(kind):
    """Moustache shapes on the face's own surface (the lip line is at z -0.34), each with its own
    outline: the walrus droops past the mouth, the handlebar spreads wide into curls, the chevron is
    a solid trimmed block over the whole upper lip."""
    parts = []
    if kind == 'walrus':
        for s in (-1, 1):
            parts.append(sphere(1, on_lip(s * .09, -.31, .06), (.15, .06, .075), rot=(0, s * -.45, 0), seg=(14, 10)))
            for k in range(5):  # the ends hang past the corners of the mouth toward the chin
                t = k / 4
                x, z = s * (.17 + .02 * t), -.35 - .12 * t
                parts.append(sphere(.05 - .022 * t, on_lip(x, z, .05 - .02 * t), (1, .8, 1.2), seg=(10, 8)))
    elif kind == 'handlebar':
        for s in (-1, 1):
            for k in range(12):  # a slim bar out to the cheeks
                x = s * (.03 + .022 * k)
                r = .03 - .0011 * k
                parts.append(sphere(r, on_lip(x, -.295 + .0024 * k, r * 2), (1.3, .9, 1), seg=(8, 6)))
            for k in range(16):  # the curl: up, over and back in, a full loop
                a = math.radians(-90 + k * 21)
                r = .017 - .0004 * k
                x = s * (.29 + .05 * math.cos(a)); z = -.25 + .05 * math.sin(a)
                parts.append(sphere(r, on_lip(x, z, r * 2), seg=(6, 4)))
    else:  # chevron: from under the nose to the lip line, as wide as the mouth, cut square
        parts.append(sphere(1, on_lip(0, -.29, .04), (.16, .035, .07), seg=(16, 10)))
        for v in parts[-1].data.vertices:  # trimmed flat along the bottom, sloping sides
            if v.co.z < -.33:
                v.co.z = -.33 + (v.co.z + .33) * .2
    return parts


def grow(female, weight, thick, shape=None):
    """Hair grown on the skull: every point lifted off the skin by `thick` times its weight (0..1),
    so the hair thins to nothing at its edges instead of ending in a hard rim. `shape(v, w)` may
    move a point further (length, a point, a parting)."""
    sk = shaped_skull(female, False)
    bm = bmesh.new(); bm.from_mesh(sk.data); bm.normal_update()
    w = {v: weight(v.co) for v in bm.verts}
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if w[v] <= .002 and all(w[e.other_vert(v)] <= .002 for e in v.link_edges)],
                     context='VERTS')
    lift = {v: v.normal.copy() * (-.01 + (thick + .016) * w[v]) for v in bm.verts}  # the edge starts under the skin, so the hairline falls smoothly between vertices
    for v in bm.verts:
        v.co += lift[v]
        if shape:
            shape(v.co, w[v])
    bm.to_mesh(sk.data); bm.free()
    return sk


def jaw_w(p):  # cheeks below the cheekbones, jaw and chin, fading toward the ears and the lips
    x, y, z = p
    down = smooth(-z, .25, .36)
    front = 1 - smooth(y, -.06, .1)  # stops short of the ears: no sideburns
    lips = bump(Vector((x * .8, y, z)), (0, -.5, -.335), .13) * smooth(-y, .3, .45)
    return max(0.0, down * front - lips * 1.6)


def curtain_w(p):  # a fringe along the jaw line and under the chin only: cheeks, lip and ears bare
    x, y, z = p
    band = smooth(-z, .4, .46)
    front = 1 - smooth(y, -.06, .1)
    return band * front


def chin_w(p):  # the Van Dyke's tuft: the chin only
    x, y, z = p
    return smooth(-z, .4, .47) * max(0.0, 1 - abs(x) / .15) * smooth(-y, .1, .3)


def beard(weight, drop=0.0, point=0.0, thick=.04):
    def shape(co, w):
        x = co.x
        centre = max(0.0, 1 - abs(x) / .34)
        co.z -= drop * w * smooth(-co.z, .32, .58) * centre ** .7
        co.z -= point * w * smooth(-co.z, .4, .58) * max(0.0, 1 - abs(x) / .14) ** 1.5
    return grow(False, weight, thick, shape)


def whiskers(style):
    """Facial hair in the head's space: a moustache alone, or a moustache with its beard."""
    parts = []
    if style == 'walrus':
        parts = moustache('walrus')
    elif style == 'handlebar':
        parts = moustache('handlebar')
    elif style == 'chevron':
        parts = moustache('chevron')
    elif style == 'vandyke':  # a pointed chin beard under a neat moustache
        parts = moustache('chevron') + [beard(chin_w, point=.12, thick=.05)]
    elif style == 'curtain':  # a chin curtain: the jaw line and chin, no moustache
        parts = [beard(curtain_w, drop=.06, thick=.05)]
    elif style == 'full':  # long, to the second collar stud
        parts = moustache('walrus') + [beard(jaw_w, drop=.36, point=.1, thick=.06)]
    ob = joined(parts, f'whiskers_{style}')
    return strands(ob, depth=.01 if style in ('full', 'curtain') else .008)


STYLES = ('walrus', 'handlebar', 'chevron', 'vandyke', 'curtain', 'full')


def scalp_w(female):
    """Where hair grows, fading over a short band at the hairline: above the brows (higher on a man's
    forehead), over the crown, down to the nape; it stops above the ears, so there are no sideburns."""
    def weight(p):
        x, y, z = p
        line = (.33 if not female else .3) - .52 * smooth(y, -.3, .42)
        if abs(x) > .27 and -.2 < y < .16:
            line = max(line, -.1 if female else .26)  # a woman's hair is drawn down over the ears; a man's is cut above them
        return smooth(z - line, 0, .07)
    return weight


def hair(female):
    """A cap of combed hair grown on the skull: a man's short cut parted on his left, or a woman's hair
    drawn back from a middle parting into a bun."""
    part_x = 0 if female else -.13  # the parting

    def shape(co, w):
        x, y, z = co
        if y < .25 and z > .2:  # a groove along the parting, front to crown
            co -= co.normalized() * .016 * w * max(0.0, 1 - abs(x - part_x) / .03)
        side = smooth(abs(x), .26, .4) * (1 - smooth(z, .32, .5))
        if female:  # bandeaux: the hair swept full over the sides
            co += Vector((x, 0, 0)).normalized() * .065 * w * side if abs(x) > 1e-4 else Vector()
        else:  # short back and sides: close over the ears and at the nape
            co -= co.normalized() * .045 * w * max(side, smooth(y, .3, .5) * (1 - smooth(z, .1, .3)))

    sk = grow(female, scalp_w(female), .065 if female else .05, shape)
    parts = [sk]
    if female:  # a curled fringe across the forehead, as worn in the eighties
        for k in range(9):
            u = (k - 4) / 4
            x = u * .2
            z = .3 - .03 * u * u
            y = face_y(x, z) if abs(x) < .3 else -.4
            parts.append(sphere(.04 - .006 * abs(u), (x, y - .02, z), (1.1, .8, .9), seg=(10, 8)))
    if female:  # the bun, high at the back and clear of the cap, with a twist in it
        bun = sphere(.15, (0, .56, .24), (1.1, .85, .95), seg=(16, 10))
        for v in bun.data.vertices:
            v.co += v.normal * .012 * math.sin(math.atan2(v.co.z - .24, v.co.x) * 6 + v.co.y * 20)
        parts.append(bun)
    ob = joined(parts, 'hair_bun' if female else 'hair_short')
    for v in ob.data.vertices:
        v.co += v.normal * noise.noise(v.co * 18) * .006
    paint(ob, lambda p: (.0, .0, .0, .22 + .22 * max(math.sin(p.x * 140 + p.y * 18), 0)))
    return ob


def hand(side):
    """A relaxed hand hanging from the cuff, wrist at z = 0: a tapered wrist, the palm, a thumb and four
    fingers with knuckles, curling toward the palm. Modelled palm toward +X; the half turn at export
    puts it toward the body."""
    parts = []
    bpy.ops.mesh.primitive_cone_add(radius1=.05, radius2=.058, depth=.09, vertices=14, location=(0, 0, -.045))
    wrist = bpy.context.object  # narrowing from the cuff into the heel of the hand
    for v in wrist.data.vertices:
        v.co.y *= 1.25
    parts.append(wrist)
    palm = sphere(1, (0, 0, -.15), (.055, .095, .1), seg=(12, 8)); parts.append(palm)
    for i in range(4):  # fingers: three tapering joints each, a knuckle at each bend, curling toward +X
        y = -.066 + i * .044
        lengths = [(.075, .05, .04), (.085, .055, .042), (.08, .052, .04), (.062, .042, .034)][i]
        at = Vector((0, y, -.235)); bend = math.radians(8)
        r = .02 - i * .0012
        for k, length in enumerate(lengths):
            parts.append(sphere(r * 1.08, tuple(at), seg=(6, 4)))  # the knuckle
            bend += math.radians(22 + k * 10)
            d = Vector((math.sin(bend), 0, -math.cos(bend)))
            c = at + d * length / 2
            bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r * .85, depth=length, vertices=8, location=tuple(c))
            seg = bpy.context.object; seg.rotation_euler = (0, -bend, 0); parts.append(seg)
            at = at + d * length; r *= .87
        parts.append(sphere(r, tuple(at), seg=(6, 4)))  # the fingertip
    # the thumb, from the heel of the palm toward the fingers, on the front
    at = Vector((.03, -.08, -.1))
    for k, length in enumerate((.06, .045)):
        d = Vector((.45, -.25, -.85)).normalized()
        c = at + d * length / 2
        bpy.ops.mesh.primitive_cone_add(radius1=.024, radius2=.02, depth=length, vertices=8, location=tuple(c))
        th = bpy.context.object; th.rotation_euler = d.to_track_quat('Z', 'Y').to_euler(); parts.append(th)
        at = at + d * length
        parts.append(sphere(.02, tuple(at), seg=(6, 4)))
    for o in parts:
        tint(o, (0, 0, 0), 0)
    ob = joined(parts, 'hand_r' if side > 0 else 'hand_l')
    if side < 0:  # the left hand mirrors the right across the hand's own middle
        for v in ob.data.vertices:
            v.co.x = -v.co.x
        ob.data.flip_normals()
    attr = ob.data.color_attributes['paint']
    for v in ob.data.vertices:  # knuckle creases a shade darker, the nails paler
        x, y, z = v.co
        crease = -.25 < z < -.22
        nail = z < -.36 and abs(x) > .02
        attr.data[v.index].color = (.06, .03, .02, .25) if crease else ((.8, .68, .6, .35) if nail else (0, 0, 0, 0))
    return ob


def bake(ob):
    """Unwrap, bake the painted colour and its coverage into one RGBA image, export the OBJ."""
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    m = bpy.data.materials.new(ob.name); m.use_nodes = True; nt = m.node_tree
    attr = nt.nodes.new('ShaderNodeVertexColor'); attr.layer_name = 'paint'
    emit = nt.nodes.new('ShaderNodeEmission'); out = nt.nodes['Material Output']
    ob.data.materials.clear(); ob.data.materials.append(m)
    sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.samples = 4; sc.render.bake.margin = 6
    planes = []
    for socket in ('Color', 'Alpha'):
        im = bpy.data.images.new(f'{ob.name}_{socket}', TEX, TEX, float_buffer=True)
        node = nt.nodes.new('ShaderNodeTexImage'); node.image = im; nt.nodes.active = node
        nt.links.new(attr.outputs[socket], emit.inputs['Color']); nt.links.new(emit.outputs[0], out.inputs['Surface'])
        bpy.ops.object.bake(type='EMIT')
        planes.append(np.array(im.pixels[:]).reshape(TEX, TEX, 4))
    rgba = planes[0].copy(); rgba[..., 3] = planes[1][..., 0]
    tex = bpy.data.images.new(f'{ob.name}_tex', TEX, TEX, alpha=True)
    tex.pixels[:] = np.clip(rgba, 0, 1).ravel()
    tex.filepath_raw = str(OUT / f'{ob.name}.png'); tex.file_format = 'PNG'; tex.save()
    # the exported material carries the baked image
    for n in list(nt.nodes):
        if n.type not in ('OUTPUT_MATERIAL',):
            nt.nodes.remove(n)
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled'); t = nt.nodes.new('ShaderNodeTexImage'); t.image = tex
    nt.links.new(t.outputs['Color'], bsdf.inputs['Base Color']); nt.links.new(bsdf.outputs[0], out.inputs['Surface'])
    for v in ob.data.vertices:  # half round, so the face (-Y) leaves the OBJ facing -Z like the kit's
        v.co.x, v.co.y = -v.co.x, -v.co.y
    lo = [v.co for v in ob.data.vertices]
    centre = [(min(v[i] for v in lo) + max(v[i] for v in lo)) / 2 for i in range(3)]
    size = [max(v[i] for v in lo) - min(v[i] for v in lo) for i in range(3)]
    bpy.ops.wm.obj_export(filepath=str(OUT / f'{ob.name}.obj'), export_selected_objects=True, forward_axis='NEGATIVE_Z',
                          up_axis='Y', export_materials=True, path_mode='RELATIVE', export_normals=True, export_uv=True)
    # Roblox axes (x, z, -y) for the centre and size: right, up, back
    return {'faces': len(ob.data.polygons), 'centre': [round(centre[0], 3), round(centre[2], 3), round(-centre[1], 3)],
            'size': [round(size[0], 3), round(size[2], 3), round(size[1], 3)], 'tex': tex}


def review(obs_texs, path, view=Vector((-.35, 1, .16))):
    """The skin-tinted look the game will give it: skin colour under the texture's coverage."""
    clear_lights = [o for o in bpy.context.scene.objects if o.type in ('CAMERA', 'LIGHT')]
    for o in clear_lights:
        bpy.data.objects.remove(o, do_unlink=True)
    sc = bpy.context.scene
    for ob, tex in obs_texs:
        m = bpy.data.materials.new(ob.name + '_review'); m.use_nodes = True; nt = m.node_tree
        bsdf = nt.nodes['Principled BSDF']; bsdf.inputs['Roughness'].default_value = .7
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = tex
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.inputs[6].default_value = (*SKIN_PREVIEW, 1)
        nt.links.new(t.outputs['Alpha'], mix.inputs['Factor']); nt.links.new(t.outputs['Color'], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs['Base Color'])
        ob.data.materials.clear(); ob.data.materials.append(m)
    lo = [o.matrix_world @ Vector(c) for o, _ in obs_texs for c in o.bound_box]
    centre = sum(lo, Vector()) / len(lo); span = max((a - b).length for a in lo for b in lo)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
    cam.location = centre + view.normalized() * span * 1.7; cam.data.lens = 60  # the face is at +Y after the turn
    cam.rotation_euler = (centre - cam.location).to_track_quat('-Z', 'Y').to_euler(); sc.camera = cam
    for loc, e, col in [((-2, 3, 3), 300, (1, .8, .58)), ((3, 1, 1), 90, (.7, .78, 1))]:
        lamp = bpy.data.objects.new('l', bpy.data.lights.new('l', 'AREA')); sc.collection.objects.link(lamp)
        lamp.data.energy = e * span; lamp.data.size = span; lamp.data.color = col
        lamp.location = centre + Vector(loc) * span * .5
        lamp.rotation_euler = (centre - lamp.location).to_track_quat('-Z', 'Y').to_euler()
    sc.world.use_nodes = True; sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.03, .03, .035, 1)
    sc.render.resolution_x = sc.render.resolution_y = 400; sc.cycles.samples = 48; sc.cycles.use_denoising = True
    sc.view_settings.view_transform = 'AgX'; sc.render.filepath = str(path); bpy.ops.render.render(write_still=True)




def outline(obs, path, px=256, side=False):
    """A flat white silhouette from straight in front, through one fixed orthographic camera, so two
    pieces can be compared pixel for pixel (how alike they read at a glance)."""
    sc = bpy.context.scene
    for o in [o for o in sc.objects if o.type in ('CAMERA', 'LIGHT')]:
        bpy.data.objects.remove(o, do_unlink=True)
    m = bpy.data.materials.new('flat'); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(n)
    e = nt.nodes.new('ShaderNodeEmission'); e.inputs['Color'].default_value = (1, 1, 1, 1)
    nt.links.new(e.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
    for ob in obs:
        ob.data.materials.clear(); ob.data.materials.append(m)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 1.6
    if side:  # from the person's left, to see the back of the head too
        cam.location = (-3, 0, -.15); cam.rotation_euler = (math.radians(90), 0, math.radians(-90))
    else:
        cam.location = (0, -3, -.15); cam.rotation_euler = (math.radians(90), 0, 0)
    sc.camera = cam
    sc.world.use_nodes = True; sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0, 0, 0, 1)
    sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [i.identifier for i in sc.render.bl_rna.properties['engine'].enum_items] else 'CYCLES'
    sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x = sc.render.resolution_y = px; sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def profile(female):
    """Down the middle of the face: (nose tip, upper lip, lower lip, chin) as (y, z), and each lip's
    distance behind the E-line in studs (positive = behind the line, as it should be)."""
    sk = shaped_skull(female, False)
    tree = BVHTree.FromObject(sk, bpy.context.evaluated_depsgraph_get())
    bpy.data.objects.remove(sk, do_unlink=True)
    pts = []
    for k in range(240):
        z = .05 - k * .003
        hit = tree.ray_cast(Vector((0, -2, z)), Vector((0, 1, 0)))
        if hit[0]:
            pts.append((hit[0].y, z))
    def front(z0, z1):
        return min((p for p in pts if z1 <= p[1] <= z0), key=lambda p: p[0])
    nose = front(0, -.3); upper = front(-.3, -.345); lower = front(-.345, -.4); chin = front(-.42, -.62)
    def behind(p):  # how far the lip sits behind the nose-chin line at its own height (+ = behind)
        (ny, nz), (cy, cz) = nose, chin
        return p[0] - (ny + (p[1] - nz) * (cy - ny) / (cz - nz))
    return nose, upper, lower, chin, behind(upper), behind(lower)


def convexity(female):
    """The profile's convexity: the angle at the base of the nose between the forehead and the chin
    (about 168 degrees in an adult; smaller means the lower face falls away)."""
    sk = shaped_skull(female, False)
    tree = BVHTree.FromObject(sk, bpy.context.evaluated_depsgraph_get())
    bpy.data.objects.remove(sk, do_unlink=True)
    pts = []
    for k in range(240):
        z = .4 - k * .004
        hit = tree.ray_cast(Vector((0, -2, z)), Vector((0, 1, 0)))
        if hit[0]:
            pts.append((hit[0].y, z))
    fwd = lambda z0, z1: min((p for p in pts if z1 <= p[1] <= z0), key=lambda p: p[0])
    back = lambda z0, z1: max((p for p in pts if z1 <= p[1] <= z0), key=lambda p: p[0])
    glabella = fwd(.3, .12); nose = fwd(0, -.3); chin = fwd(-.42, -.62)
    sub = back(nose[1], -.31)  # the deepest point between the nose tip and the upper lip
    v1 = (glabella[0] - sub[0], glabella[1] - sub[1]); v2 = (chin[0] - sub[0], chin[1] - sub[1])
    c = (v1[0] * v2[0] + v1[1] * v2[1]) / (math.hypot(*v1) * math.hypot(*v2))
    return math.degrees(math.acos(max(-1, min(1, c))))


if '--chin-sweep' in args:  # score chin and lower-face settings against the profile norms, then stop
    STUD_MM = 230 / 1.2  # a head about 23 cm tall is 1.2 studs here
    for female in (False, True):
        rows = []
        for c in [i * .02 for i in range(0, 17)]:
            for lo in [i * .02 for i in range(0, 8)]:
                CHIN[female] = c; LOWER[female] = lo
                clear()
                nose, upper, lower, chin, du, dl = profile(female)
                gap = (chin[0] - lower[0]) * STUD_MM
                ang = convexity(female)
                target_gap = 4 if female else 3
                cost = ((ang - 168) / 4) ** 2 + ((dl * STUD_MM - 2) / 2) ** 2 + ((du * STUD_MM - 4) / 2) ** 2 + ((gap - target_gap) / 3) ** 2
                rows.append((cost, c, lo, ang, du * STUD_MM, dl * STUD_MM, gap))
        rows.sort()
        CHIN[female] = 0; LOWER[female] = 0; clear()
        n, u, l, ch, du0, dl0 = profile(female)
        print(f'SWEEP {"woman" if female else "man"} now: convexity {convexity(female):.1f} deg  lips {du0 * STUD_MM:+.1f}/{dl0 * STUD_MM:+.1f} mm  chin {(ch[0] - l[0]) * STUD_MM:+.1f} mm behind lower lip')
        for r in rows[:5]:
            print(f'SWEEP {"woman" if female else "man"} chin {r[1]:.2f} lower {r[2]:.2f}: convexity {r[3]:.1f} deg  lips {r[4]:+.1f}/{r[5]:+.1f} mm  chin {r[6]:+.1f} mm behind lower lip  (score {r[0]:.2f})')
    sys.exit(0)

if '--glb' in args:  # pack each exported OBJ and its texture into one GLB for upload, then stop
    for obj in sorted(OUT.glob('*.obj')):
        clear()
        bpy.ops.wm.obj_import(filepath=str(obj), forward_axis='NEGATIVE_Z', up_axis='Y')
        ob = bpy.context.selected_objects[0]; ob.name = obj.stem
        img = bpy.data.images.load(str(OUT / f'{obj.stem}.png'))
        m = bpy.data.materials.new(obj.stem); m.use_nodes = True; nt = m.node_tree
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = img
        nt.links.new(t.outputs['Color'], nt.nodes['Principled BSDF'].inputs['Base Color'])
        nt.links.new(t.outputs['Alpha'], nt.nodes['Principled BSDF'].inputs['Alpha'])
        ob.data.materials.clear(); ob.data.materials.append(m)
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(OUT / f'{obj.stem}.glb'), use_selection=True, export_format='GLB')
        print('GLB', obj.stem, len(ob.data.polygons))
    sys.exit(0)

if '--masks' in args:  # silhouettes only: every facial-hair style and both cuts of hair, then stop
    for st in STYLES:
        clear(); outline([whiskers(st)], OUT / f'mask_whiskers_{st}.png')
    for female in (False, True):
        clear(); outline([hair(female)], OUT / f'mask_hair_{"bun" if female else "short"}.png')
        clear(); outline([hair(female)], OUT / f'mask_side_hair_{"bun" if female else "short"}.png', side=True)
    sys.exit(0)

report = {}
builds = [('head_m_young', lambda: head(False, False)), ('head_m_old', lambda: head(False, True)),
          ('head_f_young', lambda: head(True, False)), ('head_f_old', lambda: head(True, True)),
          *[(f'whiskers_{st}', (lambda st=st: whiskers(st))) for st in STYLES],
          ('hair_short', lambda: hair(False)), ('hair_bun', lambda: hair(True)),
          ('hand_r', lambda: hand(1)), ('hand_l', lambda: hand(-1))]
if '--profiles' in args:  # views only: no export
    builds = []
for name, build in builds:
    clear()
    ob = build(); ob.name = name
    info = bake(ob)
    tex = info.pop('tex')
    report[name] = info
    if RENDER and name.startswith('head'):  # front, three-quarter and side
        for k, ang in enumerate((0, 40, 90)):
            a = math.radians(ang)
            review([(ob, tex)], OUT / f'review_{name}_{k}.png', Vector((-math.sin(a), math.cos(a), .1)))
    elif RENDER and name != 'hand_l' and not name.startswith(('whiskers', 'hair')):
        review([(ob, tex)], OUT / f'review_{name}.png')


def showcase(objs, path, view):
    """Skin under the head's painted coverage and hair colour under the whiskers', before baking."""
    for ob, base in objs:
        m = bpy.data.materials.new(ob.name + '_show'); m.use_nodes = True; nt = m.node_tree
        bsdf = nt.nodes['Principled BSDF']; bsdf.inputs['Roughness'].default_value = .75
        attr = nt.nodes.new('ShaderNodeVertexColor'); attr.layer_name = 'paint'
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.inputs[6].default_value = (*base, 1)
        nt.links.new(attr.outputs['Alpha'], mix.inputs['Factor']); nt.links.new(attr.outputs['Color'], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs['Base Color'])
        ob.data.materials.clear(); ob.data.materials.append(m)
        for v in ob.data.vertices:  # the same half turn the export gives, so the review framing applies
            v.co.x, v.co.y = -v.co.x, -v.co.y
    review_lit([o for o, _ in objs], path, view)


def review_lit(obs, path, view):
    sc = bpy.context.scene
    for o in [o for o in sc.objects if o.type in ('CAMERA', 'LIGHT')]:
        bpy.data.objects.remove(o, do_unlink=True)
    lo = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    centre = sum(lo, Vector()) / len(lo); span = max((a - b).length for a in lo for b in lo)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
    cam.location = centre + view.normalized() * span * 1.7; cam.data.lens = 60
    cam.rotation_euler = (centre - cam.location).to_track_quat('-Z', 'Y').to_euler(); sc.camera = cam
    for loc, e, col in [((-2, 3, 3), 300, (1, .8, .58)), ((3, 1, 1), 90, (.7, .78, 1))]:
        lamp = bpy.data.objects.new('l', bpy.data.lights.new('l', 'AREA')); sc.collection.objects.link(lamp)
        lamp.data.energy = e * span; lamp.data.size = span; lamp.data.color = col
        lamp.location = centre + Vector(loc) * span * .5
        lamp.rotation_euler = (centre - lamp.location).to_track_quat('-Z', 'Y').to_euler()
    sc.world.use_nodes = True; sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.03, .03, .035, 1)
    sc.render.engine = 'CYCLES'; sc.render.resolution_x = sc.render.resolution_y = 400; sc.cycles.samples = 48
    sc.cycles.use_denoising = True; sc.view_settings.view_transform = 'AgX'
    sc.render.filepath = str(path); bpy.ops.render.render(write_still=True)


if '--profiles' in args:  # side and three-quarter views of the man's and woman's heads, then stop
    tag = args[args.index('--profiles') + 1]
    for female in (False, True):
        for k, ang in enumerate([float(x) for x in args[args.index('--profiles') + 2].split(',')]):
            clear()
            a = math.radians(ang)
            showcase([(head(female, False), SKIN_PREVIEW)], OUT / f'profile_{"woman" if female else "man"}_{k}_{tag}.png',
                     Vector((-math.sin(a), math.cos(a), .1)))
        clear(); outline([shaped_skull(female, False)], OUT / f'outline_{"woman" if female else "man"}_{tag}.png', px=512, side=True)
    sys.exit(0)

if RENDER:
    for st in STYLES:
        for k, ang in enumerate((0, 40)):
            clear()
            h = head(False, st == 'full'); w = whiskers(st); c = hair(False)
            a = math.radians(ang)
            showcase([(h, SKIN_PREVIEW), (w, HAIR_PREVIEW), (c, HAIR_PREVIEW)], OUT / f'show_{st}_{k}.png',
                     Vector((-math.sin(a), math.cos(a), .1)))
    for k, ang in enumerate((0, 40, 140)):
        clear()
        h = head(True, False); c = hair(True)
        a = math.radians(ang)
        showcase([(h, SKIN_PREVIEW), (c, HAIR_PREVIEW)], OUT / f'show_woman_{k}.png', Vector((-math.sin(a), math.cos(a), .1)))
(OUT / 'faces.json').write_text(json.dumps(report, indent=1))
print('FACES', json.dumps(report))
