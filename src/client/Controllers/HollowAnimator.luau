--!strict
--[[
	Procedural animation for the Hollows. Every client writes each joint's
	Motor6D.Transform from the creature's state (the State, StateAt, Emerge and Grab
	attributes the server sets) and its velocity; Animation/HollowPoses does the body
	math. No animation assets.

	  Stalker  a limp when it prowls (one leg strides, the other drags), head lolling;
	           on the hunt it pitches forward and runs with its arms flung back
	  Crawler  a spider's walk on planted hands and feet, elbows and knees high over its
	           back; it rears like a mantis, then pounces
	  Brute    a heavy, rolling stomp that shakes the ground

	Spawning is a show too: Hollows claw up out of the ground, haul themselves over the
	station's edge out of the dark, or wake in jerks from a slump in a building. A strike
	that lands is a grab (Config/Grabs): the Hollow holds its victim in one of three ways
	and squeezes, bites or yanks on the grab's rhythm. Heads twitch at random, held for a
	beat and released. Poses are smoothed so a state change never pops, and the effects
	(dust, trails, sounds, shockwaves, the Brute's embers) hang off state changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Grabs = require(Shared.Config.Grabs)
local Tuning = require(Shared.Config.Tuning)
local Safe = require(Shared.Util.Safe)
local GrimeLevel = require(Shared.Logic.GrimeLevel)

local Registry = require(script.Parent.Parent.Registry)
local HollowPoses = require(script.Parent.Parent.Animation.HollowPoses)
local HollowCosmetics = require(script.Parent.Parent.Visual.HollowCosmetics)
local cosmetics: { [Model]: HollowCosmetics.Handle } = {}

type Pose = HollowPoses.Pose

type Rig = {
	model: Model,
	root: BasePart,
	kind: string,
	skeleton: HollowPoses.Rig,
	motors: { [string]: Motor6D },
	pose: Pose,
	phase: number,
	seed: number,
	state: string,
	stateAt: number,
	emerge: string,
	twitch: CFrame,
	twitchUntil: number,
	twitchNext: number,
	trails: { Trail },
	stepSide: number,
	slammed: boolean,
	lungeAt: number,
	bites: number, -- bites of the current hold already sounded
	embers: PointLight?,
}

local HollowAnimator = {}

local H = Tuning.Hollow
local I = CFrame.identity
local rigs: { [Model]: Rig } = {}
local fxFolder: Folder

local function A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(x, y, z)
end

-- Effects ---------------------------------------------------------------------------------

local function audio(cue: string, position: Vector3, gain: number?, pitch: number?)
	if Registry.AudioController then
		Registry.AudioController.Play(cue, position, gain, pitch)
	end
end

local function shakeNear(position: Vector3, radius: number, amount: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and Registry.CameraController then
		local distance = (root.Position - position).Magnitude
		if distance < radius then
			Registry.CameraController.Shake(amount * (1 - distance / radius))
		end
	end
end

local function burst(position: Vector3, color: Color3, count: number, speed: number, size: number, up: number)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(3, 0.2, 3)
	part.CFrame = CFrame.new(position)
	part.Parent = fxFolder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, up, 0)
	emitter.Drag = 2
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Rate = 0
	emitter.Parent = part
	local debris = emitter:Clone()
	debris.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	debris.Color = ColorSequence.new(Color3.fromRGB(40, 34, 30))
	debris.Size = NumberSequence.new(0.25)
	debris.Transparency = NumberSequence.new(0)
	debris.Acceleration = Vector3.new(0, -50, 0)
	debris.Speed = NumberRange.new(speed, speed * 1.8)
	debris.Lifetime = NumberRange.new(0.5, 0.9)
	debris.Parent = part
	emitter:Emit(count)
	debris:Emit(math.floor(count * 0.6))
	task.delay(2.5, function()
		part:Destroy()
	end)
end

local function shockwave(position: Vector3)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Color3.fromRGB(70, 60, 52)
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = fxFolder
	TweenService:Create(
		ring,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.3, 26, 26), Transparency = 1 }
	):Play()
	task.delay(0.5, function()
		ring:Destroy()
	end)
	burst(position, Color3.fromRGB(64, 58, 52), 26, 14, 3.5, 2)
