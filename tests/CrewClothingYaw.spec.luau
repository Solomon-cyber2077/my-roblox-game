local Config = require(Shared.Config.CrewClothing)
local Rules = require(Shared.Logic.CrewClothing)

describe("Crew clothing mesh orientation", function()
	local function recipe(yaw)
		local result = table.clone(Config.ById.uniform_stoker)
		result.validated = true
		result.shirt, result.pants, result.wornShirt, result.wornPants = 1, 2, 3, 4
		result.accessories = {
			{
				name = "Hat",
				mesh = 5,
				texture = 6,
				limb = "Head",
				size = { 1, 1, 1 },
				offset = { 0, 0, 0 },
				triangles = 12,
				yaw = yaw,
			},
		}
		return result
	end
	it("retains default orientation and accepts a half turn", function()
		expect(Rules.available(recipe(nil))).toBe(true)
		expect(Rules.available(recipe(180))).toBe(true)
	end)
	it("rejects nonfinite rotations before constructing a CFrame", function()
		expect(Rules.available(recipe(0 / 0))).toBe(false)
		expect(Rules.available(recipe(math.huge))).toBe(false)
	end)
end)
