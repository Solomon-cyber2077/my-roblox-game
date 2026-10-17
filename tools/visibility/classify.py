"""
Mechanical tiers for the must-see gate, from the exported station data (no hand labels):

    python -I tools/visibility/classify.py <vis.json> [tools/visibility/tiers.json]

render.py imports `classify(station)` so the gate always judges the tiers of the data it
renders; the saved tiers.json is the committed record of what that was.

  Tier A, hazards: a station part whose top is walk level and which has a side where the
    ground beside it is lower by at least STEP_LIP (a drop-off to the track, a step, a gap).
    The coping is one; its lip is the drop. Measured only within LIP studs of that side.
  Tier B, obstacles: any collidable part that rises above a walk-level surface beside it
    by more than thresholds.STEP and starts below that surface + thresholds.HEAD (crates,
    barrels, posts, wall bases, the train's platform-facing side). Judged per model.
  Tier C: everything else (decor, non-colliding), counted only.

Approximations: footprints are axis-aligned boxes of each part (rotated parts are boxed),
on a CELL-stud grid; walk level is any collidable top inside WALK (the platform is y 0).
"""

import json
import math
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import thresholds as T  # noqa: E402

CELL = 0.5  # studs per grid cell
WALK = (-0.75, T.STEP)  # walk-level tops (studs, platform top = 0): reached without climbing
GAP = 0.25  # studs: seams between paving slabs narrower than twice this are closed
STEP_LIP = 0.25  # a height change a foot can catch on: lower than this is flat
LIP = 1.0  # studs: how far from a hazard's lip its pixels are judged


def aabb(p):
    r = p["r"]
    half = [p["z"][0] / 2, p["z"][1] / 2, p["z"][2] / 2]
    ext = [abs(r[i]) * half[0] + abs(r[3 + i]) * half[1] + abs(r[6 + i]) * half[2] for i in range(3)]
    return [p["p"][i] - ext[i] for i in range(3)], [p["p"][i] + ext[i] for i in range(3)]


def family(group):
    if group.startswith("Train/"):
        return "train side"
    return re.sub(r"(_\d+)?#\d+$", "", group)


