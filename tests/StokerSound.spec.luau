local Audio = require(Shared.Config.Audio)
local Tuning = require(Shared.Config.Tuning)
local StokerSound = require(Shared.Logic.StokerSound)

local S = Tuning.BruteRemake.Sound

-- every Stoker cue, the layers its `with` chain plays and what Logic/StokerSound can pick
local function stokerCues(): { string }
	local names = {}
	for name in Audio do
		if string.sub(name, 1, 6) == "Stoker" then
			table.insert(names, name)
		end
	end
	return names
end

describe("The Stoker's sound set", function()
	it("has a cue for everything it can pick, each layer included", function()
		local picks = { "StokerHeelL", "StokerHeelR", "StokerThud", "StokerBellowsOut", "StokerBellowsIn" }
		for _, list in StokerSound.Ground do
			for _, name in list do
				table.insert(picks, name)
			end
		end
		for _, name in StokerSound.Drags do
			table.insert(picks, name)
		end
		for _, name in StokerSound.Rust do
			table.insert(picks, name)
		end
		for _, name in { "StokerStrike", "StokerSnuff", "StokerPin", "StokerCrunch", "StokerEmbers" } do
			table.insert(picks, name)
		end
		for _, name in picks do
			local cue = Audio[name]
			expect(cue ~= nil).toBe(true)
			while cue and cue.with do
				expect(Audio[cue.with] ~= nil).toBe(true)
				cue = Audio[cue.with]
			end
		end
	end)

	it("plays every one-shot where it happens, and only Pro Sound Effects library ids", function()
		for _, name in stokerCues() do
			local cue = Audio[name]
			if not cue.loop then
				expect(cue.spatial).toBe(true)
			end
			-- the licensed library's ids (9.1e9 range), never an upload of our own (15 digits)
			expect(cue.id > 9.1e9 and cue.id < 9.2e9).toBe(true)
		end
	end)

	it("is heard coming: the drag carries further than his steps, the rust only close", function()
		expect(Audio.StokerDrag1.rollOff > Audio.StokerHeelL.rollOff).toBe(true)
		expect(Audio.StokerRust1.rollOff < Audio.StokerHeelL.rollOff).toBe(true)
		expect(S.Drag.Hunt > S.Drag.Prowl).toBe(true)
	end)

	it("keeps the crackle loop out of the threat tier, so it never ducks the mix", function()
		expect(Audio.StokerEmbers.loop).toBe(true)
		expect(Audio.StokerEmbers.mix).toBe("Steps")
		expect(S.EmberNear < S.EmberReach).toBe(true)
	end)

	it("lands the burnt left leg harder and lower than the right", function()
		local left = StokerSound.step("L", "Gravel", 1, 0.5)
		local right = StokerSound.step("R", "Gravel", 1, 0.5)
		expect(left.heel).toBe("StokerHeelL")
		expect(right.heel).toBe("StokerHeelR")
		expect(left.gain > right.gain).toBe(true)
		expect(left.pitch < right.pitch).toBe(true)
		expect(left.thud > right.thud).toBe(true)
	end)

	it("steps on the ground under him, taking turns, gravel when the surface is unknown", function()
		expect(StokerSound.step("L", "Gravel", 1, 0.5).ground).toBe("StokerGroundGravel1")
		expect(StokerSound.step("L", "Gravel", 2, 0.5).ground).toBe("StokerGroundGravel2")
		expect(StokerSound.step("L", "Snow", 3, 0.5).ground).toBe("StokerGroundSnow1")
		expect(StokerSound.step("R", "Plank", 1, 0.5).ground).toBe("StokerGroundPlank")
		expect(StokerSound.step("R", "TrainFloor", 1, 0.5).ground).toBe("StokerGroundPlank")
		expect(StokerSound.step("R", "Stone", 1, 0.5).ground).toBe("StokerGroundStone")
		expect(StokerSound.step("R", "Mud", 1, 0.5).ground).toBe("StokerGroundGravel1")
		for _, roll in { 0, 1 } do
			local pitch = StokerSound.step("R", "Gravel", 1, roll).pitch
			expect(math.abs(pitch / S.Right.pitch - 1) <= S.Jitter + 1e-9).toBe(true)
		end
	end)

	it("drags the shovel on the right step only, louder on the hunt, shedding rust now and then", function()
		expect(StokerSound.drags("R")).toBe(true)
		expect(StokerSound.drags("L")).toBe(false)
		local take, gain, rust = StokerSound.drag(1, "Hunt", 0.99)
		expect(take).toBe("StokerDrag1")
		expect(gain).toBe(S.Drag.Hunt)
		expect(rust).toBe(nil)
		local _, calm, flake = StokerSound.drag(2, "Prowl", 0)
		expect(calm).toBe(S.Drag.Prowl)
		expect(flake).toBe("StokerRust2")
		local _, other = StokerSound.drag(4, "Return", 0.5)
		expect(other).toBe(S.Drag.Other)
		expect(StokerSound.drag(4, "Hunt", 0.5)).toBe("StokerDrag1")
	end)

	it("breathes once out and once in a breath, faster on the hunt", function()
		local function count(rate: number, seconds: number): (number, number)
			local outs, ins = 0, 0
			local dt = 1 / 60
			for i = 1, math.floor(seconds / dt) do
				for _, stroke in StokerSound.breaths((i - 1) * dt, i * dt, rate, 0.3) do
					if stroke == "Out" then
						outs += 1
					else
						ins += 1
					end
				end
			end
			return outs, ins
		end
		local outs, ins = count(StokerSound.breathRate("Prowl"), 60)
		local expected = 60 * S.BreathRate.Rest / (2 * math.pi)
		expect(math.abs(outs - expected) <= 1).toBe(true)
		expect(math.abs(ins - expected) <= 1).toBe(true)
		local huntOuts = count(StokerSound.breathRate("Hunt"), 60)
		expect(huntOuts > outs).toBe(true)
		expect(#StokerSound.breaths(1, 1, 2, 0)).toBe(0)
	end)
end)
