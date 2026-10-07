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
export type Cause = "LeftBehind" | "Taken" | "Smothered" | "Fell" | "Disconnected"
export type Outcome = "Victory" | "Wiped" | "Derailed"
export type Zone = "Safe" | "Near" | "Mid" | "Far"

export type RouteOption = {
	archetype: string,
	tier: number,
	distanceKm: number,
	hint: string,
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
	grabMash: number,
	grabSlip: number,
	departureAccel: number,
	chaseWindow: number,
	lootMul: number,
	breachRate: number,
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
	layoutSeed: number,
	hazards: HazardParams,
	terminus: boolean,
}

export type TrainState = {
	coal: number,
	coalMax: number,
	parts: number,
	integrity: number,
	integrityMax: number,
	upgrades: { [string]: number },
	breaches: { [string]: { anchor: string, openedAt: number } },
	starving: boolean,
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

-- Per-player tally that feeds the end-of-run payout.
export type CrewTally = {
	stationsDeparted: number,
	coalDelivered: number,
	partsDelivered: number,
	relicBrass: number,
	relicsBanked: number,
	rescues: number,
	clutchBoards: number,
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
}

return {}
