--!strict
--[[
	Camera feel: impulse shakes with decay, a low rumble that follows hazard
	intensity and train speed (more in tunnels and on bridges), ride sway and
	rail-joint kicks while aboard a moving train, sprint FOV, and the
	spectator subject.

	The camera is reset on every spawn and every phase change: Custom type,
	the humanoid as subject, zoom clamped to Tuning.Camera and a close start,
	so a camera left Scriptable by anything (a test command, a plugin) can
	never stick. With the Camera setting Locked (the default) the zoom is pinned at
	Tuning.Camera.LockZoom: third person, no pinch or wheel zoom, never first person, and the
	body turns to face where the camera looks (AutoRotate off while it does), as in Evade.
	The facing pauses, holding the body still, through a LOOK glance, a Hollow's grip, the
	train camera, spectating, a seat and the lobby idle orbit; it hands AutoRotate back when
	dead, climbing or swimming, or when the setting is Free. On a PC in a run, Locked also holds
	the mouse at the centre so it steers the view with no button held; Left Alt frees it, and
	every menu frees it while open (Ui.freeCursor).
]]

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CameraFacing = require(Shared.Logic.CameraFacing)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local MathX = require(Shared.Util.MathX)
local Tuning = require(Shared.Config.Tuning)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)

local CameraController = {}

local CAM = Tuning.Camera
local TRAIN_MIN_X, TRAIN_MAX_X = -97, 97

local trauma = 0
local timedKick = 0
local timedKickAmount = 0
local timedKickLeft = 0
local timedKickDuration = 0
local fov = 70
local throb = 0 -- a heartbeat's squeeze, decaying
local THROB_FOV = 2.6 -- degrees the view narrows at a full throb
local spectateTarget: Player? = nil
local resetSerial = 0
local focusPoint: Vector3? = nil -- a point the view is dragged toward (a Hollow's face, in its grip)
local BOB_DROP = 0.12 -- studs the view dips at each footfall in first person
local BOB_SWAY = 0.04 -- studs it sways side to side with the stride

-- The train's skin is non-colliding mesh over invisible colliding walls, and Roblox's own
-- occlusion skips both (it wants opaque and colliding), so the third-person view went
-- through the walls. Each frame the view is pulled in front of any colliding train part.
local WALL_MARGIN = 0.6 -- studs kept between the view and the wall
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
wallParams.RespectCanCollide = true
local displayTrain: Instance? = nil
local displayLookAt = 0

local function ownHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- The zoom range the Camera setting allows: one distance when Locked, else MinZoom..MaxZoom.
local function zoomRange(): (number, number)
	if Players.LocalPlayer:GetAttribute("Camera") == "Free" then
		return CAM.MinZoom, CAM.MaxZoom
	end
	return CAM.LockZoom, CAM.LockZoom
end

local function applyZoom()
	local player = Players.LocalPlayer
	player.CameraMinZoomDistance, player.CameraMaxZoomDistance = zoomRange()
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
		applyZoom()
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
			applyZoom()
		end
	end)
end

local function onCharacter(character: Model)
	character:WaitForChild("Humanoid", 10)
	resetCamera(true)
end

