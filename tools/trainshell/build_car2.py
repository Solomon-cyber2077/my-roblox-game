"""
Round 2 of build_car.py: builds one car from carriage2 (carved skin, full hardware, gangway).

  blender -b --factory-startup -P tools/trainshell/build_car2.py -- <dump.json> <car> <out_dir>

Writes <out_dir>/<car>.blend, <car>.json (each MeshPart's centre, size, role and triangles, the
spec with its wear features, sign labels and door-lamp positions).
"""

import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import build_car  # noqa: E402  (measure, CARS)
import carriage2  # noqa: E402
import kit  # noqa: E402
import signs  # noqa: E402
from kit import R  # noqa: E402


def label_uv(ob, lab, rect_px):
    me = ob.data
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    mw = ob.matrix_world
    x0, y0, x1, y1 = lab["rect"]
    side = lab["side"]
    gu, gv = signs.GROUND[0] / signs.W, 1 - signs.GROUND[1] / signs.H
    for poly in me.polygons:
        n = mw.to_3x3() @ poly.normal
        rz = -n.y
        front = rz * side > 0.9
        for li in poly.loop_indices:
            p = R(mw @ me.vertices[me.loops[li].vertex_index].co)
            if front:
                u = (p[0] - x0) / (x1 - x0)
                if side < 0:
                    u = 1 - u
                v = (p[1] - y0) / (y1 - y0)
                uv.data[li].uv = signs.uv_for(rect_px, min(max(u, 0), 1), min(max(v, 0), 1))
            else:
                uv.data[li].uv = (gu, gv)


SIDE_Y = (-1.5, 9.95)  # the band of a side players see (solebar and step up to the cornice)


def split_sides(ob, car, base):
    """Move the faces on each side of the car into their own object (<car>_<base>P / N): a
    SurfaceAppearance map is at most 1024 square, so each side gets a whole atlas of its own."""
    out = []
    for side, tag in ((1, "P"), (-1, "N")):
        me = ob.data
        mw = ob.matrix_world
        sel = []
        for poly in me.polygons:
            c = R(mw @ poly.center)
            sel.append(c[2] * side > 5.9 and SIDE_Y[0] < c[1] < SIDE_Y[1])
        if not any(sel):
            continue
        for poly, s in zip(me.polygons, sel):
            poly.select = s
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_mode(type="FACE")
        bpy.ops.object.mode_set(mode="OBJECT")
        for poly, s in zip(me.polygons, sel):
            poly.select = s
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        new = [o for o in bpy.context.selected_objects if o is not ob][0]
        new.name = f"{car}_{base}{tag}"
        new.data.name = new.name
        new["role"], new["material"] = ob["role"], ob["material"]
        new["atlas"] = f"{car}_{tag}"
        out.append(new)
    ob["atlas"] = car
    return out


def join(target, others):
    for ob in others:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        target.select_set(True)
        bpy.context.view_layer.objects.active = target
        bpy.ops.object.join()


def main():
    args = sys.argv[sys.argv.index("--") + 1 :]
    dump = json.load(open(args[0]))
    car, out = args[1], args[2]
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    col = bpy.data.collections.new(car)
    bpy.context.scene.collection.children.link(col)
    spec = build_car.measure(dump, *build_car.CARS[car])
    spec["name"] = car
    pieces = carriage2.build(spec, col)
    names = [p.name for p in pieces]
    shell_family = [n for n in names if n.startswith((f"{car}_skin", f"{car}_end", f"{car}_mon"))]
    fittings = [f"{car}_Brass", f"{car}_Teak", f"{car}_Velvet", f"{car}_Bellows"]
    joins = {f"{car}_Shell": shell_family, f"{car}_Fittings": fittings}
    joins.update(spec.get("leafJoins", {}))  # identity.py's heavy door leaves take their iron and brass
    objs = kit.assemble(col, pieces, joins)
    for ob in list(col.objects):
        if ob.type == "MESH" and not ob.data.polygons:
            bpy.data.objects.remove(ob)  # the empty Sign base would steal the Sign name
    # signs: UV every label into the atlas, then join them into one MeshPart
    rects = signs.layout(spec["labels"])
    lab_objs = []
    for lab in spec["labels"]:
        ob = objs.pop(lab["piece"], None)
        if ob is None:
            continue
        label_uv(ob, lab, rects[lab["label"]])
        lab_objs.append(ob)
    if lab_objs:
        main_ob = lab_objs[0]
        join(main_ob, lab_objs[1:])
        main_ob.name = f"{car}_Sign"
        main_ob["role"] = ""
        main_ob["material"] = "Sign"
        objs.pop(f"{car}_Sign", None)
        objs[f"{car}_Sign"] = main_ob
    spec["signRects"] = rects
    for base in ("Shell", "Trim", "Fittings", "Crate", "Tarp"):
        ob = objs.get(f"{car}_{base}")
        if ob is None:
            continue
        for new in split_sides(ob, car, base):
            objs[new.name] = new
        if not ob.data.polygons:
            objs.pop(ob.name)
            bpy.data.objects.remove(ob)
    if f"{car}_Roof" in objs:
        objs[f"{car}_Roof"]["atlas"] = car
    for leaf in spec.get("leafJoins", {}):
        if leaf in objs:
            objs[leaf]["atlas"] = f"{car}_P"  # painted in the platform side's atlas
    meta = {"car": car, "spec": {k: v for k, v in spec.items() if not k.startswith("_")}, "parts": kit.describe(objs)}
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, f"{car}.blend"))
    json.dump(meta, open(os.path.join(out, f"{car}.json"), "w"), indent=1)


main()
