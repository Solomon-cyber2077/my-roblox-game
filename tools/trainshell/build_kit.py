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
pieces = kitparts.door_leaf("DoorLeafL", 1) + kitparts.door_leaf("DoorLeafR", -1) + kitparts.bogie("Bogie") + kitparts.wheel("Wheel")
objs = kit.assemble(
    col,
    pieces,
    {
        "DoorLeafL": ["DoorLeafL_iron", "DoorLeafL_brass"],
        "DoorLeafR": ["DoorLeafR_iron", "DoorLeafR_brass"],
        "Wheel": ["Wheel_teak"],
    },
)
meta = {"car": "Kit", "parts": kit.describe(objs)}
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "Kit.blend"))
json.dump(meta, open(os.path.join(out, "Kit.json"), "w"), indent=1)
