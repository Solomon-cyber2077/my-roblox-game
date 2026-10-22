--!strict
--[[
	Telemetry (docs/FINAL-DESIGN.md Prompt 0, A.4). The only caller of AnalyticsService.

	  Event(player, name, value, fields)                 a custom event (Config/Telemetry Events)
	  Funnel(player, funnel, sessionId, step, name, fields)
	                                                     onboarding through LogOnboardingFunnelStepEvent
	                                                     (no session id); other funnels through
	                                                     LogFunnelStepEvent with a server-made id
	  Brass(player, flow, amount, balance, sku)          Brass sources and sinks, LogEconomyEvent

	Every call is checked against the frozen vocabularies (Logic/Telemetry) and attributed to a
	connected Player. Crew events go once per run or stop to the first connected run member; player
	events once per player occurrence; identity (run, stop, player) only dedupes, never fills a field.
	The run is watched through RunDirector.PhaseChanged, state and a few hooks (CrewService,
	HollowService, ProgressionService, ShopService); bell, grasp, tell and AGAIN events come with
	Prompts 2, 4 and 5.

	Every call is also kept in the durable playtest sink (Logic/TelemetrySink): buffered per player,
	flushed to a DataStore every SinkFlushSeconds, on leaving and at shutdown, never in the way of the
	AnalyticsService call. Dev `telemetry dump [serverId]` reads it back as CSV. In Studio each call
	prints one diagnostic line; that output does not prove the event reached the dashboard.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Telemetry)
local Tuning = require(Shared.Config.Tuning)
local Experiments = require(Shared.Logic.Experiments)
local Retry = require(Shared.Logic.Retry)
local Telemetry = require(Shared.Logic.Telemetry)
local TelemetrySink = require(Shared.Logic.TelemetrySink)
local Safe = require(Shared.Util.Safe)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

local T = Tuning.Telemetry
local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}
local IS_CAR_SERVER = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local STOP_PHASES = { Dwell = true, LastCall = true, Departure = true }

type Fields = Telemetry.Fields

type Visitor = {
	joinedAt: number, -- os.clock()
	device: string,
	deviceReported: boolean,
	firstVisit: boolean?, -- nil until the profile has loaded
	timings: { [string]: number }, -- first_session_timing milestones waiting for the profile and device
	buffer: TelemetrySink.Buffer,
	flushing: boolean,
	lastOutcome: string?,
	lastOutcomeAt: number?,
	lastGrab: { kind: string, at: number, escaped: boolean }?,
}

type Participant = {
	player: Player,
	experience: string,
	entry: string, -- hall / car / join_in_progress
	joinedAt: number,
	deepest: number, -- deepest stop whose doors opened while they were in the run
	terminal: boolean, -- player_progress sent
	eliminations: number,
}

type Run = {
	id: string,
	startedAt: number,
	crewSize: number,
	order: { Participant },
	byPlayer: { [Player]: Participant },
	stop: number?, -- the regular stop whose doors opened last, until it resolves
	openAt: number?,
	closedAt: number?,
	dwell: number?,
	villageAt: number?, -- the Emergency Village's doors, while it is open
	logged: number,
	stopsReached: number,
}

local TelemetryService = {}

local visitors: { [Player]: Visitor } = {}
local early: { [Player]: any } = {} -- device reports that came in before the player's visit began
local sent: { [string]: boolean } = {}
local run: Run? = nil
local countdownAt: number? = nil
local serverId = ""
local sinkStore: DataStore? = nil
local inFlight = 0 -- sink flushes under way, which shutdown waits for

local function once(key: string): boolean
	if sent[key] then
		return false
	end
	sent[key] = true
	return true
end

local function connected(player: Player): boolean
	return player.Parent == Players
end

local function custom(fields: Fields?): { [string]: string }
	local out: { [string]: string } = {}
	if fields then
		for i = 1, 3 do
			local value = fields[i]
			if type(value) == "string" then
				out[FIELD_KEYS[i]] = value
			end
		end
	end
	return out
end

local function keep(player: Player, name: string, value: number, fields: Fields?)
	local visitor = visitors[player]
	if visitor and sinkStore then
		TelemetrySink.add(
			visitor.buffer,
			TelemetrySink.record(os.clock() - visitor.joinedAt, name, value, fields)
		)
	end
end

