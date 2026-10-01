--!strict
--[[
	Container searches. A container's roll is a pure function of the station
	seed and the container id, so a search always yields the same items no
	matter who opens it or when.
]]

local Shared = script.Parent.Parent
local Items = require(Shared.Config.Items)
local Loot = require(Shared.Config.Loot)
local Stations = require(Shared.Config.Stations)
local Rng = require(Shared.Util.Rng)

type Archetype = Stations.Archetype

local LootRoll = {}

local function zoneKey(zone: string): string
	return if zone == "Safe" then "Near" else zone
end

function LootRoll.weights(
	containerKind: string,
	zone: string,
	archetype: Archetype?
): { Rng.Weighted<string> }
	local def = Loot.Containers[containerKind]
	assert(def, `unknown container {containerKind}`)
	local zoneDef = Loot.Zones[zoneKey(zone)]
	local out: { Rng.Weighted<string> } = {}
	for _, entry in Loot.Tables[def.table] do
		local item = Items[entry.item]
		local weight = entry.weight
		if archetype then
			local category = Loot.Categories[entry.item]
			local bias = (archetype.loot :: any)[category]
			weight *= if type(bias) == "number" then bias else 1
		end
		if item.value >= Loot.RareValue then
			weight *= zoneDef.rareMultiplier
		end
		table.insert(out, { weight = weight, value = entry.item })
	end
	return out
end

function LootRoll.roll(containerKind: string, zone: string, archetype: Archetype?, seed: number): { string }
	local rng = Rng.new(seed)
	local weights = LootRoll.weights(containerKind, zone, archetype)
	local rolls = Loot.Zones[zoneKey(zone)].rolls
	local found: { string } = {}
	for _ = 1, rolls do
		table.insert(found, rng:weighted(weights))
	end
	return found
end

-- Expected coal-equivalent value of one search (used for balance tests and the blueprint).
function LootRoll.expectedValue(containerKind: string, zone: string, archetype: Archetype?): number
	local weights = LootRoll.weights(containerKind, zone, archetype)
	local total, value = 0, 0
	for _, entry in weights do
		total += entry.weight
		value += entry.weight * Items[entry.value].value
	end
	return Loot.Zones[zoneKey(zone)].rolls * value / total
end

function LootRoll.holdSeconds(containerKind: string, zone: string): number
	local def = Loot.Containers[containerKind]
	return def.hold * Loot.Zones[zoneKey(zone)].holdMultiplier
end

function LootRoll.seedFor(stationSeed: number, containerId: number): number
	return Rng.derive(stationSeed, "container", containerId)
end

return table.freeze(LootRoll)
