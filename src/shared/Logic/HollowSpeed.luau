--!strict
-- One speed policy shared by live pursuit and the endpoint checks.
local Tuning = require(script.Parent.Parent.Config.Tuning)
local Tutorial = require(script.Parent.Parent.Config.Tutorial)
local HollowSpeed = {}

function HollowSpeed.isFirstCrawler(kind: string, scripted: boolean, tier: number?, stop: number?): boolean
	local first = Tutorial.FirstCrawler
	return scripted and kind == "Crawler" and tier == first.Tier and stop == first.Stop
end

function HollowSpeed.resolve(
	baseChase: number,
	kind: string,
	pace: number,
	scripted: boolean,
	tier: number?,
	stop: number?
): (number, number, number)
	if HollowSpeed.isFirstCrawler(kind, scripted, tier, stop) then
		local first = Tutorial.FirstCrawler
		return first.ChaseSpeed, first.LungeSpeed, first.LungeSeconds
	end
	local def = (Tuning.HollowKinds :: { [string]: typeof(Tuning.HollowKinds.Stalker) })[kind]
	local scale = if scripted then Tutorial.ScriptedGrab.ChaseScale else 1
	local chase = baseChase * def.chase * pace * scale
	return chase, chase * def.lunge, Tuning.Hollow.LungeSeconds
end

return HollowSpeed
