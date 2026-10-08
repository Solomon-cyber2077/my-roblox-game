--!strict
--[[
	When a stop's departure warnings fire. Pure: the client's DepartureClock feeds it
	run.station (dwell, startedAt, departAt) and the server clock, so the warnings can
	only ever agree with the server's own departure.

	Milestones are counted in seconds left before departAt:
	  start      the doors open (left = dwell)
	  halfway    half the dwell gone, only for stops of HalfwayMinSeconds or more
	  warning    T-30: the watch starts ticking
	  escalated  T-10: the tick doubles
	  depart     T-0
	A start or halfway reminder within ReminderGapSeconds of another kept one (or of T-30)
	is dropped; warning, escalated and depart are always kept.
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)

local T = Tuning.Departure

export type Kind = "start" | "halfway" | "warning" | "escalated" | "depart"
export type Milestone = { kind: Kind, left: number }
export type Level = "calm" | "warning" | "escalated" | "departed"
export type Tracker = { key: number?, milestones: { Milestone }, nextIndex: number }

local DepartureSchedule = {}

function DepartureSchedule.remaining(departAt: number, now: number): number
	return math.max(departAt - now, 0)
end

function DepartureSchedule.level(left: number): Level
	if left <= 0 then
		return "departed"
	elseif left <= T.EscalatedSeconds then
		return "escalated"
	elseif left <= T.WarningSeconds then
		return "warning"
	end
	return "calm"
end

-- The stop's milestones, latest-first (largest `left` first).
function DepartureSchedule.milestones(stopLength: number): { Milestone }
	local reminders: { Milestone } = { { kind = "start", left = stopLength } }
	if stopLength >= T.HalfwayMinSeconds then
		table.insert(reminders, { kind = "halfway", left = stopLength / 2 })
	end
	local kept: { Milestone } = {}
	local previous = math.huge
	for _, reminder in reminders do
		local clear = previous - reminder.left >= T.ReminderGapSeconds
			and reminder.left - T.WarningSeconds >= T.ReminderGapSeconds
		if clear then
			table.insert(kept, reminder)
			previous = reminder.left
		end
	end
	table.insert(kept, { kind = "warning", left = T.WarningSeconds })
	table.insert(kept, { kind = "escalated", left = T.EscalatedSeconds })
	table.insert(kept, { kind = "depart", left = 0 })
	return kept
end

function DepartureSchedule.tracker(): Tracker
	return { key = nil, milestones = {}, nextIndex = 1 }
end

-- Moves the tracker to `left` seconds before the departure of the stop `key` (its startedAt)
-- and returns the milestone just reached, if any. Each fires once per stop. A tracker that
-- first sees a stop part-way through (a late joiner, a respawn) skips what has already passed,
-- bar the last CatchUpSeconds, so nothing earlier is replayed. When a jump crosses several
-- milestones at once, only the latest is returned.
function DepartureSchedule.step(tracker: Tracker, key: number, stopLength: number, left: number): Milestone?
	local list = tracker.milestones
	if tracker.key ~= key then
		tracker.key = key
		list = DepartureSchedule.milestones(stopLength)
		tracker.milestones = list
		tracker.nextIndex = 1
		while tracker.nextIndex <= #list and list[tracker.nextIndex].left > left + T.CatchUpSeconds do
			tracker.nextIndex += 1
		end
	end
	local reached: Milestone? = nil
	while tracker.nextIndex <= #list and list[tracker.nextIndex].left >= left do
		reached = list[tracker.nextIndex]
		tracker.nextIndex += 1
	end
	return reached
end

-- The chalk slate's words for a reminder, or nil for a milestone without one.
function DepartureSchedule.slate(milestone: Milestone): string?
	local seconds = math.floor(milestone.left + 0.5)
	local span = if seconds < 60
		then `{seconds} SECONDS`
		elseif seconds % 60 == 0 then `{seconds // 60} MIN`
		else string.format("%d:%02d", seconds // 60, seconds % 60)
	if milestone.kind == "start" then
		return `{span} BEFORE DEPARTURE`
	elseif milestone.kind == "halfway" then
		return `HALFWAY - {span} LEFT`
	elseif milestone.kind == "warning" then
		return `{math.floor(milestone.left + 0.5)} SECONDS`
	end
	return nil
end

return DepartureSchedule
