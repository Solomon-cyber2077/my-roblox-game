local Config = require(Shared.Config.CrewClothing)

describe("Crew clothing hat policy", function()
	it("keeps every catalog recipe hat-free", function()
		for _, recipe in Config.List do
			expect(#recipe.accessories).toBe(1)
			expect(recipe.accessories[1].name).toBe("Gear")
			expect(recipe.accessories[1].limb).toBe("Torso")
		end
	end)
end)
