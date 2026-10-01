--!strict
--[[
	The Depot Hall: ready-ups, lobby spawning, kiosk prompts and late joining.
	A player is "in the lobby" whenever they are not a live crew member.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)

local LobbyBuilder = require(script.Parent.Parent.Builders.LobbyBuilder)
local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

local LobbyService = {}

local built: LobbyBuilder.Built? = nil
local ready: { [Player]: boolean } = {}
local spawnIndex = 0

local function publishReady()
	local map: { [string]: boolean } = {}
	for player, isReady in ready do
		if isReady then
			map[tostring(player.UserId)] = true
		end
	end
	StateService.Set({ "lobby", "ready" }, map)
end

local function prompt(part: BasePart, action: string, objectText: string, actionText: string)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Action", action)
	p.Parent = part
end

function LobbyService.Init()
	local origin = Tuning.World.LobbyOrigin
	built = LobbyBuilder.build(CFrame.new(origin[1], origin[2], origin[3]), Workspace)
	local b = built :: LobbyBuilder.Built
	prompt(b.outfitter, "Outfitter", "Outfitter", "Browse")
	prompt(b.ledger, "Ledger", "Line Mastery", "Read")
	StateService.Set({ "lobby" }, { ready = {}, origin = origin })
end

function LobbyService.Start()
	NetService.Handle("SetReady", function(player, isReady: boolean)
		ready[player] = isReady
		publishReady()
	end, function(player)
		local phase = Registry.RunDirector.Phase()
		return (phase == "Lobby" or phase == "Countdown") and not Registry.CrewService.IsMember(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		publishReady()
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(LobbyService.Spawn, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(LobbyService.Spawn, player)
	end
end

function LobbyService.DisplayTrain(): Model?
	return if built then built.displayTrain else nil
end

function LobbyService.Board(): BasePart?
	return if built then built.board else nil
end

function LobbyService.SpawnPoint(): CFrame
	local b = built :: LobbyBuilder.Built
	spawnIndex = spawnIndex % #b.spawnPoints + 1
	return b.spawnPoints[spawnIndex]
end

-- Loads a fresh character in the hall.
function LobbyService.Spawn(player: Player)
	Registry.CrewService.LoadCharacterAt(player, LobbyService.SpawnPoint())
end

function LobbyService.LobbyPlayers(): { Player }
	local out: { Player } = {}
	for _, player in Players:GetPlayers() do
		if not Registry.CrewService.IsMember(player) then
			table.insert(out, player)
		end
	end
	return out
end

function LobbyService.LobbyCount(): number
	return #LobbyService.LobbyPlayers()
end

function LobbyService.ReadyCount(): number
	local count = 0
	for player, isReady in ready do
		if isReady and player.Parent ~= nil and not Registry.CrewService.IsMember(player) then
			count += 1
		end
	end
	return count
end

function LobbyService.ResetReady()
	table.clear(ready)
	publishReady()
end

return LobbyService
