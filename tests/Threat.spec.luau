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
