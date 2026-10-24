--!strict
-- Source recipe budgets are testable without pretending to render Roblox assets.
local Config = require(Shared.Config.CrewClothing)
describe("Crew clothing source geometry", function()
	it("keeps every complete outfit within the accessory and triangle budgets", function()
		for _, recipe in Config.List do
			local triangles = 0
			expect(#recipe.accessories <= Config.MaxAccessories).toBe(true)
			for _, accessory in recipe.accessories do
				triangles += accessory.triangles
			end
			expect(triangles <= Config.MaxTriangles).toBe(true)
		end
	end)
end)
