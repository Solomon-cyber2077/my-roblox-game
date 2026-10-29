# Brass fare token after old transit tokens: flat stamped disc, raised plain rim, big ring lettering,
# a train wheel punched clean through the middle. No booleans: the field is lathed around the wheel.
# blender -b --python render_brass_token.py -- <out_dir> [preview|icon]  (icon: crop to 256 px square for upload)
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
MODE = args[1] if len(args) > 1 else "preview"
FONT = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

R = 1.0          # token radius
T = 0.046        # half thickness at the rim
FIELD = 0.031    # half thickness of the field
RIM_IN = 0.90    # inner edge of the raised rim
RELIEF = 0.016   # letters and wheel stand this far above the field
WHEEL_R = 0.47   # outer radius of the wheel's tyre (the field's inner edge)
TYRE = 0.09
HUB = 0.125
SPOKES = 6
SPOKE_W = 0.095


def link(obj):
    scene.collection.objects.link(obj)
    return obj


bm = bmesh.new()  # everything goes into one mesh


def lathe(profile, seg=256):
    """Revolve a closed (r, z) profile around Z into bm."""
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z))
                      for i in range(seg)])
    n = len(rings)
    for k in range(n):
        a, b = rings[k], rings[(k + 1) % n]
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))


def prism(outline, z0, z1):
    """Extrude a 2D outline (counter-clockwise) from z0 to z1 into bm."""
    bot = [bm.verts.new((x, y, z0)) for x, y in outline]
    top = [bm.verts.new((x, y, z1)) for x, y in outline]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))


C = 0.012  # small chamfer on every stamped edge
# field and rim: inner wall at the tyre, field, rim step, rounded outer edge (mirrored below)
lathe([
    (WHEEL_R - 0.004, -FIELD), (WHEEL_R - 0.004, FIELD),
    (RIM_IN - C, FIELD), (RIM_IN, FIELD + 0.004), (RIM_IN + C * 0.6, T),
    (R - 0.03, T), (R - 0.008, T - 0.01), (R, T - 0.03),
    (R, -T + 0.03), (R - 0.008, -T + 0.01), (R - 0.03, -T),
    (RIM_IN + C * 0.6, -T), (RIM_IN, -FIELD - 0.004), (RIM_IN - C, -FIELD),
])
# the wheel, raised on both faces: tyre, hub, spokes
ZT = FIELD + RELIEF
lathe([(WHEEL_R - TYRE, -ZT), (WHEEL_R - TYRE, ZT), (WHEEL_R - 0.006, ZT), (WHEEL_R, ZT - 0.006),
       (WHEEL_R, -ZT + 0.006), (WHEEL_R - 0.006, -ZT)])
lathe([(0.0005, -ZT - 0.006), (HUB - 0.01, -ZT - 0.004), (HUB, -ZT + 0.004), (HUB, ZT - 0.004),
       (HUB - 0.01, ZT + 0.004), (0.0005, ZT + 0.006)], seg=96)
for i in range(SPOKES):
    a = 2 * math.pi * i / SPOKES + math.pi / 2
    r0, r1, w = HUB - 0.02, WHEEL_R - TYRE + 0.02, SPOKE_W / 2
    # spokes taper slightly toward the tyre, like a cast wheel
    pts = [(r0, -w * 1.15), (r1, -w * 0.85), (r1, w * 0.85), (r0, w * 1.15)]
    rot = [(x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)) for x, y in pts]
    prism(rot, -ZT + 0.002, ZT - 0.002)


