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

--[[
	A tutorial prompt: shown once per run, on runs of tier `tier`, when `when` first happens
	(Controllers/TutorialController). {KEY} becomes SPACE, A or TAP for the input device.
	  RunStart    the run begins (boarding, or the first junction)
	  OffTrain    you first step off the train
	  AwayFromTrain  you have been off the train AwaySeconds
	  NearEdge    you come within EdgeDistance of a sinkhole-edge marker (tag SinkholeEdge)
	  Grabbed     a Hollow seizes you
	  Cruise      the train is running between stops
	  Leak        a steam leak opens aboard
	  Exhausted   you sprint your breath out
	  Junction    the vote for the next stop opens
]]
export type Prompt = { id: string, tier: number, when: string, text: string }

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
		-- at the tutorial's first stop the yard's lamp pools are SafeLights too: a lit way out
		-- across the bigger stop, darkness between the pools (Services/StationService)
		YardLampsAtStop = 1,
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

	-- ROUGH DRAFT: the owner rewrites these freely. Order is the order they queue in.
	Prompts = table.freeze({
		-- run 1: moving, looting, the light, the edge
		{ id = "Move", tier = 1, when = "RunStart", text = "WASD to move. Hold SHIFT to sprint." },
		{
			id = "Loot",
			tier = 1,
			when = "OffTrain",
			text = "Search crates and bags with E. Carry coal and parts back aboard.",
		},
		{
			id = "Light",
			tier = 1,
			when = "AwayFromTrain",
			text = "Stay in the lantern light. Hollows will not follow you into it.",
		},
		{
			id = "Edge",
			tier = 1,
			when = "NearEdge",
			text = "The far edge drops into a sinkhole. Keep back from it.",
		},
		-- run 2: the skill check
		{
			id = "SkillCheck",
			tier = 2,
			when = "Grabbed",
			text = "Press {KEY} when the needle is in the zone.",
		},
		-- run 3: the hull, leaks, stamina, voting
		{
			id = "Hull",
			tier = 3,
			when = "Cruise",
			text = "Watch the hull. Repair it with parts at the Workbench.",
		},
		{
			id = "Leaks",
			tier = 3,
			when = "Leak",
			text = "A steam leak! Patch it with a part before it drains the hull.",
		},
		{
			id = "Stamina",
			tier = 3,
			when = "Exhausted",
			text = "Out of breath. Let the bar refill before you sprint again.",
		},
		{
			id = "Voting",
			tier = 3,
			when = "Junction",
			text = "Vote for the next stop. More danger, better loot.",
		},
	} :: { Prompt }),
	PromptSeconds = 7, -- each prompt stays this long (time behind another screen does not count)
	PromptGap = 1.2, -- seconds between one prompt and the next
	AwaySeconds = 8,
	EdgeDistance = 30,
	EdgeTag = "SinkholeEdge",

	-- The owner's account: the only one the `/tutorial` chat command answers.
	OwnerUserId = 11744048795,
})
