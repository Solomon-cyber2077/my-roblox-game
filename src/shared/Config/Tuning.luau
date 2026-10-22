--!strict
--[[
	Every gameplay constant that is not part of a curve lives here.
	Curves that scale with difficulty live in Config/Difficulty.
	Units: seconds, studs, studs per second, and resource units.
]]

local Difficulty = require(script.Parent.Difficulty)

local Tuning = {
	Run = {
		StationCount = 10, -- regular stops before the Terminus
		MaxCrew = 4,
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

	-- The train's door threshold, per player (Logic/Threshold, Controllers/ThresholdController).
	-- Crossing it never blocks controls or darkens the screen: light and sound only crossfade.
	Threshold = {
		FadeOut = 1.2, -- seconds for the station's cold light and sound to come in off the train (<= 1.5)
		FadeIn = 0.9, -- seconds for the train's warmth to come back aboard
		MuffleIn = 0.08, -- seconds for the walls to close over the outside sound on boarding
		Margin = 0.6, -- studs either side of the door before a crossing counts (no flicker on the sill)
		Teleport = 12, -- studs moved in one frame that count as a teleport, not a step (no thud)
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
		-- each coal an item carries (Config/Items `coal`) fills this many units of the bunker and
		-- its gauge when loaded (Logic/Ledger.deposit); the items and their stacks are unchanged
		CoalGaugePerCoal = 2,
		-- leaks, hull drain and repair: Config/Difficulty Leaks and Hull
		TickSeconds = 0.25,
	},

	-- The crew chest in the stores car (Logic/CrewChest): consumables the whole crew shares.
	CrewChest = {
		Capacity = 12, -- items it holds
		Reach = 10, -- studs from the chest a player may stow or take
	},

	-- The floor arrows to a leak (Logic/LeakRoute, Controllers/LeakController), in train-local
	-- studs (x along the train, z across it, the aisle at z = 0, TrainBuilder's layout).
	LeakArrows = {
		Spacing = 2.4, -- studs between chevrons
		Count = 24, -- at most this many ahead of you
		Lead = 2, -- the first one this far ahead of your feet
		Scroll = 1.6, -- studs per second the chevrons creep toward the leak
		CurveIn = 4.5, -- the aisle line turns toward the wall this far before the leak
		WallInset = 4.2, -- and ends this far from the train's middle (the wall is at 6.5)
		CabAnchor = "CAB", -- the Last Light's leak anchor: reached from the platform, not the cars
		CabDoorX = 58, -- the Last Light's door, on the platform (+z) side
		CabDoorZ = 7,
		PlatformApproach = 3.5, -- the platform line runs this far out from the cab door
		PlatformReach = 140, -- farther than this from the cab door, no platform arrows
		-- the notice at the top of the screen when the Last Light starts leaking
		NoticeText = "Steam leak in the Last Light car",
		NoticeIn = 0.25, -- seconds to fade in
		NoticeHold = 1.6, -- seconds fully shown
		NoticeOut = 0.9, -- seconds to fade out
	},

	-- Footsteps (Logic/Footsteps): one step every Stride studs walked, never faster than
	-- MinInterval nor slower than MaxInterval; none below MinSpeed. Takes per surface.
	Footsteps = {
		Stride = 6.2,
		MinInterval = 0.2,
		MaxInterval = 0.7,
		MinSpeed = 2,
		PitchJitter = 0.08,
		Takes = { Plank = 2, TrainFloor = 2, Gravel = 2, Snow = 3 },
		BreathFade = 1.5, -- seconds the breathing takes to swell or die away
	},
	Crew = {
		MaxHealth = 100,
		WalkSpeed = 21, -- carry speeds: duo 17.85, solo 13.65; sprint still costs stamina
		SprintSpeed = 31, -- and a sprint outruns them, while the breath lasts
		StaminaMax = 100,
		StaminaDrainPerSecond = 18, -- about five and a half seconds of sprint
		StaminaRegenPerSecond = 22,
		StaminaRegenDelay = 0.9,
		ExhaustedResume = 0.35, -- run dry and you cannot sprint again until this share is back
		WindedSeconds = 1.6, -- running dry leaves you winded: slower for this long
		WindedMultiplier = 0.85,
		SprintFov = 9, -- degrees the camera widens at full sprint
		BackpackSlots = 6,
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
		-- Past a sinkhole's far rim (Scenery/Features backdrop): a treeline, rolling hills and a
		-- mountain massif, on ground the landscape leaves to it. Reaches in studs past the rim;
		-- Margin past each end.
		Backdrop = {
			Margin = 160,
			Reach = 1300,
			TreeLine = { 30, 130 },
			Hills = { 280, 620 },
			Peaks = { 800, 1150 },
			PeakHeight = { 170, 290 }, -- under the moon's path seen from the platform
		},
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
		GlanceDegrees = 150,
		GlanceSeconds = 0.18,
		GlanceTouchGap = 8,
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
		LungeRange = 16, -- a hunter this close bursts forward
		LungeBoost = 1.45, -- its speed multiplier while lunging
		LungeSeconds = 0.55,
		LungeCooldown = 3.5,
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
	-- Client-only dressing; never feeds Hollow pace, damage or rig dimensions.
	HollowCosmetics = {
		ProgressStart = 0.3,
		Distance = 120,
		DustSpeed = 6,
		IdleSpeed = 0.5,
		StepTime = 0.16,
		NeckAngle = 0.035,
		JawAngle = 0.045,
		MaxParts = 40,
		ShedCount = 3,
		ShedPeriod = 3.2,
		ShedFall = 0.8,
		ShedDrop = 1.8,
		LightRange = 5,
		EyeDim = 0.12,
		EyeAlert = 0.8,
		DripClean = 0.15,
		DripDirty = 1.1,
		BreathRate = 1.3,
		DustRate = 4,
		SmokeRate = 0.5,
		Lifetime = 1.2,
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Colors = {
			Bone = { 205, 201, 178 },
			Grime = { 67, 51, 35 },
			Blood = { 72, 20, 19 },
			Hair = { 28, 25, 24 },
			Coat = { 44, 58, 50 },
			Crack = { 38, 34, 29 },
			Brass = { 115, 91, 47 },
			Iron = { 70, 65, 58 },
			Paper = { 159, 145, 109 },
			Eye = { 188, 191, 137 },
			Mist = { 176, 180, 186 },
		},
	},
	HollowMotion = {
		SpeedResponse = 8,
		TwitchAngle = 0.12,
	},
	HollowContortion = {
		StalkerLean = 0.5,
		StalkerTwist = 0.45,
		StalkerRoll = 0.42,
		StalkerNeck = 0.65,
		CrawlerDrop = 0.35,
		CrawlerTwist = 0.32,
		CrawlerRoll = 0.3,
		CrawlerNeck = 0.75,
		Jaw = 0.35,
	},
	HollowKinds = {
		Stalker = {
			walk = 1,
			chase = 1,
			lunge = 1.45,
			reach = 1,
			windup = 1,
			radius = 1.6,
			grip = 1,
			crush = 1,
		},
		Crawler = {
			walk = 0.8,
			chase = 1,
			lunge = 1.6,
			reach = 0.9,
			windup = 0.7,
			radius = 2.6,
			grip = 0.8,
			crush = 0.85,
		},
		Brute = {
			walk = 0.9,
			chase = 0.98, -- was 0.82: every Hollow on the hunt outpaces a jog (tests/HollowSpeed.spec)
			lunge = 0,
			reach = 1.25,
			windup = 1.4,
			radius = 2.2,
			grip = 1.2,
			crush = Difficulty.GrabDamage.BruteCrush,
		},
	},

	--[[
		Grabs (Logic/Grab). The victim breaks free with skill checks (Logic/SkillCheck,
		Difficulty.SkillCheck) before the grab's clock runs out. Meanwhile the Hollow bites,
		squeezes or yanks once per its grab's rhythm.
	]]
	Grab = {
		Throw = 42, -- studs per second the victim is flung clear when they break free
		Settle = 0.3, -- seconds the snatch takes before the hold begins to hurt
		PryInterval = 0.15, -- server limit per helper, matching a deliberate button mash
		-- A Brute's strike slams its victim face down and pins them (Config/Grabs "Slam").
		Pin = {
			Tick = 1, -- seconds between damage ticks while pinned (damage: Difficulty.GrabDamage)
			SlamSeconds = 0.35, -- the body is driven from standing to the ground over this long
		},
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
		SaveRetries = 3, -- attempts per save; a save that still fails stays dirty for the next autosave
		SaveRetryDelay = 1, -- seconds before the second attempt, doubling after
		ReceiptHistory = 50,
	},

	-- The train's residents (Config/Npcs) and their errands (Config/NpcQuests).
	Npc = {
		PromptDistance = 8,
		TalkCooldown = 1.2, -- seconds between one player's talks with one NPC
		HelperBrass = 10, -- "Lent a hand": finishing an errand you are already past
		LowCoalFraction = 0.25, -- coal below this share of the bunker: LowSupplies
		ItemOffset = 3, -- studs from the container the errand item is left beside
		ScanSeconds = 1, -- how often the crew's backpacks are checked for errand items
	},
	Lobby = {
		SeatRetouchDelay = 1.5, -- seconds a lobby seat ignores touches after someone stands up
	},
	-- The crew's carried lantern: one PointLight whose reach is the readability floor
	-- (Visibility.Radius) for every cosmetic, plus the bearer's own forward cone (client only).
	-- A lantern's look changes only its colour, glow style and flicker (Config/Cosmetics,
	-- Visual/CosmeticModels)
	CarriedLantern = {
		LightBrightness = 1.1, -- the pool's strength; a look's glow (>= 1) only adds to it
		ConeRange = 34, -- studs the forward cone reaches ahead of the bearer
		ConeAngle = 62, -- degrees across the cone
		ConeBrightness = 1.6,
		ConeHeight = 1.2, -- studs above the root it shines from
	},
	--[[
		The readability floor (Logic/Visibility): however dark the night, the fog or a chase gets,
		ground and obstacles stay readable this far round a player in every direction, on a dim
		screen in a dark room. Radius is the one value a Settings "Visibility" slider moves
		(RadiusMin..RadiusMax); the ambient floors scale with it.
	]]
	Visibility = {
		Radius = 18, -- studs readable all round
		Setting = "Visibility", -- the player attribute a Settings slider writes (studs; nil = Radius)
		RadiusMin = 18,
		RadiusMax = 30,
		-- the slider's starting point, tuned for a dim phone: the top of the measured-safe range, the
		-- nearest it comes to the 31-stud sprint reaction distance and under the 38-stud mood
		-- ceiling (tools/visibility, HANDOFF visibility parts 2-3). Bright screens can turn it down.
		Default = 30,
		AmbientFloor = { 54, 58, 66 }, -- Lighting.Ambient never darker than this (per channel)
		OutdoorFloor = { 88, 96, 110 }, -- Lighting.OutdoorAmbient never darker than this
		ExposureFloor = 0.26, -- Lighting.ExposureCompensation never lower
		DensityCap = 0.62, -- Atmosphere.Density never thicker: 0.78 hid the ground inside 18 studs
		-- a cold moonlit edge on the nearest obstacles and tall structures, so silhouettes read
		-- (Highlights: a fixed pool whose Adornee moves, never created per frame)
		Rim = {
			Kinds = {
				"Canopy",
				"GatePier",
				"Chimney",
				"Elm",
				"Statue",
				"Obelisk",
				"DrinkingFountain",
				"NoticeBoard",
			}, -- station props; every station building is rimmed too
			Range = 90, -- studs: nothing further is rimmed
			Max = 8, -- Highlights at once (Performance: MaxPerformance)
			MaxPerformance = 4,
			Color = { 168, 194, 228 }, -- moonlight
			Outline = 0.55, -- outline transparency
			Fill = 0.94, -- fill transparency: the faintest cold wash
			Every = 0.75, -- seconds between choosing the nearest
		},
		-- the train's warm lamp glow, seen from anywhere on the station: a soft billboard (no
		-- light), a fixed size on screen, fading out as you come close
		Beacon = {
			Color = { 255, 178, 96 }, -- the carriages' lamp amber
			Pixels = 84, -- the glow's size on screen
			Rings = { 0.86, 0.76, 0.62 }, -- transparency of each ring, outer to inner (Performance: the inner)
			Height = 4, -- studs above the train's roof
			Near = 40, -- studs from the train where it has faded out
			Far = 90, -- and where it is full
		},
		-- each station's own cold, desaturated grade (cyan to olive-grey), weighed in as the
		-- camera steps off the train onto the platform; the train and the lobby stay warm amber.
		-- tint is the ColorCorrection tint, saturation is taken off on top of the night's
		Grades = {
			Default = { tint = { 214, 230, 232 }, saturation = 0.18 },
			Halt = { tint = { 210, 228, 230 }, saturation = 0.16 }, -- plain cold cyan
			CoalYard = { tint = { 214, 218, 204 }, saturation = 0.24 }, -- soot olive
			SignalWorks = { tint = { 204, 226, 234 }, saturation = 0.2 }, -- steel cyan
			Market = { tint = { 220, 224, 206 }, saturation = 0.16 }, -- olive-grey
			Viaduct = { tint = { 206, 224, 238 }, saturation = 0.2 }, -- high cold air
			Minehead = { tint = { 208, 222, 214 }, saturation = 0.22 }, -- damp green-grey
			Schoolhouse = { tint = { 218, 226, 220 }, saturation = 0.18 }, -- chalk grey
			Infirmary = { tint = { 212, 232, 230 }, saturation = 0.26 }, -- carbolic cyan
			RailwayHotel = { tint = { 222, 226, 212 }, saturation = 0.14 }, -- faded olive
			PostTown = { tint = { 214, 224, 226 }, saturation = 0.18 }, -- slate
			EmergencyVillage = { tint = { 216, 220, 202 }, saturation = 0.24 }, -- mud olive
			Terminus = { tint = { 224, 232, 236 }, saturation = 0.1 }, -- dawn coming
		},
		GradeRamp = 8, -- studs past the platform edge over which the grade comes in
		-- what all this may cost: one light per player (their lantern), one shadow-casting
		-- light (your own cone, Quality only), and under Performance simpler variants
		Budget = {
			Shadows = 1, -- shadow-casting lights this adds (Performance: none)
			LanternCull = 90, -- Performance: crewmates' lanterns further than this switch off
			ConeRangePerformance = 26, -- Performance: the forward cone's shorter reach
		},
		--[[
			The chase (the only chase effect; Logic/Visibility.chaseStep): a Hollow on the hunt
			whose nearest crew member is you, within Detect. A sudden black flicker, then the dark
			stays: the ambient dims, the remaining lights dim but reach a little further, the dread
			vignette all but goes. Escaped Hold seconds, it snaps back a shade brighter than
			normal, and the night settles back over ReliefFade. The floor still holds throughout.
		]]
		Chase = {
			Detect = 60, -- studs: a hunting Hollow this close, nearest to you, is chasing you
			Hold = 4, -- seconds out of detection before the relief
			ReliefFade = 10, -- seconds the relief takes to settle back to the normal dark
			Ambient = 0.5, -- the ambient and outdoor ambient's share while chased
			Brightness = 0.6, -- Lighting.Brightness's share while chased
			Exposure = 0.18, -- exposure taken off while chased
			LightBrightness = 0.65, -- the station's own lamps: dimmer
			LightRange = 1.15, -- but reaching a little further
			Vignette = 0.08, -- the dread vignette's share while chased
			ReliefExposure = 0.1, -- exposure added at the relief's start, easing away
			-- the flicker: black opacity from each time (seconds after it starts) to the next
			Flicker = { { 0, 0.94 }, { 0.05, 0 }, { 0.11, 0.85 }, { 0.17, 0.1 }, { 0.24, 0.92 }, { 0.36, 0 } },
		},
	},
}

return table.freeze(Tuning)