local function diagnose(player: Player, kind: string, name: string, value: number, fields: Fields?)
	if T.StudioPrint and RunService:IsStudio() then
		local f = fields or {}
		local function show(i: number): string
			local v = f[i]
			return if type(v) == "string" then v else "-"
		end
		print(`[Telemetry] {kind} {name} {value} [{show(1)}, {show(2)}, {show(3)}] {player.Name}`)
	end
end

local function round(x: number, digits: number): number
	local m = 10 ^ digits
	return math.floor(x * m + 0.5) / m
end

-- Public API -------------------------------------------------------------------------------

function TelemetryService.Event(player: Player, name: string, value: number, fields: Fields)
	local ok, why = Telemetry.check(name, fields)
	if not ok then
		warn(`[Telemetry] dropped: {why}`)
		return
	end
	if not connected(player) then
		return
	end
	keep(player, name, value, fields)
	diagnose(player, "event", name, value, fields)
	Safe.call("Telemetry.Event", function()
		AnalyticsService:LogCustomEvent(player, name, value, custom(fields))
	end)
end

function TelemetryService.Funnel(
	player: Player,
	funnel: string,
	sessionId: string?,
	step: number,
	name: string,
	fields: Fields?
)
	local ok, why = Telemetry.checkFunnel(funnel, step, name)
	if not ok then
		warn(`[Telemetry] dropped: {why}`)
		return
	end
	if not connected(player) then
		return
	end
	keep(player, `{funnel}/{name}`, step, fields)
	diagnose(player, "funnel", `{funnel}/{name}`, step, fields)
	Safe.call("Telemetry.Funnel", function()
		if funnel == "onboarding" then
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name, custom(fields))
		else
			assert(sessionId and sessionId ~= "", `{funnel} needs a session id`)
			AnalyticsService:LogFunnelStepEvent(player, funnel, sessionId, step, name, custom(fields))
		end
	end)
end

-- Brass in (`flow` "Source", sku a Config/Telemetry Economy.Sources key) or out ("Sink", sku the item).
function TelemetryService.Brass(player: Player, flow: string, amount: number, balance: number, sku: string)
	local transaction = if flow == "Source"
		then (Config.Economy.Sources :: any)[sku]
		else Config.Economy.SinkType
	if amount <= 0 or transaction == nil or not connected(player) then
		return
	end
	keep(player, `brass_{string.lower(flow)}`, amount, { transaction, sku, false })
	diagnose(player, "economy", `{flow} {sku}`, amount, { transaction, false, false })
	Safe.call("Telemetry.Brass", function()
		AnalyticsService:LogEconomyEvent(
			player,
			(Enum.AnalyticsEconomyFlowType :: any)[flow],
			Config.Economy.Currency,
			amount,
			balance,
			(Enum.AnalyticsEconomyTransactionType :: any)[transaction].Name,
			sku
		)
	end)
end

function TelemetryService.Device(player: Player): string
	local visitor = visitors[player]
	return if visitor then visitor.device else "unknown"
end

-- Persistent funnels ---------------------------------------------------------------------------

-- Sends funnel step `step` once per player, ever: persisted in profile.telemetry, in order, with the
-- funnel's session id kept in the profile so a later visit finishes the same funnel.
local function milestone(player: Player, funnel: string, step: number)
	local profile = DataService.GetProfile(player)
	if profile == nil or (not DataService.IsLoaded(player) and not RunService:IsStudio()) then
		return -- a stand-in profile cannot remember the step
	end
	local record = profile.telemetry
	local key = `{funnel}/{step}`
	if record.steps[key] or (step > 1 and not record.steps[`{funnel}/{step - 1}`]) then
		return
	end
	if funnel == "onboarding" and not record.onboarding then
		return
	end
	local sessionId: string? = nil
	if funnel ~= "onboarding" then
		sessionId = record.funnels[funnel] or HttpService:GenerateGUID(false)
	end
	DataService.Update(player, function(p)
		p.telemetry.steps[key] = true
		if sessionId then
			p.telemetry.funnels[funnel] = sessionId
		end
	end)
	TelemetryService.Funnel(player, funnel, sessionId, step, Config.Funnels[funnel][step], nil)
end

local function experienceOf(player: Player): string
	local profile = DataService.GetProfile(player)
	local runs = if profile then profile.stats.runs or 0 else 0
	return if runs > 0 then "returning" else "first_run"
end

