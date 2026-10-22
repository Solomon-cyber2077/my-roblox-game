--!strict
-- Shared type vocabulary. Every replicated table matches one of these shapes.

export type Phase =
	"Lobby"
	| "Countdown"
	| "Boarding"
	| "Junction"
	| "Cruise"
	| "Arrival"
	| "Dwell"
	| "LastCall"
	| "Departure"
	| "Terminus"
	| "RunEnd"

export type CrewStatus = "Lobby" | "Aboard" | "Afield" | "Straggler" | "Eliminated"
export type Cause = "LeftBehind" | "Taken" | "Smothered" | "Fell" | "Wrecked" | "Disconnected" | "Other"
export type Outcome = "Victory" | "Wiped" | "Derailed"
export type Zone = "Safe" | "Near" | "Mid" | "Far" | "Village"

export type RouteOption = {
	archetype: string,
	tier: number,
	distanceKm: number,
	hint: string,
	mystery: boolean?, -- the sealed stand-in (Logic/Mystery.redact): archetype "Mystery", tier 0, no hint
}

-- run.destination, from lock-in to the end of the stop. A sealed mystery carries only the distance
-- and coal (Logic/Mystery.sealed); the full shape replaces it at Arrival with sealed = false.
export type Destination = {
	archetype: string,
	name: string,
	tier: number,
	distanceKm: number,
	difficulty: number,
	coalCost: number,
	terminus: boolean,
	mystery: boolean?,
	sealed: boolean?,
	biome: string?, -- a sealed destination's land (Logic/Journey biome id), so the scenery need not switch at Arrival
}

export type HazardParams = {
	difficulty: number,
	dwell: number,
	lastCall: number,
	fogStartU: number,
	fogEndFraction: number,
	fogGamma: number,
	fogDps: number,
	collapseLag: number,
	collapseWarn: number,
	collapseJitter: number,
	spawnInterval: number,
	spawnRamp: number,
	firstSpawnU: number,
	hollowCap: number,
	hollowWalk: number,
	hollowChase: number,
	hollowDamage: number,
	stop: number?, -- the stop's number in the run (RunDirector), for the per-stop rules
	tutorial: number?, -- the crew's tutorial tier (Logic/Tutorial): 1..3, nil or 0 when past it
	dormantStart: boolean?, -- tutorial stop 1: every Hollow starts asleep, no wanderer, no fog spawns
	scriptedOnly: boolean?, -- a first run's stop 3: no sleepers, no fog spawns, only its one Stalker
	departureAccel: number,
	chaseWindow: number,
	lootMul: number,
	safeBand: number,
}

export type StationInfo = {
	archetype: string,
	name: string,
	tier: number,
	difficulty: number,
	dwell: number,
	lastCall: number,
	length: number,
	depth: number,
	startedAt: number,
	departAt: number,
	lastCallEndsAt: number?, -- set at T-0: the station stays docked until then (Tuning.LastCallGrace)
	layoutSeed: number,
	hazards: HazardParams,
	terminus: boolean,
	originalDwell: number?,
	bell: "none" | "all" | "half"?,
	-- the Emergency Village after a breakdown (not one of the stops): bring `needed` repair parts
	-- aboard; `found` counts those that have come aboard since the doors opened
	emergency: { needed: number, found: number }?,
}

export type TrainState = {
	coal: number,
	coalMax: number,
	parts: number,
	integrity: number,
	integrityMax: number,
	upgrades: { [string]: number },
	-- open steam leaks; age is the seconds of travel each has been left open (Logic/Leaks)
	breaches: { [string]: { anchor: string, openedAt: number, age: number? } },
	starving: boolean,
	-- the crew chest in the stores car: shared consumables, by item id (Logic/CrewChest)
	chest: { string },
}

export type InventoryState = {
	items: { string },
	capacity: number,
}

export type CrewEntry = {
	name: string,
	status: CrewStatus,
	cause: Cause?,
	rescued: boolean,
	load: number,
}

export type RunStats = {
	coalDelivered: number,
	partsDelivered: number,
	relics: number,
	stationsCleared: number,
}

-- How one stop ended for the run: departed with the crew aboard, or the run ended there.
export type StopOutcome = "Cleared" | "Victory" | "Wiped" | "Derailed"

-- What the crew brought aboard and lost over one stop (since the previous stop resolved).
export type StopHaul = { coal: number, parts: number, relics: number, downs: number }

-- RunSummary.haul: recovered physical objects, credited once through existing Crew Rank.
export type HaulReceipt = { valuables: { string }, trophies: { string }, xp: number }

-- run.log[i], one per resolved stop in stop order (Logic/RunLog). A sealed ticket that never arrived
-- keeps its sealed name and tier 0; `revealed` is set only once its station was unsealed at Arrival.
export type LogEntry = {
	stop: number,
	name: string,
	archetype: string,
	tier: number,
	difficulty: number,
	distanceKm: number,
	coalBurned: number,
	votes: { number }, -- ballots cast per option, in ballot order
	chosen: number,
	unanimous: boolean,
	mystery: boolean?,
	revealed: boolean?,
	closeCalls: { string }?, -- display names: not aboard at T-0, aboard when the stop resolved
	haul: StopHaul?, -- loot banked and crew downed during this stop
	outcome: StopOutcome,
	bell: "none" | "all" | "half"?,
}

-- Per-player tally that feeds the end-of-run payout.
export type CrewTally = {
	stationsDeparted: number,
	coalDelivered: number,
	partsDelivered: number,
	relicBrass: number,
	relicsBanked: number,
	rescues: number,
	clutchBoards: number,
	closeCalls: number, -- not aboard at T-0, aboard when the stop resolved
	reachedTerminus: boolean,
}

-- lobby.tier: the opt-in run tier the host has picked, the crew's cap and the host's user id.
export type LobbyTier = { selected: number, max: number, host: string? }

export type Profile = {
	version: number,
	brass: number,
	xp: number,
	unlockedTier: number, -- highest opt-in run tier unlocked (Logic/RunTier)
	owned: { [string]: boolean },
	equipped: { [string]: string },
	milestones: { [string]: boolean },
	stats: { [string]: number },
	daily: { lastBonusDay: number, charterBrassDay: number, charterBrass: number },
	receipts: { [string]: number },
	settings: { [string]: any },
	npcs: { [string]: NpcProgress }, -- Logic/NpcSave
	tutorialRuns: number, -- tutorial runs completed (Logic/Tutorial); 0 for a new player
	telemetry: TelemetryProfile, -- Services/TelemetryService
}

-- profile.telemetry: what lets funnels span visits (Services/TelemetryService).
export type TelemetryProfile = {
	visits: number,
	onboarding: boolean, -- in the onboarding funnel: a new player, set on their first visit
	steps: { [string]: boolean }, -- funnel steps already sent, "<funnel>/<step>"
	funnels: { [string]: string }, -- funnel session ids, kept so a later visit can finish the funnel
}

-- profile.npcs[npcId]: one resident's story for one player (Logic/NpcSave).
export type NpcProgress = {
	stage: number,
	done: { [string]: boolean },
	choices: { [string]: string },
	seen: { [string]: boolean },
	failed: string?,
}

-- private quests[i]: one crew errand on the tracker (NpcService).
export type QuestEntry = {
	npc: string,
	name: string,
	title: string,
	text: string,
	status: string,
	helper: boolean, -- the player is past this errand: it pays "Lent a hand" and keeps their stage
}

return {}
