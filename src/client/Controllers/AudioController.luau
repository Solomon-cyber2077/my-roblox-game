--!strict
--[[
	Plays cues from Config/Audio. One-shots are pooled per cue; spatial cues are
	parented to a throwaway attachment at the world position. Beds (train run,
	wind, station eeriness, the hall) are mixed every frame from game state:
	train speed drives the chug and the wind, the station's hazard intensity
	drives the eerie bed, and the hall bed plays only in the Depot.

	The landscape shapes the mix too: inside a tunnel the world takes a hallway
	reverb and the wheels get louder, the whistle blows as the locomotive nears
	a portal, the wind rises and brightens on gorge bridges, and the rail joints
	clack under the wheels (every rail length, the second bogie just after).

	Stops get a soundscape of their own, built from the same recordings slowed
	and filtered: a low drone and slow gusts that swell with the station's hazard,
	a bell or a cry far off in a random direction every few seconds, and, when a
	Hollow comes close, a heartbeat that quickens as it nears (and the camera
	throbs with it).

	The night follows the train between stops: deep in it the drone hums under the
	wheels and something calls from far out across the fields now and then.

	The sky's omens (Logic/Omens, via AtmosphereController) have their own sounds,
	heard by the whole crew at once: a bell the size of the sky as the moon blinks,
	the sky groaning as it bleeds, a slow pulse while the Eye is open, and the Hush,
	when every sound drains away and comes back on a single far-off toll.

	The mix follows Config/AudioPriority: Warnings above Threat above Feedback above Ambience above
	the lobby piano, each tier's groups ducked by every tier above (sidechain compressors), with a
	cap on one-shots per lower tier. A Hollow's replicated Intent hushes the ambience and steps for
	0.4 s (IntentHush; SoundService attribute IntentHushAt marks each one for Studio checks).
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Audio = require(Shared.Config.Audio)
local AudioPriority = require(Shared.Config.AudioPriority)
local SettingsConfig = require(Shared.Config.Settings)
local Tuning = require(Shared.Config.Tuning)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local MathX = require(Shared.Util.MathX)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)

local AudioController = {}

local group: SoundGroup
local mixes: { [string]: SoundGroup } = {} -- Config/Audio's `mix`: Ambience, and Outdoor inside it
local walls: EqualizerSoundEffect -- the carriage walls, on the Outdoor group
local groups: { [string]: SoundGroup } = {}
local duckUntil = 0
local hushUntil = 0 -- the Intent hush (Config/AudioPriority.IntentHush)
local tierOf: { [string]: number } = {} -- SoundGroup name -> its priority tier
local voices: { [number]: number } = {} -- one-shots playing per tier
local anchorPart: Part
local beds: { [string]: Sound } = {}
local loops: { [string]: Sound } = {}
local pools: { [string]: { sounds: { Sound }, next: number } } = {}

local STOP_PHASES: { [string]: boolean } = { Dwell = true, LastCall = true, Departure = true }
local DISTANT_EVERY = { 3.5, 8 } -- seconds between far-off sounds at a stop
local DISTANT_RANGE = { 60, 110 } -- studs away
local NIGHT_EVERY = { 9, 20 } -- between far-off calls on the line, deep in the night
local NIGHT_RANGE = { 80, 170 } -- studs: spatial cues fall silent past 220, and the wheels are loud
local NIGHT_DRONE = 0.45 -- share of the drone that hums under the wheels at the darkest hour
local DREAD_NEAR, DREAD_FAR = 10, 75 -- heartbeat: full at this distance from a Hollow, silent past that one
-- the drone's danger (the stop's hazard or a Hollow near): it swells quickly, ebbs slowly once
-- they leave (half-lives), and breathes on slow, unrelated cycles so it never sits still
local DANGER_RISE, DANGER_FALL = 0.6, 3.5
local DRONE_SWAY = { body = 9.5, harmonic = 6.3, pitch = 17 } -- seconds per cycle
local DRONE_DEPTH = { body = 0.2, harmonic = 0.3, pitch = 0.012 }
local HUSH_FLOOR = 0.08 -- what is left of every sound at the depth of the Hush
-- Aboard at a stop or on the line, the carriage walls stand between you and the night: the
-- moment you step in (Controllers/ThresholdController) the whole Outdoor group loses its top
-- end and the outside beds drop, and the depot hall's room tone (the lobby's own sound) rises,
-- so the train sounds like the same warm shelter as the hall.
local OUTSIDE: { [string]: boolean } =
	{ Wind = true, StationEerie = true, Drone = true, DroneHarmonic = true, Howl = true }