-- First-session timing (first visit only), sent once the profile and the device report are in.
local function sendTimings(player: Player)
	local visitor = visitors[player]
	if visitor == nil or visitor.firstVisit == nil then
		return
	end
	if not visitor.deviceReported and os.clock() - visitor.joinedAt < 10 then
		return
	end
	local timings = visitor.timings
	visitor.timings = {}
	if not visitor.firstVisit then
		return
	end
	local entry = if IS_CAR_SERVER then "car" else "hall"
	local current = run
	local participant = current and current.byPlayer[player]
	if participant then
		entry = participant.entry
	end
	for name, seconds in timings do
		if once(`timing|{player.UserId}|{name}`) then
			TelemetryService.Event(
				player,
				"first_session_timing",
				round(seconds, 2),
				{ name, visitor.device, entry }
			)
		end
	end
end

local function timing(player: Player, name: string)
	local visitor = visitors[player]
	if visitor and visitor.timings[name] == nil then
		visitor.timings[name] = os.clock() - visitor.joinedAt
		sendTimings(player)
	end
end

-- The run ----------------------------------------------------------------------------------

local function representative(current: Run): Player?
	for _, p in current.order do
		if connected(p.player) then
			return p.player
		end
	end
	for _, player in Registry.CrewService.MemberPlayers() do
		if connected(player) then
			return player
		end
	end
	return nil
end

local function crewEvent(current: Run, name: string, value: number, fields: Fields)
	local rep = representative(current)
	if rep then
		TelemetryService.Event(rep, name, value, fields)
	end
end

local function playerFields(participant: Participant, first: string): Fields
	return { first, TelemetryService.Device(participant.player), participant.experience }
end

local function participate(current: Run, player: Player, entry: string): Participant?
	if current.byPlayer[player] or not connected(player) then
		return nil
	end
	local participant: Participant = {
		player = player,
		experience = experienceOf(player),
		entry = entry,
		joinedAt = os.clock(),
		deepest = 0,
		terminal = false,
		eliminations = 0,
	}
	current.byPlayer[player] = participant
	table.insert(current.order, participant)
	TelemetryService.Event(player, "run_joined", 1, {
		TelemetryService.Device(player),
		participant.experience,
		Telemetry.crewSize(current.crewSize),
	})
	milestone(player, "onboarding", 2) -- first_board
	milestone(player, "replay", 2) -- second_run_started, once the first run has ended
	return participant
end

