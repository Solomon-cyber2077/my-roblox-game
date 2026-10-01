--[[
	Prints the difficulty tables quoted in the production blueprint, computed by
	the shipped modules (so the document can never drift from the game).

	lune run report
]]

local Loader = require("./lib/Loader")
local Shared = Loader.roots.Shared
local require = Loader.requireNode

local DifficultyModel = require(Shared.Logic.DifficultyModel)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local Tuning = require(Shared.Config.Tuning)

local N = Tuning.Run.StationCount
local neutral = {
	dwellMultiplier = 1,
	hazard = { collapse = 1, fog = 1, hollows = 1 },
}

local function round(x, digits)
	local m = 10 ^ (digits or 0)
	return math.floor(x * m + 0.5) / m
end

print("== D by stop and tier")
print("stop,tier1,tier2,tier3")
for n = 1, N do
	local tier1 = round(DifficultyModel.forStop(n, N, 1), 3)
	local tier2 = round(DifficultyModel.forStop(n, N, 2), 3)
	local tier3 = round(DifficultyModel.forStop(n, N, 3), 3)
	print(`{n},{tier1},{tier2},{tier3}`)
end

print("\n== Hazard parameters per stop (tier 2, neutral archetype, 4 crew, no upgrades)")
print(table.concat({
	"stop",
	"D",
	"dwell_s",
	"fog_starts_s",
	"fog_stops_pct",
	"fog_dps",
	"collapse_lag_s",
	"warn_s",
	"spawn_every_s",
	"hollow_cap",
	"hollow_chase",
	"hollow_dmg",
	"pull",
	"window_s",
	"loot_x",
	"breach_per_min",
}, ","))
for n = 1, N do
	local d = DifficultyModel.forStop(n, N, 2)
	local p = DifficultyModel.params(d, neutral, 4, nil)
	print(table.concat({
		n,
		round(d, 2),
		p.dwell,
		round(p.fogStartU * p.dwell),
		round(p.fogEndFraction * 100),
		round(p.fogDps, 1),
		round(p.collapseLag, 1),
		round(p.collapseWarn, 2),
		round(p.spawnInterval, 1),
		p.hollowCap,
		round(p.hollowChase, 1),
		p.hollowDamage,
		round(p.departureAccel, 2),
		round(p.chaseWindow, 2),
		round(p.lootMul, 2),
		round(p.breachRate * 60, 2),
	}, ","))
end

print("\n== Sample stop: fronts over time (stop 6, tier 2, depth 180)")
local d6 = DifficultyModel.forStop(6, N, 2)
local p6 = DifficultyModel.params(d6, neutral, 4, nil)
local geo = { depth = 180, safe = Tuning.World.SafeStrip }
print(`dwell={p6.dwell} lastCall={p6.lastCall} D={round(d6, 3)}`)
print("t,fog_z,collapse_z")
for t = 0, p6.dwell, 4 do
	local fogZ = round(math.min(HazardSchedule.fogFront(p6, geo, t), geo.depth), 1)
	local collapseZ = round(math.min(HazardSchedule.collapseFront(p6, geo, t), geo.depth), 1)
	print(`{t},{fogZ},{collapseZ}`)
end
local spawns = HazardSchedule.spawnTimes(p6, 12345)
local list = {}
for _, t in spawns do
	table.insert(list, tostring(round(t, 1)))
end
print(`spawns={table.concat(list, " ")}`)