local SHELTER_DIP = 0.45 -- share of the outside beds the walls take away
local SHELTER_HIGH, SHELTER_MID = -30, -10 -- dB the walls take off the Outdoor group's highs and mids
local SHELTER_ROOM = 0.5 -- share of the hall's room tone heard aboard

local LOBBY =
	Vector3.new(Tuning.World.LobbyOrigin[1], Tuning.World.LobbyOrigin[2], Tuning.World.LobbyOrigin[3])

-- Filters and reverb, to shape a recording into something it was not.
local function equalize(sound: Sound, low: number, mid: number, high: number)
	local effect = Instance.new("EqualizerSoundEffect")
	effect.LowGain = low
	effect.MidGain = mid
	effect.HighGain = high
	effect.Parent = sound
end

local function reverb(sound: Sound, decay: number, wet: number, dry: number)
	local effect = Instance.new("ReverbSoundEffect")
	effect.DecayTime = decay
	effect.Density = 1
	effect.Diffusion = 1
	effect.WetLevel = wet
	effect.DryLevel = dry
	effect.Parent = sound
end

local function tremolo(sound: Sound, frequency: number, depth: number)
	local effect = Instance.new("TremoloSoundEffect")
	effect.Frequency = frequency
	effect.Depth = depth
	effect.Duty = 0.5
	effect.Parent = sound
end

local SHAPES: { [string]: (Sound) -> () } = {
	Drone = function(sound)
		equalize(sound, 0, -4, -24) -- no sub boost: the body sits at 60-120 Hz
		reverb(sound, 7, -4, -8)
	end,
	DroneHarmonic = function(sound)
		equalize(sound, -8, 0, -20)
		reverb(sound, 7, -4, -8)
	end,
	Howl = function(sound)
		tremolo(sound, 0.18, 0.75)
		equalize(sound, -2, -4, -18)
		reverb(sound, 5, -6, -6)
	end,
	DistantBell = function(sound)
		equalize(sound, 0, -2, -14)
		reverb(sound, 8, -2, -14)
	end,
	DistantCry = function(sound)
		equalize(sound, 0, -6, -20)
		reverb(sound, 6, -2, -12)
	end,
	TicketPunch = function(sound)
		equalize(sound, 4, -2, -10) -- a stamp's weight, not a slap
	end,
	DoorThud = function(sound)
		equalize(sound, 5, -9, -32)
	end,
	Heartbeat = function(sound)
		equalize(sound, 6, -18, -45)
	end,
	FogWhisper = function(sound)
		tremolo(sound, 0.55, 0.7)
		equalize(sound, -6, -2, -14)
		reverb(sound, 9, -2, -10)
	end,
	RailClack = function(sound)
		equalize(sound, 3, -4, -24)
	end,
	SkyToll = function(sound)
		equalize(sound, 4, -2, -22)
		reverb(sound, 12, 0, -10)
	end,
	SkyGroan = function(sound)
		equalize(sound, 6, -6, -32)
		reverb(sound, 9, -2, -8)
	end,
	SkyHeart = function(sound)
		equalize(sound, 9, -16, -45)
		reverb(sound, 4, -6, -4)
	end,
}

-- A SoundGroup of a cue's own, beside the main one, so ducking the mix leaves it alone.
local function ownGroup(name: string): SoundGroup
	local own: SoundGroup? = groups[name]
	if own then
		return own
	end
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Volume = 1
	made.Parent = SoundService
	groups[name] = made
	return made
