--!strict
--[[
	Footsteps and breath, client side.

	  footsteps  every crew member's steps, heard where they fall: what is under each one
	             is found by a ray down from the root, turned into a surface by
	             Logic/Footsteps (plank, gravel, the carriage floor, snow) and played as one
	             of that surface's takes, a step every stride at the speed they are moving
	  jumps      every crew member's jumps and landings, heard where they happen (airborne below)
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
local Foley = require(Shared.Config.Foley)
local Footsteps = require(Shared.Logic.Footsteps)
local Tuning = require(Shared.Config.Tuning)
local Safe = require(Shared.Util.Safe)

local Registry = require(script.Parent.Parent.Registry)
local StationSnow = require(script.Parent.Parent.Scenery.StationSnow)

local FootstepController = {}

-- aloft: off the ground last frame; fall: the fastest it came down since; jumpAt: its last jump sound
type Walker = { nextAt: number, count: number, aloft: boolean, fall: number, jumpAt: number }

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

local function walkerOf(character: Model, now: number): Walker
	local walker = walkers[character]
	if walker == nil then
		walker = { nextAt = now, count = 0, aloft = false, fall = 0, jumpAt = -math.huge }
		walkers[character] = walker
	end
	return walker
end

-- What is under a body: the ray's hit and the surface it makes (Logic/Footsteps), or nil.
local function underfoot(root: BasePart): (RaycastResult?, Footsteps.Surface)
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -6, 0), rayParams)
	if hit == nil then
		return nil, "Gravel"
	end
	local train = Workspace:FindFirstChild("Train")
	return hit,
		Footsteps.surface({
			material = hit.Material.Name,
			onTrain = train ~= nil and hit.Instance:IsDescendantOf(train),
			slabKind = if hit.Instance.Name == "Top"
				then hit.Instance:GetAttribute("SlabKind") :: string?
				else nil,
			snowy = snowy,
		})
end

-- Plays a body's cue where it happened: yours low-passed, a crewmate's out to CrewRollOff. Step
-- takes (`boots`) carry each crew member's boots (their crew slot) and the step jitter.
local function play(character: Model, cue: string, position: Vector3, gain: number, boots: boolean)
	local audio = Registry.AudioController
	if Audio[cue] == nil or audio == nil then
		return
	end
	local T = Tuning.Footsteps
	local player = Players:GetPlayerFromCharacter(character)
	local pitch = 1
	if boots then
		local entry = if player
			then Registry.StateController.Get({ "crew", tostring(player.UserId) })
			else nil
		local slot = Footsteps.boots(if type(entry) == "table" then entry.slot else nil)
		gain *= slot.gain
		pitch = slot.pitch * (1 + (math.random() * 2 - 1) * T.PitchJitter)
	end
	local own = player == Players.LocalPlayer
	audio.Play(
		cue,
		position,
		gain,
		pitch,
		if own then { muffle = T.OwnMuffle } else { rollOff = T.CrewRollOff }
	)
end

--[[
	Jumps and landings. Leaving the ground fast upward is a jump: a coat's whump at the feet.
	Coming down from a fall fast enough is a landing on the surface's own takes, both feet, with a
	thud when it was hard (Logic/Footsteps.landing, Config/Foley). Seats, holds and anchored
	bodies are neither, and a landing holds off the next footstep so the two never stack.
]]
local function airborne(character: Model, root: BasePart, humanoid: Humanoid, now: number)
	local walker = walkerOf(character, now)
	if humanoid.Sit or root.Anchored or character:GetAttribute("GrabStyle") ~= nil then
		walker.aloft = false
		walker.fall = 0
		return
	end
	local rise = root.AssemblyLinearVelocity.Y
	if humanoid.FloorMaterial == Enum.Material.Air then
		if not walker.aloft then
			walker.aloft = true
			walker.fall = 0
			if Footsteps.jumped(rise, now - walker.jumpAt) then
				walker.jumpAt = now
				play(character, "Jump", root.Position - Vector3.new(0, 2.5, 0), 1, false)
			end
		end
		walker.fall = math.max(walker.fall, -rise)
		return
	end
	if not walker.aloft then
		return
	end
	walker.aloft = false
	local landing = Footsteps.landing(walker.fall)
	walker.fall = 0
	if landing == nil then
		return
	end
	local hit, surface = underfoot(root)
	if hit == nil then
		return
	end
	local where = hit.Position
	local first = Footsteps.cue(surface, walker.count + 1)
	local second = Footsteps.cue(surface, walker.count + 2)
	walker.count += 2
	walker.nextAt = now + (Tuning.Footsteps.MinInterval :: number)
	play(character, first, where, landing.gain, true)
	task.delay(Foley.LandFootGap, function()
		play(character, second, where, landing.gain * 0.85, true)
	end)
	if landing.kind == "Hard" then
		play(character, "LandHard", where, 1, false)
	end
end

local function step(character: Model, root: BasePart, humanoid: Humanoid, now: number)
	local walker = walkerOf(character, now)
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local interval = Footsteps.interval(speed)
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if interval == nil or not grounded or humanoid.Sit or character:GetAttribute("GrabStyle") ~= nil then
		walker.nextAt = math.max(walker.nextAt, now + (Tuning.Footsteps.MinInterval :: number))
		return
	end
	if now < walker.nextAt then
		return
	end
	walker.nextAt = now + interval
	local hit, surface = underfoot(root)
	if hit == nil then
		return
	end
	walker.count += 1
	play(character, Footsteps.cue(surface, walker.count), hit.Position, 1, true)
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
					airborne(model, root, humanoid, now)
					step(model, root, humanoid, now)
				end
			end
			breathe(dt)
		end)
	end)
end

return FootstepController