end

local function setTrails(rig: Rig, on: boolean)
	for _, trail in rig.trails do
		trail.Enabled = on
	end
end

local function makeTrails(rig: Rig)
	local hands: { string } = if rig.kind == "Brute" then { "RHand" } else { "LHand", "RHand" }
	for _, name in hands do
		local hand = rig.model:FindFirstChild(name) :: BasePart?
		if hand then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.2, 0)
			a0.Parent = hand
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, if rig.kind == "Brute" then -2.4 else -1.3, 0)
			a1.Parent = hand
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.16
			trail.MinLength = 0.05
			trail.FaceCamera = true
			trail.LightInfluence = 1
			trail.Color = ColorSequence.new(Color3.fromRGB(60, 12, 14), Color3.fromRGB(20, 8, 10))
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			})
			trail.Enabled = false
			trail.Parent = hand
			table.insert(rig.trails, trail)
		end
	end
end

local function ground(rig: Rig): Vector3
	return rig.root.Position + Vector3.new(0, rig.skeleton.ground, 0)
end

-- Called when a rig's state changes: sounds and effects that go with the new state.
local function onState(rig: Rig, state: string)
	local position = rig.root.Position
	local pitch = 0.9 + (rig.seed % 30) / 100
	setTrails(rig, false)
	rig.slammed = false
	if state == "Emerge" then
		if rig.emerge == "Wake" then
			audio("HollowWake", position, 1, pitch)
		else
			local at = if rig.emerge == "Climb"
				then position + rig.root.CFrame.LookVector * -3
				else ground(rig)
			burst(at, Color3.fromRGB(46, 40, 36), 30, 9, 3, 3)
			audio("HollowScrabble", position, 1, pitch)
			audio("HollowSpawn", position, 0.9, pitch)
		end
	elseif state == "Windup" then
		if rig.kind == "Brute" then
			audio("HollowWake", position, 1.1, 0.62)
		else
			audio("HollowScream", position, 1, if rig.kind == "Crawler" then 1.35 else pitch)
		end
	elseif state == "Recover" then
		setTrails(rig, true)
		task.delay(0.28, function()
			setTrails(rig, false)
		end)
		if rig.kind ~= "Brute" then
			audio("HollowSwipe", position, 1, pitch)
		end
	elseif state == "Grab" then
		-- the snatch: a scream in the victim's face and the ground jolting
		rig.bites = 0
		audio("HollowScream", position, 1.15, if rig.kind == "Brute" then 0.7 else pitch * 1.1)
		audio("HollowScrabble", position, 0.9, 1.4)
		shakeNear(position, 24, 0.6)
		if rig.kind == "Brute" then
			burst(ground(rig) + rig.root.CFrame.LookVector * 4, Color3.fromRGB(64, 58, 52), 18, 10, 3, 2)
		end
	elseif state == "Reel" then
		audio("HollowWake", position, 0.9, pitch * 1.25)
	end
end

-- A bite, squeeze or yank of a hold: the sound of it, and the Brute's embers flaring.
local function onBite(rig: Rig, def: Grabs.Def)
	local position = rig.root.Position
	if rig.kind == "Brute" then
		audio("HollowSlam", position, 0.55, 1.15)
	elseif def.lying then
		audio("HollowScrabble", position, 0.8, 0.9)
	else
		audio("HollowSwipe", position, 0.8, 0.75)
	end
	if rig.embers then
		local embers = rig.embers :: PointLight
		embers.Brightness = 3.2
		TweenService:Create(embers, TweenInfo.new(0.5), { Brightness = 1.1 }):Play()
	end
end

-- Frame ------------------------------------------------------------------------------------------

