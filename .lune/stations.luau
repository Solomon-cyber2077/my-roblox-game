--[[
	Station size report: per archetype, the area, the buildings, the loot, the farthest
	loot on foot (Logic/StationReach) and the stop's clock at the first and the last stop,
	with the walk there and back at a jog and at the best sprint the stamina bar allows.

	Run with:  lune run stations            (seed 424242)
	           lune run stations 7          (another seed)
]]

local process = require("@lune/process")

local Loader = require("./lib/Loader")

local function load(node: any): any
	return Loader.requireNode(node)
end

local Shared = Loader.roots.Shared
local LayoutGen = load(Shared.Logic.LayoutGen)
local StationReach = load(Shared.Logic.StationReach)
local DifficultyModel = load(Shared.Logic.DifficultyModel)
local Stations = load(Shared.Config.Stations)
local Tuning = load(Shared.Config.Tuning)

local seed = tonumber(process.args[1]) or 424242
local crew = Tuning.Crew
local stops = Tuning.Run.StationCount

print(
	string.format(
		"%-13s %9s %7s %4s %4s %5s %5s %6s %6s %6s %6s %6s",
		"archetype",
		"size",
		"area",
		"bld",
		"str",
		"loot",
		"far",
		"jog2x",
		"spr2x",
		"dwell1",
		"dwellN",
		"margin"
	)
)
for _, id in Stations.Order do
	local arch = Stations.List[id]
	local plan = LayoutGen.generate(id, seed, 1)
	local reach = StationReach.measure(plan)
	local jog = StationReach.roundTrip(reach.farthestLoot, crew, false)
	local sprint = StationReach.roundTrip(reach.farthestLoot, crew, true)
	local first =
		DifficultyModel.params(DifficultyModel.forStop(arch.minStation, stops, arch.tier), arch, 1, nil)
	local last = DifficultyModel.params(DifficultyModel.forStop(stops, stops, 3), arch, 4, nil)
	print(
		string.format(
			"%-13s %4dx%-4d %7d %4d %4d %5d %5d %6.1f %6.1f %6d %6d %6.2f",
			id,
			plan.length,
			plan.depth,
			reach.area,
			#plan.buildings,
			#plan.structures,
			#plan.containers + #plan.loose,
			reach.farthestLoot,
			jog,
			sprint,
			first.dwell,
			last.dwell,
			last.dwell / jog
		)
	)
	if reach.unreachable > 0 then
		print(`  {reach.unreachable} loot spots unreachable`)
	end
end
