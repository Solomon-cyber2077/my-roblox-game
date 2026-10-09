--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Safe = require(ReplicatedStorage.Shared.Util.Safe)
local CosmeticMotion = require(ReplicatedStorage.Shared.Visual.CosmeticMotion)

local TRAIL_RATES = {
	Steam = 5,
	Mist = 4,
	Cinder = 6,
	Sparks = 6,
}

type Entry = {
	character: Model,
	humanoid: Humanoid?,
	root: BasePart?,
	cosmetics: Folder?,
	animate: ((number) -> ())?,
	trails: { ParticleEmitter },
}

local entries: { [Player]: Entry } = {}

local function refresh(entry: Entry)
	if entry.animate then
		entry.animate = nil
	end
	entry.trails = {}
	entry.humanoid = entry.character:FindFirstChildOfClass("Humanoid")
	entry.root = entry.character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local folder = entry.character:FindFirstChild("Cosmetics")
	entry.cosmetics = if folder and folder:IsA("Folder") then folder else nil
	if entry.cosmetics then
		entry.animate = CosmeticMotion.bind(entry.cosmetics)
	end
	for _, descendant in entry.character:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant.Name == "TrailEmitter" then
			table.insert(entry.trails, descendant)
		end
	end
end

local function watch(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local entry: Entry = {
		character = character,
		humanoid = character:FindFirstChildOfClass("Humanoid"),
		root = character:FindFirstChild("HumanoidRootPart") :: BasePart?,
		cosmetics = nil,
		animate = nil,
		trails = {},
	}
	entries[player] = entry
	refresh(entry)
end

local function unwatch(player: Player)
	local entry = entries[player]
	if entry then
		entries[player] = nil
	end
end

local function connectPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		unwatch(player)
		watch(player)
	end)
	watch(player)
end

Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(unwatch)
for _, player in Players:GetPlayers() do
	connectPlayer(player)
end

local refreshClock = 0
local motionClock = 0
RunService.Heartbeat:Connect(function(dt: number)
	refreshClock += dt
	motionClock += dt
	if refreshClock >= 0.5 then
		refreshClock = 0
		for _, entry in entries do
			refresh(entry)
		end
	end
	if motionClock < 0.05 then
		return
	end
	motionClock = 0
	local now = os.clock()
	for _, entry in entries do
		Safe.call("CosmeticEffects", function()
			if entry.animate then
				entry.animate(now)
			end
			local humanoid = entry.humanoid
			local root = entry.root
			local moving = humanoid ~= nil
				and humanoid.Health > 0
				and root ~= nil
				and root.AssemblyLinearVelocity.Magnitude > 1
			for _, trail in entry.trails do
				local kind = trail:GetAttribute("Style")
				trail.Rate = if moving then TRAIL_RATES[kind] or 0 else 0
			end
		end)
	end
end)
