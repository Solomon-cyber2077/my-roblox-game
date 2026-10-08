local DepartureSchedule = require(Shared.Logic.DepartureSchedule)

local function kinds(list)
	local out = {}
	for _, m in list do
		table.insert(out, m.kind)
	end
	return table.concat(out, ",")
end

-- Runs a tracker second by second from `from` seconds left down to 0 and lists what fired.
local function run(stopLength, from, step)
	local tracker = DepartureSchedule.tracker()
	local fired = {}
	local left = from
	while true do
		local reached = DepartureSchedule.step(tracker, 1, stopLength, left)
		if reached then
			table.insert(fired, reached)
		end
		if left <= 0 then
			break
		end
		left = math.max(left - (step or 0.25), 0)
	end
	return fired
end

describe("DepartureSchedule", function()
	it("keeps start and halfway only when they are clear of each other and T-30", function()
		expect(kinds(DepartureSchedule.milestones(30))).toBe("warning,escalated,depart")
		expect(kinds(DepartureSchedule.milestones(60))).toBe("start,warning,escalated,depart")
		expect(kinds(DepartureSchedule.milestones(120))).toBe("start,halfway,warning,escalated,depart")
		expect(kinds(DepartureSchedule.milestones(180))).toBe("start,halfway,warning,escalated,depart")
		expect(kinds(DepartureSchedule.milestones(240))).toBe("start,halfway,warning,escalated,depart")
	end)

	it("puts the halfway reminder at half the stop", function()
		expect(DepartureSchedule.milestones(240)[2].left).toBe(120)
		expect(DepartureSchedule.milestones(180)[2].left).toBe(90)
	end)

	it("fires every milestone once across a whole stop", function()
		for _, length in { 30, 60, 120, 180, 240 } do
			local fired = run(length, length)
			expect(kinds(fired)).toBe(kinds(DepartureSchedule.milestones(length)))
		end
	end)

	it("gives a late joiner only the milestones still ahead", function()
		expect(kinds(run(120, 45))).toBe("warning,escalated,depart")
		expect(kinds(run(120, 20))).toBe("escalated,depart")
		expect(kinds(run(120, 5))).toBe("depart")
	end)

	it("puts a late joiner inside T-30 straight into the escalated levels", function()
		expect(DepartureSchedule.level(45)).toBe("calm")
		expect(DepartureSchedule.level(20)).toBe("warning")
		expect(DepartureSchedule.level(5)).toBe("escalated")
		expect(DepartureSchedule.level(0)).toBe("departed")
	end)

	it("still fires a milestone passed a moment before the stop was first seen", function()
		expect(kinds(run(120, 119))).toBe("start,halfway,warning,escalated,depart")
	end)

	it("returns only the latest milestone when a jump crosses several", function()
		local tracker = DepartureSchedule.tracker()
		DepartureSchedule.step(tracker, 1, 120, 120)
		local reached = DepartureSchedule.step(tracker, 1, 120, 25)
		expect(reached and reached.kind).toBe("warning")
		expect(DepartureSchedule.step(tracker, 1, 120, 24)).toBe(nil)
	end)

	it("starts over for a new stop", function()
		local tracker = DepartureSchedule.tracker()
		DepartureSchedule.step(tracker, 1, 60, 0)
		local reached = DepartureSchedule.step(tracker, 2, 60, 60)
		expect(reached and reached.kind).toBe("start")
	end)

	it("counts the time left from an injected clock", function()
		local now = 1000
		local function clock()
			return now
		end
		local departAt = 1090
		expect(DepartureSchedule.remaining(departAt, clock())).toBe(90)
		now = 1089.5
		expect(DepartureSchedule.remaining(departAt, clock())).toBe(0.5)
		now = 1200
		expect(DepartureSchedule.remaining(departAt, clock())).toBe(0)
	end)

	it("words the slate reminders", function()
		local list = DepartureSchedule.milestones(240)
		expect(DepartureSchedule.slate(list[1])).toBe("4 MIN BEFORE DEPARTURE")
		expect(DepartureSchedule.slate(list[2])).toBe("HALFWAY - 2 MIN LEFT")
		expect(DepartureSchedule.slate(list[3])).toBe("30 SECONDS")
		expect(DepartureSchedule.slate(list[5])).toBe(nil)
	end)
end)
