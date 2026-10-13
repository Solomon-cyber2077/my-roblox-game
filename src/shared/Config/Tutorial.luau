--!strict
--[[
	The tutorial: a player's first Runs runs (profile.tutorialRuns counts them; Logic/Tutorial).
	A ROUGH DRAFT for the owner to tune: every stage and value lives here, no logic.

	The crew rides at its least experienced player's tier (the NPC errands' lowest-stage rule).
	Tier 1 is a first run, 2 the second, 3 the third; past them, none of this applies.

	stop1Cap        at most this many Hollows at stop 1 (nil: the threat curve alone)
	stop1Dormant    and they all start asleep (no wanderer, no fog spawns there)
	safeLightScale  SafeLight radii (parts tagged SafeLight, attribute Radius) scale by this;
	                Hollows never enter a lit radius. 0 or nil: the lights are only lamps
	grace           seconds after you step off the train before any Hollow comes for you
	zoneDegrees     skill-check zone width for the whole run (nil: Difficulty.SkillCheck.ZoneByStop)
	postGrab        immunity and stagger after breaking free, at every stop
	scriptedGrab    a slow Crawler's first grab at stop 1, to teach the skill check
]]

export type PostGrab = { immunity: number, stagger: boolean }

export type Tier = {
	stop1Cap: number?,
	stop1Dormant: boolean,
	safeLightScale: number,
	grace: number,
	zoneDegrees: number?,
	postGrab: PostGrab?,
	scriptedGrab: boolean,
}

local POST_GRAB: PostGrab = table.freeze({ immunity = 5, stagger = true })

local Tiers: { Tier } = {
	table.freeze({
		stop1Cap = 1,
		stop1Dormant = true,
		safeLightScale = 1,
		grace = 25,
		zoneDegrees = nil,
		postGrab = POST_GRAB,
		scriptedGrab = false,
	}),
	table.freeze({
		stop1Cap = 1,
		stop1Dormant = true,
		safeLightScale = 0.7,
		grace = 15,
		zoneDegrees = 100,
		postGrab = POST_GRAB,
		scriptedGrab = true,
	}),
	table.freeze({
		stop1Cap = nil,
		stop1Dormant = false,
		safeLightScale = 0.45,
		grace = 10,
		zoneDegrees = nil,
		postGrab = POST_GRAB,
		scriptedGrab = false,
	}),
}

return table.freeze({
	Runs = 3,
	Tiers = table.freeze(Tiers),

	-- SafeLight radii before the tier's scale (studs). The train's lights sit along the
	-- platform side of the train; the lamps are the platform's lamp posts.
	SafeLight = table.freeze({
		Tag = "SafeLight",
		TrainRadius = 34,
		LampRadius = 16,
	}),

	-- Tier 2's teaching grab: a slow Crawler comes for the first player who is off the train
	-- at stop 1 once their grace is over, and its hold has an oversized zone and cannot kill.
	ScriptedGrab = table.freeze({
		Stop = 1,
		Kind = "Crawler",
		AfterGrace = 4, -- seconds after the player's grace ends
		Distance = 18, -- studs from the player it claws up
		ChaseScale = 0.55, -- of its usual chase speed: you see it coming
		ZoneDegrees = 140,
	}),

	-- The owner's account: the only one the `/tutorial` chat command answers.
	OwnerUserId = 11744048795,
})
