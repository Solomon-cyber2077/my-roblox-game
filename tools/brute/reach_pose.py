"""The giant's Reach grab as a still: bent at the hips and back like a man reaching for something low, both
arms in through a station window (Config/Buildings: sill 3.4, top 8, width 4), a crew member hauled out to the
sill. The joint angles are the ones in Animation/HollowPoses (Reach, halfway through the hold).
  blender -b --python reach_pose.py -- --giant      -> ../renders/reach-outside.png, reach-inside.png"""

import math
import sys
from pathlib import Path

import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import b8lib as L  # noqa: E402
import build as B  # noqa: E402

A, T, G = L.A, L.T, B.G
deg = math.degrees
OUT = HERE.parent / "renders"
BS, k = 1.26, 0.5
ARMS = {"L": (-198, -25), "R": (-150, -18)}  # the fist reaches in; the shovel hand braces on the frame
if "--tell" in sys.argv:
    ARMS = {"L": (-150, -18), "R": (-150, -18)}


def posed():
    """frames_giant with the Reach pose's joint transforms (Part1 = Part0 * C0 * Transform * C1^-1)."""
    root = T(0, G["hip"] + G["root"][1] / 2, 0)
    pelvis = root @ T(*G["rootC0"]) @ T(0, -0.7 * BS, (0.55 + 0.25 * k) * BS) @ A(deg(-0.5 + 0.1 * k), 0, deg(0.04))
    chest = pelvis @ T(*G["waistC0"]) @ A(G["lean"]) @ A(deg(-0.65 + 0.15 * k)) @ T(*(-np.array(G["chestC1"])))
    head = chest @ T(*G["neckC0"]) @ A(G["neckTilt"]) @ A(deg(0.6)) @ T(*(-np.array(G["headC1"])))
    jaw = head @ T(*B.G_JAW_ORIGIN)
    f = {"pelvis": pelvis, "chest": chest, "head": head, "jaw": jaw}
    sx, sy, sz = G["shoulder"]
    hx, hy, hz = G["hipAt"]
    for side, s_ in (("L", -1), ("R", 1)):
        end_y = G["handL"] if side == "L" else G["handR"]
        f["upper" + side], f["fore" + side], f["hand" + side] = B.bone_frames(
            chest, T(s_ * sx, sy, sz) @ A(0, 0, -s_ * 8), G["upper"], G["fore"], end_y, ARMS[side])
        hip = deg(0.62 if side == "L" else 0.5)
        knee = deg(-0.45 if side == "L" else -0.35)
        f["thigh" + side], f["shin" + side], f["foot" + side] = B.bone_frames(
            pelvis, T(s_ * hx, hy, hz), G["thigh"], G["shin"], G["foot"], (hip, knee))
    return f


def wall(z):
    """A station wall with one window: sill 3.4, top 8, 4 wide; brick-coloured, 1 thick."""
    c = (0.33, 0.22, 0.18)
    L.prim("box", (10, 3.4, 1), T(0, 1.7, z), c)
    L.prim("box", (10, 6, 1), T(0, 11, z), c)
    for x in (-4, 4):
        L.prim("box", (6, 4.6, 1), T(x * 1.25, 5.7, z), c)
    L.prim("box", (4.4, 0.25, 1.3), T(0, 3.35, z), (0.5, 0.48, 0.44))  # sill


def victim(at):
    """A crew member held up under the arms at the sill."""
    x, y, z = at
    col = (0.30, 0.36, 0.44)
    out = []
    for size, off, rot in (((2, 2, 1), (0, 0, 0), 0), ((1, 2, 1), (-0.5, -2, 0.3), 12), ((1, 2, 1), (0.5, -2, 0.3), -8),
                           ((1, 2, 1), (-1.6, 0.6, 0), -150), ((1, 2, 1), (1.6, 0.6, 0), 150), ((1.2, 1.2, 1.2), (0, 1.6, 0), 0)):
        out.append(L.prim("box", size, T(x + off[0], y + off[1], z + off[2]) @ A(rot * 0.15, 0, rot), col))
    return out


def main():
    L.clear()
    pieces = B.import_old(L.OUT, [kk for kk in list(B.SPECS) + list(B.NEON)])
    f = posed()
    for name, frame in B.PLACES:
        o = pieces.get(name)
        if o is not None:
            c = o.get("centre", (0, 0, 0))
            L.place(o, f[frame] @ T(c[0], c[1], c[2]))
    hold = G["root"][1] / 2 + G["hip"]
    held = (0.3, hold - 2.6, -5.0)
    wall(-5.9)
    held_objs = [] if "--tell" in sys.argv else victim(held)
    L.prim("box", (40, 0.2, 40), T(0, -0.1, 0), (0.25, 0.25, 0.25))
    L.light("POINT", (f["chest"] @ T(0, 0.2, -1.6)).translation, 25, (1.0, 0.45, 0.15), size=0.4)
    # outside, from the side
    L.world((0.06, 0.07, 0.09), 1.0)
    L.light("SUN", Vector((4, 9, 6)), 2.0, (0.7, 0.78, 0.95), at_r=Vector((0, 4, -3)))
    L.light("POINT", Vector((3, 6, -9)), 300, (1.0, 0.65, 0.35), size=0.3)
    L.camera(Vector((14, 6.5, 2.0)), Vector((0, 5.0, -3.2)), fov=45)
    tag = "tell" if "--tell" in sys.argv else "reach"
    L.render(OUT / f"{tag}-outside.png", 1200, 1000, samples=32)
    # inside, the player's view: the window, its face and its arms coming through (the player is the camera)
    for o in held_objs:
        o.hide_render = True
    L.clear_lights()
    L.light("POINT", (f["chest"] @ T(0, 0.2, -1.6)).translation, 25, (1.0, 0.45, 0.15), size=0.4)
    L.world((0.03, 0.035, 0.05), 1.0)
    L.light("SUN", Vector((0, 9, 8)), 1.4, (0.55, 0.62, 0.85), at_r=Vector((0, 4, -4)))
    L.light("POINT", Vector((-2.5, 5.5, -12)), 220, (1.0, 0.62, 0.3), size=0.2)
    L.camera(Vector((-2.2, 4.4, -14.5)), Vector((0.2, 5.6, -5.0)), fov=50)
    L.render(OUT / f"{tag}-inside.png", 1200, 1000, samples=32)


main()
