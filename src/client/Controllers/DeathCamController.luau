--!strict
--[[
	The dead player's witness view (Config/Injury Witness), behind the limb-loss flag.

	Death is already committed on the server; this only borrows the dead player's own camera
	for at most Witness.Seconds, framing the body from where they were looking, then hands it
	back to the existing spectate flow (CameraController) or the report. A living player's
	camera is never touched.

	Skip with the usual confirm (Space, ButtonA, a click or a tap) from Witness.SkipAfter. The
	Motion setting "Reduced" holds the frame still instead of the slow push-in.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Injury)

local DeathCamController = {}

local STEP = "DeathCam"
local ACTION = "DeathCamSkip"
local W = Config.Witness

local running = false

local function stop()
	if not running then
		return
	end
	running = false
	RunService:UnbindFromRenderStep(STEP)
	ContextActionService:UnbindAction(ACTION)
	local camera = Workspace.CurrentCamera
	if camera and camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function witness(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = Workspace.CurrentCamera
	if root == nil or camera == nil or running then
		return
	end
	running = true
	local startedAt = os.clock()
	local reduced = Players.LocalPlayer:GetAttribute("Motion") == "Reduced"
	-- from where they were looking, a little higher, never further than the camera already was
	local focus = root.Position
	local back = camera.CFrame.Position - focus
	local flat = Vector3.new(back.X, 0, back.Z)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else -root.CFrame.LookVector
	local distance = math.clamp(back.Magnitude, 6, 12)
	local from = focus + dir * distance + Vector3.yAxis * 4
	local to = focus + dir * (distance * 0.75) + Vector3.yAxis * 3
	ContextActionService:BindActionAtPriority(
		ACTION,
		function(_, state)
			if state == Enum.UserInputState.Begin and os.clock() - startedAt >= W.SkipAfter then
				stop()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 120,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA,
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.Touch
	)
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 2, function()
		local age = os.clock() - startedAt
		if age >= W.Seconds or character.Parent == nil then
			stop()
			return
		end
		local u = if reduced then 0 else age / W.Seconds
		local eased = u * u * (3 - 2 * u)
		local body = character:FindFirstChild("Torso") :: BasePart?
		local look = if body then body.Position else focus
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(from:Lerp(to, eased), look)
	end)
end

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid == nil then
		return
	end
	humanoid.Died:Connect(function()
		if
			ReplicatedStorage:GetAttribute("LimbLoss") == true
			and Players.LocalPlayer.Character == character
		then
			-- after the grab's own camera release on the same frame
			task.defer(witness, character)
		end
	end)
end

function DeathCamController.Init() end

function DeathCamController.Start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character)
		stop()
		watch(character)
	end)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

return DeathCamController
