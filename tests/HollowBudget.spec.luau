local HollowBudget = require(Shared.Logic.HollowBudget)
local Tuning = require(Shared.Config.Tuning)

describe("HollowBudget", function()
	it("scales the Hollows at a stop by the players in the run", function()
		expect(HollowBudget.total(1)).toBe(3)
		expect(HollowBudget.total(2)).toBe(4)
		expect(HollowBudget.total(3)).toBe(5)
		expect(HollowBudget.total(4)).toBe(6)
	end)

	it("clamps crews outside the table", function()
		expect(HollowBudget.total(0)).toBe(Tuning.HollowCount.ByCrew[1])
		expect(HollowBudget.total(9)).toBe(Tuning.HollowCount.ByCrew[#Tuning.HollowCount.ByCrew])
	end)

	it("leaves room for the wanderer and the fog spawns beside the sleepers", function()
		for crew = 1, 4 do
			local total = HollowBudget.total(crew)
			local sleepers = HollowBudget.sleepers(total)
			expect(sleepers).toBeGreaterThan(-1)
			expect(sleepers).toBeLessThan(total)
		end
		expect(HollowBudget.sleepers(0)).toBe(0)
		expect(HollowBudget.sleepers(1)).toBe(0)
	end)
end)
