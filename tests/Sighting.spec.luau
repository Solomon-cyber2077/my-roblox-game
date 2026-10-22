local Sighting = require(Shared.Logic.Sighting)

local function run(seconds: number, watchers: any, dt: number?): (any, string?, number)
	local state = Sighting.new()
	local step = dt or 0.1
	local t = 0
	while t < seconds - 1e-9 do
		local reason
		state, reason = Sighting.step(state, step, watchers)
		t += step
		if reason then
			return state, reason, t
		end
	end
	return state, nil, t
end

describe("Sighting", function()
	it("never withdraws before 3 s after it is first seen", function()
		local _, reason, t = run(20, { { id = 1, offTrain = true, sight = true, facing = true } })
		expect(reason).toBe("faced")
		expect(t >= 3 - 1e-6).toBe(true)
	end)

	it("withdraws after the minimum once every off-train member has seen it 1.5 s", function()
		local _, reason, t = run(20, {
			{ id = 1, offTrain = true, sight = true, facing = false },
			{ id = 2, offTrain = false, sight = false, facing = false }, -- aboard: not waited for
		})
		expect(reason).toBe("seen")
		expect(t).toBeCloseTo(3, 0.11)
	end)

	it("waits for an off-train member who has not seen it, up to 12 s", function()
		local _, reason, t = run(20, {
			{ id = 1, offTrain = true, sight = true, facing = false },
			{ id = 2, offTrain = true, sight = false, facing = false },
		})
		expect(reason).toBe("time")
		expect(t).toBeCloseTo(12, 0.11)
	end)

	it("withdraws at 12 s even if nobody ever saw it", function()
		local _, reason = run(20, { { id = 1, offTrain = true, sight = false, facing = false } })
		expect(reason).toBe("time")
	end)

	it("logs each player's line-of-sight seconds", function()
		local state = run(2, { { id = 1, offTrain = true, sight = true, facing = false } })
		expect(state.seen[1]).toBeCloseTo(2, 0.11)
	end)

	it("keeps the preferred 15-17 band and the 24-stud fallback", function()
		expect(Sighting.preferred(15)).toBe(true)
		expect(Sighting.preferred(17)).toBe(true)
		expect(Sighting.preferred(18)).toBe(false)
		expect(Sighting.fallback(24)).toBe(true)
		expect(Sighting.fallback(24.1)).toBe(false)
	end)
end)
