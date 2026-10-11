--!strict
--[[
	How many Hollows one stop holds (Tuning.HollowCount). The total covers every Hollow
	alive at the stop, asleep or awake, so the crew never faces more than the table says.
	Sleepers take at most SleeperShare of it and always leave a slot for the wanderer.
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)

local C = Tuning.HollowCount

local HollowBudget = {}

-- Every Hollow alive at once at a stop, for `crew` players in the run.
function HollowBudget.total(crew: number): number
	return C.ByCrew[math.clamp(math.floor(crew), 1, #C.ByCrew)]
end

-- How many of `total` may start asleep in buildings.
function HollowBudget.sleepers(total: number): number
	return math.clamp(math.floor(total * C.SleeperShare), 0, math.max(total - 1, 0))
end

return table.freeze(HollowBudget)
