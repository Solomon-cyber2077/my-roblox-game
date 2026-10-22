--!strict
--[[
	A run's length and Brass as the route model counts them (docs/FINAL-DESIGN.md B.4, Prompt 10),
	from the shipped modules. Pure, used by .lune/report.luau and the Routes spec. Model outputs,
	never player observations.

	  seconds(seed, route, crew, bell?)  Countdown through the end of RunEnd: every leg's junction,
	                                     cruise, arrival, doors-open time (Logic/DifficultyModel.dwell
	                                     at the stop's level, bell scenarios applied), grace and
	                                     chase window, then the Terminus leg. The first offered
	                                     option each leg, run tier 1, no upgrades. Also returns the
	                                     mean doors-open seconds per stop
	  brass(route, won)                  a crew member's Brass from a run that departs every stop
	                                     alive: per-stop Brass plus the Terminus (loot, relics,
	                                     rescues, tiers and the daily bonus left out)
]]

local Shared = script.Parent.Parent
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)
local Rng = require(Shared.Util.Rng)
local DepartureBell = require(script.Parent.DepartureBell)
local DifficultyModel = require(script.Parent.DifficultyModel)
local RouteGen = require(script.Parent.RouteGen)
local Routes = require(script.Parent.Routes)
local RunRules = require(script.Parent.RunRules)

-- A bell scenario: at `share` of each stop's dwell, on `fraction` of the stops (seeded).
export type Bell = { share: number, fraction: number }

local RouteModel = {}

function RouteModel.seconds(seed: number, route: Routes.Route, crew: number, bell: Bell?): (number, number)
	local run = Tuning.Run
	local stops = Routes.length(route)
	local total = run.CountdownSeconds + run.BoardingSeconds
	local doorsTotal = 0
	local previous = nil
	for leg = 1, stops do
		local option = RouteGen.options(seed, leg, stops, previous)[1]
		previous = option.archetype
		local arch = Stations.List[option.archetype]
		local d = DifficultyModel.forStop(Routes.level(route, leg), run.StationCount, option.tier, 1)
		local p = DifficultyModel.params(d, arch, crew, nil, leg)
		local dwell = p.dwell
		local doors = math.max(dwell - run.LastCallSeconds, 1) + run.LastCallSeconds
		if bell then
			local rings = bell.fraction >= 1 or Rng.new(Rng.derive(seed, "bell", leg)):next() < bell.fraction
			if rings then
				doors = math.min(doors, bell.share * dwell + DepartureBell.LEAD)
			end
		end
		doorsTotal += doors
		total += run.JunctionSeconds + DifficultyModel.cruiseSeconds(option.distanceKm) + run.ArrivalSeconds + doors + RunRules.graceSeconds() + p.chaseWindow
	end
	local terminus = RouteGen.terminusOption()
	total += run.FinalJunctionSeconds + DifficultyModel.cruiseSeconds(terminus.distanceKm) + run.ArrivalSeconds + run.TerminusSeconds + run.RunEndSeconds
	return total, doorsTotal / stops
end

function RouteModel.brass(route: Routes.Route, won: boolean): number
	local e = Tuning.Economy
	return Routes.length(route) * e.BrassPerStation + (if won then e.BrassVictoryAlive else 0)
end

return table.freeze(RouteModel)
