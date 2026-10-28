-- Isolated Studio pilot for the real CosmeticService. No production code is changed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

-- Rojo cannot shadow one file inside a $path folder, so swap the frozen production config for the
-- mutable pilot copy (the fixture's Config branch) before anything requires it.
local configFolder = ReplicatedStorage.Shared.Config
local productionConfig = configFolder:FindFirstChild("CrewClothing")
if productionConfig then
	productionConfig.Name = "CrewClothingProduction"
end
local pilotConfig = script.Parent.Services.DataService:Clone()
pilotConfig.Name = "CrewClothing"
pilotConfig.Parent = configFolder

local DataService = require(script.Parent.Services.DataService)
local CosmeticService = require(script.Parent.Services.CosmeticService)
local Config = require(ReplicatedStorage.Shared.Config.CrewClothing)
local started = false

local function log(ok, message)
	print(string.format("[service-pilot] %s %s", if ok then "PASS" else "FAIL", message))
end

local function check(condition, message)
	log(condition, message)
	return condition
end

local function addAccessory(character, name, accessoryType, transparency)
	local accessory = Instance.new("Accessory")
	accessory.Name = name
	accessory.AccessoryType = accessoryType
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = transparency
	handle.Anchored = true
	handle.CanCollide = false
	handle.Parent = accessory
	accessory.Parent = character
	return accessory, handle
end

local function near(a, b)
	return math.abs(a - b) < 0.001
end

local function waitForCharacter(player)
	if player.Character then
		return player.Character
	end
	return player.CharacterAdded:Wait()
end

local function runPlayer(player)
	local profile = {
		equipped = { Uniform = "uniform_stoker" },
		owned = { uniform_stoker = true },
	}
	DataService.SetProfile(player, profile)
	if not player.Character then
		local description = Instance.new("HumanoidDescription")
		local rig = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
		rig.Name = player.Name
		rig.Parent = workspace
		player.Character = rig
	end
	local character = waitForCharacter(player)
	local hair, hairHandle = addAccessory(character, "PilotHair", Enum.AccessoryType.Hair, 0.2)
	local hat, hatHandle = addAccessory(character, "PilotHat", Enum.AccessoryType.Hat, 0.2)
	local face, faceHandle = addAccessory(character, "PilotFace", Enum.AccessoryType.Face, 0.2)
	if not started then
		started = true
		CosmeticService.Start()
	end
	task.wait(0.5)
	local applyStarted = os.clock()
	print("[service-pilot] INFO first Apply started")
	CosmeticService.Apply(player)
	print(string.format("[service-pilot] INFO first Apply returned after %.1f s", os.clock() - applyStarted))
	task.wait(0.5)

	local cosmetics = character:FindFirstChild("Cosmetics")
	local uniform = character:FindFirstChild("CrewUniform")
	check(cosmetics ~= nil, "cosmetics folder created")
	check(uniform ~= nil, "uniform equipped")
	check(
		hair.Parent == character and hat.Parent == character and face.Parent == character,
		"hair, hat, and face remain attached"
	)
	check(
		near(hairHandle.Transparency, 0.2)
			and near(hatHandle.Transparency, 0.2)
			and near(faceHandle.Transparency, 0.2),
		"accessory handles remain visible"
	)

	CosmeticService.Apply(player)
	task.wait(0.2)
	check(character:FindFirstChild("Cosmetics") == cosmetics, "reapply is idempotent")
	local accessoryCount = 0
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			accessoryCount += 1
		end
	end
	CosmeticService.Apply(player)
	task.wait(0.2)
	local accessoryCountAfter = 0
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			accessoryCountAfter += 1
		end
	end
	check(accessoryCountAfter == accessoryCount, "reapply creates no duplicate accessories")

	Config.Enabled = false
	profile.equipped.Uniform = nil
	CosmeticService.Apply(player)
	task.wait(0.2)
	check(character:FindFirstChild("CrewUniform") == nil, "uniform-off path restores base clothing")
	Config.Enabled = true
	profile.equipped.Uniform = "uniform_stoker"
	CosmeticService.Apply(player)
	task.wait(0.2)
	check(character:FindFirstChild("CrewUniform") ~= nil, "uniform can be restored")

	local description = Instance.new("HumanoidDescription")
	local fresh = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
	fresh.Name = player.Name
	fresh.Parent = workspace
	player.Character = fresh
	local freshHair = addAccessory(fresh, "PilotHairRespawn", Enum.AccessoryType.Hair, 0.2)
	DataService.SetProfile(player, profile)
	task.wait(0.5)
	CosmeticService.Apply(player)
	task.wait(0.5)
	check(
		fresh ~= character and fresh:FindFirstChild("CrewUniform") ~= nil,
		"fresh character receives uniform"
	)
	check(freshHair.Parent == fresh, "fresh character keeps hair accessory")
	print("[service-pilot] COMPLETE player=" .. player.Name)
end

local running = false

local function begin(player)
	task.spawn(function()
		while running do
			task.wait()
		end
		running = true
		local ok, err = pcall(runPlayer, player)
		if not ok then
			warn("[service-pilot] ERROR " .. tostring(err))
		end
		running = false
	end)
end

check(Config.ById.uniform_stoker ~= nil, "pilot recipe is present")

CosmeticService.Init()
Players.PlayerAdded:Connect(begin)
for _, player in Players:GetPlayers() do
	begin(player)
end
print("[service-pilot] READY; start Play in Studio with a test player")
