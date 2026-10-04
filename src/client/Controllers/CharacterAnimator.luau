--!strict
--[[
	Plays the crew's bodies on every client. Each R6 character the server builds (its
	Procedural attribute set, CrewService) has its joints written every frame from
	Animation/CrewPoses: how fast it moves and which way, whether it is in the air,
	seated, carrying, winded, afraid, or in a Hollow's hands.

	Your own character also looks where your camera looks (the head turns, within a
	neck's reach), lands with a jolt, and tells CameraController where its stride is so
	the view can bob with the steps. Other crew are read from their replicated velocity,
	seat and grab attributes.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Registry = require(script.Parent.Parent.Registry)
local CrewPoses = require(script.Parent.Parent.Animation.CrewPoses)

type Rig = {
	player: Player,
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	motors: { [string]: Motor6D },
	pose: CrewPoses.Pose,
	phase: number,
	seed: number,
	mine: boolean,
	landing: number,
	lastVertical: number,
	lastYaw: number,
	turn: number,
}

local CharacterAnimator = {}

local JOINTS = { "RootJoint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
local DREAD_NEAR, DREAD_FAR = 10, 75
local I = CFrame.identity

local rigs: { [Model]: Rig } = {}
local stride = { phase = 0, amount = 0 } -- your own steps, for the camera

local function register(player: Player, character: Model)
	if rigs[character] then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local torso = character:WaitForChild("Torso", 10)
	if root == nil or humanoid == nil or torso == nil or character:GetAttribute("Procedural") ~= true then
		return
	end
	local motors: { [string]: Motor6D } = {}
	for _, name in JOINTS do
		local parent = if name == "RootJoint" then root else torso
		local motor = parent:WaitForChild(name, 5)
		if motor and motor:IsA("Motor6D") then
			motors[name] = motor
		end
	end
	rigs[character] = {
		player = player,
		model = character,
		root = root,
		humanoid = humanoid,
		motors = motors,
		pose = {},
		phase = 0,
		seed = player.UserId % 997,
		mine = player == Players.LocalPlayer,
		landing = 0,
		lastVertical = 0,
		lastYaw = 0,
		turn = 0,
	}
	character.AncestryChanged:Connect(function()
		if character.Parent == nil then
			rigs[character] = nil
		end
	end)
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(register, player, character)
	end)
	if player.Character then
		task.spawn(register, player, player.Character)
	end
end

-- Where your camera looks, as a turn and a nod of the head from your body's facing.
local function look(root: BasePart): (number, number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return 0, 0
	end
	local dir = root.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
	local yaw = math.atan2(-dir.X, -dir.Z)
	-- looking back past the shoulder, the head gives up and faces ahead again
	if math.abs(yaw) > 2.2 then
		yaw = 0
	end
	local pitch = -math.asin(math.clamp(dir.Y, -1, 1))
	return math.clamp(yaw, -1.15, 1.15), math.clamp(pitch * 0.7, -0.55, 0.6)
end

local function animate(rig: Rig, dt: number, now: number)
	local humanoid = rig.humanoid
	local root = rig.root
	local model = rig.model
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local vertical = velocity.Y
	local grounded = if rig.mine
		then humanoid.FloorMaterial ~= Enum.Material.Air
		else math.abs(vertical) < 3.5 or root.Anchored
	-- a hard landing jolts the body
	if grounded and rig.lastVertical < -24 then
		rig.landing = math.clamp(-rig.lastVertical / 60, 0.3, 1)
	end
	rig.landing = math.max(rig.landing - dt * 3.2, 0)
	rig.lastVertical = vertical
	local _, yaw = root.CFrame:ToEulerAnglesYXZ()
	local delta = (yaw - rig.lastYaw + math.pi) % (2 * math.pi) - math.pi
	rig.lastYaw = yaw
	rig.turn += ((if dt > 0 then delta / dt else 0) - rig.turn) * math.min(dt * 8, 1)
	if grounded then
		rig.phase += dt * CrewPoses.cadence(speed)
	end

	local style = model:GetAttribute("GrabStyle") :: string?
	local target: CrewPoses.Pose
	local rate = 16
	if style then
		local at = (model:GetAttribute("GrabAt") :: number?) or now
		local struggle = if rig.mine and Registry.GrabController
			then Registry.GrabController.Struggle()
			else 0.55
		target = CrewPoses.grabbed(
			style,
			now - at,
			struggle,
			humanoid.Health / math.max(humanoid.MaxHealth, 1),
			now,
			rig.seed
		)
		rate = 24
	elseif humanoid.Health <= 0 then
		target = CrewPoses.limp(now, rig.seed)
		rate = 6
	else
		local lookYaw, lookPitch = 0, 0
		local trainCam = Registry.TrainCamController
		if rig.mine and not (trainCam and trainCam.Active()) then
			lookYaw, lookPitch = look(root)
		end
		local nearest = if Registry.HollowAnimator
			then Registry.HollowAnimator.Nearest(root.Position)
			else math.huge
		local dread = 1 - math.clamp((nearest - DREAD_NEAR) / (DREAD_FAR - DREAD_NEAR), 0, 1)
		local entry = Registry.StateController.Get({ "crew", tostring(rig.player.UserId) })
		local movement = if rig.mine then Registry.MovementController else nil
		target = CrewPoses.locomote({
			now = now,
			seed = rig.seed,
			speed = speed,
			vertical = vertical,
			grounded = grounded,
			phase = rig.phase,
			sitting = humanoid.Sit,
			load = if entry and entry.load then math.clamp(entry.load / 4, 0, 1) else 0,
			sprinting = if movement then movement.IsSprinting() else speed > 25,
			exhausted = if movement then movement.IsExhausted() else false,
			landing = rig.landing,
			lookYaw = lookYaw,
			lookPitch = lookPitch,
			dread = dread,
			turn = rig.turn,
		})
	end
	if rig.mine then
		stride.phase = rig.phase
		stride.amount = if grounded
				and not humanoid.Sit
				and style == nil
			then math.clamp(speed / 22, 0, 1.3)
			else 0
	end

	local alpha = 1 - math.exp(-rate * dt)
	for name, motor in rig.motors do
		local value = (rig.pose[name] or I):Lerp(target[name] or I, alpha)
		rig.pose[name] = value
		motor.Transform = value
	end
end

function CharacterAnimator.Init() end

function CharacterAnimator.Start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- after the engine's own animation step, so these transforms are the ones drawn
	RunService.Stepped:Connect(function(_, dt: number)
		local now = Workspace:GetServerTimeNow()
		for _, rig in rigs do
			if rig.model.Parent then
				animate(rig, dt, now)
			end
		end
	end)
end

-- Your own stride: its phase (radians) and how hard you are moving (0 still .. 1.3 sprinting).
function CharacterAnimator.Stride(): (number, number)
	return stride.phase, stride.amount
end

return CharacterAnimator
