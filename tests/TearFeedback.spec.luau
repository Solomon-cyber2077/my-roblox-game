local Config = require(Shared.Config.Injury)
local TearFeedback = require(Shared.Logic.TearFeedback)

local C = Config.Tear

describe("TearFeedback", function()
	it("lets the tear land clean before the world goes dull", function()
		expect(TearFeedback.muffle(0)).toBe(0)
		expect(TearFeedback.muffle(C.MuffleDelay * 0.9)).toBe(0)
	end)

	it("holds the muffle at full depth, then lets go by the end of the shock", function()
		local held = C.MuffleDelay + C.MuffleAttack + C.MuffleHold * 0.5
		expect(TearFeedback.muffle(held)).toBe(1)
		expect(TearFeedback.muffle(C.ShockSeconds)).toBe(0)
		local prev = 1
		for i = 1, 20 do
			local t = C.MuffleDelay + C.MuffleAttack + C.MuffleHold + i * 0.1
			local m = TearFeedback.muffle(t)
			expect(m).toBeAtMost(prev)
			prev = m
		end
	end)

	it("rises without a jump", function()
		local step = 0.01
		local prev = 0
		for i = 1, math.floor(C.ShockSeconds / step) do
			local m = TearFeedback.muffle(i * step)
			expect(math.abs(m - prev)).toBeLessThan(0.1)
			prev = m
		end
	end)

	it("holds the screen's shock from the first frame, then lets it go", function()
		expect(TearFeedback.shock(0)).toBe(1)
		expect(TearFeedback.shock(C.MuffleDelay + C.MuffleAttack + C.MuffleHold)).toBe(1)
		expect(TearFeedback.shock(C.ShockSeconds)).toBe(0)
		expect(TearFeedback.shock(-0.1)).toBe(0)
	end)

	it("rings loudest at RingPeakAt and is silent outside the shock", function()
		expect(TearFeedback.ring(C.RingPeakAt)).toBeCloseTo(1)
		expect(TearFeedback.ring(0)).toBe(0)
		expect(TearFeedback.ring(C.ShockSeconds + 1)).toBe(0)
		expect(TearFeedback.ring(C.RingPeakAt * 0.5)).toBeBetween(0, 1)
	end)

	it("races the heart first and settles it", function()
		expect(TearFeedback.heartGap(0)).toBeCloseTo(C.HeartFast)
		expect(TearFeedback.heartGap(C.ShockSeconds)).toBeCloseTo(C.HeartSettled)
		expect(TearFeedback.heartGap(C.ShockSeconds * 0.5)).toBeBetween(C.HeartFast, C.HeartSettled)
	end)

	it("hits crewmates close by fully and those far off not at all", function()
		expect(TearFeedback.nearby(0)).toBe(1)
		expect(TearFeedback.nearby(C.NearStuds)).toBe(1)
		expect(TearFeedback.nearby(C.FarStuds)).toBe(0)
		expect(TearFeedback.nearby((C.NearStuds + C.FarStuds) / 2)).toBeBetween(0, 1)
	end)

	it("gives every player one voice of their own, in range", function()
		for _, id in { 1, 42, 11744048795, -1, -2, 987654321 } do
			local a, pa = TearFeedback.voice(id, 3)
			local b, pb = TearFeedback.voice(id, 3)
			expect(a).toBe(b)
			expect(pa).toBe(pb)
			expect(a).toBeBetween(1, 3)
			expect(pa).toBeBetween(C.VoicePitchLow, C.VoicePitchHigh)
		end
	end)

	it("spreads voices across players", function()
		local seen = {}
		for id = 1, 60 do
			seen[(TearFeedback.voice(id, 3))] = true
		end
		expect(seen[1] and seen[2] and seen[3]).toBe(true)
	end)
end)
