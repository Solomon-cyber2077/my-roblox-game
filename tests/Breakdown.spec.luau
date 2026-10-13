local Breakdown = require(Shared.Logic.Breakdown)
local Difficulty = require(Shared.Config.Difficulty)

local C = Difficulty.Breakdown

describe("Breakdown", function()
	it("stops the train on the first breakdown, then rallies, then limps after the repairs", function()
		local s = Breakdown.new()
		expect(Breakdown.speedShare(s)).toBe(1)
		s = Breakdown.onFloor(s, 100, false)
		expect(s.phase).toBe("Stopped")
		expect(s.count).toBe(1)
		expect(Breakdown.speedShare(s)).toBe(0)
		s = Breakdown.tick(s, 100 + C.StopSeconds - 0.1)
		expect(s.phase).toBe("Stopped")
		s = Breakdown.tick(s, 100 + C.StopSeconds)
		expect(s.phase).toBe("Rally")
		expect(s.endsAt).toBe(100 + C.StopSeconds + C.RallySeconds)
		local done = false
		for i = 1, C.RallyRepairs do
			s, done = Breakdown.repair(s)
			expect(done).toBe(i == C.RallyRepairs)
		end
		expect(s.phase).toBe("Limp")
		expect(Breakdown.speedShare(s)).toBe(C.LimpShare)
		-- extra repairs after the rally do nothing
		local after, again = Breakdown.repair(s)
		expect(after).toBe(s)
		expect(again).toBe(false)
	end)

	it("loses the train when the rally runs out", function()
		local s = Breakdown.onFloor(Breakdown.new(), 0, false)
		s = Breakdown.tick(s, C.StopSeconds)
		s = Breakdown.repair(s)
		s = Breakdown.tick(s, C.StopSeconds + C.RallySeconds + 0.01)
		expect(s.phase).toBe("Lost")
		expect(Breakdown.lost(s)).toBe(true)
	end)

	it("loses the train on a second breakdown in the same run, even after a good rally", function()
		local s = Breakdown.onFloor(Breakdown.new(), 0, false)
		s = Breakdown.tick(s, C.StopSeconds)
		for _ = 1, C.RallyRepairs do
			s = Breakdown.repair(s)
		end
		s = Breakdown.arrive(s)
		expect(s.phase).toBe("None")
		expect(s.count).toBe(1)
		s = Breakdown.onFloor(s, 500, false)
		expect(s.phase).toBe("Lost")
		expect(s.count).toBe(2)
		-- nothing brings it back
		expect(Breakdown.arrive(s).phase).toBe("Lost")
		expect(Breakdown.onFloor(s, 600, true).phase).toBe("Lost")
	end)

	it("goes to the Emergency Village when one is granted, the first time only", function()
		local s = Breakdown.onFloor(Breakdown.new(), 0, true)
		expect(s.phase).toBe("Village")
		expect(Breakdown.speedShare(s)).toBe(0)
		s = Breakdown.arrive(s)
		expect(Breakdown.onFloor(s, 10, true).phase).toBe("Lost")
	end)

	it("adds stopped time whole to the trip, and the limp's shortfall", function()
		local stopped = Breakdown.onFloor(Breakdown.new(), 0, false)
		expect(Breakdown.delay(stopped, 2)).toBe(2)
		local limp = { phase = "Limp", count = 1, repairs = 3, needed = 3 } :: Breakdown.State
		expect(Breakdown.delay(limp, 2)).toBeCloseTo(2 * (1 - C.LimpShare))
		expect(Breakdown.delay(Breakdown.new(), 2)).toBe(0)
	end)
end)
