--[[
	The balance report (docs/FINAL-DESIGN.md Prompt 0, B.4), computed by the shipped modules so the
	document cannot drift from the game. Deterministic model outputs only: nothing here is a player
	observation. Re-run it after any change to the clock, speeds, route or bell.

	lune run report            all tables
	lune run report route      only the route model (REPORT_SEEDS sets the seed count, default 1000)
]]

local process = require("@lune/process")

local Loader = require("./lib/Loader")
local Shared = Loader.roots.Shared
local require = Loader.requireNode

local Difficulty = require(Shared.Config.Difficulty)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)
local DifficultyModel = require(Shared.Logic.DifficultyModel)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local Leaks = require(Shared.Logic.Leaks)
local RouteGen = require(Shared.Logic.RouteGen)
local RunRules = require(Shared.Logic.RunRules)
local Threat = require(Shared.Logic.Threat)
local Rng = require(Shared.Util.Rng)

local only = process.args[1]
local N = Tuning.Run.StationCount
local Run = Tuning.Run
local Crew = Tuning.Crew

-- Stop clock B (B.4, Prompt 4): the clock the design adopts. Until Prompt 4 lands it is a scenario
-- here, beside the clock the game runs now. WalkReference sizes the timer only.
local CLOCK_B = {
	Search = { 80, 60 },
	PerBuildingTile = Difficulty.StopClock.PerBuildingTile,
	BuildingTileCap = Difficulty.StopClock.BuildingTileCap,
	WalkMargin = 1.4,
	PerStop = 3,
	WalkReference = 30,
}

local function round(x: number, digits: number?): number
	local m = 10 ^ (digits or 0)
	return math.floor(x * m + 0.5) / m
end

local function csv(values: { any }): string
	local out = {}
	for i, v in values do
		out[i] = tostring(v)
	end
	return table.concat(out, ",")
end

-- The clock the game runs now: DifficultyModel.dwell itself.
local function dwellNow(d: number, arch: any, stop: number): number
	return DifficultyModel.dwell(d, arch, stop)
end

-- Clock B: DifficultyModel.dwell's formula with B's terms and the timer's reference walk speed.
local function dwellB(d: number, arch: any, stop: number): number
	local c = CLOCK_B
	local tiles = math.min(DifficultyModel.buildingTiles(arch), c.BuildingTileCap)
	local search = (c.Search[1] + (c.Search[2] - c.Search[1]) * d + c.PerBuildingTile * tiles)
		* arch.dwellMultiplier
	local walk = 2 * DifficultyModel.farWalk(arch) / c.WalkReference * c.WalkMargin
	return math.floor(search + walk + c.PerStop * math.max(stop - 1, 0) + 0.5)
end

local CLOCKS = { { name = "now", dwell = dwellNow }, { name = "B", dwell = dwellB } }

-- A bell pull sets departAt = min(departAt, now + BELL_LEAD) (Prompt 4, FIXED).
local BELL_LEAD = 30

local function section(title: string)
	print(`\n== {title}`)
end

--------------------------------------------------------------------------------------------
-- Assumptions

local function assumptions()
	print("Deterministic model outputs from the shipped modules; no player observations.")
	print(
		`Run: {N} stops then the Terminus; run tier 1 unless stated; no upgrades; route tier from the first offered option.`
	)
	print(
		`Speeds: walk {Crew.WalkSpeed}, sprint {Crew.SprintSpeed} (reach and chases use these). Timer walk term: clock now uses Crew.WalkSpeed {Crew.WalkSpeed}; clock B uses WalkReference {CLOCK_B.WalkReference} (timer only).`
	)
	print(
		`Clock now: Search {Difficulty.StopClock.Search[1]}/{Difficulty.StopClock.Search[2]}, WalkMargin {Difficulty.StopClock.WalkMargin}, PerStop {Difficulty.StopClock.PerStop}, Detour {Difficulty.StopClock.Detour}.`
	)
	print(
		`Clock B:   Search {CLOCK_B.Search[1]}/{CLOCK_B.Search[2]}, WalkMargin {CLOCK_B.WalkMargin}, PerStop {CLOCK_B.PerStop}, Detour {Difficulty.StopClock.Detour} (scenario until Prompt 4).`
	)
	print(
		`Bell: not implemented yet (Prompt 4). Scenarios pull at elapsed share u of the original params.dwell (LastCall included) from doorsOpenAt; departAt becomes min(departAt, pull + {BELL_LEAD} s). Eligibility is assumed, not simulated.`
	)
end

--------------------------------------------------------------------------------------------
-- Difficulty by stop