end

local function makeSound(cueName: string, parent: Instance): Sound?
	local cue = Audio[cueName]
	if cue == nil then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = cueName
	sound.SoundId = `rbxassetid://{cue.id}`
	sound.Volume = cue.volume
	sound.Looped = cue.loop == true
	sound.PlaybackSpeed = cue.pitch or 1
	sound.SoundGroup = if cue.mix then mixes[cue.mix] or group else group
	if cue.group then
		sound.SoundGroup = ownGroup(cue.group)
	end
	if cue.spatial then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = cue.rollOff or 220
	end
	local shape = SHAPES[cueName]
	if shape then
		shape(sound)
	end
	sound.Parent = parent
	return sound
end

-- A cue that repeats quickly (rail joints, heartbeats) plays from a few reused sounds.
local function pooled(cueName: string, gain: number): Sound?
	local pool = pools[cueName]
	if pool == nil then
		pool = { sounds = {}, next = 1 }
		for _ = 1, 4 do
			local sound = makeSound(cueName, SoundService)
			if sound then
				table.insert(pool.sounds, sound)
			end
		end
		pools[cueName] = pool
	end
	if #pool.sounds == 0 then
		return nil
	end
	local sound = pool.sounds[pool.next]
	pool.next = pool.next % #pool.sounds + 1
	sound.Volume = Audio[cueName].volume * gain
	sound.TimePosition = 0
	sound:Play()
	return sound
end

function AudioController.Init()
	group = Instance.new("SoundGroup")
	group.Name = "LastTrainOut"
	group.Volume = 1
	group.Parent = SoundService
	-- the mix: Ambience under the main group, Outdoor inside Ambience, each scaling the one above
	local ambience = Instance.new("SoundGroup")
	ambience.Name = "Ambience"
	ambience.Volume = 1
	ambience.Parent = group
	mixes.Ambience = ambience
	local outdoor = Instance.new("SoundGroup")
	outdoor.Name = "Outdoor"
	outdoor.Volume = 1
	outdoor.Parent = ambience
	mixes.Outdoor = outdoor
	walls = Instance.new("EqualizerSoundEffect")
	walls.Name = "Walls"
	walls.LowGain, walls.MidGain, walls.HighGain = 0, 0, 0
	walls.Parent = outdoor
	-- the other tiers' groups, under the main group (so the Hush still drains them); Warnings is a
	-- group of its own beside the main one, so the Hush and the departure dip leave it alone
	for _, name in { "Cues", "Steps", "Feedback", "Piano" } do
		local made = Instance.new("SoundGroup")
		made.Name = name
		made.Volume = 1
		made.Parent = group
		mixes[name] = made
	end
	-- higher ducks lower: one compressor per (lower group, higher group) pair (Config/AudioPriority)
	local tiers = AudioPriority.Tiers
	for rank, tier in tiers do
		for _, name in tier.groups do
			tierOf[name] = rank
		end
	end
	for rank, tier in tiers do
		for _, name in tier.groups do
			local target = mixes[name] or ownGroup(name)
			for higher = 1, rank - 1 do
				local above = tiers[higher]
				for _, key in above.groups do
					local compressor = Instance.new("CompressorSoundEffect")
					compressor.Name = `Duck{key}`
					compressor.SideChain = mixes[key] or ownGroup(key)
					compressor.Threshold = above.duck.threshold
					compressor.Ratio = above.duck.ratio
					compressor.Attack = 0.005
					compressor.Release = above.duck.release
					compressor.Parent = target
				end
			end
		end
	end
	anchorPart = Instance.new("Part")
	anchorPart.Name = "AudioAnchor"
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.CanTouch = false
	anchorPart.Transparency = 1
	anchorPart.Size = Vector3.one
	anchorPart.CFrame = CFrame.new(0, -1000, 0)
	anchorPart.Parent = Workspace
end

