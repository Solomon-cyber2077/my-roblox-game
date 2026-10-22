--!strict
--[[
	The tutorial's bookkeeping (Logic/Tutorial, Config/Tutorial). Fixes the crew's tier when a
	run starts (its least experienced member's), notes who steps off the train, and when the
	run ends adds one to profile.tutorialRuns for each of them who stepped off at least once.
	A profile that failed to load plays as a finished tutorial and is never written.

	The owner (Config/Tutorial OwnerUserId, nobody else) can type in chat:
	  /tutorial reset   your count back to 0 (first-run tutorial on your next run)
	  /tutorial 2       your count set to 0..3
	It takes effect on the next run. With a profile that did not load (an unpublished place in
	Studio) it changes only this session.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Difficulty = require(Shared.Config.Difficulty)
local RunRules = require(Shared.Logic.RunRules)
local Tutorial = require(Shared.Logic.Tutorial)
local Safe = require(Shared.Util.Safe)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)

local TutorialService = {}

local steppedOff: { [Player]: boolean } = {}
local overrides: { [Player]: number } = {} -- owner dev settings for a session whose profile did not load

-- Completed tutorial runs this player plays by.
function TutorialService.Runs(player: Player): number
	local override = overrides[player]
	if override == nil and DataService.IsLoaded(player) then
		local profile = DataService.GetProfile(player)
		return Tutorial.runs(true, profile and profile.tutorialRuns, nil)
	end
	return Tutorial.runs(false, nil, override)
end

-- The tier a crew of these players rides at.
function TutorialService.CrewTier(players: { Player }): number
	local list: { number } = {}
	for _, player in players do
		table.insert(list, TutorialService.Runs(player))
	end
	return Tutorial.crewTier(list)
end

-- Boarding: a crew member past the crew's tier is told the run goes at a new Hand's pace.
function TutorialService.AnnouncePace(players: { Player }, crewTier: number)
	if crewTier < 1 then
		return
	end
	for _, player in players do
		if Tutorial.tier(TutorialService.Runs(player)) ~= crewTier then
			NetService.Fire("Notify", player, "Info", Difficulty.Tutorial.NewHandPace)
		end
	end
end

local function countRun()
	for player, off in steppedOff do
		if player.Parent then
			local profile = DataService.GetProfile(player)
			local override = overrides[player]
			if override ~= nil then
				-- an owner dev setting on a profile that did not load: this session only
				if off then
					overrides[player] = math.min(override + 1, Difficulty.Tutorial.Runs)
				end
			else
				local nextRuns =
					Tutorial.afterRun(DataService.IsLoaded(player), profile and profile.tutorialRuns, off)
				if nextRuns then
					DataService.Update(player, function(p)
						p.tutorialRuns = nextRuns
					end)
				end
			end
		end
	end
	table.clear(steppedOff)
end

local function onChatted(player: Player, message: string)
	local arg = string.match(string.lower(message), "^/tutorial%s+(%w+)")
	if arg == nil or player.UserId ~= Difficulty.Tutorial.OwnerUserId then
		return
	end
	local value = if arg == "reset" then 0 else tonumber(arg)
	if value == nil or value ~= math.floor(value) or value < 0 or value > Difficulty.Tutorial.Runs then
		NetService.Fire(
			"Notify",
			player,
			"Warning",
			`/tutorial reset, or /tutorial 0-{Difficulty.Tutorial.Runs}`
		)
		return
	end
	local runs: number = value
	if DataService.IsLoaded(player) then
		DataService.Update(player, function(p)
			p.tutorialRuns = runs
		end)
	else
		overrides[player] = runs
	end
	NetService.Fire(
		"Notify",
		player,
		"Warning",
		`Tutorial runs set to {runs} (tier {Tutorial.tier(runs)} next run).`
	)
end

-- Studio's Dev `tutorial <n>`: the same owner-only setting as the chat command.
function TutorialService.DevSetRuns(player: Player, arg: string)
	onChatted(player, `/tutorial {arg}`)
end

function TutorialService.Init() end

function TutorialService.Start()
	Registry.RunDirector.PhaseChanged:Connect(function(phase: string, previous: string)
		if phase == "RunEnd" then
			Safe.call("TutorialService.countRun", countRun)
		elseif phase == "Boarding" or (phase == "Lobby" and previous ~= "RunEnd") then
			table.clear(steppedOff)
		end
	end)
	-- who has been off the train this run
	task.spawn(function()
		while true do
			task.wait(0.5)
			if RunRules.isRunPhase(Registry.RunDirector.Phase()) then
				for _, player in Registry.CrewService.MemberPlayers() do
					local status = Registry.CrewService.Status(player)
					if status == "Afield" or status == "Straggler" then
						steppedOff[player] = true
					elseif steppedOff[player] == nil then
						steppedOff[player] = false
					end
				end
			end
		end
	end)
	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		steppedOff[player] = nil
		overrides[player] = nil
	end)
end

return TutorialService