def classify(st, edge_z):
    global EDGE_Z
    EDGE_Z = edge_z
    parts = st["parts"]
    boxes = [aabb(p) for p in parts]
    xs = [b[0][0] for b in boxes] + [b[1][0] for b in boxes]
    zs = [b[0][2] for b in boxes] + [b[1][2] for b in boxes]
    x0, z0 = min(xs) - 2, min(zs) - 2
    nx, nz = int((max(xs) + 2 - x0) / CELL) + 1, int((max(zs) + 2 - z0) / CELL) + 1
    height = np.full((nx, nz), -np.inf)  # the highest walk-level collidable top per cell

    def cells(lo, hi):
        i0, i1 = int(math.floor((lo[0] - x0) / CELL + 0.5)), int(math.floor((hi[0] - x0) / CELL + 0.5))
        k0, k1 = int(math.floor((lo[2] - z0) / CELL + 0.5)), int(math.floor((hi[2] - z0) / CELL + 0.5))
        return max(i0, 0), min(max(i1, i0 + 1), nx), max(k0, 0), min(max(k1, k0 + 1), nz)

    for p, (lo, hi) in zip(parts, boxes):
        if p["col"] and hi[1] <= WALK[1]:
            i0, i1, k0, k1 = cells([lo[0] - GAP, 0, lo[2] - GAP], [hi[0] + GAP, 0, hi[2] + GAP])
            np.maximum(height[i0:i1, k0:k1], hi[1], out=height[i0:i1, k0:k1])

    def ring(lo, hi, out):
        """Heights of the cells `out` studs beyond each side: {side: array}."""
        i0, i1, k0, k1 = cells(lo, hi)
        d = max(1, int(round(out / CELL)))
        sides = {}
        if i0 - d >= 0:
            sides["-x"] = height[i0 - d, k0:k1]
        if i1 - 1 + d < nx:
            sides["+x"] = height[i1 - 1 + d, k0:k1]
        if k0 - d >= 0:
            sides["-z"] = height[i0:i1, k0 - d]
        if k1 - 1 + d < nz:
            sides["+z"] = height[i0:i1, k1 - 1 + d]
        # no surface at all: the track trench is a real gap; anywhere else the landscape
        # (not exported) carries on, so it is level ground
        for side, h in sides.items():
            k = {"-x": k0, "+x": k0, "-z": k0 - d, "+z": k1 - 1 + d}[side]
            if z0 + k * CELL > EDGE_Z + 2:
                sides[side] = np.where(np.isfinite(h), h, hi[1])
        return sides

    tier_a, tier_b = {}, {}
    for i, (p, (lo, hi)) in enumerate(zip(parts, boxes)):
        if not p["col"]:
            continue
        top = hi[1]
        station = not p["g"].startswith("Train/")
        # Tier A: a walk-level top with a lower neighbour (drop, step or gap)
        if station and WALK[0] <= top <= WALK[1] and (hi[0] - lo[0]) >= CELL and (hi[2] - lo[2]) >= CELL:
            lips = []
            for side, h in ring(lo, hi, 2 * CELL).items():
                if h.size == 0:
                    continue
                drop = top - h  # -inf ground (a gap) is an infinite drop
                if (drop >= STEP_LIP).mean() >= 0.5:  # most of that side
                    if side in ("-x", "+x"):
                        x = lo[0] if side == "-x" else hi[0]
                        lips.append([x, lo[2], x, hi[2]])
                    else:
                        z = lo[2] if side == "-z" else hi[2]
                        lips.append([lo[0], z, hi[0], z])
                    worst = float(np.max(np.minimum(drop, 99)))
            if lips:
                near_edge = p["g"].startswith("Slab_") and lo[2] < EDGE_Z + 1.5
                name = "coping" if p.get("edge") else ("platform face" if near_edge else family(p["g"]) + " edge")
                kind = "drop" if worst >= T.STEP else "step"
                tier_a[i] = {"family": name, "kind": kind, "lips": [[round(v, 2) for v in s] for s in lips]}
                continue
        # Tier B: rises above the walk surface beside it, within a body's height of it
        walk = [h[np.isfinite(h) & (h >= WALK[0]) & (h <= WALK[1])] for h in ring(lo, hi, CELL).values()]
        walk = np.concatenate(walk) if walk else np.array([])
        if walk.size and np.any((top > walk + T.STEP) & (lo[1] < walk + T.HEAD)):
            fam = family(p["g"])
            if fam == "train side" and hi[2] < EDGE_Z - 1.5:
                fam = "train interior"  # inside the carriages, off the platform side
            if tier_b.get(p["g"]) in (None, "train interior"):
                tier_b[p["g"]] = fam
    groups = {p["g"] for p in parts}
    tier_c = sorted(groups - set(tier_b) - {parts[i]["g"] for i in tier_a})
    return {"A": tier_a, "B": tier_b, "C": tier_c}


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "tiers.json")
    with open(src, encoding="utf-8") as fh:
        data = json.load(fh)
    record = {"seed": data["seed"], "cell": CELL, "walk": WALK, "stepLip": STEP_LIP, "lip": LIP,
              "step": T.STEP, "head": T.HEAD, "stations": {}}
    for st in data["stations"]:
        tiers = classify(st, data["edgeZ"])
        fams_a, fams_b = {}, {}
        for v in tiers["A"].values():
            fams_a[v["family"]] = fams_a.get(v["family"], 0) + 1
        for v in tiers["B"].values():
            fams_b[v] = fams_b.get(v, 0) + 1
        record["stations"][st["id"]] = {
            "A": {str(k): v for k, v in sorted(tiers["A"].items())},
            "B": dict(sorted(tiers["B"].items())),
            "C": len(tiers["C"]),
            "families": {"A": dict(sorted(fams_a.items())), "B": dict(sorted(fams_b.items()))},
        }
        print(st["id"], "A parts", len(tiers["A"]), fams_a)
        print("   B models", len(tiers["B"]), dict(sorted(fams_b.items())), "C", len(tiers["C"]))
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(record, fh, indent=1)
    print("->", out)


if __name__ == "__main__":
    main()
