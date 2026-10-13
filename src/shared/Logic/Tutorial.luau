--!strict
--[[
	The tutorial (Config/Tutorial): a player's first Runs runs. Pure.

	tier(runs)        1 on a first run (0 runs done), 2 on the second, 3 on the third; 0 after
	crewTier(list)    the crew rides at its least experienced player's tier. This is the NPC
	                  errands' rule for the crew's lowest stage (Logic/NpcQuest.runStage): the
	                  lowest count among the crew still inside the tutorial decides

	Counting (profile.tutorialRuns, Services/TutorialService): a run counts once it ends,
	for each player who stepped off the train at least once in it. A profile that failed to
	load counts as a finished tutorial and is never written back.
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

-- The completed tutorial runs to play by: the stored count, or a finished tutorial when the
-- profile did not load. `override` is the owner's dev setting and wins over both.
function Tutorial.runs(loaded: boolean, stored: any, override: number?): number
	if override ~= nil then
		return count(override)
	end
	return if loaded then count(stored) else T.Runs
end

-- The count to store after a run, or nil to write nothing: the profile did not load, the
-- player never stepped off the train, or the tutorial is already behind them.
function Tutorial.afterRun(loaded: boolean, stored: any, steppedOff: boolean): number?
	if not loaded or not steppedOff then
		return nil
	end
	local done = count(stored)
	return if done < T.Runs then done + 1 else nil
end

-- The tier's settings, or nil past the tutorial.
function Tutorial.def(tier: number?): TutorialConfig.Tier?
	if tier == nil or tier < 1 then
		return nil
	end
	return T.Tiers[math.min(math.floor(tier), #T.Tiers)]
end

return table.freeze(Tutorial)
