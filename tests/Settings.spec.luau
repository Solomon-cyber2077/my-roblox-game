local Settings = require(Shared.Logic.Settings)

describe("Settings", function()
	it("defaults old profiles and malformed preferences safely", function()
		expect(Settings.read(nil)).toEqual(Settings.Defaults)
		expect(Settings.read({ GraphicsQuality = 5, Hud = "bad" })).toEqual(Settings.Defaults)
	end)
	it("retains supported saved choices", function()
		local saved = {
			GraphicsQuality = "Performance",
			BrokenThingMarkers = "Off",
			Hud = "Hide",
			Visibility = "24",
			Ambience = "Low",
			Camera = "Free",
		}
		expect(Settings.read(saved)).toEqual(saved)
	end)
	it("rejects unknown settings and values without changing the save", function()
		expect(Settings.valid("RunsStarted", "999")).toBe(false)
		expect(Settings.valid("GraphicsQuality", {})).toBe(false)
		expect(Settings.valid("Hud", "Always")).toBe(false)
		local saved = { GraphicsQuality = "bad", unrelated = true }
		Settings.read(saved)
		expect(saved.GraphicsQuality).toBe("bad")
		expect(saved.unrelated).toBe(true)
	end)
end)

describe("Broken thing marker eligibility", function()
	it("shows the first three started runs and hides the fourth", function()
		local saved = {}
		for index = 1, 4 do
			expect(Settings.startRun(saved, tostring(index), 0)).toBe(true)
			expect(Settings.markersVisible("FirstFew", saved.RunsStarted)).toBe(index <= 3)
		end
	end)
	it("does not count a stop, respawn or reconnect twice", function()
		local saved = {}
		expect(Settings.startRun(saved, "run-a", 0)).toBe(true)
		expect(Settings.startRun(saved, "run-a", 0)).toBe(false)
		expect(Settings.startRun(saved, "", 0)).toBe(false)
		expect(saved.RunsStarted).toBe(1)
	end)
	it("migrates existing runs and keeps the persisted start count", function()
		local saved = {}
		expect(Settings.startRun(saved, "new-run", 9)).toBe(true)
		expect(saved.RunsStarted).toBe(10)
		expect(Settings.runsStarted(saved, 3)).toBe(10)
	end)
	it("honors Always and Off regardless of experience", function()
		expect(Settings.markersVisible("Always", 99)).toBe(true)
		expect(Settings.markersVisible("Off", 0)).toBe(false)
		expect(Settings.runsStarted({ RunsStarted = 0 / 0 }, 0)).toBe(0)
		expect(Settings.runsStarted({ RunsStarted = -1 }, 0)).toBe(0)
	end)
end)