local function animate(rig: Rig, dt: number, now: number, clock: number, position: Vector3?, grime: number)
	local model = rig.model
	local state = (model:GetAttribute("State") :: string?) or "Prowl"
	local stateAt = (model:GetAttribute("StateAt") :: number?) or now
	if state ~= rig.state or stateAt ~= rig.stateAt then
		rig.state = state
		rig.stateAt = stateAt
		rig.emerge = (model:GetAttribute("Emerge") :: string?) or "Rise"
		onState(rig, state)
	end
	local lungeAt = (model:GetAttribute("LungeAt") :: number?) or 0
	if lungeAt ~= rig.lungeAt then
		rig.lungeAt = lungeAt
		audio("HollowScrabble", rig.root.Position, 0.8, 1.2)
	end
	local elapsed = now - stateAt
	local stunned = ((model:GetAttribute("StunnedUntil") :: number?) or 0) > now

	local velocity = rig.root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local dressing = cosmetics[model]
	local neckOffset, jawOffset = I, I
	if dressing then
		HollowCosmetics.update(dressing, position, grime, state, speed)
		neckOffset, jawOffset = HollowCosmetics.offsets(dressing, clock, state, speed, stunned)
	end
	local before = rig.phase
	rig.phase += dt * HollowPoses.cadence(rig.kind, speed)
	-- a footfall every half turn: the Brute shakes the ground
	if math.floor(before / math.pi) ~= math.floor(rig.phase / math.pi) and speed > 4 then
		if rig.kind == "Brute" then
			audio("HollowStep", rig.root.Position, 1, 0.9 + rig.stepSide * 0.08)
			shakeNear(rig.root.Position, 16, 0.25)
			rig.stepSide = -rig.stepSide
		elseif rig.kind == "Crawler" and speed > 10 then
			audio("HollowScrabble", rig.root.Position, 0.25, 1.9)
		end
	end
	if rig.kind == "Crawler" and not dressing then
		local dust = rig.root:FindFirstChild("Dust") :: ParticleEmitter?
		if dust then
			dust.Rate = if speed > 6 then 14 else 0
		end
	end

	-- a hold: its id and how long it has gone on, and a sound on every bite
	local grabId = if state == "Grab" then model:GetAttribute("GrabStyle") :: string? else nil
	local grabAt = (model:GetAttribute("GrabAt") :: number?) or now
	local grabTime = now - grabAt
	if grabId then
		local def = Grabs.ById[grabId]
		if def and grabTime > Tuning.Grab.Settle then
			local bites = math.floor((grabTime - Tuning.Grab.Settle) / def.bite)
			if bites > rig.bites then
				rig.bites = bites
				onBite(rig, def)
			end
		end
	end

	-- random head twitches: snap, hold, release
	if not dressing and clock >= rig.twitchNext then
		rig.twitch = A((math.random() - 0.5) * 0.9, (math.random() - 0.5) * 1.4, (math.random() - 0.5) * 1.2)
		rig.twitchUntil = clock + 0.15 + math.random() * 0.45
		rig.twitchNext = clock + (if state == "Dormant" then 3 else 1.2) + math.random() * 3
	end
	local twitching = not dressing and clock < rig.twitchUntil and state ~= "Emerge" and state ~= "Grab"

	local kindDef = (Tuning.HollowKinds :: any)[rig.kind]
	local target = HollowPoses.pose(rig.skeleton, {
		state = state,
		elapsed = elapsed,
		speed = speed,
		phase = rig.phase,
		now = now,
		seed = rig.seed,
		emerge = rig.emerge,
		stunned = stunned,
		windup = H.WindupSeconds * (if kindDef then kindDef.windup else 1),
		grab = grabId,
		grabTime = grabTime,
	})
	if
		state == "Recover"
		and rig.kind == "Brute"
		and elapsed < 0.3
		and not rig.slammed
		and elapsed > 0.12
	then
		rig.slammed = true
		local at = rig.root.Position + rig.root.CFrame.LookVector * 4
		shockwave(at - Vector3.new(0, rig.root.Size.Y / 2 + 3.6, 0))
		audio("HollowSlam", at)
		shakeNear(at, 30, 1)
	end
	if twitching then
		target.Neck = (target.Neck or I) * rig.twitch
	end

	-- smooth toward the target: fast through strikes and grabs, slower otherwise
	local rate = if state == "Windup"
			or state == "Recover"
			or state == "Grab"
		then 26
		elseif state == "Emerge" then 22
		elseif rig.kind == "Crawler" then 18
		else 12
	local alpha = 1 - math.exp(-rate * dt)
	for name, motor in rig.motors do
		local goal = target[name] or I
		local current = rig.pose[name] or I
		local value = if twitching and name == "Neck" then goal else current:Lerp(goal, alpha)
		rig.pose[name] = value
		motor.Transform = value
			* (if name == "Neck" then neckOffset elseif name == "Jaw" then jawOffset else I)
	end
