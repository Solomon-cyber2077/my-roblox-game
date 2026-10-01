--!strict
--[[
	World setup that must exist before anything else: collision groups,
	character loading policy, base lighting and post-processing.
	Clients layer per-phase grading on top of this (AtmosphereController).
]]

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local WorldService = {}

local GROUPS = { "Players", "Train", "Station", "Hollows", "Debris", "Pickups" }

local function setupCollisionGroups()
	for _, name in GROUPS do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end
	local rules: { { string } } = {
		{ "Players", "Players" }, -- nobody can block a doorway with their body
		{ "Station", "Train" }, -- the moving station slides past the static train
		{ "Hollows", "Hollows" },
		{ "Hollows", "Train" },
		{ "Debris", "Train" },
		{ "Debris", "Station" },
		{ "Debris", "Hollows" },
	}
	for _, pair in rules do
		PhysicsService:CollisionGroupSetCollidable(pair[1], pair[2], false)
	end
end

local function setupLighting()
	Lighting.ClockTime = 17.7
	Lighting.GeographicLatitude = 38
	Lighting.Brightness = 2.8
	Lighting.Ambient = Color3.fromRGB(70, 62, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(136, 120, 118)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0.3

	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.36
	atmosphere.Offset = 0.22
	atmosphere.Color = Color3.fromRGB(196, 164, 136)
	atmosphere.Decay = Color3.fromRGB(96, 62, 54)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 2.1
	atmosphere.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8
	sky.StarCount = 1200
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "BaseGrade"
	grade.Saturation = -0.08
	grade.Contrast = 0.1
	grade.Brightness = 0.01
	grade.TintColor = Color3.fromRGB(255, 244, 232)
	grade.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.6
	rays.Parent = Lighting
end

local function clearTemplate()
	-- A fresh Baseplate place ships with these; the game builds its own world.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = Workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		terrain:Clear()
	end
end

function WorldService.Init()
	Players.CharacterAutoLoads = false
	StarterPlayer.CharacterWalkSpeed = 16
	StarterPlayer.CharacterJumpHeight = 7.2
	StarterPlayer.CharacterUseJumpPower = false
	setupCollisionGroups()
	clearTemplate()
	setupLighting()
end

function WorldService.Start() end

-- Puts every part of a character in the Players collision group.
function WorldService.TagCharacter(character: Model)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end)
end

return WorldService
