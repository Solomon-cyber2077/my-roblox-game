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
local RouteGen = require(Shared.Logic.RouteGen)
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
	lastArchetype: string?,
	chosen: Types.RouteOption?,
	cruiseSeconds: number,
	params: Types.HazardParams?,
	info: Types.StationInfo?,
	plan: LayoutGen.Plan?,
	outcome: Types.Outcome?,
}

local state: RunState = {
	phase = "Lobby",
	startedAt = 0,
	endsAt = nil,
	runId = "",
	seed = 0,
	nextStop = 1,
	stationsCleared = 0,
	lastArchetype = nil,
	chosen = nil,
	cruiseSeconds = 30,
	params = nil,
	info = nil,
	plan = nil,
	outcome = nil,
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
	StateService.Set({ "stats" }, { coalDelivered = 0, partsDelivered = 0, relics = 0, stationsCleared = 0 })
	local crew = Registry.LobbyService.LobbyPlayers()
	Registry.TrainService.ResetForRun()
	Registry.TrainService.SetDoors(false)
	Registry.CrewService.BeginRun(crew)
	Registry.CosmeticService.RefreshLivery()
	Registry.LobbyService.ResetReady()
end

Enter.Junction = function()
	local options = RouteGen.options(state.seed, state.nextStop, Tuning.Run.StationCount, state.lastArchetype)
	Registry.RouteService.Open(options)
	local d =
		DifficultyModel.forStop(math.min(state.nextStop, Tuning.Run.StationCount), Tuning.Run.StationCount, 2)
	Registry.TrainService.SetBreachRate(DifficultyModel.breachRate(d, Registry.TrainService.Get().upgrades))
end

Enter.Cruise = function()
	local _, option = Registry.RouteService.Close()
	local arch = Stations.List[option.archetype]
	local d = if arch.terminus
		then 0
		else DifficultyModel.forStop(state.nextStop, Tuning.Run.StationCount, option.tier)
	local train = Registry.TrainService.Get()
	state.chosen = option
	state.lastArchetype = option.archetype
	state.params = DifficultyModel.params(d, arch, Registry.CrewService.AliveCount(), train.upgrades)
	state.cruiseSeconds = DifficultyModel.cruiseSeconds(option.distanceKm)
	Registry.TrainService.BeginLeg(
		option.distanceKm,
		state.cruiseSeconds,
		(state.params :: Types.HazardParams).breachRate
	)
	StateService.Set({ "run", "destination" }, {
		archetype = option.archetype,
		name = arch.name,
		tier = option.tier,
		distanceKm = option.distanceKm,
		difficulty = d,
		coalCost = Ledger.legCoalCost(train, option.distanceKm),
		terminus = arch.terminus == true,
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

Enter.Departure = function()
	local params = state.params :: Types.HazardParams
	Registry.HazardDirector.Freeze()
	Registry.StationService.BeginDeparture(params.departureAccel)
end

Exit.Departure = function(nextPhase)
	if nextPhase == "Junction" then
		Registry.CrewService.ResolveDeparture()
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
	Registry.ProgressionService.PayRun(finalOutcome, Registry.CrewService.Tallies(), state.stationsCleared)
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
		Registry.StationService.SetInfo(info)
		StateService.Set({ "run", "station" }, info)
	end
	if state.endsAt then
		state.endsAt -= seconds
		StateService.Set({ "run", "phaseEndsAt" }, state.endsAt)
	end
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
