--[[
	Prototype gate for recoverable limb loss (design step 1). Two headless measurements on the
	real shared rules; neither is a network or player test.

	1 Rescue timing: Logic/Rescue judged for a rescuer who presses on the beat they see, at
	  0/150/300/500ms round trip, with uniform random jitter added to each press's one-way trip
	  (seeded). It simulates delay only: no packet loss, no clock-sync error, no frame
	  quantisation, no human reaction spread. The hit rate is the share of 2000 sessions rescued.
	2 Return routes: every walkable tile of every archetype over 20 seeds (Logic/LayoutGen +
	  Logic/StationReach, the walk over tiles through building doors), one-way back to the nearest
	  door at a jog (Crew.WalkSpeed) and at the best sprint the stamina bar allows, plus
	  DOOR_ALLOWANCE seconds for boarding. Movement and stamina are the game's own numbers.

	Run with:  lune run limbloss-gate
]]

local Loader = require("./lib/Loader")

local function load(node: any): any
	return Loader.requireNode(node)
end

local Shared = Loader.roots.Shared
local Rescue = load(Shared.Logic.Rescue)
local LayoutGen = load(Shared.Logic.LayoutGen)
local StationReach = load(Shared.Logic.StationReach)
local Stations = load(Shared.Config.Stations)
local Tuning = load(Shared.Config.Tuning)
local Rng = load(Shared.Util.Rng)

local DOOR_ALLOWANCE = 2 -- seconds to reach a door opening and board (assumed, not measured)
local SESSIONS = 2000
local SEEDS = 20

print("## Rescue timing (simulated delay only)")
print("| RTT ms | jitter ms (±) | rescued | first failure reason |")
print("|---|---|---|---|")
for _, rtt in { 0, 0.15, 0.3, 0.5 } do
	for _, jitter in { 0, 0.03, 0.06 } do
		local rng = Rng.new(Rng.derive(7, `rescue{rtt}{jitter}`))
		local wins = 0
		local reasons: { [string]: number } = {}
		for i = 1, SESSIONS do
			local s = Rescue.new(i, 0, rtt)
			Rescue.join(s, 1, 0.5, rtt)
			for beat = 1, Rescue.BeatCount do
				local at = Rescue.beatAt(s, beat)
				local arrive = at + rtt / 2 + (rng:next() * 2 - 1) * jitter
				Rescue.tick(s, arrive)
				if Rescue.resolved(s) then
					break
				end
				Rescue.press(s, 1, beat, at, arrive)
			end
			Rescue.tick(s, 10)
			if s.phase == "Rescued" then
				wins += 1
			else
				reasons[s.why or "?"] = (reasons[s.why or "?"] or 0) + 1
			end
		end
		local top, n = "-", 0
		for why, count in reasons do
			if count > n then
				top, n = why, count
			end
		end
		print(
			string.format("| %d | %d | %.1f%% | %s |", rtt * 1000, jitter * 1000, wins / SESSIONS * 100, top)
		)
	end
end

local crew = Tuning.Crew
local function oneWay(studs: number, sprint: boolean): number
	return StationReach.roundTrip(studs / 2, crew, sprint) + DOOR_ALLOWANCE
end

print("")
print(`## Return routes ({SEEDS} seeds, every walkable tile, +{DOOR_ALLOWANCE}s boarding)`)
print(
	"| archetype | p10 studs | median | p90 | max | jog p90 s | sprint p90 s | fits 25/35/45 (jog) | fits 25/35/45 (sprint) |"
)
print("|---|---|---|---|---|---|---|---|---|")
for _, id in Stations.Order do
	local dists: { number } = {}
	for seed = 1, SEEDS do
		local plan = LayoutGen.generate(id, seed * 7919, 1)
		local reach = StationReach.measure(plan)
		for _, d in reach.dist do
			table.insert(dists, d)
		end
	end
	table.sort(dists)
	local function pct(p: number): number
		return dists[math.clamp(math.ceil(#dists * p), 1, #dists)]
	end
	local function fits(budget: number, sprint: boolean): string
		local ok = 0
		for _, d in dists do
			if oneWay(d, sprint) <= budget then
				ok += 1
			end
		end
		return string.format("%.0f%%", ok / #dists * 100)
	end
	print(
		string.format(
			"| %s | %d | %d | %d | %d | %.1f | %.1f | %s/%s/%s | %s/%s/%s |",
			id,
			pct(0.1),
			pct(0.5),
			pct(0.9),
			dists[#dists],
			oneWay(pct(0.9), false),
			oneWay(pct(0.9), true),
			fits(25, false),
			fits(35, false),
			fits(45, false),
			fits(25, true),
			fits(35, true),
			fits(45, true)
		)
	)
end
