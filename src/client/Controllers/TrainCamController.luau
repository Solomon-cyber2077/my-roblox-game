--!strict
--[[
	The train camera. From aboard, press C (gamepad D-pad up, or the chip by the
	backpack) to step out of the carriage's windows and watch the train itself run through
	the night from outside. F (D-pad right) cuts to the next shot:

	  Orbit      free: drag to swing round the train, scroll (or the triggers) to close in
	  Lineside   low beside the track as the engine runs at you, rods flailing
	  Chase      riding high behind the brake van, the whole consist ahead
	  Footplate  over the boiler, down the line into the dark
	  Aerial     far above the train and the country it crosses
	  Moon       low on the far side, the train small under the moon (telephoto)

	In a tunnel every shot gives way to a tight one inside the bore. Your character stays
	in their seat (or where they stand) and cannot walk away while you watch; C again
	brings you back, and it closes by itself when you leave the train.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local TrainFraming = require(script.Parent.Parent.Camera.TrainFraming)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Safe = require(ReplicatedStorage.Shared.Util.Safe)

type Shot = { name: string, fov: number }

local TrainCamController = {}

local SHOTS: { Shot } = {
	{ name = "Orbit", fov = 62 },
	{ name = "Lineside", fov = 52 },
	{ name = "Chase", fov = 58 },
	{ name = "Footplate", fov = 66 },
	{ name = "Aerial", fov = 50 },
	{ name = "Moon", fov = 34 },
}
local CENTER = Vector3.new(0, 6, 0) -- the train's middle (it never moves)
local C = Tuning.TrainCamera
local ORBIT_NEAR, ORBIT_FAR = C.OrbitNear, C.OrbitFar
local IGNORE_FOLDERS = {
	"Train",
	"Hollows",
	"Heavens",
	"Scenery",
	"Weather",
	"Rain",
	"ClientEffects",
	"HollowFx",
	"StationEffects",
}

local active = false
local shotIndex = 1
local yaw, pitch, distance = math.rad(35), math.rad(16), 125
local current: CFrame? = nil
local currentFov = 62
local dragging = false
local chip: TextButton
local bar: Frame
local barLabel: TextLabel
local nextButton: TextButton
local backButton: TextButton
local zoomIn: TextButton
local zoomOut: TextButton
local savedMouse = Enum.MouseBehavior.Default
local savedCursor = true
local savedFov = 70
local touch: InputObject? = nil
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function aboard(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return Session.isRunActive()
		and Session.status() == "Aboard"
		and humanoid ~= nil
		and humanoid.Health > 0
		and character:GetAttribute("GrabStyle") == nil
end

local function refreshFilter()
	local ignore: { Instance } = {}
	for _, name in IGNORE_FOLDERS do
		local child = Workspace:FindFirstChild(name)
		if child then
			table.insert(ignore, child)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
end

local function label()
	local shot = SHOTS[shotIndex]
	local last = UserInputService:GetLastInputType()
	local pad = last == Enum.UserInputType.Gamepad1
	local mobile = last == Enum.UserInputType.Touch
	barLabel.Text = `TRAIN CAMERA  ·  {string.upper(shot.name)}`
	nextButton.Text = if mobile then "NEXT SHOT" elseif pad then "NEXT  [→]" else "NEXT  [F]"
	backButton.Text = if mobile then "BACK" elseif pad then "BACK  [↑]" else "BACK  [C]"
	zoomIn.Visible = shot.name == "Orbit"
	zoomOut.Visible = shot.name == "Orbit"
end

local function nextShot()
	shotIndex = shotIndex % #SHOTS + 1
	current = nil -- a cut must not sweep the lens through the carriage or station walls
	label()
end

local function setActive(on: boolean)
	if on == active then
		return
	end
	active = on
	local camera = Workspace.CurrentCamera
	local movement = Registry.MovementController
	if on then
		current = nil
		currentFov = camera.FieldOfView
		savedFov = camera.FieldOfView
		savedMouse = UserInputService.MouseBehavior
		savedCursor = UserInputService.MouseIconEnabled
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		camera.CameraType = Enum.CameraType.Scriptable
		if movement then
			movement.SetFrozen(true)
		end
		refreshFilter()
		label()
		bar.Visible = true
		ContextActionService:BindAction("LTO_TrainCamNext", function(_, state)
			if state == Enum.UserInputState.Begin then
				nextShot()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.F, Enum.KeyCode.DPadRight)
	else
		ContextActionService:UnbindAction("LTO_TrainCamNext")
		bar.Visible = false
		dragging = false
		touch = nil
		UserInputService.MouseBehavior = savedMouse
		UserInputService.MouseIconEnabled = savedCursor
		camera.FieldOfView = savedFov
		camera.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		if movement then
			movement.SetFrozen(false)
		end
	end
end

local function toggle()
	if active then
		setActive(false)
	elseif aboard() then
		setActive(true)
	end
end

-- Where a shot puts the camera this moment, and what it looks at.
local function framing(shot: Shot, now: number, tunnel: number): (Vector3, Vector3, number?)
	if tunnel > 0.4 then
		-- inside the bore: tight behind the brake van, looking along the train to the light ahead
		return Vector3.new(-122, 11, 2.5), Vector3.new(30, 6, 0)
	end
	local name = shot.name
	if name == "Orbit" then
		local offset = Vector3.new(
			math.cos(pitch) * math.sin(yaw),
			math.sin(pitch),
			math.cos(pitch) * math.cos(yaw)
		) * distance
		return CENTER + offset, CENTER
	elseif name == "Lineside" then
		-- a hand-held drift, low by the platform side of the line, the engine coming on
		local sway =
			Vector3.new(math.sin(now * 0.3) * 3, math.sin(now * 0.47) * 0.6, math.sin(now * 0.23) * 2)
		return Vector3.new(150, 3.5, 30) + sway, Vector3.new(60, 5, 0)
	elseif name == "Chase" then
		local bob = math.sin(now * 0.5) * 2
		return Vector3.new(-190, 36 + bob, 28), Vector3.new(20, 2, 0)
	elseif name == "Footplate" then
		return Vector3.new(57, 15.2, 0.5), Vector3.new(420, 4, 0)
	elseif name == "Aerial" then
		local drift = now * 0.04
		return Vector3.new(math.cos(drift) * 120, 300, 180 + math.sin(drift) * 60), Vector3.new(20, 0, 0)
	end
	-- the moon: from low on the far side of the train, looking past it up at the moon
	local moon = if Registry.AtmosphereController then Registry.AtmosphereController.Moon() else nil
	local direction = if moon and moon.visible > 0.2
		then moon.direction
		else Vector3.new(0.2, 0.25, 0.95).Unit
	local viewport = Workspace.CurrentCamera.ViewportSize
	return TrainFraming.moon(
		CENTER,
		direction,
		if moon then moon.size else 11,
		viewport.X / math.max(viewport.Y, 1)
	)
end

local function frame(dt: number)
	if not active then
		return
	end
	if not aboard() then
		setActive(false)
		return
	end
	local camera = Workspace.CurrentCamera
	local shot = SHOTS[shotIndex]
	local now = Workspace:GetServerTimeNow()
	local context = if Registry.SceneryController then Registry.SceneryController.Context() else nil
	local tunnel = if context then context.tunnel else 0
	local eye, focus, dynamicFov = framing(shot, now, tunnel)
	-- nothing solid (a station's buildings) may stand between the train and the lens
	local from = if tunnel > 0.4 then Vector3.new(0, 10, 0) else CENTER
	local hit = Workspace:Raycast(from, eye - from, rayParams)
	if hit then
		eye = hit.Position + (from - eye).Unit * 2
	end
	local want = CFrame.lookAt(eye, focus)
	local blend = 1 - math.exp(-dt * (if shot.name == "Orbit" and tunnel <= 0.4 then 12 else 3.2))
	current = if current then (current :: CFrame):Lerp(want, blend) else want
	camera.CFrame = current :: CFrame
	camera.Focus = CFrame.new(focus)
	currentFov += ((dynamicFov or shot.fov) - currentFov) * (1 - math.exp(-dt * 3))
	camera.FieldOfView = currentFov
end

function TrainCamController.Init() end

function TrainCamController.Start()
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = Ui.new("ScreenGui", {
		Name = "TrainCamera",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = gui,
	})
	chip = Ui.button("TRAIN CAMERA  [C]", "Secondary", toggle, {
		Name = "TrainCamChip",
		Size = UDim2.fromOffset(176, 44),
		Position = UDim2.new(1, -16, 1, -236), -- clear above the pocket watch's bow
		AnchorPoint = Vector2.new(1, 1),
		TextSize = 14,
	})
	chip.Visible = false
	chip.Parent = screen
	bar = Ui.panel({
		Name = "TrainCamBar",
		-- stops short of the HUD's pocket watch in the bottom right
		Size = UDim2.new(1, -240, 0, 82),
		Position = UDim2.new(0.5, -104, 1, -112),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = screen,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(540, 82), Parent = bar })
	barLabel = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 15,
		Color = Theme.Color.brassLight,
		Size = UDim2.new(1, 0, 0, 28),
		XAlign = Enum.TextXAlignment.Center,
	})
	barLabel.Parent = bar
	nextButton = Ui.button("NEXT  [F]", "Secondary", nextShot, {
		Size = UDim2.new(0.5, -61, 0, 40),
		Position = UDim2.fromOffset(52, 34),
		TextSize = 14,
	})
	nextButton.Parent = bar
	backButton = Ui.button("BACK  [C]", "Secondary", toggle, {
		Size = UDim2.new(0.5, -61, 0, 40),
		Position = UDim2.new(0.5, 9, 0, 34),
		TextSize = 14,
	})
	backButton.Parent = bar
	zoomOut = Ui.button("−", "Secondary", function()
		distance = math.clamp(distance * 1.15, ORBIT_NEAR, ORBIT_FAR)
	end, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(6, 34), TextSize = 22 })
	zoomOut.Parent = bar
	zoomIn = Ui.button("+", "Secondary", function()
		distance = math.clamp(distance / 1.15, ORBIT_NEAR, ORBIT_FAR)
	end, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -46, 0, 34), TextSize = 22 })
	zoomIn.Parent = bar
	UserInputService.LastInputTypeChanged:Connect(function()
		if active then
			label()
		end
	end)

	ContextActionService:BindAction("LTO_TrainCam", function(_, state)
		if state == Enum.UserInputState.Begin and (active or aboard()) then
			toggle()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.C, Enum.KeyCode.DPadUp)

	-- orbit: drag with either mouse button or a finger, scroll or the triggers to zoom
	UserInputService.InputBegan:Connect(function(input, processed)
		if not active or processed then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch and touch ~= nil then
			return
		end
		if
			kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.MouseButton2
			or kind == Enum.UserInputType.Touch
		then
			dragging = true
			if kind == Enum.UserInputType.Touch then
				touch = input
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch and input ~= touch then
			return
		end
		if
			kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.MouseButton2
			or kind == Enum.UserInputType.Touch
		then
			dragging = false
			if input == touch then
				touch = nil
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not active or SHOTS[shotIndex].name ~= "Orbit" then
			return
		end
		local kind = input.UserInputType
		if dragging and (kind == Enum.UserInputType.MouseMovement or input == touch) then
			yaw -= input.Delta.X * 0.006
			pitch = math.clamp(pitch + input.Delta.Y * 0.005, math.rad(-4), math.rad(70))
		elseif kind == Enum.UserInputType.MouseWheel then
			distance = math.clamp(distance * (1 - input.Position.Z * 0.12), ORBIT_NEAR, ORBIT_FAR)
		end
	end)

	-- after the player camera and CameraController's feel, so the shot is what is drawn
	RunService:BindToRenderStep("LTO_TrainCam", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		if active and SHOTS[shotIndex].name == "Orbit" and UserInputService.GamepadEnabled then
			local gamepad = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
			for _, state in gamepad do
				if state.KeyCode == Enum.KeyCode.Thumbstick2 then
					local stick = state.Position
					if stick.Magnitude > C.GamepadDeadzone then
						yaw -= stick.X * C.GamepadYaw * dt
						pitch = math.clamp(pitch + stick.Y * C.GamepadPitch * dt, math.rad(-4), math.rad(70))
					end
				elseif state.KeyCode == Enum.KeyCode.ButtonR2 and state.Position.Z > 0.1 then
					distance =
						math.clamp(distance - dt * C.ZoomSpeed * state.Position.Z, ORBIT_NEAR, ORBIT_FAR)
				elseif state.KeyCode == Enum.KeyCode.ButtonL2 and state.Position.Z > 0.1 then
					distance =
						math.clamp(distance + dt * C.ZoomSpeed * state.Position.Z, ORBIT_NEAR, ORBIT_FAR)
				end
			end
		end
		Safe.call("TrainCamController.frame", frame, dt)
	end)
	RunService.Heartbeat:Connect(function()
		chip.Visible = aboard() and not active
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		setActive(false)
	end)
end

function TrainCamController.Active(): boolean
	return active
end

return TrainCamController
