--!strict

local Rules = require(Shared.Logic.CrewClothing)
local Config = require(Shared.Config.CrewClothing)
local Cosmetics = require(Shared.Config.Cosmetics)
local Progression = require(Shared.Config.Progression)
local Milestones = require(Shared.Logic.Milestones)
local Catalog = require(Shared.Logic.Catalog)

describe("CrewClothing", function()
	it("keeps the disabled gate closed", function()
		expect(Rules.canWear(Config.Default, {})).toBe(false)
		expect(Rules.resolve(Config.Default, {})).toBe(nil)
		expect(Rules.wear(10, "Cruise")).toBe(false)
	end)

	it("allows wear only at positive stops in active run phases", function()
		local active = { "Junction", "Cruise", "Arrival", "Dwell", "LastCall", "Departure", "Terminus" }
		for _, phase in active do
			expect(Rules.wearAt(3, phase)).toBe(true)
			expect(Rules.wearAt(2, phase)).toBe(false)
		end
		for _, phase in { "RunEnd", "Lobby", "Countdown", "Boarding", "Unknown" } do
			expect(Rules.wearAt(3, phase)).toBe(false)
		end
		expect(Rules.wearAt(0, "Cruise")).toBe(false)
		expect(Rules.wearAt(0 / 0, "Cruise")).toBe(false)
	end)

	it("rejects malformed or over-budget recipes", function()
		local base = Config.List[1]
		local function copy(overrides: { [string]: any }): any
			local result = table.clone(base)
			for key, value in overrides do
				result[key] = value
			end
			return result
		end
		-- gear with no uploaded mesh
		local unmeshed = table.clone(base.accessories[1])
		unmeshed.mesh = 0
		expect(Rules.available(copy({
			validated = true,
			shirt = 1,
			pants = 1,
			wornShirt = 1,
			wornPants = 1,
			accessories = { unmeshed },
		}))).toBe(false)
		expect(Rules.available(copy({
			validated = true,
			shirt = 1,
			pants = 1,
			wornShirt = 1,
			wornPants = 1,
			accessories = {
				{
					name = "x",
					mesh = 1,
					texture = 1,
					limb = "Root",
					size = { 1, 1, 1 },
					offset = { 0, 0, 0 },
					triangles = 1,
				},
			},
		}))).toBe(false)
		expect(Rules.available(copy({
			validated = true,
			shirt = 1,
			pants = 1,
			wornShirt = 1,
			wornPants = 1,
			accessories = {
				{
					name = "x",
					mesh = 1,
					texture = 1,
					limb = "Head",
					size = { 1, 1, 1 },
					offset = { 0, 0, 0 },
					triangles = Config.MaxTriangles + 1,
				},
			},
		}))).toBe(false)
	end)

	it("migrates only invalid or unowned uniform selections", function()
		local owned = { uniform_stoker_veteran = true }
		local profile =
			{ owned = owned, equipped = { Uniform = "uniform_stoker_veteran", Lantern = "lantern" } }
		Rules.migrate(profile)
		expect(profile.equipped.Uniform).toBe("uniform_stoker_veteran")
		expect(profile.equipped.Lantern).toBe("lantern")
		local invalid = { owned = {}, equipped = { Uniform = "missing" } }
		Rules.migrate(invalid)
		expect(invalid.equipped.Uniform).toBe(Config.Default)
	end)

	it("exposes five free starter identities without a dev bypass", function()
		local starterCount = 0
		for _, recipe in Config.List do
			if recipe.starter then
				starterCount += 1
				local def = Cosmetics.ById[recipe.id]
				expect(def ~= nil).toBe(true)
				assert(def ~= nil, "uniform catalog entry missing")
				expect(def.category).toBe("Uniform")
				expect(def.default).toBe(true)
				expect(Catalog.canUse({}, recipe.id, Cosmetics.DevUnlock.UserId, true)).toBe(false)
			end
		end
		expect(starterCount).toBe(5)
	end)

	it("derives both accomplishment uniforms from their records", function()
		for _, recipe in Config.List do
			if not recipe.starter then
				local def = Cosmetics.ById[recipe.id]
				expect(def ~= nil).toBe(true)
				assert(def ~= nil, "uniform catalog entry missing")
				expect(def.category).toBe("Uniform")
				expect(def.record ~= nil).toBe(true)
				local milestone = nil
				for _, candidate in Progression.Milestones do
					if candidate.reward.cosmetic == recipe.id then
						milestone = candidate
						break
					end
				end
				expect(milestone ~= nil).toBe(true)
				assert(milestone ~= nil, "uniform milestone missing")
				expect(milestone.reward.cosmetic).toBe(recipe.id)
				local requirements = Milestones.requirements(milestone)
				expect(#requirements).toBe(#def.record)
				for index, requirement in def.record do
					expect(requirements[index].stat).toBe(requirement.stat)
					expect(requirements[index].goal).toBe(requirement.goal)
				end
			end
		end
	end)

	it("awards accomplishment uniforms at the exact threshold once", function()
		for _, recipe in Config.List do
			if not recipe.starter then
				local def = Cosmetics.ById[recipe.id]
				assert(def ~= nil, "uniform catalog entry missing")
				local milestone = nil
				for _, candidate in Progression.Milestones do
					if candidate.reward.cosmetic == recipe.id then
						milestone = candidate
						break
					end
				end
				assert(milestone ~= nil, "uniform milestone missing")
				local below: { [string]: number } = {}
				for _, requirement in def.record do
					below[requirement.stat] = requirement.goal - 1
				end
				expect(table.find(Milestones.newlyCompleted(below, 0, {}), milestone.id)).toBe(nil)
				local atGoal: { [string]: number } = {}
				for _, requirement in def.record do
					atGoal[requirement.stat] = requirement.goal
				end
				local completed = Milestones.newlyCompleted(atGoal, 0, {})
				expect(table.find(completed, milestone.id) ~= nil).toBe(true)
				local claimed: { [string]: boolean } = { [milestone.id] = true }
				expect(table.find(Milestones.newlyCompleted(atGoal, 0, claimed), milestone.id)).toBe(nil)
			end
		end
	end)
end)
