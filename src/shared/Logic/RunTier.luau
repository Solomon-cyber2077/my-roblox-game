--!strict
--[[
	Opt-in run difficulty tiers. Tier 1 is the default; winning a run at tier N
	unlocks N + 1 (capped at Max). The host may pick any tier up to the lowest
	unlocked tier among the crew. Numbers live in Config/Difficulty.RunTier.
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)

local RunTier = {}

function RunTier.clamp(tier: number?): number
	local t = math.floor(tonumber(tier) or Difficulty.RunTier.Default)
	return math.clamp(t, 1, Difficulty.RunTier.Max)
end

-- Added to every stop's difficulty D.
function RunTier.offset(tier: number): number
	return Difficulty.RunTier.OffsetPerTier * (RunTier.clamp(tier) - 1)
end

-- Brass multiplier for a run at this tier (1 at tier 1).
function RunTier.brassMultiplier(tier: number): number
	return 1 + Difficulty.RunTier.BrassBonusPerTier * (RunTier.clamp(tier) - 1)
end

-- Highest tier the whole crew may play: the lowest of their unlocked tiers.
function RunTier.crewMax(unlocked: { number }): number
	local best = Difficulty.RunTier.Max
	if #unlocked == 0 then
		return Difficulty.RunTier.Default
	end
	for _, tier in unlocked do
		best = math.min(best, RunTier.clamp(tier))
	end
	return best
end

-- The unlocked tier after a run at `played`; only a victory unlocks the next one.
function RunTier.afterRun(unlocked: number, played: number, victory: boolean): number
	local current = RunTier.clamp(unlocked)
	if not victory then
		return current
	end
	return math.max(current, RunTier.clamp(RunTier.clamp(played) + 1))
end

return table.freeze(RunTier)
