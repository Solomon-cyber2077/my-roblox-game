--!strict
--[[
	Local colour and air. Layers a client-only grade over the server's base
	lighting: warm interior in the Depot Hall, thickening air as you approach the
	fog, a red-shifted pulse during Last Call and departure, a desaturated world
	while spectating, and a flare's red flash.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local MathX = require(Shared.Util.MathX)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)

local AtmosphereController = {}

local grade: ColorCorrectionEffect
local flareUntil = 0

local LOBBY =
	Vector3.new(Tuning.World.LobbyOrigin[1], Tuning.World.LobbyOrigin[2], Tuning.World.LobbyOrigin[3])

function AtmosphereController.Init()
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "ClientGrade"
	grade.Parent = Lighting
end

function AtmosphereController.Start()
	local density, haze, saturation, contrast = 0.36, 2.1, 0, 0
	local tint = Color3.new(1, 1, 1)
	local brightness = 0
	RunService.RenderStepped:Connect(function(dt)
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = workspace.CurrentCamera
		local focus = if root then root.Position else camera.CFrame.Position
		local phase = Session.phase()
		local now = Session.now()

		local targetDensity, targetHaze, targetSat, targetContrast = 0.36, 2.1, 0, 0
		local targetTint = Color3.new(1, 1, 1)
		local targetBrightness = 0

		if (focus - LOBBY).Magnitude < 420 then
			targetDensity, targetHaze = 0.18, 0.8
			targetTint = Color3.fromRGB(255, 236, 214)
			targetSat = 0.05
			targetBrightness = -0.07
			targetContrast = 0.08
		else
			local fog = Registry.StationVisualsController and Registry.StationVisualsController.FogDepth()
			local localPos = Registry.StationVisualsController
				and Registry.StationVisualsController.ToLocal(focus)
			if fog and localPos then
				local inside = math.clamp((localPos.Z - (fog - 24)) / 30, 0, 1)
				targetDensity = MathX.lerp(0.36, 0.78, inside)
				targetHaze = MathX.lerp(2.1, 4, inside)
				targetSat -= 0.3 * inside
			end
			if phase == "LastCall" or phase == "Departure" then
				local pulse = 0.5 + 0.5 * math.sin(now * 5)
				targetTint = Color3.new(1, 0.9 - 0.06 * pulse, 0.88 - 0.08 * pulse)
				targetContrast = 0.12
			end
		end
		if Session.status() == "Eliminated" and Session.isRunActive() then
			targetSat = -0.65
		end
		if os.clock() < flareUntil then
			local k = (flareUntil - os.clock()) / 1.6
			targetTint = targetTint:Lerp(Color3.fromRGB(255, 150, 140), k)
			targetBrightness = 0.08 * k
		end

		local blend = MathX.damp(0.35, dt)
		density = MathX.lerp(density, targetDensity, blend)
		haze = MathX.lerp(haze, targetHaze, blend)
		saturation = MathX.lerp(saturation, targetSat, blend)
		contrast = MathX.lerp(contrast, targetContrast, blend)
		tint = tint:Lerp(targetTint, blend)
		brightness = MathX.lerp(brightness, targetBrightness, MathX.damp(0.08, dt))
		if atmosphere then
			atmosphere.Density = density
			atmosphere.Haze = haze
		end
		grade.Saturation = saturation
		grade.Contrast = contrast
		grade.TintColor = tint
		grade.Brightness = brightness
	end)
end

function AtmosphereController.FlareFlash()
	flareUntil = os.clock() + 1.6
end

return AtmosphereController
