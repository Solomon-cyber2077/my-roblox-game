--!strict
--[[
	Containers, loot tables and zone scaling.

	Zone rule (design pillar 2): for any container kind, the expected value of a
	search is 1x near the train, 2x in the middle and about 4x at the far edge.
	Mid doubles the roll count; Far triples it and weights rare items 2.5x.
	tests/Loot.spec.luau enforces those ratios against these tables.
]]

export type ContainerDef = {
	id: string,
	name: string,
	hold: number,
	table: string,
	farOnly: boolean?,
	zoneWeights: { Near: number, Mid: number, Far: number },
}

export type LootEntry = { item: string, weight: number }

local Containers: { [string]: ContainerDef } = {
	Crate = {
		id = "Crate",
		name = "Supply Crate",
		hold = 0.8,
		table = "General",
		zoneWeights = { Near = 3, Mid = 3, Far = 2 },
	},
	Locker = {
		id = "Locker",
		name = "Porter's Locker",
		hold = 1.0,
		table = "Tools",
		zoneWeights = { Near = 2, Mid = 2, Far = 1 },
	},
	CoalBin = {
		id = "CoalBin",
		name = "Coal Bin",
		hold = 0.6,
		table = "Coal",
		zoneWeights = { Near = 1, Mid = 2, Far = 2 },
	},
	ToolChest = {
		id = "ToolChest",
		name = "Tool Chest",
		hold = 1.2,
		table = "Parts",
		zoneWeights = { Near = 0.5, Mid = 2, Far = 2 },
	},
	Vault = {
		id = "Vault",
		name = "Stationmaster's Safe",
		hold = 2.0,
		table = "Vault",
		farOnly = true,
		zoneWeights = { Near = 0, Mid = 0, Far = 1 },
	},
}

local Tables: { [string]: { LootEntry } } = {
	General = {
		{ item = "CoalLump", weight = 30 },
		{ item = "Scrap", weight = 26 },
		{ item = "CoalSack", weight = 8 },
		{ item = "GearCrate", weight = 5 },
		{ item = "Tonic", weight = 7 },
		{ item = "Flashbulb", weight = 6 },
		{ item = "PocketWatch", weight = 8 },
		{ item = "SignalLamp", weight = 2 },
		{ item = "Flare", weight = 3 },
	},
	Tools = {
		{ item = "Tonic", weight = 22 },
		{ item = "Flashbulb", weight = 18 },
		{ item = "Scrap", weight = 20 },
		{ item = "CoalLump", weight = 16 },
		{ item = "Flare", weight = 6 },
		{ item = "PocketWatch", weight = 6 },
		{ item = "GearCrate", weight = 3 },
	},
	Coal = {
		{ item = "CoalLump", weight = 50 },
		{ item = "CoalSack", weight = 22 },
		{ item = "Scrap", weight = 8 },
		{ item = "PocketWatch", weight = 2 },
	},
	Parts = {
		{ item = "Scrap", weight = 46 },
		{ item = "GearCrate", weight = 14 },
		{ item = "Flashbulb", weight = 8 },
		{ item = "CoalLump", weight = 10 },
		{ item = "SignalLamp", weight = 2 },
	},
	Vault = {
		{ item = "PocketWatch", weight = 24 },
		{ item = "SignalLamp", weight = 14 },
		{ item = "TicketPunch", weight = 5 },
		{ item = "Flare", weight = 12 },
		{ item = "GearCrate", weight = 10 },
		{ item = "Tonic", weight = 10 },
	},
}

export type ZoneDef = { rolls: number, rareMultiplier: number, holdMultiplier: number }

local Zones: { [string]: ZoneDef } = {
	Near = { rolls = 1, rareMultiplier = 1.0, holdMultiplier = 1.0 },
	Mid = { rolls = 2, rareMultiplier = 1.0, holdMultiplier = 1.25 },
	Far = { rolls = 3, rareMultiplier = 2.5, holdMultiplier = 1.5 },
}

-- Items worth at least this much (coal-equivalent) count as rare for zone scaling.
local RARE_VALUE = 8

-- Archetype loot biases multiply weights by item category.
local Categories: { [string]: string } = {
	CoalLump = "coal",
	CoalSack = "coal",
	Scrap = "parts",
	GearCrate = "parts",
	PocketWatch = "relic",
	SignalLamp = "relic",
	TicketPunch = "relic",
	Flare = "tools",
	Tonic = "tools",
	Flashbulb = "tools",
}

for _, def in Containers do
	table.freeze(def.zoneWeights)
	table.freeze(def)
end
for _, entries in Tables do
	for _, entry in entries do
		table.freeze(entry)
	end
	table.freeze(entries)
end
for _, zone in Zones do
	table.freeze(zone)
end

return table.freeze({
	Containers = table.freeze(Containers),
	Tables = table.freeze(Tables),
	Zones = table.freeze(Zones),
	Categories = table.freeze(Categories),
	RareValue = RARE_VALUE,
	LooseItems = table.freeze({ "CoalLump", "CoalLump", "CoalLump", "Scrap", "Scrap" }),
})
