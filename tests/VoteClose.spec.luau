local Vote = require(Shared.Logic.Vote)

local options = {
	{ archetype = "Halt", distanceKm = 6, tier = 1 },
	{ archetype = "Market", distanceKm = 4, tier = 1 },
	{ archetype = "Viaduct", distanceKm = 8, tier = 1 },
} :: any

describe("Closing a junction ballot", function()
	it("drops the votes of crew who left or went down, so they can't decide the route", function()
		local votes = { ["1"] = 1, ["2"] = 1, ["3"] = 3 }
		local present = { ["3"] = true }
		local kept = Vote.prune(votes, function(key)
			return present[key] == true
		end)
		expect(kept["1"]).toBe(nil)
		expect(kept["3"]).toBe(3)
		expect(votes["1"]).toBe(1) -- the input is not changed
		expect(Vote.tally(kept, options, 0)).toBe(3)
		expect(Vote.tally(votes, options, 0)).toBe(1)
	end)

	it("tells a clear majority, a settled tie and an empty ballot apart", function()
		expect(Vote.result({ a = 1, b = 1, c = 2 }, 3)).toBe("majority")
		expect(Vote.result({ a = 1, b = 2 }, 3)).toBe("tie")
		expect(Vote.result({}, 3)).toBe("none")
		expect(Vote.result({ a = 9, b = 1.5 }, 3)).toBe("none") -- invalid ballots don't count
		expect(Vote.result({ a = 2 }, 3)).toBe("majority")
	end)

	it("buckets turnout against the crew who could vote", function()
		expect(Vote.turnout(0, 3)).toBe("none")
		expect(Vote.turnout(2, 3)).toBe("some")
		expect(Vote.turnout(3, 3)).toBe("all")
		expect(Vote.turnout(1, 0)).toBe("all")
	end)
end)
