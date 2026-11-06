"""Oil paintings for Last Train Out: the saloon's four landscapes and two station landscapes,
rendered in Cycles and finished as oil on canvas (Kuwahara brushwork, then varnish, canvas weave
and a darkened edge in numpy).

    blender -b --python tools/paintings/paintings.py -- <out_dir> [name ...]

Writes <name>.png at 720 x 520 (the canvas's 2.16 x 1.56 studs). Upload as Decal images and put the
ids in src/shared/Config/Paintings.luau.
"""

import math
import os
import random
import sys

import bpy
import numpy as np

W, H = 720, 520
SPP = 48


def rgb(r, g, b):
    return (r / 255, g / 255, b / 255, 1)


# the saloon's four (same order and colours as Builders/TrainInterior PAINTINGS), then the stations'
LANDSCAPES = {
    "train1_dusk_viaduct": dict(top=rgb(78, 48, 92), mid=rgb(226, 116, 78), horizon=rgb(252, 198, 124),
        peaks=rgb(116, 66, 90), land=rgb(32, 22, 30), water=rgb(140, 76, 88), orb=rgb(255, 224, 156),
        orb_alt=4, orb_az=-8, moon=False, lamps=True, stars=False, seed=1),
    "train2_high_line_noon": dict(top=rgb(78, 132, 178), mid=rgb(150, 192, 214), horizon=rgb(240, 226, 192),
        peaks=rgb(108, 132, 158), land=rgb(38, 60, 44), water=rgb(86, 136, 162), orb=rgb(255, 246, 214),
        orb_alt=30, orb_az=14, moon=False, lamps=False, stars=False, seed=2),
    "train3_amber_moon": dict(top=rgb(10, 12, 30), mid=rgb(38, 32, 66), horizon=rgb(108, 58, 74),
        peaks=rgb(42, 36, 64), land=rgb(9, 9, 15), water=rgb(32, 28, 54), orb=rgb(240, 136, 76),
        orb_alt=16, orb_az=10, moon=True, lamps=True, stars=True, seed=3),
    "train4_last_light_pass": dict(top=rgb(36, 46, 78), mid=rgb(102, 100, 138), horizon=rgb(204, 166, 166),
        peaks=rgb(80, 82, 112), land=rgb(22, 26, 28), water=rgb(88, 88, 120), orb=rgb(244, 236, 218),
        orb_alt=20, orb_az=-16, moon=True, lamps=True, stars=True, seed=4),
    # station rooms: older canvases gone dark under their varnish
    "station_land1_valley": dict(top=rgb(54, 58, 52), mid=rgb(120, 112, 82), horizon=rgb(196, 170, 112),
        peaks=rgb(84, 80, 66), land=rgb(30, 30, 22), water=rgb(96, 92, 70), orb=rgb(232, 206, 150),
        orb_alt=8, orb_az=12, moon=False, lamps=False, stars=False, seed=5, dark=0.5, train=False),
    "station_land2_mill": dict(top=rgb(40, 40, 46), mid=rgb(92, 80, 70), horizon=rgb(170, 132, 96),
        peaks=rgb(70, 62, 60), land=rgb(26, 22, 20), water=rgb(70, 62, 58), orb=rgb(220, 180, 130),
        orb_alt=6, orb_az=-12, moon=False, lamps=True, stars=False, seed=6, dark=0.55, train=True),
}
# portraits were tried (a lit bust under heavy varnish) and read as mannequins: dropped, not shipped


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.samples = SPP
    s.cycles.use_denoising = True
    s.render.resolution_x, s.render.resolution_y = W, H
    s.render.film_transparent = False
    s.view_settings.view_transform = "Standard"
    return s