local function difficultyTable()
	section("D by stop and route tier (run tier 1)")
	print("stop,tier1,tier2,tier3")
	for n = 1, N do
		print(csv({
			n,
			round(DifficultyModel.forStop(n, N, 1), 3),
			round(DifficultyModel.forStop(n, N, 2), 3),
			round(DifficultyModel.forStop(n, N, 3), 3),
		}))
	end
end

--------------------------------------------------------------------------------------------
-- Archetypes: the real stops with their real dimensions

local function archetypeTable()
	section("Archetypes at stops 1 and 10 (route tier 2, run tier 1, no upgrades)")
	print(
		"archetype,length,depth,far_walk,tiles,stop,D,dwell_now_s,dwell_B_s,fog_starts_now_s,fog_starts_B_s,hollows_crew1,hollows_crew4,hollow_cap_crew4"
	)
	for _, id in Stations.Order do
		local arch = Stations.List[id]
		for _, stop in { 1, N } do
			local d = DifficultyModel.forStop(stop, N, 2, 1)
			local p = DifficultyModel.params(d, arch, 4, nil, stop)
			local b = dwellB(d, arch, stop)
			print(csv({
				id,
				arch.length,
				arch.depth,
				round(DifficultyModel.farWalk(arch), 1),
				DifficultyModel.buildingTiles(arch),
				stop,
				round(d, 3),
				p.dwell,
				b,
				round(p.fogStartU * p.dwell),
				round(p.fogStartU * b),
				Threat.total(stop, 1),
				Threat.total(stop, 4),
				p.hollowCap,
			}))
		end
	end
end

--------------------------------------------------------------------------------------------
-- Normal chase ranges, kind and pace included

local function chaseTable()
	section(`Normal chase ranges: HollowChase(D) x kind chase x pace (1 +/- {Tuning.Hollow.PaceSpread})`)
	print("kind,D,kind_x,chase_min,chase_max,minus_walk_min,minus_walk_max,sprint_minus_max")
	local kinds = {}
	for kind in Tuning.HollowKinds do
		table.insert(kinds, kind)
	end
	table.sort(kinds)
	for _, kind in kinds do
		local k = Tuning.HollowKinds[kind].chase
		for _, d in { 0, 1 } do
			local base = Difficulty.HollowChase[1]
				+ (Difficulty.HollowChase[2] - Difficulty.HollowChase[1]) * d
			local lo = base * k * (1 - Tuning.Hollow.PaceSpread)
			local hi = base * k * (1 + Tuning.Hollow.PaceSpread)
			print(csv({
				kind,
				d,
				k,
				round(lo, 3),
				round(hi, 3),
				round(lo - Crew.WalkSpeed, 3),
				round(hi - Crew.WalkSpeed, 3),
				round(Crew.SprintSpeed - hi, 3),
			}))
		end
	end
	print("Speed relationships only: not catch or escape guarantees (B.4).")
end

--------------------------------------------------------------------------------------------
-- Hazards per stop (each archetype in Stations.Order at its own stop number)

