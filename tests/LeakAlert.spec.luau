local LeakAlert = require(Shared.Logic.LeakAlert)

local ME = { x = 0, y = 0, z = 0 }

describe("LeakAlert", function()
	it("shows nothing without leaks: patching the last one clears it", function()
		local leaks = { { id = "B1", anchor = "CR1", x = 10, y = 0, z = 0 } }
		expect(LeakAlert.view(leaks, ME, true)).toBeTruthy()
		table.remove(leaks, 1)
		expect(LeakAlert.view(leaks, ME, true)).toBe(nil)
	end)

	it("shows nothing with Broken Things Markers off", function()
		local leaks = { { id = "B1", anchor = "CR1", x = 10, y = 0, z = 0 } }
		expect(LeakAlert.view(leaks, ME, false)).toBe(nil)
	end)

	it("names the nearest leak's car and its distance, and counts them all", function()
		local leaks = {
			{ id = "B1", anchor = "BV1", x = 80, y = 0, z = 0 },
			{ id = "B2", anchor = "CR2", x = 0, y = 0, z = -25 },
			{ id = "B3", anchor = "WS1", x = 40, y = 0, z = 0 },
		}
		local view = LeakAlert.view(leaks, ME, true) :: LeakAlert.View
		expect(view.count).toBe(3)
		expect(view.nearest.id).toBe("B2")
		expect(view.car).toBe("crew car")
		expect(view.distance).toBeCloseTo(25)
		expect(view.metres).toBe(7) -- 25 studs x 0.28
		expect(string.find(view.text, "3 STEAM LEAKS", 1, true) ~= nil).toBe(true)
		local one = LeakAlert.view({ leaks[3] }, ME, true) :: LeakAlert.View
		expect(string.find(one.text, "STEAM LEAK  ·  WORKSHOP", 1, true) ~= nil).toBe(true)
	end)

	it("falls back to 'train' for an unknown anchor", function()
		expect(LeakAlert.car(nil)).toBe("train")
		expect(LeakAlert.car("ZZ")).toBe("train")
	end)
end)
