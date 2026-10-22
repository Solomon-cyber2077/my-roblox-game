local Tuning = require(Shared.Config.Tuning)
local DifficultyModel = require(Shared.Logic.DifficultyModel)
local RouteGen = require(Shared.Logic.RouteGen)
local RouteModel = require(Shared.Logic.RouteModel)
local Routes = require(Shared.Logic.Routes)

local N = Tuning.Run.StationCount

describe("Routes", function()
	it("has a 5-stop Short Line and a 10-stop Long Line", function()
		expect(Routes.length("Short")).toBe(5)
		expect(Routes.length("Long")).toBe(10)
		expect(Routes.length(nil)).toBe(10)
		expect(Routes.of(5)).toBe("Short")
		expect(Routes.of(10)).toBe("Long")
		expect(Routes.of(nil)).toBe("Long")
	end)

	it("maps Short Line stop k to Long Line stop m(k) = 1, 2, 4, 6, 8", function()
		local expected = { 1, 2, 4, 6, 8 }
		for k = 1, 5 do
			expect(Routes.level("Short", k)).toBe(expected[k])
		end
		for k = 1, 10 do
			expect(Routes.level("Long", k)).toBe(k)
		end
	end)

	it("gives the Short Line the design's D at tier offset 0, below the Long Line's peak", function()
		local expected = { 0.080, 0.117, 0.252, 0.431, 0.643 }
		for k = 1, 5 do
			local d = DifficultyModel.forStop(Routes.level("Short", k), N, 2)
			expect(d).toBeCloseTo(expected[k], 3)
		end
		-- stops 1-2 match on both lines (the tutorial is intact), and the climax stays under the Long peak
		for k = 1, 2 do
			expect(DifficultyModel.forStop(Routes.level("Short", k), N, 2)).toBe(
				DifficultyModel.forStop(k, N, 2)
			)
		end
		expect(DifficultyModel.forStop(Routes.level("Short", 5), N, 2)).toBeLessThan(
			DifficultyModel.forStop(N, N, 2)
		)
		expect(DifficultyModel.forStop(N, N, 2)).toBeCloseTo(0.880, 3)
	end)

	it("treats a player as new until two runs reached RunEnd", function()
		expect(Routes.isNew(nil)).toBe(true)
		expect(Routes.isNew(0)).toBe(true)
		expect(Routes.isNew(1)).toBe(true)
		expect(Routes.isNew(2)).toBe(false)
	end)

	it("fixes the line for a crew with a new Hand and otherwise follows the vote", function()
		local route, fixed = Routes.decide(true, nil, 0, 3)
		expect(route).toBe("Short")
		expect(fixed).toBe(true)
		route, fixed = Routes.decide(true, "Long", 3, 0) -- E1's arm wins while E1 runs
		expect(route).toBe("Long")
		expect(fixed).toBe(true)
		route, fixed = Routes.decide(false, nil, 2, 1)
		expect(route).toBe("Short")
		expect(fixed).toBe(false)
		route = Routes.decide(false, nil, 1, 1) -- a tie goes Long
		expect(route).toBe("Long")
		route = Routes.decide(false, "Short", 0, 0) -- no votes: Long; E1 never applies to veterans
		expect(route).toBe("Long")
	end)
end)

describe("The first run's first leg", function()
	it("is FirstLegKm on every option, so its cruise is 25 s or less", function()
		for seed = 1, 50 do
			for _, option in RouteGen.options(seed, 1, 5, nil, Tuning.Run.FirstLegKm) do
				expect(option.distanceKm).toBe(Tuning.Run.FirstLegKm)
				expect(DifficultyModel.cruiseSeconds(option.distanceKm)).toBeAtMost(25)
			end
		end
	end)

	it("keeps the stations, tiers and later legs the same", function()
		for seed = 1, 50 do
			local plain = RouteGen.options(seed, 1, 5, nil)
			local short = RouteGen.options(seed, 1, 5, nil, Tuning.Run.FirstLegKm)
			expect(#short).toBe(#plain)
			for i, option in plain do
				expect(short[i].archetype).toBe(option.archetype)
				expect(short[i].tier).toBe(option.tier)
			end
			local later = RouteGen.options(seed, 2, 5, plain[1].archetype, Tuning.Run.FirstLegKm)
			local laterPlain = RouteGen.options(seed, 2, 5, plain[1].archetype)
			for i, option in laterPlain do
				expect(later[i].distanceKm).toBe(option.distanceKm)
			end
		end
	end)
end)

describe("Route durations (the report's model)", function()
	local function mean(route: Routes.Route, bell: RouteModel.Bell?): number
		local sum = 0
		for seed = 1, 100 do
			sum += RouteModel.seconds(seed, route, 1, bell)
		end
		return sum / 100 / 60
	end

	it("puts the Long Line near B.4's 47.6 min with no bell and the Short Line near 24-26", function()
		expect(mean("Long")).toBeBetween(46, 49)
		expect(mean("Short")).toBeBetween(23, 26)
	end)

	it("puts mixed bell use on the Short Line at about 21-23 min", function()
		expect(mean("Short", { share = 0.5, fraction = 0.6 })).toBeBetween(20, 23)
		expect(mean("Short", { share = 0.4, fraction = 1 })).toBeLessThan(mean("Short"))
	end)

	it("pays a Short Line for the stops it covers", function()
		local e = Tuning.Economy
		expect(RouteModel.brass("Short", true)).toBe(5 * e.BrassPerStation + e.BrassVictoryAlive)
		expect(RouteModel.brass("Long", true)).toBe(10 * e.BrassPerStation + e.BrassVictoryAlive)
		expect(RouteModel.brass("Short", false)).toBe(5 * e.BrassPerStation)
	end)
end)
