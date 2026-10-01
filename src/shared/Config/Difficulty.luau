--!strict
--[[
	Difficulty curve constants. Each pair is { atD0, atD1 } and is interpolated
	linearly by the station difficulty D in [0, 1]. Logic/DifficultyModel is the
	only reader; the production blueprint quotes these numbers.

	Base curve:  R(n) = Start + Span * ((n - 1) / (N - 1)) ^ Exponent
	Station D:   D = clamp(R(n) + TierOffset[tier], 0, 1)
]]

return table.freeze({
	Base = table.freeze({ Start = 0.08, Span = 0.80, Exponent = 1.4 }),
	TierOffset = table.freeze({ -0.08, 0, 0.10 }),

	Dwell = table.freeze({ 95, 60 }), -- seconds the doors stay open, before archetype scaling

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
	HollowCap = table.freeze({ Base = 1, PerDifficulty = 5, PerExtraCrew = 0.6, Max = 10 }),
	HollowWalk = table.freeze({ 9, 12 }),
	HollowChase = table.freeze({ 17, 21 }),
	HollowDamage = table.freeze({ 25, 40 }),

	DepartureAccel = table.freeze({ 4, 6 }), -- studs per second squared
	ChaseWindow = table.freeze({ 7, 5 }), -- seconds the boarding volume stays live while pulling out

	LootMultiplier = table.freeze({ 1.0, 1.35 }), -- container count scaling
	BreachRate = table.freeze({ 0.015, 0.045 }), -- breaches per second while travelling
})