function AudioController.Start()
	-- the buttons' key, loaded up front so the first press is as quick as the rest
	pooled("MenuClick", 0)
	local tap = pools.MenuClick
	if tap then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(tap.sounds)
			end)
		end)
	end
	Registry.SceneryController.TunnelAhead:Connect(function()
		AudioController.Play("Whistle")
	end)
	local ambientReverb = Enum.ReverbType.NoReverb
	-- the carriage door, heard through the walls as you cross it either way
	Registry.ThresholdController.Crossed:Connect(function(inside: boolean)
		AudioController.Play("DoorThud", nil, if inside then 1 else 0.8, if inside then 1 else 1.06)
	end)

	for _, name in { "TrainRun", "Wind", "StationEerie", "DepotHall", "Drone", "DroneHarmonic", "Howl" } do
		local sound = makeSound(name, SoundService)
		if sound then
			sound.Volume = 0
			sound:Play()
			beds[name] = sound
		end
	end

	local ambience = 0 -- 0..1: how much the stop's soundscape is playing
	local danger = 0 -- 0..1: the drone's danger, eased
	local night = 0 -- 0..1: how much of the night layer is playing on the line
	local nextDistant = 0
	local nextNight = 0
	local nextBeat = 0
	local railJoint = 0
	local omenHeard = -1 -- start of the omen whose sounds are under way
	local eyeBeat = -1

	-- An omen's sounds, timed from its start in server time so every client hears them together.
	local function omenCue(omen: any, share: number, cue: string, gain: number, pitch: number?)
		task.delay(math.max(omen.start + share * omen.duration - Session.now(), 0), function()
			AudioController.Play(cue, nil, gain, pitch)
		end)
	end
	local function heraldOmen(omen: any)
		if omen.kind == "Blink" then
			omenCue(omen, 0.22, "SkyToll", 1)
		elseif omen.kind == "Bleed" then
			omenCue(omen, 0, "SkyGroan", 1)
			omenCue(omen, 0.62, "SkyGroan", 0.6, 0.85)
		elseif omen.kind == "TallOnes" then
			omenCue(omen, 0.5, "SkyGroan", 0.7, 1.1)
		elseif omen.kind == "Eye" then
			omenCue(omen, 0, "SkyGroan", 0.5, 0.8)
		elseif omen.kind == "Hush" then
			omenCue(omen, 1.02, "SkyToll", 0.8, 0.9)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local speed = if Registry.SceneryController then Registry.SceneryController.Speed() else 0
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local focus = if root then root.Position else Workspace.CurrentCamera.CFrame.Position
		local inLobby = (focus - LOBBY).Magnitude < 420
		local phase = Session.phase()
		local station = Registry.StateController.Get({ "run", "station" })
		local tension = 0
		if station and (phase == "Dwell" or phase == "LastCall" or phase == "Departure") then
			tension = HazardSchedule.intensity(station.hazards, Session.now() - station.startedAt)
		end
		local context = Registry.SceneryController.Context()
		local tunnel = if inLobby then 0 else context.tunnel
		local bridge = if inLobby then 0 else context.bridge
		local wantReverb = if tunnel > 0.4 then Enum.ReverbType.Hallway else Enum.ReverbType.NoReverb
		if wantReverb ~= ambientReverb then
			ambientReverb = wantReverb
			SoundService.AmbientReverb = ambientReverb
		end
		local pace = math.min(speed / Tuning.Motion.CruiseSpeed, 1)
		local atStop = not inLobby and STOP_PHASES[phase] == true and station ~= nil
		ambience = MathX.lerp(ambience, if atStop then 1 else 0, MathX.damp(if atStop then 2 else 4, dt))
		local atmosphere = Registry.AtmosphereController
		local dark = if atmosphere then atmosphere.Dark() else 0
		local riding = not inLobby and not atStop and Session.isRunActive()
		-- 0..1 the carriage walls between you and the outside: shut at once on boarding, open
		-- with the station crossfade on the way out (Logic/Threshold)
		local threshold = Registry.ThresholdController
		local shelter = if not inLobby and Session.isRunActive() and threshold then threshold.Shelter() else 0
		night = MathX.lerp(night, if riding then dark else 0, MathX.damp(1.5, dt))

		-- the sky's omens
		local now = Session.now()
		local omen = if atmosphere and not inLobby then atmosphere.Omen() else nil
		local hush, swell = 0, 0
		if omen then
			if omen.start ~= omenHeard then
				omenHeard = omen.start
				heraldOmen(omen)
			end
			local p = omen.progress
			if omen.kind == "Hush" then
				hush = MathX.smoothstep(0, 0.15, p) * (1 - MathX.smoothstep(0.8, 1, p))
			elseif omen.kind == "Eye" then
				-- a slow pulse in step with the moon's throb, and the camera feels it
				swell = MathX.smoothstep(0, 0.2, p) * (1 - MathX.smoothstep(0.8, 1, p))
				-- on the throb's crest (Scenery/Sky: 0.5 + 0.5 sin(2.2 pi t) peaks at 1.1 t = k + 0.25)
				local beat = math.floor(now * 1.1 - 0.25)
				if beat ~= eyeBeat and swell > 0.3 then
					eyeBeat = beat
					AudioController.Play("SkyHeart", nil, swell)
					if Registry.CameraController then
						Registry.CameraController.Pulse(0.6 * swell)
					end
				end
			elseif omen.kind == "Bleed" then
				swell = MathX.smoothstep(0, 0.3, p) * (1 - MathX.smoothstep(0.7, 1, p))
			end
		end
		-- how near the nearest Hollow is (the heartbeat and the drone)
		local nearest = if Registry.HollowAnimator then Registry.HollowAnimator.Nearest(focus) else math.huge
		local dread = if inLobby
			then 0
			else 1 - MathX.saturate((nearest - DREAD_NEAR) / (DREAD_FAR - DREAD_NEAR))
		local wantDanger = math.max(tension, dread)
		danger = MathX.lerp(
			danger,
			wantDanger,
			MathX.damp(if wantDanger > danger then DANGER_RISE else DANGER_FALL, dt)
		)
		local cycle = os.clock() * 2 * math.pi
		local sway = 1 + DRONE_DEPTH.body * math.sin(cycle / DRONE_SWAY.body)
		local swayHigh = 1 + DRONE_DEPTH.harmonic * math.sin(cycle / DRONE_SWAY.harmonic + 1.7)
		local drift = 1 + DRONE_DEPTH.pitch * math.sin(cycle / DRONE_SWAY.pitch)

		-- the Settings drone and ambience volume
		local level = SettingsConfig.AmbienceLevels[Players.LocalPlayer:GetAttribute("Ambience") :: any]
		mixes.Ambience.Volume = if type(level) == "number" then level else 1

		local duck = if os.clock() < duckUntil then 1 - Tuning.Departure.DuckShare else 1
		group.Volume = (1 - (1 - HUSH_FLOOR) * hush) * duck
		-- the Intent hush: ambience and steps dip for its 0.4 s (warnings and threat untouched)
		local intent = AudioPriority.IntentHush
		local hushing = os.clock() < hushUntil
		mixes.Ambience.Volume *= if hushing then intent.Ambience else 1
		mixes.Steps.Volume = if hushing then intent.Steps else 1

		local targets: { [string]: number } = {
			TrainRun = if inLobby then 0 else Audio.TrainRun.volume * pace * (1 + 0.35 * tunnel),
			Wind = if inLobby
				then 0
				else Audio.Wind.volume * (0.35 + 0.65 * pace) * (1 + 1.4 * bridge) * (1 - 0.6 * tunnel),
			StationEerie = if inLobby then 0 else Audio.StationEerie.volume * (0.3 + tension),
			DepotHall = Audio.DepotHall.volume * (if inLobby then 1 else SHELTER_ROOM * shelter),
			-- the stop's drone, rising with danger; the night humming under the wheels, an omen swelling it
			Drone = Audio.Drone.volume
				* (math.max(ambience * (0.3 + 0.7 * danger), NIGHT_DRONE * night) + 0.6 * swell)
				* sway,
			DroneHarmonic = Audio.DroneHarmonic.volume
				* (math.max(ambience * (0.4 + 0.6 * danger), NIGHT_DRONE * night) + 0.4 * swell)
				* swayHigh,
			Howl = Audio.Howl.volume * (ambience * (0.4 + 0.6 * tension) + 0.5 * swell),
		}
		walls.MidGain = SHELTER_MID * shelter
		walls.HighGain = SHELTER_HIGH * shelter
		for name in OUTSIDE do
			targets[name] = (targets[name] or 0) * (1 - SHELTER_DIP * shelter)
		end
		for name, sound in beds do
			sound.Volume = MathX.lerp(sound.Volume, targets[name] or 0, MathX.damp(0.4, dt))
			if name == "TrainRun" then
				sound.PlaybackSpeed = 0.7 + 0.5 * pace
			elseif name == "Wind" then
				sound.PlaybackSpeed = 1 + 0.18 * bridge
			elseif name == "Drone" or name == "DroneHarmonic" then
				sound.PlaybackSpeed = (Audio[name].pitch or 1) * drift -- the harmonic stays locked to the body
			end
		end

		local clock = os.clock()
		-- far off, somewhere out in the dark
		if ambience > 0.5 and clock >= nextDistant then
			if nextDistant > 0 then
				local angle = math.random() * math.pi * 2
				local away = DISTANT_RANGE[1] + math.random() * (DISTANT_RANGE[2] - DISTANT_RANGE[1])
				local at = focus
					+ Vector3.new(math.cos(angle) * away, 8 + math.random() * 10, math.sin(angle) * away)
				local cue = if math.random() < 0.65 then "DistantBell" else "DistantCry"
				AudioController.Play(cue, at, 0.8 + 0.4 * math.random(), 0.9 + 0.2 * math.random())
			end
			nextDistant = clock + DISTANT_EVERY[1] + math.random() * (DISTANT_EVERY[2] - DISTANT_EVERY[1])
		elseif ambience <= 0.5 then
			nextDistant = 0
		end

		-- deep in the night, something calls from far out across the fields
		if night > 0.3 and clock >= nextNight then
			if nextNight > 0 then
				local angle = math.random() * math.pi * 2
				local away = NIGHT_RANGE[1] + math.random() * (NIGHT_RANGE[2] - NIGHT_RANGE[1])
				local spot = focus + Vector3.new(math.cos(angle) * away, 20, math.sin(angle) * away)
				local cue = if math.random() < 0.6 then "DistantCry" else "DistantBell"
				AudioController.Play(cue, spot, 1.3 + 0.5 * math.random(), 0.75 + 0.2 * math.random())
			end
			local wait = NIGHT_EVERY[1] + math.random() * (NIGHT_EVERY[2] - NIGHT_EVERY[1])
			nextNight = clock + wait * (1.6 - night)
		elseif night <= 0.3 then
			nextNight = 0
		end

		-- a heartbeat when a Hollow is near, lub and dub, faster the nearer it is; past
		-- halfway the camera throbs with it
		if dread > 0.12 and clock >= nextBeat then
			pooled("Heartbeat", dread)
			task.delay(0.22, pooled, "Heartbeat", 0.7 * dread)
			if dread > 0.45 and Registry.CameraController then
				Registry.CameraController.Pulse(0.7 * dread)
			end
			nextBeat = clock + 60 / (64 + 80 * dread)
		end

		-- rail joints under the wheels, the second bogie just after
		local joint = math.floor(Registry.SceneryController.Odometer() / Tuning.Camera.RailLength)
		if joint ~= railJoint then
			railJoint = joint
			if not inLobby and speed > 8 then
				local gain = pace * (1 + 0.5 * tunnel)
				pooled("RailClack", gain)
				task.delay(Tuning.Camera.BogieGap / speed, pooled, "RailClack", 0.8 * gain)
			end
		end
	end)
