local Difficulty = require(Shared.Config.Difficulty)
local NpcQuest = require(Shared.Logic.NpcQuest)
local Tutorial = require(Shared.Logic.Tutorial)

describe("Tutorial tiers", function()
	it("is tier 1, 2, 3 on a player's first three runs, then over", function()
		expect(Tutorial.tier(0)).toBe(1)
		expect(Tutorial.tier(1)).toBe(2)
		expect(Tutorial.tier(2)).toBe(3)
		expect(Tutorial.tier(3)).toBe(0)
		expect(Tutorial.tier(40)).toBe(0)
	end)

	it("treats an unreadable count as a finished tutorial", function()
		expect(Tutorial.tier(0 / 0)).toBe(0)
		expect(Tutorial.tier(math.huge)).toBe(0)
		expect(Tutorial.tier(nil :: any)).toBe(0)
		expect(Tutorial.tier(-1)).toBe(0)
	end)

	it("rides at the crew's least experienced player's tier", function()
		expect(Tutorial.crewTier({ 0, 5, 2 })).toBe(1)
		expect(Tutorial.crewTier({ 2, 1 })).toBe(2)
		expect(Tutorial.crewTier({ 2, 9 })).toBe(3)
		expect(Tutorial.crewTier({ 3, 9 })).toBe(0)
		expect(Tutorial.crewTier({})).toBe(0)
	end)

	it("is the NPC errands' lowest-stage rule", function()
		local crews = { { 0, 5, 2 }, { 1, 2 }, { 3, 4 }, { 2 }, { 7, 0 } }
		for _, crew in crews do
			local lowest = NpcQuest.runStage(crew, Difficulty.Tutorial.Runs - 1)
			expect(Tutorial.crewTier(crew)).toBe(if lowest then lowest + 1 else 0)
		end
	end)

	it("hands out each tier's settings, none past the tutorial", function()
		expect(Tutorial.def(0)).toBe(nil)
		expect(Tutorial.def(nil)).toBe(nil)
		expect(Tutorial.def(1)).toBe(Difficulty.Tutorial.Tiers[1])
		expect(Tutorial.def(3)).toBe(Difficulty.Tutorial.Tiers[3])
	end)
end)
