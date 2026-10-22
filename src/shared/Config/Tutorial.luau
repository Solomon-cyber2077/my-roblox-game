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
	scriptedGrab    the scripted Crawler at ScriptedGrab.Stop, to teach the skill check
	quietUntilStop  stops 1..this: no wanderer and no timed events (no Surge), so only the
	                planned first-run encounters happen (docs/FINAL-DESIGN.md Prompt 5)
	sighting        stop 1's scripted Stalker sighting (Sighting below; E2's treatment arm)
	stop3Stalker    stop 3 holds one awake Stalker, a wanderer that stalks the first player
	                Stop3.AwayStuds or more from the train, and nothing else

	First run (tier 1, Prompt 5): stop 1 no attacks and the sighting, no leak on the first cruise;
	stop 2 the scripted Crawler (pursuit 24, lunge 40, the first-strike guard); stop 3 the
	stalking wanderer. Tier 2 keeps zone 100 and grace 15 without a scripted grab.
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
	  Carrying    your backpack holds something
]]
-- touch: the wording on a phone or tablet (the keys in `text` mean nothing there)
export type Prompt = { id: string, tier: number, when: string, text: string, touch: string? }

export type Tier = {
	stop1Cap: number?,
	stop1Dormant: boolean,
	safeLightScale: number,
	grace: number,
	zoneDegrees: number?,
	postGrab: PostGrab?,
	scriptedGrab: boolean,
	quietUntilStop: number?,
	sighting: boolean,
	stop3Stalker: boolean,
}

local POST_GRAB: PostGrab = table.freeze({ immunity = 5, stagger = true })

local Tiers: { Tier } = {
	table.freeze({
		stop1Cap = 0, -- no attacks at all on a first run's stop 1: only the sighting
		stop1Dormant = true,
		safeLightScale = 1,
		grace = 25,
		zoneDegrees = 100,
		postGrab = POST_GRAB,
		scriptedGrab = true,
		quietUntilStop = 2,
		sighting = true,
		stop3Stalker = true,
	}),
	table.freeze({
		stop1Cap = 1,
		stop1Dormant = true,
		safeLightScale = 0.7,
		grace = 15,
		zoneDegrees = 100,
		postGrab = POST_GRAB,
		scriptedGrab = false,
		quietUntilStop = nil,
		sighting = false,
		stop3Stalker = false,
	}),
	table.freeze({
		stop1Cap = nil,
		stop1Dormant = false,
		safeLightScale = 0.45,
		grace = 10,
		zoneDegrees = nil,
		postGrab = POST_GRAB,
		scriptedGrab = false,
		quietUntilStop = nil,
		sighting = false,
		stop3Stalker = false,
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
		-- where the teaching Crawler comes (ScriptedGrab.Stop) the yard's lamp pools are SafeLights
		-- too: a lit way out across the bigger stop, darkness between the pools (StationService)
		YardLampsAtStop = 2,
	}),

	-- Prompt 5 installs this tier-1 stop-2 encounter; absolute speeds ignore normal scaling.
	FirstCrawler = table.freeze({
		Tier = 1,
		Stop = 2,
		ChaseSpeed = 24,
		LungeSpeed = 40,
		LungeSeconds = 0.55,
		WarningSeconds = 1.5,
	}),

	-- The first run's teaching Crawler (tier 1, stop 2): it comes for the first player who is off
	-- the train once their grace is over, at FirstCrawler's absolute speeds behind the
	-- first-strike guard; its hold has the oversized zone and cannot kill. Sprinting away works.
	ScriptedGrab = table.freeze({
		Stop = 2,
		Kind = "Crawler",
		AfterGrace = 4, -- seconds after the player's grace ends
		Distance = 18, -- studs from the player it claws up
		ChaseScale = 0.55, -- only if a scripted Crawler ever runs outside FirstCrawler's stop
		ZoneDegrees = 100,
	}),

	-- Stop 1's scripted sighting (Prompt 5, FIXED; E2's treatment arm). `Enabled` decides while E2
	-- is off (Config/Experiments); E2's arm decides while it runs. A harmless Stalker appears in
	-- sight of a crew member off the train, holds the Stalk freeze, then withdraws at walking pace.
	Sighting = table.freeze({
		Enabled = true,
		Kind = "Stalker",
		Near = 15, -- studs from that player: inside Visibility RadiusMin 18 at every setting
		Far = 17,
		Fallback = 24, -- the nearest legal point up to this when none fits 15-17
		LampMargin = 4, -- studs outside every lamp pool, at the light's edge
		MinSeconds = 3, -- held at least this long after anyone first sees it
		FacedSeconds = 1, -- faced this long (after the minimum): it withdraws
		SeenSeconds = 1.5, -- every living off-train member has seen it this long: it withdraws
		MaxSeconds = 12, -- it withdraws by now whatever happens
		WithdrawSeconds = 8, -- walking away, then it is gone
		RetrySeconds = 1, -- no spot in view yet: look again this often while someone is off the train
	}),

	-- Stop 3 of a first run: one Stalker, a wanderer-with-stalk (Prompt 5, FIXED).
	Stop3 = table.freeze({
		Stop = 3,
		Kind = "Stalker",
		AwayStuds = 20, -- it targets only a player this far from the train
	}),

	-- Shown to a crew member riding below their own tier (Logic/Tutorial.crewTier).
	NewHandPace = "Riding at a new Hand's pace.",

	-- ROUGH DRAFT: the owner rewrites these freely. Order is the order they queue in.
	Prompts = table.freeze({
		-- run 1: moving, looting, the light, the edge
		{
			id = "Move",
			tier = 1,
			when = "RunStart",
			text = "WASD to move. Hold SHIFT to sprint.",
			touch = "Move with the left stick. Tap RUN to sprint, tap again to walk.",
		},
		{
			id = "Loot",
			tier = 1,
			when = "OffTrain",
			text = "Search crates and bags with E. Carry coal and parts back aboard.",
			touch = "Tap a crate or bag to search it. Carry coal and parts back aboard.",
		},
		{
			id = "Drop",
			tier = 1,
			when = "Carrying",
			text = "Right-click an item in your backpack to drop it.",
			touch = "Press and hold an item in your backpack to drop it.",
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
		{
			id = "Face",
			tier = 1,
			when = "Stalked",
			text = "Face it and it waits. Staring only buys time; the glance just looks behind you.",
		},
		{
			id = "Bell",
			tier = 1,
			when = "BackAboard",
			text = "Everyone aboard? Ring the bell in the saloon to leave early.",
		},
		-- run 2: the skill check
		{
			id = "SkillCheck",
			tier = 2,
			when = "Grabbed",
			text = "Press {KEY} when the marker is on the white.",
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
