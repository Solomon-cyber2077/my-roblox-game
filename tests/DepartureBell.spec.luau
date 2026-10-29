local Bell = require(Shared.Logic.DepartureBell)

describe("DepartureBell branches", function()
	it("lets a solo crew ring at 40% (all aboard)", function()
		expect(Bell.branch(1, 1, 39.9, 100)).toBe(nil)
		expect(Bell.branch(1, 1, 40, 100)).toBe("all")
	end)

	it("covers 2, 3 and 4 living crew on both branches", function()
		for _, case in
			{
				-- aboard, living, elapsed share, expected
				{ 2, 2, 0.40, "all" },
				{ 1, 2, 0.40, nil },
				{ 1, 2, 0.60, "half" },
				{ 3, 3, 0.40, "all" },
				{ 2, 3, 0.59, nil },
				{ 2, 3, 0.60, "half" },
				{ 1, 3, 0.90, nil },
				{ 4, 4, 0.40, "all" },
				{ 3, 4, 0.50, nil },
				{ 2, 4, 0.60, "half" }, -- at least half, not a strict majority
				{ 1, 4, 0.99, nil },
			}
		do
			expect(Bell.branch(case[1], case[2], case[3] * 100, 100)).toBe(case[4])
		end
	end)

	it("needs someone alive", function()
		expect(Bell.branch(0, 0, 90, 100)).toBe(nil)
	end)

	it("measures u over the original dwell (LastCall included)", function()
		expect(Bell.share(80, 200)).toBeCloseTo(0.4)
		expect(Bell.branch(2, 2, 80, 200)).toBe("all")
		expect(Bell.branch(2, 2, 79, 200)).toBe(nil)
	end)
end)

describe("DepartureBell clock", function()
	it("sets departure to now + 30 only when that is sooner", function()
		expect(Bell.proposed(100, 60)).toBe(90)
		expect(Bell.proposed(100, 70)).toBe(nil) -- now + 30 = 100: not strictly shorter
		expect(Bell.proposed(100, 80)).toBe(nil) -- would extend: refused
		-- the minimum dwell: a pull never brings departure before the floor
		expect(Bell.proposed(100, 20, 70)).toBe(70)
		expect(Bell.proposed(100, 60, 70)).toBe(90)
		expect(Bell.proposed(100, 20, 100)).toBe(nil) -- the floor is the departure: nothing to shorten
	end)

	it("is idempotent: a second pull right after the first changes nothing", function()
		local first = Bell.proposed(200, 60) :: number
		expect(first).toBe(90)
		expect(Bell.proposed(first, 60)).toBe(nil)
		expect(Bell.proposed(first, 61)).toBe(nil)
	end)
end)
