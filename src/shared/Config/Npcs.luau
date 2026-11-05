--!strict
--[[
	The train's residents. Everything about an NPC is data: who they are, where they
	stand, their quest chain (Config/NpcQuests), their lines (Config/NpcDialogue) and
	the cosmetic for finishing the chain (Config/Cosmetics).

	`post` is in train space (TrainBuilder: x along the track, +X the locomotive,
	y = 0 the floor, +Z the platform side); `yaw` turns the figure, 0 facing -Z and
	90 facing -X. The train never moves and stations never touch it, so posts do
	not depend on stop layouts.

	`enabled = false` reserves a slot (and its save key) without building anything.
	Logic/NpcSave fills a save entry for every enabled NPC on load, so switching one
	on later needs no migration of its own.
]]

local Dialogue = script.Parent.NpcDialogue
local Outfits = require(script.Parent.Outfits)

export type Line = {
	id: string,
	topic: string,
	text: string,
	when: { [string]: any }?,
}

-- Dressed from the shared period kit (Config/Outfits, built by Builders/OutfitKit).
export type Look = Outfits.Look

export type NpcDef = {
	id: string,
	name: string,
	role: string,
	enabled: boolean,
	post: { x: number, z: number, yaw: number }?,
	chain: { string },
	cosmetic: string?,
	look: Look?,
	-- The resident's Blender figure (Builders/NpcFigure): one mesh and its texture, uploaded under
	-- the owner's account. Without one, or if it fails to load, the kit figure is what shows.
	mesh: { meshId: number, textureId: number }?,
	-- The resident as the same blocky R6 body the crew wear (Builders/NpcFigure, like CrewService's
	-- buildR6): classic Shirt and Pants sheets, a face decal and mesh pieces welded to limbs (the
	-- CrewClothing accessory fields). When set it wins over `mesh`; every client animates it
	-- (CharacterAnimator). Ids are owner uploads; a missing one is left off.
	rig: Rig?,
	lines: { Line },
}

export type RigPiece = {
	name: string,
	mesh: number,
	texture: number,
	limb: string, -- "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"
	offset: { number }, -- studs in the limb's space
	yaw: number?, -- degrees about the limb's up axis
	size: { number }?, -- the mesh's native size in studs, set in case the import rescaled it
}

-- shirt, pants and face are image ids (585x559 classic sheets and a face decal), applied as
-- ShirtTemplate, PantsTemplate and the head's face texture.
export type Rig = {
	shirt: number?,
	pants: number?,
	face: number?,
	pieces: { RigPiece },
}

local Order = { "Mabel", "Dutch", "Varga", "Pip", "Conductor" }

local List: { [string]: NpcDef } = {
	Mabel = {
		id = "Mabel",
		name = "Mabel Orrin",
		role = "Ticket Clerk",
		enabled = true,
		-- the crew saloon's platform side, between the bell and the route board, facing the aisle:
		-- clear of the bays (the old post at -25.4, -3.5 stood in a bench back), the doors and the
		-- board's sight line
		post = { x = -28.5, z = 3.4, yaw = 0 },
		chain = { "MabelLuggage", "MabelNames", "MabelManifest" },
		cosmetic = "hat_clerk",
		-- the company's navy in a fitted bodice and plain skirt, a clerk's eyeshade, her punch
		look = {
			skin = { 234, 196, 168 },
			hair = { 128, 112, 104 },
			hairStyle = "Bun",
			cut = "Bodice",
			coat = { 40, 50, 78 },
			trim = { 201, 160, 82 },
			lower = { 40, 46, 70 },
			skirt = "Plain",
			hat = "Visor",
			prop = "Punch",
		},
		mesh = { meshId = 117337144385821, textureId = 134575749709709 },
		rig = {
			shirt = 103214750665177,
			pants = 103978285622458,
			face = 114163570879355,
			-- Studio's OBJ import turns these pieces round (front to back), hence yaw 180
			pieces = {
				{
					name = "Skirt",
					limb = "Torso",
					mesh = 114561113986467,
					texture = 130730528507892,
					offset = { 0, -1.701, 0.06 },
					yaw = 180,
					size = { 3.063, 2.347, 2.137 },
				},
				{
					name = "Hair",
					limb = "Head",
					mesh = 139153894998568,
					texture = 72542832896870,
					offset = { 0, 0.109, 0.122 },
					yaw = 180,
					size = { 1.28, 1.067, 1.441 },
				},
				{
					name = "Eyeshade",
					limb = "Head",
					mesh = 111491431774316,
					texture = 125078973870979,
					offset = { 0, 0.195, -0.18 },
					yaw = 180,
					size = { 1.506, 0.38, 1.781 },
				},
				{
					name = "TicketPunch",
					limb = "Right Arm",
					mesh = 94369767665961,
					texture = 114842239591331,
					offset = { 0, -0.996, -0.309 },
					yaw = 180,
					size = { 0.252, 0.937, 0.53 },
				},
			},
		},
		lines = require(Dialogue.Mabel) :: any,
	},
	-- Reserved for the next passes; built from this table once enabled.
	Dutch = {
		id = "Dutch",
		name = "Dutch Calloway",
		role = "Stoker",
		enabled = false,
		chain = {},
		lines = {},
	},
	Varga = { id = "Varga", name = "Dr. Ines Varga", role = "Medic", enabled = false, chain = {}, lines = {} },
	Pip = { id = "Pip", name = "Pip", role = "Stowaway", enabled = false, chain = {}, lines = {} },
	Conductor = {
		id = "Conductor",
		name = "The Conductor",
		role = "Conductor",
		enabled = false,
		chain = {},
		lines = {},
	},
}

for _, id in Order do
	local def = List[id]
	assert(def and def.id == id, `npc {id} is missing or mismatched`)
	assert(not def.enabled or def.post ~= nil, `enabled npc {id} needs a post`)
	table.freeze(def)
end

return table.freeze({
	Order = table.freeze(Order),
	List = table.freeze(List),
})
