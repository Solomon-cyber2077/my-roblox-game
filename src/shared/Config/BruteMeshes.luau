--!strict
--[[
	Close-up meshes for the Brute (tools/brute/build.py, out/brute_<name>.fbx and .png), to be uploaded under the
	owner's account. Same rules as Config/StalkerMeshes: `size` is the mesh's box in studs, `center` where that
	box's middle sits in the frame of the part it is welded to, `id` the mesh and `texture` its colour image.
	A row with no id leaves the block build in place, and the blocks stay as the Performance setting's version.
	`eyes` and `embers` are drawn in Neon (no texture). The arm and leg pieces are one per side (L, R).
	Nothing is drawn while Tuning.BruteRemake.Enabled is off, ids or not.
	Sizes for the 12-stud skeleton (Config/BruteBody Giant), from the scan rebuild's out-scan/report.json (round 5, 2026-11-19, 23082 triangles for the whole figure).
]]

local StalkerMeshes = require(script.Parent.StalkerMeshes)
local Tuning = require(script.Parent.Tuning)

local BruteMeshes: { [string]: StalkerMeshes.Piece } = {
	head = { size = { 1.42, 1.783, 2.045 }, center = { -0.003, -0.141, 0.337 } },
	jaw = { size = { 0.877, 0.443, 0.648 }, center = { 0, 0.078, 0.196 } },
	eyes = { size = { 0.521, 0.055, 0.019 }, center = { -0, -0.443, -0.315 } },
	torso = { size = { 3.846, 4.939, 2.923 }, center = { 0.008, 0.298, 0.114 } },
	embers = { size = { 1.392, 3.448, 1.799 }, center = { -0.934, 0.728, 0.397 } },
	apron = { size = { 3.02, 4.257, 2.413 }, center = { 0.051, -1.2, -0.081 } },
	upperarmL = { size = { 2.706, 1.023, 1.433 }, center = { -0.038, -0.064, 0.235 } },
	upperarmR = { size = { 2.626, 1.326, 1.721 }, center = { 0.015, 0.105, 0.205 } },
	forearmL = { size = { 2.563, 0.883, 0.889 }, center = { 0.106, -0.03, 0.014 } },
	forearmR = { size = { 2.651, 1.234, 1.302 }, center = { 0.123, 0.036, 0.179 } },
	fist = { size = { 1.358, 1.953, 1.053 }, center = { 0.199, 0.118, -0.342 } },
	shovel = { size = { 2.392, 5.954, 2.044 }, center = { 0.173, -1.972, -0.506 } },
	thighL = { size = { 2.413, 1.497, 1.802 }, center = { -0.153, 0.005, -0.015 } },
	thighR = { size = { 2.506, 2.052, 1.911 }, center = { -0.111, 0.202, 0.004 } },
	shinL = { size = { 2.831, 1.296, 1.507 }, center = { 0.091, 0.034, 0.197 } },
	shinR = { size = { 2.853, 1.096, 1.65 }, center = { 0.101, 0.169, 0.104 } },
	bootL = { size = { 1.195, 0.961, 2.436 }, center = { -0.485, 0.011, -0.597 } },
	bootR = { size = { 1.37, 0.982, 2.395 }, center = { -0.003, 0.055, -0.713 } },
}

if not Tuning.BruteRemake.Enabled then
	for _, piece in BruteMeshes do
		piece.id = nil
	end
end

return BruteMeshes
