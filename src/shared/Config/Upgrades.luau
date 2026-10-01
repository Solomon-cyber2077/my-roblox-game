--!strict
--[[
	Train upgrades bought with parts at the Workshop car. They last for one run.
	Effects are read through Logic/Ledger.derived so no system reads levels directly.
]]

export type UpgradeDef = {
	id: string,
	name: string,
	description: string,
	costs: { number },
	order: number,
}

local Upgrades: { [string]: UpgradeDef } = {
	FireboxBaffles = {
		id = "FireboxBaffles",
		name = "Firebox Baffles",
		description = "Burn 15% less coal per kilometre, per level.",
		costs = { 6, 10, 16 },
		order = 1,
	},
	CoalBunker = {
		id = "CoalBunker",
		name = "Coal Bunker",
		description = "The bunker holds 25 more coal, per level.",
		costs = { 5, 9 },
		order = 2,
	},
	SteamWhistle = {
		id = "SteamWhistle",
		name = "Steam Whistle",
		description = "The train waits one second longer at departure, per level.",
		costs = { 7, 12 },
		order = 3,
	},
	Floodlamps = {
		id = "Floodlamps",
		name = "Floodlamps",
		description = "Hollows stay 6 studs further back and fog bites 15% less, per level.",
		costs = { 8, 14 },
		order = 4,
	},
	ArmorPlating = {
		id = "ArmorPlating",
		name = "Armour Plating",
		description = "25% fewer hull breaches while travelling, per level.",
		costs = { 8, 14 },
		order = 5,
	},
	PorterSatchels = {
		id = "PorterSatchels",
		name = "Porter Satchels",
		description = "Every crew member carries one more slot.",
		costs = { 12 },
		order = 6,
	},
}

local Effects = {
	BurnMultiplierPerLevel = 0.85,
	CoalMaxPerLevel = 25,
	ChaseSecondsPerLevel = 1,
	SafeBandPerLevel = 6,
	FogDpsMultiplierPerLevel = 0.85,
	BreachMultiplierPerLevel = 0.75,
	SlotsPerLevel = 1,
}

for _, def in Upgrades do
	table.freeze(def.costs)
	table.freeze(def)
end

return table.freeze({
	List = table.freeze(Upgrades),
	Effects = table.freeze(Effects),
})
