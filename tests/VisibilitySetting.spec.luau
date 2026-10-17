local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Settings = require(Shared.Logic.Settings)
local Visibility = require(Shared.Logic.Visibility)
local Config = require(Shared.Config.Settings)
local Tuning = require(Shared.Config.Tuning)

local V = Tuning.Visibility
local KEY = V.Setting
local RANGE = Config.Ranges[KEY]

describe("Visibility setting", function()
	it("clamps into the slider's range on load and on the server", function()
		expect(Settings.clamp(KEY, 999)).toBe(tostring(RANGE.max))
		expect(Settings.clamp(KEY, "-5")).toBe(tostring(RANGE.min))
		expect(Settings.clamp(KEY, "24.6")).toBe(tostring(math.clamp(25, RANGE.min, RANGE.max)))
		expect(Settings.clamp(KEY, "far")).toBe(nil)
		expect(Settings.clamp(KEY, 0 / 0)).toBe(nil)
		expect(Settings.clamp(KEY, math.huge)).toBe(nil)
		expect(Settings.clamp("Hud", 5)).toBe(nil)
		expect(Settings.valid(KEY, "999")).toBe(true) -- accepted, then stored clamped
		expect(Settings.valid(KEY, {})).toBe(false)
		expect(Settings.read({ [KEY] = "999" })[KEY]).toBe(tostring(RANGE.max))
		expect(Visibility.radius("999")).toBe(V.RadiusMax)
	end)

	it("falls back to the dim-phone default, inside the safe range above the floor", function()
		expect(Settings.read(nil)[KEY]).toBe(tostring(V.Default))
		expect(Settings.read({ [KEY] = {} })[KEY]).toBe(tostring(V.Default))
		expect(Settings.read({ [KEY] = "lots" })[KEY]).toBe(tostring(V.Default))
		expect(Visibility.radius(Settings.Defaults[KEY])).toBe(V.Default)
		expect(Visibility.radius(nil)).toBe(V.Default)
		expect(RANGE.min).toBeAtMost(V.Default)
		expect(RANGE.max).toBeAtLeast(V.Default)
		expect(V.Default).toBeAtLeast(V.Radius) -- never darker than the floor the gates ran at
	end)

	it("survives a save and load round trip with the other settings", function()
		-- the profile is saved as JSON (DataStore); SettingsService stores the clamped string
		local profile = { settings = { Hud = "Hide" } }
		local sent = tostring(math.clamp(V.Radius + 4, RANGE.min, RANGE.max))
		expect(Settings.valid(KEY, sent)).toBe(true)
		profile.settings[KEY] = Settings.clamp(KEY, sent) or sent
		local loaded = serde.decode("json", serde.encode("json", profile))
		local read = Settings.read(loaded.settings)
		expect(read[KEY]).toBe(sent)
		expect(read.Hud).toBe("Hide")
		expect(Visibility.radius(read[KEY])).toBe(tonumber(sent))
	end)

	it("holds the floor in the chase, at every reach the slider allows", function()
		local C = V.Chase
		for studs = RANGE.min, RANGE.max do
			local radius = Visibility.radius(studs)
			-- the chase halves a night already at the floor; the floor is applied after it
			for i, channel in V.AmbientFloor do
				local chased = channel * C.Ambient
				local r, g, b = Visibility.floor(V.AmbientFloor, radius)
				expect(math.max(chased, ({ r, g, b })[i])).toBeAtLeast(channel)
			end
			-- lanterns reach further in the chase, never shorter than the floor
			expect(radius * C.LightRange).toBeAtLeast(radius)
		end
		-- AtmosphereController clamps last: Sky.floor wraps Sky.chase with the player's reach
		local source = fs.readFile("src/client/Controllers/AtmosphereController.luau")
		local floor = string.find(source, "Sky.floor(", 1, true)
		local chase = string.find(source, "Sky.chase(", 1, true)
		expect(floor ~= nil and chase ~= nil and floor < chase).toBe(true)
		expect(string.find(source, "Registry.VisibilityController.Radius()", 1, true) ~= nil).toBe(true)
	end)

	it(
		"is fair at the slider's lowest reach: the Quality cone covers a sprint's reaction distance",
		function()
			-- tools/visibility/thresholds.py: perception-response 0.75 s (Green 2000, expected hazard),
			-- stopping 0.1 s, input and network latency 0.15 s, at Tuning.Crew.SprintSpeed
			local reaction = Tuning.Crew.SprintSpeed * (0.75 + 0.1 + 0.15)
			local lowest = Visibility.radius(RANGE.min)
			expect(math.max(Tuning.CarriedLantern.ConeRange, lowest)).toBeAtLeast(reaction)
			-- Performance's cone (Budget.ConeRangePerformance) falls short of it: a Tuning decision left
			-- to the owner (docs/visibility/gates_45_fix1.md); it must at least clear the floor
			expect(V.Budget.ConeRangePerformance).toBeAtLeast(lowest)
			-- the slider never goes under the default floor, which the gates were run at
			expect(RANGE.min).toBe(V.Radius)
		end
	)

	it("is visual only: no detection, aggro, damage or loot code reads it", function()
		-- every file allowed to read the setting: the floor, the sky, the lanterns, the save
		local allowed = {
			["src/shared/Logic/Visibility.luau"] = true,
			["src/shared/Logic/Settings.luau"] = true,
			["src/shared/Config/Settings.luau"] = true,
			["src/shared/Config/Tuning.luau"] = true,
			["src/server/Services/SettingsService.luau"] = true,
			["src/client/Controllers/VisibilityController.luau"] = true,
			["src/client/Controllers/AtmosphereController.luau"] = true,
			["src/client/UI/LanternSlider.luau"] = true,
		}
		local patterns = {
			"Visibility%.Setting",
			"VisibilityController%.Radius",
			"Visibility%.radius",
			"Visibility%.scale",
			"Ranges%.Visibility",
			'GetAttribute%(%s*"Visibility"',
			"Defaults%.Visibility",
		}
		local readers = {}
		local function scan(dir: string)
			for _, entry in fs.readDir(dir) do
				local path = `{dir}/{entry}`
				if fs.isDir(path) then
					scan(path)
				elseif string.match(entry, "%.luau$") and not allowed[path] then
					local source = fs.readFile(path)
					for _, pattern in patterns do
						if string.find(source, pattern) then
							table.insert(readers, `{path} ({pattern})`)
						end
					end
				end
			end
		end
		scan("src")
		expect(table.concat(readers, ", ")).toBe("")
		-- and the server never reads it back except to save it
		local service = fs.readFile("src/server/Services/SettingsService.luau")
		expect(string.find(service, "GetAttribute", 1, true)).toBe(nil)
	end)
end)
