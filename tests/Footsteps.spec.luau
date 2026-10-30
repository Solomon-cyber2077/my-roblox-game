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

describe("Jumps and landings", function()
	local Foley = require(Shared.Config.Foley)

	it("keeps a step off a ledge quiet and makes a default jump a soft landing", function()
		expect(Footsteps.landing(20)).toBe(nil) -- off a one-stud ledge
		local jump = Footsteps.landing(53) -- a default 7.2-stud jump coming down
		expect(jump ~= nil and jump.kind == "Soft").toBe(true)
	end)

	it("makes a long fall hard and caps its level", function()
		local fall = Footsteps.landing(90)
		expect(fall ~= nil and fall.kind == "Hard").toBe(true)
		expect(fall and fall.gain).toBe(Foley.LandGainMax)
		local soft = Footsteps.landing(Foley.LandSoft)
		expect(soft and soft.gain).toBe(Foley.LandGainMin)
	end)

	it("sounds a jump only on a real push-off, once per hop", function()
		expect(Footsteps.jumped(50, 1)).toBe(true)
		expect(Footsteps.jumped(8, 1)).toBe(false) -- a bump or a ramp
		expect(Footsteps.jumped(50, Foley.JumpGap / 2)).toBe(false)
	end)

	it("scuffs once when a body breaks into a run, and re-arms only after slowing down", function()
		local fast, broke = Footsteps.sprint(false, 31)
		expect(fast).toBe(true)
		expect(broke).toBe(true)
		fast, broke = Footsteps.sprint(true, 31)
		expect(broke).toBe(false) -- still running: no second scuff
		fast, broke = Footsteps.sprint(true, 25) -- easing off a little keeps it armed off
		expect(fast).toBe(true)
		expect(broke).toBe(false)
		fast, broke = Footsteps.sprint(true, 21) -- back to a walk
		expect(fast).toBe(false)
		expect(select(2, Footsteps.sprint(fast, 31))).toBe(true)
		expect(Foley.SprintRearm).toBeLessThan(Foley.SprintFrom)
	end)

	it("has a cue for every new foley sound", function()
		for _, name in { "Jump", "LandHard", "ItemDrop" } do
			expect(Audio[name] ~= nil and Audio[name].spatial == true).toBe(true)
		end
	end)
end)

describe("Crew-slot boots", function()
	it("gives a joiner the lowest free slot and never moves anyone", function()
		expect(Footsteps.freeSlot({})).toBe(1)
		expect(Footsteps.freeSlot({ [1] = true, [2] = true })).toBe(3)
		expect(Footsteps.freeSlot({ [1] = true, [3] = true })).toBe(2) -- a left player's slot is reused
		expect(Footsteps.freeSlot({ [1] = true, [2] = true, [3] = true, [4] = true })).toBe(1)
	end)

	it("keeps four timbres far enough apart that the step jitter never blurs two together", function()
		local boots = Tuning.Footsteps.Boots
		expect(#boots).toBe(4)
		local jitter = Tuning.Footsteps.PitchJitter
		for i = 1, #boots do
			for j = i + 1, #boots do
				local a, b =
					math.min(boots[i].pitch, boots[j].pitch), math.max(boots[i].pitch, boots[j].pitch)
				expect(a * (1 + jitter)).toBeLessThan(b * (1 - jitter))
			end
		end
		expect(Footsteps.boots(2).name).toBe(boots[2].name)
		expect(Footsteps.boots(nil).name).toBe(boots[1].name)
		expect(Footsteps.boots(6).name).toBe(boots[2].name)
	end)
end)
