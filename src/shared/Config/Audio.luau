--!strict
--[[
	Sound cues. Every id is from Roblox's licensed audio library (Pro Sound
	Effects and Roblox's own uploads), so they are cleared for use in any
	experience without uploading anything.

	volume     0..1 base volume
	maxSeconds stop a long recording early
	spatial    true plays at a world position (3D falloff)
	loop       for beds and machinery
	group      a SoundGroup of its own (beside the main one, so ducking the mix leaves it alone)
	rollOff    studs a spatial cue carries before it falls silent (default 220)
	with       another cue played together with this one (a layered sound)
	mix        where it sits in the mix (AudioController; tiers in Config/AudioPriority): "Ambience"
	           (the beds the Settings volume turns down), "Outdoor" (ambience out in the night,
	           muffled by the carriage walls), "Cues" (threat: everything below ducks hard under
	           it), "Steps" and "Feedback" (footsteps and the player's own sounds), "Piano" (the
	           lobby piano, under everything). The Warnings group sits above them all.
]]

export type Cue = {
	id: number,
	volume: number,
	maxSeconds: number?,
	spatial: boolean?,
	loop: boolean?,
	pitch: number?,
	group: string?,
	rollOff: number?,
	mix: string?,
	with: string?,
}

local Cues: { [string]: Cue } = {
	Whistle = { id = 9119628070, volume = 0.7, maxSeconds = 4 },
	-- the co-op ping: a soft whistle from the pinger (the engine's whistle, high and short)
	PingWhistle = {
		id = 9119628070,
		volume = 0.35,
		maxSeconds = 0.9,
		pitch = 1.9,
		spatial = true,
		rollOff = 180,
		mix = "Feedback",
	},
	-- a stalking Hollow between cover: now and then a board creaks or a pebble skips (Prompt 7)
	StalkCreak = {
		id = 9114129572,
		volume = 0.22,
		maxSeconds = 0.9,
		pitch = 0.55,
		spatial = true,
		rollOff = 40,
		mix = "Cues",
	},
	StalkPebble = {
		id = 15675059323,
		volume = 0.16,
		maxSeconds = 0.4,
		pitch = 2.1,
		spatial = true,
		rollOff = 35,
		mix = "Cues",
	},
	Departure = { id = 9119628064, volume = 0.75, maxSeconds = 5 },
	Brakes = { id = 9114659986, volume = 0.6 },
	DoorsOpen = { id = 9120301474, volume = 0.5 },
	-- crossing the carriage door (Controllers/ThresholdController): a heavy door, muffled (ProSoundEffects
	-- "Door Bang Rattle 8", heavy double doors, Creator Store)
	DoorThud = { id = 9114129572, volume = 0.5, maxSeconds = 1.2, pitch = 0.78 },
	Alarm = { id = 9113085203, volume = 0.45, maxSeconds = 2.5, mix = "Cues" },
	Deposit = { id = 9113849492, volume = 0.6, mix = "Feedback" },
	Loot = { id = 17208319162, volume = 0.6, mix = "Feedback" },
	Heal = { id = 9114171855, volume = 0.6, mix = "Feedback" },
	Hit = { id = 9113570506, volume = 0.8, mix = "Feedback" },
	HollowSpawn = { id = 9125475729, volume = 0.9, spatial = true, mix = "Cues" },
	HollowStrike = { id = 9125471724, volume = 0.9, spatial = true, mix = "Cues" },
	Flash = { id = 9113024908, volume = 0.8, spatial = true, mix = "Feedback" },
	FlareLaunch = { id = 12222095, volume = 0.8, spatial = true, maxSeconds = 3 },
	FlareBurst = { id = 9114361763, volume = 0.7, spatial = true, maxSeconds = 3 },
	Toll = { id = 9113804436, volume = 0.35, maxSeconds = 4 },
	Eliminated = { id = 9126213744, volume = 0.7, mix = "Feedback" },
	Rumble = { id = 9113218938, volume = 0.7, spatial = true, maxSeconds = 2.5 },
	Thunder = { id = 9113218938, volume = 0.55, maxSeconds = 4, pitch = 0.62 },
	Collapse = { id = 9118582680, volume = 0.9, spatial = true, maxSeconds = 3 },
	SteamLeak = { id = 9116496074, volume = 0.6, spatial = true, loop = true },
	Victory = { id = 9112766203, volume = 0.5, maxSeconds = 6 },
	Purchase = { id = 9113728042, volume = 0.6, mix = "Feedback" },
	Clutch = { id = 9125573009, volume = 0.6, maxSeconds = 2, mix = "Feedback" },
	Click = { id = 15675059323, volume = 0.4, mix = "Feedback" },
	-- UI sounds, Creator Store (ProSoundEffects), chosen 2026-10-17 for audition (HANDOFF.md lists them)
	MenuClick = { id = 9120300134, volume = 0.3, maxSeconds = 0.25, pitch = 0.9, mix = "Feedback" }, -- "Typewriter Key 2"
	-- a vote lands: heavy paper, then the brass clip ("Paper Tear Heavy Paper Bag Slow Rustle 5")
	TicketStamp = { id = 9125725195, volume = 0.45, maxSeconds = 0.7, with = "BrassClick", mix = "Feedback" },
	BrassClick = { id = 9117028601, volume = 0.35, maxSeconds = 0.3, pitch = 0.85, mix = "Feedback" }, -- "Moviola Toggle Switch 6"
	-- the ticket's stamp coming down ("Table Hit Hand Smacks On Wood Table 14")
	TicketPunch = { id = 9119909448, volume = 0.6, maxSeconds = 0.6, pitch = 0.8, mix = "Feedback" },

	-- Departure warnings (Controllers/DepartureClock), from the recordings above
	WarnTick = { id = 15675059323, volume = 0.1, maxSeconds = 0.4, pitch = 1.7, group = "Warnings" },
	WarnBell = { id = 9113804436, volume = 0.35, maxSeconds = 4, pitch = 1.15, group = "Warnings" },
	-- whistles from the locomotive's chimney, heard across the whole stop
	WarnWhistle = {
		id = 9119628070,
		volume = 0.8,
		maxSeconds = 3,
		pitch = 0.8,
		spatial = true,
		group = "Warnings",
		rollOff = 900,
	},
	WarnWhistleLong = {
		id = 9119628070,
		volume = 1,
		maxSeconds = 6,
		pitch = 0.9,
		spatial = true,
		group = "Warnings",
		rollOff = 1600,
	},

	-- Beds
	TrainRun = { id = 9120247081, volume = 0.55, loop = true, mix = "Ambience" },
	Wind = { id = 9113286969, volume = 0.4, loop = true, mix = "Outdoor" },
	StationEerie = { id = 9125440141, volume = 0.35, loop = true, mix = "Outdoor" },
	DepotHall = { id = 9114872503, volume = 0.3, loop = true, mix = "Ambience" },
	-- Satie, Gnossienne No. 3 (APM Music), from the lobby piano (Builders/LobbyBuilder)
	LobbyPiano = { id = 1837474268, volume = 0.48, loop = true, spatial = true, mix = "Piano" },

	-- The stops' soundscape: the same recordings slowed and shaped (AudioController
	-- adds the filters and reverb), so nothing new needs clearing.
	-- the stop's drone (ProSoundEffects "Hollow Rumble 1", Creator Store): measured in Studio (AudioAnalyzer)
	-- at 86% of its energy in 60-120 Hz, 6% below. The same recording at 4x is its harmonic layer
	-- (77% in 250-500 Hz), so phone and laptop speakers that cannot play the body still hear the drone.
	Drone = { id = 9112795295, volume = 0.42, loop = true, mix = "Outdoor" },
	DroneHarmonic = { id = 9112795295, volume = 0.14, loop = true, pitch = 4, mix = "Outdoor" },
	-- the void mist's hum (Controllers/MistController): the drone's recording at 2x, between its body
	-- and its harmonic; MistController sets the volume (proximity, idle) every frame
	MistHum = { id = 9112795295, volume = 0, loop = true, pitch = 2, mix = "Outdoor" },
	Howl = { id = 9113286969, volume = 0.2, loop = true, pitch = 0.6, mix = "Outdoor" }, -- gusts that come and go
	DistantBell = {
		id = 9113804436,
		volume = 0.26,
		maxSeconds = 7,
		pitch = 0.62,
		spatial = true,
		mix = "Outdoor",
	},
	DistantCry = {
		id = 9125475729,
		volume = 0.24,
		maxSeconds = 4,
		pitch = 0.48,
		spatial = true,
		mix = "Outdoor",
	},
	Heartbeat = { id = 9113570506, volume = 0.65, maxSeconds = 1, pitch = 0.42, mix = "Cues" },
	RailClack = { id = 15675059323, volume = 0.14, maxSeconds = 1, pitch = 0.45 },

	-- The sky's omens (Logic/Omens), from the same recordings again
	SkyToll = { id = 9113804436, volume = 0.55, maxSeconds = 9, pitch = 0.36 }, -- a bell the size of the sky
	SkyGroan = { id = 9113218938, volume = 0.6, maxSeconds = 6, pitch = 0.3 }, -- the sky groans
	SkyHeart = { id = 9113570506, volume = 0.75, maxSeconds = 1.5, pitch = 0.28 }, -- the Eye's pulse

	-- weather
	Rain = { id = 9116496074, volume = 0.34, loop = true, pitch = 0.55, mix = "Outdoor" }, -- the steam hiss slowed into rain
	-- the storm outside the Depot Hall's back windows (Controllers/LobbyStorm); ProSoundEffects library
	LobbyRain = { id = 9112855439, volume = 0.5, loop = true, spatial = true, rollOff = 170, pitch = 0.92 },
	LobbyThunder = {
		id = 9116282646,
		volume = 0.8,
		spatial = true,
		rollOff = 420,
		maxSeconds = 10,
		pitch = 0.82,
	},
	LobbyThunderFar = {
		id = 9113218938,
		volume = 0.7,
		spatial = true,
		rollOff = 420,
		maxSeconds = 5,
		pitch = 0.5,
	},

	-- the fog: a scream slowed until it is many voices whispering, out where the fog lies
	FogWhisper = { id = 9125475729, volume = 0.5, loop = true, spatial = true, pitch = 0.36, mix = "Outdoor" },

	-- the Hollows, layered from the same few recordings at other speeds
	HollowScream = {
		id = 9125475729,
		volume = 1,
		spatial = true,
		pitch = 1.3,
		maxSeconds = 2.2,
		mix = "Cues",
	},
	HollowWake = {
		id = 9125475729,
		volume = 0.85,
		spatial = true,
		pitch = 0.72,
		maxSeconds = 3,
		mix = "Cues",
	},
	HollowSwipe = {
		id = 9125471724,
		volume = 0.85,
		spatial = true,
		pitch = 1.35,
		maxSeconds = 1,
		mix = "Cues",
	},
	HollowSlam = { id = 9113218938, volume = 1, spatial = true, pitch = 0.8, maxSeconds = 2, mix = "Cues" },
	HollowScrabble = {
		id = 9118582680,
		volume = 0.55,
		spatial = true,
		pitch = 1.7,
		maxSeconds = 1.2,
		mix = "Cues",
	},
	HollowStep = {
		id = 9113218938,
		volume = 0.35,
		spatial = true,
		pitch = 1.6,
		maxSeconds = 0.5,
		mix = "Steps",
	},

	-- building interactions
	DoorForce = {
		id = 9118582680,
		volume = 0.75,
		spatial = true,
		pitch = 1.25,
		maxSeconds = 1.5,
		mix = "Cues",
	},
	Winded = { id = 9113570506, volume = 0.45, maxSeconds = 0.8, pitch = 0.5 },

	-- Footsteps by surface (Logic/Footsteps, Controllers/FootstepController): Creator Store
	-- uploads, free, chosen 2026-10-15 for audition (HANDOFF.md lists them with their sources).
	-- Two or three takes a surface; the controller picks one and nudges the pitch per step.
	StepPlank1 = {
		id = 136507037003210,
		volume = 0.5,
		spatial = true,
		rollOff = 70,
		maxSeconds = 0.8,
		mix = "Steps",
	},
	StepPlank2 = {
		id = 137526436035209,
		volume = 0.5,
		spatial = true,
		rollOff = 70,
		maxSeconds = 0.8,
		mix = "Steps",
	},
	-- the carriage floor: the same boards, lower, hollow over the underframe
	StepTrain1 = {
		id = 136507037003210,
		volume = 0.45,
		spatial = true,
		rollOff = 50,
		maxSeconds = 0.9,
		pitch = 0.8,
		mix = "Steps",
	},
	StepTrain2 = {
		id = 137526436035209,
		volume = 0.45,
		spatial = true,
		rollOff = 50,
		maxSeconds = 0.9,
		pitch = 0.76,
		mix = "Steps",
	},
	StepGravel1 = {
		id = 131788428206726,
		volume = 0.5,
		spatial = true,
		rollOff = 70,
		maxSeconds = 0.8,
		mix = "Steps",
	},
	StepGravel2 = {
		id = 132387836053582,
		volume = 0.5,
		spatial = true,
		rollOff = 70,
		maxSeconds = 0.8,
		mix = "Steps",
	},
	StepSnow1 = {
		id = 103816422099881,
		volume = 0.55,
		spatial = true,
		rollOff = 60,
		maxSeconds = 0.7,
		mix = "Steps",
	},
	StepSnow2 = {
		id = 135918121539048,
		volume = 0.55,
		spatial = true,
		rollOff = 60,
		maxSeconds = 0.7,
		mix = "Steps",
	},
	StepSnow3 = {
		id = 103079968724414,
		volume = 0.55,
		spatial = true,
		rollOff = 60,
		maxSeconds = 0.7,
		mix = "Steps",
	},
	-- heavy breathing while stamina is spent (MovementController.IsExhausted), not tied to combat
	Breath = { id = 100147087354736, volume = 0.5, loop = true, mix = "Feedback" },
}

for _, cue in Cues do
	table.freeze(cue)
end

return table.freeze(Cues)
