"""
Builds the shared kit (door leaves, bogie, wheel):

  blender -b --factory-startup -P tools/trainshell/build_kit.py -- <out_dir>
"""

import json
import os
import sys

import bpy


sys.path.insert(0, os.path.dirname(__file__))
import kit  # noqa: E402
import kitparts  # noqa: E402

out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
col = bpy.data.collections.new("Kit")
bpy.context.scene.collection.children.link(col)
V2 = "--v1" not in sys.argv
joins = {
    "DoorLeafL": ["DoorLeafL_iron", "DoorLeafL_brass"],
    "DoorLeafR": ["DoorLeafR_iron", "DoorLeafR_brass"],
    "Wheel": ["Wheel_teak"],
}
if V2 and "--r2" not in sys.argv:
    # round 3: a slimmer Mansell wheel, and the locomotive's driving wheels, coupling rods and the
    # tender's coal heap (mirrored pairs: the platform side's outer face is local -X / +Z)
    pieces = kitparts.door_leaf2("DoorLeafL", 1) + kitparts.door_leaf2("DoorLeafR", -1) + kitparts.bogie2("Bogie") + kitparts.wheel3("Wheel")
    pieces += kitparts.drive_wheel("DriveWheelP") + kitparts.mirror(kitparts.drive_wheel("DriveWheelN"), "x")
    pieces += kitparts.coupling_rod("RodP") + kitparts.mirror(kitparts.coupling_rod("RodN"), "z")
    pieces += kitparts.coal_lump("CoalLump")
    joins["DriveWheelP"] = ["DriveWheelP_paint"]
    joins["DriveWheelN"] = ["DriveWheelN_paint"]
    joins["RodP"] = ["RodP_brass"]
    joins["RodN"] = ["RodN_brass"]
elif V2:
    # round 2: framed and braced leaves with hinges and flush pulls; a lighter bogie
    pieces = kitparts.door_leaf2("DoorLeafL", 1) + kitparts.door_leaf2("DoorLeafR", -1) + kitparts.bogie2("Bogie") + kitparts.wheel("Wheel")
else:
    pieces = kitparts.door_leaf("DoorLeafL", 1) + kitparts.door_leaf("DoorLeafR", -1) + kitparts.bogie("Bogie") + kitparts.wheel("Wheel")
objs = kit.assemble(col, pieces, joins)
# the leaves get an atlas of their own (a SurfaceAppearance map is capped at 1024)
for key, ob in objs.items():
    ob["atlas"] = "Doors" if V2 and key.startswith("DoorLeaf") else "Kit"
meta = {"car": "Kit", "parts": kit.describe(objs)}
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "Kit.blend"))
json.dump(meta, open(os.path.join(out, "Kit.json"), "w"), indent=1)