local function beginRun()
	local crew = Registry.CrewService.MemberPlayers()
	table.sort(crew, function(a, b)
		return a.UserId < b.UserId
	end)
	local current: Run = {
		id = (StateService.Get({ "run", "runId" }) :: string?) or HttpService:GenerateGUID(false),
		startedAt = countdownAt or os.clock(),
		crewSize = math.max(#crew, 1),
		order = {},
		byPlayer = {},
		logged = 0,
		stopsReached = 0,
	}
	run = current
	local tier = (StateService.Get({ "run", "tier" }) :: number?) or 1
	local tutorial = (StateService.Get({ "run", "tutorial" }) :: number?) or 0
	local entry = if IS_CAR_SERVER then "car" else "hall"
	for _, player in crew do
		participate(current, player, entry)
	end
	crewEvent(current, "run_started", 1, {
		Telemetry.crewSize(current.crewSize),
		tostring(tier),
		tostring(tutorial),
	})
	for _, participant in current.order do
		local visitor = visitors[participant.player]
		if visitor and visitor.timings.run_start == nil then
			visitor.timings.run_start = current.startedAt - visitor.joinedAt
			sendTimings(participant.player)
		end
	end
	countdownAt = nil
end

local function openStop(current: Run)
	if Registry.RunDirector.IsVillageStop() then
		current.villageAt = os.clock()
		return
	end
	local stop = Registry.RunDirector.NextStop()
	local info = StateService.Get({ "run", "station" }) :: Types.StationInfo?
	current.stop, current.openAt, current.closedAt = stop, os.clock(), nil
	current.dwell = if info then info.dwell else nil
	current.stopsReached = math.max(current.stopsReached, stop)
	for _, participant in current.order do
		local player = participant.player
		if connected(player) and Registry.CrewService.IsAlive(player) then
			participant.deepest = math.max(participant.deepest, stop)
			timing(player, "first_stop")
			if stop == 3 and participant.entry ~= "join_in_progress" then
				milestone(player, "onboarding", 5) -- reached_stop3
			end
		end
	end
end

-- T-0, the whistle: the doors-open time of the stop ends here.
local function closeStop(current: Run)
	if current.villageAt then
		current.villageAt = nil
	elseif current.openAt and current.closedAt == nil then
		current.closedAt = os.clock()
	end
end

local function stopResolved(current: Run, entry: Types.LogEntry)
	local openAt = current.openAt
	if current.stop ~= entry.stop or openAt == nil or not once(`stop|{current.id}|{entry.stop}`) then
		return -- a stop whose doors never opened is not reported as one
	end
	local doors = (current.closedAt or os.clock()) - openAt
	local stop = Telemetry.stop(entry.stop)
	local share = if current.dwell and current.dwell > 0 then doors / current.dwell * 100 else 0
	local crewSize = Telemetry.crewSize(current.crewSize)
	local outcome = string.lower(entry.outcome)
	crewEvent(current, "stop_resolved", round(share, 1), { stop, outcome, entry.bell or "none" })
	crewEvent(current, "stop_archetype", 1, { stop, entry.archetype, crewSize })
	crewEvent(current, "stop_timing", round(doors, 1), { stop, Telemetry.doorsOpen(doors), crewSize })
	for _, participant in current.order do
		local player = participant.player
		if connected(player) and Registry.CrewService.IsMember(player) then
			TelemetryService.Event(
				player,
				"player_stop_resolved",
				round(doors, 1),
				playerFields(participant, stop)
			)
			if
				entry.stop == 1
				and outcome == "cleared"
				and participant.entry ~= "join_in_progress"
				and Registry.CrewService.IsAlive(player)
			then
				milestone(player, "onboarding", 4) -- survived_stop1
			end
		end
	end
	current.stop, current.openAt, current.closedAt, current.dwell = nil, nil, nil, nil
end

-- New run.log entries are resolved stops (the Terminus leg's entry is the run's end, not a stop).
local function resolveLog(current: Run)
	local log = StateService.Get({ "run", "log" }) :: { Types.LogEntry }?
	local count = if log then #log else 0
	for i = current.logged + 1, count do
		local entry = (log :: { Types.LogEntry })[i]
		if entry.archetype ~= "Terminus" then
			stopResolved(current, entry)
		end
	end
	current.logged = count
end

local function sendProgress(current: Run, participant: Participant)
	if participant.terminal then
		return
	end
	participant.terminal = true
	TelemetryService.Event(participant.player, "player_progress", participant.deepest, {
		TelemetryService.Device(participant.player),
		participant.experience,
		Telemetry.crewSize(current.crewSize),
	})
	if participant.experience == "first_run" then
		milestone(participant.player, "replay", 1) -- first_run_ended
	end
end

local function setOutcome(player: Player, outcome: string)
	local visitor = visitors[player]
	if visitor then
		visitor.lastOutcome = outcome
		visitor.lastOutcomeAt = os.clock()
	end
end

local function endRun(current: Run)
	closeStop(current)
	local outcome = string.lower((StateService.Get({ "run", "outcome" }) :: string?) or "aborted")
	if not once(`end|{current.id}`) then
		return
	end
	local minutes = (os.clock() - current.startedAt) / 60
	local crewSize = Telemetry.crewSize(current.crewSize)
	crewEvent(current, "run_ended", round(minutes, 2), { outcome, crewSize, Telemetry.runDuration(minutes) })
	crewEvent(current, "run_progress", current.stopsReached, {
		outcome,
		crewSize,
		Telemetry.routeLength(Registry.RunDirector.StopCount()),
	})
	for _, participant in current.order do
		local player = participant.player
		if connected(player) then
			local alive = Registry.CrewService.IsAlive(player)
			local mine = if outcome == "victory" and alive
				then "victory"
				elseif not alive then "eliminated"
				elseif outcome == "derailed" then "derailed"
				else "aborted"
			local minutesIn = (os.clock() - participant.joinedAt) / 60
			TelemetryService.Event(
				player,
				"player_run_outcome",
				round(minutesIn, 2),
				playerFields(participant, mine)
			)
			setOutcome(player, mine)
			sendProgress(current, participant)
		end
	end
end

local function onPhase(phase: string, previous: string)
	if phase == "Countdown" then
		countdownAt = os.clock()
		return
	end
	if phase == "Boarding" then
		beginRun()
	end
	local current = run
	if current == nil then
		return
	end
	if phase == "Dwell" then
		openStop(current)
	elseif phase == "Departure" then
		closeStop(current)
	end
	resolveLog(current)
	if phase == "RunEnd" then
		endRun(current)
	elseif phase == "Lobby" then
		if previous ~= "RunEnd" then
			endRun(current) -- the run stopped without an ending: reported as aborted
		end
		run = nil
	end
end

local function heldBy(player: Player, cause: string): string
	local visitor = visitors[player]
	local grab = visitor and visitor.lastGrab
	if cause == "Taken" and grab and not grab.escaped and os.clock() - grab.at <= T.TakenGrabSeconds then
		return grab.kind
	end
	local character = player.Character
	local kind = character and character:GetAttribute("GrabKind")
	return if type(kind) == "string" and table.find(Config.Vocab.HeldBy, kind) then kind else "none"
end

-- Where the run is, as a stop field, and the seconds since that stop's (or village's) doors opened.
local function stopNow(current: Run): (string, number)
	if current.villageAt then
		return "village", os.clock() - current.villageAt
	elseif current.openAt and STOP_PHASES[Registry.RunDirector.Phase()] then
		return Telemetry.stop(current.stop), os.clock() - current.openAt
	elseif current.stop then
		return Telemetry.stop(current.stop), 0
	end
	return if current.stopsReached > 0 then "between" else "pre", 0
