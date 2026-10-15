--!strict
--[[
	Breaking a Hollow's hold with skill checks (Config/Difficulty SkillCheck). Pure, so the
	server (Services/HollowService, the only judge) and the specs agree.

	A check is a marker crossing a bar once, left to right (UI/Struggle): "angle" 0 at the left
	end at `startsAt` (server time), 360 at the right end one SweepSeconds later. The zone (the
	grey) covers [zoneStart, zoneStart + zoneWidth]; the great zone (the white block) is its
	middle GreatShare. The zone does not sit still: it slides along the bar at ZoneDrift degrees a
	second (left or right by the check's id), bouncing off the ends (zoneStartAt). The server picks every check at random the moment it appears, sends it
	to the victim, and judges the one press it accepts for it:

	  good   the marker was in the zone when the press was made
	  great  the same, in the white block: GreatBonus more progress
	  miss   early, late, or no press within one turn: MissCost progress back and MissClock
	         seconds off the grab's clock

	The victim's client reads the press the moment the key goes down and sends the server time
	it saw then (the marker is drawn from that same clock). The server judges that instant, but
	only trusts it within `tolerance` of the press's arrival: never later than it arrived, never
	more than tolerance before (pressTime). tolerance = LatencyBase + half the victim's
	round-trip ping, capped at LatencyMax. A press without a time is judged on arrival, looking
	back the same tolerance (judge).

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
	drift: number?, -- degrees a second the zone slides (sign is the direction); nil or 0 sits still
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

-- The zone's speed for check `id`: odd ids slide left, even ones right.
function SkillCheck.drift(id: number): number
	return if id % 2 == 0 then C.ZoneDrift else -C.ZoneDrift
end

-- The furthest ahead of the needle a zone of this width may start (it must end inside the turn).
function SkillCheck.maxLead(zoneWidth: number): number
	return math.max(math.min(C.LeadDegrees[2], 350 - zoneWidth), C.LeadDegrees[1])
end

--[[
	The longest it can take to win the minimum checks, hitting every one at the zone's last
	moment: the first check's delay, then each check's turn up to its zone's end, with the
	longest gap between them. A sliding zone always stays on the bar, so the needle still
	crosses it within one turn.
]]
function SkillCheck.minimumSeconds(zoneWidth: number): number
	local perCheck = if C.ZoneDrift > 0
		then C.SweepSeconds
		else (SkillCheck.maxLead(zoneWidth) + zoneWidth) / 360 * C.SweepSeconds
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
		drift = SkillCheck.drift(id),
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

-- Where the zone starts at server time `t`: it slides from zoneStart at its drift and bounces
-- off both ends of the bar, so it always covers [0, 360].
function SkillCheck.zoneStartAt(check: Check, t: number): number
	local range = math.max(360 - check.zoneWidth, 0)
	local drift = check.drift or 0
	if drift == 0 or range == 0 then
		return check.zoneStart
	end
	local p = (check.zoneStart + drift * math.max(t - check.startsAt, 0)) % (2 * range)
	return if p > range then 2 * range - p else p
end

-- Server time the turn ends: with no press by then (plus the largest tolerance), it is a miss.
function SkillCheck.endsAt(check: Check): number
	return check.startsAt + check.sweep + C.LatencyMax
end

function SkillCheck.tolerance(ping: number?): number
	local p = if type(ping) == "number" and ping == ping and ping > 0 then ping else 0
	return math.min(C.LatencyBase + p / 2, C.LatencyMax)
end

-- Does [from, to] (in either order) cross [lo, hi]?
local function overlaps(from: number, to: number, lo: number, hi: number): boolean
	return math.max(from, to) >= lo and math.min(from, to) <= hi
end

-- The needle's place relative to the zone's start at server time `t`.
local function relative(check: Check, t: number): number
	return SkillCheck.angleAt(check, t) - SkillCheck.zoneStartAt(check, t)
end

local WINDOW_STEPS = 12 -- the look-back window is checked in this many slices (the zone moves)

-- Where the great zone (the white block, centred in the zone) starts.
function SkillCheck.greatStart(check: Check): number
	return check.zoneStart + (check.zoneWidth - check.greatWidth) / 2
end

-- Judges one press that arrived at server time `at`, allowing `tolerance` seconds of latency
-- (0 judges the exact instant `at`).
function SkillCheck.judge(check: Check, at: number, tolerance: number): Result
	local tol = math.clamp(tolerance, 0, C.LatencyMax)
	local great = (check.zoneWidth - check.greatWidth) / 2
	local steps = if tol > 0 then WINDOW_STEPS else 1
	local good = false
	local prev = relative(check, at - tol)
	for i = 1, steps do
		local r = relative(check, at - tol + tol * i / steps)
		if overlaps(prev, r, great, great + check.greatWidth) then
			return "Great"
		end
		good = good or overlaps(prev, r, 0, check.zoneWidth)
		prev = r
	end
	return if good then "Good" else "Miss"
end

-- The instant to judge a press the client says it made at `claimed` (server time) that
-- arrived at `arrived`: the claim, held within [arrived - tolerance, arrived]. nil when the
-- claim is not a usable number.
function SkillCheck.pressTime(claimed: any, arrived: number, tolerance: number): number?
	if type(claimed) ~= "number" or claimed ~= claimed or math.abs(claimed) == math.huge then
		return nil
	end
	local tol = math.clamp(tolerance, 0, C.LatencyMax)
	return math.clamp(claimed, arrived - tol, arrived)
end

-- Judges a press with the client's claimed press time when it has one (the marker where the
-- player saw it), else on arrival with the look-back window.
function SkillCheck.judgePress(check: Check, claimed: any, arrived: number, tolerance: number): Result
	local at = SkillCheck.pressTime(claimed, arrived, tolerance)
	if at == nil then
		return SkillCheck.judge(check, arrived, tolerance)
	end
	return SkillCheck.judge(check, at, 0)
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
