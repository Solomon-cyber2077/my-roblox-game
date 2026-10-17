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
	mix        where it sits in the mix (AudioController): "Ambience" (the beds the Settings
	           volume turns down), "Outdoor" (ambience out in the night, muffled by the carriage walls)
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
}

local Cues: { [string]: Cue } = {
	Whistle = { id = 9119628070, volume = 0.7, maxSeconds = 4 },
	Departure = { id = 9119628064, volume = 0.75, maxSeconds = 5 },
	Brakes = { id = 9114659986, volume = 0.6 },
	DoorsOpen = { id = 9120301474, volume = 0.5 },
	-- crossing the carriage door (Controllers/ThresholdController): a heavy door, muffled (ProSoundEffects
	-- "Door Bang Rattle 8", heavy double doors, Creator Store)
	DoorThud = { id = 9114129572, volume = 0.5, maxSeconds = 1.2, pitch = 0.78 },
	Alarm = { id = 9113085203, volume = 0.45, maxSeconds = 2.5 },
	Deposit = { id = 9113849492, volume = 0.6 },
	Loot = { id = 17208319162, volume = 0.6 },
	Heal = { id = 9114171855, volume = 0.6 },
	Hit = { id = 9113570506, volume = 0.8 },
	HollowSpawn = { id = 9125475729, volume = 0.9, spatial = true },
	HollowStrike = { id = 9125471724, volume = 0.9, spatial = true },
	Flash = { id = 9113024908, volume = 0.8, spatial = true },
	FlareLaunch = { id = 12222095, volume = 0.8, spatial = true, maxSeconds = 3 },
	FlareBurst = { id = 9114361763, volume = 0.7, spatial = true, maxSeconds = 3 },
	Toll = { id = 9113804436, volume = 0.35, maxSeconds = 4 },
	Eliminated = { id = 9126213744, volume = 0.7 },
	Rumble = { id = 9113218938, volume = 0.7, spatial = true, maxSeconds = 2.5 },
	Thunder = { id = 9113218938, volume = 0.55, maxSeconds = 4, pitch = 0.62 },
	Collapse = { id = 9118582680, volume = 0.9, spatial = true, maxSeconds = 3 },
	SteamLeak = { id = 9116496074, volume = 0.6, spatial = true, loop = true },
	Victory = { id = 9112766203, volume = 0.5, maxSeconds = 6 },
	Purchase = { id = 9113728042, volume = 0.6 },
	Clutch = { id = 9125573009, volume = 0.6, maxSeconds = 2 },
	Click = { id = 15675059323, volume = 0.4 },
	TicketStamp = { id = 15675059323, volume = 0.35, maxSeconds = 0.4, pitch = 0.6 }, -- the click, heavier
	TicketPunch = { id = 15675059323, volume = 0.6, maxSeconds = 0.5, pitch = 0.8 },

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
	TrainRun = { id = 9120247081, volume = 0.55, loop = true },
	Wind = { id = 9113286969, volume = 0.4, loop = true, mix = "Outdoor" },
	StationEerie = { id = 9125440141, volume = 0.35, loop = true, mix = "Outdoor" },
	DepotHall = { id = 9114872503, volume = 0.3, loop = true, mix = "Ambience" },
	-- Satie, Gnossienne No. 3 (APM Music), from the lobby piano (Builders/LobbyBuilder)
	LobbyPiano = { id = 1837474268, volume = 0.48, loop = true, spatial = true },

	-- The stops' soundscape: the same recordings slowed and shaped (AudioController
	-- adds the filters and reverb), so nothing new needs clearing.
	Drone = { id = 9113286969, volume = 0.38, loop = true, pitch = 0.32, mix = "Outdoor" }, -- wind, slowed to a moan
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
	Heartbeat = { id = 9113570506, volume = 0.65, maxSeconds = 1, pitch = 0.42 },
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
	HollowScream = { id = 9125475729, volume = 1, spatial = true, pitch = 1.3, maxSeconds = 2.2 },
	HollowWake = { id = 9125475729, volume = 0.85, spatial = true, pitch = 0.72, maxSeconds = 3 },
	HollowSwipe = { id = 9125471724, volume = 0.85, spatial = true, pitch = 1.35, maxSeconds = 1 },
	HollowSlam = { id = 9113218938, volume = 1, spatial = true, pitch = 0.8, maxSeconds = 2 },
	HollowScrabble = { id = 9118582680, volume = 0.55, spatial = true, pitch = 1.7, maxSeconds = 1.2 },
	HollowStep = { id = 9113218938, volume = 0.35, spatial = true, pitch = 1.6, maxSeconds = 0.5 },

	-- building interactions
	DoorForce = { id = 9118582680, volume = 0.75, spatial = true, pitch = 1.25, maxSeconds = 1.5 },
	Winded = { id = 9113570506, volume = 0.45, maxSeconds = 0.8, pitch = 0.5 },

	-- Footsteps by surface (Logic/Footsteps, Controllers/FootstepController): Creator Store
	-- uploads, free, chosen 2026-10-15 for audition (HANDOFF.md lists them with their sources).
	-- Two or three takes a surface; the controller picks one and nudges the pitch per step.
	StepPlank1 = { id = 136507037003210, volume = 0.5, spatial = true, rollOff = 70, maxSeconds = 0.8 },
	StepPlank2 = { id = 137526436035209, volume = 0.5, spatial = true, rollOff = 70, maxSeconds = 0.8 },
	-- the carriage floor: the same boards, lower, hollow over the underframe
	StepTrain1 = {
		id = 136507037003210,
		volume = 0.45,
		spatial = true,
		rollOff = 50,
		maxSeconds = 0.9,
		pitch = 0.8,
	},
	StepTrain2 = {
		id = 137526436035209,
		volume = 0.45,
		spatial = true,
		rollOff = 50,
		maxSeconds = 0.9,
		pitch = 0.76,
	},
	StepGravel1 = { id = 131788428206726, volume = 0.5, spatial = true, rollOff = 70, maxSeconds = 0.8 },
	StepGravel2 = { id = 132387836053582, volume = 0.5, spatial = true, rollOff = 70, maxSeconds = 0.8 },
	StepSnow1 = { id = 103816422099881, volume = 0.55, spatial = true, rollOff = 60, maxSeconds = 0.7 },
	StepSnow2 = { id = 135918121539048, volume = 0.55, spatial = true, rollOff = 60, maxSeconds = 0.7 },
	StepSnow3 = { id = 103079968724414, volume = 0.55, spatial = true, rollOff = 60, maxSeconds = 0.7 },
	-- heavy breathing while stamina is spent (MovementController.IsExhausted), not tied to combat
	Breath = { id = 100147087354736, volume = 0.5, loop = true },
}

for _, cue in Cues do
	table.freeze(cue)
end

return table.freeze(Cues)
