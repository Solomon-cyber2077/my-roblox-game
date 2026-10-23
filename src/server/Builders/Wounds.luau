--!strict
--[[
	What a Hollow's grip leaves on a body (HollowService calls it; Config/Grabs names the
	area each grip works on):

	  mark   a bite lands: a round bruise raked by three dark claw marks, welded flush on the
	         limb the grip is working, so the crew sees who has been hurt. A limb keeps its last
	         Tuning.Trauma.WoundsPerLimb marks. A grip on the head marks the neck.
	  sever  a death in its grip: that limb comes away (the head, an arm or a leg; a grip on
	         the torso tears the legs away). The ends are capped in a dark, dried colour and a
	         few dark drops fall: kept short of gore on purpose, no bright red and no spray.

	Marks and stumps are server parts so every client sees the same body. They are massless,
	never collide and cast no shadow.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Grabs = require(ReplicatedStorage.Shared.Config.Grabs)
local Kit = require(ReplicatedStorage.Shared.Visual.Kit)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Wounds = {}

local T = Tuning.Trauma
local BRUISE = Color3.fromRGB(48, 26, 32) -- plum-brown, a little seen through
local GASH = Color3.fromRGB(66, 10, 12) -- a dark dried cut, never a bright red
local STUMP = Color3.fromRGB(46, 12, 14)
local DROPS = ColorSequence.new(Color3.fromRGB(70, 10, 12), Color3.fromRGB(38, 6, 8))
local FLUSH = 0.02 -- a mark stands this far off the limb's skin

-- The limb each area marks (a grip on the head marks the neck: the head is a mesh) and the joints
-- (on the Torso) a death there breaks.
local LIMB: { [Grabs.Area]: string } = {
	Head = "Torso",
	Torso = "Torso",
	LeftArm = "Left Arm",
	RightArm = "Right Arm",
	LeftLeg = "Left Leg",
	RightLeg = "Right Leg",
}
local JOINTS: { [Grabs.Area]: { string } } = {
	Head = { "Neck" },
	Torso = { "Left Hip", "Right Hip" },
	LeftArm = { "Left Shoulder" },
	RightArm = { "Right Shoulder" },
	LeftLeg = { "Left Hip" },
	RightLeg = { "Right Hip" },
}

local function folder(character: Model): Folder
	local existing = character:FindFirstChild("Wounds")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "Wounds"
	made.Parent = character
	return made
end

local function attach(part: BasePart, to: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	Kit.weld(part, to)
end

-- One bite's mark on the limb `area` works on. `rng` picks the spot.
function Wounds.mark(character: Model, area: Grabs.Area, rng: Random)
	local limb = character:FindFirstChild(LIMB[area])
	if limb == nil or not limb:IsA("BasePart") then
		return
	end
	local store = folder(character)
	local own: { Instance } = {}
	for _, mark in store:GetChildren() do
		if mark:GetAttribute("Limb") == limb.Name then
			table.insert(own, mark)
		end
	end
	if #own >= T.WoundsPerLimb then
		own[1]:Destroy() -- the oldest goes (children keep the order they were added in)
	end
	local half = limb.Size / 2
	-- the front, the back or the outer side of the limb (the torso's sides are under the arms, a
	-- limb's inner side against the body); a grip on the head marks the neck's top band
	local faces = { Vector3.zAxis, -Vector3.zAxis }
	if limb.Name ~= "Torso" then
		table.insert(faces, if string.find(limb.Name, "Left", 1, true) then -Vector3.xAxis else Vector3.xAxis)
	end
	local normal = faces[rng:NextInteger(1, #faces)]
	local across = if math.abs(normal.Z) > 0 then Vector3.xAxis else Vector3.zAxis
	local spanAcross = math.abs((half * across).Magnitude) - 0.3
	local high = if area == "Head" then half.Y - 0.35 else rng:NextNumber(-half.Y + 0.35, half.Y - 0.35)
	local depth = (half * normal).Magnitude + FLUSH
	local spot = normal * depth + across * rng:NextNumber(-spanAcross, spanAcross) + Vector3.yAxis * high
	local facing = CFrame.lookAt(spot, spot + normal) * CFrame.Angles(0, 0, rng:NextNumber(-0.7, 0.7))
	local mark = Instance.new("Model")
	mark.Name = "Wound"
	mark:SetAttribute("Limb", limb.Name)
	local at = limb.CFrame * facing
	-- a round bruise, the disc's axis along the face's normal
	local size = rng:NextNumber(0.45, 0.6)
	local bruise = Kit.cylinder(
		mark,
		0.02,
		size,
		at * CFrame.Angles(0, math.rad(90), 0),
		BRUISE,
		{ collide = false, shadow = false, transparency = 0.2 }
	)
	attach(bruise, limb)
	-- three claw rakes across it, a little ragged
	for i = -1, 1 do
		local rake = Kit.block(
			mark,
			Vector3.new(size * rng:NextNumber(0.7, 0.95), 0.045, 0.03),
			at * CFrame.new(rng:NextNumber(-0.03, 0.03), i * 0.11, -0.015),
			GASH,
			{ collide = false, shadow = false }
		)
		attach(rake, limb)
	end
	mark.Parent = store
end

-- A cap over a torn joint: a dark disc whose face looks along `out`, welded to `on`.
local function stump(on: BasePart, at: Vector3, out: Vector3, diameter: number)
	local cap = Kit.cylinder(
		on,
		0.12,
		diameter,
		CFrame.lookAt(at, at + out) * CFrame.Angles(0, math.rad(90), 0),
		STUMP,
		{ collide = false, shadow = false, material = Enum.Material.Slate }
	)
	cap.Name = "Stump"
	attach(cap, on)
	return cap
end

-- A few dark drops from a torn joint, then gone.
local function drops(on: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Drops"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = DROPS
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new(0.14, 0.02)
	emitter.Lifetime = NumberRange.new(0.45, 0.8)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Rate = 0
	emitter.Parent = on
	emitter:Emit(7) -- a third fewer than the first pass (Prompt 9 blood audit)
	task.delay(1.5, function()
		emitter:Destroy()
	end)
end

-- A death in its grip: the limb `area` comes away. Returns how many joints it broke.
function Wounds.sever(character: Model, area: Grabs.Area): number
	local torso = character:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return 0
	end
	local broken = 0
	for _, name in JOINTS[area] do
		local motor = torso:FindFirstChild(name)
		if motor == nil or not motor:IsA("Motor6D") then
			continue
		end
		local limb = motor.Part1
		if limb == nil then
			continue
		end
		local joint = torso.CFrame * motor.C0
		local out = (limb.Position - torso.Position).Unit
		motor:Destroy()
		broken += 1
		local diameter = math.min(limb.Size.X, limb.Size.Z) * 0.92
		stump(torso, joint.Position, out, diameter)
		stump(limb, joint.Position + out * 0.02, -out, diameter)
		drops(torso)
		limb.Anchored = false
		limb.CanCollide = true
		limb.Massless = false
		if limb:CanSetNetworkOwnership() then
			limb:SetNetworkOwner(nil)
		end
		limb.AssemblyLinearVelocity = (out + Vector3.yAxis * 0.6).Unit * T.SeverImpulse
		limb.AssemblyAngularVelocity = Vector3.new(
			math.random() - 0.5,
			math.random() - 0.5,
			math.random() - 0.5
		) * 8
	end
	return broken
end

return Wounds
