local fs = require("@lune/fs")

local DifficultyModel = require(Shared.Logic.DifficultyModel)
local Haul = require(Shared.Config.Haul)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)

-- The speeds MovementController actually gives the crew: it must read them from Tuning.Crew.
local function crewSpeeds(): (number, number)
	local source = fs.readFile("src/client/Controllers/MovementController.luau")
	assert(
		string.find(source, "local base = if sprinting then crew.SprintSpeed else crew.WalkSpeed", 1, true),
		"MovementController no longer sets speed from crew.SprintSpeed / crew.WalkSpeed"
	)
	assert(
		string.find(source, "local crew = Tuning.Crew", 1, true),
		"MovementController's crew is not Tuning.Crew"
	)
	return Tuning.Crew.WalkSpeed, Tuning.Crew.SprintSpeed
end

local HollowSpeed = require(Shared.Logic.HollowSpeed)
local Tutorial = require(Shared.Config.Tutorial)

describe("Hollow speed", function()
	it("preserves the sprint budget and recovery envelope", function()
		local crew = Tuning.Crew
		expect(crew.StaminaMax).toBe(100)
		expect(crew.StaminaDrainPerSecond).toBe(18)
		expect(crew.StaminaRegenPerSecond).toBe(22)
		expect(crew.StaminaRegenDelay).toBe(0.9)
		expect(crew.ExhaustedResume).toBe(0.35)
		expect(crew.WindedSeconds).toBe(1.6)
		expect(crew.WindedMultiplier).toBe(0.85)
		expect(Tuning.Hollow.LungeCooldown).toBe(3.5)
	end)

	it("keeps the normal speed ladder at both difficulty and pace endpoints", function()
		local walk, sprint = crewSpeeds()
		expect(walk).toBe(21)
		expect(sprint).toBe(31)
		local duo = walk * (1 - Haul.DuoPenalty)
		local solo = walk * (1 - Haul.SoloPenalty)
		local spread = Tuning.Hollow.PaceSpread
		for _, d in { 0, 1 } do
			local params = DifficultyModel.params(d, Stations.List.Halt, 1, nil)
			for name in Tuning.HollowKinds do
				for _, pace in { 1 - spread, 1 + spread } do
					local chase, lunge, duration =
						HollowSpeed.resolve(params.hollowChase, name, pace, false, nil, nil)
					assert(chase > duo and chase > solo, `{name} must gain on both carrier arrangements`)
					if d == 0 then
						assert(chase - walk >= 2 and chase - walk <= 6, `{name} D0 walk gap`)
					else
						assert(sprint - chase >= 3, `{name} D1 sprint gap`)
					end
					if name == "Brute" then
						expect(lunge).toBe(0)
					else
						assert(lunge > sprint, `{name} lunge must briefly overtake sprint`)
						expect(duration).toBe(0.55)
					end
				end
			end
		end
	end)

	it("keeps the first scripted Crawler absolute and scoped to tier 1 stop 2", function()
		for _, base in { 25, 26 } do
			for _, pace in { 0.94, 1.06 } do
				local chase, lunge, duration = HollowSpeed.resolve(base, "Crawler", pace, true, 1, 2)
				expect(chase).toBe(24)
				expect(lunge).toBe(40)
				expect(duration).toBe(0.55)
			end
		end
		assert(Tutorial.FirstCrawler.WarningSeconds >= 1.5, "first Crawler needs a readable warning")
		expect(HollowSpeed.isFirstCrawler("Crawler", false, 1, 2)).toBe(false)
		expect(HollowSpeed.isFirstCrawler("Stalker", true, 1, 2)).toBe(false)
		expect(HollowSpeed.isFirstCrawler("Crawler", true, 2, 1)).toBe(false)
		local legacy = HollowSpeed.resolve(25, "Crawler", 1, true, 2, 1)
		expect(legacy).toBe(25 * Tutorial.ScriptedGrab.ChaseScale)
	end)
end)
