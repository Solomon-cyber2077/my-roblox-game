--!strict
--[[
	Every gameplay constant that is not part of a curve lives here.
	Curves that scale with difficulty live in Config/Difficulty.
	Units: seconds, studs, studs per second, and resource units.
]]

local Tuning = {
	Run = {
		StationCount = 10, -- regular stops before the Terminus
		MaxCrew = 8,
		MinReadyShare = 0.5, -- share of lobby players that must be ready to start the countdown
		CountdownSeconds = 10,
		BoardingSeconds = 4,
		JunctionSeconds = 20,
		FinalJunctionSeconds = 8, -- the last junction has a single option: the Terminus
		CruiseBaseSeconds = 18,
		CruiseSecondsPerKm = 6,
		ArrivalSeconds = 10,
		LastCallSeconds = 15,
		TerminusSeconds = 8,
		RunEndSeconds = 12,
		JoinInProgressMaxStation = 6,
		TerminusDistanceKm = 5,
		RouteOptionCount = 2,
		WideJunctions = { [4] = true, [8] = true }, -- legs that offer three options
	},

	Motion = {
		CruiseSpeed = 110, -- studs per second, the speed the world scrolls past the train
		DepartureLingerSeconds = 12, -- after the chase window the station keeps sliding, then despawns
		SpinUp = 9, -- studs/s² the scenery gains toward cruise while boarding or at a junction
		DepartureSpinUp = 6, -- studs/s² when no departing station is there to follow
		RunEndBrake = 12, -- studs/s² the scenery loses when a run ends on the line
	},

	Train = {
		StartCoal = 40,
		CoalMax = 100,
		StartParts = 4,
		IntegrityMax = 100,
		BurnPerKm = 2.0,
		StarvingDrainPerSecond = 3,
		BreachDrainPerSecond = 0.5,
		MaxBreaches = 3,
		BreachPatchCost = 1,
		BreachPatchHold = 1.5,
		HullPatchCost = 5,
		HullPatchAmount = 20,
		TickSeconds = 0.25,
	},

	Crew = {
		MaxHealth = 100,
		WalkSpeed = 16,
		SprintSpeed = 25,
		StaminaMax = 100,
		StaminaDrainPerSecond = 16,
		StaminaRegenPerSecond = 25,
		StaminaRegenDelay = 1.0,
		BackpackSlots = 4,
		HeavySpeedMultiplier = 0.86, -- per heavy item, stacking
		JumpHeight = 7.2,
		HeavyJumpHeight = 5.0,
		HitSlowMultiplier = 0.6,
		HitSlowSeconds = 0.8,
		PositionTickHz = 10,
		FallDepth = 40, -- below platform height, in studs
		StragglerDepthMin = 0.6, -- share of the clear depth where stragglers spawn
		StragglerDepthMax = 0.8,
		ClutchBoardSeconds = 2, -- boarding this close to the chase deadline counts as a clutch
	},

	World = {
		FloorY = 0,
		TrainHalfWidth = 6.5,
		PlatformEdgeZ = 7,
		SafeStrip = 24,
		TileSize = 12,
		LobbyOrigin = { 0, 0, -12000 }, -- far enough that the landscape (|z| up to 4000) never reaches it
		AbyssY = -220,
	},

	-- The landscape the train rides through (client-only scenery, planned by Logic/Journey).
	Journey = {
		BlendAt = 0.35, -- share of a leg where the next biome starts to take over
		BlendLength = 600, -- studs over which two biomes mix
		PieceStart = 2400, -- the first set piece of a leg sits past the near window at the leg start
		PieceGap = { 700, 1300 }, -- clear track between one set piece and the next
		PlanLength = 9000, -- set pieces are planned this far past the leg start, then trimmed at the dock
		DockClearance = 400, -- no set piece ends closer than this to a station's sinkhole
		DockTolerance = 30, -- re-cut the sinkhole when the station lands further than this from the prediction
		SinkholeMarginX = 70, -- void past each end of the station
		SinkholeMarginZ = 60, -- void past the station's far edge
		GorgeHalfWidth = 1100, -- a gorge's void reaches this far out on both sides of the track
		TunnelCutting = 70, -- open rock cutting before each tunnel portal
		TypicalLeg = 6000, -- leg length the sky assumes before the route is chosen
		UnknownShareCap = 0.3, -- and how far through the leg it lets the sky run on that guess
		BuiltAhead = 2200, -- the near landscape is built this far ahead; later changes start beyond it
		PruneBehind = 3000, -- set pieces and sinkholes this far behind the train are forgotten
		-- Time of day by run progress (legs travelled). Hours keep counting past 24 so the
		-- night interpolates forward. mode: Stop = after `at` legs, Share = at that share of
		-- the run, End = `at` legs before the Terminus.
		Sky = {
			{ mode = "Stop", at = 0, hour = 18.3 }, -- the lobby: the sun just touching the horizon
			{ mode = "Stop", at = 1, hour = 18.9 }, -- first stop: sunset embers
			{ mode = "Stop", at = 2, hour = 19.6 }, -- second stop: the last blue light
			{ mode = "Share", at = 0.4, hour = 22 },
			{ mode = "Share", at = 0.65, hour = 26 }, -- two in the morning
			{ mode = "End", at = 1, hour = 28.9 }, -- the last stop before dawn
			{ mode = "End", at = 0, hour = 30.5 }, -- the Terminus at sunrise
		},
		-- Set pieces. length in studs along the track; reach is the |z| band kept clear of
		-- ordinary props (sided pieces use one side, the others both); pad extends it along x.
		Pieces = {
			{
				kind = "Tunnel",
				weight = 1.2,
				length = { 380, 560 },
				sided = false,
				reach = { 0, 300 },
				pad = 40,
			},
			{
				kind = "Gorge",
				weight = 1.0,
				length = { 240, 340 },
				sided = false,
				reach = { 0, 1100 },
				pad = 30,
			},
			{
				kind = "BurningTown",
				weight = 1.0,
				length = { 360, 480 },
				sided = true,
				reach = { 24, 380 },
				pad = 30,
			},
			{
				kind = "Halt",
				weight = 0.8,
				length = { 120, 150 },
				sided = true,
				reach = { 8, 120 },
				pad = 20,
			},
			{
				kind = "Wreck",
				weight = 0.8,
				length = { 160, 220 },
				sided = true,
				reach = { 10, 140 },
				pad = 20,
			},
			{
				kind = "Gantry",
				weight = 0.7,
				length = { 16, 16 },
				sided = false,
				reach = { 0, 30 },
				pad = 20,
			},
			{
				kind = "HollowField",
				weight = 0.7,
				length = { 260, 360 },
				sided = true,
				reach = { 30, 420 },
				pad = 20,
			},
			{
				kind = "Graveyard",
				weight = 0.6,
				length = { 140, 180 },
				sided = true,
				reach = { 24, 200 },
				pad = 20,
			},
			{
				kind = "Lake",
				weight = 0.6,
				length = { 300, 420 },
				sided = true,
				reach = { 36, 420 },
				pad = 20,
			},
			{
				kind = "Crossing",
				weight = 0.6,
				length = { 30, 30 },
				sided = false,
				reach = { 0, 420 },
				pad = 20,
			},
		},
	},

	-- Omens and storms in the night sky (Logic/Omens). Every client rolls the same schedule
	-- from the run seed and the server clock. `dark` is how deep into the night the run is:
	-- 0 at dusk and dawn, 1 at the darkest hour (Scenery/Sky).
	Sky = {
		OmenSlot = 45, -- seconds of server time per omen roll; an omen never crosses its slot
		OmenChance = { 0.2, 0.6 }, -- chance of an omen per slot at the edge of night, and at its depth
		OmenMinDark = 0.25, -- none in the dusk or the dawn
		Omens = {
			{ kind = "Hush", weight = 1.0, duration = 6, minDark = 0.25 }, -- every sound dies away
			{ kind = "TallOnes", weight = 1.0, duration = 6, minDark = 0.35 }, -- lightning shows figures
			{ kind = "Blink", weight = 1.1, duration = 2.4, minDark = 0.5 }, -- the moon closes, and opens
			{ kind = "Bleed", weight = 0.8, duration = 10, minDark = 0.55 }, -- the sky floods red
			{ kind = "Eye", weight = 0.5, duration = 8, minDark = 0.8 }, -- the moon looks down
		},
		RevealAt = { 0.08, 0.42, 0.74 }, -- TallOnes: lightning at these shares of the omen
		StrikeSlot = 3, -- seconds per lightning roll
		StrikeChance = 0.55, -- chance of a strike per slot in a full storm
		StrikeSeconds = 1.1, -- a strike's flicker
		StrikeRange = { 1500, 6500 }, -- studs from the train
		ThunderSpeed = 1200, -- studs per second
		DryLightning = 0.2, -- storm level every biome reaches at the darkest hour: far-off flickers
	},

	Camera = {
		MinZoom = 0.5, -- first person
		MaxZoom = 30,
		StartZoom = 11, -- close third person on every spawn
		SwayRoll = 0.35, -- degrees of roll at cruise while aboard
		RailLength = 48, -- a joint kick every rail length (about 0.45 s at cruise)
		BogieGap = 13, -- the second, softer kick follows after this many studs
		JointKick = 0.22, -- degrees of pitch per kick at cruise
	},

	Hollow = {
		StrikeRange = 4.5,
		StrikeCooldown = 1.5,
		SightRange = 80,
		AwarenessRange = 26,
		SafeMargin = 3,
		ThinkHz = 8,
		RetreatSeconds = 6,
	},

	Tools = {
		FlashRadius = 18,
		FlashStunSeconds = 3,
		TonicHeal = 50,
	},

	Economy = {
		BrassPerStation = 6,
		BrassPerTenCoal = 2,
		BrassPerFiveParts = 2,
		BrassPerRescue = 10,
		BrassVictoryAlive = 80,
		BrassVictoryCrew = 40,
		XpPerRun = 25,
		DailyFirstRunMultiplier = 2,
		DailyBonusCap = 400,
		CharterSoloMultiplier = 0.6,
		CharterDailyBrassCap = 1500,
		CharterStampMinCrew = 3,
		CharterStampMinStations = 5,
	},

	Data = {
		StoreName = "LTO_Profiles_v1",
		AutosaveSeconds = 120,
		LockTimeoutSeconds = 300,
		LoadRetries = 5,
		ReceiptHistory = 50,
	},
}

return table.freeze(Tuning)
