--!strict
--[[
	Telemetry vocabulary (docs/FINAL-DESIGN.md Prompt 0). Services/TelemetryService is the only caller
	of AnalyticsService; Logic/Telemetry checks every custom field against these lists before a call.
	Each event has three string slots (CustomField01..03); `false` leaves a slot unused. Every list is
	frozen and bounded, so each event stays under Roblox's 8,000 field combinations
	(tests/Telemetry.spec). Event and funnel names are fixed here: none is built at run time.
]]

local Config = script.Parent
local Stations = require(Config.Stations)
local Tuning = require(Config.Tuning)

local function list(values: { string }): { string }
	return table.freeze(values)
end

local function stops(): { string }
	local out = { "pre" } -- before the first stop opens: never a made-up stop number
	for n = 1, Tuning.Run.StationCount do
		table.insert(out, tostring(n))
	end
	table.insert(out, "terminus")
	table.insert(out, "between") -- on the line after a stop resolved, before the next one opens
	table.insert(out, "village") -- the Emergency Village: between stops, not one of them
	return table.freeze(out)
end

local Vocab = table.freeze({
	Device = list({ "phone", "tablet", "desktop", "console", "unknown" }),
	Experience = list({ "first_run", "returning" }),
	CrewSize = list({ "1", "2", "3", "4" }),
	RunTier = list({ "1", "2", "3", "4", "5" }), -- Difficulty.RunTier.Max
	TutorialTier = list({ "0", "1", "2", "3" }),
	RouteLength = list({ "short", "long" }),
	Stop = stops(),
	Archetype = Stations.Order,
	StopOutcome = list({ "cleared", "wiped", "derailed", "aborted" }),
	RunOutcome = list({ "victory", "wiped", "derailed", "aborted" }),
	-- a player's own end of a run: reached the Terminus, went down (any cause), or the run ended
	-- around them still standing (derailed, aborted)
	PlayerOutcome = list({ "victory", "eliminated", "derailed", "aborted" }),
	Bell = list({ "none", "all", "half" }),
	Cause = list({
		"LeftBehind",
		"Taken",
		"Smothered",
		"Fell",
		"Wrecked",
		"Stranded",
		"Disconnected",
		"Other",
	}),
	HeldBy = list({ "Stalker", "Crawler", "Brute", "none" }),
	TellBucket = list({ "0", "0-1.5", "1.5-3", "3+" }),
	CrewNear = list({ "0", "1", "2+" }),
	GraspResult = list({ "caught", "missed", "window", "state", "occupied" }),
	SecondsLeft = list({ "<1", "1-2", "2+" }),
	RunDuration = list({ "<20", "20-30", "30-40", "40-50", "50+" }), -- minutes
	DoorsOpen = list({ "<90", "90-150", "150-210", "210+" }), -- seconds
	Phase = list({
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
	}),
	Milestone = list({ "control", "run_start", "first_stop", "first_hollow_seen" }),
	Entry = list({ "hall", "car", "join_in_progress" }),
	InviteSource = list({ "depot", "runcard" }),
	ExperimentId = list({ "E1", "E2" }), -- Config/Experiments
	Arm = list({ "A", "B" }), -- an experiment's arms[1], arms[2]
})

export type EventDef = { fields: { string | false } }

local function event(f1: string | false, f2: string | false, f3: string | false): EventDef
	return table.freeze({ fields = table.freeze({ f1, f2, f3 }) })
end

-- Event name -> the vocabulary of each custom field (Prompt 0's table, then A.4's additions).
local Events: { [string]: EventDef } = table.freeze({
	run_started = event("CrewSize", "RunTier", "TutorialTier"),
	run_joined = event("Device", "Experience", "CrewSize"),
	stop_resolved = event("Stop", "StopOutcome", "Bell"),
	stop_archetype = event("Stop", "Archetype", "CrewSize"),
	stop_timing = event("Stop", "DoorsOpen", "CrewSize"),
	player_stop_resolved = event("Stop", "Device", "Experience"),
	player_eliminated = event("Cause", "Stop", "HeldBy"),
	tell_exposure = event("TellBucket", "CrewNear", "Stop"),
	tell_cohort = event("TellBucket", "Device", "Experience"),
	grasp = event("GraspResult", "SecondsLeft", "Device"),
	grasp_shortfall = event("GraspResult", "SecondsLeft", "Device"),
	grasp_reach = event("GraspResult", "SecondsLeft", "Device"),
	grasp_press_offset = event("GraspResult", "SecondsLeft", "Device"),
	mist_rescue = event("Stop", "Device", false), -- value: ping in ms (MistService)
	run_ended = event("RunOutcome", "CrewSize", "RunDuration"),
	run_progress = event("RunOutcome", "CrewSize", "RouteLength"),
	player_run_outcome = event("PlayerOutcome", "Device", "Experience"),
	player_progress = event("Device", "Experience", "CrewSize"),
	again_pressed = event("RunOutcome", "Device", "Experience"),
	session_ended = event("Phase", "Device", "Experience"),
	quit_after_outcome = event("PlayerOutcome", "Device", "Experience"),
	first_session_timing = event("Milestone", "Device", "Entry"),
	cohort_assigned = event("ExperimentId", "Arm", "Device"),
	invite_prompted = event("InviteSource", "Device", "Experience"),
	-- stop 1's scripted sighting on a first run: each player's line-of-sight seconds (Prompt 5, E2)
	sighting_exposure = event("TellBucket", "Device", "Experience"),
})

-- Funnel name -> its step names, in order. `onboarding` goes through LogOnboardingFunnelStepEvent;
-- the rest through LogFunnelStepEvent with a server-made session id kept in the profile. A player
-- may pry without ever being grabbed, so grab and pry are separate funnels.
local Funnels: { [string]: { string } } = table.freeze({
	onboarding = list({ "joined", "first_board", "first_off_train", "survived_stop1", "reached_stop3" }),
	grab = list({ "first_grab", "first_escape" }),
	pry = list({ "first_pry" }),
	replay = list({ "first_run_ended", "second_run_started" }),
})

-- Brass through LogEconomyEvent: transaction types (Enum.AnalyticsEconomyTransactionType names) and SKUs.
local Economy = table.freeze({
	Currency = "Brass",
	Sources = table.freeze({ run_payout = "Gameplay", milestone = "Gameplay" }),
	SinkType = "Shop", -- a Brass purchase; its SKU is the catalog item id (Config/Cosmetics)
})

-- Upper edges of the duration buckets, matching the Vocab lists above (a value on an edge goes up).
local Buckets = table.freeze({
	RunMinutes = table.freeze({ 20, 30, 40, 50 }),
	DoorsOpenSeconds = table.freeze({ 90, 150, 210 }),
	TellSeconds = table.freeze({ 1.5, 3 }), -- 0 exactly is its own bucket
	SecondsLeft = table.freeze({ 1, 2 }),
	CrewNearStuds = 20,
})

return table.freeze({
	Vocab = Vocab,
	Events = Events,
	Funnels = Funnels,
	Economy = Economy,
	Buckets = Buckets,
	MaxCombinations = 8000, -- Roblox's limit per custom event
})
