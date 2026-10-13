local DifficultyModel = require(Shared.Logic.DifficultyModel)
local LayoutGen = require(Shared.Logic.LayoutGen)
local StationReach = require(Shared.Logic.StationReach)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)
local LootRoll = require(Shared.Logic.LootRoll)

local SEEDS = 8
local STOPS = Tuning.Run.StationCount

-- every regular stop and the Emergency Village, SEEDS layouts each, generated once
local IDS = table.clone(Stations.Order)
table.insert(IDS, "EmergencyVillage")
local cache: { { id: string, arch: any, plan: any } } = {}
local function eachPlan(fn: (string, any, any) -> ())
	if #cache == 0 then
		for _, id in IDS do
			for seed = 1, SEEDS do
				table.insert(cache, {
					id = id,
					arch = Stations.List[id],
					plan = LayoutGen.generate(id, seed * 7919 + 11, 1.35),
				})
			end
		end
	end
	for _, entry in cache do
		fn(entry.id, entry.arch, entry.plan)
	end
end

describe("Station reach", function()
	it("reaches every container and pickup on foot from the train", function()
		eachPlan(function(id, _, plan)
			local reach = StationReach.measure(plan)
			if reach.unreachable > 0 then
				error(`{id}: {reach.unreachable} loot spots unreachable`)
			end
		end)
	end)

	it("leaves no walkable ground cut off from the platform", function()
		eachPlan(function(id, _, plan)
			local reach = StationReach.measure(plan)
			for gz = plan.safeRows, plan.rows - 1 do
				for gx = 0, plan.cols - 1 do
					local key = gz * plan.cols + gx
					if not plan.blocked[key] and reach.dist[key] == nil then
						error(`{id}: tile {gx},{gz} is cut off`)
					end
				end
			end
		end)
	end)

	it("puts the Hollows' spawn lanes on the stop, along its far edge", function()
		eachPlan(function(id, arch, plan)
			expect(#plan.spawnLanes).toBe(8)
			for _, x in plan.spawnLanes do
				expect(math.abs(x)).toBeLessThan(arch.length / 2)
				local slab = LayoutGen.slabAt(plan, x, plan.depth - plan.tile / 2)
				if slab == nil then
					error(`{id}: spawn lane {x} is off the grid`)
				end
			end
			for _, sleeper in plan.sleepers do
				local building = plan.buildings[sleeper.building]
				expect(building ~= nil).toBe(true)
			end
		end)
	end)

	it("gives every container a zone the loot tables know", function()
		eachPlan(function(id, _, plan)
			for _, c in plan.containers do
				local ok = pcall(LootRoll.holdSeconds, c.kind, c.zone)
				if not ok then
					error(`{id}: no loot rules for a {c.kind} in zone {c.zone}`)
				end
			end
		end)
	end)

	it("keeps loot off the edge tiles, where the hazard rail stands", function()
		eachPlan(function(id, _, plan)
			for _, list in { plan.containers, plan.loose } do
				for _, spot in list do
					if not (spot :: any).building then
						local gx, gz = StationReach.tileOf(plan, spot.x, spot.z)
						if gx == 0 or gx == plan.cols - 1 or gz == plan.rows - 1 then
							error(`{id}: loot on the edge tile {gx},{gz}`)
						end
					end
				end
			end
		end)
	end)

	it("marks every open edge tile with a hazard rail, and lights the lip", function()
		eachPlan(function(id, arch, plan)
			local marked: { [number]: boolean } = {}
			local glows = 0
			for _, prop in plan.props do
				if prop.kind == "EdgeMark" then
					local gx, gz = StationReach.tileOf(plan, prop.x, prop.z)
					marked[gz * plan.cols + gx] = true
				elseif prop.kind == "EdgeGlow" then
					glows += 1
				end
			end
			for gz = plan.safeRows, plan.rows - 1 do
				for gx = 0, plan.cols - 1 do
					local onEdge = gx == 0 or gx == plan.cols - 1 or gz == plan.rows - 1
					local key = gz * plan.cols + gx
					local slab = LayoutGen.slabAt(
						plan,
						-plan.length / 2 + (gx + 0.5) * plan.tile,
						(gz + 0.5) * plan.tile
					)
					if
						onEdge
						and slab
						and slab.kind == "Floor"
						and not plan.blocked[key]
						and not marked[key]
					then
						error(`{id}: open edge tile {gx},{gz} has no hazard rail`)
					end
				end
			end
			expect(glows).toBeAtLeast(3)
			expect(glows).toBeAtMost(Stations.Edge.GlowLights + 1)
			local _ = arch
		end)
	end)

	it("gives the crew time to reach the farthest loot and back, with margin, at every stop", function()
		eachPlan(function(id, arch, plan)
			local reach = StationReach.measure(plan)
			local jog = StationReach.roundTrip(reach.farthestLoot, Tuning.Crew, false)
			local sprint = StationReach.roundTrip(reach.farthestLoot, Tuning.Crew, true)
			expect(sprint).toBeLessThan(jog)
			-- the hardest case: the tightest clock (D = 1) at the first stop it can be
			local params = DifficultyModel.params(1, arch, 4, nil, math.min(arch.minStation, STOPS))
			local open = params.dwell + params.lastCall
			if open < jog * 2.5 then
				error(`{id}: {open} s open, the farthest loot is {jog} s there and back at a jog`)
			end
		end)
	end)

	it("computes the clock from the stop's size and its index", function()
		for _, id in Stations.Order do
			local arch = Stations.List[id]
			local early = DifficultyModel.params(0.5, arch, 1, nil, 2)
			local late = DifficultyModel.params(0.5, arch, 1, nil, STOPS)
			expect(late.dwell).toBeGreaterThan(early.dwell)
			expect(DifficultyModel.dwell(0.5, arch, 2)).toBe(early.dwell)
		end
	end)

	it("paces a sprint by the stamina bar", function()
		local crew = Tuning.Crew
		-- a short dash is all sprint
		expect(StationReach.roundTrip(31, crew, true)).toBeCloseTo(2, 1e-6)
		-- a long haul averages between a jog and a sprint
		local pace = 2 * 2000 / StationReach.roundTrip(2000, crew, true)
		expect(pace).toBeGreaterThan(crew.WalkSpeed)
		expect(pace).toBeLessThan(crew.SprintSpeed)
	end)
end)
