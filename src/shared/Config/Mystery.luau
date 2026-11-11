--!strict
--[[
	The mystery ticket: a sealed line whose station is real but unnamed until the train arrives
	(Logic/Mystery). Distance and coal show on the ticket; name, type, danger and the reward stay
	on the server.

	Enabled      the feature flag
	Chance       the roll at an eligible junction, on the run seed
	PityAfter    this many junctions in a row without one, and the next eligible junction has one
	FirstLeg     never offered before this leg (leg 1 is the first junction)
	LootBonus    multiplies the station's lootMul (LayoutGen scales every container's count by it)
	DangerBias   tiers added to the hidden station's danger, capped at MaxTier (0 = none)
	Archetype    the public stand-in for the hidden archetype; it is in no Stations list
]]

return table.freeze({
	Enabled = true,
	Chance = 0.25,
	PityAfter = 5,
	FirstLeg = 2,
	LootBonus = 1.3,
	DangerBias = 0,
	MaxTier = 3,
	Archetype = "Mystery",
	Name = "????",
})
