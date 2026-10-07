--!strict
--[[
	The Depot Hall: ready-ups, lobby spawning, kiosk prompts and late joining.
	A player is "in the lobby" whenever they are not a live crew member and not
	aboard a boarding car (CarService); car players are ready by being aboard.
	The host (the lobby player who has been in the server longest) picks the opt-in
	run tier, up to the lowest tier any hall player has unlocked.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)
local RunTier = require(Shared.Logic.RunTier)
local Safe = require(Shared.Util.Safe)
local Types = require(Shared.Types)

local LobbyBuilder = require(script.Parent.Parent.Builders.LobbyBuilder)
local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

local LobbyService = {}

local built: LobbyBuilder.Built? = nil
local ready: { [Player]: boolean } = {}
local spawnIndex = 0
local crewOverride: { Player }? = nil
local joinOrder: { Player } = {}
local selectedTier = Difficulty.RunTier.Default
local published: Types.LobbyTier? = nil

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

local function crewMax(crew: { Player }): number
	local unlocked: { number } = {}
	for _, player in crew do
		table.insert(unlocked, Registry.DataService.UnlockedTier(player))
	end
	return RunTier.crewMax(unlocked)
end

-- The longest-present player in the hall.
local function host(): Player?
	for _, player in joinOrder do
		if
			player.Parent ~= nil
			and not Registry.CrewService.IsMember(player)
			and not Registry.CarService.IsAboard(player)
		then
			return player
		end
	end
	return nil
end

local function publishTier()
	local max = crewMax(LobbyService.LobbyPlayers())
	local h = host()
	local info: Types.LobbyTier =
		{ selected = math.min(selectedTier, max), max = max, host = if h then tostring(h.UserId) else nil }
	local last = published
	if last and last.selected == info.selected and last.max == info.max and last.host == info.host then
		return
	end
	published = info
	StateService.Set({ "lobby", "tier" }, info)
end

function LobbyService.Init()
	local origin = Tuning.World.LobbyOrigin
	built = LobbyBuilder.build(CFrame.new(origin[1], origin[2], origin[3]), Workspace)
	local b = built :: LobbyBuilder.Built
	prompt(b.outfitter, "Outfitter", "Outfitter", "Browse")
	prompt(b.ledger, "Ledger", "Line Mastery", "Read")
	StateService.Set({ "lobby" }, { ready = {}, origin = origin })
	publishTier()
end

function LobbyService.Start()
	NetService.Handle("SetReady", function(player, isReady: boolean)
		ready[player] = isReady
		publishReady()
	end, function(player)
		local phase = Registry.RunDirector.Phase()
		return (phase == "Lobby" or phase == "Countdown")
			and not Registry.CrewService.IsMember(player)
			and not Registry.CarService.IsAboard(player)
	end)

	NetService.Handle("SetRunTier", function(_player, tier: number)
		selectedTier = RunTier.clamp(tier)
		publishTier()
	end, function(player)
		local phase = Registry.RunDirector.Phase()
		return (phase == "Lobby" or phase == "Countdown") and host() == player
	end)

	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		local index = table.find(joinOrder, player)
		if index then
			table.remove(joinOrder, index)
		end
		publishReady()
	end)
	Players.PlayerAdded:Connect(function(player)
		table.insert(joinOrder, player)
		task.spawn(LobbyService.Spawn, player)
	end)
	for _, player in Players:GetPlayers() do
		table.insert(joinOrder, player)
		task.spawn(LobbyService.Spawn, player)
	end

	-- profiles load, players join, leave and come home from runs: keep the host and cap current
	task.spawn(function()
		while true do
			task.wait(Difficulty.RunTier.LobbyRefreshSeconds)
			Safe.call("LobbyService.publishTier", publishTier)
		end
	end)
end

function LobbyService.DisplayTrain(): Model?
	return if built then built.displayTrain else nil
end

function LobbyService.DisplayCabins(): { LobbyBuilder.Cabin }
	return if built then built.displayCabins else {}
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
		if not Registry.CrewService.IsMember(player) and not Registry.CarService.IsAboard(player) then
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

-- The run tier for this crew: the host's pick, capped by what every member has unlocked.
function LobbyService.TierFor(crew: { Player }): number
	return math.min(selectedTier, crewMax(crew))
end

-- The crew for the next Boarding: a launching car's players if one was set, else the hall.
function LobbyService.SetCrew(crew: { Player })
	crewOverride = crew
end

function LobbyService.TakeCrew(): { Player }
	local crew = crewOverride or LobbyService.LobbyPlayers()
	crewOverride = nil
	return crew
end

function LobbyService.ClearReady(player: Player)
	ready[player] = nil
	publishReady()
end

function LobbyService.ResetReady()
	table.clear(ready)
	publishReady()
end

return LobbyService
