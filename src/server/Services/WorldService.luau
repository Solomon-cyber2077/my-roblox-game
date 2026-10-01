--!strict
--[[
	World setup that must exist before anything else: collision groups and
	character loading policy. Lighting belongs to the client: AtmosphereController
	builds the sky, atmosphere and post effects and drives the time of day.
]]

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
