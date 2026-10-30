local Downed = require(Shared.Logic.Downed)
local Config = require(Shared.Config.Downed)

local ON = { downed = true, injury = true }
local function rescuer(arriveIn: number?)
	return { id = 2, alive = true, free = true, hasArm = true, arriveIn = arriveIn or 3 }
end

describe("Downed", function()
	it("is off by default and needs the injury feature too", function()
		expect(Config.Enabled).toBe(false)
		expect((Downed.eligible({ downed = true, injury = false }, { hasArm = true }, { rescuer() }))).toBe(
			false
		)
		expect(
			select(2, Downed.eligible({ downed = false, injury = true }, { hasArm = true }, { rescuer() }))
		).toBe("FlagOff")
	end)

	it("offers only with an arm left and a rescuer who can arrive with a whole sequence to spare", function()
		expect(Downed.eligible(ON, { hasArm = true }, { rescuer(3) })).toBe(true)
		expect(select(2, Downed.eligible(ON, { hasArm = false }, { rescuer(3) }))).toBe("NoArm")
		expect(select(2, Downed.eligible(ON, { hasArm = true }, {}))).toBe("Solo")
		local late = Config.BleedSeconds - Config.Rescue.Length + 0.01
		expect(select(2, Downed.eligible(ON, { hasArm = true }, { rescuer(late) }))).toBe("NoRescuer")
		local held = rescuer(1)
		held.free = false
		expect(select(2, Downed.eligible(ON, { hasArm = true }, { held }))).toBe("NoRescuer")
		expect(
			select(
				2,
				Downed.eligible(
					{ downed = true, injury = true, tutorial = true },
					{ hasArm = true },
					{ rescuer() }
				)
			)
		).toBe("Tutorial")
	end)

	it("keeps one immutable deadline and one attempt", function()
		local s = Downed.new(1, 7, 100)
		expect(s.deadline).toBe(100 + Config.BleedSeconds)
		expect(Downed.join(s, 7, 101)).toBe(false) -- not yourself
		expect(Downed.join(s, 2, 101)).toBe(true)
		expect(Downed.join(s, 3, 101)).toBe(false) -- the attempt is spent
		expect(s.deadline).toBe(100 + Config.BleedSeconds)
	end)

	it("refuses a join that cannot fit the whole sequence before the deadline", function()
		local s = Downed.new(1, 7, 0)
		expect(Downed.canJoin(s, Config.BleedSeconds - Config.Rescue.Length)).toBe(true)
		expect(Downed.canJoin(s, Config.BleedSeconds - Config.Rescue.Length + 0.001)).toBe(false)
	end)

	it("reopens once after a miss with enough bleed left, and the drag escalates", function()
		local s = Downed.new(1, 7, 0)
		Downed.join(s, 2, 1)
		expect(Downed.miss(s, 3)).toBe(true)
		expect(s.phase).toBe("Downed")
		expect(Downed.drag(s, false)).toBe(Config.DragSpeed * Config.MissDragMult)
		expect(Downed.join(s, 3, 4)).toBe(true)
		expect(Downed.miss(s, 6)).toBe(false) -- the retry is spent
		local late = Downed.new(2, 7, 0)
		Downed.join(late, 2, 1)
		expect(Downed.miss(late, Config.BleedSeconds - Config.RetryFloor + 0.01)).toBe(false)
	end)

	it("drags at DragSpeed, less the crawl, and not at all during a rescue", function()
		local s = Downed.new(1, 7, 0)
		expect(Downed.drag(s, false)).toBe(Config.DragSpeed)
		expect(Downed.drag(s, true)).toBe(Config.DragSpeed - Config.CrawlSpeed)
		Downed.join(s, 2, 1)
		expect(Downed.drag(s, false)).toBe(0)
	end)

	it("bleeds out at the deadline exactly, and settles once whatever comes after", function()
		local s = Downed.new(1, 7, 0)
		expect(Downed.tick(s, Config.BleedSeconds - 0.001)).toBe("Downed")
		expect(Downed.tick(s, Config.BleedSeconds)).toBe("Settled")
		expect(s.outcome).toBe("Taken")
		expect(Downed.settle(s, "Rescued", Config.BleedSeconds)).toBe(false) -- a late duplicate changes nothing
		expect(s.outcome).toBe("Taken")
	end)

	it("lets a rescue that finishes by the deadline win, and departure settle with its own cause", function()
		local s = Downed.new(1, 7, 0)
		Downed.join(s, 2, Config.BleedSeconds - Config.Rescue.Length)
		expect(Downed.tick(s, Config.BleedSeconds)).toBe("Rescuing") -- the bleed does not cut a fitted sequence
		expect(Downed.settle(s, "Rescued", Config.BleedSeconds)).toBe(true)
		local d = Downed.new(2, 8, 0)
		expect(Downed.settle(d, "Departure", 5)).toBe(true)
		expect(d.outcome).toBe("Departure")
	end)

	it("counts a Downed player as recoverable, not as a rescuer", function()
		local s = Downed.new(1, 7, 0)
		expect(Downed.recoverable(s)).toBe(true)
		expect(Downed.canRescue(s)).toBe(false)
		Downed.settle(s, "Taken", 20)
		expect(Downed.recoverable(s)).toBe(false)
		expect(Downed.canRescue(nil)).toBe(true)
	end)
end)
