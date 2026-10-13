--!strict
--[[
	How hard a stop leans on the crew, by its number in the run and the crew's tutorial tier
	(Config/Difficulty Threat and PostGrab, Config/Tutorial). Pure.

	protection   after breaking free: seconds no Hollow may grab you, and whether the Hollow
	             that held you is staggered (stunned and shoved away). By stop from the
	             PostGrab schedule; a tutorial tier's own postGrab replaces it at every stop.
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)
local Tutorial = require(Shared.Config.Tutorial)

local Threat = {}

export type Protection = { immunity: number, stagger: boolean }

-- The tutorial tier's table, or nil when the crew is past the tutorial (tier 0 or nil).
local function tierDef(tutorialTier: number?): Tutorial.Tier?
	if tutorialTier == nil or tutorialTier < 1 then
		return nil
	end
	return Difficulty.Tutorial.Tiers[math.min(math.floor(tutorialTier), #Difficulty.Tutorial.Tiers)]
end

function Threat.protection(stop: number, tutorialTier: number?): Protection
	local tier = tierDef(tutorialTier)
	if tier and tier.postGrab then
		return { immunity = tier.postGrab.immunity, stagger = tier.postGrab.stagger }
	end
	local chosen = Difficulty.PostGrab.Schedule[1]
	for _, row in Difficulty.PostGrab.Schedule do
		if stop >= row.fromStop then
			chosen = row
		end
	end
	return { immunity = chosen.immunity, stagger = chosen.stagger }
end

return table.freeze(Threat)
