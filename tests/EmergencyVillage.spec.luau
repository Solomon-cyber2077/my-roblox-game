local Breakdown = require(Shared.Logic.Breakdown)
local Difficulty = require(Shared.Config.Difficulty)
local JourneyPlan = require(Shared.Logic.JourneyPlan)
local LayoutGen = require(Shared.Logic.LayoutGen)
local LootRoll = require(Shared.Logic.LootRoll)
local Loot = require(Shared.Config.Loot)
local StationReach = require(Shared.Logic.StationReach)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)

local C = Difficulty.Breakdown
local VILLAGE = Stations.List.EmergencyVillage

describe("Emergency Village: the breakdown's states", function()
	it("runs again when enough parts came aboard, and a second breakdown still loses the train", function()
		local s = Breakdown.onFloor(Breakdown.new(), 0, true)
		expect(s.phase).toBe("Village")
		s = Breakdown.villageDone(s, C.VillageParts, C.VillageParts, 200)
		expect(s.phase).toBe("None")
		expect(s.count).toBe(1)
		expect(Breakdown.speedShare(s)).toBe(1)
		expect(Breakdown.onFloor(s, 300, true).phase).toBe("Lost")
	end)

	it("falls back on the halt and the rally when the crew comes back short", function()
		local s = Breakdown.onFloor(Breakdown.new(), 0, true)
		s = Breakdown.villageDone(s, C.VillageParts - 1, C.VillageParts, 200)
		expect(s.phase).toBe("Stopped")
		expect(s.endsAt).toBe(200 + C.StopSeconds)
		s = Breakdown.tick(s, 200 + C.StopSeconds)
		expect(s.phase).toBe("Rally")
		-- the rally's repairs, then the limp
		local done = false
		for _ = 1, C.RallyRepairs do
			s, done = Breakdown.repair(s)
		end
		expect(done).toBe(true)
		expect(s.phase).toBe("Limp")
	end)

	it("ignores a village result outside a village stop", function()
		local stopped = Breakdown.onFloor(Breakdown.new(), 0, false)
		expect(Breakdown.villageDone(stopped, 9, 3, 5)).toBe(stopped)
		local fresh = Breakdown.new()
		expect(Breakdown.villageDone(fresh, 9, 3, 5)).toBe(fresh)
	end)

	it("restores more hull than the rally and asks for a handful of parts", function()
		expect(C.VillageRestore).toBe(40)
		expect(C.VillageRestore).toBeGreaterThan(C.RallyRestore)
		expect(C.VillageParts).toBeAtLeast(1)
	end)
end)

describe("Emergency Village: the place", function()
	it("is not one of the stops and never on a ballot", function()
		expect(table.find(Stations.Order, "EmergencyVillage")).toBe(nil)
		expect(VILLAGE.weight).toBe(0)
		expect(VILLAGE.emergency).toBe(true)
	end)

	it("yields repair parts only", function()
		for kind in Loot.Containers do
			for _, entry in LootRoll.weights(kind, "Mid", VILLAGE) do
				if entry.weight > 0 then
					expect(Loot.Categories[entry.value]).toBe("parts")
				end
			end
		end
	end)

	it(
		"has no station on its bank, one lamp, its edge marked and every part reachable in the window",
		function()
			for seed = 1, 6 do
				local plan = LayoutGen.generate("EmergencyVillage", seed * 131, 1.2)
				local lamps, edge = 0, 0
				for _, prop in plan.props do
					expect(prop.kind ~= "Canopy" and prop.kind ~= "Bench" and prop.kind ~= "Sign").toBe(true)
					if prop.kind == "YardLamp" or prop.kind == "Lamp" then
						lamps += 1
					elseif prop.kind == "EdgeMark" then
						edge += 1
					end
				end
				expect(lamps).toBe(1)
				expect(edge).toBeGreaterThan(10)
				local reach = StationReach.measure(plan)
				expect(reach.unreachable).toBe(0)
				local jog = StationReach.roundTrip(reach.farthestLoot, Tuning.Crew, false)
				if C.VillageSeconds < jog * 2.5 then
					error(`{C.VillageSeconds} s window, the farthest part is {jog} s there and back`)
				end
			end
		end
	)
end)

describe("Emergency Village: the scenery", function()
	local function input(phase: string, station: any?, odometer: number, stationX: number?)
		return {
			phase = phase,
			active = true,
			run = {
				runId = "v",
				seed = 5,
				stopCount = Tuning.Run.StationCount,
				nextStop = 3,
				destination = { archetype = "Halt" },
				station = station,
			},
			odometer = odometer,
			speed = 0,
			now = 0,
			stationX = stationX,
		}
	end

	it("keeps the leg going when the village departs, and cuts the village where it docked", function()
		local plan = JourneyPlan.new()
		local village = { archetype = "EmergencyVillage", emergency = { needed = 3, found = 0 } }
		JourneyPlan.step(plan, input("Cruise", nil, 1000))
		local leg = plan.leg
		JourneyPlan.step(plan, input("Arrival", village, 5000, 0))
		expect(plan.upcoming and plan.upcoming.center).toBeCloseTo(5000, 1e-6)
		JourneyPlan.step(plan, input("Departure", village, 5000, 0))
		expect(plan.leg).toBe(leg)
		expect(plan.upcoming).toBe(nil)
		expect(plan.lastDock).toBeCloseTo(5000, 1e-6)
		-- a regular departure starts the next leg
		local station = { archetype = "Halt" }
		local other = JourneyPlan.new()
		JourneyPlan.step(other, input("Dwell", station, 9000, 0))
		local before = other.leg
		JourneyPlan.step(other, input("Departure", station, 9000, 0))
		expect(other.leg).toBe(before + 1)
	end)
end)
