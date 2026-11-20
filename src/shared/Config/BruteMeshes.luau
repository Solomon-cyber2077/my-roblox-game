--!strict
--[[
	Close-up meshes for the Brute (tools/brute/build.py, out/brute_<name>.fbx and .png), to be uploaded under the
	owner's account. Same rules as Config/StalkerMeshes: `size` is the mesh's box in studs, `center` where that
	box's middle sits in the frame of the part it is welded to, `id` the mesh and `texture` its colour image.
	A row with no id leaves the block build in place, and the blocks stay as the Performance setting's version.
	`eyes` and `embers` are drawn in Neon (no texture). The arm and leg pieces are one per side (L, R).
	Nothing is drawn while Tuning.BruteRemake.Enabled is off, ids or not.
	Sizes for the 12-stud skeleton (Config/BruteBody Giant), from tools/brute/out-giant/report.json (26253 triangles for the whole figure).
]]

local StalkerMeshes = require(script.Parent.StalkerMeshes)
local Tuning = require(script.Parent.Tuning)

local BruteMeshes: { [string]: StalkerMeshes.Piece } = {
	head = {
		id = 109426615865492,
		texture = 90153797429576,
		size = { 1.385, 1.678, 1.984 },
		center = { -0.014, -0.192, 0.368 },
		perf = 92126512355122,
		perfTexture = 117089571495787,
		perfSize = { 1.308, 1.57, 1.775 },
		perfCenter = { -0.038, -0.137, 0.259 },
	},
	jaw = {
		id = 83405252182393,
		texture = 100474934958559,
		size = { 0.835, 0.427, 0.649 },
		center = { 0.003, 0.07, 0.196 },
		perf = 107961753763499,
		perfTexture = 117089571495787,
		perfSize = { 0.675, 0.297, 0.533 },
		perfCenter = { 0.001, 0.002, 0.153 },
	},
	eyes = { id = 136875542969797, size = { 0.509, 0.507, 0.311 }, center = { -0.001, -0.51, -0.138 } },
	torso = {
		id = 139617947773171,
		texture = 91206612995880,
		size = { 3.876, 4.939, 2.92 },
		center = { -0.008, 0.298, 0.113 },
		perf = 101349663056522,
		perfTexture = 117089571495787,
		perfSize = { 3.747, 4.746, 2.834 },
		perfCenter = { 0.061, 0.393, 0.096 },
	},
	embers = { id = 92198730698781, size = { 1.304, 3.448, 1.8 }, center = { -0.89, 0.728, 0.397 } },
	apron = {
		id = 134223284576320,
		texture = 106631428583111,
		size = { 3.02, 3.692, 2.406 },
		center = { 0.051, -0.918, -0.071 },
		perf = 137790370693279,
		perfTexture = 117089571495787,
		perfSize = { 3.02, 3.501, 2.326 },
		perfCenter = { 0.051, -0.782, -0.062 },
	},
	upperarmL = {
		id = 71347529758939,
		texture = 79965152164930,
		size = { 2.129, 0.989, 1.396 },
		center = { -0.012, -0.07, 0.251 },
		perf = 118415136574960,
		perfTexture = 117089571495787,
		perfSize = { 0.66, 0.758, 0.864 },
		perfCenter = { -0.747, 0.036, -0.012 },
	},
	upperarmR = {
		id = 87558972480807,
		texture = 114468369039257,
		size = { 2.648, 1.298, 1.694 },
		center = { 0.027, 0.107, 0.208 },
		perf = 128763752946229,
		perfTexture = 117089571495787,
		perfSize = { 2.471, 1.147, 1.546 },
		perfCenter = { -0.062, 0.095, 0.221 },
	},
	forearmL = {
		id = 98962139738914,
		texture = 104523700336836,
		size = { 1.977, 0.886, 0.881 },
		center = { 0.083, -0.023, 0.009 },
		perf = 137611151695268,
		perfTexture = 117089571495787,
		perfSize = { 1.914, 0.875, 0.832 },
		perfCenter = { 0.058, -0.002, -0.009 },
	},
	forearmR = {
		id = 106452956563559,
		texture = 98207864761813,
		size = { 2.582, 1.232, 1.29 },
		center = { 0.112, 0.053, 0.182 },
		perf = 83542927312902,
		perfTexture = 117089571495787,
		perfSize = { 2.431, 1.121, 1.212 },
		perfCenter = { 0.055, -0.012, 0.187 },
	},
	fist = {
		id = 102453216977675,
		texture = 103069387758732,
		size = { 1.6, 1.871, 0.953 },
		center = { 0.079, 0.011, -0.302 },
		perf = 93721094040490,
		perfTexture = 117089571495787,
		perfSize = { 1.44, 1.903, 0.915 },
		perfCenter = { 0.073, 0.094, -0.27 },
	},
	shovel = {
		id = 123647108809173,
		texture = 73155662864170,
		size = { 3.642, 5.519, 3.763 },
		center = { 0.822, -1.755, -1.365 },
		perf = 87141809928523,
		perfTexture = 117089571495787,
		perfSize = { 3.489, 5.517, 3.757 },
		perfCenter = { 0.889, -1.739, -1.363 },
	},
	thighL = {
		id = 89474226889725,
		texture = 134399586913719,
		size = { 2.338, 1.427, 1.874 },
		center = { -0.191, -0.015, -0.064 },
		perf = 135632580436577,
		perfTexture = 117089571495787,
		perfSize = { 2.159, 0.99, 1.665 },
		perfCenter = { -0.237, -0.234, -0.077 },
	},
	thighR = {
		id = 123428100997654,
		texture = 126759719098886,
		size = { 2.453, 2.041, 1.949 },
		center = { -0.137, 0.208, 0.015 },
		perf = 83313813744463,
		perfTexture = 117089571495787,
		perfSize = { 2.214, 1.657, 1.746 },
		perfCenter = { -0.256, 0.4, 0.015 },
	},
	shinL = {
		id = 130918455485780,
		texture = 105435520364594,
		size = { 2.831, 1.28, 1.498 },
		center = { 0.091, 0.026, 0.192 },
		perf = 81879035461623,
		perfTexture = 117089571495787,
		perfSize = { 2.732, 1.192, 1.419 },
		perfCenter = { 0.062, 0.017, 0.138 },
	},
	shinR = {
		id = 74486277074286,
		texture = 90562658515971,
		size = { 2.853, 1.056, 1.643 },
		center = { 0.101, 0.161, 0.1 },
		perf = 113224568179653,
		perfTexture = 117089571495787,
		perfSize = { 2.699, 0.894, 1.596 },
		perfCenter = { 0.049, 0.162, 0.092 },
	},
	bootL = {
		id = 91018611712434,
		texture = 88066109316746,
		size = { 1.156, 0.949, 2.427 },
		center = { -0.474, 0.019, -0.61 },
		perf = 84660856138268,
		perfTexture = 117089571495787,
		perfSize = { 1.049, 0.892, 2.369 },
		perfCenter = { -0.482, 0.005, -0.611 },
	},
	bootR = {
		id = 126873086847620,
		texture = 84594300304800,
		size = { 1.323, 0.966, 2.375 },
		center = { 0.011, 0.06, -0.729 },
		perf = 78614338613758,
		perfTexture = 117089571495787,
		perfSize = { 1.129, 0.923, 2.312 },
		perfCenter = { -0.007, 0.037, -0.724 },
	},
}

if not Tuning.BruteRemake.Enabled then
	for _, piece in BruteMeshes do
		piece.id = nil
	end
end

return BruteMeshes