end

local function register(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	model:WaitForChild("Humanoid", 5)
	if root == nil then
		return
	end
	local motors: { [string]: Motor6D } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end
	local chest = model:FindFirstChild("Chest")
	local seed = (model:GetAttribute("Seed") :: number?) or math.random(1, 1e6)
	local rig: Rig = {
		model = model,
		root = root,
		kind = (model:GetAttribute("Kind") :: string?) or "Stalker",
		skeleton = HollowPoses.rigOf(model),
		motors = motors,
		pose = {},
		phase = seed % 7,
		seed = seed % 1000,
		state = "",
		stateAt = 0,
		emerge = "Rise",
		twitch = I,
		twitchUntil = 0,
		twitchNext = os.clock() + 1 + (seed % 30) / 10,
		trails = {},
		stepSide = 1,
		slammed = false,
		lungeAt = (model:GetAttribute("LungeAt") :: number?) or 0,
		bites = 0,
		embers = if chest then chest:FindFirstChild("EmberGlow") :: PointLight? else nil,
	}
	makeTrails(rig)
	rigs[model] = rig
	if rig.kind == "Stalker" or rig.kind == "Crawler" then
		cosmetics[model] = HollowCosmetics.attach(model, root)
	end
	local ancestry: RBXScriptConnection? = nil
	ancestry = model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			local dressing = cosmetics[model]
			if dressing then
				HollowCosmetics.destroy(dressing)
				cosmetics[model] = nil
				for _, name in { "Neck", "Jaw" } do
					local motor = rig.motors[name]
					if motor and motor.Parent then
						motor.Transform = rig.pose[name] or I
					end
				end
			end
			rigs[model] = nil
			if ancestry then
				ancestry:Disconnect()
			end
		end
	end)
end

function HollowAnimator.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "HollowFx"
	fxFolder.Parent = Workspace
end

function HollowAnimator.Start()
	task.spawn(function()
		local folder = Workspace:WaitForChild("Hollows", 60)
		if folder == nil then
			return
		end
		folder.ChildAdded:Connect(function(child)
			task.spawn(register, child)
		end)
		for _, child in folder:GetChildren() do
			task.spawn(register, child)
		end
	end)

	RunService.Stepped:Connect(function(_, dt: number)
		local now = Workspace:GetServerTimeNow()
		local clock = os.clock()
		local character = Players.LocalPlayer.Character
		local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local position = if playerRoot and playerRoot:IsA("BasePart") then playerRoot.Position else nil
		local run = Registry.StateController.Get({ "run" })
		local grime = if run
			then GrimeLevel.forStop(
				run.nextStop or 1,
				run.stopCount or Tuning.Run.StationCount,
				run.station ~= nil and run.station.terminus == true
			)
			else 0
		for _, rig in rigs do
			Safe.call("HollowAnimator", animate, rig, dt, now, clock, position, grime)
		end
	end)
end

-- Distance from `position` to the nearest Hollow, or math.huge when there is none.
function HollowAnimator.Nearest(position: Vector3): number
	local best = math.huge
	for _, rig in rigs do
		best = math.min(best, (rig.root.Position - position).Magnitude)
	end
	return best
end

return HollowAnimator
