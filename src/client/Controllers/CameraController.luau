--!strict
--[[
	Camera feel: impulse shakes with decay, a low rumble that follows hazard
	intensity and train speed (more in tunnels and on bridges), ride sway and
	rail-joint kicks while aboard a moving train, sprint FOV, and the
	spectator subject.

	The camera is reset on every spawn and every phase change: Custom type,
	the humanoid as subject, zoom clamped to Tuning.Camera and a close start,
	so a camera left Scriptable by anything (a test command, a plugin) can
	never stick.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local MathX = require(Shared.Util.MathX)
local Tuning = require(Shared.Config.Tuning)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)

local CameraController = {}

local CAM = Tuning.Camera
local TRAIN_MIN_X, TRAIN_MAX_X = -97, 97

local trauma = 0
local fov = 70
local throb = 0 -- a heartbeat's squeeze, decaying
local THROB_FOV = 2.6 -- degrees the view narrows at a full throb
local spectateTarget: Player? = nil
local resetSerial = 0
local focusPoint: Vector3? = nil -- a point the view is dragged toward (a Hollow's face, in its grip)
local BOB_DROP = 0.12 -- studs the view dips at each footfall in first person
local BOB_SWAY = 0.04 -- studs it sways side to side with the stride

local function ownHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Puts the camera back in the default player camera, following us, at a close zoom.
local function resetCamera(pinZoom: boolean)
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	if spectateTarget == nil then
		local humanoid = ownHumanoid()
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	player.CameraMode = Enum.CameraMode.Classic
	if not pinZoom then
		player.CameraMinZoomDistance = CAM.MinZoom
		player.CameraMaxZoomDistance = CAM.MaxZoom
		return
	end
	-- Pinning min = max for a frame makes the camera module adopt the start zoom.
	resetSerial += 1
	local serial = resetSerial
	player.CameraMinZoomDistance = CAM.StartZoom
	player.CameraMaxZoomDistance = CAM.StartZoom
	task.spawn(function()
		RunService.RenderStepped:Wait()
		RunService.RenderStepped:Wait()
		if serial == resetSerial then
			player.CameraMinZoomDistance = CAM.MinZoom
			player.CameraMaxZoomDistance = CAM.MaxZoom
		end
	end)
end

local function onCharacter(character: Model)
	character:WaitForChild("Humanoid", 10)
	resetCamera(true)
end

-- True while our character stands inside the train's body.
local function aboard(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return false
	end
	local p = root.Position
	return p.X > TRAIN_MIN_X and p.X < TRAIN_MAX_X and math.abs(p.Z) < 7.5 and p.Y > -2 and p.Y < 14
end

function CameraController.Init() end

function CameraController.Start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	Registry.StateController.Observe("public", { "run", "phase" }, function()
		local trainCam = Registry.TrainCamController
		if
			Workspace.CurrentCamera.CameraType ~= Enum.CameraType.Custom
			and not (trainCam and trainCam.Active())
		then
			resetCamera(false)
		end
	end)

	-- The default camera reads Camera.CFrame to find its look direction, so a
	-- shake left in place would accumulate into drift. Remove last frame's offset
	-- before the camera module runs, and re-apply a fresh one after it.
	local applied = CFrame.identity
	RunService:BindToRenderStep("LTO_CameraUnshake", Enum.RenderPriority.Camera.Value - 1, function()
		if applied ~= CFrame.identity then
			local camera = Workspace.CurrentCamera
			camera.CFrame *= applied:Inverse()
			applied = CFrame.identity
		end
	end)

	local lastJoint = 0
	local secondKickAt = math.huge
	local kick = 0
	RunService:BindToRenderStep("LTO_CameraFeel", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = Workspace.CurrentCamera
		local phase = Session.phase()
		local station = Registry.StateController.Get({ "run", "station" })
		local scenery = Registry.SceneryController
		local speed = if scenery then scenery.Speed() else 0
		local pace = math.min(speed / Tuning.Motion.CruiseSpeed, 1)
		local context = if scenery then scenery.Context() else nil

		-- Ambient rumble: hazard tension at a station, wheels on the rails while moving.
		local rumble = 0
		if station and (phase == "Dwell" or phase == "LastCall" or phase == "Departure") then
			rumble = HazardSchedule.intensity(station.hazards, Session.now() - station.startedAt) * 0.12
		end
		local echo = if context then 1 + 0.6 * context.tunnel + 0.4 * context.bridge else 1
		rumble += pace * 0.05 * echo

		trauma = math.max(trauma - dt * 1.4, 0)
		local shake = trauma * trauma + rumble
		local t = os.clock()
		local offset = CFrame.identity
		if shake > 0.001 then
			offset = CFrame.Angles(
				math.rad((math.noise(t * 12, 1) * 2) * shake),
				math.rad((math.noise(t * 12, 2) * 2) * shake),
				math.rad((math.noise(t * 12, 3) * 1.5) * shake)
			)
		end

		-- Ride sway and rail joints, only while riding a moving train.
		if scenery and speed > 3 and aboard() then
			local odometer = scenery.Odometer()
			local joint = math.floor(odometer / CAM.RailLength)
			if joint ~= lastJoint then
				lastJoint = joint
				kick = 1
				secondKickAt = joint * CAM.RailLength + CAM.BogieGap
			elseif odometer >= secondKickAt then
				secondKickAt = math.huge
				kick = math.max(kick, 0.6)
			end
			local roll = math.noise(t * 0.55, 7.3) * 2 * CAM.SwayRoll * pace
			local pitch = -CAM.JointKick * kick * pace * echo
			offset *= CFrame.new(0, -0.04 * kick * pace, 0) * CFrame.Angles(
				math.rad(pitch),
				0,
				math.rad(roll)
			)
		end
		kick *= math.exp(-dt * 16)

		-- the view bobs with your steps: plainly in first person, barely over the shoulder
		local animator = Registry.CharacterAnimator
		if animator and camera.CameraType == Enum.CameraType.Custom then
			local stepPhase, amount = animator.Stride()
			if amount > 0.05 then
				local close = (camera.Focus.Position - camera.CFrame.Position).Magnitude < 1.5
				local scale = amount * (if close then 1 else 0.25)
				offset *= CFrame.new(
					math.cos(stepPhase) * BOB_SWAY * scale,
					-math.abs(math.sin(stepPhase)) * BOB_DROP * scale,
					0
				) * CFrame.Angles(0, 0, math.cos(stepPhase) * 0.005 * scale)
			end
		end

		if offset ~= CFrame.identity then
			applied = offset
			camera.CFrame *= applied
		end

		-- in a Hollow's grip the view is dragged round to its face
		local point = focusPoint
		if point and camera.CameraType == Enum.CameraType.Custom then
			local from = camera.CFrame
			camera.CFrame = from:Lerp(CFrame.lookAt(from.Position, point), 1 - math.exp(-dt * 2.4))
		end

		local sprinting = Registry.MovementController and Registry.MovementController.IsSprinting()
		local target = 70
			+ (if sprinting then 7 else 0)
			+ (if phase == "LastCall" or phase == "Departure" then 3 else 0)
		fov = MathX.lerp(fov, target, MathX.damp(0.12, dt))
		-- a heartbeat squeezes the view for an instant
		throb *= math.exp(-dt * 9)
		camera.FieldOfView = fov - THROB_FOV * throb
	end)
end

-- Adds a one-off shake. 0.3 is a nudge, 1 is a heavy hit.
function CameraController.Shake(amount: number)
	trauma = math.min(trauma + amount, 1.2)
end

-- Drags the view toward `point` every frame until it is cleared with nil.
function CameraController.Focus(point: Vector3?)
	focusPoint = point
end

-- A heartbeat's throb (0..1): the view narrows for an instant and eases back.
function CameraController.Pulse(amount: number)
	throb = math.max(throb, math.min(amount, 1))
end

function CameraController.SetSpectateTarget(player: Player?)
	spectateTarget = player
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local subject: Instance? = nil
	if player and player.Character then
		subject = player.Character:FindFirstChildOfClass("Humanoid")
	end
	if subject == nil then
		subject = ownHumanoid()
	end
	if subject then
		camera.CameraSubject = subject
	end
end

function CameraController.SpectateTarget(): Player?
	return spectateTarget
end

return CameraController