def letters(text, radius, size, top, sign=1):
    """Raised letters on the field (face `sign`), around the ring; baselines toward the rim."""
    font = bpy.data.fonts.load(FONT, check_existing=True)
    glyphs = []
    for ch in text:
        if ch == " ":
            glyphs.append((None, size * 0.26))
            continue
        cu = bpy.data.curves.new("ch", "FONT")
        cu.body, cu.font, cu.size = ch, font, size
        cu.align_x, cu.align_y = "CENTER", "BOTTOM_BASELINE"
        cu.extrude = RELIEF / 2
        cu.bevel_depth, cu.bevel_resolution = 0.003, 2
        ob = link(bpy.data.objects.new("ch", cu))
        deps = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(deps))
        xs = [v.co.x for v in me.vertices]
        width = (max(xs) - min(xs)) * 0.86
        glyphs.append((me, width + size * 0.035))
        bpy.data.objects.remove(ob)
    total = sum(w for _, w in glyphs)
    a = math.pi / 2 + total / radius / 2 if top else -math.pi / 2 - total / radius / 2
    for me, w in glyphs:
        da = w / radius
        mid = a - da / 2 if top else a + da / 2
        a = a - da if top else a + da
        if me is None:
            continue
        # top line: letters stand on a circle, baseline inward; bottom line: baseline outward
        if top:
            base_r = radius - size * 0.36
            m = Matrix.Rotation(mid - math.pi / 2, 4, "Z") @ Matrix.Translation((0, base_r, 0))
        else:
            base_r = radius + size * 0.36
            m = Matrix.Rotation(mid + math.pi / 2, 4, "Z") @ Matrix.Translation((0, -base_r, 0))
        m = Matrix.Translation((0, 0, sign * (FIELD + RELIEF / 2) - 0.002 * sign)) @ m @ Matrix.Diagonal((0.86, 1, sign, 1))
        me.transform(m)
        if sign < 0:
            me.flip_normals()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)


letters("LAST TRAIN OUT", 0.70, 0.235, True)
letters("GOOD FOR ONE FARE", 0.70, 0.205, False)
letters("NOT TRANSFERABLE", 0.70, 0.17, True, -1)
# five-point stars between the two lines
for side in (-1, 1):
    pts = []
    for k in range(10):
        ang = math.pi / 2 + k * math.pi / 5
        rr = 0.06 if k % 2 == 0 else 0.024
        pts.append((0.70 * side + rr * math.cos(ang), rr * math.sin(ang)))
    prism(pts, FIELD - 0.002, FIELD + RELIEF)

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("Token")
bm.to_mesh(me)
bm.free()
body = link(bpy.data.objects.new("Token", me))
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.shade_auto_smooth(angle=math.radians(35))

# --- material: aged fare-token brass ------------------------------------------------------------
mat = bpy.data.materials.new("AgedBrass")
mat.use_nodes = True
nt = mat.node_tree
N, L = nt.nodes, nt.links
for n in list(N):
    N.remove(n)
out = N.new("ShaderNodeOutputMaterial")
bsdf = N.new("ShaderNodeBsdfPrincipled")
L.new(bsdf.outputs[0], out.inputs[0])
bsdf.inputs["Metallic"].default_value = 1.0

geo = N.new("ShaderNodeNewGeometry")
ao = N.new("ShaderNodeAmbientOcclusion")
ao.inputs["Distance"].default_value = 0.035
ao.samples = 16
tc = N.new("ShaderNodeTexCoord")


def ramp(stops, inp):
    r = N.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position, r.color_ramp.elements[0].color = stops[0]
    r.color_ramp.elements[1].position, r.color_ramp.elements[1].color = stops[-1]
    for p, c in stops[1:-1]:
        e = r.color_ramp.elements.new(p)
        e.color = c
    L.new(inp, r.inputs[0])
    return r


def noise(scale, detail, rough):
    t = N.new("ShaderNodeTexNoise")
    t.inputs["Scale"].default_value = scale
    t.inputs["Detail"].default_value = detail
    t.inputs["Roughness"].default_value = rough
    L.new(tc.outputs["Object"], t.inputs["Vector"])
    return t


def rgb(c):
    n = N.new("ShaderNodeRGB")
    n.outputs[0].default_value = (*c, 1)
    return n.outputs[0]


def mix(a, b, fac):
    m = N.new("ShaderNodeMix")
    m.data_type = "RGBA"
    L.new(fac, m.inputs["Factor"])
    L.new(a, m.inputs[6])
    L.new(b, m.inputs[7])
    return m.outputs[2]


