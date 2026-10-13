--!strict
--[[
	Difficulty curve constants. Each pair is { atD0, atD1 } and is interpolated
	linearly by the station difficulty D in [0, 1]. Logic/DifficultyModel is the
	only reader; the production blueprint quotes these numbers.

	Base curve:  R(n) = Start + Span * ((n - 1) / (N - 1)) ^ Exponent
	Station D:   D = clamp(R(n) + TierOffset[tier] + RunTier offset, 0, 1)

	RunTier is the opt-in run difficulty the host picks in the lobby (Logic/RunTier).
	Tier 1 adds nothing; each tier above 1 adds OffsetPerTier to every stop's D and
	BrassBonusPerTier to the run's Brass. Winning at tier N unlocks N + 1, up to Max.
]]

local Tutorial = require(script.Parent.Tutorial)

return table.freeze({
	Base = table.freeze({ Start = 0.08, Span = 0.80, Exponent = 1.4 }),
	TierOffset = table.freeze({ -0.08, 0, 0.10 }),
	RunTier = table.freeze({
		Default = 1,
		Max = 5,
		OffsetPerTier = 0.06,
		BrassBonusPerTier = 0.20,
		LobbyRefreshSeconds = 1,
	}),

	Dwell = table.freeze({ 148, 94 }), -- seconds the doors stay open, before archetype scaling

	FogStartU = table.freeze({ 0.45, 0.15 }), -- share of the dwell before the fog front moves
	FogEndFraction = table.freeze({ 0.45, 0.10 }), -- clear depth left past the safe strip at departure
	FogGamma = table.freeze({ 1.6, 1.2 }), -- >1 means the fog accelerates toward Last Call
	FogDps = table.freeze({ 6, 14 }),

	CollapseLag = table.freeze({ 14, 8 }), -- seconds the collapse front trails the fog front
	CollapseWarn = table.freeze({ 2.2, 1.2 }), -- telegraph length before a slab falls
	CollapseJitter = 8, -- studs of per-slab noise on the collapse line

	SpawnInterval = table.freeze({ 14, 6 }), -- seconds between Hollow spawns at the start of the ramp
	SpawnRamp = 2.5, -- spawn rate multiplier reached at departure: 1 + SpawnRamp
	FirstSpawnU = table.freeze({ 0.40, 0.15 }),
	-- Feeds HazardParams.hollowCap's "any Hollows here at all" test; the count itself is Threat below.
	HollowCap = table.freeze({ Base = 1, PerDifficulty = 5, PerExtraCrew = 0.6, Max = 16 }),
	-- Sleeping Hollow target is ceil(actual building tiles / TilesPerSleeper), with clearance and retry budget.
	Sleepers = table.freeze({ TilesPerSleeper = 6, Clearance = 2, AttemptsPerSleeper = 24 }),
	-- Wanderer delay in seconds after doors open, interpolated from easiest to hardest stop.
	WandererDelay = table.freeze({ 18, 10 }),
	HollowWalk = table.freeze({ 11, 14 }),
	HollowChase = table.freeze({ 22, 26 }), -- between the crew's jog (20) and sprint (31)
	HollowDamage = table.freeze({ 25, 40 }), -- was { 20, 32 } (+25%)
	-- how often each kind of Hollow comes
	HollowKinds = table.freeze({
		Stalker = table.freeze({ 1, 0.55 }),
		Crawler = table.freeze({ 0.18, 0.32 }),
		Brute = table.freeze({ 0.04, 0.2 }),
	}),
	-- bigger stops take longer and hold more Hollows: per tile of enterable building
	SizeDwellPerTile = 0.02, -- dwell multiplier added per building tile
	SizeCapPerTile = 0.025, -- Hollow cap multiplier added per building tile

	DepartureAccel = table.freeze({ 4, 6 }), -- studs per second squared
	ChaseWindow = table.freeze({ 7, 5 }), -- seconds the boarding volume stays live while pulling out

	LootMultiplier = table.freeze({ 1.0, 1.35 }), -- container count scaling

	--[[
		Fix pass part 2: the one table for grabs, the threat curve, the tutorial, post-grab
		protection, skill checks, the hull and its leaks. Every number here is a first draft
		for the owner to tune; the specs (tests/Part2Config.spec and the per-system specs)
		check the rules they must keep.
	]]

	-- How hard Hollows press, not how fast they run (HollowChase above stays between the
	-- crew's jog and sprint): how far they notice you, how long they keep after you once
	-- they lose sight of you, and how soon they strike again.
	Aggression = table.freeze({
		SightRange = 118.75, -- studs a Hollow can see crew (was 95: +25%)
		AwarenessRange = 37.5, -- studs it senses crew without line of sight (was 30: +25%)
		Persistence = 5.2, -- seconds it keeps hunting where it last saw you (was 4: +30%)
		StrikeCooldown = 0.72, -- seconds from one strike's start to the next (was 0.9: -20%)
	}),

	-- What a hold does to you (Logic/Grab), carried over from round 2.
	GrabDamage = table.freeze({
		DpsShare = 0.6, -- damage per second held, as a share of the stop's hollowDamage
		MaxBiteShare = 0.35, -- no single bite takes more than this share of MaxHealth
		PinDpsShare = 0.5, -- a Brute pin's damage per second, as a share of hollowDamage
		BruteCrush = 1.2, -- the Brute's damage scale (Tuning.HollowKinds.Brute.crush)
	}),

	-- How many Hollows a stop holds (Logic/HollowBudget, Logic/Threat): sleepers, fog spawns
	-- and the wanderer all count. The full count by players in the run, reached at
	-- FullAtStop; stop 1 gets StartShare of it, rising in even steps, never below Minimum.
	-- The crew rides at its least experienced player's tutorial tier (Config/Tutorial).
	Threat = table.freeze({
		FullByCrew = table.freeze({ 3, 4, 5, 6 }), -- 1, 2, 3, 4 players
		SleeperShare = 0.5, -- at most this share may start asleep in buildings
		StartShare = 0.35,
		FullAtStop = 7,
		Minimum = 1,
	}),

	-- After you break free (Logic/Threat.protection): no Hollow can grab you for `immunity`
	-- seconds, and with `stagger` the one that held you is stunned and shoved away. The row
	-- with the highest fromStop at or below the stop applies.
	PostGrab = table.freeze({
		Schedule = table.freeze({
			table.freeze({ fromStop = 1, immunity = 5, stagger = true }),
			table.freeze({ fromStop = 3, immunity = 4, stagger = true }),
			table.freeze({ fromStop = 5, immunity = 3, stagger = true }),
			table.freeze({ fromStop = 7, immunity = 2, stagger = false }),
		}),
		StaggerSeconds = 1.5,
		StaggerPush = 16, -- studs per second the staggered Hollow is shoved back at first, easing off
	}),

	-- Breaking a hold (Logic/SkillCheck): a needle sweeps a ring; Space (gamepad A, or the
	-- on-screen button) with the needle in the zone is a hit. The server picks every check
	-- and judges every press.
	SkillCheck = table.freeze({
		Required = 3, -- progress that frees you: a good hit is 1
		GreatBonus = 0.5, -- a great hit adds this on top
		MissCost = 0.5, -- a miss (early, late or no press) takes this much back
		MissClock = 1.5, -- and brings the grab's finish this many seconds closer
		FirstDelay = 1.1, -- no check appears sooner than this after the grab
		Gap = table.freeze({ 0.45, 0.9 }), -- seconds from one check's end to the next one
		SweepSeconds = 1.25, -- one turn of the needle; a check nobody presses ends after one turn
		LeadDegrees = table.freeze({ 110, 230 }), -- the zone starts this far ahead of the needle
		ZoneByStop = table.freeze({ 70, 64, 58, 52, 47, 42, 38 }), -- zone width by stop, the last for later stops
		GreatShare = 0.25, -- the great zone: this leading share of the zone
		LatencyBase = 0.05, -- seconds of press tolerance on top of half the player's round-trip ping
		LatencyMax = 0.2, -- never more tolerance than this
		MinPressGap = 0.12, -- presses closer together than this are ignored
		FinishByStop = table.freeze({ 12, 11.5, 11, 10.5, 10, 9.5, 9 }), -- the grab clock by stop
		FinishMargin = 1, -- the clock always exceeds the time the minimum checks need by this
		PryProgress = 0.15, -- one crewmate's tear at the Hollow
	}),

	-- The hull (Logic/Ledger, Logic/Leaks, Services/BreakdownService).
	Hull = table.freeze({
		Floor = 1, -- it never drains below this by itself: reaching it is a breakdown
		StarvingPerSecond = 3, -- an empty firebox, while the train is moving
		RepairParts = 2, -- Workbench "Repair hull": parts per repair
		RepairAmount = 10, -- hull per repair
		Tiers = table.freeze({ Creak = 75, Flicker = 50, Emergency = 25 }), -- hull % effects start at
		MarkersOffBoost = 1.4, -- hull-tier and leak world cues this much stronger with markers off
	}),

	-- Steam leaks (Logic/Leaks). A leak drains hull only while the train is moving; its rate
	-- is set so one left alone costs OneLeakTrip % over a trip, whatever the trip's length.
	Leaks = table.freeze({
		OneLeakTrip = 14, -- % hull one unattended leak costs over its trip (three cost ~39%)
		Growth = 0.5, -- severity added per trip-length of travel it is ignored (1 to 1.5 in one trip)
		MaxSeverity = 2,
		FirstShare = 0.1, -- the first leak bursts this far into a trip
		Spacing = 0.05, -- each further one this much later
		Jitter = 0.02, -- plus or minus, per leak
		ExpectedPerTrip = table.freeze({ 0.8, 2.2 }), -- leaks per trip by station difficulty
		EarlyCap = 1, -- stops 1 to EarlyUntilStop: at most one leak
		EarlyUntilStop = 3,
		Cap = 3,
		PatchParts = 1,
		PatchHold = 1.5,
		HissRange = 40, -- studs the hiss carries with markers on
		HissRangeOff = 95, -- and off: into the neighbouring cars
		SteamRate = 40, -- particles per second at severity 1, markers on
		SteamRateOff = 90,
		StudsToMetres = 0.28, -- the leak arrow's distance readout
	}),

	-- Reaching the hull floor (Services/BreakdownService).
	Breakdown = table.freeze({
		StopSeconds = 4, -- the train grinds to a halt
		LimpShare = 0.5, -- speed share for the rest of the trip in limp mode
		RallySeconds = 45, -- the crew's window to make the repairs
		RallyRepairs = 3, -- repair interactions the crew must complete
		RallyHold = 1.5, -- seconds each repair takes
		RallyRestore = 15, -- hull % after a successful rally
	}),

	Tutorial = Tutorial,
})
