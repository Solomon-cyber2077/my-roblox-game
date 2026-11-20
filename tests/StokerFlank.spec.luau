local Tuning = require(Shared.Config.Tuning)
local StokerFlank = require(Shared.Logic.StokerFlank)

local F = Tuning.BruteRemake.Flank

describe("The Stoker's cunning approach", function()
	it("tries only inside its distance band and under its chance", function()
		expect(StokerFlank.tries(30, 0)).toBe(true)
		expect(StokerFlank.tries(F.Min - 1, 0)).toBe(false)
		expect(StokerFlank.tries(F.Max + 1, 0)).toBe(false)
		expect(StokerFlank.tries(30, F.Chance + 0.01)).toBe(false)
	end)

	it("bows out to one side first, never straight at them", function()
		local flank = StokerFlank.plan(0, 0.9)
		local own, prey = { x = 0, z = 0 }, { x = 0, z = -40 }
		local goal = StokerFlank.goal(flank, own, prey, { x = 0, z = 1 })
		-- halfway along, and well off the line
		expect(math.abs(goal.z + 20) < 0.01).toBe(true)
		expect(math.abs(goal.x) > 40 * F.Swing * 0.9).toBe(true)
	end)

	it("comes round to their side or back, Radius from them", function()
		local flank = StokerFlank.plan(0, 0.1)
		flank.leg = 2
		local prey = { x = 0, z = -40 }
		local facing = { x = 0, z = 1 } -- they face him
		local goal = StokerFlank.goal(flank, { x = 0, z = 0 }, prey, facing)
		local ox, oz = goal.x - prey.x, goal.z - prey.z
		expect(math.abs(math.sqrt(ox * ox + oz * oz) - F.Radius) < 0.01).toBe(true)
		-- behind their shoulder: the spot is against where they face
		expect(ox * facing.x + oz * facing.z < 0).toBe(true)
	end)

	it("moves to the second leg, then is round", function()
		local flank = StokerFlank.plan(0, 0.1)
		expect(StokerFlank.advance(flank, { x = 0, z = 0 }, { x = F.Arrive + 1, z = 0 })).toBe(nil)
		expect(flank.leg).toBe(1)
		expect(StokerFlank.advance(flank, { x = 0, z = 0 }, { x = 1, z = 0 })).toBe(nil)
		expect(flank.leg).toBe(2)
		expect(StokerFlank.advance(flank, { x = 0, z = 0 }, { x = 1, z = 0 })).toBe("Round")
	end)

	it("ends when they turn and see him, or when it takes too long", function()
		local flank = StokerFlank.plan(0, 0.1)
		local own, prey = { x = 0, z = 0 }, { x = 0, z = -20 }
		expect(StokerFlank.ends(flank, 1, own, prey, { x = 0, z = 1 }, true)).toBe("Seen")
		expect(StokerFlank.ends(flank, 1, own, prey, { x = 0, z = -1 }, true)).toBe(nil)
		expect(StokerFlank.ends(flank, 1, own, prey, { x = 0, z = 1 }, false)).toBe(nil)
		expect(StokerFlank.ends(flank, F.Seconds, own, prey, { x = 0, z = -1 }, true)).toBe("Late")
	end)
end)
