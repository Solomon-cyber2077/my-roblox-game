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
		id = 86223002155840,
		texture = 76768072324317,
		size = { 1.889, 3.006, 1.076 },
		center = { -0.008, 0.099, 0.042 },
		perf = 70854355902361,
		perfTexture = 85684252581187,
		perfSize = { 1.88, 3.007, 1.078 },
		perfCenter = { 0.001, 0.098, 0.051 },
	},
	coat = {
		id = 101736348584968,
		texture = 74287727162863,
		size = { 2.274, 4.263, 1.593 },
		center = { 0, -1.781, 0.125 },
		perf = 112298926010383,
		perfTexture = 73139482025721,
		perfSize = { 2.295, 4.264, 1.608 },
		perfCenter = { 0.011, -1.781, 0.133 },
	},
	sleeve = {
		id = 135111111727063,
		texture = 99444660649735,
		size = { 2.9, 0.426, 0.443 },
		center = { 0, 0, 0 },
		perf = 81789750083232,
		perfTexture = 76448141662289,
		perfSize = { 2.9, 0.426, 0.451 },
		perfCenter = { 0, 0, 0 },
	},
	forearm = {
		id = 104798188745457,
		texture = 134664391499905,
		size = { 2.75, 0.351, 0.348 },
		center = { 0, 0.004, 0.01 },
		perf = 107007800953665,
		perfTexture = 123454093984625,
		perfSize = { 2.75, 0.355, 0.355 },
		perfCenter = { 0, 0.001, 0.011 },
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
}

-- On: the 11-20 rebuild passed review. Set this to false to put every Stalker back on its block build.
local ENABLED = true
if not ENABLED then
	for _, piece in StalkerMeshes do
		piece.id = nil
	end
end

return StalkerMeshes
