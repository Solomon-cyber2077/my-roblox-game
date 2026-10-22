--!strict
--[[
	The departure bell (docs/FINAL-DESIGN.md Prompt 4). Pure: RunDirector.ShortenStop counts the crew
	and asks this module.

	  branch     u = (serverNow - doorsOpenAt) / the ORIGINAL params.dwell (LastCall included). "all":
	             every living crew member aboard and u >= 0.40; "half": at least ceil(living / 2)
	             aboard and u >= 0.60. Solo is its own crew; eliminated players do not count
	  proposed   departAt = min(departAt, now + 30), only if that strictly shortens: a bell never
	             extends or restarts a clock, and a second pull changes nothing
]]

local DepartureBell = {}

export type Branch = "all" | "half"

local LEAD = 30 -- seconds a pull leaves before departure (FIXED)
DepartureBell.LEAD = LEAD

function DepartureBell.share(elapsed: number, originalDwell: number): number
	return if originalDwell > 0 then elapsed / originalDwell else 0
end

function DepartureBell.proposed(existing: number, serverNow: number): number?
	local candidate = math.min(existing, serverNow + LEAD)
	return if candidate < existing then candidate else nil
end

function DepartureBell.branch(aboardLiving: number, living: number, elapsed: number, dwell: number): Branch?
	if living <= 0 or dwell <= 0 then
		return nil
	end
	local u = DepartureBell.share(elapsed, dwell)
	if aboardLiving >= living and u >= 0.40 then
		return "all"
	end
	if aboardLiving >= math.ceil(living / 2) and u >= 0.60 then
		return "half"
	end
	return nil
end

return table.freeze(DepartureBell)
