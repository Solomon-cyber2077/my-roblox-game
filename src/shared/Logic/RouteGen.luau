--!strict
--[[
	Junction options for each leg. Deterministic from the run seed, so every
	client can show the same cards before the server even sends them.

	Leg k leads to stop k. Legs past the last stop lead to the Terminus.
	Rules: every station (weight > 0) can come up at any leg, stop 1 included, so
	no stop is fixed (the run seed is fresh every run, RunDirector Enter.Boarding;
	`minStation` in Config/Stations is no longer a gate). Options use distinct
	archetypes (a ballot never shows the same station twice), an archetype never
	repeats the previous stop unless nothing else is eligible, legs 1 and 2 never
	show tier 3, and every junction offers at least one leg of 5 km or less.
	A first run's first leg (`firstLegKm`, Tuning.Run.FirstLegKm) is that long on every option, so
	its cruise stays within 25 s (Prompt 10); the draws are the same, so the rest of the plan is too.
]]

local Shared = script.Parent.Parent
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)
local MathX = require(Shared.Util.MathX)
local Rng = require(Shared.Util.Rng)
local Types = require(Shared.Types)

type RouteOption = Types.RouteOption

local RouteGen = {}

function RouteGen.terminusOption(): RouteOption
	return {
		archetype = "Terminus",
		tier = 1,
		distanceKm = Tuning.Run.TerminusDistanceKm,
		hint = Stations.List.Terminus.hint,
	}
end

function RouteGen.options(
	runSeed: number,
	leg: number,
	stopCount: number,
	previous: string?,
	firstLegKm: number?
): { RouteOption }
	if leg > stopCount then
		return { RouteGen.terminusOption() }
	end

	local rng = Rng.new(Rng.derive(runSeed, "route", leg))
	local count = if Tuning.Run.WideJunctions[leg] then 3 else Tuning.Run.RouteOptionCount

	local pool: { Rng.Weighted<string> } = {}
	for _, id in Stations.Order do
		local arch = Stations.List[id]
		if arch.weight > 0 and not arch.terminus and id ~= previous then
			table.insert(pool, { weight = arch.weight, value = id })
		end
	end
	if #pool < count and previous then
		local arch = Stations.List[previous]
		if arch and arch.weight > 0 then
			table.insert(pool, { weight = arch.weight, value = previous })
		end
	end

	local options: { RouteOption } = {}
	while #options < count and #pool > 0 do
		local id = rng:weighted(pool)
		for i, entry in pool do
			if entry.value == id then
				table.remove(pool, i)
				break
			end
		end
		local arch = Stations.List[id]
		local roll = rng:weighted({
			{ weight = 1, value = -1 },
			{ weight = 2, value = 0 },
			{ weight = 1, value = 1 },
		})
		local maxTier = if leg <= 2 then 2 else 3
		table.insert(options, {
			archetype = id,
			tier = MathX.clamp(arch.tier + roll, 1, maxTier),
			distanceKm = rng:int(3, 8),
			hint = arch.hint,
		})
	end

	local hasShort = false
	for _, option in options do
		if option.distanceKm <= 5 then
			hasShort = true
		end
	end
	if not hasShort and #options > 0 then
		options[rng:int(1, #options)].distanceKm = rng:int(3, 5)
	end
	if firstLegKm and leg == 1 then
		for _, option in options do
			option.distanceKm = firstLegKm
		end
	end

	return options
end

return table.freeze(RouteGen)
