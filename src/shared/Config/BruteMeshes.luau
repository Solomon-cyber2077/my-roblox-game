--!strict
--[[
	Close-up meshes for the Brute (tools/brute/build.py, out/brute_<name>.fbx and .png), to be uploaded under the
	owner's account. Same rules as Config/StalkerMeshes: `size` is the mesh's box in studs, `center` where that
	box's middle sits in the frame of the part it is welded to, `id` the mesh and `texture` its colour image.
	A row with no id leaves the block build in place, and the blocks stay as the Performance setting's version.
	`eyes` and `embers` are drawn in Neon (no texture). The arm and leg pieces are one per side (L, R).
	Nothing is drawn while Tuning.BruteRemake.Enabled is off, ids or not.
	Sizes for the 12-stud skeleton (Config/BruteBody Giant), from tools/brute/out-giant/report.json (19980 triangles for the whole figure).
]]

local StalkerMeshes = require(script.Parent.StalkerMeshes)
local Tuning = require(script.Parent.Tuning)

local BruteMeshes: { [string]: StalkerMeshes.Piece } = {
	head = { size = { 1.234, 2.199, 1.559 }, center = { 0.011, -0.69, -0.058 } },
	jaw = { size = { 0.99, 0.529, 0.817 }, center = { 0, 0.075, -0.144 } },
	eyes = { size = { 0.546, 0.056, 0.025 }, center = { 0.001, -0.093, -0.576 } },
	torso = { size = { 3.653, 4.125, 2.466 }, center = { 0.026, 0.264, -0.085 } },
	embers = { size = { 2.749, 1.917, 1.889 }, center = { -0.012, 0.154, 0.16 } },
	apron = { size = { 2.497, 3.545, 2.356 }, center = { 0.002, -0.834, -0.156 } },
	upperarmL = { size = { 3.036, 1.07, 1.167 }, center = { 0.085, 0.016, 0.045 } },
	upperarmR = { size = { 3.072, 1.115, 1.206 }, center = { 0.086, -0.006, 0.042 } },
	forearmL = { size = { 2.776, 1.036, 1.011 }, center = { 0.076, 0.005, -0.037 } },
	forearmR = { size = { 2.806, 1.074, 1.053 }, center = { 0.08, -0.005, -0.035 } },
	fist = { size = { 0.64, 1.367, 0.866 }, center = { 0.004, 0.106, -0.073 } },
	shovel = { size = { 1.879, 4.839, 0.578 }, center = { 0, -1.883, -0.043 } },
	thighL = { size = { 3.917, 1.352, 1.344 }, center = { 0.096, -0.004, -0.025 } },
	thighR = { size = { 3.917, 1.341, 1.352 }, center = { 0.096, -0.001, -0.028 } },
	shinL = { size = { 3.648, 1.337, 1.248 }, center = { 0.047, 0.049, 0.002 } },
	shinR = { size = { 3.648, 1.316, 1.272 }, center = { 0.047, -0.032, 0 } },
	bootL = { size = { 0.962, 1.381, 1.686 }, center = { 0.001, 0.311, -0.095 } },
	bootR = { size = { 0.966, 1.381, 1.686 }, center = { -0.001, 0.311, -0.095 } },
}

if not Tuning.BruteRemake.Enabled then
	for _, piece in BruteMeshes do
		piece.id = nil
	end
end

return BruteMeshes
