--!strict
--[[
	Breaking a Hollow's hold with skill checks (Config/Difficulty SkillCheck). Pure, so the
	server (Services/HollowService, the only judge) and the specs agree.

	A check is a needle sweeping a ring once, clockwise from the top: angle 0 at `startsAt`
	(server time), 360 one SweepSeconds later. The zone covers [zoneStart, zoneStart + zoneWidth]
	degrees; its leading GreatShare is the great zone. The server picks every check at random
	the moment it appears, sends it to the victim, and judges the one press it accepts for it:

	  good   the needle was in the zone at some moment of [press - tolerance, press]
	  great  the same, in the great zone: GreatBonus more progress
	  miss   early, late, or no press within one turn: MissCost progress back and MissClock
	         seconds off the grab's clock

	tolerance = LatencyBase + half the victim's round-trip ping, capped at LatencyMax: a press is
	judged when it arrives, so the window looks back for the time it spent on the wire, never
	forward.

	Progress reaching Required frees the victim. The grab finishes FinishByStop seconds after
	it began (less every miss); the first check never comes before FirstDelay, and the finish
	always leaves room for the minimum checks (`minimumSeconds`) plus FinishMargin.
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)

local C = Difficulty.SkillCheck

export type Check = {
	id: number,
	startsAt: number, -- server time the needle sets off from 0 degrees
	sweep: number, -- seconds for one full turn
	zoneStart: number, -- degrees clockwise from the top
	zoneWidth: number,
	greatWidth: number,
}

export type Result = "Great" | "Good" | "Miss"

-- (lo, hi) -> a number in [lo, hi]: Random:NextNumber on the server, fixed in the specs.
export type Roll = (lo: number, hi: number) -> number

local SkillCheck = {}

SkillCheck.Required = C.Required

local function pick<T>(list: { T }, stop: number): T
	return list[math.clamp(math.floor(stop), 1, #list)]
end

--[[
	Zone width in degrees. `tutorialZone` (Config/Tutorial: tier 2's wide zone, or the scripted
	grab's oversized one) replaces the stop's when given.
]]
function SkillCheck.zoneWidth(stop: number, tutorialZone: number?): number
	return tutorialZone or pick(C.ZoneByStop, stop)
end

-- The grab's clock: seconds from the snatch to its finish, before any misses.
function SkillCheck.finishSeconds(stop: number, zoneWidth: number): number
	return math.max(pick(C.FinishByStop, stop), SkillCheck.minimumSeconds(zoneWidth) + C.FinishMargin)
end

-- The furthest ahead of the needle a zone of this width may start (it must end inside the turn).
function SkillCheck.maxLead(zoneWidth: number): number
	return math.max(math.min(C.LeadDegrees[2], 350 - zoneWidth), C.LeadDegrees[1])
end

--[[
	The longest it can take to win the minimum checks, hitting every one at the zone's last
	moment: the first check's delay, then each check's turn up to its zone's end, with the
	longest gap between them.
]]
function SkillCheck.minimumSeconds(zoneWidth: number): number
	local perCheck = (SkillCheck.maxLead(zoneWidth) + zoneWidth) / 360 * C.SweepSeconds
	return C.FirstDelay + C.Required * perCheck + (C.Required - 1) * C.Gap[2]
end

-- A new check, appearing now. Nothing about it is known before it appears.
function SkillCheck.new(id: number, now: number, zoneWidth: number, roll: Roll): Check
	local width = math.clamp(zoneWidth, 1, 340)
	return {
		id = id,
		startsAt = now,
		sweep = C.SweepSeconds,
		zoneStart = roll(C.LeadDegrees[1], SkillCheck.maxLead(width)),
		zoneWidth = width,
		greatWidth = width * C.GreatShare,
	}
end

-- Seconds after the previous check ends before the next one appears.
function SkillCheck.gap(roll: Roll): number
	return roll(C.Gap[1], C.Gap[2])
end

-- Where the needle points at server time `t` (may run past 360 once the turn is over).
function SkillCheck.angleAt(check: Check, t: number): number
	return (t - check.startsAt) / check.sweep * 360
end

-- Server time the turn ends: with no press by then (plus the largest tolerance), it is a miss.
function SkillCheck.endsAt(check: Check): number
	return check.startsAt + check.sweep + C.LatencyMax
end

function SkillCheck.tolerance(ping: number?): number
	local p = if type(ping) == "number" and ping == ping and ping > 0 then ping else 0
	return math.min(C.LatencyBase + p / 2, C.LatencyMax)
end

-- Does the needle's path over [from, to] degrees cross [lo, hi]?
local function overlaps(from: number, to: number, lo: number, hi: number): boolean
	return to >= lo and from <= hi
end

-- Judges one press that arrived at server time `at`, allowing `tolerance` seconds of latency.
function SkillCheck.judge(check: Check, at: number, tolerance: number): Result
	local tol = math.clamp(tolerance, 0, C.LatencyMax)
	local from = SkillCheck.angleAt(check, at - tol)
	local to = SkillCheck.angleAt(check, at)
	local lo = check.zoneStart
	if overlaps(from, to, lo, lo + check.greatWidth) then
		return "Great"
	elseif overlaps(from, to, lo, lo + check.zoneWidth) then
		return "Good"
	end
	return "Miss"
end

-- Progress after a result, and the seconds it takes off the grab's clock.
function SkillCheck.apply(progress: number, result: Result): (number, number)
	if result == "Great" then
		return progress + 1 + C.GreatBonus, 0
	elseif result == "Good" then
		return progress + 1, 0
	end
	return math.max(progress - C.MissCost, 0), C.MissClock
end

-- Progress after a crewmate tears at the Hollow once.
function SkillCheck.pry(progress: number): number
	return progress + C.PryProgress
end

function SkillCheck.freed(progress: number): boolean
	return progress >= C.Required - 1e-9
end

-- Progress as a share of what frees you, for the meter.
function SkillCheck.fraction(progress: number): number
	return math.clamp(progress / C.Required, 0, 1)
end

--[[
	Whether the server should judge a press at `at` for check `id`: there must be a live check
	with that id that has not been judged (no replays), and the last judged-or-ignored press must
	be at least MinPressGap ago (rate limit). Returns the reason when it should not.
]]
function SkillCheck.accept(
	current: Check?,
	judged: boolean,
	id: number,
	at: number,
	lastPressAt: number
): (boolean, string?)
	if at - lastPressAt < C.MinPressGap then
		return false, "Rate"
	end
	if current == nil or current.id ~= id then
		return false, "Stale"
	end
	if judged then
		return false, "Replay"
	end
	return true, nil
end

return table.freeze(SkillCheck)
