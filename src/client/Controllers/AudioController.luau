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
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Audio = require(Shared.Config.Audio)
local Tuning = require(Shared.Config.Tuning)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local MathX = require(Shared.Util.MathX)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)

local AudioController = {}

local group: SoundGroup
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
local HUSH_FLOOR = 0.08 -- what is left of every sound at the depth of the Hush

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
		equalize(sound, 4, -10, -40)
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
	Heartbeat = function(sound)
		equalize(sound, 6, -18, -45)
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
	sound.SoundGroup = group
	if cue.spatial then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = 220
	end
	local shape = SHAPES[cueName]
	if shape then
		shape(sound)
	end
	sound.Parent = parent
	return sound
end

-- A cue that repeats quickly (rail joints, heartbeats) plays from a few reused sounds.
local function pooled(cueName: string, gain: number)
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
		return
	end
	local sound = pool.sounds[pool.next]
	pool.next = pool.next % #pool.sounds + 1
	sound.Volume = Audio[cueName].volume * gain
	sound.TimePosition = 0
	sound:Play()
end

function AudioController.Init()
	group = Instance.new("SoundGroup")
	group.Name = "LastTrainOut"
	group.Volume = 1
	group.Parent = SoundService
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
	Registry.SceneryController.TunnelAhead:Connect(function()
		AudioController.Play("Whistle")
	end)
	local ambientReverb = Enum.ReverbType.NoReverb

	for _, name in { "TrainRun", "Wind", "StationEerie", "DepotHall", "Drone", "Howl" } do
		local sound = makeSound(name, SoundService)
		if sound then
			sound.Volume = 0
			sound:Play()
			beds[name] = sound
		end
	end

	local ambience = 0 -- 0..1: how much the stop's soundscape is playing
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
		group.Volume = 1 - (1 - HUSH_FLOOR) * hush

		local targets = {
			TrainRun = if inLobby then 0 else Audio.TrainRun.volume * pace * (1 + 0.35 * tunnel),
			Wind = if inLobby
				then 0
				else Audio.Wind.volume * (0.35 + 0.65 * pace) * (1 + 1.4 * bridge) * (1 - 0.6 * tunnel),
			StationEerie = if inLobby then 0 else Audio.StationEerie.volume * (0.3 + tension),
			DepotHall = if inLobby then Audio.DepotHall.volume else 0,
			-- the stop's drone, the night humming under the wheels, an omen swelling it
			Drone = Audio.Drone.volume
				* (math.max(ambience * (0.6 + 0.4 * tension), NIGHT_DRONE * night) + 0.6 * swell),
			Howl = Audio.Howl.volume * (ambience * (0.4 + 0.6 * tension) + 0.5 * swell),
		}
		for name, sound in beds do
			sound.Volume = MathX.lerp(sound.Volume, targets[name] or 0, MathX.damp(0.4, dt))
			if name == "TrainRun" then
				sound.PlaybackSpeed = 0.7 + 0.5 * pace
			elseif name == "Wind" then
				sound.PlaybackSpeed = 1 + 0.18 * bridge
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
		local nearest = if Registry.HollowAnimator then Registry.HollowAnimator.Nearest(focus) else math.huge
		local dread = if inLobby
			then 0
			else 1 - MathX.saturate((nearest - DREAD_NEAR) / (DREAD_FAR - DREAD_NEAR))
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
	local sound = makeSound(cueName, parent)
	if sound == nil then
		return
	end
	sound.Volume = cue.volume * (gain or 1)
	sound.PlaybackSpeed = (cue.pitch or 1) * (pitch or 1)
	sound:Play()
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

function AudioController.StopLoop(key: string)
	local sound = loops[key]
	if sound then
		sound:Destroy()
		loops[key] = nil
	end
end

return AudioController