end

-- Hooks ------------------------------------------------------------------------------------

-- The first run's stop-1 sighting withdrew: `seconds` of line of sight this player had of it (an
-- opportunity to see it; G1's think-aloud says whether they noticed).
function TelemetryService.Sighting(player: Player, seconds: number)
	local current = run
	local participant = current and current.byPlayer[player]
	if participant == nil or not once(`sighting|{current and current.id}|{player.UserId}`) then
		return
	end
	TelemetryService.Event(
		player,
		"sighting_exposure",
		round(seconds, 2),
		playerFields(participant, Telemetry.tell(seconds))
	)
end

-- AGAIN accepted on the run card (LobbyService), once per player per card: seconds after the card
-- opened, and the run it followed.
function TelemetryService.AgainPressed(player: Player, secondsAfterCard: number, outcome: string)
	TelemetryService.Event(player, "again_pressed", round(secondsAfterCard, 2), {
		string.lower(outcome),
		TelemetryService.Device(player),
		experienceOf(player),
	})
end

-- A Hollow had a clear line to this player (HollowService): first_hollow_seen, the A.4 timing
-- "join to first Hollow in line of sight" (an unobstructed line, not proof they looked).
local hollowSeen: { [Player]: boolean } = {}
function TelemetryService.HollowSeen(player: Player)
	if hollowSeen[player] then
		return
	end
	hollowSeen[player] = true
	timing(player, "first_hollow_seen")
end

-- An experiment's exposure (RunDirector): the player's first exposed arm is stored for good and
-- logged once (cohort_assigned: experiment, arm A/B as actually run, device). A profile that did not
-- load keeps it for this session only.
local sessionCohorts: { [Player]: { [string]: string } } = {}
function TelemetryService.CohortAssigned(player: Player, def: Experiments.Def, arm: string)
	local first = false
	if DataService.GetProfile(player) and DataService.IsLoaded(player) then
		DataService.Update(player, function(p)
			p.telemetry.cohorts = p.telemetry.cohorts or {}
			first = Experiments.expose(p.telemetry.cohorts, def, arm)
		end)
	else
		local cohorts = sessionCohorts[player] or {}
		sessionCohorts[player] = cohorts
		first = Experiments.expose(cohorts, def, arm)
	end
	if first then
		TelemetryService.Event(player, "cohort_assigned", 1, {
			def.id,
			Experiments.label(def, arm),
			TelemetryService.Device(player),
		})
	end
end

-- An INVITE button opened Roblox's invite prompt (UI/Lobby "depot", UI/RunCard "runcard").
function TelemetryService.InvitePrompted(player: Player, source: string)
	TelemetryService.Event(player, "invite_prompted", 1, {
		source,
		TelemetryService.Device(player),
		experienceOf(player),
	})
end

-- A Hollow's strike attempt on `player` (HollowService): the warning it gave them first, its
-- Stalk/coil time in sight within 36 studs. An opportunity to see it, not proof they did.
function TelemetryService.Tell(player: Player, seconds: number, crewmatesNear: number)
	local current = run
	local participant = current and current.byPlayer[player]
	if current == nil or participant == nil then
		return
	end
	local bucket = Telemetry.tell(seconds)
	local stop = stopNow(current)
	TelemetryService.Event(player, "tell_exposure", round(seconds, 2), {
		bucket,
		Telemetry.crewNear(crewmatesNear),
		stop,
	})
	TelemetryService.Event(player, "tell_cohort", round(seconds, 2), playerFields(participant, bucket))