local function hazardTable()
	section("Hazard parameters per stop (route tier 2, 4 crew, archetype = Stations.Order[stop])")
	print(csv({
		"stop",
		"archetype",
		"D",
		"dwell_s",
		"fog_starts_s",
		"fog_stops_pct",
		"fog_dps",
		"collapse_lag_s",
		"warn_s",
		"spawn_every_s",
		"hollows",
		"hollow_cap",
		"hollow_chase",
		"hollow_dmg",
		"pull",
		"window_s",
		"loot_x",
		"leaks_per_trip",
	}))
	for n = 1, N do
		local id = Stations.Order[((n - 1) % #Stations.Order) + 1]
		local arch = Stations.List[id]
		local d = DifficultyModel.forStop(n, N, 2)
		local p = DifficultyModel.params(d, arch, 4, nil, n)
		print(csv({
			n,
			id,
			round(d, 2),
			p.dwell,
			round(p.fogStartU * p.dwell),
			round(p.fogEndFraction * 100),
			round(p.fogDps, 1),
			round(p.collapseLag, 1),
			round(p.collapseWarn, 2),
			round(p.spawnInterval, 1),
			Threat.total(n, 4),
			p.hollowCap,
			round(p.hollowChase, 1),
			p.hollowDamage,
			round(p.departureAccel, 2),
			round(p.chaseWindow, 2),
			round(p.lootMul, 2),
			Leaks.count(n, d, nil, 0.5),
		}))
	end

	section("Sample stop: fronts over time (stop 6, Minehead, route tier 2)")
	local arch = Stations.List.Minehead
	local d6 = DifficultyModel.forStop(6, N, 2)
	local p6 = DifficultyModel.params(d6, arch, 4, nil, 6)
	local geo = { depth = arch.depth, safe = Tuning.World.SafeStrip }
	print(`dwell={p6.dwell} lastCall={p6.lastCall} D={round(d6, 3)} depth={arch.depth}`)
	print("t,fog_z,collapse_z")
	for t = 0, p6.dwell, 8 do
		local fogZ = round(math.min(HazardSchedule.fogFront(p6, geo, t), geo.depth), 1)
		local collapseZ = round(math.min(HazardSchedule.collapseFront(p6, geo, t), geo.depth), 1)
		print(`{t},{fogZ},{collapseZ}`)
	end
end

--------------------------------------------------------------------------------------------
-- The route model: Countdown to the Terminus's RunEnd, every leg through the Terminus

type Scenario = { name: string, share: number?, fraction: number, eligibility: string }

local SCENARIOS: { Scenario } = {
	{ name = "no bell", share = nil, fraction = 0, eligibility = "full schedule" },
	{ name = "every stop u=0.40", share = 0.40, fraction = 1, eligibility = "all living crew aboard" },
	{ name = "every stop u=0.60", share = 0.60, fraction = 1, eligibility = "at least half aboard" },
	{ name = "60% of stops u=0.50", share = 0.50, fraction = 0.6, eligibility = "all living crew aboard" },
}

-- One run: seconds from Countdown to the end of RunEnd (as B.4 counts it) and the mean doors-open seconds per stop.
local function simulate(
	seed: number,
	stops: number,
	crew: number,
	dwellOf: any,
	scenario: Scenario
): (number, number)
	local total = Run.CountdownSeconds + Run.BoardingSeconds
	local doorsTotal = 0
	local previous = nil
	for leg = 1, stops do
		local option = RouteGen.options(seed, leg, stops, previous)[1]
		previous = option.archetype
		local arch = Stations.List[option.archetype]
		local d = DifficultyModel.forStop(leg, stops, option.tier, 1)
		local p = DifficultyModel.params(d, arch, crew, nil, leg)
		local dwell = dwellOf(d, arch, leg)
		local doors = math.max(dwell - Run.LastCallSeconds, 1) + Run.LastCallSeconds
		local share = scenario.share
		if share then
			local rings = scenario.fraction >= 1
				or Rng.new(Rng.derive(seed, "bell", leg)):next() < scenario.fraction
			if rings then
				doors = math.min(doors, share * dwell + BELL_LEAD)
			end
		end
		doorsTotal += doors
		total += Run.JunctionSeconds + DifficultyModel.cruiseSeconds(option.distanceKm) + Run.ArrivalSeconds + doors + RunRules.graceSeconds() + p.chaseWindow
	end
	local terminus = RouteGen.terminusOption()
	total += Run.FinalJunctionSeconds + DifficultyModel.cruiseSeconds(terminus.distanceKm) + Run.ArrivalSeconds + Run.TerminusSeconds + Run.RunEndSeconds
	return total, doorsTotal / stops
end

local function routeModel()
	local seeds = tonumber(process.env.REPORT_SEEDS) or 1000
	section(
		`Route model ({seeds} seeds, first offered route, run tier 1, no upgrades, Countdown through RunEnd; telemetry run_ended stops at RunEnd entry, {Run.RunEndSeconds} s sooner)`
	)
	print("line,stops,crew,clock,scenario,eligibility,mean_min,min_min,max_min,mean_doors_open_s")
	local lines = {
		{ name = "Long Line", stops = N, note = "" },
		{
			name = "Short Line",
			stops = 5,
			note = " (placeholder: Prompt 10 sets its difficulty, sky and rewards)",
		},
	}
	for _, line in lines do
		for _, crew in { 1, 4 } do
			for _, clock in CLOCKS do
				for _, scenario in SCENARIOS do
					local sum, lo, hi, doors = 0, math.huge, -math.huge, 0
					for seed = 1, seeds do
						local seconds, meanDoors = simulate(seed, line.stops, crew, clock.dwell, scenario)
						sum += seconds
						lo = math.min(lo, seconds)
						hi = math.max(hi, seconds)
						doors += meanDoors
					end
					print(csv({
						line.name .. line.note,
						line.stops,
						crew,
						clock.name,
						scenario.name,
						scenario.eligibility,
						round(sum / seeds / 60, 2),
						round(lo / 60, 2),
						round(hi / 60, 2),
						round(doors / seeds),
					}))
				end
			end
		end
	end
	print(
		"Crew size changes Hollow counts, not the clock, so 1 and 4 match on duration. Means, not ceilings; no outcome or completion rate follows from them."
	)
end

if only == "route" then
	routeModel()
else
	assumptions()
	difficultyTable()
	archetypeTable()
	chaseTable()
	hazardTable()
	routeModel()
end
