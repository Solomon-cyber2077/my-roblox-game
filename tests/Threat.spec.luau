local Difficulty = require(Shared.Config.Difficulty)
local Threat = require(Shared.Logic.Threat)

describe("Threat: post-grab protection", function()
	it("follows the stop schedule: 5/4/3 s with stagger, then 2 s without", function()
		local expected = {
			{ 1, 5, true },
			{ 2, 5, true },
			{ 3, 4, true },
			{ 4, 4, true },
			{ 5, 3, true },
			{ 6, 3, true },
			{ 7, 2, false },
			{ 8, 2, false },
			{ 10, 2, false },
		}
		for _, row in expected do
			local p = Threat.protection(row[1], nil)
			expect(p.immunity).toBe(row[2])
			expect(p.stagger).toBe(row[3])
		end
	end)

	it("gives the tutorial 5 s and a stagger at every stop", function()
		for tier = 1, Difficulty.Tutorial.Runs do
			for stop = 1, 10 do
				local p = Threat.protection(stop, tier)
				expect(p.immunity).toBe(5)
				expect(p.stagger).toBe(true)
			end
		end
		-- tier 0 is past the tutorial: the schedule again
		expect(Threat.protection(9, 0).stagger).toBe(false)
	end)
end)

describe("Threat: the curve", function()
	it("runs from 35% at stop 1 to 100% at stop 7 in even steps", function()
		expect(Threat.share(1)).toBeCloseTo(0.35)
		expect(Threat.share(7)).toBeCloseTo(1)
		expect(Threat.share(10)).toBeCloseTo(1)
		local step = Threat.share(2) - Threat.share(1)
		for stop = 2, 7 do
			expect(Threat.share(stop) - Threat.share(stop - 1)).toBeCloseTo(step)
		end
	end)

	it("keeps the full counts 3/4/5/6 from stop 7 and never drops below one", function()
		for crew, full in { 3, 4, 5, 6 } do
			expect(Threat.total(7, crew)).toBe(full)
			expect(Threat.total(10, crew)).toBe(full)
			for stop = 1, 10 do
				expect(Threat.total(stop, crew)).toBeAtLeast(1)
				expect(Threat.total(stop, crew)).toBeAtMost(full)
				if stop > 1 then
					expect(Threat.total(stop, crew)).toBeAtLeast(Threat.total(stop - 1, crew))
				end
			end
		end
		expect(Threat.total(1, 1)).toBe(1) -- 3 x 0.35 = 1.05
		expect(Threat.total(1, 4)).toBe(2) -- 6 x 0.35 = 2.1
		expect(Threat.total(4, 4)).toBe(4) -- 6 x 0.675 = 4.05
	end)
end)
