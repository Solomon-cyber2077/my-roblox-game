"""
Poses the kit's door leaves as a closed door on a car's platform side, so the door atlas can be
painted with the same cause-based wear as the cars (canvas.py + bake2.py), then puts them back.

  blender -b <in.blend> -P tools/trainshell/kitpose.py -- car <out_dir> <out.blend>
  blender -b <in.blend> -P tools/trainshell/kitpose.py -- home <out.blend>

`car` moves DoorLeafL/R to x -1.4 / +1.4, floor at y 0, leaf centre at z 6.74 (train space), every
other piece 30 studs apart along X (so nothing shades anything else in the AO bake), and
writes <out_dir>/Doors.json and Kit.json's spec: where the wear's causes are on that door (stiles
and meeting edges, hand-height pulls, hinge straps and their bolts, kick plates, rails and the
glazing light's sill). `home` undoes the move (UVs and bakes are unaffected by where a part sits).
"""

import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
from kit import V  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1 :]
MODE = args[0]
HH, HW, ST = 3.75, 1.4, 0.32
POSE = {"DoorLeafL": (-HW, HH, 6.74), "DoorLeafR": (HW, HH, 6.74)}


def leaf_features():
    """Wear causes on the posed pair (side +1, train space)."""
    f = {k: [] for k in ("panels", "ledges", "rivets", "grips", "steps", "doorEdges", "straps", "windows", "vents", "plates", "boards", "lamps")}
    for name, (cx, cy, _) in POSE.items():
        meeting = 1 if name == "DoorLeafL" else -1
        xa, xb = cx - HW, cx + HW
        # boarded fields (vertical boards, painted, unlined)
        f["panels"].append({"side": 1, "rect": [xa + ST, cy - HH + 0.5, xb - ST, cy - 0.62], "depth": 0.07, "kind": "leafboards"})
        f["panels"].append({"side": 1, "rect": [xa + ST, cy - 0.22, xb - ST, cy + HH - 0.42], "depth": 0.07, "kind": "leafboards"})
        # rain runs off the tops of the rails and the glazing light's sill
        for y in (cy - HH + 0.5, cy - 0.22, cy + 0.1 - 0.16):
            f["ledges"].append({"side": 1, "x": [xa + 0.05, xb - 0.05], "y": y})
        # hinge straps: bolts weep rust, and the strap's lower edge streaks
        ox = cx - meeting * HW
        for y in (-2.55, 2.85):
            for k in range(4):
                f["rivets"].append({"side": 1, "x": ox + meeting * (0.15 + k * 0.38), "y": cy + y})
            a, b = sorted((ox, ox + meeting * 1.7))
            f["ledges"].append({"side": 1, "x": [a, b], "y": cy + y - 0.11, "iron": True})
        for k in range(7):
            f["rivets"].append({"side": 1, "x": xa + 0.2 + k * (2 * HW - 0.4) / 6, "y": cy - HH + 0.23})
        # the pull at hand height near the meeting edge
        f["grips"].append({"side": 1, "x": cx + meeting * (HW - 0.17), "y": [cy - 1.05, cy + 0.25]})
        f["doorEdges"].append({"side": 1, "x": [xa, xb]})
    # boots against the kick plates
    f["steps"].append({"side": 1, "x": [-2 * HW, 2 * HW], "y": -1.2})
    return f


def move(ob, d):
    ob.location = ob.location + V(*d)


if MODE == "car":
    out, blend = args[1], args[2]
    # every other kit piece moves well clear along X, so no piece shades another in the AO bake
    others = sorted(ob.name for ob in bpy.data.objects if ob.type == "MESH" and ob.name not in POSE and not ob.hide_render)
    for name in list(POSE) + others:
        ob = bpy.data.objects[name]
        if name in POSE:
            x, y, z = POSE[name]
            c = ob.location
            here = (c.x, c.z, -c.y)  # Roblox
            d = (x - here[0], y - here[1], z - here[2])
        else:
            d = (30.0 * (others.index(name) + 1), 0.0, 0.0)
        move(ob, d)
        ob["pose"] = list(d)
    spec = {"name": "Doors", "x0": -2 * HW, "x1": 2 * HW, "feat": leaf_features()}
    json.dump({"car": "Doors", "spec": spec}, open(os.path.join(out, "Doors.json"), "w"), indent=1)
    kj = os.path.join(out, "Kit.json")
    meta = json.load(open(kj))
    meta["spec"] = {"name": "Kit", "x0": -4.0, "x1": 4.0, "feat": {}}
    json.dump(meta, open(kj, "w"), indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
else:
    blend = args[1]
    for ob in bpy.data.objects:
        d = ob.get("pose")
        if d:
            move(ob, [-v for v in d])
            del ob["pose"]
    bpy.ops.wm.save_as_mainfile(filepath=blend)
print("DONE kitpose", MODE)
