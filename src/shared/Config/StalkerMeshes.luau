--!strict
--[[
	Close-up meshes for the Stalker (tools/stalker/build.py, assets/stalker/*.fbx), uploaded under the
	owner's account. `size` is the mesh's box in studs and `center` where that box's middle sits in the
	frame of the part it is welded to (the head, a hand, a forearm bone, an upper-arm bone, the pelvis).
	`texture` is the colour image's id (tools/stalker/out/<name>.png, sRGB); without one the part keeps its flat
	colour. A mesh with no id yet leaves the block build in place (Builders/HollowBuilder); the blocks also
	stay as the Performance setting's lighter version, unless the piece has its own lighter `perf` mesh.
]]

export type Piece = {
	id: number?,
	texture: number?,
	size: { number },
	center: { number },
	-- a lighter mesh (and its colour image) drawn in this piece's place under Performance; with one, the
	-- piece's blocks are never drawn at all (Builders/HollowBuilder)
	perf: number?,
	perfTexture: number?,
	perfSize: { number }?, -- the lighter mesh's own box and centre, when they differ from the close-up one's
	perfCenter: { number }?,
}

local StalkerMeshes: { [string]: Piece } = {
	head = {
		id = 118041040690112,
		texture = 138576579037625,
		size = { 0.79, 1.554, 1.096 },
		center = { -0.011, 0.022, -0.026 },
		perf = 137807005369790,
		perfTexture = 112785085952315,
		perfSize = { 0.74, 1.548, 1.101 },
		perfCenter = { 0.013, 0.018, -0.023 },
	},
	jaw = {
		id = 115341817124769,
		texture = 126782591064875,
		size = { 0.447, 0.388, 0.488 },
		center = { 0, 0.206, -0.068 },
		perf = 75314125633979,
		perfTexture = 136513793666145,
		perfSize = { 0.437, 0.393, 0.494 },
		perfCenter = { 0.004, 0.21, -0.061 },
	},
	torso = {
		id = 102236891740741,
		texture = 98276305606517,
		size = { 1.901, 3.008, 1.078 },
		center = { 0.001, 0.098, 0.038 },
		perf = 97115996559425,
		perfTexture = 85980093977352,
		perfSize = { 1.882, 3.008, 1.083 },
		perfCenter = { -0.008, 0.098, 0.044 },
	},
	coat = {
		id = 130178864493216,
		texture = 126544317308747,
		size = { 2.267, 4.222, 1.594 },
		center = { 0.001, -1.761, 0.138 },
		perf = 127925933969803,
		perfTexture = 78522078686140,
		perfSize = { 2.258, 4.222, 1.594 },
		perfCenter = { 0.005, -1.76, 0.138 },
	},
	sleeve = {
		id = 83138223174416,
		texture = 74552075972933,
		size = { 2.9, 0.423, 0.437 },
		center = { -0.0, 0.0, 0.0 },
		perf = 108751961181140,
		perfTexture = 124083291378262,
		perfSize = { 2.9, 0.401, 0.448 },
		perfCenter = { 0.0, 0.0, 0.0 },
	},
	forearm = {
		id = 115158916498776,
		texture = 89597958500374,
		size = { 2.75, 0.357, 0.35 },
		center = { -0.0, 0.004, 0.01 },
		perf = 89499378154468,
		perfTexture = 84041549751827,
		perfSize = { 2.751, 0.355, 0.353 },
		perfCenter = { -0.0, -0.001, 0.008 },
	},
	hand = {
		id = 108882756111997,
		texture = 102938202928120,
		size = { 0.53, 1.492, 0.635 },
		center = { 0.068, -0.495, -0.208 },
		perf = 92580323589048,
		perfTexture = 133626736513757,
		perfSize = { 0.524, 1.492, 0.636 },
		perfCenter = { 0.071, -0.495, -0.207 },
	},
	-- both hands share one colour image
	handL = {
		id = 130655414108648,
		texture = 102938202928120,
		size = { 0.53, 1.492, 0.635 },
		center = { -0.068, -0.495, -0.208 },
		perf = 138295751577269,
		perfTexture = 133626736513757,
		perfSize = { 0.524, 1.492, 0.636 },
		perfCenter = { -0.071, -0.495, -0.207 },
	},
	thigh = {
		id = 113401308247189,
		texture = 120863291098937,
		size = { 2.527, 0.873, 0.866 },
		center = { -0.113, -0.017, 0.027 },
		perf = 73798049284292,
		perfTexture = 76227177759939,
		perfSize = { 2.425, 0.888, 0.882 },
		perfCenter = { -0.068, -0.027, 0.029 },
	},
	shin = {
		id = 120902471423399,
		texture = 109691250481272,
		size = { 2.05, 0.366, 0.398 },
		center = { 0.02, -0.002, 0.004 },
		perf = 108525223781629,
		perfTexture = 120151661342905,
		perfSize = { 2.018, 0.37, 0.395 },
		perfCenter = { 0.036, -0.001, 0.003 },
	},
	shinL = {
		id = 75818758023930,
		texture = 78868097151448,
		size = { 2.05, 0.399, 0.406 },
		center = { 0.02, 0.015, 0.003 },
		perf = 122089567142105,
		perfTexture = 94696551321233,
		perfSize = { 2.044, 0.403, 0.433 },
		perfCenter = { 0.023, 0.013, 0.016 },
	},
	boot = {
		id = 108936894643384,
		texture = 137369386871807,
		size = { 0.315, 0.8, 0.914 },
		center = { -0.002, 0.255, -0.168 },
		perf = 95370480394238,
		perfTexture = 84867324958379,
		perfSize = { 0.315, 0.799, 0.911 },
		perfCenter = { 0.001, 0.255, -0.168 },
	},
	bootL = {
		id = 124725157238745,
		texture = 136068418693337,
		size = { 0.314, 0.8, 0.913 },
		center = { -0.002, 0.255, -0.167 },
		perf = 110878207801594,
		perfTexture = 80207949839965,
		perfSize = { 0.316, 0.8, 0.914 },
		perfCenter = { -0.001, 0.256, -0.17 },
	},
}

-- On: the 11-20 rebuild passed review. Set this to false to put every Stalker back on its block build.
local ENABLED = true
if not ENABLED then
	for _, piece in StalkerMeshes do
		piece.id = nil
	end
end

return StalkerMeshes
