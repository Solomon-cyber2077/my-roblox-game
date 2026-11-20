"""Write Config/BruteMeshes.luau from out/report.json: python meshes_luau.py <path to BruteMeshes.luau>"""
import json
import sys
from pathlib import Path

rep = json.loads(Path(sys.argv[2] if len(sys.argv) > 2 else Path(__file__).resolve().parent.parent / "out" / "report.json").read_text())
order = ["head", "jaw", "eyes", "torso", "embers", "apron", "upperarmL", "upperarmR", "forearmL", "forearmR", "fist",
         "shovel", "thighL", "thighR", "shinL", "shinR", "bootL", "bootR"]


def n(v):
    return ", ".join(f"{x:g}" for x in v)


rows = []
for k in order:
    r = rep["brute_" + k]
    rows.append(f"\t{k} = {{ size = {{ {n(r['size'])} }}, center = {{ {n(r['center'])} }} }},")
src = f"""--!strict
--[[
	Close-up meshes for the Brute (tools/brute/build.py, out/brute_<name>.fbx and .png), to be uploaded under the
	owner's account. Same rules as Config/StalkerMeshes: `size` is the mesh's box in studs, `center` where that
	box's middle sits in the frame of the part it is welded to, `id` the mesh and `texture` its colour image.
	A row with no id leaves the block build in place, and the blocks stay as the Performance setting's version.
	`eyes` and `embers` are drawn in Neon (no texture). The arm and leg pieces are one per side (L, R).
	Nothing is drawn while Tuning.BruteRemake.Enabled is off, ids or not.
	Sizes for the 12-stud skeleton (Config/BruteBody Giant), from tools/brute/out-giant/report.json ({rep['figure_tris']} triangles for the whole figure).
]]

local StalkerMeshes = require(script.Parent.StalkerMeshes)
local Tuning = require(script.Parent.Tuning)

local BruteMeshes: {{ [string]: StalkerMeshes.Piece }} = {{
{chr(10).join(rows)}
}}

if not Tuning.BruteRemake.Enabled then
	for _, piece in BruteMeshes do
		piece.id = nil
	end
end

return BruteMeshes
"""
Path(sys.argv[1]).write_text(src, encoding="utf-8", newline="\n")
print("wrote", sys.argv[1])
