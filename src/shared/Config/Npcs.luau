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

export type Line = {
	id: string,
	topic: string,
	text: string,
	when: { [string]: any }?,
}

export type Look = {
	skin: { number },
	hair: { number },
	coat: { number },
	trim: { number },
	legs: { number },
	hat: string, -- "Visor" (more styles with later NPCs)
}

export type NpcDef = {
	id: string,
	name: string,
	role: string,
	enabled: boolean,
	post: { x: number, z: number, yaw: number }?,
	chain: { string },
	cosmetic: string?,
	look: Look?,
	lines: { Line },
}

local Order = { "Mabel", "Dutch", "Varga", "Pip", "Conductor" }

local List: { [string]: NpcDef } = {
	Mabel = {
		id = "Mabel",
		name = "Mabel Orrin",
		role = "Ticket Clerk",
		enabled = true,
		-- the crew saloon's end wall, across the Workshop gangway from the route board (never in
		-- front of it), clear of the door and the bays
		post = { x = -25.4, z = -3.5, yaw = 90 },
		chain = { "MabelLuggage", "MabelNames", "MabelManifest" },
		cosmetic = "hat_clerk",
		look = {
			skin = { 234, 196, 168 },
			hair = { 128, 112, 104 },
			coat = { 40, 50, 78 },
			trim = { 201, 160, 82 },
			legs = { 52, 44, 52 },
			hat = "Visor",
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