end

-- Plays a one-shot cue, at a world position when the cue is spatial, optionally louder or
-- softer (gain) and higher or lower (pitch, a multiple of the cue's own).
function AudioController.Play(cueName: string, position: Vector3?, gain: number?, pitch: number?)
	local cue = Audio[cueName]
	if cue == nil then
		return
	end
	local parent: Instance = SoundService
	local holder: Attachment? = nil
	if cue.spatial and position then
		holder = Instance.new("Attachment");
		(holder :: Attachment).WorldPosition = position;
		(holder :: Attachment).Parent = anchorPart
		parent = holder :: Attachment
	end
	-- a lower tier past its cap drops the cue; warnings and threat never drop
	local rank = tierOf[cue.group or cue.mix or ""]
	local cap = if rank then AudioPriority.Tiers[rank].voices else 0
	if rank and cap > 0 and (voices[rank] or 0) >= cap then
		if holder then
			holder:Destroy()
		end
		return
	end
	local sound = makeSound(cueName, parent)
	if sound == nil then
		return
	end
	sound.Volume = cue.volume * (gain or 1)
	sound.PlaybackSpeed = (cue.pitch or 1) * (pitch or 1)
	sound:Play()
	if rank then
		local tier: number = rank
		local counted = true
		local function release()
			if counted then
				counted = false
				voices[tier] = math.max((voices[tier] or 1) - 1, 0)
			end
		end
		voices[tier] = (voices[tier] or 0) + 1
		sound.Ended:Once(release)
		sound.Destroying:Once(release)
	end
	if cue.with then
		AudioController.Play(cue.with, position, gain)
	end
	local lifetime = cue.maxSeconds or 12
	task.delay(lifetime, function()
		if cue.maxSeconds and sound.IsPlaying then
			local fade = sound.Volume
			for i = 1, 10 do
				sound.Volume = fade * (1 - i / 10)
				task.wait(0.03)
			end
		end
		sound:Destroy()
		if holder then
			holder:Destroy()
		end
	end)
end

-- A UI tap (a button's key): from a pool loaded at Start, so it sounds the instant it is asked
-- for, rather than after a new Sound's asset has loaded.
function AudioController.Tap(cueName: string)
	local sound = pooled(cueName, 1)
	local cut = Audio[cueName].maxSeconds
	if sound and cut then
		task.delay(cut, function()
			-- stop only this press's take: a quicker press may already have restarted the sound
			if sound.IsPlaying and sound.TimePosition >= cut * 0.5 then
				sound:Stop()
			end
		end)
	end
end

-- The SoundGroup of a mix ("Cues", "Steps", ...), for sounds made elsewhere (a Hollow's breath).
function AudioController.Group(mix: string): SoundGroup?
	return mixes[mix]
end

-- A Hollow's Intent turned on (HollowAnimator): the 0.4 s predictive hush of ambience and steps.
function AudioController.IntentHush()
	hushUntil = os.clock() + AudioPriority.IntentHush.Seconds
	SoundService:SetAttribute("IntentHushAt", os.clock())
end

-- Dips the main mix (not cues with a group of their own) for a moment, under a bell or a whistle.
function AudioController.Duck(seconds: number)
	duckUntil = math.max(duckUntil, os.clock() + seconds)
end

-- Starts a keyed loop attached to a part (machinery, leaks). Stop it with StopLoop.
function AudioController.Loop(key: string, cueName: string, parent: Instance)
	if loops[key] then
		return
	end
	local sound = makeSound(cueName, parent)
	if sound then
		sound.Looped = true
		sound:Play()
		loops[key] = sound
	end
end

-- The Sound of a running loop, to shape it (a leak's hiss grows louder and carries further).
function AudioController.LoopSound(key: string): Sound?
	return loops[key]
end

function AudioController.StopLoop(key: string)
	local sound = loops[key]
	if sound then
		sound:Destroy()
		loops[key] = nil
	end
end

return AudioController
