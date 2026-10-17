local Threshold = require(Shared.Logic.Threshold)
local Tuning = require(Shared.Config.Tuning)

local T = Tuning.Threshold

local function run(out: number, inside: boolean, seconds: number): number
	for _ = 1, math.round(seconds * 60) do
		out = Threshold.stepOut(out, inside, 1 / 60)
	end
	return out
end

describe("Threshold", function()
	it("keeps both crossfades at or under a second and a half", function()
		expect(T.FadeOut <= 1.5).toBe(true)
		expect(T.FadeIn <= 1.5).toBe(true)
		expect(run(0, false, 1.5)).toBe(1)
		expect(run(1, true, 1.5)).toBe(0)
	end)
	it("fades rather than cuts", function()
		local half = run(0, false, T.FadeOut / 2)
		expect(half > 0.3 and half < 0.7).toBe(true)
	end)
	it("closes the walls over the outside almost at once on boarding", function()
		local shelter = 0
		for _ = 1, 6 do -- a tenth of a second
			shelter = Threshold.stepShelter(shelter, true, 1, 1 / 60)
		end
		expect(shelter).toBe(1)
	end)
	it("opens the walls with the crossfade on the way out", function()
		expect(Threshold.stepShelter(1, false, 0, 1 / 60)).toBe(1)
		expect(Threshold.stepShelter(1, false, 0.5, 1 / 60)).toBe(0.5)
		expect(Threshold.stepShelter(1, false, 1, 1 / 60)).toBe(0)
	end)
	it("holds the sill with a margin both ways", function()
		-- just past the wall: still inside if you were, still out if you were
		local edge = 2 + T.Margin / 2
		expect(Threshold.within(0, 0, edge, 10, 5, 2, Threshold.grow(true))).toBe(true)
		expect(Threshold.within(0, 0, edge, 10, 5, 2, Threshold.grow(false))).toBe(false)
		expect(Threshold.within(0, 0, 2 - T.Margin * 2, 10, 5, 2, Threshold.grow(false))).toBe(true)
	end)
end)