end

-- A late joiner is on the line (CrewService.SpawnPendingJoiners).
function TelemetryService.RunJoined(player: Player)
	local current = run
	if current then
		participate(current, player, "join_in_progress")
	end
end

-- A crew member went down (CrewService.Eliminate), or left the game while still in the run.
function TelemetryService.Eliminated(player: Player, cause: string)
	local current = run
	local participant = current and current.byPlayer[player]
	if current == nil or participant == nil then
		return
	end
	participant.eliminations += 1
	local stop, since = stopNow(current)
	TelemetryService.Event(
		player,
		"player_eliminated",
		round(since, 1),
		{ cause, stop, heldBy(player, cause) }
	)
	setOutcome(player, "eliminated")
end

-- A crew member is leaving the game (CrewService's PlayerRemoving, before it forgets them).
function TelemetryService.Left(player: Player, wasAlive: boolean)
	local current = run
	local participant = current and current.byPlayer[player]
	if current == nil or participant == nil then
		return
	end
	if wasAlive then
		TelemetryService.Eliminated(player, "Disconnected")
	end
	sendProgress(current, participant)
end

-- Grabs (HollowService): the grab funnel, and what held a Taken player.
function TelemetryService.Grabbed(player: Player, kind: string)
	local visitor = visitors[player]
	if visitor then
		visitor.lastGrab = { kind = kind, at = os.clock(), escaped = false }
	end
	milestone(player, "grab", 1)
end

function TelemetryService.Escaped(player: Player)
	local visitor = visitors[player]
	local grab = visitor and visitor.lastGrab
	if grab then
		grab.escaped = true
	end
	milestone(player, "grab", 2)
end

function TelemetryService.Pried(player: Player)
	milestone(player, "pry", 1)
end

-- The client's one-time device report (the ClientReady payload, StateService). Later reports
-- (snapshot resyncs) cannot change it.
function TelemetryService.ReportDevice(player: Player, report: any)
	local visitor = visitors[player]
	if visitor == nil then
		if early[player] == nil and player.Parent == Players then
			early[player] = report or "unknown"
		end
	elseif not visitor.deviceReported then
		visitor.deviceReported = true
		visitor.device = Telemetry.device(report)
		sendTimings(player)
	end
end

-- The sink ---------------------------------------------------------------------------------

local function flush(player: Player, visitor: Visitor): boolean
	local store = sinkStore
	if store == nil or #visitor.buffer.pending == 0 or visitor.flushing then
		return true
	end
	visitor.flushing = true
	inFlight += 1
	local count = #visitor.buffer.pending
	local snapshot = table.move(visitor.buffer.pending, 1, count, 1, {})
	local key = TelemetrySink.key(game.PlaceId, serverId, player.UserId)
	local dropped = visitor.buffer.dropped
	local total = dropped
	local ok, err = Retry.run(function()
		return store:UpdateAsync(key, function(old: any)
			local merged, newTotal = TelemetrySink.merge(
				if type(old) == "table" then old else nil,
				snapshot,
				dropped,
				T.SinkMaxRecords
			)
			total = newTotal
			return merged
		end)
	end, T.SinkRetries, T.SinkRetryDelay, task.wait)
	visitor.flushing = false
	inFlight -= 1
	if ok then
		TelemetrySink.flushed(visitor.buffer, count, total)
	else
		warn(`[Telemetry] sink flush failed for {key}: {err}`)
	end
	return ok
end

function TelemetryService.FlushAll()
	for player, visitor in visitors do
		task.spawn(flush, player, visitor)
	end
end

-- Dev `telemetry dump [serverId]`: every sink key of this place (or of one server) as CSV.
function TelemetryService.Dump(server: string?)
	local store = sinkStore
	if store == nil then
		print("[Telemetry] the sink is off or its DataStore is unavailable")
		return
	end
	local pages = store:ListKeysAsync(TelemetrySink.prefix(game.PlaceId, server), 50)
	local keys = 0
	print(TelemetrySink.csvHeader())
	while keys < T.DumpMaxKeys do
		for _, item in pages:GetCurrentPage() do
			local name = (item :: DataStoreKey).KeyName
			local value = store:GetAsync(name)
			if type(value) == "table" then
				for _, row in TelemetrySink.csv(name, value) do
					print(row)
				end
			end
			keys += 1
		end
		if pages.IsFinished then
			break
		end
		pages:AdvanceToNextPageAsync()
	end
	print(`[Telemetry] dumped {keys} key(s); this server is {serverId}`)
end

function TelemetryService.ServerId(): string
	return serverId
end

-- Players ----------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local visitor: Visitor = {
		joinedAt = os.clock(),
		device = "unknown",
		deviceReported = false,
		firstVisit = nil,
		timings = {},
		buffer = TelemetrySink.newBuffer(),
		flushing = false,
		lastOutcome = nil,
		lastOutcomeAt = nil,
		lastGrab = nil,
	}
	visitors[player] = visitor
	if early[player] ~= nil then
		TelemetryService.ReportDevice(player, early[player])
		early[player] = nil
	end
	if player.Character then
		timing(player, "control")
	else
		player.CharacterAdded:Once(function()
			timing(player, "control")
		end)
	end
	local profile = DataService.WaitForProfile(player)
	if profile == nil or not connected(player) then
		return
	end
	local first = profile.telemetry.visits == 0 and (profile.stats.runs or 0) == 0
	visitor.firstVisit = first
	DataService.Update(player, function(p)
		if p.telemetry.visits == 0 then
			p.telemetry.onboarding = first
		end
		p.telemetry.visits += 1
	end)
	milestone(player, "onboarding", 1) -- joined
	sendTimings(player)
end

local function onPlayerRemoving(player: Player)
	early[player] = nil
	sessionCohorts[player] = nil
	hollowSeen[player] = nil
	local visitor = visitors[player]
	if visitor == nil then
		return
	end
	local experience = experienceOf(player)
	local phase = Registry.RunDirector.Phase()
	TelemetryService.Event(
		player,
		"session_ended",
		round((os.clock() - visitor.joinedAt) / 60, 2),
		{ phase, visitor.device, experience }
	)
	if visitor.lastOutcome and visitor.lastOutcomeAt then
		TelemetryService.Event(
			player,
			"quit_after_outcome",
			round(os.clock() - visitor.lastOutcomeAt, 1),
			{ visitor.lastOutcome, visitor.device, experience }
		)
	end
	-- after CrewService's own PlayerRemoving hook has had its turn, keep the records and let go
	task.defer(function()
		flush(player, visitor)
		visitors[player] = nil
	end)
end

-- Crew members off the train for the first time, and timings waiting on a slow device report.
local function poll()
	local current = run
	local phase = Registry.RunDirector.Phase()
	if current and STOP_PHASES[phase] then
		for _, participant in current.order do
			local player = participant.player
			if
				connected(player)
				and Registry.CrewService.IsAlive(player)
				and not Registry.CrewService.IsAboard(player)
			then
				milestone(player, "onboarding", 3) -- first_off_train
			end
		end
	end
	for player, visitor in visitors do
		if next(visitor.timings) ~= nil then
			sendTimings(player)
		end
	end
end

function TelemetryService.Init()
	serverId = if game.JobId ~= ""
		then game.JobId
		else `studio-{string.sub(HttpService:GenerateGUID(false), 1, 8)}`
	local wanted = T.SinkEnabled or RunService:IsStudio() or game.PrivateServerId ~= ""
	if wanted then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(T.SinkStore)
		end)
		if ok then
			sinkStore = result
		else
			warn(`[Telemetry] sink DataStore unavailable: {result}`)
		end
	end
end

function TelemetryService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Registry.RunDirector.PhaseChanged:Connect(function(phase: string, previous: string)
		Safe.call("Telemetry.phase", onPhase, phase, previous)
	end)
	task.spawn(function()
		while true do
			task.wait(T.PollSeconds)
			Safe.call("Telemetry.poll", poll)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(T.SinkFlushSeconds)
			Safe.call("Telemetry.flush", TelemetryService.FlushAll)
		end
	end)
	game:BindToClose(function()
		TelemetryService.FlushAll()
		task.wait() -- let every flush start
		local deadline = os.clock() + T.ShutdownWaitSeconds
		while inFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	if RunService:IsStudio() then
		print(`[Telemetry] server {serverId}; sink {if sinkStore then "on" else "off"}`)
	end
end

return TelemetryService
