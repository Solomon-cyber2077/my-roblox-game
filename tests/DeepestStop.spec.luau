local Economy = require(Shared.Logic.Economy)

describe("Economy.deepestStop", function()
	it("counts the stop a player died at, not only the stops they left", function()
		local t = Economy.emptyTally()
		t.stationsDeparted = 1 -- left stop 1 alive
		t.deepestStop = 2 -- stop 2's doors opened, then they were lost there
		expect(Economy.deepestStop(t)).toBe(2)
	end)

	it("is never below the stops left alive", function()
		local t = Economy.emptyTally()
		t.stationsDeparted = 3
		expect(Economy.deepestStop(t)).toBe(3)
	end)

	it("is zero for a run that never opened a door", function()
		expect(Economy.deepestStop(Economy.emptyTally())).toBe(0)
	end)
end)
