local Footsteps = require(Shared.Logic.Footsteps)
local Audio = require(Shared.Config.Audio)
local Tuning = require(Shared.Config.Tuning)

describe("Footsteps", function()
	it("tells the train, snow, planks and gravel apart", function()
		local function ground(material, onTrain, slabKind, snowy)
			return { material = material, onTrain = onTrain, slabKind = slabKind, snowy = snowy }
		end
		expect(Footsteps.surface(ground("WoodPlanks", true, nil, false))).toBe("TrainFloor")
		expect(Footsteps.surface(ground("Snow", false, nil, false))).toBe("Snow")
		expect(Footsteps.surface(ground("Cobblestone", false, "Floor", true))).toBe("Snow")
		expect(Footsteps.surface(ground("Cobblestone", false, "Safe", true))).toBe("Plank")
		expect(Footsteps.surface(ground("WoodPlanks", false, "Foundation", false))).toBe("Plank")
		expect(Footsteps.surface(ground("Cobblestone", false, "Floor", false))).toBe("Gravel")
		expect(Footsteps.surface(ground("Ground", false, nil, false))).toBe("Gravel")
	end)

	it("steps faster as you run, and not at all standing still", function()
		expect(Footsteps.interval(0)).toBe(nil)
		local walk = Footsteps.interval(Tuning.Crew.WalkSpeed) :: number
		local sprint = Footsteps.interval(Tuning.Crew.SprintSpeed) :: number
		expect(sprint).toBeLessThan(walk)
		expect(sprint).toBeAtLeast(Tuning.Footsteps.MinInterval)
		expect(walk).toBeAtMost(Tuning.Footsteps.MaxInterval)
	end)

	it("has a cue for every take of every surface, and alternates them", function()
		for _, surface in { "TrainFloor", "Snow", "Plank", "Gravel" } do
			local seen = {}
			for n = 1, Tuning.Footsteps.Takes[surface] do
				local cue = Footsteps.cue(surface, n)
				expect(Audio[cue] ~= nil).toBe(true)
				expect(Audio[cue].spatial).toBe(true)
				seen[cue] = true
			end
			expect(
				Footsteps.cue(surface, 1) ~= Footsteps.cue(surface, 2) or Tuning.Footsteps.Takes[surface] == 1
			).toBe(true)
		end
		expect(Audio.Breath.loop).toBe(true)
	end)
end)
