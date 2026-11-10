local LightBudget = require(Shared.Logic.LightBudget)
local Tuning = require(Shared.Config.Tuning)

describe("LightBudget.keep", function()
	it("keeps the nearest lamps up to the cap", function()
		local keep = LightBudget.keep({ 50, 10, 80, 30, 60 }, 2, 0)
		expect(keep[2]).toBe(true)
		expect(keep[4]).toBe(true)
		expect(keep[1]).toBe(nil)
		expect(keep[3]).toBe(nil)
		expect(keep[5]).toBe(nil)
	end)

	it("never darkens a lamp right by the camera, even past the cap", function()
		local keep = LightBudget.keep({ 5, 6, 7, 90 }, 1, 10)
		expect(keep[1] and keep[2] and keep[3]).toBe(true)
		expect(keep[4]).toBe(nil)
	end)

	it("keeps them all when there are fewer than the cap", function()
		local keep = LightBudget.keep({ 40, 120 }, 14, 25)
		expect(keep[1] and keep[2]).toBe(true)
	end)

	it("cuts a full stop (64 lit) to the phone cap", function()
		local distances = {}
		for i = 1, 64 do
			distances[i] = 30 + i * 4 -- none inside the always radius
		end
		local n = 0
		for _ in LightBudget.keep(distances, Tuning.StationPhone.LightCap, Tuning.StationPhone.LightAlways) do
			n += 1
		end
		expect(n).toBe(Tuning.StationPhone.LightCap)
	end)
end)