-- How far to pull the view in so it stays this side of the train's walls (0 when clear).
local function wallPull(camera: Camera): number
	local trains: { Instance } = {}
	local run = Workspace:FindFirstChild("Train")
	if run then
		table.insert(trains, run)
	end
	if (displayTrain == nil or displayTrain.Parent == nil) and os.clock() >= displayLookAt then
		displayLookAt = os.clock() + 2
		displayTrain = Workspace:FindFirstChild("DisplayTrain", true)
	end
	if displayTrain and displayTrain.Parent then
		table.insert(trains, displayTrain)
	end
	if #trains == 0 then
		return 0
	end
	local focus = camera.Focus.Position
	local span = camera.CFrame.Position - focus
	local distance = span.Magnitude
	if distance < 1 then
		return 0 -- first person
	end
	wallParams.FilterDescendantsInstances = trains
	local hit = Workspace:Raycast(focus, span, wallParams)
	if hit == nil then
		return 0
	end
	return math.max(distance - math.max(hit.Distance - WALL_MARGIN, 0.5), 0)
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
	local glanceHeld = false
	local glance = 0
	local function canGlance(): boolean
		local character = Players.LocalPlayer.Character
		local humanoid = ownHumanoid()
		local blocked = Session.phase() == "Lobby"
			or character == nil
			or character:GetAttribute("GrabStyle") ~= nil
			or humanoid == nil
			or humanoid.Health <= 0
			or Workspace.CurrentCamera.CameraType ~= Enum.CameraType.Custom
			or spectateTarget ~= nil
			or UserInputService:GetFocusedTextBox() ~= nil
		return not blocked
	end
	ContextActionService:BindAction("LTO_Glance", function(_, state)
		if not canGlance() then
			glanceHeld = false
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			glanceHeld = UserInputService:GetFocusedTextBox() == nil
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			glanceHeld = false
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonR1)
	ContextActionService:SetTitle("LTO_Glance", "LOOK")
	-- LOOK does nothing in the hall, so its touch button only shows to a crew member in a run
	RunService.Heartbeat:Connect(function()
		local lookButton = ContextActionService:GetButton("LTO_Glance")
		if lookButton then
			lookButton.Visible = Session.isMember()
		end
		local pingButton = ContextActionService:GetButton("LTO_Ping") -- the ping is never in the hall either
		if pingButton then
			pingButton.Visible = Session.isMember()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		glanceHeld = false
	end)
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("Camera"):Connect(applyZoom)
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
	-- before player controls read camera-relative movement, then re-apply after the camera.
	local applied = CFrame.identity
	RunService:BindToRenderStep("LTO_CameraUnshake", Enum.RenderPriority.Input.Value - 1, function()
		if applied ~= CFrame.identity then
			local camera = Workspace.CurrentCamera
			camera.CFrame *= applied:Inverse()
			applied = CFrame.identity
		end
	end)

	-- Locked camera: the body faces the view. `facing` means this module turned AutoRotate off
	-- and owes it back; a pause keeps it off so the body holds still instead of turning to walk.
	local facing = false
	local function release()
		if facing then
			facing = false
			local humanoid = ownHumanoid()
			if humanoid then
				humanoid.AutoRotate = true
			end
		end
	end
	player:GetAttributeChangedSignal("Camera"):Connect(release)
	player.CharacterAdded:Connect(function()
		facing = false -- a new humanoid starts with AutoRotate on
	end)
	local function faceBody(camera: Camera, dt: number)
		local character = player.Character
		local humanoid = ownHumanoid()
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local state = humanoid and humanoid:GetState()
		if
			player:GetAttribute("Camera") == "Free"
			or humanoid == nil
			or root == nil
			or humanoid.Health <= 0
			or state == Enum.HumanoidStateType.Climbing
			or state == Enum.HumanoidStateType.Swimming
			or state == Enum.HumanoidStateType.Dead
		then
			release()
			return
		end
		local trainCam = Registry.TrainCamController
		local idle = Registry.LobbyIdleController
		if
			glance > 0
			or focusPoint ~= nil
			or spectateTarget ~= nil
			or camera.CameraType ~= Enum.CameraType.Custom
			or camera.CameraSubject ~= humanoid
			or humanoid.Sit
			or humanoid.PlatformStand
			or (character :: Model):GetAttribute("GrabStyle") ~= nil
			or (trainCam and trainCam.Active())
			or (idle and idle.Orbiting())
		then
			return
		end
		local look = camera.CFrame.LookVector
		local target = CameraFacing.yaw(look.X, look.Z)
		if target == nil then
			return
		end
		facing = true
		humanoid.AutoRotate = false
		local now = root.CFrame.LookVector
		local current = CameraFacing.yaw(now.X, now.Z) or target
		local yaw = CameraFacing.turn(current, target, dt, CAM.FaceTurnRate)
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	end

	-- Locked on a PC in a run: the mouse is held at the centre and steers the view without a
	-- held button, as in Evade. Left Alt frees it while held; menus free it themselves
	-- (Ui.freeCursor, GuiButton.Modal). The hall, the train camera, a grab and spectating keep
	-- their own mouse. `mouseHeld` means this module locked it and owes it back.
	local mouseHeld = false
	local function holdMouse(camera: Camera)
		local humanoid = ownHumanoid()
		local character = player.Character
		local trainCam = Registry.TrainCamController
		local want = player:GetAttribute("Camera") ~= "Free"
			and UserInputService.MouseEnabled
			and Session.isMember()
			and humanoid ~= nil
			and humanoid.Health > 0
			and camera.CameraType == Enum.CameraType.Custom
			and camera.CameraSubject == humanoid
			and spectateTarget == nil
			and (character :: Model):GetAttribute("GrabStyle") == nil
			and not (trainCam and trainCam.Active())
			and UserInputService:GetFocusedTextBox() == nil
			and not UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
		if want then
			mouseHeld = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		elseif mouseHeld then
			mouseHeld = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end

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
		if timedKickLeft > 0 then
			timedKickLeft = math.max(timedKickLeft - dt, 0)
			timedKick = timedKickAmount
				* if timedKickDuration > 0 then timedKickLeft / timedKickDuration else 0
		else
			timedKick = 0
			timedKickAmount = 0
		end
		local shake = trauma * trauma + timedKick * timedKick + rumble
		local t = os.clock()
		local offset = CFrame.identity
		if camera.CameraType == Enum.CameraType.Custom then
			local pull = wallPull(camera)
			if pull > 0 then
				offset = CFrame.new(0, 0, -pull)
			end
		end
		if shake > 0.001 then
			offset *= CFrame.Angles(
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

		if not canGlance() then
			glanceHeld = false
			glance = 0
		else
			local goal = if glanceHeld then 1 else 0
			local step = dt / CAM.GlanceSeconds
			glance += math.clamp(goal - glance, -step, step)
		end
		-- before this frame's shake and glance go on, so the body follows the steady view
		faceBody(camera, dt)
		holdMouse(camera)
		-- View-only yaw: never change Humanoid movement or the character's root facing.
		offset *= CFrame.Angles(0, math.rad(CAM.GlanceDegrees) * glance, 0)
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

-- A local camera impulse with an explicit lifetime, used for short success cues.
function CameraController.ShakeFor(amount: number, duration: number)
	timedKickAmount = math.max(timedKickAmount, amount)
	timedKick = timedKickAmount
	timedKickDuration = math.max(duration, 0)
	timedKickLeft = timedKickDuration
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
