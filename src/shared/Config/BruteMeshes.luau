--!strict
--[[
	Close-up meshes for the Brute (tools/brute/build.py, out/brute_<name>.fbx and .png), to be uploaded under the
	owner's account. Same rules as Config/StalkerMeshes: `size` is the mesh's box in studs, `center` where that
	box's middle sits in the frame of the part it is welded to, `id` the mesh and `texture` its colour image.
	A row with no id leaves the block build in place, and the blocks stay as the Performance setting's version.
	`eyes` and `embers` are drawn in Neon (no texture). The arm and leg pieces are one per side (L, R).
	Nothing is drawn while Tuning.BruteRemake.Enabled is off, ids or not.
	Sizes for the 12-stud skeleton (Config/BruteBody Giant), from tools/brute/out-giant/report.json (26254 triangles for the whole figure).
]]

local StalkerMeshes = require(script.Parent.StalkerMeshes)
local Tuning = require(script.Parent.Tuning)

local BruteMeshes: { [string]: StalkerMeshes.Piece } = {
	head = { size = { 1.385, 1.678, 1.984 }, center = { -0.014, -0.192, 0.368 } },
	jaw = { size = { 0.835, 0.427, 0.649 }, center = { 0.003, 0.07, 0.196 } },
	eyes = { size = { 0.509, 0.507, 0.311 }, center = { -0.001, -0.51, -0.138 } },
	torso = { size = { 3.894, 4.939, 2.919 }, center = { -0.017, 0.298, 0.113 } },
	embers = { size = { 1.316, 3.448, 1.797 }, center = { -0.897, 0.728, 0.398 } },
	apron = { size = { 3.02, 3.692, 2.406 }, center = { 0.051, -0.918, -0.071 } },
	upperarmL = { size = { 2.279, 1.011, 1.406 }, center = { -0.014, -0.09, 0.255 } },
	upperarmR = { size = { 2.648, 1.298, 1.694 }, center = { 0.027, 0.107, 0.208 } },
	forearmL = { size = { 2.128, 0.879, 0.881 }, center = { 0.093, -0.023, 0.007 } },
	forearmR = { size = { 2.582, 1.232, 1.29 }, center = { 0.112, 0.053, 0.182 } },
	fist = { size = { 1.363, 1.873, 1.044 }, center = { 0.196, 0.032, -0.348 } },
	shovel = { size = { 3.558, 5.573, 3.761 }, center = { 0.78, -1.782, -1.364 } },
	thighL = { size = { 2.338, 1.427, 1.874 }, center = { -0.191, -0.015, -0.064 } },
	thighR = { size = { 2.453, 2.041, 1.949 }, center = { -0.137, 0.208, 0.015 } },
	shinL = { size = { 2.831, 1.28, 1.498 }, center = { 0.091, 0.026, 0.192 } },
	shinR = { size = { 2.853, 1.056, 1.643 }, center = { 0.101, 0.161, 0.1 } },
	bootL = { size = { 1.156, 0.949, 2.427 }, center = { -0.474, 0.019, -0.61 } },
	bootR = { size = { 1.323, 0.966, 2.375 }, center = { 0.011, 0.06, -0.729 } },
}

if not Tuning.BruteRemake.Enabled then
	for _, piece in BruteMeshes do
		piece.id = nil
	end
end

return BruteMeshes
