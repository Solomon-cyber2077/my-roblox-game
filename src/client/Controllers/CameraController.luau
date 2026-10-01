--!strict
--[[
	Camera feel: impulse shakes with decay, a low rumble that follows hazard
	intensity and train speed, sprint FOV, and the spectator subject.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local MathX = require(Shared.Util.MathX)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)

local CameraController = {}

local trauma = 0
local fov = 70
local spectateTarget: Player? = nil

function CameraController.Init() end

function CameraController.Start()
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

	RunService:BindToRenderStep("LTO_CameraFeel", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = Workspace.CurrentCamera
		local phase = Session.phase()
		local station = Registry.StateController.Get({ "run", "station" })

		-- Ambient rumble: hazard tension at a station, wheels on the rails while moving.
		local rumble = 0
		if station and (phase == "Dwell" or phase == "LastCall" or phase == "Departure") then
			rumble = HazardSchedule.intensity(station.hazards, Session.now() - station.startedAt) * 0.12
		end
		local speed = if Registry.SceneryController then Registry.SceneryController.Speed() else 0
		rumble += math.min(speed / 110, 1) * 0.05

		trauma = math.max(trauma - dt * 1.4, 0)
		local shake = trauma * trauma + rumble
		if shake > 0.001 then
			local t = os.clock()
			applied = CFrame.Angles(
				math.rad((math.noise(t * 12, 1) * 2) * shake),
				math.rad((math.noise(t * 12, 2) * 2) * shake),
				math.rad((math.noise(t * 12, 3) * 1.5) * shake)
			)
			camera.CFrame *= applied
		end

		local sprinting = Registry.MovementController and Registry.MovementController.IsSprinting()
		local target = 70
			+ (if sprinting then 7 else 0)
			+ (if phase == "LastCall" or phase == "Departure" then 3 else 0)
		fov = MathX.lerp(fov, target, MathX.damp(0.12, dt))
		camera.FieldOfView = fov
	end)
end

-- Adds a one-off shake. 0.3 is a nudge, 1 is a heavy hit.
function CameraController.Shake(amount: number)
	trauma = math.min(trauma + amount, 1.2)
end

function CameraController.SetSpectateTarget(player: Player?)
	spectateTarget = player
	local camera = Workspace.CurrentCamera
	local subject: Instance? = nil
	if player and player.Character then
		subject = player.Character:FindFirstChildOfClass("Humanoid")
	end
	if subject == nil then
		local own = Players.LocalPlayer.Character
		subject = own and own:FindFirstChildOfClass("Humanoid")
	end
	if subject then
		camera.CameraSubject = subject
	end
end

function CameraController.SpectateTarget(): Player?
	return spectateTarget
end

return CameraController
