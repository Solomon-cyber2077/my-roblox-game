local Difficulty = require(Shared.Config.Difficulty)
local SkillCheck = require(Shared.Logic.SkillCheck)
local Tuning = require(Shared.Config.Tuning)

local C = Difficulty.SkillCheck

-- A roll that always lands at the share `u` of its range.
local function fixed(u: number): SkillCheck.Roll
	return function(lo: number, hi: number): number
		return lo + (hi - lo) * u
	end
end

-- Server time at which the needle points at `degrees`.
local function timeAt(check: SkillCheck.Check, degrees: number): number
	return check.startsAt + degrees / 360 * check.sweep
end

describe("SkillCheck", function()
	it("puts a random zone ahead of the needle, inside one turn", function()
		for _, u in { 0, 0.3, 0.7, 1 } do
			for stop = 1, 10 do
				local width = SkillCheck.zoneWidth(stop)
				local check = SkillCheck.new(1, 100, width, fixed(u))
				expect(check.zoneStart).toBeAtLeast(C.LeadDegrees[1])
				expect(check.zoneStart + check.zoneWidth).toBeLessThan(360)
				expect(check.greatWidth).toBeLessThan(check.zoneWidth)
			end
		end
		-- the scripted grab's oversized zone still fits
		local wide = SkillCheck.new(1, 0, Difficulty.Tutorial.ScriptedGrab.ZoneDegrees, fixed(1))
		expect(wide.zoneStart + wide.zoneWidth).toBeLessThan(360)
	end)

	it("judges a press in the great zone, the zone, early and late", function()
		local check = SkillCheck.new(7, 50, 60, fixed(0.5))
		local lo = check.zoneStart
		-- the white block is the middle of the zone; the grey either side is a good press
		expect(SkillCheck.judge(check, timeAt(check, lo + check.zoneWidth / 2), 0)).toBe("Great")
		expect(SkillCheck.judge(check, timeAt(check, lo + check.zoneWidth * 0.1), 0)).toBe("Good")
		expect(SkillCheck.judge(check, timeAt(check, lo + check.zoneWidth * 0.9), 0)).toBe("Good")
		expect(SkillCheck.greatStart(check)).toBeCloseTo(lo + (check.zoneWidth - check.greatWidth) / 2)
		-- early: the needle had not reached the zone
		expect(SkillCheck.judge(check, timeAt(check, lo - 10), 0)).toBe("Miss")
		-- late: it had passed it, and the tolerance does not reach back far enough
		expect(SkillCheck.judge(check, timeAt(check, lo + check.zoneWidth + 70), C.LatencyMax)).toBe("Miss")
		-- before the check even started
		expect(SkillCheck.judge(check, check.startsAt - 0.5, 0)).toBe("Miss")
	end)

	it("forgives the time a press spent on the wire, but never more than LatencyMax", function()
		local check = SkillCheck.new(1, 0, 40, fixed(0))
		local justAfter = timeAt(check, check.zoneStart + check.zoneWidth) + 0.06
		expect(SkillCheck.judge(check, justAfter, 0)).toBe("Miss")
		expect(SkillCheck.judge(check, justAfter, SkillCheck.tolerance(0.05))).toBe("Good")
		expect(SkillCheck.tolerance(5)).toBe(C.LatencyMax)
		expect(SkillCheck.tolerance(nil)).toBe(C.LatencyBase)
		expect(SkillCheck.tolerance(0 / 0)).toBe(C.LatencyBase)
		-- a client claiming a huge tolerance is clamped by judge itself
		local wayLate = timeAt(check, check.zoneStart + check.zoneWidth) + 1
		expect(SkillCheck.judge(check, wayLate, 10)).toBe("Miss")
	end)

	it("judges the instant the client pressed, trusted only within the tolerance", function()
		local check = SkillCheck.new(3, 0, 60, fixed(0.5))
		local tol = SkillCheck.tolerance(0.1)
		local centre = timeAt(check, check.zoneStart + check.zoneWidth / 2)
		-- pressed dead centre, arrived 0.08 s later: still Great (the marker moved on meanwhile)
		expect(SkillCheck.judgePress(check, centre, centre + 0.08, tol)).toBe("Great")
		-- pressed on the grey: Good, however the window would have looked back
		local edge = timeAt(check, check.zoneStart + check.zoneWidth * 0.1)
		expect(SkillCheck.judgePress(check, edge, edge + 0.05, tol)).toBe("Good")
		-- a claim from the future is held to the arrival; one from long ago to arrival - tolerance
		expect(SkillCheck.pressTime(centre + 5, centre, tol)).toBe(centre)
		expect(SkillCheck.pressTime(centre - 5, centre, tol)).toBeCloseTo(centre - tol)
		expect(SkillCheck.judgePress(check, centre - 5, centre + 1, tol)).toBe("Miss")
		-- no usable claim: judged on arrival with the window
		expect(SkillCheck.pressTime(nil, 1, tol)).toBe(nil)
		expect(SkillCheck.pressTime(0 / 0, 1, tol)).toBe(nil)
		expect(SkillCheck.judgePress(check, "x", centre, tol)).toBe(SkillCheck.judge(check, centre, tol))
		-- the white block is smaller than the old great zone (a quarter of the zone)
		expect(check.greatWidth).toBeLessThan(check.zoneWidth * 0.25)
	end)

	it("judges each check once: replays, stale ids and rapid presses are refused", function()
		local check = SkillCheck.new(3, 10, 50, fixed(0.5))
		local ok = SkillCheck.accept(check, false, 3, 11, 0)
		expect(ok).toBe(true)
		local replay, why = SkillCheck.accept(check, true, 3, 12, 11)
		expect(replay).toBe(false)
		expect(why).toBe("Replay")
		local stale, why2 = SkillCheck.accept(check, false, 2, 12, 0)
		expect(stale).toBe(false)
		expect(why2).toBe("Stale")
		local none = SkillCheck.accept(nil, false, 3, 12, 0)
		expect(none).toBe(false)
		local rapid, why3 = SkillCheck.accept(check, false, 3, 11 + C.MinPressGap / 2, 11)
		expect(rapid).toBe(false)
		expect(why3).toBe("Rate")
	end)

	it("adds progress for hits, takes it back for misses, and frees at Required", function()
		local p, clock = SkillCheck.apply(0, "Good")
		expect(p).toBe(1)
		expect(clock).toBe(0)
		p = SkillCheck.apply(p, "Great")
		expect(p).toBe(2 + C.GreatBonus)
		local missed, penalty = SkillCheck.apply(p, "Miss")
		expect(missed).toBe(p - C.MissCost)
		expect(penalty).toBe(C.MissClock)
		expect(SkillCheck.apply(0, "Miss")).toBe(0)
		expect(SkillCheck.freed(C.Required - 0.01)).toBe(false)
		expect(SkillCheck.freed(C.Required)).toBe(true)
		local good = 0
		for _ = 1, C.Required do
			good = SkillCheck.apply(good, "Good")
		end
		expect(SkillCheck.freed(good)).toBe(true)
		expect(SkillCheck.fraction(C.Required * 2)).toBe(1)
	end)

	it("never lets a grab finish before the minimum checks can be won", function()
		for stop = 1, Tuning.Run.StationCount + 2 do
			local widths = { SkillCheck.zoneWidth(stop) }
			for _, tier in Difficulty.Tutorial.Tiers do
				if tier.zoneDegrees then
					table.insert(widths, SkillCheck.zoneWidth(stop, tier.zoneDegrees))
				end
			end
			table.insert(widths, Difficulty.Tutorial.ScriptedGrab.ZoneDegrees)
			for _, width in widths do
				local finish = SkillCheck.finishSeconds(stop, width)
				expect(finish).toBeAtLeast(SkillCheck.minimumSeconds(width) + C.FinishMargin - 1e-9)
				-- and the first check comes no sooner than about a second in
				expect(C.FirstDelay).toBeAtLeast(1)
				expect(finish).toBeGreaterThan(C.FirstDelay + 1)
			end
		end
	end)

	it("narrows the zone as the stops go on, and is wide in tutorial run 2", function()
		for stop = 2, 10 do
			expect(SkillCheck.zoneWidth(stop)).toBeAtMost(SkillCheck.zoneWidth(stop - 1))
		end
		expect(SkillCheck.zoneWidth(7)).toBeLessThan(SkillCheck.zoneWidth(1))
		local wide = Difficulty.Tutorial.Tiers[2].zoneDegrees :: number
		expect(SkillCheck.zoneWidth(1, wide)).toBeGreaterThan(SkillCheck.zoneWidth(1))
	end)

	it("ends an unpressed check after one turn and the largest tolerance", function()
		local check = SkillCheck.new(1, 20, 50, fixed(0.2))
		expect(SkillCheck.endsAt(check)).toBeCloseTo(20 + C.SweepSeconds + C.LatencyMax)
		expect(SkillCheck.angleAt(check, 20 + C.SweepSeconds)).toBeCloseTo(360)
	end)
end)
