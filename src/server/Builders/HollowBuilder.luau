--!strict
--[[
	The Hollow: a gaunt, eight-stud figure assembled from primitives on a
	Humanoid rig. Joints are Motor6Ds so clients can animate the limbs
	procedurally (HollowAnimator) with no animation assets.

	It is built to read in the dark rather than in daylight: pale eyes that
	light the ground in front of it, faint cold veins that trace the silhouette,
	and a low mist dragging from its feet. In fog the eyes show first.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)

local HollowBuilder = {}

local SKIN = Color3.fromRGB(22, 20, 24)
local CLOTH = Color3.fromRGB(34, 30, 34)
local EYE = Color3.fromRGB(190, 236, 255)
local VEIN = Color3.fromRGB(70, 150, 170)

local LEG_LENGTH = 3.6
local HIP_HEIGHT = 3.4

local function limb(model: Model, name: string, size: Vector3, color: Color3): BasePart
	local part =
		Kit.block(model, size, CFrame.new(), color, { material = Enum.Material.Slate, collide = false })
	part.Name = name
	part.Anchored = false
	part.Massless = true
	return part
end

local function joint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = part0
	return motor
end

function HollowBuilder.build(at: CFrame): (Model, Humanoid)
	local model = Kit.model("Hollow")

	local root =
		Kit.block(model, Vector3.new(2.2, 2.2, 1.2), at, Color3.new(), { transparency = 1, shadow = false })
	root.Name = "HumanoidRootPart"
	root.Anchored = false
	root.CanCollide = true

	local torso = limb(model, "Torso", Vector3.new(1.9, 3.2, 1.0), SKIN)
	local head = limb(model, "Head", Vector3.new(1.0, 1.6, 1.1), SKIN)
	local leftArm = limb(model, "LeftArm", Vector3.new(0.45, 4.4, 0.45), SKIN)
	local rightArm = limb(model, "RightArm", Vector3.new(0.45, 4.4, 0.45), SKIN)
	local leftLeg = limb(model, "LeftLeg", Vector3.new(0.55, LEG_LENGTH, 0.55), SKIN)
	local rightLeg = limb(model, "RightLeg", Vector3.new(0.55, LEG_LENGTH, 0.55), SKIN)

	joint("RootJoint", root, torso, CFrame.new(0, 0.4, 0) * Kit.angles(-14, 0, 0), CFrame.new(0, -1.6, 0))
	joint("Neck", torso, head, CFrame.new(0, 1.6, -0.25) * Kit.angles(-20, 0, 0), CFrame.new(0, -0.7, 0))
	joint("LeftShoulder", torso, leftArm, CFrame.new(-1.15, 1.35, 0), CFrame.new(0, 2.0, 0))
	joint("RightShoulder", torso, rightArm, CFrame.new(1.15, 1.35, 0), CFrame.new(0, 2.0, 0))
	joint("LeftHip", root, leftLeg, CFrame.new(-0.55, -1.0, 0), CFrame.new(0, LEG_LENGTH / 2, 0))
	joint("RightHip", root, rightLeg, CFrame.new(0.55, -1.0, 0), CFrame.new(0, LEG_LENGTH / 2, 0))

	-- Eyes glow so a Hollow in fog reads before its silhouette does.
	for _, side in { -0.24, 0.24 } do
		local eye = Kit.neon(model, Vector3.new(0.22, 0.14, 0.1), CFrame.new(), EYE)
		eye.Name = "Eye"
		eye.Anchored = false
		eye.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = eye
		weld.C0 = CFrame.new(side, 0.25, -0.56)
		weld.Parent = eye
	end
	local glow = Kit.pointLight(head, EYE, 1.3, 11, false)
	glow.Name = "EyeGlow"

	-- Cold veins along the body: barely there in light, a traced outline in the dark.
	local veins: { { part: BasePart, size: Vector3, c0: CFrame } } = {
		{
			part = torso,
			size = Vector3.new(0.08, 1.6, 0.06),
			c0 = CFrame.new(-0.35, 0.3, -0.52) * Kit.angles(0, 0, 18),
		},
		{
			part = torso,
			size = Vector3.new(0.08, 1.2, 0.06),
			c0 = CFrame.new(0.3, -0.4, -0.52) * Kit.angles(0, 0, -24),
		},
		{
			part = torso,
			size = Vector3.new(0.08, 0.9, 0.06),
			c0 = CFrame.new(0.15, 0.9, -0.52) * Kit.angles(0, 0, 35),
		},
		{ part = leftArm, size = Vector3.new(0.06, 2.4, 0.06), c0 = CFrame.new(0, -0.4, -0.245) },
		{ part = rightArm, size = Vector3.new(0.06, 2.2, 0.06), c0 = CFrame.new(0, -0.2, -0.245) },
	}
	for _, vein in veins do
		local line = Kit.neon(model, vein.size, CFrame.new(), VEIN)
		line.Name = "Vein"
		line.Anchored = false
		line.Massless = true
		line.Transparency = 0.25
		local weld = Instance.new("Weld")
		weld.Part0 = vein.part
		weld.Part1 = line
		weld.C0 = vein.c0
		weld.Parent = line
	end

	-- Claws and tattered cloak.
	for _, arm in { leftArm, rightArm } do
		for i = -1, 1 do
			local claw =
				Kit.wedge(model, Vector3.new(0.1, 0.9, 0.25), CFrame.new(), SKIN, { collide = false })
			claw.Anchored = false
			claw.Massless = true
			local weld = Instance.new("Weld")
			weld.Part0 = arm
			weld.Part1 = claw
			weld.C0 = CFrame.new(i * 0.15, -2.55, -0.05) * Kit.angles(180, 0, 0)
			weld.Parent = claw
		end
	end
	for i = 1, 5 do
		-- alternate thickness and depth so neighbouring rags never share a face
		local rag = Kit.wedge(
			model,
			Vector3.new(0.12 + (i % 2) * 0.04, 2.4 + (i % 2) * 0.8, 0.9),
			CFrame.new(),
			CLOTH,
			{ material = Enum.Material.Fabric, collide = false }
		)
		rag.Anchored = false
		rag.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = rag
		weld.C0 = CFrame.new(-0.9 + (i - 1) * 0.45, -1.8, 0.45 + (i % 2) * 0.06) * Kit.angles(10, 90, 180)
		weld.Parent = rag
	end

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(20, 18, 22))
	smoke.Rate = 6
	smoke.Lifetime = NumberRange.new(1, 1.8)
	smoke.Speed = NumberRange.new(0.4, 1.2)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) })
	smoke.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Parent = torso

	-- A low mist that drags behind it as it moves.
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "FootMist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(46, 48, 56))
	mist.Rate = 9
	mist.Lifetime = NumberRange.new(2.2, 3.4)
	mist.Speed = NumberRange.new(0.3, 0.9)
	mist.SpreadAngle = Vector2.new(70, 70)
	mist.EmissionDirection = Enum.NormalId.Bottom
	mist.Acceleration = Vector3.new(0, 0.6, 0)
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 5.5) })
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.RotSpeed = NumberRange.new(-15, 15)
	mist.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.MaxHealth = 10000
	humanoid.Health = 10000
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.AutoJumpEnabled = false
	humanoid.Parent = model
	for _, state in
		{
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Jumping,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end

	model.PrimaryPart = root
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Hollows"
			part.CanTouch = false
		end
	end
	return model, humanoid
end

return HollowBuilder
