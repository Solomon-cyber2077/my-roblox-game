--!strict
--[[
	Close-up meshes for the Stalker (tools/stalker/build.py, assets/stalker/*.fbx), uploaded under the
	owner's account. `size` is the mesh's box in studs and `center` where that box's middle sits in the
	frame of the part it is welded to (the head, a hand, a forearm bone, an upper-arm bone, the pelvis).
	`texture` is the colour image's id (tools/stalker/out/<name>.png, sRGB); without one the part keeps its flat
	colour. A mesh with no id yet leaves the block build in place (Builders/HollowBuilder); the blocks also
	stay as the Performance setting's lighter version.
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
		id = 136370457738629,
		texture = 129299439692086,
		size = { 0.807, 1.499, 1.061 },
		center = { -0.004, 0.049, -0.003 },
	},
	jaw = {
		id = 135718368796987,
		texture = 89978575412475,
		size = { 0.541, 0.362, 0.501 },
		center = { -0.001, 0.099, -0.05 },
	},
	torso = {
		id = 71264569548769,
		texture = 120459886516923,
		size = { 1.889, 3.006, 1.076 },
		center = { -0.008, 0.099, 0.042 },
	},
	coat = {
		id = 108380113004910,
		texture = 119369364077842,
		size = { 2.274, 4.263, 1.593 },
		center = { 0, -1.781, 0.125 },
	},
	sleeve = {
		id = 114040160893582,
		texture = 120717393588382,
		size = { 3.573, 0.426, 0.452 },
		center = { -0.336, 0, 0 },
	},
	forearm = {
		id = 135215404458869,
		texture = 106116602677876,
		size = { 2.75, 0.338, 0.304 },
		center = { 0, 0, 0.014 },
	},
	hand = {
		id = 92188242389961,
		texture = 76243631586705,
		size = { 0.53, 1.492, 0.635 },
		center = { 0.068, -0.495, -0.208 },
	},
	-- both hands share one colour image
	handL = {
		id = 116194316652302,
		texture = 76243631586705,
		size = { 0.53, 1.492, 0.635 },
		center = { -0.068, -0.495, -0.208 },
	},
}

-- Off: the close-up pieces stay out of the game until a rebuild passes review, so every Stalker keeps its
-- block build. The ids above are kept for that rebuild; set this to true to bring them back.
local ENABLED = false
if not ENABLED then
	for _, piece in StalkerMeshes do
		piece.id = nil
	end
end

return StalkerMeshes
