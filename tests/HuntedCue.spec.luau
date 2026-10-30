local HuntedCue = require(Shared.Logic.HuntedCue)
local Tuning = require(Shared.Config.Tuning)

local C = Tuning.HuntedCue
local W, H = 800, 400

describe("HuntedCue", function()
	it("fades in from Range to full strength at FullAt", function()
		expect(HuntedCue.strength(C.Range + 1)).toBe(0)
		expect(HuntedCue.strength(C.FullAt)).toBe(1)
		expect(HuntedCue.strength(0)).toBe(1)
		local mid = HuntedCue.strength((C.Range + C.FullAt) / 2)
		expect(mid).toBeCloseTo(0.5)
	end)

	it("shows nothing for a Hollow the player can already see", function()
		expect(HuntedCue.place(W / 2, H / 2, true, W, H)).toBe(nil)
		expect(HuntedCue.place(W * 0.8, H * 0.3, true, W, H)).toBe(nil)
	end)

	it("pins an off-screen Hollow to the edge on its side", function()
		local right = HuntedCue.place(W * 2, H / 2, true, W, H) :: any
		expect(right.x).toBeCloseTo(W * (1 - C.Inset))
		expect(right.y).toBeCloseTo(H / 2)
		expect(right.angle).toBeCloseTo(90)
		local top = HuntedCue.place(W / 2, -H, true, W, H) :: any
		expect(top.y).toBeCloseTo(H * C.Inset)
		expect(top.angle).toBeCloseTo(0)
	end)

	it("mirrors a Hollow behind the camera", function()
		-- behind and to the left projects to the right: the cue must point left
		local behindLeft = HuntedCue.place(W * 0.9, H / 2, false, W, H) :: any
		expect(behindLeft.x).toBeCloseTo(W * C.Inset)
		expect(behindLeft.angle).toBeCloseTo(-90)
		local straightBehind = HuntedCue.place(W / 2, H / 2, false, W, H) :: any
		expect(straightBehind.y).toBeCloseTo(H * (1 - C.Inset))
	end)
end)
