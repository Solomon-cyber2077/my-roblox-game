--!strict
--[[
	Crew errands: the quest chains of the train's residents (Config/Npcs).

	A chain is an ordered list; a player's saved `stage` for an NPC is the index of
	the next quest in it, and stage #chain + 1 means the chain is finished.

	Kinds:
	  Find     `item` (Config/Items) is hidden at a docked stop numbered `stops[1]..stops[2]`,
	           beside one of the station's containers. Whoever carries it to the NPC
	           and talks to them completes the errand.
	  Survive  completes when the train reaches the Terminus; everyone aboard counts.

	`brass` is paid on the run summary as "Crew errands" (Logic/Economy is untouched).
]]

export type QuestKind = "Find" | "Survive"

export type QuestDef = {
	id: string,
	npc: string,
	title: string,
	kind: QuestKind,
	item: string?,
	stops: { number }?, -- Find: first and last stop the item can turn up at
	brass: number,
	brief: string, -- the tracker line while the errand is open
	carried: string?, -- the tracker line once the crew has the item
}

local Quests: { [string]: QuestDef } = {
	MabelLuggage = {
		id = "MabelLuggage",
		npc = "Mabel",
		title = "Unclaimed Valise",
		kind = "Find",
		item = "UnclaimedValise",
		stops = { 1, 3 },
		brass = 25,
		brief = "Find the unclaimed valise at one of the first three stops.",
		carried = "Bring the valise to Mabel in the saloon.",
	},
	MabelNames = {
		id = "MabelNames",
		npc = "Mabel",
		title = "A Name on the List",
		kind = "Find",
		item = "TicketStub",
		stops = { 4, 7 },
		brass = 30,
		brief = "Find a punched ticket stub at stops 4 to 7.",
		carried = "Bring the ticket stub to Mabel in the saloon.",
	},
	MabelManifest = {
		id = "MabelManifest",
		npc = "Mabel",
		title = "The Final Manifest",
		kind = "Survive",
		brass = 40,
		brief = "Get Mabel and her final manifest to the Terminus.",
	},
}

for id, def in Quests do
	assert(def.id == id, `quest {id} has mismatched id {def.id}`)
	assert(def.kind ~= "Find" or (def.item and def.stops), `Find quest {id} needs an item and stops`)
	table.freeze(def)
end

return table.freeze(Quests)
