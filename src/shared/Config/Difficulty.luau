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
	HollowCap = table.freeze({ Base = 1, PerDifficulty = 5, PerExtraCrew = 0.6, Max = 16 }),
	-- Raises only the early minimum; the later HollowCap curve remains unchanged.
	EarlyHollowCap = table.freeze({ Minimum = 3, UntilDifficulty = 0.5 }),
	-- Sleeping Hollow target is ceil(actual building tiles / TilesPerSleeper), with clearance and retry budget.
	Sleepers = table.freeze({ TilesPerSleeper = 6, Clearance = 2, AttemptsPerSleeper = 24 }),
	-- Wanderer delay in seconds after doors open, interpolated from easiest to hardest stop.
	WandererDelay = table.freeze({ 18, 10 }),
	HollowWalk = table.freeze({ 11, 14 }),
	HollowChase = table.freeze({ 22, 26 }), -- between the crew's jog (20) and sprint (31)
	HollowDamage = table.freeze({ 20, 32 }),
	GrabMash = table.freeze({ 0.15, 0.105 }), -- escape won per press of the struggle key
	GrabSlip = table.freeze({ 0.2, 0.3 }), -- escape lost per second of a hold
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
	BreachRate = table.freeze({ 0.015, 0.045 }), -- breaches per second while travelling
})
