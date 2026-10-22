--!strict
--[[
	Route length (docs/FINAL-DESIGN.md Prompt 10). Pure.

	  Short Line  5 stops, the proposed default for new players
	  Long Line   10 stops, the veteran and status route

	  length(route)            stops before the Terminus (run.stopCount)
	  level(route, k)          the Long Line stop index stop k's difficulty reads: Short stop k
	                           reads m(k) = {1, 2, 4, 6, 8}, so stops 1-2 match the Long Line and the
	                           Short Line still climbs to a late climax below the Long Line's peak.
	                           Every stop-indexed difficulty input reads it (forStop over the Long
	                           Line's count, Threat, Hollow caps, leaks, skill checks, door-forcing);
	                           the stop clock and the tutorial's stop rules use the real k
	  isNew(runsEnded)         new until NewHandRuns runs reached RunEnd
	  decide(anyNew, armE1, shortVotes, longVotes)
	                           the run's route and whether the crew had a choice: any new member
	                           fixes it (E1's arm while E1 runs, else Short); otherwise the vote,
	                           with a tie or no votes going Long (the full experience)
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)

export type Route = "Short" | "Long"

local Routes = {}

function Routes.length(route: Route?): number
	return if route == "Short" then Tuning.Run.Routes.Short else Tuning.Run.Routes.Long
end

-- The route a run of `stops` stops is on (a run state that predates routes reads Long).
function Routes.of(stops: number?): Route
	return if stops == Tuning.Run.Routes.Short then "Short" else "Long"
end

function Routes.level(route: Route?, stop: number): number
	if route == "Short" then
		local levels = Tuning.Run.ShortLevels
		return levels[math.clamp(stop, 1, #levels)]
	end
	return stop
end

function Routes.isNew(runsEnded: number?): boolean
	return (runsEnded or 0) < Tuning.Run.NewHandRuns
end

function Routes.decide(
	anyNew: boolean,
	armE1: string?,
	shortVotes: number,
	longVotes: number
): (Route, boolean)
	if anyNew then
		return if armE1 == "Long" then "Long" else "Short", true
	end
	return if shortVotes > longVotes then "Short" else "Long", false
end

return table.freeze(Routes)
