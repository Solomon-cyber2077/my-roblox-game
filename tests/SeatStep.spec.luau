local SeatStep = require(Shared.Logic.SeatStep)

describe("Walk-on seats", function()
	-- a 2 x 1 x 2 cushion: its top is 0.5 above the part's centre

	it("takes a player standing on the cushion", function()
		expect(SeatStep.onCushion(0, 0.5, 0, 2, 1, 2)).toBe(true)
		expect(SeatStep.onCushion(0.5, 0.1, -0.5, 2, 1, 2)).toBe(true)
	end)

	it("ignores a player brushing past the side at floor level", function()
		expect(SeatStep.onCushion(1.2, -2, 0, 2, 1, 2)).toBe(false)
		expect(SeatStep.onCushion(0, -0.5, 0, 2, 1, 2)).toBe(false)
	end)

	it("ignores feet beside the cushion, past the margin", function()
		expect(SeatStep.onCushion(0, 0.5, 1.6, 2, 1, 2)).toBe(false)
	end)
end)
