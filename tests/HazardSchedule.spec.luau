local DifficultyModel = require(Shared.Logic.DifficultyModel)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local LayoutGen = require(Shared.Logic.LayoutGen)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)

local SAFE = Tuning.World.SafeStrip

local function setup(id, d)
	local arch = Stations.List[id]
	local params = DifficultyModel.params(d, arch, 4, nil)
	return params, { depth = arch.depth, safe = SAFE }, arch
end

describe("HazardSchedule", function()
	it("holds the fog beyond the far edge until its start time", function()
		local params, geo = setup("Halt", 0.3)
		local t0 = HazardSchedule.fogStartTime(params)
		expect(HazardSchedule.fogFront(params, geo, 0)).toBeGreaterThan(geo.depth)
		expect(HazardSchedule.fogFront(params, geo, t0)).toBeGreaterThan(geo.depth)
	end)

	it("moves the fog toward the train and stops at its end depth", function()
		for _, id in Stations.Order do
			for d = 0, 1, 0.25 do
				local params, geo = setup(id, d)
				local previous = math.huge
				for t = 0, params.dwell, 1 do
					local z = HazardSchedule.fogFront(params, geo, t)
					expect(z).toBeAtMost(previous + 1e-9)
					previous = z
				end
				expect(HazardSchedule.fogFront(params, geo, params.dwell)).toBeCloseTo(
					HazardSchedule.fogEndZ(params, geo)
				)
				expect(HazardSchedule.fogEndZ(params, geo)).toBeGreaterThan(SAFE)
			end
		end
	end)

	it("never collapses the safe strip", function()
		for _, id in Stations.Order do
			for d = 0, 1, 0.25 do
				local params, geo = setup(id, d)
				for t = 0, params.dwell + 20, 0.5 do
					expect(HazardSchedule.collapseFront(params, geo, t)).toBeAtLeast(SAFE)
				end
				expect(HazardSchedule.collapseTimeAt(params, geo, SAFE - 0.1)).toBe(nil)
			end
		end
	end)

	it("agrees between the closed-form collapse time and the front", function()
		local params, geo = setup("CoalYard", 0.6)
		for z = SAFE, geo.depth - 1, 6 do
			local at = HazardSchedule.collapseTimeAt(params, geo, z)
			if at then
				expect(HazardSchedule.collapseFront(params, geo, at)).toBeCloseTo(
					math.min(z, geo.depth + 8),
					0.05
				)
				expect(at).toBeAtMost(params.dwell)
			end
		end
	end)

	it("keeps the collapse behind the fog", function()
		local params, geo = setup("Market", 0.7)
		for t = 0, params.dwell, 0.5 do
			expect(HazardSchedule.collapseFront(params, geo, t)).toBeAtLeast(
				HazardSchedule.fogFront(params, geo, t) - 1e-6
			)
		end
	end)

	it("schedules collapse events with their telegraph, in time order", function()
		local params, geo = setup("Viaduct", 0.8)
		local plan = LayoutGen.generate("Viaduct", 42, params.lootMul)
		local refs = {}
		for _, slab in plan.slabs do
			table.insert(refs, { id = slab.id, z = slab.z, kind = slab.kind })
		end
		local events = HazardSchedule.collapsePlan(params, geo, refs, 42)
		expect(#events).toBeGreaterThan(0)
		local last = -1
		for _, event in events do
			expect(event.at).toBeAtLeast(last)
			expect(event.at - event.warnAt).toBeAtMost(params.collapseWarn + 1e-9)
			expect(event.slab ~= 1).toBe(true)
			last = event.at
		end
	end)

	it("spawns more Hollows on harder stops and only inside the dwell", function()
		local easyParams = setup("SignalWorks", 0.1)
		local hardParams = setup("SignalWorks", 0.9)
		local easy = HazardSchedule.spawnTimes(easyParams, 7)
		local hard = HazardSchedule.spawnTimes(hardParams, 7)
		expect(#hard).toBeGreaterThan(#easy)
		for _, t in hard do
			expect(t).toBeBetween(hardParams.firstSpawnU * hardParams.dwell - 1e-6, hardParams.dwell + 1e-6)
		end
	end)

	it("rises in intensity toward departure", function()
		local params = setup("Halt", 0.5)
		expect(HazardSchedule.intensity(params, 0)).toBe(0)
		expect(HazardSchedule.intensity(params, params.dwell)).toBeCloseTo(1, 0.11)
		expect(HazardSchedule.intensity(params, params.dwell * 0.5)).toBeLessThan(
			HazardSchedule.intensity(params, params.dwell * 0.9)
		)
	end)
end)