# cavity: recesses dark and grimy; sharp highs rubbed bright
cav = ramp([(0.35, (0, 0, 0, 1)), (0.9, (1, 1, 1, 1))], ao.outputs["AO"])
edge = ramp([(0.5, (0, 0, 0, 1)), (0.56, (1, 1, 1, 1))], geo.outputs["Pointiness"])
blot = ramp([(0.42, (0, 0, 0, 1)), (0.58, (1, 1, 1, 1))], noise(3.2, 6, 0.6).outputs["Fac"])

brass_dull = rgb((0.36, 0.21, 0.06))     # toned, handled brass
brass_warm = rgb((0.70, 0.46, 0.14))
brass_bright = rgb((0.88, 0.64, 0.30))   # rubbed high points
grime = rgb((0.045, 0.03, 0.015))        # packed dirt in the recesses
olive = rgb((0.20, 0.15, 0.06))          # faint olive toning

c = mix(brass_dull, brass_warm, blot.outputs[0])
c = mix(olive, c, ramp([(0.15, (0.55, 0.55, 0.55, 1)), (0.5, (1, 1, 1, 1))], noise(1.4, 4, 0.5).outputs["Fac"]).outputs[0])
# tarnish blotches: darker brown patches across the field, as on handled tokens
tarnish = ramp([(0.47, (0, 0, 0, 1)), (0.62, (0.75, 0.75, 0.75, 1))], noise(7.5, 8, 0.62).outputs["Fac"])
c = mix(c, rgb((0.17, 0.10, 0.035)), tarnish.outputs[0])
# dirt gathers in the corners: along the rim's inner step and around the wheel
rad = N.new("ShaderNodeVectorMath")
rad.operation = "LENGTH"
L.new(tc.outputs["Object"], rad.inputs[0])
rim_dirt = ramp([(0.0, (0, 0, 0, 1)), (0.80, (0, 0, 0, 1)), (RIM_IN - 0.005, (0.85, 0.85, 0.85, 1)), (RIM_IN + 0.004, (0, 0, 0, 1))], rad.outputs["Value"])
hub_dirt = ramp([(WHEEL_R - 0.01, (0, 0, 0, 1)), (WHEEL_R + 0.004, (0.7, 0.7, 0.7, 1)), (WHEEL_R + 0.07, (0, 0, 0, 1))], rad.outputs["Value"])
c = mix(c, rgb((0.08, 0.05, 0.02)), rim_dirt.outputs[0])
c = mix(c, rgb((0.08, 0.05, 0.02)), hub_dirt.outputs[0])
c = mix(grime, c, cav.outputs[0])
# raised highs (letters, wheel, rim) rubbed brighter by handling than the sunken field
xyz = N.new("ShaderNodeSeparateXYZ")
L.new(tc.outputs["Object"], xyz.inputs[0])
absz = N.new("ShaderNodeMath")
absz.operation = "ABSOLUTE"
L.new(xyz.outputs["Z"], absz.inputs[0])
highs = N.new("ShaderNodeMapRange")
highs.inputs["From Min"].default_value = FIELD + 0.004
highs.inputs["From Max"].default_value = FIELD + RELIEF - 0.002
L.new(absz.outputs[0], highs.inputs["Value"])
hw = N.new("ShaderNodeMath")
hw.operation = "MULTIPLY"
hw.inputs[1].default_value = 0.7
L.new(highs.outputs[0], hw.inputs[0])
c = mix(c, brass_warm, hw.outputs[0])
c = mix(c, brass_bright, edge.outputs[0])
L.new(c, bsdf.inputs["Base Color"])

# roughness: satin, grime rougher, worn highs smoother
rough_base = ramp([(0.0, (0.30, 0.3, 0.3, 1)), (1.0, (0.46, 0.46, 0.46, 1))], noise(18, 8, 0.65).outputs["Fac"])
r = mix(rgb((0.72, 0.72, 0.72)), rough_base.outputs[0], cav.outputs[0])
r = mix(r, rgb((0.2, 0.2, 0.2)), edge.outputs[0])
sep = N.new("ShaderNodeSeparateColor")
L.new(r, sep.inputs[0])
L.new(sep.outputs[0], bsdf.inputs["Roughness"])

