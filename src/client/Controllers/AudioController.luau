--!strict
--[[
	Plays cues from Config/Audio. One-shots are pooled per cue; spatial cues are
	parented to a throwaway attachment at the world position. Beds (train run,
	wind, station eeriness, the hall) are mixed every frame from game state:
	train speed drives the chug and the wind, the station's hazard intensity
	drives the eerie bed, and the hall bed plays only in the Depot.
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

local LOBBY =
	Vector3.new(Tuning.World.LobbyOrigin[1], Tuning.World.LobbyOrigin[2], Tuning.World.LobbyOrigin[3])

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
	sound.Parent = parent
	return sound
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
	for _, name in { "TrainRun", "Wind", "StationEerie", "DepotHall" } do
		local sound = makeSound(name, SoundService)
		if sound then
			sound.Volume = 0
			sound:Play()
			beds[name] = sound
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
		local targets = {
			TrainRun = if inLobby
				then 0
				else Audio.TrainRun.volume * math.min(speed / Tuning.Motion.CruiseSpeed, 1),
			Wind = if inLobby
				then 0
				else Audio.Wind.volume * (0.35 + 0.65 * math.min(speed / Tuning.Motion.CruiseSpeed, 1)),
			StationEerie = if inLobby then 0 else Audio.StationEerie.volume * (0.3 + tension),
			DepotHall = if inLobby then Audio.DepotHall.volume else 0,
		}
		for name, sound in beds do
			sound.Volume = MathX.lerp(sound.Volume, targets[name] or 0, MathX.damp(0.4, dt))
			if name == "TrainRun" then
				sound.PlaybackSpeed = 0.7 + 0.5 * math.min(speed / Tuning.Motion.CruiseSpeed, 1)
			end
		end
	end)
end

-- Plays a one-shot cue, at a world position when the cue is spatial.
function AudioController.Play(cueName: string, position: Vector3?)
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
