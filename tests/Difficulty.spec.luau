local DifficultyModel = require(Shared.Logic.DifficultyModel)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)

local N = Tuning.Run.StationCount

describe("DifficultyModel", function()
	it("runs the base curve from 0.08 at stop 1 to 0.88 at the last stop", function()
		expect(DifficultyModel.base(1, N)).toBeCloseTo(0.08)
		expect(DifficultyModel.base(N, N)).toBeCloseTo(0.88)
	end)

	it("rises at every stop", function()
		for n = 2, N do
			expect(DifficultyModel.base(n, N)).toBeGreaterThan(DifficultyModel.base(n - 1, N))
		end
	end)

	it("orders tiers and clamps to [0, 1]", function()
		for n = 1, N do
			local t1 = DifficultyModel.forStop(n, N, 1)
			local t2 = DifficultyModel.forStop(n, N, 2)
			local t3 = DifficultyModel.forStop(n, N, 3)
			expect(t1).toBeAtMost(t2)
			expect(t2).toBeLessThan(t3)
			expect(t1).toBeAtLeast(0)
			expect(t3).toBeAtMost(1)
		end
	end)

	it("makes every hazard harsher as D rises", function()
		local halt = Stations.List.Halt
		local easy = DifficultyModel.params(0, halt, 4, nil)
		local hard = DifficultyModel.params(1, halt, 4, nil)
		expect(hard.dwell).toBeLessThan(easy.dwell)
		expect(hard.fogStartU).toBeLessThan(easy.fogStartU)
		expect(hard.fogDps).toBeGreaterThan(easy.fogDps)
		expect(hard.collapseLag).toBeLessThan(easy.collapseLag)
		expect(hard.collapseWarn).toBeLessThan(easy.collapseWarn)
		expect(hard.spawnInterval).toBeLessThan(easy.spawnInterval)
		expect(hard.hollowCap).toBeGreaterThan(easy.hollowCap)
		expect(hard.chaseWindow).toBeLessThan(easy.chaseWindow)
		expect(hard.departureAccel).toBeGreaterThan(easy.departureAccel)
	end)

	it("never telegraphs a collapse for less than 1.2 seconds", function()
		for _, id in Stations.Order do
			for d = 0, 1, 0.1 do
				expect(DifficultyModel.params(d, Stations.List[id], 8, nil).collapseWarn).toBeAtLeast(
					1.2 - 1e-9
				)
			end
		end
	end)

	it("keeps every Hollow outrunnable by an unloaded sprinting player", function()
		for _, id in Stations.Order do
			local params = DifficultyModel.params(1, Stations.List[id], 8, nil)
			expect(params.hollowChase).toBeLessThan(Tuning.Crew.SprintSpeed)
			-- even the quickest kind, at the quick end of its pace
			for _, kind in Tuning.HollowKinds do
				local fastest = params.hollowChase * kind.chase * (1 + Tuning.Hollow.PaceSpread)
				expect(fastest).toBeLessThan(Tuning.Crew.SprintSpeed)
			end
		end
	end)

	it("gives each body its own pace: the Crawler bolts, the Brute plods", function()
		local kinds = Tuning.HollowKinds
		expect(kinds.Crawler.chase).toBeGreaterThan(kinds.Stalker.chase)
		expect(kinds.Stalker.chase).toBeGreaterThan(kinds.Brute.chase)
		-- same-kind hunters drift apart: no two share a pace exactly
		expect(Tuning.Hollow.PaceSpread).toBeGreaterThan(0)
	end)

	it("caps Hollows by crew size and difficulty", function()
		local halt = Stations.List.Halt
		expect(DifficultyModel.hollowCap(0, 1, 1)).toBe(1)
		expect(DifficultyModel.hollowCap(0.5, 4, 1)).toBe(6)
		expect(DifficultyModel.hollowCap(1, 8, 1)).toBe(11)
		expect(DifficultyModel.params(0.5, halt, 4, nil).hollowCap).toBe(5) -- 0.8 bias, a small booking hall
	end)

	it("keeps big stops open longer and fuller than small ones", function()
		local halt = DifficultyModel.params(0.5, Stations.List.Halt, 4, nil)
		local school = DifficultyModel.params(0.5, Stations.List.Schoolhouse, 4, nil)
		expect(school.dwell).toBeGreaterThan(halt.dwell * 1.4)
		expect(school.hollowCap).toBeGreaterThan(halt.hollowCap)
	end)

	it("applies upgrades", function()
		local halt = Stations.List.Halt
		local base = DifficultyModel.params(0.5, halt, 4, nil)
		local upgraded =
			DifficultyModel.params(0.5, halt, 4, { SteamWhistle = 2, Floodlamps = 1, ArmorPlating = 2 })
		expect(upgraded.chaseWindow).toBeCloseTo(base.chaseWindow + 2)
		expect(upgraded.safeBand).toBe(base.safeBand + 6)
		expect(upgraded.fogDps).toBeCloseTo(base.fogDps * 0.85)
		expect(upgraded.breachRate).toBeCloseTo(base.breachRate * 0.75 ^ 2)
	end)

	it("matches the published dwell range of 60 to 95 seconds before archetype scaling", function()
		local neutral = table.clone(Stations.List.CoalYard)
		neutral.landmarks = nil
		expect(DifficultyModel.params(0, neutral, 1, nil).dwell).toBe(95)
		expect(DifficultyModel.params(1, neutral, 1, nil).dwell).toBe(60)
	end)
end)
