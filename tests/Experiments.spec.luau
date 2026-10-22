local Config = require(Shared.Config.Experiments)
local Experiments = require(Shared.Logic.Experiments)

local ON_E1 = table.freeze({ id = "E1", salt = Config.E1.salt, arms = Config.E1.arms, enabled = true })
local ON_E2 = table.freeze({ id = "E2", salt = Config.E2.salt, arms = Config.E2.arms, enabled = true })

describe("Experiments", function()
	it("gives the same arm for the same run seed, wherever it is asked", function()
		for seed = 1, 200 do
			local arm = Experiments.arm(seed, ON_E1)
			expect(Experiments.arm(seed, ON_E1)).toBe(arm)
			expect(table.find(ON_E1.arms, arm) ~= nil).toBe(true)
		end
	end)

	it("splits crews about evenly and crosses E1 and E2 as an independent 2x2", function()
		local cells: { [string]: number } = {}
		local short = 0
		local runs = 4000
		for seed = 1, runs do
			local a, b = Experiments.arm(seed * 7919, ON_E1), Experiments.arm(seed * 7919, ON_E2)
			cells[a .. b] = (cells[a .. b] or 0) + 1
			if a == "Short" then
				short += 1
			end
		end
		expect(short / runs).toBeBetween(0.45, 0.55)
		for _, a in ON_E1.arms do
			for _, b in ON_E2.arms do
				expect((cells[a .. b] or 0) / runs).toBeBetween(0.21, 0.29)
			end
		end
	end)

	it("runs only when on and some crew member is eligible; a Studio override wins", function()
		expect(Experiments.pick(5, ON_E1, true, nil)).toBe(Experiments.arm(5, ON_E1))
		expect(Experiments.pick(5, ON_E1, false, nil)).toBe(nil)
		expect(Experiments.pick(5, Config.E1, true, nil)).toBe(nil) -- shipped off until G2
		expect(Experiments.pick(5, Config.E1, false, "Long")).toBe("Long")
		expect(Experiments.pick(5, ON_E1, true, "Nonsense")).toBe(Experiments.arm(5, ON_E1))
	end)

	it("logs arms as A and B", function()
		expect(Experiments.label(ON_E1, "Short")).toBe("A")
		expect(Experiments.label(ON_E1, "Long")).toBe("B")
		expect(Experiments.label(ON_E2, "Sighting")).toBe("A")
		expect(Experiments.label(ON_E2, "None")).toBe("B")
	end)

	it("stores a player's first exposed arm once and never changes it", function()
		local cohorts: { [string]: string } = {}
		expect(Experiments.expose(cohorts, ON_E1, "Long")).toBe(true)
		expect(Experiments.expose(cohorts, ON_E1, "Short")).toBe(false)
		expect(cohorts.E1).toBe("Long")
		expect(Experiments.expose(cohorts, ON_E2, "None")).toBe(true)
		expect(cohorts.E2).toBe("None")
	end)
end)
