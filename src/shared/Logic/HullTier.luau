--!strict
--[[
	How damaged the hull is, for its effects (Controllers/HullController, Difficulty.Hull.Tiers):
	  0  sound
	  1  below Creak (75%): the train creaks, a first warning
	  2  below Flicker (50%): the lights flicker
	  3  below Emergency (25%): emergency lighting and the alarm
	Pure.
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)

local HullTier = {}

-- `integrity` out of `max` (the hull's percent when max is 100).
function HullTier.tier(integrity: number, max: number?): number
	local percent = integrity / math.max(max or 100, 1) * 100
	local tiers = Difficulty.Hull.Tiers
	if percent < tiers.Emergency then
		return 3
	elseif percent < tiers.Flicker then
		return 2
	elseif percent < tiers.Creak then
		return 1
	end
	return 0
end

-- How strongly a tier's effects play: a notch stronger with Broken Things Markers off.
function HullTier.strength(markersOn: boolean): number
	return if markersOn then 1 else Difficulty.Hull.MarkersOffBoost
end

return table.freeze(HullTier)
