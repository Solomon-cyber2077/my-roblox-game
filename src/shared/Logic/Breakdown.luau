--!strict
--[[
	A breakdown (Difficulty.Breakdown): the hull drains to its floor (Difficulty.Hull.Floor) while
	the train runs. Pure state machine; Services/BreakdownService runs it.

	  None     running normally
	  Village  the first breakdown of a run, when an Emergency Village stop is available (part 3
	           builds it: BreakdownService.requestVillageStop); the train stops there
	  Stopped  the first breakdown otherwise: the train grinds to a halt (StopSeconds)
	  Rally    the crew has RallySeconds to make RallyRepairs repairs aboard; done, the hull is
	           restored to RallyRestore and the train limps on
	  Limp     the rest of the trip at LimpShare of its speed
	  Lost     a second breakdown in the run, or a failed rally: the train is lost, the run ends

	`count` is the run's breakdowns so far. The train does not move while Village, Stopped or
	Rally, so the hull does not drain then either.

	A successful repair (the village's or the rally's) starts a grace (RepairGraceSeconds): until
	`graceUntil` the open leaks stay open but do not drain the hull, and no new leak bursts.
	Alternative design, not built: close every open leak on success instead (TrainService
	ClearBreaches where BreakdownService starts the grace).
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)

local C = Difficulty.Breakdown

export type Phase = "None" | "Village" | "Stopped" | "Rally" | "Limp" | "Lost"

export type State = {
	phase: Phase,
	count: number,
	endsAt: number?, -- server time the current phase runs out (Stopped, Rally)
	repairs: number,
	needed: number,
	graceUntil: number?, -- server time the grace after a successful repair ends
}

local Breakdown = {}

function Breakdown.new(): State
	return { phase = "None", count = 0, endsAt = nil, repairs = 0, needed = C.RallyRepairs }
end

local function with(state: State, changes: { [string]: any }): State
	local out = table.clone(state)
	for key, value in changes do
		(out :: any)[key] = value
	end
	return out
end

-- The hull reached its floor at `now`. `village`: an Emergency Village stop was granted.
function Breakdown.onFloor(state: State, now: number, village: boolean): State
	if state.phase == "Lost" then
		return state
	end
	if state.count >= 1 then
		return with(state, { phase = "Lost", count = state.count + 1, endsAt = nil })
	end
	if village then
		return with(state, { phase = "Village", count = 1, endsAt = nil })
	end
	return with(state, { phase = "Stopped", count = 1, endsAt = now + C.StopSeconds, repairs = 0 })
end

-- Moves timed phases on: the halt becomes the rally; a rally that runs out is the train lost.
function Breakdown.tick(state: State, now: number): State
	local endsAt = state.endsAt
	if endsAt == nil or now < endsAt then
		return state
	end
	if state.phase == "Stopped" then
		return with(state, { phase = "Rally", endsAt = now + C.RallySeconds, repairs = 0 })
	elseif state.phase == "Rally" then
		return with(state, { phase = "Lost", endsAt = nil })
	end
	return state
end

-- One repair made during the rally at `now`. Returns the new state and whether that finished
-- it (restore the hull to RallyRestore); finishing it starts the grace.
function Breakdown.repair(state: State, now: number): (State, boolean)
	if state.phase ~= "Rally" then
		return state, false
	end
	local repairs = state.repairs + 1
	if repairs >= state.needed then
		return with(
			state,
			{ phase = "Limp", repairs = repairs, endsAt = nil, graceUntil = now + C.RepairGraceSeconds }
		),
			true
	end
	return with(state, { repairs = repairs }), false
end

-- The trip ended (the train arrived): back to normal running; the run's count stays.
function Breakdown.arrive(state: State): State
	if state.phase == "Lost" then
		return state
	end
	local out = with(state, { phase = "None", repairs = 0 })
	out.endsAt, out.graceUntil = nil, nil -- `with` cannot clear a field
	return out
end

-- The Emergency Village stop is over: `found` repair parts came aboard of the `needed`. Enough,
-- and the train runs again (the run's count stays, so a second breakdown still loses it); short,
-- and it falls back on the halt and the rally. Enough also starts the grace.
function Breakdown.villageDone(state: State, found: number, needed: number, now: number): State
	if state.phase ~= "Village" then
		return state
	end
	if found >= needed then
		return with(state, { phase = "None", endsAt = nil, graceUntil = now + C.RepairGraceSeconds })
	end
	return with(state, { phase = "Stopped", endsAt = now + C.StopSeconds, repairs = 0 })
end

-- The share of its cruising speed the train runs at.
function Breakdown.speedShare(state: State): number
	if state.phase == "Limp" then
		return C.LimpShare
	elseif state.phase == "Stopped" or state.phase == "Rally" or state.phase == "Village" then
		return 0
	end
	return 1
end

--[[
	Seconds to add to the trip's clock for `dt` seconds at this state's speed: the trip is a
	distance, so time spent stopped is added whole, and limping adds the share it falls behind.
]]
function Breakdown.delay(state: State, dt: number): number
	return dt * (1 - Breakdown.speedShare(state))
end

-- True during the grace after a successful repair: leaks hold the hull and none burst.
function Breakdown.inGrace(state: State, now: number): boolean
	local graceUntil = state.graceUntil
	return graceUntil ~= nil and now < graceUntil and state.phase ~= "Lost"
end

-- Whole seconds of grace left at `now` (0 outside it).
function Breakdown.graceLeft(state: State, now: number): number
	return if Breakdown.inGrace(state, now) then math.ceil((state.graceUntil :: number) - now) else 0
end

function Breakdown.lost(state: State): boolean
	return state.phase == "Lost"
end

return table.freeze(Breakdown)
