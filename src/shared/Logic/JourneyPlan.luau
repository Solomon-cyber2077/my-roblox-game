--!strict
--[[
	The journey's live plan, advanced one frame at a time from the replicated run
	state. Pure (no engine access), so Lune specs can play whole runs through it.

	SceneryController calls JourneyPlan.step every frame and rebuilds the chunks
	each returned change names; the chunk builders read the plan (seed, base
	biome, transitions, set pieces, sinkholes).

	  * a new run (runId) resets the plan and asks for a full rebuild
	  * Departure starts the next leg and plans its set pieces
	  * in Cruise the dock is predicted from the clock: the station's sinkhole is
	    cut there, the leg's pieces are trimmed clear of it, and the destination
	    biome is scheduled to blend in from BlendAt of the leg
	  * once a station is present the dock is checked against where it really is
	    and re-cut when it is more than DockTolerance out (dev skips, late joins)

	JourneyPlan.speed is the scenery's scroll speed for a frame: it follows a
	moving station's velocity. JourneyPlan.correction then steers the odometer
	onto the station's own position (the dock it is arriving at or leaving), so
	rounding never accumulates and a station sits exactly in its sinkhole.
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local Stations = require(Shared.Config.Stations)
local Journey = require(Shared.Logic.Journey)
local Motion = require(Shared.Logic.Motion)
local MathX = require(Shared.Util.MathX)

export type Plan = {
	seed: number,
	base: Journey.Biome,
	transitions: { Journey.Transition },
	pieces: { Journey.Piece },
	sinkholes: { Journey.Sinkhole },
	runKey: string?,
	leg: number,
	legStart: number,
	upcoming: Journey.Sinkhole?,
	lastDock: number?, -- land x of the dock the train last left
	transitionLeg: number,
	stationChecked: boolean,
	lastPhase: string,
	progress: number,
	skyProgress: number, -- progress as the sky and the clock count it (Journey.skyProgress)
	skyLeg: number, -- the leg skyShare belongs to
	skyShare: number, -- the leg's share as the sky counts it: it never runs backwards
}

export type RunState = {
	runId: string?,
	seed: number?,
	stopCount: number?,
	nextStop: number?,
	phaseStartedAt: number?,
	phaseEndsAt: number?,
	destination: { archetype: string }?,
	station: { archetype: string, startedAt: number?, dwell: number? }?,
}

export type Input = {
	phase: string,
	active: boolean, -- the phase belongs to a run (RunRules.isRunPhase)
	run: RunState?,
	odometer: number,
	speed: number, -- the scenery's speed this frame
	now: number,
	stationX: number?, -- world x of the present station's centre, when there is one
}

-- Land range [x0, x1] to rebuild; chunks starting less than minAhead ahead of the train are kept.
export type Change = { x0: number, x1: number, minAhead: number? }

export type Result = { changes: { Change }, rebuild: boolean }

local J = Tuning.Journey

local JourneyPlan = {}

JourneyPlan.DefaultSeed = 1931

function JourneyPlan.new(): Plan
	return {
		seed = JourneyPlan.DefaultSeed,
		base = Journey.FirstBiome,
		transitions = {},
		pieces = {},
		sinkholes = {},
		runKey = nil,
		leg = 0,
		legStart = 0,
		upcoming = nil,
		lastDock = nil,
		transitionLeg = 0,
		stationChecked = false,
		lastPhase = "",
		progress = 0,
		skyProgress = 0,
		skyLeg = 0,
		skyShare = 0,
	}
end

local function beginLeg(plan: Plan, leg: number, odometer: number, stops: number)
	plan.leg = leg
	plan.legStart = odometer
	plan.lastDock = if plan.upcoming then plan.upcoming.center else nil
	plan.upcoming = nil
	plan.stationChecked = false
	for _, piece in Journey.legPlan(plan.seed, leg, odometer, leg > stops) do
		table.insert(plan.pieces, piece)
	end
	local pieces: { Journey.Piece } = {}
	for _, piece in plan.pieces do
		if piece.at + piece.length > odometer - J.PruneBehind then
			table.insert(pieces, piece)
		end
	end
	plan.pieces = pieces
	local sinkholes: { Journey.Sinkhole } = {}
	for _, sinkhole in plan.sinkholes do
		if sinkhole.rect.x1 > odometer - J.PruneBehind then
			table.insert(sinkholes, sinkhole)
		end
	end
	plan.sinkholes = sinkholes
end

-- Cuts (or re-cuts) the sinkhole for the station the train is heading to.
local function setUpcoming(
	plan: Plan,
	center: number,
	archetype: string,
	odometer: number,
	changes: { Change }
)
	local arch = Stations.List[archetype]
	if arch == nil then
		return
	end
	local old = plan.upcoming
	if old then
		local index = table.find(plan.sinkholes, old)
		if index then
			table.remove(plan.sinkholes, index)
		end
		table.insert(changes, { x0 = old.rect.x0 - 20, x1 = old.rect.x1 + 20 })
	end
	local sinkhole = Journey.sinkhole(center, arch.length, arch.depth, arch.id, arch.terminus == true)
	table.insert(plan.sinkholes, sinkhole)
	plan.upcoming = sinkhole
	table.insert(changes, { x0 = sinkhole.rect.x0 - 20, x1 = sinkhole.rect.x1 + 20 })

	-- this leg's set pieces must end clear of the dock
	local kept: { Journey.Piece } = {}
	for _, piece in plan.pieces do
		if piece.leg ~= plan.leg or #Journey.trim({ piece }, sinkhole) == 1 then
			table.insert(kept, piece)
		else
			local footprint = Journey.footprint(piece)
			table.insert(changes, { x0 = footprint.x0, x1 = footprint.x1 })
		end
	end
	plan.pieces = kept

	-- the destination's biome takes over from BlendAt of the leg, beyond what is built
	if plan.transitionLeg ~= plan.leg then
		plan.transitionLeg = plan.leg
		local at = Journey.blendStart(plan.legStart, center, odometer + J.BuiltAhead + 100)
		table.insert(
			plan.transitions,
			{ at = at, length = J.BlendLength, biome = Journey.biomeFor(archetype) }
		)
		table.sort(plan.transitions, function(a, b)
			return a.at < b.at
		end)
		table.insert(changes, { x0 = at, x1 = odometer + 20000, minAhead = J.BuiltAhead })
	end
end

local function startRun(plan: Plan, run: RunState, phase: string, odometer: number)
	local runId = run.runId :: string
	local destination = run.destination
	local base = if phase == "Boarding" or destination == nil
		then Journey.FirstBiome
		else Journey.biomeFor(destination.archetype)
	plan.seed = run.seed or JourneyPlan.DefaultSeed
	plan.base = base
	plan.transitions = {}
	plan.pieces = {}
	plan.sinkholes = {}
	plan.upcoming = nil
	plan.lastDock = nil
	plan.runKey = runId
	plan.transitionLeg = 0
	plan.lastPhase = phase
	local stops = run.stopCount or Tuning.Run.StationCount
	local leg = math.max(run.nextStop or 1, 1) + (if phase == "Departure" then 1 else 0)
	beginLeg(plan, leg, odometer, stops)
end

-- Advances the plan by one frame.
function JourneyPlan.step(plan: Plan, input: Input): Result
	local changes: { Change } = {}
	local result: Result = { changes = changes, rebuild = false }
	local run = input.run
	local phase = input.phase
	if run == nil then
		return result
	end
	if input.active and run.runId and run.runId ~= plan.runKey then
		startRun(plan, run, phase, input.odometer)
		result.rebuild = true
	end
	if plan.runKey == nil then
		return result
	end

	local stops = run.stopCount or Tuning.Run.StationCount
	if phase ~= plan.lastPhase then
		if phase == "Departure" then
			beginLeg(plan, (run.nextStop or plan.leg) + 1, input.odometer, stops)
		end
		plan.stationChecked = false
		plan.lastPhase = phase
	end

	local destination = run.destination
	if phase == "Cruise" and destination and run.phaseEndsAt then
		local predicted = Journey.dockFromCruise(input.odometer, run.phaseEndsAt - input.now, input.speed)
		local upcoming = plan.upcoming
		if upcoming == nil or math.abs(predicted - upcoming.center) > J.DockTolerance then
			setUpcoming(plan, predicted, destination.archetype, input.odometer, changes)
		end
	end
	local station = run.station
	local stationPhase = phase == "Arrival" or phase == "Dwell" or phase == "LastCall" or phase == "Terminus"
	if stationPhase and station and input.stationX and not plan.stationChecked then
		plan.stationChecked = true
		local actual = input.odometer + input.stationX
		local upcoming = plan.upcoming
		if upcoming == nil or math.abs(actual - upcoming.center) > J.DockTolerance then
			setUpcoming(plan, actual, station.archetype, input.odometer, changes)
		end
	end

	if input.active then
		local dock = if plan.upcoming then plan.upcoming.center else nil
		local share = Journey.legShare(input.odometer, plan.legStart, dock)
		plan.progress = Journey.progress(plan.leg, share)
		-- a dock first predicted (or re-cut) further off shrinks the share; the clock waits for it
		-- instead of running backwards
		if plan.skyLeg ~= plan.leg then
			plan.skyLeg = plan.leg
			plan.skyShare = share
		else
			plan.skyShare = math.max(plan.skyShare, share)
		end
		-- how far through the stop the crew is: the clock keeps running while the doors are open
		local stay = 0
		if phase == "Terminus" then
			-- the sun comes up over the last platform
			local started = run.phaseStartedAt or input.now
			local length = if run.phaseEndsAt then run.phaseEndsAt - started else 1
			stay = MathX.saturate((input.now - started) / math.max(length, 1))
		elseif
			(phase == "Dwell" or phase == "LastCall")
			and station
			and station.startedAt
			and station.dwell
		then
			stay = MathX.saturate((input.now - station.startedAt) / math.max(station.dwell, 1))
		end
		plan.skyProgress = Journey.skyProgress(plan.leg, plan.skyShare, stay)
	elseif phase == "Lobby" then
		plan.progress = 0
		plan.skyProgress = 0
		plan.skyLeg = 0
		plan.skyShare = 0
	end
	return result
end

--[[
	The scenery's scroll speed this frame (studs per second toward -X).
	stationVelocity: the present station's velocity along X, when there is one.
	phaseElapsed: seconds since the phase began (used when the station is missing).
]]
function JourneyPlan.speed(
	current: number,
	phase: string,
	dt: number,
	stationVelocity: number?,
	phaseElapsed: number
): number
	local motion = Tuning.Motion
	if (phase == "Arrival" or phase == "Departure") and stationVelocity then
		return math.max(-stationVelocity, 0)
	end
	if phase == "Arrival" then
		return -Motion.arrivalVelocity(phaseElapsed)
	end
	-- the station just left keeps pulling away for a while: stay locked to it
	if phase == "Junction" and stationVelocity and stationVelocity < -1 then
		return -stationVelocity
	end
	if phase == "Junction" or phase == "Cruise" or phase == "Boarding" then
		return MathX.approach(current, motion.CruiseSpeed, motion.SpinUp * dt)
	end
	if phase == "Departure" then
		return MathX.approach(current, motion.CruiseSpeed, motion.DepartureSpinUp * dt)
	end
	if phase == "RunEnd" then
		return MathX.approach(current, 0, motion.RunEndBrake * dt)
	end
	return 0
end

-- Fraction of the odometer error removed per second while a station is moving.
local CORRECTION_RATE = 2.5

--[[
	How far to move the odometer this frame so the present station stays on its
	dock: exactly while it stands still, smoothly while it moves. Zero when no
	station or no dock applies. Call after JourneyPlan.step.
]]
function JourneyPlan.correction(
	plan: Plan,
	phase: string,
	odometer: number,
	stationX: number?,
	dt: number
): number
	if stationX == nil then
		return 0
	end
	local dock: number? = nil
	if phase == "Arrival" or phase == "Dwell" or phase == "LastCall" or phase == "Terminus" then
		dock = if plan.upcoming then plan.upcoming.center else nil
	elseif phase == "Departure" or phase == "Junction" then
		dock = plan.lastDock
	end
	if dock == nil then
		return 0
	end
	local error = dock - stationX - odometer
	if phase == "Arrival" or phase == "Departure" or phase == "Junction" then
		return error * math.min(1, dt * CORRECTION_RATE)
	end
	return error
end

return table.freeze(JourneyPlan)
