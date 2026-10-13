local RunRules = require(Shared.Logic.RunRules)

describe("Hull drain", function()
	it("drains and bursts leaks only while the train is running between stops", function()
		for _, phase in RunRules.Phases do
			expect(RunRules.hullDrains(phase)).toBe(phase == "Cruise")
		end
		-- never at the vote, at a stop or on the platform
		expect(RunRules.hullDrains("Junction")).toBe(false)
		expect(RunRules.hullDrains("Dwell")).toBe(false)
		expect(RunRules.hullDrains("Arrival")).toBe(false)
		expect(RunRules.hullDrains("Departure")).toBe(false)
	end)
end)
