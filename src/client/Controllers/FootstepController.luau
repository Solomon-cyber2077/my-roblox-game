--!strict
--[[
	Footsteps and breath, client side.

	  footsteps  every crew member's steps, heard where they fall: what is under each one
	             is found by a ray down from the root, turned into a surface by
	             Logic/Footsteps (plank, gravel, the carriage floor, snow) and played as one
	             of that surface's takes, a step every stride at the speed they are moving
	  breath     the local player's heavy breathing while their stamina is spent
	             (MovementController.IsExhausted), swelling in and dying away; nothing to do
	             with being hurt or chased
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Audio = require(Shared.Config.Audio)
local Footsteps = require(Shared.Logic.Footsteps)
local Tuning = require(Shared.Config.Tuning)
local Safe = require(Shared.Util.Safe)

local Registry = require(script.Parent.Parent.Registry)
local StationSnow = require(script.Parent.Parent.Scenery.StationSnow)

local FootstepController = {}

type Walker = { nextAt: number, count: number }

local walkers: { [Model]: Walker } = {}
local deathBound: { [Model]: boolean } = {}
local deathWatch: { [Model]: RBXScriptConnection } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local snowy = false
local breath = 0 -- 0..1: how hard the local player is breathing

local function suppressDefaultDeathSound(instance: Instance)
	if not instance:IsA("Sound") then
		return
	end
	local name = string.lower(instance.Name)
	if name == "died" or name == "death" or name == "deathsound" then
		instance:Stop()
		instance.SoundId = ""
		instance.Volume = 0
	end
end

local function bindDeath(character: Model)
	if deathBound[character] then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	deathBound[character] = true
	for _, descendant in character:GetDescendants() do
		suppressDefaultDeathSound(descendant)
	end
	deathWatch[character] = character.DescendantAdded:Connect(suppressDefaultDeathSound)
	humanoid.Died:Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local position = if root then root.Position else nil
		local audio = Registry.AudioController
		if audio then
			audio.Play("Death", position)
		end
	end)
end

local function station(): Model?
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, 8) == "Station_" then
			return child
		end
	end
	return nil
end

local function step(character: Model, root: BasePart, humanoid: Humanoid, now: number)
	local walker = walkers[character]
	if walker == nil then
		walker = { nextAt = now, count = 0 }
		walkers[character] = walker
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local interval = Footsteps.interval(speed)
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if interval == nil or not grounded or humanoid.Sit or character:GetAttribute("GrabStyle") ~= nil then
		walker.nextAt = now + (Tuning.Footsteps.MinInterval :: number)
		return
	end
	if now < walker.nextAt then
		return
	end
	walker.nextAt = now + interval
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -6, 0), rayParams)
	if hit == nil then
		return
	end
	local train = Workspace:FindFirstChild("Train")
	local surface = Footsteps.surface({
		material = hit.Material.Name,
		onTrain = train ~= nil and hit.Instance:IsDescendantOf(train),
		slabKind = if hit.Instance.Name == "Top"
			then hit.Instance:GetAttribute("SlabKind") :: string?
			else nil,
		snowy = snowy,
	})
	walker.count += 1
	local T = Tuning.Footsteps
	local cue = Footsteps.cue(surface, walker.count)
	if Audio[cue] and Registry.AudioController then
		-- each crew member's boots (their crew slot); yours low-passed, a crewmate's out to CrewRollOff
		local player = Players:GetPlayerFromCharacter(character)
		local entry = if player
			then Registry.StateController.Get({ "crew", tostring(player.UserId) })
			else nil
		local boots = Footsteps.boots(if type(entry) == "table" then entry.slot else nil)
		local own = player == Players.LocalPlayer
		Registry.AudioController.Play(
			cue,
			hit.Position,
			boots.gain,
			boots.pitch * (1 + (math.random() * 2 - 1) * T.PitchJitter),
			if own then { muffle = T.OwnMuffle } else { rollOff = T.CrewRollOff }
		)
	end
end

local function breathe(dt: number)
	local controller = Registry.MovementController
	local exhausted = controller ~= nil and controller.IsExhausted()
	local fade = dt / Tuning.Footsteps.BreathFade
	breath = math.clamp(breath + (if exhausted then fade else -fade), 0, 1)
	local audio = Registry.AudioController
	if audio == nil then
		return
	end
	if breath > 0 then
		audio.Loop("breath", "Breath", SoundService)
		local sound = audio.LoopSound("breath")
		if sound then
			sound.Volume = Audio.Breath.volume * breath
		end
	else
		audio.StopLoop("breath")
	end
end

function FootstepController.Init() end

function FootstepController.Start()
	local lastScan = 0
	RunService.Heartbeat:Connect(function(dt: number)
		Safe.call("FootstepController", function()
			local now = os.clock()
			local characters: { Instance } = {}
			for _, player in Players:GetPlayers() do
				if player.Character then
					bindDeath(player.Character)
				end
				if player.Character then
					table.insert(characters, player.Character)
				end
			end
			if now - lastScan > 1 then
				lastScan = now
				local model = station()
				snowy = model ~= nil and StationSnow.snowy(string.sub(model.Name, 9))
				rayParams.FilterDescendantsInstances = characters
				for character in walkers do
					if character.Parent == nil then
						walkers[character] = nil
					end
				end
				for character, connection in deathWatch do
					if character.Parent == nil then
						connection:Disconnect()
						deathWatch[character] = nil
						deathBound[character] = nil
					end
				end
			end
			for _, character in characters do
				local model = character :: Model
				local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				bindDeath(model)
				if root and humanoid and humanoid.Health > 0 then
					step(model, root, humanoid, now)
				end
			end
			breathe(dt)
		end)
	end)
end

return FootstepController