# micro surface: pitting and fine circular handling marks as bump
pits = noise(220, 6, 0.75)
scr = N.new("ShaderNodeTexWave")
scr.wave_type = "BANDS"
scr.inputs["Scale"].default_value = 90
scr.inputs["Distortion"].default_value = 40
scr.inputs["Detail"].default_value = 6
L.new(tc.outputs["Object"], scr.inputs["Vector"])
add = N.new("ShaderNodeMath")
add.operation = "ADD"
L.new(pits.outputs["Fac"], add.inputs[0])
sm = N.new("ShaderNodeMath")
sm.operation = "MULTIPLY"
sm.inputs[1].default_value = 0.25
L.new(scr.outputs["Fac"], sm.inputs[0])
L.new(sm.outputs[0], add.inputs[1])
bump = N.new("ShaderNodeBump")
bump.inputs["Strength"].default_value = 0.09
bump.inputs["Distance"].default_value = 0.002
L.new(add.outputs[0], bump.inputs["Height"])
L.new(bump.outputs[0], bsdf.inputs["Normal"])
body.data.materials.append(mat)

# --- staging --------------------------------------------------------------------------------
body.rotation_euler = (math.radians(-26), math.radians(6), math.radians(-8))

world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
wn, wl = world.node_tree.nodes, world.node_tree.links
wb = wn["Background"]
# a soft dark-to-warm gradient world so the metal has something to reflect
wtc = wn.new("ShaderNodeTexCoord")
sepw = wn.new("ShaderNodeSeparateXYZ")
mp = wn.new("ShaderNodeMapRange")
wr = wn.new("ShaderNodeValToRGB")
wr.color_ramp.elements[0].color = (0.010, 0.012, 0.016, 1)
wr.color_ramp.elements[1].color = (0.22, 0.17, 0.11, 1)
wl.new(wtc.outputs["Generated"], sepw.inputs[0])
wl.new(sepw.outputs["Z"], mp.inputs[0])
wl.new(mp.outputs[0], wr.inputs[0])
wl.new(wr.outputs[0], wb.inputs[0])
wb.inputs[1].default_value = 0.6


def area(name, loc, energy, color, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.color, ld.size = energy, color, size
    ob = link(bpy.data.objects.new(name, ld))
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return ob


area("Key", (-2.6, -2.2, 3.4), 380, (1.0, 0.80, 0.58), 1.6)   # lantern-warm key
area("Rim", (2.8, 2.6, 1.2), 200, (0.62, 0.74, 1.0), 0.9)     # cold moonlight rim
area("Fill", (0.5, -3.5, -0.6), 40, (1.0, 0.9, 0.8), 3.0)

cam_d = bpy.data.cameras.new("cam")
cam_d.lens = 85
cam = link(bpy.data.objects.new("cam", cam_d))
cam.location = (0, -0.25, 6.4)
cam.rotation_euler = (math.radians(2.2), 0, 0)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 96 if MODE == "icon" else 64
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Punchy"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"

if MODE == "icon":
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = 512
    cam_d.lens = 92
    # an icon sits on dark UI: lift the lights so it reads at 24-32 px
    for ob in scene.objects:
        if ob.type == "LIGHT":
            ob.data.energy *= 1.7
    scene.render.filepath = os.path.join(OUT, "brass_token_icon.png")
else:
    # a dark counter top under it
    bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, -0.6))
    plate = bpy.context.active_object
    pm = bpy.data.materials.new("Counter")
    pm.use_nodes = True
    pb = pm.node_tree.nodes["Principled BSDF"]
    pb.inputs["Base Color"].default_value = (0.035, 0.025, 0.018, 1)
    pb.inputs["Roughness"].default_value = 0.7
    plate.data.materials.append(pm)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 900
    scene.render.filepath = os.path.join(OUT, "brass_token_preview.png")

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"brass_token_{MODE}.blend"))
bpy.ops.render.render(write_still=True)
print("TOKEN_DONE", scene.render.filepath)
