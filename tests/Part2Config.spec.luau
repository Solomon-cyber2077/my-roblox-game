local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)

local function number(value: any): boolean
	return type(value) == "number" and value == value and value < math.huge
end

local function expectNumbers(section: { [string]: any }, keys: { string })
	for _, key in keys do
		if not number(section[key]) then
			error(`{key} is not a number`)
		end
		expect(section[key]).toBeAtLeast(0)
	end
end

describe("Part 2 config (Config/Difficulty)", function()
	it("holds every part-2 section", function()
		for _, key in
			{
				"Aggression",
				"GrabDamage",
				"Threat",
				"PostGrab",
				"SkillCheck",
				"Hull",
				"Leaks",
				"Breakdown",
				"Tutorial",
			}
		do
			expect(type((Difficulty :: any)[key])).toBe("table")
		end
	end)

	it("gives aggression, damage, hull, leak and breakdown numbers", function()
		expectNumbers(
			Difficulty.Aggression,
			{ "SightRange", "AwarenessRange", "Persistence", "StrikeCooldown" }
		)
		expectNumbers(Difficulty.GrabDamage, { "DpsShare", "MaxBiteShare", "PinDpsShare", "BruteCrush" })
		expectNumbers(
			Difficulty.Hull,
			{ "Floor", "StarvingPerSecond", "RepairParts", "RepairAmount", "MarkersOffBoost" }
		)
		expectNumbers(Difficulty.Leaks, {
			"OneLeakTrip",
			"Growth",
			"MaxSeverity",
			"FirstShare",
			"Spacing",
			"Jitter",
			"EarlyCap",
			"EarlyUntilStop",
			"Cap",
			"PatchParts",
			"PatchHold",
			"HissRange",
			"HissRangeOff",
			"SteamRate",
			"SteamRateOff",
			"StudsToMetres",
		})
		expectNumbers(
			Difficulty.Breakdown,
			{ "StopSeconds", "LimpShare", "RallySeconds", "RallyRepairs", "RallyHold", "RallyRestore" }
		)
		expect(Difficulty.Aggression.AwarenessRange).toBeLessThan(Difficulty.Aggression.SightRange)
		expect(Difficulty.Breakdown.LimpShare).toBeGreaterThan(0)
		expect(Difficulty.Breakdown.LimpShare).toBeLessThan(1)
		expect(Difficulty.Hull.Floor).toBeGreaterThan(0)
		expect(Difficulty.Breakdown.RallyRestore).toBeGreaterThan(Difficulty.Hull.Floor)
	end)

	it("keeps the hull tiers in order inside the hull", function()
		local tiers = Difficulty.Hull.Tiers
		expect(tiers.Creak).toBeLessThan(Tuning.Train.IntegrityMax)
		expect(tiers.Flicker).toBeLessThan(tiers.Creak)
		expect(tiers.Emergency).toBeLessThan(tiers.Flicker)
		expect(tiers.Emergency).toBeGreaterThan(Difficulty.Hull.Floor)
	end)

	it("gives the threat curve a full count per crew size and a share from stop 1", function()
		local threat = Difficulty.Threat
		expect(#threat.FullByCrew).toBe(Tuning.Run.MaxCrew)
		expect(threat.StartShare).toBeGreaterThan(0)
		expect(threat.StartShare).toBeAtMost(1)
		expect(threat.FullAtStop).toBeGreaterThan(1)
		expect(threat.Minimum).toBeAtLeast(1)
	end)

	it("orders the post-grab schedule from stop 1", function()
		local schedule = Difficulty.PostGrab.Schedule
		expect(schedule[1].fromStop).toBe(1)
		for i = 2, #schedule do
			expect(schedule[i].fromStop).toBeGreaterThan(schedule[i - 1].fromStop)
			expect(schedule[i].immunity).toBeAtMost(schedule[i - 1].immunity)
		end
	end)

	it("keeps every skill-check zone inside one turn of the needle", function()
		local c = Difficulty.SkillCheck
		expect(#c.FinishByStop).toBe(#c.ZoneByStop)
		for i, zone in c.ZoneByStop do
			expect(c.LeadDegrees[2] + zone).toBeLessThan(360)
			if i > 1 then
				expect(zone).toBeAtMost(c.ZoneByStop[i - 1])
			end
		end
		expect(c.GreatShare).toBeGreaterThan(0)
		expect(c.GreatShare).toBeLessThan(1)
		expect(c.Gap[1]).toBeAtMost(c.Gap[2])
		expect(c.LatencyBase).toBeAtMost(c.LatencyMax)
	end)

	it("defines three tutorial tiers, each with a grace and a light scale", function()
		local tutorial = Difficulty.Tutorial
		expect(#tutorial.Tiers).toBe(tutorial.Runs)
		for _, tier in tutorial.Tiers do
			expect(tier.grace).toBeGreaterThan(0)
			expect(tier.safeLightScale).toBeGreaterThan(0)
			if tier.zoneDegrees then
				-- a wide zone pulls its lead in (Logic/SkillCheck), but must still fit after the shortest lead
				expect(Difficulty.SkillCheck.LeadDegrees[1] + tier.zoneDegrees).toBeLessThan(360)
			end
		end
		-- each run is lighter than the one before
		for i = 2, #tutorial.Tiers do
			expect(tutorial.Tiers[i].grace).toBeLessThan(tutorial.Tiers[i - 1].grace)
			expect(tutorial.Tiers[i].safeLightScale).toBeLessThan(tutorial.Tiers[i - 1].safeLightScale)
		end
		expect(Difficulty.SkillCheck.LeadDegrees[1] + tutorial.ScriptedGrab.ZoneDegrees).toBeLessThan(360)
	end)

	it("defines every tutorial prompt with a known moment, a tier and short text", function()
		local moments = {
			RunStart = true,
			OffTrain = true,
			AwayFromTrain = true,
			NearEdge = true,
			Grabbed = true,
			Cruise = true,
			Leak = true,
			Exhausted = true,
			Junction = true,
		}
		local ids = {}
		local tiers = {}
		for _, prompt in Difficulty.Tutorial.Prompts do
			expect(moments[prompt.when]).toBe(true)
			expect(ids[prompt.id]).toBe(nil)
			ids[prompt.id] = true
			expect(prompt.tier).toBeAtLeast(1)
			expect(prompt.tier).toBeAtMost(Difficulty.Tutorial.Runs)
			expect(#prompt.text).toBeGreaterThan(0)
			expect(#prompt.text).toBeLessThan(90)
			tiers[prompt.tier] = (tiers[prompt.tier] or 0) + 1
		end
		for tier = 1, Difficulty.Tutorial.Runs do
			expect(tiers[tier] or 0).toBeGreaterThan(0)
		end
		-- run 2 teaches the skill check in the owner's words
		expect(ids.SkillCheck).toBe(true)
		expect(Difficulty.Tutorial.PromptSeconds).toBeGreaterThan(0)
	end)
end)
