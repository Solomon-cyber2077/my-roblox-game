local Difficulty = require(Shared.Config.Difficulty)
local TimedEvents = require(Shared.Config.TimedEvents)
local Tuning = require(Shared.Config.Tuning)
local Schedule = require(Shared.Logic.TimedEventSchedule)

local LAST_CALL = Tuning.Run.LastCallSeconds

describe("TimedEventSchedule", function()
	it("warns 8 to 10 seconds ahead", function()
		expect(TimedEvents.Lead).toBeGreaterThan(7.99)
		expect(TimedEvents.Lead).toBeLessThan(10.01)
	end)

	it("never overlaps, keeps the cooldown and ends before Last Call", function()
		for seed = 1, 300 do
			for _, dwell in { 80, 94, 120, 148, 180, 240 } do
				local slots = Schedule.plan(dwell, LAST_CALL, seed)
				expect(#slots).toBeLessThan(TimedEvents.MaxPerStop + 1)
				for i, slot in slots do
					expect(slot.startAt - slot.warnAt).toBe(TimedEvents.Lead)
					expect(slot.endAt).toBeLessThan(Schedule.limit(dwell, LAST_CALL) + 1e-9)
					expect(slot.warnAt).toBeGreaterThan(TimedEvents.FirstWarn[1] - 1e-9)
					local before = slots[i - 1]
					if before then
						expect(slot.warnAt - before.endAt).toBeGreaterThan(TimedEvents.Gap[1] - 1e-9)
						expect(slot.id == before.id).toBe(false)
					end
				end
			end
		end
	end)

	it("gives a typical stop one or two events", function()
		local counts = { [0] = 0, [1] = 0, [2] = 0 }
		for seed = 1, 400 do
			local d = (seed % 5) / 4
			local dwell = Difficulty.Dwell[1] + (Difficulty.Dwell[2] - Difficulty.Dwell[1]) * d
			local n = #Schedule.plan(dwell, LAST_CALL, seed)
			counts[n] += 1
		end
		expect(counts[1] + counts[2]).toBeGreaterThan(counts[0] * 4)
		expect(counts[1]).toBeGreaterThan(0)
	end)

	it("is the same plan for the same stop", function()
		local a = Schedule.plan(140, LAST_CALL, 99)
		local b = Schedule.plan(140, LAST_CALL, 99)
		expect(#a).toBe(#b)
		for i, slot in a do
			expect(slot.id).toBe(b[i].id)
			expect(slot.warnAt).toBe(b[i].warnAt)
		end
	end)

	it("plans nothing when the doors are open too briefly", function()
		expect(#Schedule.plan(40, LAST_CALL, 3)).toBe(0)
	end)
end)
