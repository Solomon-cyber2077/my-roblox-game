--!strict
--[[
	The tutorial (Config/Tutorial): a player's first Runs runs. Pure.

	tier(runs)        1 on a first run (0 runs done), 2 on the second, 3 on the third; 0 after
	crewTier(list)    the crew rides at its least experienced player's tier. This is the NPC
	                  errands' rule for the crew's lowest stage (Logic/NpcQuest.runStage): the
	                  lowest count among the crew still inside the tutorial decides
	inline(id, tier)  the prompt its own screen draws on this tier (Config/Tutorial `inline`), or nil

	Counting (profile.tutorialRuns, Services/TutorialService): a run counts once it ends,
	for each player who stepped off the train at least once in it and whose own tier it was
	played at or below (a newcomer who joined a run already under way, at a later tier or past
	the tutorial, keeps their tier). A profile that failed to load counts as a finished
	tutorial and is never written back.
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)
local TutorialConfig = require(Shared.Config.Tutorial)
local NpcQuest = require(script.Parent.NpcQuest)

local T = Difficulty.Tutorial

local Tutorial = {}

export type Def = TutorialConfig.Tier

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

-- Whether a run played at `runTier` counts toward a player with `runs` done: only a tier at
-- or below their own (a crew rides at its least experienced member's tier, so only a late
-- joiner can be in a run harder than their own tier).
function Tutorial.counts(runs: any, runTier: number): boolean
	local own = Tutorial.tier(runs)
	return own >= 1 and runTier >= 1 and runTier <= own
end

-- The count to store after a run, or nil to write nothing: the profile did not load, the
-- player never stepped off the train, the run was harder than their tier, or the tutorial
-- is already behind them.
function Tutorial.afterRun(loaded: boolean, stored: any, steppedOff: boolean, runTier: number): number?
	if not loaded or not steppedOff or not Tutorial.counts(stored, runTier) then
		return nil
	end
	local done = count(stored)
	return if done < T.Runs then done + 1 else nil
end

function Tutorial.inline(id: string, tier: number?): TutorialConfig.Prompt?
	if tier == nil or tier < 1 then
		return nil
	end
	for _, prompt in T.Prompts do
		if prompt.id == id and prompt.inline == true and tier <= prompt.tier then
			return prompt
		end
	end
	return nil
end

-- The tier's settings, or nil past the tutorial.
function Tutorial.def(tier: number?): TutorialConfig.Tier?
	if tier == nil or tier < 1 then
		return nil
	end
	return T.Tiers[math.min(math.floor(tier), #T.Tiers)]
end

return table.freeze(Tutorial)
