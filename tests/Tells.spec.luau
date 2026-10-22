local Tuning = require(Shared.Config.Tuning)
local Tells = require(Shared.Logic.Tells)

local function stalker(x: number, z: number, state: string?, coil: boolean?): any
	return { x = x, z = z, state = state or "Stalk", coil = coil == true }
end

describe("Tells", function()
	it("leans the light away from a stalker inside r = 30", function()
		local look = Tells.compute(0, 0, { stalker(0, 20) }, 0)
		expect(look.strength > 0).toBe(true)
		expect(look.leanZ).toBeCloseTo(-1)
		expect(look.leanX).toBeCloseTo(0)
	end)

	it("keeps the flicker at or under 15%", function()
		for t = 0, 10, 0.05 do
			local look = Tells.compute(0, 0, { stalker(0, 1) }, t)
			expect(look.flicker <= Tuning.Stalk.FlickerMax + 1e-9).toBe(true)
			expect(look.flicker >= 0).toBe(true)
		end
	end)

	it("stutters the watch within 36 but leans only within 30", function()
		local look = Tells.compute(0, 0, { stalker(0, 33) }, 0)
		expect(look.stutter).toBe(true)
		expect(look.strength).toBe(0)
		expect(Tells.compute(0, 0, { stalker(0, 37) }, 0).stutter).toBe(false)
	end)

	it("rolls the breath off from 15 to 30 studs", function()
		expect(Tells.breath(10)).toBe(1)
		expect(Tells.breath(15)).toBe(1)
		expect(Tells.breath(22.5)).toBeCloseTo(0.5)
		expect(Tells.breath(30)).toBe(0)
	end)

	it("reads only Stalk and a coiling hunter", function()
		expect(Tells.compute(0, 0, { stalker(0, 10, "Hunt") }, 0).stutter).toBe(false)
		expect(Tells.compute(0, 0, { stalker(0, 10, "Hunt", true) }, 0).stutter).toBe(true)
		expect(Tells.compute(0, 0, { stalker(0, 10, "Prowl") }, 0).breath).toBe(0)
	end)

	it("takes the nearest stalker", function()
		local look = Tells.compute(0, 0, { stalker(0, 28), stalker(10, 0) }, 0)
		expect(look.leanX).toBeCloseTo(-1)
	end)

	it("clears within one second of leaving range", function()
		local value = 1
		for _ = 1, 60 do
			value = Tells.fade(value, 0, 1 / 60)
		end
		expect(value).toBeCloseTo(0, 1e-6)
	end)
end)
