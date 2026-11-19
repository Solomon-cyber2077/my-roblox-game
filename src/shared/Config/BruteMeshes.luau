--!strict
--[[
	Close-up meshes for the Brute (tools/brute/build.py, out/brute_<name>.fbx and .png), to be uploaded under the
	owner's account. Same rules as Config/StalkerMeshes: `size` is the mesh's box in studs, `center` where that
	box's middle sits in the frame of the part it is welded to, `id` the mesh and `texture` its colour image.
	A row with no id leaves the block build in place, and the blocks stay as the Performance setting's version.
	`eyes` and `embers` are drawn in Neon (no texture). The arm and leg pieces are one per side (L, R).
	Nothing is drawn while Tuning.BruteRemake.Enabled is off, ids or not.
	Sizes for the 12-stud skeleton (Config/BruteBody Giant), from tools/brute/out-giant/report.json (19979 triangles for the whole figure).
]]

local StalkerMeshes = require(script.Parent.StalkerMeshes)
local Tuning = require(script.Parent.Tuning)

local BruteMeshes: { [string]: StalkerMeshes.Piece } = {
	head = { size = { 1.239, 2.198, 1.562 }, center = { 0.007, -0.688, -0.06 } },
	jaw = { size = { 0.991, 0.53, 0.82 }, center = { 0.001, 0.073, -0.146 } },
	eyes = { size = { 0.546, 0.056, 0.024 }, center = { 0.001, -0.093, -0.576 } },
	torso = { size = { 3.662, 4.128, 2.458 }, center = { 0.121, 0.265, -0.081 } },
	embers = { size = { 2.737, 1.92, 1.877 }, center = { -0.012, 0.154, 0.157 } },
	apron = { size = { 2.497, 3.545, 2.356 }, center = { 0.002, -0.834, -0.156 } },
	upperarmL = { size = { 3.031, 0.922, 1.005 }, center = { 0.082, 0.014, 0.038 } },
	upperarmR = { size = { 3.07, 1.261, 1.371 }, center = { 0.086, -0.011, 0.044 } },
	forearmL = { size = { 2.778, 0.895, 0.873 }, center = { 0.075, 0.005, -0.032 } },
	forearmR = { size = { 2.806, 1.245, 1.22 }, center = { 0.08, -0.005, -0.041 } },
	fist = { size = { 0.62, 1.567, 0.87 }, center = { 0.012, 0.007, -0.069 } },
	shovel = { size = { 1.879, 4.839, 0.578 }, center = { 0, -1.883, -0.043 } },
	thighL = { size = { 3.917, 1.352, 1.344 }, center = { 0.096, -0.004, -0.025 } },
	thighR = { size = { 3.917, 1.341, 1.352 }, center = { 0.096, -0.001, -0.028 } },
	shinL = { size = { 3.648, 1.337, 1.248 }, center = { 0.047, 0.049, 0.002 } },
	shinR = { size = { 3.656, 1.316, 1.244 }, center = { 0.043, -0.032, -0.001 } },
	bootL = { size = { 0.962, 1.381, 1.686 }, center = { 0.001, 0.311, -0.095 } },
	bootR = { size = { 0.966, 1.381, 1.686 }, center = { -0.001, 0.311, -0.095 } },
}

if not Tuning.BruteRemake.Enabled then
	for _, piece in BruteMeshes do
		piece.id = nil
	end
end

return BruteMeshes
