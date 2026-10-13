--!strict
--[[
	How many Hollows one stop holds (Difficulty.Threat). The total covers every Hollow
	alive at the stop, asleep or awake, so the crew never faces more than the table says.
	Sleepers take at most SleeperShare of it and always leave a slot for the wanderer.
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)

local C = Difficulty.Threat

local HollowBudget = {}

-- Every Hollow alive at once at a stop, for `crew` players in the run.
function HollowBudget.total(crew: number): number
	return C.FullByCrew[math.clamp(math.floor(crew), 1, #C.FullByCrew)]
end

-- How many of `total` may start asleep in buildings.
function HollowBudget.sleepers(total: number): number
	return math.clamp(math.floor(total * C.SleeperShare), 0, math.max(total - 1, 0))
end

return table.freeze(HollowBudget)
