local Luminance = require(Shared.Logic.Luminance)
local Surfaces = require(Shared.Config.Surfaces)
local Tuning = require(Shared.Config.Tuning)

-- the dirtiest grade's shade, as Builders/Limewash applies it (tone jitter at its darkest)
local function worstShade(): number
	local grime = 0
	for _, g in Surfaces.Grime do
		grime = math.max(grime, g)
	end
	return 1 - grime - Surfaces.Limewash.tone
end

describe("Surface treatments (Config/Surfaces)", function()
	it("measures luminance on the Rec. 709 / WCAG scale", function()
		expect(Luminance.of({ 255, 255, 255 })).toBeCloseTo(1)
		expect(Luminance.of({ 0, 0, 0 })).toBeCloseTo(0)
		expect(Luminance.of({ 255, 0, 0 })).toBeCloseTo(0.2126)
		expect(Luminance.of({ 128, 128, 128 })).toBeCloseTo(0.2159, 0.001)
	end)

	it("keeps the lime-washed bands pale after the worst grade's grime", function()
		expect(Luminance.shaded(Surfaces.Limewash.color, worstShade())).toBeAtLeast(Surfaces.MinPale)
	end)

	it("keeps the coping and the train's lining pale", function()
		expect(Luminance.of(Surfaces.Coping.color)).toBeAtLeast(Surfaces.MinPale)
		expect(Luminance.of(Surfaces.Train.lining)).toBeAtLeast(Surfaces.MinPale)
	end)

	it("keeps the blue-brick margin dark, so the coping reads against it", function()
		expect(Luminance.of(Surfaces.Margin.color)).toBeAtMost(Surfaces.MaxMargin)
	end)

	it("gives every station grade a grime entry no darker than the floor allows", function()
		for id in Tuning.Visibility.Grades do
			local grime = Surfaces.Grime[id] or Surfaces.Grime.Default
			expect(Luminance.shaded(Surfaces.Limewash.color, 1 - grime - Surfaces.Limewash.tone)).toBeAtLeast(
				Surfaces.MinPale
			)
		end
	end)

	it("widens the coping past the docked train's overhang without moving its outer edge", function()
		expect(Surfaces.Coping.width).toBeGreaterThan(1.55)
		expect(Surfaces.Limewash.min).toBeLessThan(Surfaces.Limewash.max)
		expect(Surfaces.Limewash.share).toBeBetween(0.2, 0.8)
	end)
end)
