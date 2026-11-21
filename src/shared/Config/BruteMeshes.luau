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
		id = 84934960681907,
		texture = 70566477812151,
		size = { 1.385, 1.664, 1.966 },
		center = { -0.014, -0.184, 0.358 },
		perf = 113422390384502,
		perfTexture = 81848806202252,
		perfSize = { 1.334, 1.572, 1.765 },
		perfCenter = { -0.02, -0.151, 0.267 },
	},
	jaw = {
		id = 80392066632478,
		texture = 114176753212872,
		size = { 0.804, 0.44, 0.62 },
		center = { 0.002, 0.077, 0.182 },
		perf = 110683352376645,
		perfTexture = 81848806202252,
		perfSize = { 0.744, 0.312, 0.616 },
		perfCenter = { -0.004, 0.012, 0.161 },
	},
	eyes = { id = 85539678782433, size = { 0.509, 0.508, 0.313 }, center = { -0.001, -0.51, -0.139 } },
	torso = {
		id = 95763423676331,
		texture = 120593481515108,
		size = { 3.73, 4.912, 2.919 },
		center = { 0.033, 0.311, 0.113 },
		perf = 107509340545118,
		perfTexture = 81848806202252,
		perfSize = { 3.68, 4.864, 2.925 },
		perfCenter = { 0.031, 0.346, 0.124 },
	},
	embers = { id = 125897149962116, size = { 1.159, 3.45, 1.8 }, center = { -0.813, 0.726, 0.397 } },
	apron = {
		id = 101462424087044,
		texture = 108434563714010,
		size = { 2.811, 3.959, 2.402 },
		center = { 0.034, -1.024, -0.075 },
		perf = 76433558603179,
		perfTexture = 81848806202252,
		perfSize = { 2.799, 3.9, 2.331 },
		perfCenter = { 0.041, -1.027, -0.074 },
	},
	upperarmL = {
		id = 103116925701060,
		texture = 76445351850028,
		size = { 2.093, 0.985, 1.237 },
		center = { 0.02, -0.057, 0.09 },
		perf = 76835195895161,
		perfTexture = 81848806202252,
		perfSize = { 2.028, 0.931, 1.106 },
		perfCenter = { 0.028, -0.018, 0.096 },
	},
	upperarmR = {
		id = 131044361782897,
		texture = 98955510175935,
		size = { 2.626, 1.329, 1.854 },
		center = { 0.013, 0.113, 0.126 },
		perf = 118450734411750,
		perfTexture = 81848806202252,
		perfSize = { 2.558, 1.175, 1.61 },
		perfCenter = { 0.012, 0.075, 0.207 },
	},
	forearmL = {
		id = 136974503773288,
		texture = 133238853812468,
		size = { 1.893, 0.889, 0.801 },
		center = { 0.118, -0.027, -0.033 },
		perf = 134043567916479,
		perfTexture = 81848806202252,
		perfSize = { 1.898, 0.888, 0.791 },
		perfCenter = { 0.099, -0.027, -0.037 },
	},
	forearmR = {
		id = 113352129479187,
		texture = 92056853571399,
		size = { 2.502, 1.199, 1.286 },
		center = { 0.146, 0.032, 0.186 },
		perf = 133807679428212,
		perfTexture = 81848806202252,
		perfSize = { 2.465, 1.14, 1.25 },
		perfCenter = { 0.107, 0.011, 0.182 },
	},
	fist = {
		id = 89862522778664,
		texture = 83128396681453,
		size = { 1.603, 1.883, 0.948 },
		center = { 0.078, 0.017, -0.307 },
		perf = 125617423235078,
		perfTexture = 81848806202252,
		perfSize = { 1.569, 1.921, 0.913 },
		perfCenter = { 0.076, 0.041, -0.289 },
	},
	shovel = {
		id = 94864893633338,
		texture = 115439809337775,
		size = { 3.641, 5.474, 3.735 },
		center = { 0.823, -1.782, -1.38 },
		perf = 106842444638328,
		perfTexture = 81848806202252,
		perfSize = { 3.633, 5.475, 3.73 },
		perfCenter = { 0.817, -1.778, -1.376 },
	},
	thighL = {
		id = 135784339599992,
		texture = 94215570548484,
		size = { 2.948, 1.352, 1.774 },
		center = { 0.176, 0.057, 0.028 },
		perf = 101444287438930,
		perfTexture = 81848806202252,
		perfSize = { 2.873, 1.336, 1.707 },
		perfCenter = { 0.11, 0.052, 0.002 },
	},
	thighR = {
		id = 121528038457953,
		texture = 98083171172987,
		size = { 2.921, 1.473, 1.838 },
		center = { 0.166, -0.117, 0.05 },
		perf = 135946082401099,
		perfTexture = 81848806202252,
		perfSize = { 2.755, 1.412, 1.837 },
		perfCenter = { 0.082, -0.086, 0.062 },
	},
	shinL = {
		id = 79765498377769,
		texture = 85178763659356,
		size = { 2.746, 1.259, 1.521 },
		center = { 0.087, 0.05, 0.179 },
		perf = 119388575696721,
		perfTexture = 81848806202252,
		perfSize = { 2.614, 1.193, 1.44 },
		perfCenter = { 0.057, 0.043, 0.2 },
	},
	shinR = {
		id = 89393990060315,
		texture = 112957134516985,
		size = { 2.74, 1.071, 1.69 },
		center = { 0.09, 0.168, 0.1 },
		perf = 120090025378652,
		perfTexture = 81848806202252,
		perfSize = { 2.621, 1.006, 1.629 },
		perfCenter = { 0.051, 0.167, 0.111 },
	},
	bootL = {
		id = 124756219959712,
		texture = 78167829069892,
		size = { 1.133, 0.927, 2.426 },
		center = { -0.486, 0.008, -0.61 },
		perf = 101380619556279,
		perfTexture = 81848806202252,
		perfSize = { 1.038, 0.896, 2.393 },
		perfCenter = { -0.487, -0.001, -0.623 },
	},
	bootR = {
		id = 88707685424135,
		texture = 70810271461946,
		size = { 1.323, 0.962, 2.375 },
		center = { 0.011, 0.058, -0.729 },
		perf = 135444068813432,
		perfTexture = 81848806202252,
		perfSize = { 1.167, 0.884, 2.341 },
		perfCenter = { -0.007, 0.021, -0.736 },
	},
}

if not Tuning.BruteRemake.Enabled then
	for _, piece in BruteMeshes do
		piece.id = nil
	end
end

return BruteMeshes
