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
		perf = 101862149749225,
		perfTexture = 102024037017653,
		perfSize = { 1.343, 1.573, 1.793 },
		perfCenter = { -0.021, -0.151, 0.288 },
	},
	jaw = {
		id = 83405252182393,
		texture = 100474934958559,
		size = { 0.835, 0.427, 0.649 },
		center = { 0.003, 0.07, 0.196 },
		perf = 108298195895696,
		perfTexture = 102024037017653,
		perfSize = { 0.739, 0.331, 0.579 },
		perfCenter = { 0.004, 0.017, 0.159 },
	},
	eyes = { id = 136875542969797, size = { 0.509, 0.507, 0.311 }, center = { -0.001, -0.51, -0.138 } },
	torso = {
		id = 139617947773171,
		texture = 91206612995880,
		size = { 3.876, 4.939, 2.92 },
		center = { -0.008, 0.298, 0.113 },
		perf = 91409071023170,
		perfTexture = 102024037017653,
		perfSize = { 3.843, 4.935, 2.925 },
		perfCenter = { 0.023, 0.311, 0.124 },
	},
	embers = { id = 92198730698781, size = { 1.304, 3.448, 1.8 }, center = { -0.89, 0.728, 0.397 } },
	apron = {
		id = 134223284576320,
		texture = 106631428583111,
		size = { 3.02, 3.692, 2.406 },
		center = { 0.051, -0.918, -0.071 },
		perf = 119439462860382,
		perfTexture = 102024037017653,
		perfSize = { 3.02, 3.787, 2.34 },
		perfCenter = { 0.051, -0.966, -0.079 },
	},
	upperarmL = {
		id = 71347529758939,
		texture = 79965152164930,
		size = { 2.129, 0.989, 1.396 },
		center = { -0.012, -0.07, 0.251 },
		perf = 80338344112767,
		perfTexture = 102024037017653,
		perfSize = { 1.95, 0.896, 1.262 },
		perfCenter = { -0.102, -0.033, 0.166 },
	},
	upperarmR = {
		id = 87558972480807,
		texture = 114468369039257,
		size = { 2.648, 1.298, 1.694 },
		center = { 0.027, 0.107, 0.208 },
		perf = 136787747977842,
		perfTexture = 102024037017653,
		perfSize = { 2.519, 1.199, 1.621 },
		perfCenter = { -0.035, 0.077, 0.222 },
	},
	forearmL = {
		id = 98962139738914,
		texture = 104523700336836,
		size = { 1.977, 0.886, 0.881 },
		center = { 0.083, -0.023, 0.009 },
		perf = 79403841214508,
		perfTexture = 102024037017653,
		perfSize = { 1.929, 0.876, 0.871 },
		perfCenter = { 0.052, -0.015, 0.013 },
	},
	forearmR = {
		id = 106452956563559,
		texture = 98207864761813,
		size = { 2.582, 1.232, 1.29 },
		center = { 0.112, 0.053, 0.182 },
		perf = 108024114281608,
		perfTexture = 102024037017653,
		perfSize = { 2.514, 1.194, 1.279 },
		perfCenter = { 0.096, 0.033, 0.183 },
	},
	fist = {
		id = 102453216977675,
		texture = 103069387758732,
		size = { 1.6, 1.871, 0.953 },
		center = { 0.079, 0.011, -0.302 },
		perf = 78248645223007,
		perfTexture = 102024037017653,
		perfSize = { 1.569, 1.965, 0.933 },
		perfCenter = { 0.076, 0.063, -0.279 },
	},
	shovel = {
		id = 123647108809173,
		texture = 73155662864170,
		size = { 3.642, 5.519, 3.763 },
		center = { 0.822, -1.755, -1.365 },
		perf = 93349497302670,
		perfTexture = 102024037017653,
		perfSize = { 3.632, 5.502, 3.757 },
		perfCenter = { 0.817, -1.747, -1.363 },
	},
	thighL = {
		id = 89474226889725,
		texture = 134399586913719,
		size = { 2.338, 1.427, 1.874 },
		center = { -0.191, -0.015, -0.064 },
		perf = 122428318864209,
		perfTexture = 102024037017653,
		perfSize = { 2.264, 1.362, 1.777 },
		perfCenter = { -0.227, -0.048, -0.021 },
	},
	thighR = {
		id = 123428100997654,
		texture = 126759719098886,
		size = { 2.453, 2.041, 1.949 },
		center = { -0.137, 0.208, 0.015 },
		perf = 133830527057413,
		perfTexture = 102024037017653,
		perfSize = { 2.214, 1.673, 1.746 },
		perfCenter = { -0.256, 0.392, 0.015 },
	},
	shinL = {
		id = 130918455485780,
		texture = 105435520364594,
		size = { 2.831, 1.28, 1.498 },
		center = { 0.091, 0.026, 0.192 },
		perf = 115964545427455,
		perfTexture = 102024037017653,
		perfSize = { 2.69, 1.25, 1.449 },
		perfCenter = { 0.039, 0.031, 0.158 },
	},
	shinR = {
		id = 74486277074286,
		texture = 90562658515971,
		size = { 2.853, 1.056, 1.643 },
		center = { 0.101, 0.161, 0.1 },
		perf = 82941524754779,
		perfTexture = 102024037017653,
		perfSize = { 2.715, 0.986, 1.654 },
		perfCenter = { 0.064, 0.158, 0.08 },
	},
	bootL = {
		id = 91018611712434,
		texture = 88066109316746,
		size = { 1.156, 0.949, 2.427 },
		center = { -0.474, 0.019, -0.61 },
		perf = 110341651193486,
		perfTexture = 102024037017653,
		perfSize = { 1.05, 0.902, 2.393 },
		perfCenter = { -0.48, 0.002, -0.623 },
	},
	bootR = {
		id = 126873086847620,
		texture = 84594300304800,
		size = { 1.323, 0.966, 2.375 },
		center = { 0.011, 0.06, -0.729 },
		perf = 71808461797663,
		perfTexture = 102024037017653,
		perfSize = { 1.167, 0.911, 2.341 },
		perfCenter = { -0.007, 0.034, -0.736 },
	},
}

if not Tuning.BruteRemake.Enabled then
	for _, piece in BruteMeshes do
		piece.id = nil
	end
end

return BruteMeshes
