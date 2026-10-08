--!strict
--[[
	The run state machine as data and pure functions. RunDirector owns the
	clock and the side effects; this module owns the rules.

	Timer expiry:  RunRules.next(phase, ctx)
	Every tick:    RunRules.guard(phase, ctx) may override the phase.
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local Types = require(Shared.Types)

type Phase = Types.Phase
type Outcome = Types.Outcome

export type Context = {
	nextStop: number, -- the stop the train is heading to or standing at (1..stopCount + 1)
	stopCount: number,
	readyCount: number,
	lobbyCount: number,
	crewAlive: number,
	integrity: number,
	playerCount: number,
	cruiseSeconds: number,
	dwellSeconds: number,
	chaseSeconds: number,
}

local RUN_PHASES: { [Phase]: boolean } = {
	Boarding = true,
	Junction = true,
	Cruise = true,
	Arrival = true,
	Dwell = true,
	LastCall = true,
	Departure = true,
	Terminus = true,
}

local RunRules = {}

RunRules.Phases = table.freeze({
	"Lobby",
	"Countdown",
	"Boarding",
	"Junction",
	"Cruise",
	"Arrival",
	"Dwell",
	"LastCall",
	"Departure",
	"Terminus",
	"RunEnd",
} :: { Phase })

function RunRules.isRunPhase(phase: Phase): boolean
	return RUN_PHASES[phase] == true
end

function RunRules.isTravel(phase: Phase): boolean
	return phase == "Junction" or phase == "Cruise"
end

-- Doors open, loot live, hazards running.
function RunRules.isStationOpen(phase: Phase): boolean
	return phase == "Dwell" or phase == "LastCall" or phase == "Departure"
end

function RunRules.isFinalLeg(ctx: Context): boolean
	return ctx.nextStop > ctx.stopCount
end

function RunRules.requiredReady(lobbyCount: number): number
	return math.max(1, math.ceil(lobbyCount * Tuning.Run.MinReadyShare))
end

--[[
	Departure opens with the Last Call grace: the whistle has blown at T-0 (run.station.departAt) but
	the station stays docked until run.station.lastCallEndsAt; then it moves and the chase window runs.
]]
function RunRules.graceSeconds(): number
	local grace = Tuning.LastCallGrace
	return if grace.Enabled then grace.Seconds else 0
end

-- Inside Departure: true once the grace is over (or there is none) and the station is moving.
function RunRules.hasDeparted(lastCallEndsAt: number?, now: number): boolean
	return lastCallEndsAt == nil or now >= lastCallEndsAt
end

-- The crew who were not aboard at T-0 (`missing`) but are aboard when the stop resolves.
function RunRules.closeCalls<K>(missing: { [K]: boolean }, aboard: { [K]: boolean }): { K }
	local out: { K } = {}
	for key in missing do
		if aboard[key] then
			table.insert(out, key)
		end
	end
	return out
end

function RunRules.duration(phase: Phase, ctx: Context): number?
	local run = Tuning.Run
	if phase == "Countdown" then
		return run.CountdownSeconds
	elseif phase == "Boarding" then
		return run.BoardingSeconds
	elseif phase == "Junction" then
		return if RunRules.isFinalLeg(ctx) then run.FinalJunctionSeconds else run.JunctionSeconds
	elseif phase == "Cruise" then
		return ctx.cruiseSeconds
	elseif phase == "Arrival" then
		return run.ArrivalSeconds
	elseif phase == "Dwell" then
		return math.max(ctx.dwellSeconds - run.LastCallSeconds, 1)
	elseif phase == "LastCall" then
		return run.LastCallSeconds
	elseif phase == "Departure" then
		return RunRules.graceSeconds() + ctx.chaseSeconds
	elseif phase == "Terminus" then
		return run.TerminusSeconds
	elseif phase == "RunEnd" then
		return run.RunEndSeconds
	end
	return nil
end

function RunRules.next(phase: Phase, ctx: Context): Phase
	if phase == "Countdown" then
		return "Boarding"
	elseif phase == "Boarding" then
		return "Junction"
	elseif phase == "Junction" then
		return "Cruise"
	elseif phase == "Cruise" then
		return "Arrival"
	elseif phase == "Arrival" then
		return if RunRules.isFinalLeg(ctx) then "Terminus" else "Dwell"
	elseif phase == "Dwell" then
		return "LastCall"
	elseif phase == "LastCall" then
		return "Departure"
	elseif phase == "Departure" then
		return "Junction"
	elseif phase == "Terminus" then
		return "RunEnd"
	end
	return "Lobby"
end

function RunRules.guard(phase: Phase, ctx: Context): (Phase?, Outcome?)
	if ctx.playerCount == 0 then
		return if phase ~= "Lobby" then "Lobby" else nil, nil
	end
	if RunRules.isRunPhase(phase) and phase ~= "Boarding" then
		if ctx.crewAlive <= 0 then
			return "RunEnd", "Wiped"
		end
		if ctx.integrity <= 0 then
			return "RunEnd", "Derailed"
		end
	end
	if
		phase == "Lobby"
		and ctx.lobbyCount > 0
		and ctx.readyCount >= RunRules.requiredReady(ctx.lobbyCount)
	then
		return "Countdown", nil
	end
	if phase == "Countdown" and ctx.readyCount < RunRules.requiredReady(ctx.lobbyCount) then
		return "Lobby", nil
	end
	return nil, nil
end

return table.freeze(RunRules)
