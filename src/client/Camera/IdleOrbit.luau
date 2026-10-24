--!strict
--[[
	The lobby idle view's slow turn (docs/direction/2026-10-23_lobby-idle-final.md, prompt 4).

	It never takes the camera: the camera stays Custom and the player module keeps it. Before
	the camera module runs, the orbit turns Camera.CFrame round the focus by this frame's share of
	LobbyIdle.orbitAngle, which the module reads as its look direction (the same way a stray
	offset becomes drift, see CameraController's unshake). Distance, pitch and FOV are left
	alone, so it starts from the current view without a jump and stopping leaves the view where
	it is, with the player's next input working from there. After the camera (and
	CameraController's train wall pull) it asks IdleClearance where the view may sit: it pulls
	in at once, and cancels when no pose is clear.

	Begin refuses unless the camera is Custom on our own living humanoid, the Camera setting is
	Free, the view is third person and neither VR nor reduced motion is on. It cancels itself when
	the camera type, subject, FOV or viewport changes. Cancel is idempotent.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local LobbyIdle = require(Shared.Logic.LobbyIdle)
local Safe = require(Shared.Util.Safe)
local Tuning = require(Shared.Config.Tuning)

local IdleClearance = require(script.Parent.IdleClearance)

local IDLE = Tuning.LobbyIdle
local TURN_STEP = "LTO_IdleOrbitTurn"
local CLEAR_STEP = "LTO_IdleOrbitClear"
local FIRST_PERSON = 1.5 -- studs from the focus; closer is first person

local IdleOrbit = {}

export type Orbit = {
	Begin: (self: Orbit) -> boolean,
	Active: (self: Orbit) -> boolean,
	Cancel: (self: Orbit) -> (),
}

local function ownHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function IdleOrbit.new(clearance: IdleClearance.Clearance): Orbit
	local active = false
	local startedAt = 0
	local turned = 0
	local subject: Instance? = nil
	local fov = 0
	local viewport = Vector2.zero

	local orbit = {} :: Orbit

	function orbit:Active(): boolean
		return active
	end

	function orbit:Cancel()
		if not active then
			return
		end
		active = false
		RunService:UnbindFromRenderStep(TURN_STEP)
		RunService:UnbindFromRenderStep(CLEAR_STEP)
		clearance:Reset()
	end

	local function changed(camera: Camera): boolean
		return camera.CameraType ~= Enum.CameraType.Custom
			or camera.CameraSubject ~= subject
			or camera.FieldOfView ~= fov
			or camera.ViewportSize ~= viewport
	end

	function orbit:Begin(): boolean
		if active then
			return true
		end
		local camera = Workspace.CurrentCamera
		local humanoid = ownHumanoid()
		if
			camera == nil
			or humanoid == nil
			or humanoid.Health <= 0
			or camera.CameraType ~= Enum.CameraType.Custom
			or camera.CameraSubject ~= humanoid
			or Players.LocalPlayer:GetAttribute("Camera") ~= "Free"
			or UserInputService.VREnabled
			or GuiService.ReducedMotionEnabled
			or (camera.CFrame.Position - camera.Focus.Position).Magnitude < FIRST_PERSON
		then
			return false
		end
		active = true
		startedAt = os.clock()
		turned = 0
		subject = humanoid
		fov = camera.FieldOfView
		viewport = camera.ViewportSize
		clearance:Reset()

		RunService:BindToRenderStep(TURN_STEP, Enum.RenderPriority.Camera.Value - 1, function()
			Safe.call("IdleOrbit.turn", function()
				local cam = Workspace.CurrentCamera
				if changed(cam) or GuiService.ReducedMotionEnabled then
					orbit:Cancel()
					return
				end
				local angle = LobbyIdle.orbitAngle(os.clock() - startedAt, IDLE.YawSpeed, IDLE.Ramp)
				local delta = angle - turned
				turned = angle
				local pivot = cam.Focus.Position
				cam.CFrame = CFrame.new(pivot) * CFrame.Angles(0, delta, 0) * CFrame.new(-pivot) * cam.CFrame
			end)
		end)
		RunService:BindToRenderStep(CLEAR_STEP, Enum.RenderPriority.Camera.Value + 2, function(dt: number)
			Safe.call("IdleOrbit.clear", function()
				local cam = Workspace.CurrentCamera
				local focus = cam.Focus.Position
				local span = cam.CFrame.Position - focus
				local desired = span.Magnitude
				if desired < FIRST_PERSON then
					orbit:Cancel()
					return
				end
				local result = clearance:Query(cam, focus, span, desired, dt)
				if not result.ok then
					orbit:Cancel()
					return
				end
				local pull = desired - result.distance
				if pull > 1e-3 then
					cam.CFrame -= span.Unit * pull
				end
			end)
		end)
		return true
	end

	return orbit
end

return IdleOrbit
