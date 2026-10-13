--!strict
--[[
	The tutorial (Config/Tutorial): a player's first Runs runs. Pure.

	tier(runs)        1 on a first run (0 runs done), 2 on the second, 3 on the third; 0 after
	crewTier(list)    the crew rides at its least experienced player's tier. This is the NPC
	                  errands' rule for the crew's lowest stage (Logic/NpcQuest.runStage): the
	                  lowest count among the crew still inside the tutorial decides
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)
local TutorialConfig = require(Shared.Config.Tutorial)
local NpcQuest = require(script.Parent.NpcQuest)

local T = Difficulty.Tutorial

local Tutorial = {}

local function count(runs: any): number
	return if type(runs) == "number"
			and runs == runs
			and runs >= 0
			and runs < math.huge
		then math.floor(runs)
		else T.Runs
end

function Tutorial.tier(runs: number): number
	local done = count(runs)
	return if done < T.Runs then done + 1 else 0
end

-- `runsList`: each crew member's completed tutorial runs.
function Tutorial.crewTier(runsList: { number }): number
	local counts: { number } = {}
	for _, runs in runsList do
		table.insert(counts, count(runs))
	end
	local lowest = NpcQuest.runStage(counts, T.Runs - 1)
	return if lowest then Tutorial.tier(lowest) else 0
end

-- The tier's settings, or nil past the tutorial.
function Tutorial.def(tier: number?): TutorialConfig.Tier?
	if tier == nil or tier < 1 then
		return nil
	end
	return T.Tiers[math.min(math.floor(tier), #T.Tiers)]
end

return table.freeze(Tutorial)
