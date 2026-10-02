--!strict
--[[
	Procedural animation for the Hollows. Every client writes each joint's
	Motor6D.Transform from the creature's kind, its state (the State, StateAt and
	Emerge attributes the server sets) and its velocity. No animation assets.

	  Stalker  a limp when it prowls (one leg strides, the other drags), head lolling;
	           on the hunt it pitches forward and runs with its arms flung back. It rears
	           and screams before it strikes, then rakes down with both hands.
	  Crawler  a four-legged scuttle with its upside-down head chattering; it crouches,
	           then pounces.
	  Brute    a heavy, rolling stomp that shakes the ground; it raises the shovel over its
	           head and slams it down with a shockwave.

	Spawning is a show too: Hollows claw up out of the ground, haul themselves over the
	station's edge out of the dark, or wake in jerks from a slump in a building. Heads
	twitch at random, held for a beat and released. Poses are smoothed so a state change
	never pops, and the effects (dust, trails, sounds, shockwaves) hang off state changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Registry = require(script.Parent.Parent.Registry)

type Pose = { [string]: CFrame }

type Rig = {
	model: Model,
	root: BasePart,
	kind: string,
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
}

local HollowAnimator = {}

local H = Tuning.Hollow
local I = CFrame.identity
local rigs: { [Model]: Rig } = {}
local fxFolder: Folder

local function A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(x, y, z)
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function easeOut(t: number): number
	local u = 1 - clamp01(t)
	return 1 - u * u * u
end

local function blend(a: Pose, b: Pose, t: number): Pose
	local out: Pose = {}
	for name, value in a do
		out[name] = value:Lerp(b[name] or I, t)
	end
	for name, value in b do
		if (out[name] :: CFrame?) == nil then
			out[name] = I:Lerp(value, t)
		end
	end
	return out
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
	local height = rig.root.Size.Y / 2
	local humanoid = rig.model:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 3
	return rig.root.Position - Vector3.new(0, height + hip, 0)
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
	end
end

-- Poses --------------------------------------------------------------------------------------

local function stalkerGait(out: Pose, p: number, stride: number, hunt: boolean, now: number, seed: number)
	local lean = if hunt then -0.5 else -0.1
	local l, r = math.sin(p), math.sin(p + math.pi)
	-- the left leg strides, the right drags: a limp
	out.LHip = A(l * 0.62 * stride, 0, -0.04)
	out.RHip = A(r * 0.4 * stride, 0, 0.06)
	out.LKnee = A(-math.max(0, math.cos(p)) * 1.1 * stride - 0.06, 0, 0)
	out.RKnee = A(-math.max(0, math.cos(p + math.pi)) * 0.45 * stride - 0.05, 0, 0)
	out.LAnkle = A(math.max(0, -math.cos(p)) * 0.3 * stride, 0, 0)
	out.RAnkle = A(0.25 * stride, 0, 0)
	local bob = math.abs(l) * 0.22 * stride
	out.RootJoint = CFrame.new(0, bob - 0.1 * stride, 0)
		* A(lean * 0.4, l * 0.08 * stride, l * 0.1 * stride + 0.06)
	out.Waist = A(lean * 0.6 + math.sin(p * 2) * 0.03, l * 0.12 * stride, 0)
	if hunt then
		local reach = l * 0.8 * stride
		out.LShoulder = A(-0.6 + reach, 0, -0.25)
		out.RShoulder = A(-0.6 - reach, 0, 0.25)
		out.LElbow = A(0.55, 0, 0)
		out.RElbow = A(0.55, 0, 0)
		out.Neck = A(0.55, 0, 0)
		out.Jaw = A(-0.25 - 0.1 * math.sin(now * 9 + seed), 0, 0)
	else
		out.LShoulder = A(-r * 0.25 * stride + 0.05, 0, -0.06 - 0.04 * math.sin(p * 0.5))
		out.RShoulder = A(-l * 0.25 * stride + 0.05, 0, 0.06 + 0.04 * math.sin(p * 0.5))
		out.LElbow = A(0.15 + 0.1 * math.max(0, l), 0, 0)
		out.RElbow = A(0.15 + 0.1 * math.max(0, r), 0, 0)
		out.Neck = A(-0.1, 0.25 * math.sin(now * 0.7 + seed), 0.38)
		out.Jaw = A(-0.12, 0, 0)
	end
	out.LWrist = A(0.2, 0, 0)
	out.RWrist = A(0.2, 0, 0)
end

local function crawlerGait(out: Pose, p: number, stride: number, hunt: boolean, now: number, seed: number)
	local a, b = math.sin(p), math.sin(p + math.pi)
	-- diagonal pairs: left arm with right leg, right arm with left leg
	out.LShoulder = A(a * 0.5 * stride, 0, -0.15)
	out.RShoulder = A(b * 0.5 * stride, 0, 0.15)
	out.LElbow = A(-0.5 - math.max(0, math.cos(p)) * 0.6 * stride, 0, 0)
	out.RElbow = A(-0.5 - math.max(0, math.cos(p + math.pi)) * 0.6 * stride, 0, 0)
	out.LHip = A(0.2 + b * 0.45 * stride, 0, 0)
	out.RHip = A(0.2 + a * 0.45 * stride, 0, 0)
	out.LKnee = A(-1.75 - math.max(0, math.cos(p + math.pi)) * 0.4 * stride, 0, 0)
	out.RKnee = A(-1.75 - math.max(0, math.cos(p)) * 0.4 * stride, 0, 0)
	out.LAnkle = A(0.9, 0, 0)
	out.RAnkle = A(0.9, 0, 0)
	out.RootJoint = CFrame.new(0, math.abs(a) * 0.15 * stride, 0) * A(0, a * 0.12 * stride, a * 0.1 * stride)
	out.Waist = A(0, b * 0.15 * stride, 0)
	out.Neck = A(0, math.sin(now * 1.7 + seed) * 0.4, 0)
	out.Jaw = A(if hunt then -0.35 - 0.25 * math.abs(math.sin(now * 16)) else -0.1, 0, 0)
end

local function bruteGait(out: Pose, p: number, stride: number, hunt: boolean, now: number, seed: number)
	local l, r = math.sin(p), math.sin(p + math.pi)
	out.LHip = A(l * 0.45 * stride, 0, -0.05)
	out.RHip = A(r * 0.45 * stride, 0, 0.05)
	out.LKnee = A(-math.max(0, math.cos(p)) * 0.8 * stride - 0.1, 0, 0)
	out.RKnee = A(-math.max(0, math.cos(p + math.pi)) * 0.8 * stride - 0.1, 0, 0)
	out.RootJoint = CFrame.new(0, -math.abs(l) * 0.25 * stride, 0) * A(0, l * 0.1 * stride, l * 0.12 * stride)
	out.Waist = A((if hunt then -0.25 else 0) + math.sin(now * 1.2 + seed) * 0.03, -l * 0.15 * stride, 0)
	-- the fist swings; the shovel arm hangs heavy and scrapes
	out.LShoulder = A(-r * 0.5 * stride, 0, -0.2)
	out.RShoulder = A(-l * 0.2 * stride + 0.1, 0, 0.18)
	out.LElbow = A(0.4, 0, 0)
	out.RElbow = A(0.2, 0, 0)
	out.Neck = A(if hunt then 0.3 else 0.1, math.sin(now * 0.6 + seed) * 0.2, 0)
	out.Jaw = A(if hunt then -0.3 else -0.1, 0, 0)
end

local function gait(
	kind: string,
	out: Pose,
	p: number,
	stride: number,
	hunt: boolean,
	now: number,
	seed: number
)
	if kind == "Crawler" then
		crawlerGait(out, p, stride, hunt, now, seed)
	elseif kind == "Brute" then
		bruteGait(out, p, stride, hunt, now, seed)
	else
		stalkerGait(out, p, stride, hunt, now, seed)
	end
end

local function dormant(kind: string, now: number, seed: number): Pose
	local breathe = math.sin(now * 1.3 + seed) * 0.04
	if kind == "Crawler" then
		return {
			RootJoint = CFrame.new(0, -0.9, 0) * A(0, 0, 0.6),
			LHip = A(1.2, 0, 0),
			RHip = A(1.2, 0, 0),
			LKnee = A(-2.2, 0, 0),
			RKnee = A(-2.2, 0, 0),
			LShoulder = A(-0.6, 0, -0.4),
			RShoulder = A(-0.6, 0, 0.4),
			Waist = A(0.2 + breathe, 0, 0),
			Neck = A(-0.6, 0, 0),
		}
	elseif kind == "Brute" then
		return {
			RootJoint = CFrame.new(0, -2.3, 0.4) * A(-0.1, 0, 0),
			LHip = A(1.3, 0, -0.1),
			RHip = A(0.4, 0, 0.1),
			LKnee = A(-1.6, 0, 0),
			RKnee = A(-1.9, 0, 0),
			Waist = A(-0.55 + breathe, 0, 0),
			Neck = A(-0.7, 0, 0),
			LShoulder = A(0.3, 0, -0.1),
			RShoulder = A(0.6, 0, 0.1),
			LElbow = A(0.6, 0, 0),
			RElbow = A(0.3, 0, 0),
		}
	end
	return {
		RootJoint = CFrame.new(0, -2.9, 0.6) * A(-0.15, 0, 0.08),
		LHip = A(1.45, 0, -0.12),
		RHip = A(1.35, 0, 0.18),
		LKnee = A(-0.25, 0, 0),
		RKnee = A(-0.55, 0, 0),
		Waist = A(-0.55 + breathe, 0, 0.1),
		Neck = A(-0.75, 0.2, 0.35),
		LShoulder = A(0.1, 0, -0.15),
		RShoulder = A(0.25, 0, 0.12),
		LElbow = A(0.2, 0, 0),
		RElbow = A(0.4, 0, 0),
		Jaw = A(-0.2, 0, 0),
	}
end

local function emerge(rig: Rig, out: Pose, t: number, now: number)
	local style = rig.emerge
	local under = 1 - easeOut(t)
	local depth = if rig.kind == "Crawler" then 4.5 elseif rig.kind == "Brute" then 10 else 9
	local claw = math.sin(now * 14 + rig.seed) * 0.18 * under
	if style == "Climb" then
		out.RootJoint = CFrame.new(0, -depth * under, 3.5 * under) * A(-0.9 * under, 0, 0)
		out.LShoulder = A(1.7 + 0.9 * under + claw, 0, -0.3)
		out.RShoulder = A(1.7 + 0.9 * under - claw, 0, 0.3)
		out.LElbow = A(0.9 * under, 0, 0)
		out.RElbow = A(0.9 * under, 0, 0)
		out.Neck = A(0.4 * under, 0, 0)
	else
		out.RootJoint = CFrame.new(0, -depth * under, 0) * A(-0.6 * under, 0, 0)
		out.LShoulder = A(2.8 * under + claw, 0, -0.3 * under)
		out.RShoulder = A(2.8 * under - claw, 0, 0.3 * under)
		out.LElbow = A(0.6 * under, 0, 0)
		out.RElbow = A(0.6 * under, 0, 0)
		out.Neck = A(-0.8 * under + 0.3 * t, 0, 0)
	end
	-- it screams as it frees itself
	out.Jaw = A(-0.9 * clamp01((t - 0.65) / 0.2) * clamp01((1 - t) / 0.1 + 0.3), 0, 0)
end

local function attack(rig: Rig, out: Pose, windup: number?, strike: number?, now: number)
	local kind = rig.kind
	if windup then
		local e = easeOut(windup)
		local shake = math.sin(now * 50) * 0.04 * e
		if kind == "Crawler" then
			out.RootJoint = CFrame.new(0, -0.5 * e, 0.6 * e) * A(0.15 * e, 0, 0)
			out.LHip = A(0.6 * e, 0, 0)
			out.RHip = A(0.6 * e, 0, 0)
			out.LShoulder = A(-0.4 * e, 0, -0.2)
			out.RShoulder = A(-0.4 * e, 0, 0.2)
			out.Neck = A(0.5 * e + shake, 0, 0)
			out.Jaw = A(-1.0 * e, 0, 0)
		elseif kind == "Brute" then
			out.Waist = A(0.35 * e, 0, 0)
			out.LShoulder = A(2.9 * e, 0, -0.25 * e)
			out.RShoulder = A(2.9 * e, 0, 0.25 * e)
			out.LElbow = A(0.3 * e, 0, 0)
			out.RElbow = A(0.3 * e, 0, 0)
			out.Neck = A(0.5 * e + shake, 0, 0)
			out.Jaw = A(-0.8 * e, 0, 0)
		else
			out.Waist = A(-0.1 + 0.45 * e, 0, 0)
			out.LShoulder = A(2.6 * e, 0, -0.35 * e)
			out.RShoulder = A(2.6 * e, 0, 0.35 * e)
			out.LElbow = A(0.5 * e, 0, 0)
			out.RElbow = A(0.5 * e, 0, 0)
			out.Neck = A(0.5 * e + shake, shake, 0)
			out.Jaw = A(-0.95 * e, 0, 0)
		end
	elseif strike then
		local s = easeOut(strike)
		if kind == "Crawler" then
			out.RootJoint = CFrame.new(0, math.sin(math.pi * s) * 1.4, -2.5 * s) * A(-0.3 * s, 0, 0)
			out.LShoulder = A(1.3 * s, 0, -0.2)
			out.RShoulder = A(1.3 * s, 0, 0.2)
			out.LHip = A(-0.6 * s, 0, 0)
			out.RHip = A(-0.6 * s, 0, 0)
			out.Jaw = A(-1.0 * (1 - s), 0, 0)
		elseif kind == "Brute" then
			out.RootJoint = CFrame.new(0, -0.6 * s, -0.4 * s)
			out.Waist = A(0.35 - 1.05 * s, 0, 0)
			out.LShoulder = A(2.9 - 2.4 * s, 0, -0.25)
			out.RShoulder = A(2.9 - 2.4 * s, 0, 0.25)
			out.Neck = A(0.3, 0, 0)
			out.Jaw = A(-0.8 * (1 - s), 0, 0)
		else
			out.RootJoint = CFrame.new(0, 0, -0.8 * s)
			out.Waist = A(0.35 - 0.85 * s, 0, 0)
			out.LShoulder = A(2.6 - 2.25 * s, 0, -0.35 * (1 - s))
			out.RShoulder = A(2.6 - 2.25 * s, 0, 0.35 * (1 - s))
			out.LElbow = A(0.5 * (1 - s), 0, 0)
			out.RElbow = A(0.5 * (1 - s), 0, 0)
			out.Neck = A(0.5, 0, 0)
			out.Jaw = A(-0.95 * (1 - s) - 0.1, 0, 0)
		end
	end
end

local function cower(rig: Rig, out: Pose, now: number, stunned: boolean)
	local shiver = math.sin(now * 40) * 0.05
	if rig.kind == "Crawler" then
		out.RootJoint = CFrame.new(0, -0.6, 0.4) * A(0, 0, shiver)
		out.Neck = A(-0.6, 0.6 + shiver, 0)
		out.LShoulder = A(-0.8, 0, -0.5)
		out.RShoulder = A(-0.8, 0, 0.5)
		return
	end
	out.LShoulder = A(2.1 + shiver, 0, 0.55)
	out.RShoulder = A(2.1 - shiver, 0, -0.55)
	out.LElbow = A(1.5, 0, 0)
	out.RElbow = A(1.5, 0, 0)
	out.Waist = A((if stunned then 0.35 else 0.15) + shiver, 0, 0)
	out.Neck = A(-0.4, (if stunned then 0 else 0.8) + shiver, 0)
	out.Jaw = A(-0.5, 0, 0)
	out.RootJoint = CFrame.new(0, -0.4, 0.3) * A(0, 0, shiver)
end

-- Frame ------------------------------------------------------------------------------------------

local function animate(rig: Rig, dt: number, now: number, clock: number)
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
	local strideLength = if rig.kind == "Brute" then 9 elseif rig.kind == "Crawler" then 5 else 7.5
	local stride = math.min(speed / 12, 1.4)
	local before = rig.phase
	rig.phase += dt * (1.5 + speed / strideLength * math.pi)
	-- a footfall every half turn: the Brute shakes the ground, the Crawler kicks up dust
	if math.floor(before / math.pi) ~= math.floor(rig.phase / math.pi) and speed > 4 then
		if rig.kind == "Brute" then
			audio("HollowStep", rig.root.Position, 1, 0.9 + rig.stepSide * 0.08)
			shakeNear(rig.root.Position, 16, 0.25)
			rig.stepSide = -rig.stepSide
		end
	end
	if rig.kind == "Crawler" then
		local dust = rig.root:FindFirstChild("Dust") :: ParticleEmitter?
		if dust then
			dust.Rate = if speed > 6 then 14 else 0
		end
	end

	-- random head twitches: snap, hold, release
	if clock >= rig.twitchNext then
		rig.twitch = A((math.random() - 0.5) * 0.9, (math.random() - 0.5) * 1.4, (math.random() - 0.5) * 1.2)
		rig.twitchUntil = clock + 0.15 + math.random() * 0.45
		rig.twitchNext = clock + (if state == "Dormant" then 3 else 1.2) + math.random() * 3
	end
	local twitching = clock < rig.twitchUntil

	local target: Pose = {}
	local hunt = state == "Hunt" or state == "Windup" or state == "Recover"
	if state == "Dormant" then
		target = dormant(rig.kind, now, rig.seed)
	elseif state == "Emerge" and rig.emerge == "Wake" then
		local t = clamp01(elapsed / H.EmergeSeconds)
		-- it unfolds in jerks, not smoothly
		local jerk = math.floor(t * 5) / 5 + (t * 5 % 1) ^ 6 / 5
		local standing: Pose = {}
		gait(rig.kind, standing, 0, 0, true, now, rig.seed)
		target = blend(dormant(rig.kind, now, rig.seed), standing, jerk)
		if t < 0.25 then
			target.Neck = A(0.35, 0, 0) -- the head comes up first
		end
		target.Jaw = A(-0.9 * clamp01((t - 0.7) / 0.15), 0, 0)
	elseif state == "Emerge" then
		gait(rig.kind, target, rig.phase, 0, false, now, rig.seed)
		emerge(rig, target, clamp01(elapsed / H.EmergeSeconds), now)
	elseif stunned or state == "Stunned" then
		cower(rig, target, now, true)
	elseif state == "Repelled" then
		gait(rig.kind, target, rig.phase, stride, false, now, rig.seed)
		cower(rig, target, now, false)
	else
		gait(rig.kind, target, rig.phase, stride, hunt, now, rig.seed)
		local kind = (Tuning.HollowKinds :: any)[rig.kind]
		local windupSeconds = H.WindupSeconds * (if kind then kind.windup else 1)
		if state == "Windup" then
			attack(rig, target, clamp01(elapsed / windupSeconds), nil, now)
		elseif state == "Recover" and elapsed < 0.3 then
			attack(rig, target, nil, clamp01(elapsed / 0.18), now)
			if rig.kind == "Brute" and not rig.slammed and elapsed > 0.12 then
				rig.slammed = true
				local at = rig.root.Position + rig.root.CFrame.LookVector * 4
				shockwave(at - Vector3.new(0, rig.root.Size.Y / 2 + 3.6, 0))
				audio("HollowSlam", at)
				shakeNear(at, 30, 1)
			end
		end
	end
	if twitching and state ~= "Emerge" then
		target.Neck = (target.Neck or I) * rig.twitch
	end

	-- smooth toward the target: fast through strikes, slower otherwise
	local rate = if state == "Windup" or state == "Recover" then 30 elseif state == "Emerge" then 22 else 12
	local alpha = 1 - math.exp(-rate * dt)
	for name, motor in rig.motors do
		local goal = target[name] or I
		local current = rig.pose[name] or I
		local value = if twitching and name == "Neck" then goal else current:Lerp(goal, alpha)
		rig.pose[name] = value
		motor.Transform = value
	end
end

local function register(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if root == nil then
		return
	end
	local motors: { [string]: Motor6D } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end
	local seed = (model:GetAttribute("Seed") :: number?) or math.random(1, 1e6)
	local rig: Rig = {
		model = model,
		root = root,
		kind = (model:GetAttribute("Kind") :: string?) or "Stalker",
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
	}
	makeTrails(rig)
	rigs[model] = rig
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			rigs[model] = nil
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
		for _, rig in rigs do
			animate(rig, dt, now, clock)
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
