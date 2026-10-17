--!strict
-- Preferences use the existing session-locked profile and replicate as attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage.Shared.Logic.Settings)
local Registry = require(script.Parent.Parent.Registry)
local SettingsService = {}

local function publish(player: Player)
	local profile = Registry.DataService.GetProfile(player)
	for key, value in Settings.read(if profile then profile.settings else nil) do
		player:SetAttribute(key, value)
	end
	player:SetAttribute(
		"RunsStarted",
		Settings.runsStarted(
			if profile then profile.settings else nil,
			if profile then profile.stats.runs else nil
		)
	)
	player:SetAttribute("SettingsReady", profile ~= nil)
end

local function countRun(player: Player)
	local profile = Registry.DataService.GetProfile(player)
	local runId = Registry.StateService.Get({ "run", "runId" })
	local phase = Registry.RunDirector.Phase()
	if
		not profile
		or not Registry.CrewService.IsMember(player)
		or phase == "Lobby"
		or phase == "Summary"
		or type(runId) ~= "string"
		or runId == ""
		or profile.settings.LastCountedRun == runId
	then
		return
	end
	Registry.DataService.Update(player, function(p)
		Settings.startRun(p.settings, runId, p.stats.runs)
	end)
end

local function watchPlayer(player: Player)
	publish(player)
	player.CharacterAdded:Connect(function()
		-- Crew membership is installed before its character is built.
		task.defer(countRun, player)
	end)
	countRun(player)
end

function SettingsService.Init() end

function SettingsService.Start()
	Registry.DataService.ProfileLoaded:Connect(function(player: Player)
		publish(player)
		countRun(player)
	end)
	Registry.DataService.ProfileChanged:Connect(publish)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Registry.RunDirector.PhaseChanged:Connect(function(phase: string)
		if phase == "Boarding" then
			for _, player in Players:GetPlayers() do
				countRun(player)
			end
		end
	end)
	Registry.NetService.Handle("SetSetting", function(player: Player, key: string, value: string)
		if not Settings.valid(key, value) or not Registry.DataService.GetProfile(player) then
			return
		end
		Registry.DataService.Update(player, function(profile)
			profile.settings[key] = Settings.clamp(key, value) or value
		end)
	end)
end

return SettingsService
