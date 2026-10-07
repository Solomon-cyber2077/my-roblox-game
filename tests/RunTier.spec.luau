local RunTier = require(Shared.Logic.RunTier)
local DifficultyModel = require(Shared.Logic.DifficultyModel)
local Economy = require(Shared.Logic.Economy)
local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)

local N = Tuning.Run.StationCount

describe("RunTier", function()
	it("leaves tier 1 unchanged and adds a fixed offset per tier", function()
		expect(RunTier.offset(1)).toBe(0)
		expect(RunTier.offset(3)).toBeCloseTo(2 * Difficulty.RunTier.OffsetPerTier)
		expect(DifficultyModel.forStop(3, N, 2, 1)).toBeCloseTo(DifficultyModel.forStop(3, N, 2))
		expect(DifficultyModel.forStop(3, N, 2, 4)).toBeGreaterThan(DifficultyModel.forStop(3, N, 2, 1))
		expect(DifficultyModel.forStop(N, N, 3, 5)).toBeAtMost(1)
	end)

	it("clamps tiers to 1..Max", function()
		expect(RunTier.clamp(0)).toBe(1)
		expect(RunTier.clamp(99)).toBe(Difficulty.RunTier.Max)
		expect(RunTier.clamp(nil)).toBe(1)
	end)

	it("unlocks the next tier only on a victory, capped at Max", function()
		expect(RunTier.afterRun(1, 1, true)).toBe(2)
		expect(RunTier.afterRun(1, 1, false)).toBe(1)
		expect(RunTier.afterRun(3, 1, true)).toBe(3)
		expect(RunTier.afterRun(5, 5, true)).toBe(5)
	end)

	it("limits the crew to its lowest unlocked tier", function()
		expect(RunTier.crewMax({ 4, 2, 5 })).toBe(2)
		expect(RunTier.crewMax({})).toBe(1)
	end)

	it("pays about 20% more Brass per tier above 1", function()
		local tally = Economy.emptyTally()
		tally.stationsDeparted = 10
		local base = Economy.payout(tally, { outcome = nil, dailyBonus = false, soloCharter = false }).brass
		local tier3 =
			Economy.payout(tally, { outcome = nil, dailyBonus = false, soloCharter = false, tier = 3 })
		expect(tier3.brass).toBe(math.floor(base * 1.4))
		expect(tier3.xp).toBe(
			Economy.payout(tally, { outcome = nil, dailyBonus = false, soloCharter = false }).xp
		)
	end)
end)