def mat(name, color, rough=0.8, emit=0.0, metallic=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
    return m


def vcolor_mat(name):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    return m


def obj(name, mesh_fn, loc, scale=(1, 1, 1), material=None, rot=(0, 0, 0)):
    mesh_fn(location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    if material:
        o.data.materials.append(material)
    return o


def box(name, loc, size, material, rot=(0, 0, 0)):
    o = obj(name, bpy.ops.mesh.primitive_cube_add, loc, (size[0] / 2, size[1] / 2, size[2] / 2), material, rot)
    return o


def world_sky(s, top, mid, horizon, strength=1.0):
    w = bpy.data.worlds.new("Sky")
    s.world = w
    nt = w.node_tree
    nt.nodes.clear()
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    bg = nt.nodes.new("ShaderNodeBackground")
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, horizon
    els[1].position, els[1].color = 0.28, top
    mid_el = els.new(0.08)
    mid_el.color = mid
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    nt.links.new(bg.outputs[0], out.inputs[0])


def ridge(name, rng, x0, x1, y, depth, base_z, height, color, snow, sun_dir, res=90, rough=1.0):
    """A mountain range as a heightfield strip, its colour baked per vertex: lit flank, shade, snow."""
    mesh = bpy.data.meshes.new(name)
    nx, ny = res, 18
    verts, faces, cols = [], [], []
    phase = [rng.uniform(0, 100) for _ in range(4)]

    def hgt(u, v):
        h = 0.0
        amp, freq = 1.0, 1.2
        for k in range(4):
            h += amp * abs(math.sin(u * freq * 6.0 + phase[k]) * math.cos(u * freq * 2.3 + phase[k] * 0.7))
            amp *= 0.5
            freq *= 2.1
        peak = h / 1.9
        return height * peak * (1 - v) ** 1.4 * rough

    for j in range(ny + 1):
        v = j / ny
        for i in range(nx + 1):
            u = i / nx
            verts.append((x0 + (x1 - x0) * u, y + depth * v, base_z + hgt(u, v)))
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    layer = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for poly in mesh.polygons:
        n = poly.normal
        lit = max(0.0, n.x * sun_dir[0] + n.y * sun_dir[1] + n.z * sun_dir[2])
        zc = sum(mesh.vertices[k].co.z for k in poly.vertices) / len(poly.vertices)
        rel = (zc - base_z) / max(height, 1e-3)
        c = [color[k] * (0.55 + 0.75 * lit) for k in range(3)]
        if snow and rel > 0.55 and n.z > 0.35:
            c = [0.86 * (0.6 + 0.5 * lit), 0.86 * (0.6 + 0.5 * lit), 0.9 * (0.65 + 0.45 * lit)]
        for li in poly.loop_indices:
            layer.data[li].color = (c[0], c[1], c[2], 1)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(vcolor_mat(name + "Mat"))
    return o


def landscape(name, p, out):
    s = reset()
    rng = random.Random(p["seed"])
    world_sky(s, p["top"], p["mid"], p["horizon"], 1.0 if not p["moon"] else 0.6)
    alt, az = math.radians(p["orb_alt"]), math.radians(p["orb_az"])
    sun_dir = (math.sin(az) * math.cos(alt), math.cos(az) * math.cos(alt), math.sin(alt))
    # the orb in its halo, out over the far range
    dist = 900
    orb_pos = (sun_dir[0] * dist, sun_dir[1] * dist, sun_dir[2] * dist + 18)
    orb_size = 26 if p["moon"] else 32
    obj("Orb", bpy.ops.mesh.primitive_uv_sphere_add, orb_pos, (orb_size,) * 3, mat("OrbM", p["orb"], emit=4 if p["moon"] else 9))
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.color = p["orb"][:3]
    sun.energy = 1.4 if p["moon"] else 3.2
    sun.angle = math.radians(6)  # soft edges, so the foreground shadows read as dusk not blots
    sun_o = bpy.data.objects.new("Sun", sun)
    bpy.context.collection.objects.link(sun_o)
    sun_o.rotation_euler = (math.radians(90) - alt, 0, -az + math.pi)
    # stars or streaked clouds
    if p["stars"]:
        star = mat("Star", rgb(255, 244, 220), emit=20)
        for k in range(70):
            a, e = rng.uniform(-0.75, 0.75), rng.uniform(0.18, 0.5)
            obj(f"Star{k}", bpy.ops.mesh.primitive_ico_sphere_add,
                (math.sin(a) * 950, math.cos(a) * 950, math.tan(e) * 950), (rng.uniform(0.8, 2.0),) * 3, star)
    cloud = mat("Cloud", tuple(min(1, c * 1.15) for c in p["horizon"][:3]) + (1,), emit=0.9, alpha=0.55)
    for k in range(9):
        a, e = rng.uniform(-0.6, 0.6), rng.uniform(0.07, 0.28)
        obj(f"Cloud{k}", bpy.ops.mesh.primitive_uv_sphere_add,
            (math.sin(a) * 800, math.cos(a) * 800, math.tan(e) * 800), (rng.uniform(60, 140), 8, rng.uniform(5, 11)), cloud)
    # far snowy range, near range, and the land
    ridge("FarRange", rng, -900, 900, 820, 300, -10, 230, p["peaks"], True, sun_dir)
    near = tuple(c * 0.75 + l * 0.25 for c, l in zip(p["peaks"][:3], p["land"][:3]))
    ridge("NearRange", rng, -700, 700, 560, 200, -6, 110, near, False, sun_dir, rough=0.9)
    # the lake, catching the orb
    water = mat("Water", p["water"], rough=0.2)
    box("Lake", (0, 330, -2), (1600, 520, 1), water)
    land = mat("Land", p["land"], rough=1)
    box("Foreground", (0, 10, -1), (900, 120, 4), land)
    box("BankL", (-170, 95, -1), (220, 60, 5), land, (0, 0, 0.18))
    box("BankR", (190, 110, -1.5), (200, 40, 4), land, (0, 0, -0.1))
    # the viaduct across the lake and the train on it
    stone = mat("Stone", tuple(c * 0.6 + 0.12 for c in p["peaks"][:3]) + (1,), rough=0.9)
    deck_z, vy = 30, 420
    box("Deck", (40, vy, deck_z), (420, 8, 3.5), stone)
    box("Parapet", (40, vy - 3.6, deck_z + 2.6), (420, 0.8, 1.8), stone)
    for k in range(-9, 10):
        box(f"Pier{k}", (40 + k * 22, vy, deck_z / 2 - 2), (5.5, 7, deck_z), stone)
    if p.get("train", True):
        loco = mat("Loco", rgb(24, 22, 22), rough=0.4, metallic=0.4)
        box("Loco", (-40, vy, deck_z + 5.5), (22, 6, 8), loco)
        obj("Boiler", bpy.ops.mesh.primitive_cylinder_add, (-34, vy, deck_z + 6.5), (3.2, 3.2, 9), loco, (0, math.pi / 2, 0))
        obj("Stack", bpy.ops.mesh.primitive_cylinder_add, (-27, vy, deck_z + 12), (1.2, 1.2, 2.6), loco)
        coach = mat("Coach", rgb(70, 30, 26), rough=0.6)
        lamp = mat("Window", rgb(255, 196, 110), emit=12 if p["lamps"] else 0.6)
        for k in range(3):
            cx = -66 - k * 25
            box(f"Coach{k}", (cx, vy, deck_z + 5.6), (23, 6.2, 8), coach)
            for w in range(6):
                box(f"Win{k}_{w}", (cx - 9 + w * 3.6, vy - 3.2, deck_z + 6.6), (2, 0.3, 2.4), lamp)
        smoke = mat("Smoke", rgb(214, 206, 196), emit=0.6, alpha=0.5)
        for k in range(10):
            obj(f"Smoke{k}", bpy.ops.mesh.primitive_uv_sphere_add,
                (-27 - k * 9, vy + rng.uniform(-2, 6), deck_z + 16 + k * 2.4), (4 + k * 1.2, 4 + k * 0.8, 3 + k * 0.8), smoke)
    # foreground: pines, a semaphore signal and telegraph poles strung with sagging wire
    pine = mat("Pine", tuple(c * 0.55 for c in p["land"][:3]) + (1,), rough=1)
    for k in range(18):
        y = rng.uniform(55, 120)
        side = -1 if k % 3 else 1
        x = side * rng.uniform(0.32, 0.62) * (y + 70)
        h = rng.uniform(18, 34)
        for tier in range(3):
            r = h * (0.26 - tier * 0.06)
            obj(f"Pine{k}_{tier}", bpy.ops.mesh.primitive_cone_add, (x, y, h * (0.32 + tier * 0.24)), (r, r, h * 0.3), pine)
    iron = mat("Iron", rgb(20, 18, 18), rough=0.7)
    box("SignalPost", (52, 80, 18), (1.2, 1.2, 36), iron)
    box("SignalArm", (55.5, 79.3, 34), (7, 0.5, 1.3), mat("Arm", rgb(170, 34, 30)), (0, math.radians(-20), 0))
    if p["lamps"]:
        obj("SignalLamp", bpy.ops.mesh.primitive_uv_sphere_add, (52, 79, 31.5), (0.8,) * 3, mat("Lamp", rgb(120, 255, 140), emit=30))
    poles = [(-150 + k * 34, 70 + k * 16) for k in range(4)]
    for k, (x, y) in enumerate(poles):
        box(f"Pole{k}", (x, y, 15), (0.9, 0.9, 30), iron)
        box(f"Cross{k}", (x, y, 28.5), (5, 0.5, 0.5), iron)
    for k in range(len(poles) - 1):
        (xa, ya), (xb, yb) = poles[k], poles[k + 1]
        curve = bpy.data.curves.new(f"Wire{k}", "CURVE")
        curve.dimensions = "3D"
        curve.bevel_depth = 0.12
        spl = curve.splines.new("POLY")
        spl.points.add(8)
        for i in range(9):
            t = i / 8
            spl.points[i].co = (xa + (xb - xa) * t, ya + (yb - ya) * t, 28.5 - 3.2 * math.sin(math.pi * t), 1)
        wo = bpy.data.objects.new(f"Wire{k}", curve)
        wo.data.materials.append(iron)
        bpy.context.collection.objects.link(wo)
    # the camera, low on the near shore looking across the water
    cam = bpy.data.cameras.new("Cam")
    cam.lens = 30
    co = bpy.data.objects.new("Cam", cam)
    bpy.context.collection.objects.link(co)
    co.location = (0, -70, 46)
    co.rotation_euler = (math.radians(87), 0, 0)
    cam.lens = 32
    s.camera = co
    render(s, name, out, p.get("dark", 0.0))


def render(s, name, out, dark):
    tree = bpy.data.node_groups.new("Oil", "CompositorNodeTree")
    s.compositing_node_group = tree
    rl = tree.nodes.new("CompositorNodeRLayers")
    glare = tree.nodes.new("CompositorNodeGlare")
    glare.inputs["Type"].default_value = "Fog Glow"
    glare.inputs["Strength"].default_value = 0.6
    kuw = tree.nodes.new("CompositorNodeKuwahara")
    kuw.inputs["Size"].default_value = 7
    kuw.inputs["Type"].default_value = "Anisotropic"
    outn = tree.nodes.new("NodeGroupOutput")
    tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
    tree.links.new(glare.outputs["Image"], kuw.inputs["Image"])
    tree.links.new(kuw.outputs["Image"], outn.inputs[0])
    raw = os.path.join(out, f"_{name}_raw.png")
    s.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    finish(raw, os.path.join(out, f"{name}.png"), dark)
    os.remove(raw)


def finish(src, dst, dark):
    """Varnish, canvas weave and a darkened edge, in numpy."""
    img = bpy.data.images.load(src)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgbv = px[..., :3]
    # amber varnish: warm the lights, sink the blues, and age it by `dark`
    varnish = np.array([1.0, 0.9, 0.7], dtype=np.float32)
    rgbv = rgbv * (1 - 0.25 - 0.4 * dark) + rgbv * varnish * (0.25 + 0.4 * dark)
    rgbv *= 1 - 0.45 * dark
    # the edge darkens under the frame
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx / w - 0.5) / 0.62) ** 2 + ((yy / h - 0.5) / 0.6) ** 2)
    rgbv *= np.clip(1.15 - 0.55 * d ** 2, 0.45, 1.0)[..., None]
    # canvas weave and a little craquelure grain
    weave = 0.035 * np.sin(xx * 1.9) * np.sin(yy * 1.9)
    grain = np.random.default_rng(1).normal(0, 0.012, (h, w)).astype(np.float32)
    rgbv += (weave + grain)[..., None]
    px[..., :3] = np.clip(rgbv, 0, 1)
    px[..., 3] = 1
    img.pixels[:] = px.ravel()
    img.filepath_raw = dst
    img.file_format = "PNG"
    img.save()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = os.path.abspath(argv[0] if argv else "paintings_out")
    os.makedirs(out, exist_ok=True)
    only = set(argv[1:])
    for name, p in LANDSCAPES.items():
        if not only or name in only:
            landscape(name, p, out)


main()
