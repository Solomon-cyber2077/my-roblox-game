--!strict
--[[
	When a stop's timed events (Config/TimedEvents) warn, start and end, in seconds since
	the doors opened. Pure and seeded by the stop's layout seed, so the plan is the same on
	every run of the same stop. Events never overlap, keep a Gap between them, never repeat
	back to back and all end EndMargin before Last Call.
]]

local Shared = script.Parent.Parent
local TimedEvents = require(Shared.Config.TimedEvents)
local Rng = require(Shared.Util.Rng)

export type Slot = { id: string, warnAt: number, startAt: number, endAt: number }

local TimedEventSchedule = {}

-- The latest moment an event may still be running.
function TimedEventSchedule.limit(dwell: number, lastCall: number): number
	return dwell - lastCall - TimedEvents.EndMargin
end

-- Picks an event, never the same one twice in a row (when there is another).
function TimedEventSchedule.pick(rng: Rng.Rng, previous: string?): string
	local entries: { Rng.Weighted<string> } = {}
	for id, def in TimedEvents.Events do
		if id ~= previous then
			table.insert(entries, { weight = def.weight, value = id })
		end
	end
	table.sort(entries, function(a, b)
		return a.value < b.value
	end)
	if #entries == 0 then
		return previous :: string
	end
	return rng:weighted(entries)
end

-- The slot for event `id` warned at `warnAt`.
function TimedEventSchedule.slot(id: string, warnAt: number): Slot
	local startAt = warnAt + TimedEvents.Lead
	return { id = id, warnAt = warnAt, startAt = startAt, endAt = startAt + TimedEvents.Events[id].duration }
end

function TimedEventSchedule.plan(dwell: number, lastCall: number, seed: number): { Slot }
	local rng = Rng.new(Rng.derive(seed, "timedEvents"))
	local limit = TimedEventSchedule.limit(dwell, lastCall)
	local slots: { Slot } = {}
	local warnAt = rng:range(TimedEvents.FirstWarn[1], TimedEvents.FirstWarn[2])
	local previous: string? = nil
	while #slots < TimedEvents.MaxPerStop do
		local id = TimedEventSchedule.pick(rng, previous)
		local slot = TimedEventSchedule.slot(id, warnAt)
		if slot.endAt > limit then
			break
		end
		table.insert(slots, slot)
		previous = id
		warnAt = slot.endAt + rng:range(TimedEvents.Gap[1], TimedEvents.Gap[2])
	end
	return slots
end

return table.freeze(TimedEventSchedule)
