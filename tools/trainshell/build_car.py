"""
Builds one car's exterior in Blender from the measured primitive train:

  blender -b --factory-startup -P tools/trainshell/build_car.py -- <dump.json> <car> <out_dir>

Writes <out_dir>/<car>.blend (modifiers live), <car>.fbx (modifiers applied, one object per
MeshPart) and <car>.json (each MeshPart's centre and size in train space, role and triangles).
"""

import json
import os
import sys

import bpy


sys.path.insert(0, os.path.dirname(__file__))
import carriage  # noqa: E402
import kit  # noqa: E402

CARS = {
    # name: body x0, x1 (TrainBuilder's car() calls)
    "GuardsVan": (-90, -66),
    "LastTrainOut": (-63, -44.5),
    "CrewSaloon": (-41.5, -23),
    "Workshop": (-20, -1.5),
    "Stores": (1.5, 20),
}


def measure(dump, x0, x1):
    spec = {"x0": x0, "x1": x1, "windows": {1: [], -1: []}, "doors": {1: [], -1: []}}
    board = 12
    rear = front = False
    for p in dump:
        x, y, z = p["cf"][:3]
        s = p["size"]
        # an open deck floored behind the rear wall (the guard's veranda): its far end is the car's end
        if p["material"] == "WoodPlanks" and abs(y + 0.5) < 0.01 and x < x0 and abs(x + s[0] / 2 - x0) < 0.05:
            spec["rearDeck"] = x - s[0] / 2
        if not (x0 - 0.01 <= x <= x1 + 0.01):
            continue
        if p["material"] == "Glass" and p["name"] == "Part" and abs(abs(z) - 6.25) < 0.05 and abs(s[0] - 3.6) < 0.01:
            spec["windows"][1 if z > 0 else -1].append(round(x, 3))
        if p["name"] == "DoorBlocker":
            spec["doors"][1 if z > 0 else -1].append(round(x, 3))
        if p["material"] == "Wood" and abs(y - 8.15) < 0.01 and abs(s[1] - 0.62) < 0.01:
            board = s[0]
        # an end wall with a gangway has a lintel 4 wide over the opening
        if abs(s[0] - 0.5) < 0.01 and abs(s[1] - 2) < 0.01 and abs(s[2] - 4) < 0.01:
            if abs(x - (x0 + 0.25)) < 0.05:
                rear = True
            if abs(x - (x1 - 0.25)) < 0.05:
                front = True
    for side in (1, -1):
        spec["windows"][side].sort()
        spec["doors"][side].sort()
    spec["board"] = board - 1
    spec["rearGangway"], spec["frontGangway"] = rear, front
    cx = (x0 + x1) / 2
    half = (x1 - x0 + 0.6 - 4.6) / 2
    spec["monitor"] = (cx - half, cx + half)
    return spec


def main():
    args = sys.argv[sys.argv.index("--") + 1 :]
    dump = json.load(open(args[0]))
    car, out = args[1], args[2]
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    col = bpy.data.collections.new(car)
    bpy.context.scene.collection.children.link(col)
    spec = measure(dump, *CARS[car])
    spec["name"] = car
    print("SPEC", {k: v for k, v in spec.items() if not k.startswith("_")})
    pieces = carriage.build(spec, col)
    family = [p.name for p in pieces if p.name.startswith((f"{car}_skin", f"{car}_end", f"{car}_mon"))]
    objs = kit.assemble(col, pieces, {f"{car}_Shell": family + [f"{car}_Iron", f"{car}_Brass"]})
    if f"{car}_Sign" in objs:
        kit.sign_uv(objs[f"{car}_Sign"], spec["boards"])
    meta = {"car": car, "spec": {k: v for k, v in spec.items() if not k.startswith("_")}, "parts": kit.describe(objs)}
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, f"{car}.blend"))
    json.dump(meta, open(os.path.join(out, f"{car}.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
