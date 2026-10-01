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
		LobbyOrigin = { 0, 0, -3200 },
		AbyssY = -220,
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
