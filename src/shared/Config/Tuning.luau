--!strict
--[[
	Every gameplay constant that is not part of a curve lives here.
	Curves that scale with difficulty live in Config/Difficulty.
	Units: seconds, studs, studs per second, and resource units.
]]

local Tuning = {
	Run = {
		StationCount = 10, -- regular stops before the Terminus
		MaxCrew = 4,
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

	-- Departure warnings at a stop (Logic/DepartureSchedule, Controllers/DepartureClock).
	-- Seconds are counted down to run.station.departAt.
	Departure = {
		WarningSeconds = 30, -- the watch starts ticking, the bell and a low whistle
		EscalatedSeconds = 10, -- the tick doubles, the long whistle
		HalfwayMinSeconds = 60, -- shorter stops get no halfway reminder
		ReminderGapSeconds = 15, -- a start or halfway reminder this close to another is dropped
		CatchUpSeconds = 2, -- a milestone this recently passed still fires when a stop is first seen
		DuckShare = 0.2, -- the rest of the mix dips this much under the bell and whistles
		DuckSeconds = 0.3,
		FogDensity = 0.08, -- extra Atmosphere density at full warning
	},

	-- The Last Call grace after T-0 (Logic/RunRules): the whistle blows and the station stays docked this
	-- long before it actually departs (run.station.lastCallEndsAt). Off: it departs at T-0 as before.
	LastCallGrace = {
		Enabled = true,
		Seconds = 3,
		PulseRate = 2.5, -- pulses per second of the lanterns at the train's platform doors
		LanternBrightness = 1.6,
		LanternRange = 12,
	},

	-- Boarding cars on the Depot Hall's display train: a full car, or a car whose countdown runs out,
	-- leaves for its own server.
	Cars = {
		MinPlayers = 2, -- the countdown starts once this many are aboard
		MaxPlayers = 4, -- a full car leaves at once
		CountdownSeconds = 40,
		ExitWindowSeconds = 10, -- after the countdown starts, the door lets people out this long
		HoldSeconds = 0.6, -- hold E to board or leave (touch players tap)
		FadeSeconds = 1, -- the screen goes black this long before the teleport
		ArrivalWaitSeconds = 20, -- a car's server waits this long for the whole car to arrive
		PromptDistance = 8,
		CameraZoom = 4.5, -- the camera's distance cap aboard: a car is narrower than the default zoom
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
		WalkSpeed = 20, -- a jog: Hollows on the hunt are a little faster
		SprintSpeed = 31, -- and a sprint outruns them, while the breath lasts
		StaminaMax = 100,
		StaminaDrainPerSecond = 18, -- about five and a half seconds of sprint
		StaminaRegenPerSecond = 22,
		StaminaRegenDelay = 0.9,
		ExhaustedResume = 0.35, -- run dry and you cannot sprint again until this share is back
		WindedSeconds = 1.6, -- running dry leaves you winded: slower for this long
		WindedMultiplier = 0.85,
		SprintFov = 9, -- degrees the camera widens at full sprint
		BackpackSlots = 4,
		HeavySpeedMultiplier = 0.86, -- per heavy item, stacking
		JumpHeight = 7.2,
		HeavyJumpHeight = 5.0,
		HitSlowMultiplier = 0.7,
		HitSlowSeconds = 0.6,
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
		StopHours = 0.15, -- share of a leg's night that passes while the train stands at its stop
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

	TrainCamera = {
		OrbitNear = 45,
		OrbitFar = 260,
		GamepadYaw = 1.8, -- radians per second at full stick
		GamepadPitch = 1.2,
		GamepadDeadzone = 0.12,
		ZoomSpeed = 90,
		MoonDistance = 240,
		MoonHeight = 4,
		MoonMargin = 6, -- degrees of space around the train and moon
		TrainRadius = 105, -- covers the whole consist in the moon shot
		TrainHalfHeight = 10,
		TrainHalfWidth = 8,
	},

	Hollow = {
		StrikeRange = 6.5, -- a strike starts when the target is this close to the Hollow's root
		HitRange = 8, -- and lands if the target is still this close when the windup ends
		WindupSeconds = 0.3, -- the tell: the Hollow rears back before it strikes
		RecoverSeconds = 0.4,
		StrikeCooldown = 0.9, -- from one strike's start to the next
		LungeRange = 16, -- a hunter this close bursts forward
		LungeBoost = 1.45, -- its speed multiplier while lunging
		LungeSeconds = 0.55,
		LungeCooldown = 3.5,
		SightRange = 95,
		AwarenessRange = 30,
		SafeMargin = 3,
		ThinkHz = 12,
		RetreatSeconds = 6,
		StopShort = 2.4, -- hunters aim this far short of the target, so they never stand on it
		PathEvery = 0.6, -- seconds between path recomputes when the target is out of sight
		SameFloor = 4, -- a seen target this close in height is walked at straight; higher or lower, it paths
		StallSeconds = 2, -- a hunter that stays within StallRadius this long has stalled
		StallRadius = 2,
		NarrowRadius = 1, -- path agent radius tried when the full-size one finds no way
		StallRepath = 3, -- seconds a stalled hunter follows a computed path, even with the target in sight
		EmergeSeconds = 1.7, -- a spawn or a wake: it cannot move or strike yet
		WakeRange = 16, -- a sleeper wakes when crew come this close
		WakeSight = 30, -- or into its line of sight this close
		SleeperStir = 0.5, -- share of the dwell after which sleepers wake on their own
		LitFlee = 1.2, -- seconds a Hollow caught in a lit building cowers before it flees
		PaceSpread = 0.06, -- each Hollow keeps its own pace, up to this share off its kind's
		FlankAngle = 58, -- degrees between hunters closing on the same crew member
		FlankUntil = 11, -- hunters fan out around a target until this close, then go straight in
		Spacing = 1.5, -- studs Hollows keep between their bodies (on top of their kinds' radii)
	},

	--[[
		The kinds of Hollow (Config/Difficulty holds how often each comes). walk and chase
		scale the hazard's speeds by body: the Crawler creeps, then bolts; the Brute is slow
		but never stops. reach scales the strike and hit ranges, radius is the body's
		footprint (they keep apart by it). A strike that lands becomes a grab
		(Config/Grabs): grip scales how hard it is to break free, crush the damage.
	]]
	HollowKinds = {
		Stalker = { walk = 1, chase = 1, reach = 1, windup = 1, radius = 1.6, grip = 1, crush = 1 },
		Crawler = {
			walk = 0.8,
			chase = 1.1,
			reach = 0.9,
			windup = 0.7,
			radius = 2.6,
			grip = 0.8,
			crush = 0.85,
		},
		Brute = {
			walk = 0.9,
			chase = 0.82,
			reach = 1.25,
			windup = 1.4,
			radius = 2.2,
			grip = 1.2,
			crush = 1.4,
		},
	},

	--[[
		Grabs (Logic/Grab). Every press of the struggle key adds the stop's grabMash to the
		victim's escape, which slips back at grabSlip per second; reaching Escape breaks the
		hold. Meanwhile the Hollow bites, squeezes or yanks once per its grab's rhythm.
	]]
	Grab = {
		Escape = 1,
		DpsShare = 0.4, -- damage per second while held, as a share of the stop's hollowDamage
		AllyPresses = 2.5, -- a crewmate prying at the Hollow counts as this many presses
		Grace = 2.5, -- seconds after breaking free before anything can grab you again
		Stagger = 1.6, -- seconds a Hollow reels when its victim breaks free
		Throw = 42, -- studs per second the victim is flung clear when they break free
		MaxSeconds = 14, -- no hold lasts longer than this
		Settle = 0.3, -- seconds the snatch takes before the hold begins to hurt
		PryInterval = 0.15, -- server limit per helper, matching a deliberate button mash
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
