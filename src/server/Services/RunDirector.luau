--!strict
--[[
	Owns the run clock and is the only writer of run.phase.
	Rules come from Logic/RunRules; this module performs the side effects of
	entering and leaving each phase and publishes the timestamps clients count
	down from. Each Heartbeat: global guards first, then timer expiry.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)
local DifficultyModel = require(Shared.Logic.DifficultyModel)
local LayoutGen = require(Shared.Logic.LayoutGen)
local Ledger = require(Shared.Logic.Ledger)
local Mystery = require(Shared.Logic.Mystery)
local RouteGen = require(Shared.Logic.RouteGen)
local RunLog = require(Shared.Logic.RunLog)
local RunRules = require(Shared.Logic.RunRules)
local Format = require(Shared.Util.Format)
local Rng = require(Shared.Util.Rng)
local Safe = require(Shared.Util.Safe)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

type Phase = Types.Phase

local RunDirector = {
	PhaseChanged = Signal.new() :: Signal.Signal<string, string>,
}

type RunState = {
	phase: Phase,
	startedAt: number,
	endsAt: number?,
	runId: string,
	seed: number,
	nextStop: number,
	stationsCleared: number,
	runTier: number,
	lastArchetype: string?,
	chosen: Types.RouteOption?,
	cruiseSeconds: number,
	params: Types.HazardParams?,
	info: Types.StationInfo?,
	plan: LayoutGen.Plan?,
	outcome: Types.Outcome?,
	departed: boolean, -- false only during the Last Call grace, while the station is still docked
	mystery: Mystery.History, -- junctions since the last mystery ticket
	sealed: boolean, -- this leg's destination is a mystery not yet revealed
	forceMystery: boolean, -- Dev `mystery`: the next ballot has one
	pending: Types.LogEntry?, -- this stop's run.log entry, appended when the stop resolves
}

local state: RunState = {
	phase = "Lobby",
	startedAt = 0,
	endsAt = nil,
	runId = "",
	seed = 0,
	nextStop = 1,
	stationsCleared = 0,
	runTier = 1,
	lastArchetype = nil,
	chosen = nil,
	cruiseSeconds = 30,
	params = nil,
	info = nil,
	plan = nil,
	outcome = nil,
	departed = true,
	mystery = Mystery.newHistory(),
	sealed = false,
	forceMystery = false,
	pending = nil,
}

local rng = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish()
	StateService.Set({ "run", "phase" }, state.phase)
	StateService.Set({ "run", "phaseStartedAt" }, state.startedAt)
	StateService.Set({ "run", "phaseEndsAt" }, state.endsAt)
	StateService.Set({ "run", "runId" }, state.runId)
	StateService.Set({ "run", "seed" }, state.seed)
	StateService.Set({ "run", "nextStop" }, state.nextStop)
	StateService.Set({ "run", "stationsCleared" }, state.stationsCleared)
	StateService.Set({ "run", "stopCount" }, Tuning.Run.StationCount)
	StateService.Set({ "run", "outcome" }, state.outcome)
end

local function context(): RunRules.Context
	return {
		nextStop = state.nextStop,
		stopCount = Tuning.Run.StationCount,
		readyCount = Registry.LobbyService.ReadyCount(),
		lobbyCount = Registry.LobbyService.LobbyCount(),
		crewAlive = Registry.CrewService.AliveCount(),
		integrity = Registry.TrainService.Integrity(),
		playerCount = #Players:GetPlayers(),
		cruiseSeconds = state.cruiseSeconds,
		dwellSeconds = if state.params then state.params.dwell else 60,
		chaseSeconds = if state.params then state.params.chaseWindow else 6,
	}
end

-- The stop has resolved: its entry joins run.log (Logic/RunLog).
local function logStop(outcome: Types.StopOutcome, closeCalls: { string }?)
	local pending = state.pending
	if pending == nil then
		return
	end
	state.pending = nil
	local log = StateService.Get({ "run", "log" }) :: { Types.LogEntry }?
	StateService.Set({ "run", "log" }, RunLog.append(log, RunLog.resolve(pending, outcome, closeCalls)))
end

local function cleanupRun()
	Registry.HazardDirector.Stop()
	Registry.HollowService.Clear()
	Registry.StationService.Clear()
	Registry.RouteService.Clear()
	Registry.TrainService.ClearBreaches()
	Registry.TrainService.SetDoors(false)
	Registry.CrewService.EndRun()
	state.info, state.plan, state.params, state.chosen = nil, nil, nil, nil
	StateService.Set({ "run", "station" }, nil)
	StateService.Set({ "run", "destination" }, nil)
end

-- Phase entry ---------------------------------------------------------------------------

local Enter: { [string]: (previous: Phase, outcome: Types.Outcome?) -> () } = {}
local Exit: { [string]: (nextPhase: Phase) -> () } = {}

Enter.Lobby = function(previous)
	if RunRules.isRunPhase(previous) or previous == "RunEnd" then
		cleanupRun()
	end
	state.outcome = nil
	Registry.LobbyService.ResetReady()
	Registry.CosmeticService.RefreshLivery()
end

Enter.Boarding = function()
	state.runId = HttpService:GenerateGUID(false)
	state.seed = rng:NextInteger(1, 2147483646)
	state.nextStop = 1
	state.stationsCleared = 0
	state.lastArchetype = nil
	state.outcome = nil
	state.mystery = Mystery.newHistory()
	state.sealed = false
	state.pending = nil
	StateService.Set({ "run", "log" }, {})
	StateService.Set({ "stats" }, { coalDelivered = 0, partsDelivered = 0, relics = 0, stationsCleared = 0 })
	local crew = Registry.LobbyService.TakeCrew()
	state.runTier = Registry.LobbyService.TierFor(crew)
	StateService.Set({ "run", "tier" }, state.runTier)
	Registry.TrainService.ResetForRun()
	Registry.TrainService.SetDoors(false)
	Registry.CrewService.BeginRun(crew)
	Registry.CosmeticService.RefreshLivery()
	Registry.LobbyService.ResetReady()
end

-- The ballot, with a sealed mystery ticket when Logic/Mystery says so. Its real station comes from a
-- seed only the server holds and is handed to RouteService alone; state sees the stand-in.
local function openBallot()
	local leg, stops = state.nextStop, Tuning.Run.StationCount
	local options = RouteGen.options(state.seed, leg, stops, state.lastArchetype)
	local roll = Rng.new(Rng.derive(state.seed, "mystery", leg)):next()
	local offered = state.forceMystery and leg <= stops or Mystery.offers(state.mystery, leg, stops, roll)
	local sealed: { [number]: Types.RouteOption } = {}
	local real = if offered
		then Mystery.pick(rng:NextInteger(1, 2147483646), leg, stops, state.lastArchetype, options)
		else nil
	if real then
		local index = Mystery.place(options)
		options[index] = Mystery.redact(real)
		sealed[index] = real
	end
	state.forceMystery = false
	state.mystery = Mystery.record(state.mystery, real ~= nil)
	Registry.RouteService.Open(options, sealed)
end

Enter.Junction = function()
	openBallot()
	local d = DifficultyModel.forStop(
		math.min(state.nextStop, Tuning.Run.StationCount),
		Tuning.Run.StationCount,
		2,
		state.runTier
	)
	Registry.TrainService.SetBreachRate(DifficultyModel.breachRate(d, Registry.TrainService.Get().upgrades))
end

Enter.Cruise = function()
	local index, ticket, option = Registry.RouteService.Close()
	local arch = Stations.List[option.archetype]
	local d = if arch.terminus
		then 0
		else DifficultyModel.forStop(state.nextStop, Tuning.Run.StationCount, option.tier, state.runTier)
	local train = Registry.TrainService.Get()
	state.chosen = option
	state.lastArchetype = option.archetype
	state.params = DifficultyModel.params(d, arch, Registry.CrewService.AliveCount(), train.upgrades)
	state.sealed = Mystery.isSealed(ticket)
	if state.sealed then
		local params = state.params :: Types.HazardParams
		params.lootMul = Mystery.lootMul(params.lootMul)
	end
	state.cruiseSeconds = DifficultyModel.cruiseSeconds(option.distanceKm)
	Registry.TrainService.BeginLeg(
		option.distanceKm,
		state.cruiseSeconds,
		(state.params :: Types.HazardParams).breachRate
	)
	local coalCost = Ledger.legCoalCost(train, option.distanceKm)
	local destination: Types.Destination = if state.sealed
		then Mystery.sealed(option.distanceKm, coalCost, option.archetype)
		else {
			archetype = option.archetype,
			name = arch.name,
			tier = option.tier,
			distanceKm = option.distanceKm,
			difficulty = d,
			coalCost = coalCost,
			terminus = arch.terminus == true,
		}
	StateService.Set({ "run", "destination" }, destination)
	local ballot =
		StateService.Get({ "run", "route" }) :: { options: { Types.RouteOption }, votes: { [string]: number }? }?
	state.pending = RunLog.entry({
		stop = state.nextStop,
		ticket = ticket,
		name = arch.name,
		difficulty = d,
		coalBurned = coalCost,
		votes = ballot and ballot.votes,
		optionCount = if ballot then #ballot.options else index,
		chosen = index,
	})
end

Enter.Arrival = function()
	Registry.TrainService.EndLeg()
	local option = state.chosen :: Types.RouteOption
	local params = state.params :: Types.HazardParams
	local arch = Stations.List[option.archetype]
	local layoutSeed = Rng.derive(state.seed, "station", state.nextStop)
	local plan = LayoutGen.generate(option.archetype, layoutSeed, params.lootMul)
	local startedAt = now() + Tuning.Run.ArrivalSeconds
	local info: Types.StationInfo = {
		archetype = option.archetype,
		name = arch.name,
		tier = option.tier,
		difficulty = params.difficulty,
		dwell = params.dwell,
		lastCall = Tuning.Run.LastCallSeconds,
		length = plan.length,
		depth = plan.depth,
		startedAt = startedAt,
		departAt = startedAt + params.dwell,
		layoutSeed = layoutSeed,
		hazards = params,
		terminus = arch.terminus == true,
	}
	state.info = info
	state.plan = plan
	Registry.StationService.Spawn(plan, info)
	StateService.Set({ "run", "station" }, info)
	if state.sealed then
		-- the reveal: the full destination replaces the sealed one (UI/Unseal plays it)
		state.sealed = false
		local destination: Types.Destination = {
			archetype = option.archetype,
			name = arch.name,
			tier = option.tier,
			distanceKm = option.distanceKm,
			difficulty = params.difficulty,
			coalCost = (StateService.Get({ "run", "destination", "coalCost" }) :: number?) or 0,
			terminus = false,
			mystery = true,
			sealed = false,
		}
		StateService.Set({ "run", "destination" }, destination)
		if state.pending then
			state.pending =
				RunLog.reveal(state.pending, option.archetype, arch.name, option.tier, params.difficulty)
		end
	end
end

Enter.Dwell = function()
	local info = state.info :: Types.StationInfo
	local plan = state.plan :: LayoutGen.Plan
	Registry.StationService.Dock()
	-- The doors open now: re-anchor the station clock to this exact moment.
	info.startedAt = now()
	info.departAt = info.startedAt + info.dwell
	Registry.StationService.SetInfo(info)
	StateService.Set({ "run", "station" }, info)
	Registry.TrainService.SetDoors(true)
	local built = Registry.StationService.Built()
	if built then
		Registry.LootService.Activate(built, plan)
		Registry.BuildingService.Activate(built, plan)
	end
	Registry.HazardDirector.Begin(plan, info)
	Registry.CrewService.SpawnPendingJoiners()
	NetService.FireAll(
		"Notify",
		"Station",
		`{info.name}. Doors open. Departure in {Format.clock(info.dwell)}.`
	)
end

Enter.LastCall = function()
	NetService.FireAll("Notify", "LastCall", "Last call! The train leaves in 15 seconds.")
end

-- The actual departure: the end of the Last Call grace (at once when there is none).
local function depart()
	state.departed = true
	local params = state.params :: Types.HazardParams
	Registry.HazardDirector.Freeze()
	Registry.HollowService.LetGo()
	Registry.StationService.BeginDeparture(params.departureAccel)
end

-- T-0: the whistle blows. The station stays docked through the grace, then departs (tick).
Enter.Departure = function()
	Registry.CrewService.MarkLastCall()
	local info = state.info
	local grace = RunRules.graceSeconds()
	if info and grace > 0 then
		state.departed = false
		info.lastCallEndsAt = now() + grace
		Registry.StationService.SetInfo(info)
		StateService.Set({ "run", "station" }, info)
	else
		depart()
	end
end

Exit.Departure = function(nextPhase)
	state.departed = true
	if nextPhase == "Junction" then
		local closeCalls = Registry.CrewService.ResolveDeparture()
		-- the last of the crew left behind: the run ends at this stop, not the next
		logStop(if Registry.CrewService.AliveCount() > 0 then "Cleared" else "Wiped", closeCalls)
		state.stationsCleared += 1
		state.nextStop += 1
		StateService.Update({ "stats" }, function(stats)
			local s = stats or { coalDelivered = 0, partsDelivered = 0, relics = 0, stationsCleared = 0 }
			s.stationsCleared = state.stationsCleared
			return s
		end)
	end
	Registry.TrainService.SetDoors(false)
	Registry.HazardDirector.Stop()
	Registry.StationService.ReleaseAfter(Tuning.Motion.DepartureLingerSeconds)
end

Enter.Terminus = function()
	Registry.StationService.Dock()
	Registry.TrainService.SetDoors(true)
	Registry.CrewService.MarkTerminus()
	NetService.FireAll("Notify", "Station", "Terminus. End of the line. You made it.")
end

Enter.RunEnd = function(previous, outcome)
	state.outcome = outcome or (if previous == "Terminus" then "Victory" else "Wiped")
	Registry.HazardDirector.Stop()
	Registry.HollowService.Clear()
	local finalOutcome = state.outcome :: Types.Outcome
	logStop(finalOutcome :: any, nil) -- Outcome is a subset of StopOutcome
	Registry.ProgressionService.PayRun(
		finalOutcome,
		Registry.CrewService.Tallies(),
		state.stationsCleared,
		state.runTier
	)
	local text = {
		Victory = "The train reached the Terminus.",
		Wiped = "The whole crew was lost.",
		Derailed = "The train broke down on the line.",
	}
	NetService.FireAll("Notify", "RunEnd", text[finalOutcome])
end

-- Transitions --------------------------------------------------------------------------------

local function transition(nextPhase: any, outcome: any)
	local previous = state.phase
	local exitFn = Exit[previous]
	if exitFn then
		Safe.call(`RunDirector.exit {previous}`, exitFn, nextPhase)
	end
	state.phase = nextPhase
	state.startedAt = now()
	local enterFn = Enter[nextPhase]
	if enterFn then
		Safe.call(`RunDirector.enter {nextPhase}`, enterFn, previous, outcome)
	end
	local duration = RunRules.duration(nextPhase, context())
	state.endsAt = if duration then state.startedAt + duration else nil
	if nextPhase == "LastCall" and state.info then
		-- Anchor to the published departure so the clock and the phase can never disagree.
		state.endsAt = state.info.departAt
	end
	publish()
	RunDirector.PhaseChanged:Fire(nextPhase, previous)
end

local function tick()
	local ctx = context()
	local guardPhase, outcome = RunRules.guard(state.phase, ctx)
	if guardPhase and guardPhase ~= state.phase then
		transition(guardPhase, outcome)
		return
	end
	if state.phase == "Departure" and not state.departed then
		local info = state.info
		if RunRules.hasDeparted(info and info.lastCallEndsAt, now()) then
			Safe.call("RunDirector.depart", depart)
		end
	end
	if state.endsAt and now() >= state.endsAt then
		transition(RunRules.next(state.phase, ctx), nil)
	end
end

function RunDirector.Init() end

function RunDirector.Start()
	state.startedAt = now()
	publish()
	RunService.Heartbeat:Connect(function()
		Safe.call("RunDirector.tick", tick)
	end)
end

-- Studio developer console: end the current phase on the next tick.
function RunDirector.ForceAdvance()
	if state.endsAt then
		state.endsAt = now()
	end
end

-- Studio developer console: move the station clock forward by `seconds`.
function RunDirector.DevWarp(seconds: number)
	local info = state.info
	if info then
		info.startedAt -= seconds
		info.departAt -= seconds
		if info.lastCallEndsAt then
			info.lastCallEndsAt -= seconds
		end
		Registry.StationService.SetInfo(info)
		StateService.Set({ "run", "station" }, info)
	end
	if state.endsAt then
		state.endsAt -= seconds
		StateService.Set({ "run", "phaseEndsAt" }, state.endsAt)
	end
end

-- Studio only (DevService `mystery`): the next ballot carries a mystery ticket; at a junction, now.
function RunDirector.DevForceMystery()
	state.forceMystery = true
	if state.phase == "Junction" then
		openBallot()
	end
end

-- Starts a run at once for `crew`: a departing boarding car (Studio), or a car's reserved server.
function RunDirector.Launch(crew: { Player }): boolean
	if state.phase ~= "Lobby" and state.phase ~= "Countdown" then
		return false
	end
	Registry.LobbyService.SetCrew(crew)
	transition("Boarding", nil)
	return true
end

function RunDirector.Phase(): Phase
	return state.phase
end

function RunDirector.PhaseEndsAt(): number?
	return state.endsAt
end

function RunDirector.NextStop(): number
	return state.nextStop
end

function RunDirector.StationsCleared(): number
	return state.stationsCleared
end

return RunDirector
